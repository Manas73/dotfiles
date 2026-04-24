# Ansible

Provisioning layer for OS packages, services, groups, and Chezmoi configuration.

See `docs/ANSIBLE_MIGRATION_PLAN.md` for the long-term plan and `docs/ONBOARDING.md` for adding a new machine.

## Scope

Ansible owns:

- OS/package installation (pacman, yay, Homebrew).
- User groups, udev rules, and systemd user services.
- Fish login shell switching.
- Docker, Kanata, and Plasma custom-WM setup.
- Rendering `~/.config/chezmoi/chezmoi.toml` from inventory vars.
- Running `chezmoi apply` non-interactively.

Ansible does not own:

- The contents of `~/.config/*` dotfiles (Chezmoi owns these).
- `~/.gitconfig`, `~/.ssh/*`, Fish functions, Hyprland/i3 configs.

## Layout

```text
ansible/
├── ansible.cfg
├── inventories/
│   └── personal/
│       ├── hosts.yml
│       ├── group_vars/
│       │   ├── all.yml
│       │   ├── linux.yml
│       │   ├── darwin.yml
│       │   ├── arch.yml
│       │   ├── hyprland.yml
│       │   ├── i3.yml
│       │   └── gaming.yml
│       └── host_vars/
│           └── alfred.yml
├── playbooks/
│   ├── site.yml
│   └── dotfiles.yml
└── roles/
    ├── chezmoi/
    ├── arch_packages/
    ├── aur_packages/
    ├── darwin_packages/
    ├── fish/
    ├── docker/
    ├── kanata/
    ├── plasma_custom_wm/
    ├── hyprland/
    └── i3/
```

## Status

Progress:

- `chezmoi-g19` ✓ chezmoi role renders `~/.config/chezmoi/chezmoi.toml` and runs `chezmoi apply`.
- `chezmoi-fwb` ✓ package data migrated into group vars.
- `chezmoi-a2q` ✓ arch_packages, aur_packages.
- `chezmoi-c7u` ✓ hyprland, i3 desktop profile roles.
- `chezmoi-7tw` darwin_packages.
- `chezmoi-hoz` fish, docker, kanata, plasma_custom_wm.

## Package Vars

Package roles (pending) consume these group vars, concatenated across every group a host belongs to:

| Group | Vars |
|---|---|
| `arch` | `arch_pacman_packages`, `arch_aur_packages`, `arch_multilib_packages` |
| `hyprland` | `hyprland_pacman_packages`, `hyprland_aur_packages`, `hyprland_multilib_packages` |
| `i3` | `i3_pacman_packages`, `i3_aur_packages`, `i3_multilib_packages` |
| `gaming` | `gaming_pacman_packages`, `gaming_aur_packages`, `gaming_multilib_packages` |
| `darwin` | `darwin_brews`, `darwin_casks` |

Gaming packages install only when `gaming_enabled: true` (set per host).

## Usage

```sh
cd ansible
ansible-playbook -i inventories/personal/hosts.yml playbooks/site.yml --limit alfred --ask-become-pass
ansible-playbook -i inventories/personal/hosts.yml playbooks/dotfiles.yml --limit alfred
```

Syntax check:

```sh
ansible-playbook -i inventories/personal/hosts.yml playbooks/site.yml --syntax-check
ansible-playbook -i inventories/personal/hosts.yml playbooks/dotfiles.yml --syntax-check
```

Add more groups or roles only when they gate real behavior.
