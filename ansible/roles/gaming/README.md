# Role: gaming

Installs optional gaming packages on hosts where `gaming_enabled: true`.

## Responsibilities

- Install gaming packages declared in inventory vars.
- Composes with `arch_packages` and `aur_packages` via inventory vars.
- Only runs on hosts in the `gaming` group with `gaming_enabled: true`.

## Does Not

- Install non-gaming tooling.
- Configure services or dotfiles.

## Inputs

- `gaming_packages`
- `gaming_multilib_packages`
- `gaming_aur_packages`
- `gaming_enabled`

## Implementation Task

Tracked by Beads issue `chezmoi-a2q`.
