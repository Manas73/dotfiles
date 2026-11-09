#!/usr/bin/env python3
"""Print the mise tools the package catalog tracks at `@latest`, one per line.

Pinned specs (tool@1.2.3) are skipped so `mise upgrade --bump` leaves them
alone. Run via `mise run update-mise`.
"""

from __future__ import annotations

import sys
from pathlib import Path

from ansible.parsing.dataloader import DataLoader

ANSIBLE_DIR = Path(__file__).resolve().parents[1]
CATALOG = ANSIBLE_DIR / "group_vars" / "all" / "package_catalog.yml"


def latest_tools(catalog: dict) -> list[str]:
    tools: set[str] = set()
    for entry in catalog.values():
        for block in (entry or {}).values():
            if not isinstance(block, dict) or block.get("provider") != "mise":
                continue
            for spec in block.get("packages") or []:
                name, _, version = spec.rpartition("@")
                if name and version == "latest":
                    # pypi:black[extras=jupyter] -> pypi:black (the config key).
                    tools.add(name.split("[", 1)[0])
    return sorted(tools)


def main() -> int:
    loader = DataLoader()
    data = loader.load_from_file(str(CATALOG))
    if not isinstance(data, dict) or "package_catalog" not in data:
        raise SystemExit(f"expected package_catalog mapping in {CATALOG}")
    print("\n".join(latest_tools(data["package_catalog"])))
    return 0


if __name__ == "__main__":
    sys.exit(main())
