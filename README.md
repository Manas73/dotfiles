# My Dotfiles

This repository holds the dotfiles and machine-provisioning setup for my personal systems.

Two layers, one repo:

- **Chezmoi** manages user dotfiles under `$HOME`.
- **Ansible** manages OS packages, services, groups, udev rules, and renders `~/.config/chezmoi/chezmoi.toml`.

`chezmoi apply` never installs packages, switches your shell, or writes to `/etc`. Provisioning happens through Ansible.

See `docs/ANSIBLE_MIGRATION_PLAN.md` for architecture and `docs/ONBOARDING.md` for adding a new machine.

> macOS bootstrap documentation is pending: tracked by Beads issue `chezmoi-qxl`, which is blocked on `chezmoi-7tw` (Homebrew role implementation) until a MacBook exists.

## Requirements

- `git`
- `age` (1.2.0+)
- `chezmoi` (2.52.2+)
- `ansible-core` (2.15+) for full machine provisioning
- `community.general` Ansible collection (installed in the bootstrap step below)
- SSH access to `github.com` (HTTPS is no longer wired up; see Authentication below)

## Authentication

Clones and pushes go through SSH. `~/.ssh/config` defines two host aliases:

- `github.com-personal` → `~/.ssh/github-personal` (personal account)
- `github.com-turing` → `~/.ssh/github-turing` (work account, if relevant)

Repo origins use those aliases, e.g.:

```text
git@github.com-personal/Manas73/dotfiles.git
```

You need the matching SSH keys on the machine and their public keys registered on the correct GitHub account. If an org enforces SAML SSO (Turing orgs do), authorize the key per-org at `https://github.com/settings/keys` after adding it.

## Full Provisioning (New Machine)

```sh
# Clone the repo into the Chezmoi source path.
git clone git@github.com/Manas73/dotfiles.git ~/.local/share/chezmoi

# Install the required Ansible collection.
cd ~/.local/share/chezmoi
ansible-galaxy install -r ansible/requirements.yml

# Run the full site playbook against this host.
cd ansible
ansible-playbook -i inventories/personal/hosts.yml playbooks/site.yml \
    --limit "$(hostname)" --ask-become-pass
```

The site playbook:

1. Installs pacman, multilib, and AUR packages (bootstraps `yay` if missing).
2. Renders `~/.config/chezmoi/chezmoi.toml` from inventory vars and runs `chezmoi apply`.
3. Applies system setup: Fish login shell, Docker group/socket, Kanata udev + user service, Plasma custom-WM wiring.
4. Composes the Hyprland and i3 desktop profile hooks for hosts in those groups.

Notes:

- `--ask-become-pass` prompts once for the sudo password; needed for pacman, group setup, udev rules, and systemd unit masking.
- First run prompts once for the age passphrase to decrypt the Chezmoi identity (see Troubleshooting).
- Log out and back in afterwards so new group memberships (`docker`, `input`, `uinput`) take effect.

## Dotfiles Only

On a machine already provisioned (or one you don't plan to fully provision), apply just the dotfiles:

```sh
cd ~/.local/share/chezmoi/ansible
ansible-playbook -i inventories/personal/hosts.yml playbooks/dotfiles.yml \
    --limit "$(hostname)"
```

Or, if the host isn't in Ansible inventory yet:

```sh
chezmoi init --apply git@github.com-personal:Manas73/dotfiles.git
```

Chezmoi will prompt for commit email, profile, WM choices, and GPU vendor (these prompts are a manual fallback; Ansible fills them in automatically on inventory-managed hosts).

## Tags (Operational Slicing)

`site.yml` supports tags for targeted runs:

| Tag | What runs |
|---|---|
| `packages` | pacman + multilib via `arch_packages` |
| `aur` | AUR via `aur_packages` |
| `dotfiles` | `chezmoi` role only |
| `system` | fish, docker, kanata, plasma_custom_wm (gated by host feature flags) |
| `desktop` | hyprland and i3 profile hooks |
| `upgrade` | `pacman -Syu` (only when you explicitly want a full upgrade) |

Examples:

```sh
# Just install packages, no dotfiles or system setup.
ansible-playbook ... playbooks/site.yml --tags packages --ask-become-pass

# Just re-apply dotfiles.
ansible-playbook ... playbooks/dotfiles.yml
```

## Validation

Run these before committing non-trivial Ansible or Chezmoi changes.

```sh
# UTF-8 locale is required by Ansible on this machine.
export LC_ALL=C.UTF-8 LANG=C.UTF-8

cd ~/.local/share/chezmoi/ansible

# Playbook syntax.
ansible-playbook -i inventories/personal/hosts.yml playbooks/site.yml --syntax-check
ansible-playbook -i inventories/personal/hosts.yml playbooks/dotfiles.yml --syntax-check

# Inventory resolves as expected (hosts, groups, merged vars).
ansible-inventory -i inventories/personal/hosts.yml --graph
ansible-inventory -i inventories/personal/hosts.yml --host "$(hostname)"

# Dry-run. Skips sudo-gated tasks if --ask-become-pass is omitted, which is
# useful for quickly exercising the playbook structure.
ansible-playbook -i inventories/personal/hosts.yml playbooks/site.yml \
    --limit "$(hostname)" --check --diff

# Chezmoi side.
chezmoi diff                                    # pending dotfile changes
chezmoi managed | grep -E '^(ansible|docs|bootstrap)/' && echo FAIL \
    || echo "chezmoi boundary ok"
```

`chezmoi managed` returning any line under `ansible/`, `docs/`, or `bootstrap/` means `.chezmoiignore` is broken and repo-only files would be deployed into `$HOME`.

## Repo Layout

```text
.
├── dot_*/                   source files for Chezmoi
├── key.txt.age              encrypted age identity (first-run bootstrap)
├── .chezmoi.toml.tmpl       manual-fallback Chezmoi config
├── .chezmoiignore           repo-only paths Chezmoi must skip
├── .chezmoiscripts/         Chezmoi-specific scripts (age decrypt only)
├── ansible/                 provisioning (inventories, playbooks, roles)
└── docs/                    architecture plan and onboarding docs
```

## Troubleshooting

### Ansible locale warning

If `ansible --version` complains about `ISO-8859-1`, set a UTF-8 locale before running:

```sh
export LC_ALL=C.UTF-8 LANG=C.UTF-8
```

### Chezmoi cannot find the age identity

On the very first run, the Chezmoi source repo contains `key.txt.age` (passphrase-encrypted). The Chezmoi role (and the `run_once_before_decrypt-private-key.sh.tmpl` script) decrypts it using `chezmoi age decrypt --passphrase` and prompts interactively for the passphrase. After decryption, `~/.config/chezmoi/key.txt` persists and subsequent runs are non-interactive.

### SSH: "Repository not found" from a Turing org

The SSH key works (you can `ssh -T git@github.com-turing` and see the right greeting) but `git fetch`/`git push` on a specific org's repo fails. That org enforces SAML SSO. Go to `https://github.com/settings/keys` while logged in as the matching account, click **Configure SSO** on the key, and authorize it for that org.

### Beads Dolt push fails

`bd dolt push` errors with `403` or `Permission denied` typically mean the configured remote points at an account that lacks push rights. The Dolt remote URL lives in `.beads/config.yaml` (`sync.remote`) and in `.beads/embeddeddolt/<prefix>/.dolt/repo_state.json`. Both should point at `git+ssh://git@github.com-personal/Manas73/dotfiles.git` on this repo.

### ansible-galaxy: collection already installed elsewhere

If Ansible complains it can't find `community.general` despite `ansible-galaxy install` succeeding, check that `ansible.cfg`'s `collections_path` matches where `ansible-galaxy` actually installed the collection. This repo sets `collections_path = collections` under `ansible/`, so the install and the playbook run must be executed from the `ansible/` working directory.
