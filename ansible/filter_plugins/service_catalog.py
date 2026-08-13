"""Service catalog resolver. Sibling to catalog.py (packages).

Resolves logical service names against group_vars/all/service_catalog.yml
into per-manager buckets:
    {"systemd_user": [...], "systemd_system": [...], "brew": [...]}
Each entry is a fully-specified dict consumed by roles/services/tasks/.
See service_catalog.yml for the schema. Exhaustive catalog; missing OS key
is a silent skip.
"""

from __future__ import annotations

from typing import Any

from ansible.errors import AnsibleFilterError

VALID_MANAGERS = {"systemd", "brew"}
VALID_SCOPES = {"system", "user"}
SYSTEMD_STATES = {"started", "stopped", "restarted", "reloaded"}
BREW_STATES = {"started", "stopped", "restarted"}


class ServiceCatalogError(AnsibleFilterError):
    """Raised for any service-catalog schema or resolution error."""


def _require_name(name: str, target_os: str, block: dict[str, Any]) -> str:
    unit = block.get("name")
    if not isinstance(unit, str) or not unit:
        raise ServiceCatalogError(
            f"Service '{name}'.{target_os} must have a non-empty string 'name'."
        )
    return unit


def _ingest_systemd(
    name: str,
    target_os: str,
    block: dict[str, Any],
    buckets: dict[str, list[dict[str, Any]]],
) -> None:
    unit = _require_name(name, target_os, block)

    scope = block.get("scope", "system")
    if scope not in VALID_SCOPES:
        raise ServiceCatalogError(
            f"Service '{name}'.{target_os} has invalid scope {scope!r}. "
            f"Valid: {sorted(VALID_SCOPES)}."
        )

    enabled = block.get("enabled", True)
    if not isinstance(enabled, bool):
        raise ServiceCatalogError(
            f"Service '{name}'.{target_os}.enabled must be a bool, "
            f"got {type(enabled).__name__}."
        )

    entry: dict[str, Any] = {"name": unit, "enabled": enabled}

    state = block.get("state")
    if state is not None:
        if state not in SYSTEMD_STATES:
            raise ServiceCatalogError(
                f"Service '{name}'.{target_os} has invalid systemd state "
                f"{state!r}. Valid: {sorted(SYSTEMD_STATES)}."
            )
        entry["state"] = state

    bucket = "systemd_user" if scope == "user" else "systemd_system"
    buckets.setdefault(bucket, []).append(entry)


def _ingest_brew(
    name: str,
    target_os: str,
    block: dict[str, Any],
    buckets: dict[str, list[dict[str, Any]]],
) -> None:
    unit = _require_name(name, target_os, block)

    for forbidden in ("scope", "enabled"):
        if forbidden in block:
            raise ServiceCatalogError(
                f"Service '{name}'.{target_os} manager 'brew' does not "
                f"support {forbidden!r}."
            )

    state = block.get("state", "started")
    if state not in BREW_STATES:
        raise ServiceCatalogError(
            f"Service '{name}'.{target_os} has invalid brew state {state!r}. "
            f"Valid: {sorted(BREW_STATES)}."
        )

    buckets.setdefault("brew", []).append({"name": unit, "state": state})


def _ingest_block(
    name: str,
    target_os: str,
    block: Any,
    buckets: dict[str, list[dict[str, Any]]],
) -> None:
    if not isinstance(block, dict):
        raise ServiceCatalogError(
            f"Service '{name}'.{target_os} manager block must be a mapping, "
            f"got {type(block).__name__}."
        )

    manager = block.get("manager")
    if manager is None:
        raise ServiceCatalogError(
            f"Service '{name}'.{target_os} missing required 'manager' key."
        )
    if manager not in VALID_MANAGERS:
        raise ServiceCatalogError(
            f"Service '{name}'.{target_os} has invalid manager {manager!r}. "
            f"Valid: {sorted(VALID_MANAGERS)}."
        )

    if manager == "systemd":
        _ingest_systemd(name, target_os, block, buckets)
    else:
        _ingest_brew(name, target_os, block, buckets)


def _resolve_one(
    name: str,
    catalog: dict[str, Any],
    target_os: str,
    buckets: dict[str, list[dict[str, Any]]],
) -> None:
    entry = catalog.get(name)
    if entry is None:
        raise ServiceCatalogError(
            f"resolve_services: service {name!r} has no entry in "
            f"service_catalog. Add it to group_vars/all/service_catalog.yml."
        )

    if not isinstance(entry, dict):
        raise ServiceCatalogError(
            f"Service entry '{name}' must be a mapping, got {type(entry).__name__}."
        )

    os_entry = entry.get(target_os)
    if os_entry is None:
        return

    blocks = os_entry if isinstance(os_entry, list) else [os_entry]
    if not blocks:
        raise ServiceCatalogError(
            f"Service '{name}'.{target_os} must not be an empty list."
        )
    for block in blocks:
        _ingest_block(name, target_os, block, buckets)


def resolve_services(
    services: list[str] | None,
    catalog: dict[str, Any] | None,
    target_os: str,
) -> dict[str, list[dict[str, Any]]]:
    if services is None:
        services = []
    if catalog is None:
        catalog = {}

    if not isinstance(services, list):
        raise ServiceCatalogError(
            f"resolve_services: 'services' must be a list, got "
            f"{type(services).__name__}."
        )
    if not isinstance(catalog, dict):
        raise ServiceCatalogError(
            f"resolve_services: 'catalog' must be a dict, got {type(catalog).__name__}."
        )
    if not isinstance(target_os, str) or not target_os:
        raise ServiceCatalogError(
            "resolve_services: 'target_os' must be a non-empty string."
        )

    buckets: dict[str, list[dict[str, Any]]] = {}
    for svc in services:
        if not isinstance(svc, str) or not svc:
            raise ServiceCatalogError(
                f"resolve_services: service names must be non-empty strings; "
                f"got {svc!r}."
            )
        _resolve_one(svc, catalog, target_os, buckets)

    result: dict[str, list[dict[str, Any]]] = {}
    for bucket, entries in buckets.items():
        seen: list[dict[str, Any]] = []
        for entry in sorted(entries, key=lambda e: e["name"]):
            if entry not in seen:
                seen.append(entry)
        result[bucket] = seen
    return result


class FilterModule:
    """Expose ``resolve_services`` as an ansible jinja filter."""

    def filters(self) -> dict[str, Any]:
        return {"resolve_services": resolve_services}
