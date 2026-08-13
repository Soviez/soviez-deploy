#!/usr/bin/env python3
"""Generate all Phase 19 migration modules."""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MIG = ROOT / "src" / "migration"


def w(rel: str, content: str) -> None:
    path = MIG / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    if not content.endswith("\n"):
        content += "\n"
    path.write_text(content)
    print(f"wrote {rel}")


def main() -> None:
    # --- common/codes.sh ---
    w(
        "common/codes.sh",
        Path(__file__).with_name("_codes_body.sh").read_text()
        if Path(__file__).with_name("_codes_body.sh").exists()
        else "",
    )
    # codes written separately below if empty
    if not (MIG / "common/codes.sh").read_text().strip():
        raise SystemExit("codes body missing")


if __name__ == "__main__":
    # Prefer writing files inline in this script body
    pass
