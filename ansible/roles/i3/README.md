# Role: i3

Installs i3 ecosystem dependencies on hosts in the `i3` group.

## Responsibilities

- Install i3-wm, Picom, Polybar, sxhkd, feh, and Rofi plugins.
- Composes with `arch_packages` and `aur_packages` via inventory vars.

## Does Not

- Write to `~/.config/i3`, `~/.config/picom`, `~/.config/polybar`, or any other dotfiles.

## Inputs

- `i3_packages`
- `i3_aur_packages`

## Implementation Task

Tracked by Beads issue `chezmoi-c7u`.
