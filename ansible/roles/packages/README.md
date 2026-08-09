# Role: packages

Cross-OS package installation. Resolves logical app names through the catalog
and installs via provider task files.

## Architecture

```
Intent       <group>_apps / profile_apps   (logical names)
Catalog      group_vars/all/package_catalog.yml
Resolve      THIS ROLE (resolve_catalog filter)
Providers    tasks/{pacman,aur,brew,cask}.yml
```

## Responsibilities

1. Compute `packages_target_os` and `packages_default_provider` from facts.
2. Aggregate OS-family apps + profile apps for the host.
3. Resolve through the catalog into per-provider buckets.
4. Include the matching provider task file for each non-empty bucket
   (fixed order: pacman → aur → brew → cask).

## Does not

- Manage configuration, services, or dotfiles.
- Own package *lists* (those live in group_vars).

## Inputs

- `package_catalog` — from `group_vars/all/package_catalog.yml`
- `arch_apps` / `darwin_apps` — OS-family intent lists
- `profiles` + `profile_apps` — host profile opt-in
- Provider defaults in `defaults/main.yml` (`packages_pacman_*`,
  `packages_aur_*`, `packages_brew_*`)

## Outputs (set_fact)

- `packages_target_os`, `packages_default_provider`
- `packages_logical_apps`, `packages_resolved`

## Tags

| Tag | Scope |
|-----|--------|
| `packages` | Whole role |
| `pacman` / `aur` / `brew` / `cask` | Single provider file |
| `arch` / `darwin` | OS package work |
| `upgrade` | `pacman -Syu` only |

```sh
ansible-playbook ... --tags packages
ansible-playbook ... --tags aur
```

## Adding a new provider

1. Add `roles/packages/tasks/<name>.yml` (accept `provider_packages`).
2. Wire an `include_tasks` block in `tasks/main.yml` in the right order.
3. Add `"<name>"` to `VALID_PROVIDERS` in `filter_plugins/catalog.py`.
4. Add `provider: <name>` catalog entries as needed.
