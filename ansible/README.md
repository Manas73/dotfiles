# Ansible

This directory contains the Ansible provisioning layer that manages OS packages, services, groups, and Chezmoi configuration on each machine.

See `docs/ANSIBLE_MIGRATION_PLAN.md` for the long-term plan.

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
├── requirements.yml
├── inventories/
│   └── personal/
│       ├── hosts.yml
│       ├── group_vars/
│       └── host_vars/
├── playbooks/
│   ├── site.yml
│   ├── packages.yml
│   ├── dotfiles.yml
│   ├── desktop.yml
│   └── system.yml
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
    ├── i3/
    ├── development/
    └── gaming/
```

## Status

This is a skeleton. Roles are intentionally empty until later Beads tasks implement them:

- `chezmoi-g19`: Chezmoi role implementation.
- `chezmoi-fwb`: Package variable migration.
- `chezmoi-a2q`: Arch/AUR package roles.
- `chezmoi-7tw`: macOS Homebrew role.
- `chezmoi-hoz`: System setup roles.
- `chezmoi-c7u`: Desktop profile roles.

## Usage

Once roles are implemented, typical commands will be:

```sh
ansible-playbook -i ansible/inventories/personal/hosts.yml ansible/playbooks/site.yml --limit alfred --ask-become-pass
ansible-playbook -i ansible/inventories/personal/hosts.yml ansible/playbooks/packages.yml --limit alfred --ask-become-pass
ansible-playbook -i ansible/inventories/personal/hosts.yml ansible/playbooks/dotfiles.yml --limit alfred
```

Syntax-check everything:

```sh
ansible-playbook -i ansible/inventories/personal/hosts.yml ansible/playbooks/site.yml --syntax-check
```
