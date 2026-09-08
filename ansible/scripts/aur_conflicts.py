#!/usr/bin/env python3
"""Report AUR catalog packages whose install would conflict with installed pkgs.

Walks uninstalled AUR targets and their uninstalled dependencies against
the sync DB (expac) and, for AUR-only names, `yay -Si`. Does not install
anything. Run via `mise run aur-conflicts`.
"""

from __future__ import annotations

import argparse
import os
import re
import socket
import subprocess
import sys
from collections import deque
from pathlib import Path

ANSIBLE_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ANSIBLE_DIR / "filter_plugins"))

from ansible.parsing.dataloader import DataLoader  # noqa: E402
from catalog import resolve_catalog  # noqa: E402

SPLIT_VER = re.compile(r"[<>=:]")


def pkgname(token: str) -> str:
    return SPLIT_VER.split(token.strip(), maxsplit=1)[0]


def load_yaml(loader: DataLoader, path: Path) -> dict:
    data = loader.load_from_file(str(path))
    if not isinstance(data, dict):
        raise SystemExit(f"expected mapping in {path}")
    return data


def find_host(node, hostname: str) -> dict | None:
    if not isinstance(node, dict):
        return None
    hosts = node.get("hosts")
    if isinstance(hosts, dict) and hostname in hosts:
        entry = hosts[hostname]
        return entry if isinstance(entry, dict) else {}
    for child in node.values():
        found = find_host(child, hostname)
        if found is not None:
            return found
    return None


def aur_targets(hostname: str) -> list[str]:
    loader = DataLoader()
    loader.set_basedir(str(ANSIBLE_DIR))
    hosts = load_yaml(loader, ANSIBLE_DIR / "hosts.yml")
    host = find_host(hosts, hostname)
    if host is None:
        raise SystemExit(f"host {hostname!r} is not in ansible/hosts.yml")
    recipe_name = host.get("recipe")
    if not recipe_name:
        raise SystemExit(f"host {hostname!r} has no recipe:")
    recipe = load_yaml(loader, ANSIBLE_DIR / "recipes" / f"{recipe_name}.yml")
    os_apps = load_yaml(loader, ANSIBLE_DIR / "group_vars" / "arch" / "apps.yml")[
        "os_apps"
    ]
    profiles = load_yaml(loader, ANSIBLE_DIR / "group_vars" / "all" / "profiles.yml")[
        "profiles_catalog"
    ]
    catalog = load_yaml(
        loader, ANSIBLE_DIR / "group_vars" / "all" / "package_catalog.yml"
    )["package_catalog"]
    apps = list(os_apps)
    for name in recipe.get("profiles") or []:
        block = profiles.get(name) or {}
        apps.extend(block.get("apps") or [])
    apps.extend(recipe.get("apps") or [])
    resolved = resolve_catalog(apps, catalog, "arch", "pacman")
    return list(resolved.get("packages", {}).get("aur") or [])


def run_lines(argv: list[str]) -> list[str]:
    proc = subprocess.run(argv, check=False, capture_output=True, text=True)
    if proc.returncode != 0:
        return []
    return [line for line in proc.stdout.splitlines() if line]


def installed_names() -> set[str]:
    return set(run_lines(["pacman", "-Qq"]))


def installed_provides() -> dict[str, set[str]]:
    """provide name -> installed package names that provide it."""
    out: dict[str, set[str]] = {}
    for line in run_lines(["expac", "%n\t%S"]):
        name, _, provides = line.partition("\t")
        out.setdefault(name, set()).add(name)
        for token in provides.split():
            prov = pkgname(token)
            if prov:
                out.setdefault(prov, set()).add(name)
    return out


class Pkg:
    __slots__ = ("name", "conflicts", "depends", "provides")

    def __init__(self, name: str):
        self.name = name
        self.conflicts: set[str] = set()
        self.depends: set[str] = set()
        self.provides: set[str] = {name}


def parse_tokens(raw: str) -> set[str]:
    if not raw or raw == "None":
        return set()
    return {pkgname(tok) for tok in raw.split() if tok and tok != "None"}


def parse_expac(text: str) -> dict[str, Pkg]:
    info: dict[str, Pkg] = {}
    for line in text.splitlines():
        parts = line.split("\t")
        if not parts or not parts[0]:
            continue
        pkg = Pkg(parts[0])
        if len(parts) > 1:
            pkg.conflicts = parse_tokens(parts[1])
        if len(parts) > 2:
            pkg.depends = parse_tokens(parts[2])
        if len(parts) > 3:
            pkg.provides = parse_tokens(parts[3]) | {pkg.name}
        info[pkg.name] = pkg
    return info


def parse_yay_si(text: str) -> dict[str, Pkg]:
    info: dict[str, Pkg] = {}
    current: Pkg | None = None
    field: str | None = None
    buf: list[str] = []

    def flush() -> None:
        nonlocal field, buf
        if current is None or field is None:
            buf = []
            field = None
            return
        value = " ".join(buf).strip()
        if field == "conflicts":
            current.conflicts = parse_tokens(value)
        elif field == "depends":
            current.depends = parse_tokens(value)
        elif field == "provides":
            current.provides = parse_tokens(value) | {current.name}
        buf = []
        field = None

    for line in text.splitlines():
        if line.startswith("Name") and ":" in line:
            flush()
            current = Pkg(line.split(":", 1)[1].strip())
            info[current.name] = current
            continue
        if current is None:
            continue
        if ":" in line and not line.startswith(" "):
            key, _, rest = line.partition(":")
            key_l = key.strip().lower()
            mapped = {
                "conflicts with": "conflicts",
                "depends on": "depends",
                "provides": "provides",
            }.get(key_l)
            if mapped:
                flush()
                field = mapped
                buf = [rest.strip()]
                continue
            flush()
            continue
        if field is not None:
            buf.append(line.strip())
    flush()
    return info


class InfoCache:
    def __init__(self) -> None:
        self._data: dict[str, Pkg] = {}
        self._missing: set[str] = set()

    def fetch(self, names: list[str]) -> None:
        want = [n for n in names if n not in self._data and n not in self._missing]
        if not want:
            return
        proc = subprocess.run(
            ["expac", "-S", "%n\t%C\t%E\t%S", *want],
            check=False,
            capture_output=True,
            text=True,
        )
        found = parse_expac(proc.stdout)
        self._data.update(found)
        leftover = [n for n in want if n not in found]
        if leftover:
            # `yay -Si a b` fails the whole query if any name is missing.
            for name in leftover:
                yay = subprocess.run(
                    ["yay", "-Si", "--", name],
                    check=False,
                    capture_output=True,
                    text=True,
                )
                yfound = parse_yay_si(yay.stdout)
                if name in yfound:
                    self._data[name] = yfound[name]
                else:
                    self._missing.add(name)

    def get(self, name: str) -> Pkg | None:
        if name not in self._data and name not in self._missing:
            self.fetch([name])
        return self._data.get(name)


def satisfied(dep: str, installed: set[str], provides: dict[str, set[str]]) -> bool:
    return dep in installed or bool(provides.get(dep))


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Find AUR catalog apps that would conflict with installed packages."
    )
    parser.add_argument(
        "--host",
        default=os.environ.get("AUR_CONFLICTS_HOST") or socket.gethostname(),
        help="inventory hostname (default: this machine)",
    )
    parser.add_argument(
        "--all",
        action="store_true",
        help="include already-installed AUR targets (deps they would pull on reinstall)",
    )
    args = parser.parse_args()

    targets = aur_targets(args.host)
    installed = installed_names()
    provides = installed_provides()
    pending_roots = [
        pkg
        for pkg in targets
        if args.all or not satisfied(pkg, installed, provides)
    ]
    if not pending_roots:
        print(f"No pending AUR installs for {args.host} ({len(targets)} catalogued).")
        print("Pass --all to check already-installed apps too.")
        return 0

    cache = InfoCache()
    cache.fetch(pending_roots)

    queue: deque[tuple[str, str]] = deque((pkg, pkg) for pkg in pending_roots)
    seen: set[str] = set()
    hits: list[tuple[str, str, str, str]] = []
    missing: list[tuple[str, str]] = []

    while queue:
        name, root = queue.popleft()
        if name in seen:
            continue
        seen.add(name)
        pkg = cache.get(name)
        if pkg is None:
            missing.append((name, root))
            continue
        for conflict in pkg.conflicts:
            if conflict in installed and conflict != name:
                hits.append((root, name, conflict, "conflicts with"))
        for dep in pkg.depends:
            if satisfied(dep, installed, provides):
                providers = provides.get(dep, set())
                if dep not in installed and dep not in providers:
                    continue
                # A real repo package of this name would replace the provider.
                if dep not in installed:
                    cache.fetch([dep])
                    real = cache.get(dep)
                    if real is not None and dep not in providers:
                        for provider in sorted(providers):
                            provider_pkg = cache.get(provider)
                            provider_conflicts = (
                                provider_pkg.conflicts if provider_pkg else set()
                            )
                            if provider in real.conflicts or dep in provider_conflicts:
                                hits.append(
                                    (
                                        root,
                                        dep,
                                        provider,
                                        "needed; conflicts with provider",
                                    )
                                )
                continue
            queue.append((dep, root))

    print(
        f"Host {args.host}: {len(targets)} AUR catalog packages, "
        f"{len(pending_roots)} pending."
    )
    if missing:
        print("No metadata (not in repos / yay -Si failed):")
        for name, root in missing:
            print(f"  {name}  (needed by {root})")
    if not hits:
        print("No conflicts against installed packages.")
        return 0

    print(f"{len(hits)} conflict(s):")
    print()
    print(f"{'AUR app':<28} {'would install':<28} {'clashes with':<24} reason")
    print(f"{'-'*28} {'-'*28} {'-'*24} {'-'*32}")
    for root, new, old, reason in sorted(set(hits)):
        print(f"{root:<28} {new:<28} {old:<24} {reason}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
