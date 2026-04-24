# Role: arch_packages

Installs native pacman packages on Arch/Garuda hosts.

## Responsibilities

- Install Arch core/extra/multilib packages declared in inventory vars.
- Use `community.general.pacman` where practical.
- Remain idempotent.

## Does Not

- Install AUR packages (owned by `aur_packages`).
- Install macOS packages.
- Configure services or dotfiles.

## Inputs

- `arch_core_packages`
- `arch_extra_packages`
- `arch_multilib_packages`

## Implementation Task

Tracked by Beads issue `chezmoi-a2q`.
