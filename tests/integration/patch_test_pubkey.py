#!/usr/bin/env python3
"""Patch LICENSE_PUBLIC_KEY_PEM in a workspace copy of license_tools.py."""
from __future__ import annotations

import re
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 4:
        print("usage: patch_test_pubkey.py <src_py> <public_pem> <out_py>", file=sys.stderr)
        return 2
    src = Path(sys.argv[1]).read_text(encoding="utf-8")
    pub = Path(sys.argv[2]).read_text(encoding="utf-8").strip() + "\n"
    pat = r'LICENSE_PUBLIC_KEY_PEM = """\\.*?"""'
    repl = 'LICENSE_PUBLIC_KEY_PEM = """\\\n' + pub + '"""'
    out, n = re.subn(pat, repl, src, count=1, flags=re.S)
    if n != 1:
        # Fallback without requiring the line-continuation backslash
        pat2 = r"LICENSE_PUBLIC_KEY_PEM = \"\"\"[\s\S]*?\"\"\""
        repl2 = 'LICENSE_PUBLIC_KEY_PEM = """\\\n' + pub + '"""'
        out, n = re.subn(pat2, repl2, src, count=1)
    if n != 1:
        print(f"failed to patch public key block (n={n})", file=sys.stderr)
        return 1
    Path(sys.argv[3]).write_text(out, encoding="utf-8")
    print("patched ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
