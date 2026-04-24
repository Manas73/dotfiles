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

Skeleton only. Role bodies arrive in later Beads tasks:

- `chezmoi-g19` chezmoi
- `chezmoi-fwb` populate group vars with package lists
- `chezmoi-a2q` arch_packages, aur_packages
- `chezmoi-7tw` darwin_packages
- `chezmoi-hoz` fish, docker, kanata, plasma_custom_wm
- `chezmoi-c7u` hyprland, i3

Running `site.yml` today is a no-op on purpose.

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
