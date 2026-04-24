# Role: aur_packages

Installs AUR packages on Arch/Garuda hosts via `yay`.

## Responsibilities

- Ensure `yay` is available.
- Install AUR packages declared in inventory vars.
- Remain idempotent.

## Does Not

- Install pacman packages (owned by `arch_packages`).
- Install macOS packages.
- Configure services or dotfiles.

## Inputs

- `arch_aur_packages`
- `development_aur_packages`
- `hyprland_aur_packages`
- `i3_aur_packages`
- `gaming_aur_packages`

## Implementation Task

Tracked by Beads issue `chezmoi-a2q`.
