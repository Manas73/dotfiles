# My Dotfiles

Chezmoi owns `$HOME`. Ansible owns packages, services, and
`~/.config/chezmoi/chezmoi.toml`. The repo-root `mise.toml` installs the
repo toolchain and runs tasks — it does not provision the machine or write
dotfiles. Cross-platform CLI tools are pinned in the package catalog and
installed by Ansible via `mise use --global`.

> macOS package dispatch already works; bare-metal bootstrap is still
> pending (`chezmoi-qxl`).

## 1. New machine

You need **mise** and **git**. Everything else (`ansible-core`, `chezmoi`)
comes from `mise.toml` when you run a task.

```sh
curl https://mise.run | sh
export PATH="$HOME/.local/bin:$PATH"
# If git is missing: mise use -g git
```

Clone over SSH. Add an ed25519 key to the matching GitHub account (and
authorize it per-org if SSO is required). Origins use the host aliases
in `~/.ssh/config`:

- `github.com-personal` → `~/.ssh/github-personal`
- `github.com-turing` → `~/.ssh/github-turing`

```sh
ssh -T git@github.com-personal   # expect: Hi <user>! ...
git clone git@github.com-personal:Manas73/dotfiles.git ~/.local/share/chezmoi
cd ~/.local/share/chezmoi

mise trust          # no-op with a warning if already trusted
mise run deps       # galaxy collections (already vendored; run to refresh)
mise run apply      # sudo
```

Log out and back in so new groups (`docker`, `input`, `uinput`) apply.

The host must be in `ansible/hosts.yml` with a `recipe:`. Wiring a new
box: [onboarding](docs/ansible/02-onboarding.md).

## 2. Day to day

From the repo root (`~/.local/share/chezmoi`):

| Command | What it does |
|---|---|
| `mise tasks` | list tasks |
| `mise run check` | pre-commit validation |
| `mise run test` | chezmoi/repo boundary guard |
| `mise run test-catalog` | package catalog resolver unit tests |
| `mise run diff` | pending dotfile changes |
| `mise run apply` | full provision (sudo) |
| `mise run packages` | packages only (sudo) |
| `mise run dotfiles` | re-apply dotfiles only |
| `mise run deps` | refresh Ansible collections |

Host-acting tasks (`apply`, `dotfiles`, `packages`) use
`--limit "$(hostname)"`. Tags and raw playbook commands:
[tags & validation](docs/ansible/04-tags-and-validation.md).

## 3. Other paths

Already provisioned, refresh dotfiles only:

```sh
mise run dotfiles
```

Host not in Ansible inventory (dotfiles only, no packages/system):

```sh
chezmoi init --apply git@github.com-personal:Manas73/dotfiles.git
```

Details: [bootstrap fallback](docs/chezmoi/02-bootstrap-fallback.md).

## How it works

`chezmoi apply` never installs packages, switches the login shell, or
writes to `/etc`. Ansible never owns dotfile contents. Repo-root mise
never replaces either — it only puts ansible/chezmoi on PATH and
runs the tasks above. User CLI pins live in
`ansible/group_vars/all/package_catalog.yml`.

## Docs

Start at [`docs/README.md`](docs/README.md).

- [Overview](docs/00-overview.md)
- Chezmoi: [model](docs/chezmoi/01-dotfiles-model.md) ·
  [fallback](docs/chezmoi/02-bootstrap-fallback.md)
- Ansible: [architecture](docs/ansible/01-architecture.md) ·
  [onboarding](docs/ansible/02-onboarding.md) ·
  [adding apps](docs/ansible/03-adding-apps-providers.md) ·
  [tags](docs/ansible/04-tags-and-validation.md)
- [ansible/README.md](ansible/README.md)
