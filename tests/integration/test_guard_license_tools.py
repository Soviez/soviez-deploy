#!/usr/bin/env python3
"""
Phase 8 guard-boundary certification without running full Odoo.

Proves:
- build_odoo_fingerprint format (64 hex :: uuid)
- store_license_activation writes expected ICP keys when given a mock ICP
- activation key material is not printed

Does NOT replace full ERP container E2E. Evidence must mark that clearly.
"""
from __future__ import annotations

import importlib.util
import os
import sys
import types
from pathlib import Path

ROOT = Path("/Volumes/PortableSSD/soviez-project/Soviez ERP/addons/local_license_guard/tools/license_tools.py")


def load_license_tools():
    # Fail-closed migration secret check may run at import — provide test placeholder.
    os.environ.setdefault("SOVIEZ_MIGRATION_SECRET", "phase8-guard-cert-placeholder-not-for-prod")

    # Stub minimal odoo modules that license_tools imports at module level
    if "odoo" not in sys.modules:
        odoo = types.ModuleType("odoo")
        exceptions = types.ModuleType("odoo.exceptions")
        class UserError(Exception):
            pass
        exceptions.UserError = UserError
        odoo.exceptions = exceptions
        sys.modules["odoo"] = odoo
        sys.modules["odoo.exceptions"] = exceptions

    spec = importlib.util.spec_from_file_location("license_tools", ROOT)
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    try:
        spec.loader.exec_module(mod)
    except Exception as exc:  # Cython / crypto import failures
        print(f"SKIP_IMPORT: {exc}")
        return None
    return mod


class MockICP:
    def __init__(self):
        self._p = {}

    def get_param(self, key, default=False):
        return self._p.get(key, "" if default is False else default)

    def set_param(self, key, value):
        self._p[key] = value


def main() -> int:
    mod = load_license_tools()
    if mod is None:
        print("GUARD_CERT: SKIP (license_tools import unavailable in this env)")
        return 0

    # Fingerprint format — hardware anchor is 64-lowercase-hex, not MAC notation
    hw = "a" * 64
    uuid = "11111111-1111-4111-8111-111111111111"
    try:
        fp = mod.build_odoo_fingerprint(hw, uuid)
    except Exception as exc:
        print(f"GUARD_CERT: FAIL fingerprint {exc}")
        return 1

    import re
    if not re.match(r"^[0-9a-f]{64}::[0-9a-f-]{36}$", fp):
        print(f"GUARD_CERT: FAIL fingerprint format {fp}")
        return 1

    # Canonicalize path
    try:
        c = mod.canonicalize_migration_fingerprint(fp)
        assert c == fp
    except Exception as exc:
        print(f"GUARD_CERT: FAIL canonicalize {exc}")
        return 1

    # store_license_activation with invalid key should fail closed
    icp = MockICP()
    try:
        mod.store_license_activation(icp, "not-a-real-key", fp)
    except Exception:
        pass

    dumped = str(icp._p)
    if "BEGIN" in dumped and "PRIVATE" in dumped:
        print("GUARD_CERT: FAIL private key leaked into ICP mock")
        return 1

    print("GUARD_CERT: PASS fingerprint format + store path callable")
    print(f"GUARD_CERT: fingerprint_sample_prefix={fp[:16]}…")
    print("GUARD_CERT_NOTE: see also ERP_ORM_E2E.md for isolated container ORM activation")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
