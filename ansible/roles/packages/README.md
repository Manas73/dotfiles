# Role: packages

Cross-OS package installation. Resolves logical app names through the catalog
and installs via provider task files.

## Architecture

```
Intent       os_apps + profile_apps (via recipe profiles:)
Catalog      group_vars/all/package_catalog.yml
Resolve      THIS ROLE (resolve_catalog filter)
Providers    tasks/{pacman,aur,brew,cask}.yml
```

## Responsibilities

1. Map `ansible_facts.os_family` → `packages_target_os` / default provider
   via `os_family_map` (`group_vars/all/os_providers.yml`).
2. Aggregate `os_apps` + recipe `profiles` → `profile_apps`.
3. Resolve through the catalog into per-provider buckets.
4. Include the matching provider task file for each non-empty bucket
   (fixed order: pacman → aur → brew → cask).

## Does not

- Manage configuration, services, or dotfiles.
- Own package *lists* (`group_vars/<os>/apps.yml` and recipes).

## Inputs

- `package_catalog` — from `group_vars/all/package_catalog.yml`
- `os_apps` — OS-family intent list (same var name on every OS group)
- `profiles` + `profile_apps` — recipe profile opt-in (recipe loaded by playbook)
- `os_family_map` — from `group_vars/all/os_providers.yml`
- Provider defaults in `defaults/main.yml`

## Outputs (set_fact)

- `packages_target_os`, `packages_default_provider`
- `packages_logical_apps`, `packages_resolved`
