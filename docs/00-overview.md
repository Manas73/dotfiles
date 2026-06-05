# 00 — Overview

This repo manages two distinct things in one place, with a hard boundary
between them.

## Two layers, one repo

```text
Ansible answers: what should this machine have installed and enabled?
Chezmoi answers: what should this user's home config look like?
```

- **Chezmoi** manages user-owned dotfiles under `$HOME` (shell config,
  editor config, `~/.gitconfig`, `~/.ssh/*`, window-manager configs).
- **Ansible** manages machine provisioning: OS packages, user groups, udev
  rules, systemd services, the login shell, and — crucially — it renders
  `~/.config/chezmoi/chezmoi.toml` and runs `chezmoi apply` non-interactively.

The division of labor is strict:

- `chezmoi apply` **never** installs packages, switches your shell, or writes
  to `/etc`. It only writes files into `$HOME`.
- Ansible **never** owns the contents of dotfiles. It installs and enables;
  Chezmoi templates and deploys.

This keeps each tool doing the one thing it's good at, and means a
dotfile-only change never risks touching system state.

## Repo layout

```text
.
├── .chezmoiroot             pins Chezmoi's source dir to chezmoi/
├── justfile                 task runner (validation + ops recipes)
├── README.md                quick orientation
├── chezmoi/                 Chezmoi source state (the ONLY dir Chezmoi sees)
│   ├── dot_*/               source files deployed into $HOME
│   ├── key.txt.age          encrypted age identity (first-run bootstrap)
│   ├── .chezmoi.toml.tmpl   manual-fallback Chezmoi config
│   ├── .chezmoiignore       paths under chezmoi/ that Chezmoi must skip
│   └── .chezmoiscripts/     Chezmoi-specific scripts (age decrypt only)
├── ansible/                 provisioning: hosts, vars, playbooks, roles
└── docs/                    this documentation
```

## The Chezmoi boundary

The single most important invariant: **Chezmoi must only manage files
intended for `$HOME`.** Repo-only directories (`ansible/`, `docs/`) and
top-level files (`README.md`, `AGENTS.md`, `CLAUDE.md`, `justfile`) must
never be deployed into a user's home directory.

This is enforced structurally, not by listing exceptions:

- `.chezmoiroot` at the repo root contains the single line `chezmoi`. This
  pins Chezmoi's source directory to the `chezmoi/` subdirectory. Everything
  outside `chezmoi/` is invisible to Chezmoi **by construction**.
- `chezmoi/.chezmoiignore` only needs to list paths that live *inside*
  `chezmoi/` but should not be applied into `$HOME` (e.g. `key.txt.age`).
  Repo-only top-level directories need no ignore entries.

Verify the invariant at any time (the `just test` recipe does exactly this):

```sh
chezmoi managed | grep -E '^(ansible|docs|bootstrap)/' \
    && echo FAIL || echo "chezmoi boundary ok"
```

Any match means the `.chezmoiroot` / `.chezmoiignore` setup is broken and
repo-only files would land in `$HOME`.

## Where to go next

- Chezmoi internals: [`chezmoi/01-dotfiles-model.md`](chezmoi/01-dotfiles-model.md)
- Ansible package architecture: [`ansible/01-architecture.md`](ansible/01-architecture.md)
- Onboard a machine: [`ansible/02-onboarding.md`](ansible/02-onboarding.md)
