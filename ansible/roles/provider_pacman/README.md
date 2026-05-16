# Role: provider_pacman

Layer 4 provider for pacman (Arch/Garuda). Installs packages from the
official and multilib repos via `community.general.pacman`. Invoked by
the `packages` orchestrator with a resolved list of concrete pacman
package names; does no catalog resolution or intent aggregation itself.

## Liskov contract (uniform across providers)

- **Input**: `provider_packages` (list[str]) — concrete pacman package names.
- **Empty input**: install task no-ops via `when: length > 0`.
- **Asserts**: host `os_family == "Archlinux"`.
- **Idempotent**: `state: present` (= `--needed` semantics).
- **Self-bootstraps**: pacman is part of the base system; just verifies it
  exists.
- **Side effects**: only package installation.

## Multilib

Multilib is a pacman *repo*, not a separate manager. Catalog entries that
were historically "multilib" (e.g. `steam`) route to `provider: pacman`
and this role installs them via the same module. The `multilib` repo
must be enabled in `/etc/pacman.conf`.

## Inputs / knobs

- `provider_packages` (required) — set by the orchestrator.
- `provider_pacman_refresh_databases: true` — runs `pacman -Sy` first.
- `provider_pacman_perform_upgrade: false` — runs full `pacman -Syu`. Off by
  default; partial upgrades are unsafe on Arch.

## Tags

`packages`, `pacman`, `arch`, plus `upgrade` for the upgrade task.
