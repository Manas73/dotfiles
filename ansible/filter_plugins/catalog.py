"""Package catalog resolver for the ansible packages orchestrator.

Resolves a list of logical application names against the per-OS package
catalog and returns a dict bucketed by provider name. Each bucket is the
input to the matching ``provider_<name>`` role.

Catalog schema (in YAML)::

    vivaldi:
      arch:   { provider: pacman, packages: [vivaldi, vivaldi-ffmpeg-codecs] }
      darwin: { provider: cask,   packages: [vivaldi] }

    docker:
      includes: [docker-engine, docker-buildx-plugin, docker-compose-plugin]

Rules:

* An entry has either ``includes:`` (a bundle) or per-OS keys (``arch``,
  ``darwin``, ...). Not both.
* ``includes:`` expands recursively. Cycles raise ``CatalogError``.
* An app whose logical name is not in the catalog is routed verbatim to
  ``default_provider`` (e.g. ``pacman`` on arch, ``brew`` on darwin).
* An app whose catalog entry has no key for ``target_os`` is silently
  dropped: the user explicitly chose not to install it on this OS.
* Output buckets are deduplicated and sorted for stable diffs.
"""

from __future__ import annotations

from typing import Any

from ansible.errors import AnsibleFilterError

# Providers must match the existing ``roles/provider_<name>/`` set. Add a
# new entry here when you add a new provider role; nothing else changes.
# Multilib is intentionally absent: it is a pacman repo, not a separate
# manager, so multilib packages route to ``pacman`` and provider_pacman
# installs them via the same module.
VALID_PROVIDERS = {"pacman", "aur", "brew", "cask"}


class CatalogError(AnsibleFilterError):
    """Raised for any catalog-schema or resolution error."""


def _resolve_one(
    name: str,
    catalog: dict[str, Any],
    target_os: str,
    default_provider: str,
    buckets: dict[str, list[str]],
    visited: list[str],
) -> None:
    if name in visited:
        chain = " -> ".join(visited + [name])
        raise CatalogError(f"Circular include detected in catalog. Chain: {chain}")

    entry = catalog.get(name)
    if entry is None:
        # Not in catalog: route verbatim to the default provider for this OS.
        buckets.setdefault(default_provider, []).append(name)
        return

    if not isinstance(entry, dict):
        raise CatalogError(
            f"Catalog entry '{name}' must be a mapping, got {type(entry).__name__}."
        )

    if "includes" in entry:
        if any(key in entry for key in ("arch", "darwin")):
            raise CatalogError(
                f"Catalog entry '{name}' cannot have both 'includes' and per-OS keys."
            )
        children = entry["includes"]
        if not isinstance(children, list):
            raise CatalogError(
                f"Catalog entry '{name}'.includes must be a list, "
                f"got {type(children).__name__}."
            )
        next_visited = visited + [name]
        for child in children:
            if not isinstance(child, str):
                raise CatalogError(
                    f"Catalog entry '{name}'.includes must contain strings; "
                    f"got {child!r}."
                )
            _resolve_one(
                child, catalog, target_os, default_provider, buckets, next_visited
            )
        return

    os_entry = entry.get(target_os)
    if os_entry is None:
        # App exists cross-OS but isn't packaged for this OS. Silent skip
        # so darwin-only apps don't fail on Arch and vice versa.
        return

    if not isinstance(os_entry, dict):
        raise CatalogError(
            f"Catalog entry '{name}'.{target_os} must be a mapping, "
            f"got {type(os_entry).__name__}."
        )

    provider = os_entry.get("provider")
    if provider is None:
        raise CatalogError(
            f"Catalog entry '{name}'.{target_os} missing required 'provider' key."
        )
    if provider not in VALID_PROVIDERS:
        raise CatalogError(
            f"Catalog entry '{name}'.{target_os} has invalid provider "
            f"{provider!r}. Valid providers: {sorted(VALID_PROVIDERS)}."
        )

    packages = os_entry.get("packages")
    if not isinstance(packages, list) or not packages:
        raise CatalogError(
            f"Catalog entry '{name}'.{target_os} must have a non-empty "
            f"'packages' list."
        )
    for pkg in packages:
        if not isinstance(pkg, str) or not pkg:
            raise CatalogError(
                f"Catalog entry '{name}'.{target_os}.packages must contain "
                f"non-empty strings; got {pkg!r}."
            )

    buckets.setdefault(provider, []).extend(packages)


def resolve_catalog(
    apps: list[str] | None,
    catalog: dict[str, Any] | None,
    target_os: str,
    default_provider: str,
) -> dict[str, list[str]]:
    """Resolve logical app names through the catalog.

    Args:
        apps: list of logical app names contributed by the host's groups.
        catalog: the ``package_catalog`` mapping.
        target_os: ``"arch"``, ``"darwin"``, ... matches catalog per-OS keys.
        default_provider: fallback provider for names absent from the catalog.

    Returns:
        ``{provider_name: [concrete_package_names, ...]}`` with each list
        deduped and sorted.
    """
    if apps is None:
        apps = []
    if catalog is None:
        catalog = {}

    if not isinstance(apps, list):
        raise CatalogError(
            f"resolve_catalog: 'apps' must be a list, got {type(apps).__name__}."
        )
    if not isinstance(catalog, dict):
        raise CatalogError(
            f"resolve_catalog: 'catalog' must be a dict, "
            f"got {type(catalog).__name__}."
        )
    if not isinstance(target_os, str) or not target_os:
        raise CatalogError("resolve_catalog: 'target_os' must be a non-empty string.")
    if default_provider not in VALID_PROVIDERS:
        raise CatalogError(
            f"resolve_catalog: invalid default_provider {default_provider!r}. "
            f"Valid providers: {sorted(VALID_PROVIDERS)}."
        )

    buckets: dict[str, list[str]] = {}
    for app in apps:
        if not isinstance(app, str) or not app:
            raise CatalogError(
                f"resolve_catalog: app names must be non-empty strings; got {app!r}."
            )
        _resolve_one(app, catalog, target_os, default_provider, buckets, [])

    return {provider: sorted(set(pkgs)) for provider, pkgs in buckets.items()}


class FilterModule:
    """Expose ``resolve_catalog`` as an ansible jinja filter."""

    def filters(self) -> dict[str, Any]:
        return {"resolve_catalog": resolve_catalog}
