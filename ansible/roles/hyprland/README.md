# Role: hyprland

Installs Hyprland ecosystem dependencies on hosts in the `hyprland` group.

## Responsibilities

- Install Hyprland, Waybar, SwayNC, SwayOSD, Hyprlock, Hypridle, Hyprsunset, UWSM, XDG portal, Wayland clipboard tools, CopyQ, AWWW, Matugen, and related packages.
- Composes with `arch_packages` and `aur_packages` via inventory vars.

## Does Not

- Write to `~/.config/hypr`, `~/.config/waybar`, `~/.config/swaync`, `~/.config/swayosd`, or any other dotfiles.

## Inputs

- `hyprland_packages`
- `hyprland_aur_packages`

## Implementation Task

Tracked by Beads issue `chezmoi-c7u`.
