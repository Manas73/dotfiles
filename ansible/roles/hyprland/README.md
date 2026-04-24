# Role: hyprland

Represents Hyprland desktop readiness on a host.

## Responsibilities

- Assert the host is Arch-based.
- Assert the host is in the `hyprland` inventory group.
- Act as the explicit home for future non-package Hyprland work.

## Does Not

- **Install packages.** `arch_packages` and `aur_packages` handle that via the `hyprland_pacman_packages`, `hyprland_aur_packages`, and `hyprland_multilib_packages` group vars (see `inventories/personal/group_vars/hyprland.yml`).
- **Manage Hyprland dotfiles.** `~/.config/hypr/` stays with Chezmoi.
- **Start the Hyprland session.** The display manager or `uwsm` handles that.

## Why This Role Exists

Package installation via group membership and group vars is enough today, but Hyprland may grow non-package needs:

- Systemd user services (hypridle, hyprsunset autostart).
- XDG portal selection.
- `graphical.target` wiring.
- Seat/session integration.

Having a dedicated role keeps those additions discoverable and testable.

## Inputs

Currently none beyond group membership.

## Example

```sh
ansible-playbook -i inventories/personal/hosts.yml playbooks/site.yml \
    --limit alfred --tags desktop,hyprland --ask-become-pass
```
