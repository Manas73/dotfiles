# My Dotfiles

This repository holds the dotfiles and machine-provisioning setup for my
personal systems.

Two layers, one repo:

- **Chezmoi** manages user dotfiles under `$HOME`.
- **Ansible** manages OS packages, services, groups, udev rules, and renders
  `~/.config/chezmoi/chezmoi.toml`.

`chezmoi apply` never installs packages, switches your shell, or writes to
`/etc`. Provisioning happens through Ansible.

> macOS bootstrap is pending (beads `chezmoi-qxl`): package dispatch and
> chezmoi rendering on darwin already work; the bare-metal bootstrap is
> filled in when a MacBook is actually onboarded.

## Documentation

Full docs live in [`docs/`](docs/) — start at
[`docs/README.md`](docs/README.md) for the guided reading order:

- [Overview](docs/00-overview.md) — the two-layer model and the Chezmoi/repo
  boundary.
- Chezmoi: [dotfiles model](docs/chezmoi/01-dotfiles-model.md) ·
  [bootstrap fallback](docs/chezmoi/02-bootstrap-fallback.md)
- Ansible: [architecture](docs/ansible/01-architecture.md) ·
  [onboarding](docs/ansible/02-onboarding.md) ·
  [adding apps/providers](docs/ansible/03-adding-apps-providers.md) ·
  [tags & validation](docs/ansible/04-tags-and-validation.md)
- In-tree reference: [`ansible/README.md`](ansible/README.md)

## Requirements

- `git`
- `age` (1.2.0+)
- `chezmoi` (2.52.2+)
- `just` (task runner; see Quickstart)
- `ansible-core` (2.15+) for full machine provisioning
- `community.general` Ansible collection (installed in the bootstrap step below)
- SSH access to `github.com` (HTTPS is no longer wired up; see Authentication)

## Quickstart

Day-to-day work goes through [`just`](https://just.systems) recipes in the
repo-root `justfile`. Run them from the repo root (`~/.local/share/chezmoi`).
Each bakes in the UTF-8 locale Ansible needs and `cd`s into `ansible/` so the
inventory resolves — no manual `export` or directory juggling.

```sh
just            # list all recipes
just check      # full pre-commit validation (run before committing)
just test       # chezmoi-boundary guard only
just diff       # pending dotfile changes (chezmoi diff)
just apply      # full site playbook for this host (prompts for sudo)
just dotfiles   # re-apply dotfiles only
just packages   # install packages only (prompts for sudo)
```

All host-acting recipes (`apply`, `dotfiles`, `packages`) scope to the current
host via `--limit "$(hostname)"`. See
[tags & validation](docs/ansible/04-tags-and-validation.md) for the
underlying commands and tag-based slicing.

## Authentication

Clones and pushes go through SSH. `~/.ssh/config` defines two host aliases:

- `github.com-personal` → `~/.ssh/github-personal` (personal account)
- `github.com-turing` → `~/.ssh/github-turing` (work account, if relevant)

Repo origins use those aliases, e.g.:

```text
git@github.com-personal:Manas73/dotfiles.git
```

You need the matching SSH keys on the machine and their public keys
registered on the correct GitHub account. If an org enforces SAML SSO (Turing
orgs do), authorize the key per-org at `https://github.com/settings/keys`
after adding it. Troubleshooting for SSO and other gotchas is in
[tags & validation](docs/ansible/04-tags-and-validation.md#troubleshooting).

## First run

New machine, full provisioning:

```sh
# Clone into the Chezmoi source path.
git clone git@github.com-personal:Manas73/dotfiles.git ~/.local/share/chezmoi

# Install the required Ansible collection (from the repo root).
cd ~/.local/share/chezmoi
ansible-galaxy install -r ansible/requirements.yml

# Provision this host.
just apply        # == ansible-playbook playbooks/site.yml --limit "$(hostname)" --ask-become-pass
```

`--ask-become-pass` prompts once for sudo; the first run also prompts once for
the age passphrase. Log out and back in afterward so new group memberships
(`docker`, `input`, `uinput`) take effect.

Already-provisioned machine, dotfiles only:

```sh
just dotfiles
```

Machine not yet in Ansible inventory (Chezmoi-only fallback):

```sh
chezmoi init --apply git@github.com-personal:Manas73/dotfiles.git
```

Full step-by-step (host_vars, inventory wiring, validation) is in
[onboarding](docs/ansible/02-onboarding.md); the fallback path is detailed in
[bootstrap fallback](docs/chezmoi/02-bootstrap-fallback.md).
