# My Dotfiles

This repository holds the dotfiles and machine provisioning setup for my personal systems.

Two layers, one repo:

- **Chezmoi** manages user dotfiles under `$HOME`.
- **Ansible** manages OS packages, services, groups, udev rules, and renders `~/.config/chezmoi/chezmoi.toml`.

`chezmoi apply` never installs packages, switches your shell, or writes to `/etc`. Provisioning happens through Ansible.

See `docs/ANSIBLE_MIGRATION_PLAN.md` for architecture and `docs/ONBOARDING.md` for adding a new machine.

## Requirements

- `git`
- `age` (1.2.0+)
- `chezmoi` (2.52.2+)
- `ansible-core` (2.15+) and the `community.general` collection for full machine provisioning

## Full Provisioning (New Machine)

```sh
# Clone the repo into the Chezmoi source path.
git clone https://github.com/Manas73/dotfiles.git ~/.local/share/chezmoi

# Install the required Ansible collection.
ansible-galaxy install -r ~/.local/share/chezmoi/ansible/requirements.yml

# Run the full site playbook against this host.
cd ~/.local/share/chezmoi/ansible
ansible-playbook -i inventories/personal/hosts.yml playbooks/site.yml \
    --limit "$(hostname)" --ask-become-pass
```

The site playbook installs packages, applies dotfiles via Chezmoi, and configures system services (Fish login shell, Docker, Kanata, Plasma custom WM).

Log out and back in afterwards so group membership changes (docker, input, uinput) take effect.

## Dotfiles Only

If you just want dotfiles applied on an already-provisioned machine, or the target is a machine that is not yet modeled in Ansible inventory, use Chezmoi directly:

```sh
chezmoi init --apply https://github.com/Manas73/dotfiles.git
```

Chezmoi will prompt for commit email, profile, WM choices, and GPU vendor. On a machine that is already in Ansible inventory, `ansible-playbook playbooks/dotfiles.yml --limit <host>` is the non-interactive alternative.

## Repo Layout

```text
.
├── dot_*/                   source files for Chezmoi
├── key.txt.age              encrypted age identity
├── .chezmoi.toml.tmpl       manual-fallback Chezmoi config
├── .chezmoiignore           repo-only paths Chezmoi must skip
├── .chezmoiscripts/         Chezmoi-specific scripts (age decrypt only)
├── ansible/                 provisioning (inventories, playbooks, roles)
└── docs/                    plan and onboarding docs
```

## Troubleshooting

### Ansible locale warning

If `ansible --version` complains about `ISO-8859-1`, set a UTF-8 locale before running:

```sh
export LC_ALL=C.UTF-8 LANG=C.UTF-8
```

### Chezmoi cannot find age identity

On the very first run, the Chezmoi source repo contains `key.txt.age` (passphrase-encrypted). The `chezmoi` role decrypts it once using `chezmoi age decrypt --passphrase`; it will prompt interactively. After that, `~/.config/chezmoi/key.txt` persists and subsequent runs are non-interactive.
