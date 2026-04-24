# Role: arch_packages

Installs pacman and multilib packages on Arch/Garuda hosts. AUR packages are handled by the `aur_packages` role.

## Responsibilities

- Assert the host is Arch-based (`os_family == "Archlinux"`).
- Refresh pacman databases (`pacman -Sy`), idempotently.
- Optionally perform a full system upgrade (`pacman -Syu`) when `arch_perform_upgrade: true`.
- Install pacman packages via `community.general.pacman`, `--needed`.
- Install multilib packages the same way when present.

## Does Not

- Install AUR packages.
- Manage services.
- Manage dotfiles.

## Inputs

Aggregated from every group a host belongs to:

- `arch_pacman_packages`, `hyprland_pacman_packages`, `i3_pacman_packages`, `gaming_pacman_packages`
- `arch_multilib_packages`, `hyprland_multilib_packages`, `i3_multilib_packages`, `gaming_multilib_packages`

Gaming lists are included only when `gaming_enabled: true`.

Behavior knobs (defaults):

- `arch_refresh_databases: true`
- `arch_perform_upgrade: false`

## Prerequisites

Requires the `community.general` collection:

```sh
ansible-galaxy install -r ansible/requirements.yml
```

## Check Mode

Fully check-mode compatible. Runs in `--check --diff` without side effects.

## Example

```sh
ansible-playbook -i inventories/personal/hosts.yml playbooks/site.yml \
    --limit alfred --tags packages --ask-become-pass
```

Force an upgrade on demand:

```sh
ansible-playbook ... --tags upgrade -e arch_perform_upgrade=true --ask-become-pass
```
