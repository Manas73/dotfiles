"""Package catalog resolver for the ansible packages role.

Resolves a list of logical application names against the per-OS package
catalog. Returns ``{"packages": {provider: [pkg, ...]},
"taps": {provider: [tap, ...]}}``. Package buckets feed
``roles/packages/tasks/<name>.yml`` as ``provider_packages``; tap buckets
feed brew/cask as ``provider_taps``.

Catalog schema (in YAML)::

    # Single-provider per OS (the common case):
    vivaldi:
      arch:   { provider: pacman, packages: [vivaldi, vivaldi-ffmpeg-codecs] }
      darwin: { provider: cask,   packages: [vivaldi] }

    # Third-party Homebrew tap — declare taps explicitly; packages stay
    # unqualified formula/cask names:
    fresh-editor:
      darwin: { provider: brew, packages: [fresh-editor], taps: [sinelaw/fresh] }

    # Multi-provider per OS — the per-OS value is a list of {provider, packages}.
    # Use when one logical name needs packages from different providers on the
    # same OS (e.g. most of python from pacman, but pyrefly from AUR on Arch):
    python:
      arch:
        - { provider: pacman, packages: [python, python-pip, python-poetry] }
        - { provider: aur,    packages: [pyrefly] }
      darwin: { provider: brew, packages: [black, python, uv] }

Rules:

* Each per-OS value is either a single ``{provider, packages}`` mapping or
  a list of such mappings. The list form is for mixed providers on one OS.
* Optional ``taps:`` (list of ``user/repo`` strings) is valid only on
  ``brew`` / ``cask`` blocks. brew.yml / cask.yml tap them before install.
* The catalog is exhaustive: an app whose logical name is not in the
  catalog raises ``CatalogError``. There is no default-provider
  fall-through — every app in os_apps / profiles_catalog[].apps must be listed.
* An app whose catalog entry has no key for ``target_os`` is silently
  dropped: the user explicitly chose not to install it on this OS
  (this is how Linux-only / macOS-only apps are expressed).
* Output buckets are deduplicated and sorted for stable diffs.
"""

from __future__ import annotations

from typing import Any

from ansible.errors import AnsibleFilterError

# Providers must match task files under ``roles/packages/tasks/<name>.yml``.
# Add a new entry here when you add a provider task file + include in main.yml.
# Multilib is intentionally absent: it is a pacman repo, not a separate
# manager, so multilib packages route to ``pacman`` and pacman.yml installs
# them via the same module.
VALID_PROVIDERS = {"pacman", "aur", "brew", "cask"}


class CatalogError(AnsibleFilterError):
    """Raised for any catalog-schema or resolution error."""


# Homebrew taps are only meaningful for brew/cask.
TAP_PROVIDERS = {"brew", "cask"}


def _ingest_taps(
    name: str,
    target_os: str,
    provider: str,
    block: dict[str, Any],
    tap_buckets: dict[str, list[str]],
) -> None:
    taps = block.get("taps")
    if taps is None:
        return
    if provider not in TAP_PROVIDERS:
        raise CatalogError(
            f"Catalog entry '{name}'.{target_os} has 'taps' but provider "
            f"{provider!r} does not support taps (only {sorted(TAP_PROVIDERS)})."
        )
    if not isinstance(taps, list) or not taps:
        raise CatalogError(
            f"Catalog entry '{name}'.{target_os}.taps must be a non-empty list."
        )
    for tap in taps:
        if not isinstance(tap, str) or not tap or "/" not in tap:
            raise CatalogError(
                f"Catalog entry '{name}'.{target_os}.taps must contain "
                f"'user/repo' strings; got {tap!r}."
            )
    tap_buckets.setdefault(provider, []).extend(taps)


def _ingest_provider_block(
    name: str,
    target_os: str,
    block: Any,
    buckets: dict[str, list[str]],
    tap_buckets: dict[str, list[str]],
) -> None:
    if not isinstance(block, dict):
        raise CatalogError(
            f"Catalog entry '{name}'.{target_os} provider block must be a "
            f"mapping, got {type(block).__name__}."
        )

    provider = block.get("provider")
    if provider is None:
        raise CatalogError(
            f"Catalog entry '{name}'.{target_os} missing required 'provider' key."
        )
    if provider not in VALID_PROVIDERS:
        raise CatalogError(
            f"Catalog entry '{name}'.{target_os} has invalid provider "
            f"{provider!r}. Valid providers: {sorted(VALID_PROVIDERS)}."
        )

    packages = block.get("packages")
    if not isinstance(packages, list) or not packages:
        raise CatalogError(
            f"Catalog entry '{name}'.{target_os} must have a non-empty 'packages' list."
        )
    for pkg in packages:
        if not isinstance(pkg, str) or not pkg:
            raise CatalogError(
                f"Catalog entry '{name}'.{target_os}.packages must contain "
                f"non-empty strings; got {pkg!r}."
            )

    buckets.setdefault(provider, []).extend(packages)
    _ingest_taps(name, target_os, provider, block, tap_buckets)


def _resolve_one(
    name: str,
    catalog: dict[str, Any],
    target_os: str,
    default_provider: str,
    buckets: dict[str, list[str]],
    tap_buckets: dict[str, list[str]],
) -> None:
    entry = catalog.get(name)
    if entry is None:
        # The catalog is exhaustive: every logical app referenced by os_apps
        # or profiles_catalog[].apps must have an explicit entry. No implicit
        # fall-through to a default provider. A missing entry is a bug in the
        # catalog (or a typo in the intent lists), so fail loudly.
        raise CatalogError(
            f"resolve_catalog: app {name!r} has no entry in package_catalog. "
            f"Add it to group_vars/all/package_catalog.yml (arch and/or darwin "
            f"blocks). The catalog is exhaustive; there is no default-provider "
            f"fall-through."
        )

    if not isinstance(entry, dict):
        raise CatalogError(
            f"Catalog entry '{name}' must be a mapping, got {type(entry).__name__}."
        )

    os_entry = entry.get(target_os)
    if os_entry is None:
        # App exists cross-OS but isn't packaged for this OS. Silent skip
        # so darwin-only apps don't fail on Arch and vice versa.
        return

    # Per-OS value is either a single provider block (dict) or a list of them.
    blocks = os_entry if isinstance(os_entry, list) else [os_entry]
    if not blocks:
        raise CatalogError(
            f"Catalog entry '{name}'.{target_os} must not be an empty list."
        )
    seen_providers: set[str] = set()
    for block in blocks:
        if isinstance(block, dict):
            provider = block.get("provider")
            if provider in seen_providers:
                raise CatalogError(
                    f"Catalog entry '{name}'.{target_os} lists provider "
                    f"{provider!r} more than once; merge the packages lists."
                )
            if isinstance(provider, str):
                seen_providers.add(provider)
        _ingest_provider_block(name, target_os, block, buckets, tap_buckets)


def resolve_catalog(
    apps: list[str] | None,
    catalog: dict[str, Any] | None,
    target_os: str,
    default_provider: str,
) -> dict[str, dict[str, list[str]]]:
    """Resolve logical app names through the catalog.

    Args:
        apps: list of logical app names contributed by the host's groups.
        catalog: the ``package_catalog`` mapping.
        target_os: ``"arch"``, ``"darwin"``, ... matches catalog per-OS keys.
        default_provider: retained for signature/wiring compatibility and
            still validated, but no longer used for fall-through — the
            catalog is exhaustive and uncatalogued apps raise CatalogError.

    Returns:
        ``{"packages": {provider: [pkg, ...]}, "taps": {provider: [tap, ...]}}``
        with each list deduped and sorted.
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
            f"resolve_catalog: 'catalog' must be a dict, got {type(catalog).__name__}."
        )
    if not isinstance(target_os, str) or not target_os:
        raise CatalogError("resolve_catalog: 'target_os' must be a non-empty string.")
    if default_provider not in VALID_PROVIDERS:
        raise CatalogError(
            f"resolve_catalog: invalid default_provider {default_provider!r}. "
            f"Valid providers: {sorted(VALID_PROVIDERS)}."
        )

    buckets: dict[str, list[str]] = {}
    tap_buckets: dict[str, list[str]] = {}
    for app in apps:
        if not isinstance(app, str) or not app:
            raise CatalogError(
                f"resolve_catalog: app names must be non-empty strings; got {app!r}."
            )
        _resolve_one(app, catalog, target_os, default_provider, buckets, tap_buckets)

    return {
        "packages": {provider: sorted(set(pkgs)) for provider, pkgs in buckets.items()},
        "taps": {provider: sorted(set(taps)) for provider, taps in tap_buckets.items()},
    }


class FilterModule:
    """Expose ``resolve_catalog`` as an ansible jinja filter."""

    def filters(self) -> dict[str, Any]:
        return {"resolve_catalog": resolve_catalog}
