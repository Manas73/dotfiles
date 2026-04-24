# Role: i3

Represents i3 desktop readiness on a host.

## Responsibilities

- Assert the host is Arch-based.
- Assert the host is in the `i3` inventory group.
- Act as the explicit home for future non-package i3 work.

## Does Not

- **Install packages.** `arch_packages` and `aur_packages` handle that via the `i3_pacman_packages`, `i3_aur_packages`, and `i3_multilib_packages` group vars (see `inventories/personal/group_vars/i3.yml`).
- **Manage i3 dotfiles.** `~/.config/i3/`, `~/.config/picom/`, and `~/.config/polybar/` stay with Chezmoi.
- **Start the i3 session.** The display manager or `startx` handles that.

## Why This Role Exists

Package installation via group membership is enough today, but i3 may grow non-package needs:

- Systemd user services for background helpers.
- Picom service enablement.
- `graphical.target` wiring.

Having a dedicated role keeps those additions discoverable and testable.

## Inputs

Currently none beyond group membership.

## Example

```sh
ansible-playbook -i inventories/personal/hosts.yml playbooks/site.yml \
    --limit alfred --tags desktop,i3 --ask-become-pass
```
