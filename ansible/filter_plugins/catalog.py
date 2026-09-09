"""Package catalog resolver for the ansible packages role.

Resolves a list of logical application names against the per-OS package
catalog. Returns ``{"packages": {provider: [pkg, ...]},
"taps": {provider: [tap, ...]}, "post_install": [action, ...]}``.
Package buckets feed ``roles/packages/tasks/<name>.yml`` as
``provider_packages``; tap buckets feed brew/cask as ``provider_taps``;
``post_install`` feeds ``roles/packages/tasks/post_install.yml`` after
the provider installs.

Catalog schema (in YAML)::

    # Single-provider per OS (the common case):
    vivaldi:
      arch:   { provider: pacman, packages: [vivaldi, vivaldi-ffmpeg-codecs] }
      darwin: { provider: cask,   packages: [vivaldi] }

    # Cross-OS CLI tool via mise. ``all:`` applies on every target OS;
    # an optional arch:/darwin: block is unioned with it (for mixed
    # mise + system packages). mise packages must be ``tool@version``.
    bat:
      all: { provider: mise, packages: ["bat@0.26.1"] }

    # Cross-OS Python CLI via uv. Specs are passed to ``uv tool install``.
    linecast:
      all: { provider: uv, packages: [linecast] }

    python:
      all: { provider: mise, packages: ["python@3.14.7", "uv@0.12.3"] }
      arch:   { provider: pacman, packages: [python, python-gpgme] }
      darwin: { provider: brew,   packages: [python] }

    # Third-party Homebrew tap — declare taps explicitly; packages stay
    # unqualified formula/cask names:
    fresh-editor:
      darwin: { provider: brew, packages: [fresh-editor], taps: [sinelaw/fresh] }

    # Multi-provider per OS — the per-OS value is a list of {provider, packages}.
    # Use when one logical name needs packages from different providers on the
    # same OS (e.g. most of python from pacman, but pyrefly from AUR on Arch):
    python-screeninfo:
      arch: { provider: aur, packages: [python-screeninfo] }

    # Post-install actions (optional, OS-scoped via the block they sit on).
    # Typed actions; each ``action`` value has a task file under
    # roles/packages/tasks/post_install/<action>.yml.
    #   chmod        — set mode on a path (octal "0755" or symbolic "+x")
    #   desktop_exec — rewrite Exec= on a .desktop file
    rambox:
      arch:
        provider: aur
        packages: [rambox-pro-bin]
        post_install:
          - { action: chmod, path: /opt/rambox, mode: "0755" }
          - { action: chmod, path: /opt/rambox/rambox, mode: "+x" }
      darwin: { provider: cask, packages: [rambox] }

Rules:

* Each per-OS value (and ``all:``) is either a single ``{provider, packages}``
  mapping or a list of such mappings. The list form is for mixed providers.
* ``all:`` is applied on every OS, then unioned with the matching
  ``arch:`` / ``darwin:`` / … block. Duplicate providers after that union
  are an error — merge the ``packages:`` lists.
* Optional ``taps:`` (list of ``user/repo`` strings) is valid only on
  ``brew`` / ``cask`` blocks. brew.yml taps them before install.
* Optional ``post_install:`` is a non-empty list of action mappings on a
  provider block. Actions are OS-scoped by which block they sit on
  (put Linux-only tweaks on ``arch:``, not ``all:``). See
  ``VALID_POST_INSTALL_ACTIONS``.
* ``provider: mise`` packages must be pinned ``tool@version`` specs
  (``bat@0.26.1``, ``ubi:owner/repo[exe=bd]@1.2.3``). Bare names and
  ``@latest`` are rejected.
* ``provider: uv`` packages are PEP 508 specs passed to
  ``uv tool install`` (``linecast``, ``linecast==1.2.3``). Bare names
  are allowed.
* The catalog is exhaustive: an app whose logical name is not in the
  catalog raises ``CatalogError``. There is no default-provider
  fall-through — every app in os_apps / profiles_catalog[].apps must be listed.
* An app whose catalog entry has neither ``all:`` nor a key for
  ``target_os`` is silently dropped: the user explicitly chose not to
  install it on this OS (Linux-only / macOS-only apps).
* Output package/tap buckets are deduplicated and sorted for stable diffs.
  ``post_install`` preserves catalog order (then app-intent order) and
  drops exact duplicate action dicts.
"""

from __future__ import annotations

from typing import Any

from ansible.errors import AnsibleFilterError

# Providers must match task files under ``roles/packages/tasks/<name>.yml``.
# Add a new entry here when you add a provider task file + include in main.yml.
# Multilib is intentionally absent: it is a pacman repo, not a separate
# manager, so multilib packages route to ``pacman`` and pacman.yml installs
# them via the same module.
VALID_PROVIDERS = {"pacman", "aur", "brew", "cask", "mise", "uv"}

# Post-install action types must match task files under
# ``roles/packages/tasks/post_install/<action>.yml``. Add a validator
# branch in ``_normalize_post_install_action`` when adding a type.
VALID_POST_INSTALL_ACTIONS = {"chmod", "desktop_exec"}

# Cross-OS key unioned with the per-OS block. Not a target_os value.
ALL_OS_KEY = "all"

# mise CLI treats these as unpinned; the catalog requires a concrete version.
UNPINNED_MISE_VERSIONS = {""}


class CatalogError(AnsibleFilterError):
    """Raised for any catalog-schema or resolution error."""


# Homebrew taps are only meaningful for brew/cask.
TAP_PROVIDERS = {"brew", "cask"}

# Keys allowed on each post_install action type (plus the shared ``action``).
_CHMOD_KEYS = {"action", "path", "mode", "optional"}
_DESKTOP_EXEC_KEYS = {"action", "path", "exec", "optional", "section"}
_POST_INSTALL_KEYS = {
    "chmod": _CHMOD_KEYS,
    "desktop_exec": _DESKTOP_EXEC_KEYS,
}


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


def _normalize_post_install_action(
    name: str,
    target_os: str,
    action: Any,
) -> dict[str, Any]:
    """Validate one post_install mapping and return a normalized dict."""
    loc = f"Catalog entry '{name}'.{target_os}.post_install"
    if not isinstance(action, dict):
        raise CatalogError(
            f"{loc} items must be mappings, got {type(action).__name__}."
        )

    kind = action.get("action")
    if kind not in VALID_POST_INSTALL_ACTIONS:
        raise CatalogError(
            f"{loc} has invalid action {kind!r}. "
            f"Valid actions: {sorted(VALID_POST_INSTALL_ACTIONS)}."
        )

    unknown = set(action) - _POST_INSTALL_KEYS[kind]
    if unknown:
        raise CatalogError(
            f"{loc} action {kind!r} has unknown keys {sorted(unknown)}. "
            f"Allowed: {sorted(_POST_INSTALL_KEYS[kind])}."
        )

    if kind == "chmod":
        return _normalize_chmod(loc, name, action)
    if kind == "desktop_exec":
        return _normalize_desktop_exec(loc, name, action)

    raise CatalogError(f"{loc} action {kind!r} has no normalizer.")


def _optional_bool(loc: str, action: dict[str, Any], kind: str) -> bool:
    optional = action.get("optional", False)
    if not isinstance(optional, bool):
        raise CatalogError(
            f"{loc} {kind} 'optional' must be a bool, "
            f"got {type(optional).__name__}."
        )
    return optional


def _normalize_chmod(
    loc: str,
    name: str,
    action: dict[str, Any],
) -> dict[str, Any]:
    path = action.get("path")
    if not isinstance(path, str) or not path:
        raise CatalogError(
            f"{loc} chmod requires a non-empty string 'path'."
        )

    mode = action.get("mode")
    if isinstance(mode, int):
        raise CatalogError(
            f"{loc} chmod 'mode' must be a string (quote octal values, "
            f"e.g. \"0755\" or \"+x\"); got integer {mode}."
        )
    if not isinstance(mode, str) or not mode:
        raise CatalogError(
            f"{loc} chmod requires a non-empty string 'mode' "
            f"(octal like \"0755\" or symbolic like \"+x\")."
        )
    if any(ch.isspace() for ch in mode):
        raise CatalogError(
            f"{loc} chmod 'mode' must not contain whitespace; got {mode!r}."
        )

    return {
        "app": name,
        "action": "chmod",
        "path": path,
        "mode": mode,
        "optional": _optional_bool(loc, action, "chmod"),
    }


def _normalize_desktop_exec(
    loc: str,
    name: str,
    action: dict[str, Any],
) -> dict[str, Any]:
    path = action.get("path")
    if not isinstance(path, str) or not path:
        raise CatalogError(
            f"{loc} desktop_exec requires a non-empty string 'path'."
        )
    if not path.endswith(".desktop"):
        raise CatalogError(
            f"{loc} desktop_exec path must end with '.desktop'; got {path!r}."
        )

    exec_value = action.get("exec")
    if not isinstance(exec_value, str) or not exec_value:
        raise CatalogError(
            f"{loc} desktop_exec requires a non-empty string 'exec'."
        )
    if exec_value.startswith("Exec="):
        raise CatalogError(
            f"{loc} desktop_exec 'exec' is the Exec value, not the whole "
            f"key line; omit the 'Exec=' prefix (got {exec_value!r})."
        )
    if "\n" in exec_value:
        raise CatalogError(
            f"{loc} desktop_exec 'exec' must be a single line."
        )

    section = action.get("section", "Desktop Entry")
    if not isinstance(section, str) or not section:
        raise CatalogError(
            f"{loc} desktop_exec 'section' must be a non-empty string."
        )

    return {
        "app": name,
        "action": "desktop_exec",
        "path": path,
        "exec": exec_value,
        "optional": _optional_bool(loc, action, "desktop_exec"),
        "section": section,
    }


def _ingest_post_install(
    name: str,
    target_os: str,
    block: dict[str, Any],
    post_install: list[dict[str, Any]],
) -> None:
    actions = block.get("post_install")
    if actions is None:
        return
    if not isinstance(actions, list) or not actions:
        raise CatalogError(
            f"Catalog entry '{name}'.{target_os}.post_install must be a "
            f"non-empty list."
        )
    for action in actions:
        post_install.append(
            _normalize_post_install_action(name, target_os, action)
        )


def _ingest_provider_block(
    name: str,
    target_os: str,
    block: Any,
    buckets: dict[str, list[str]],
    tap_buckets: dict[str, list[str]],
    post_install: list[dict[str, Any]],
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
        if provider == "mise":
            _validate_mise_spec(name, target_os, pkg)

    buckets.setdefault(provider, []).extend(packages)
    _ingest_taps(name, target_os, provider, block, tap_buckets)
    _ingest_post_install(name, target_os, block, post_install)


def _validate_mise_spec(name: str, target_os: str, spec: str) -> None:
    """Require a pinned ``tool@version`` spec for the mise provider."""
    if "@" not in spec:
        raise CatalogError(
            f"Catalog entry '{name}'.{target_os} mise package {spec!r} must "
            f"be pinned as 'tool@version' (e.g. 'bat@0.26.1')."
        )
    tool, version = spec.rsplit("@", 1)
    if not tool or not version:
        raise CatalogError(
            f"Catalog entry '{name}'.{target_os} mise package {spec!r} must "
            f"be pinned as 'tool@version'; tool and version must be non-empty."
        )
    if version.lower() in UNPINNED_MISE_VERSIONS:
        raise CatalogError(
            f"Catalog entry '{name}'.{target_os} mise package {spec!r} must "
            f"pin a concrete version, not {version!r}."
        )


def _blocks_from_entry(name: str, key: str, value: Any) -> list[Any]:
    """Normalize a catalog value (``all`` or per-OS) into a non-empty block list."""
    blocks = value if isinstance(value, list) else [value]
    if not blocks:
        raise CatalogError(
            f"Catalog entry '{name}'.{key} must not be an empty list."
        )
    return blocks


def _resolve_one(
    name: str,
    catalog: dict[str, Any],
    target_os: str,
    default_provider: str,
    buckets: dict[str, list[str]],
    tap_buckets: dict[str, list[str]],
    post_install: list[dict[str, Any]],
) -> None:
    entry = catalog.get(name)
    if entry is None:
        # The catalog is exhaustive: every logical app referenced by os_apps
        # or profiles_catalog[].apps must have an explicit entry. No implicit
        # fall-through to a default provider. A missing entry is a bug in the
        # catalog (or a typo in the intent lists), so fail loudly.
        raise CatalogError(
            f"resolve_catalog: app {name!r} has no entry in package_catalog. "
            f"Add it to group_vars/all/package_catalog.yml (all: and/or "
            f"arch/darwin blocks). The catalog is exhaustive; there is no "
            f"default-provider fall-through."
        )

    if not isinstance(entry, dict):
        raise CatalogError(
            f"Catalog entry '{name}' must be a mapping, got {type(entry).__name__}."
        )

    # ``all:`` applies on every OS; the per-OS key is unioned with it so a
    # CLI tool can be mise everywhere while still installing a system package
    # on one OS (e.g. python via mise + python-gpgme via pacman).
    all_entry = entry.get(ALL_OS_KEY)
    os_entry = entry.get(target_os)
    blocks: list[Any] = []
    if all_entry is not None:
        blocks.extend(_blocks_from_entry(name, ALL_OS_KEY, all_entry))
    if os_entry is not None:
        blocks.extend(_blocks_from_entry(name, target_os, os_entry))
    if not blocks:
        # App exists but has neither all: nor a key for this OS. Silent skip
        # so darwin-only apps don't fail on Arch and vice versa.
        return

    seen_providers: set[str] = set()
    for block in blocks:
        if isinstance(block, dict):
            provider = block.get("provider")
            if provider in seen_providers:
                raise CatalogError(
                    f"Catalog entry '{name}' lists provider {provider!r} "
                    f"more than once for {target_os} (after unioning "
                    f"'{ALL_OS_KEY}' with '{target_os}'); merge the "
                    f"packages lists."
                )
            if isinstance(provider, str):
                seen_providers.add(provider)
        # Label errors with the OS being resolved, even for all: blocks.
        _ingest_provider_block(
            name, target_os, block, buckets, tap_buckets, post_install
        )


def resolve_catalog(
    apps: list[str] | None,
    catalog: dict[str, Any] | None,
    target_os: str,
    default_provider: str,
) -> dict[str, Any]:
    """Resolve logical app names through the catalog.

    Args:
        apps: list of logical app names contributed by the host's groups.
        catalog: the ``package_catalog`` mapping.
        target_os: ``"arch"``, ``"darwin"``, ... matches catalog per-OS keys.
        default_provider: retained for signature/wiring compatibility and
            still validated, but no longer used for fall-through — the
            catalog is exhaustive and uncatalogued apps raise CatalogError.

    Returns:
        ``{"packages": {provider: [pkg, ...]}, "taps": {provider: [tap, ...]},
        "post_install": [action, ...]}`` with package/tap lists deduped and
        sorted. ``post_install`` preserves catalog order and drops exact
        duplicate action dicts.
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
    post_install: list[dict[str, Any]] = []
    for app in apps:
        if not isinstance(app, str) or not app:
            raise CatalogError(
                f"resolve_catalog: app names must be non-empty strings; got {app!r}."
            )
        _resolve_one(
            app,
            catalog,
            target_os,
            default_provider,
            buckets,
            tap_buckets,
            post_install,
        )

    deduped_post_install: list[dict[str, Any]] = []
    for action in post_install:
        if action not in deduped_post_install:
            deduped_post_install.append(action)

    return {
        "packages": {provider: sorted(set(pkgs)) for provider, pkgs in buckets.items()},
        "taps": {provider: sorted(set(taps)) for provider, taps in tap_buckets.items()},
        "post_install": deduped_post_install,
    }


class FilterModule:
    """Expose ``resolve_catalog`` as an ansible jinja filter."""

    def filters(self) -> dict[str, Any]:
        return {"resolve_catalog": resolve_catalog}
