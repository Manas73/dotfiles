# Role: packages (orchestrator)

Cross-OS package installation orchestrator. Layer 3 of the four-layer package
model.

## Architecture

```
Layer 1: Intent       <group>_apps   (lists of logical names per group)
Layer 2: Catalog      group_vars/all/package_catalog.yml
Layer 3: Dispatcher   THIS ROLE
Layer 4: Providers    roles/provider_pacman, _aur, _brew, _cask
```

## Responsibilities

1. Compute `packages_target_os` and `packages_default_provider` from
   `ansible_facts['os_family']`.
2. Aggregate `<group>_apps` lists across every inventory group the host
   actually belongs to (`linux`, `arch`, `darwin`, `hyprland`, `i3`,
   `gaming`). Membership is checked via `group_names`, not var presence.
3. Resolve the logical names through the catalog (`resolve_catalog` filter
   plugin from `ansible/filter_plugins/catalog.py`).
4. Dispatch to provider roles dynamically via `include_role` over
   `dict2items(packages_resolved)`. Each provider receives its bucket as
   `provider_packages`.

## Does Not

- Install anything itself (providers do that).
- Manage configuration, services, or dotfiles.
- Bootstrap package managers (providers self-bootstrap).

## Inputs

- `package_catalog` (from `group_vars/all/package_catalog.yml`).
- `<group>_apps` lists from any of the supported group_vars files.
- `gaming_enabled` (gates the gaming bucket).

## Outputs (set_fact)

- `packages_target_os`: `"arch"` or `"darwin"`.
- `packages_default_provider`: `"pacman"` or `"brew"`.
- `packages_logical_apps`: the aggregated logical-name list.
- `packages_resolved`: `{provider: [package, ...]}`.

## Tag map

Each provider role tags its own tasks (`pacman`, `aur`, `brew`, `cask`).
Common tags: `packages`, plus `arch` or `darwin` as applicable.

Run examples:

```sh
ansible-playbook ... --tags packages           # everything
ansible-playbook ... --tags aur                # just AUR
ansible-playbook ... --tags pacman             # just pacman
```

## Adding a new provider

True Open/Closed: drop in a new `roles/provider_flatpak/`, add `flatpak`
to `VALID_PROVIDERS` in `filter_plugins/catalog.py`, and add
`provider: flatpak` entries to the catalog. No edits to this role.
