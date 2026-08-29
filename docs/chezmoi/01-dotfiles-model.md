# Chezmoi 01 — Dotfiles Model

How the Chezmoi layer is structured and why.

## Source directory: `.chezmoiroot`

The repo root contains a `.chezmoiroot` file whose entire content is:

```text
chezmoi
```

This pins Chezmoi's **source directory** to `chezmoi/`. Consequences:

- Only files under `chezmoi/` are part of Chezmoi's source state.
- `ansible/`, `docs/`, and top-level files are outside Chezmoi's view by
  construction — no ignore rules needed for them.
- Source-state paths use Chezmoi's attribute prefixes (`dot_`, `private_`,
  `.tmpl`, etc.) relative to `chezmoi/`.

See [`../00-overview.md`](../00-overview.md) for the boundary invariant and
how to verify it.

## Source state

```text
chezmoi/
├── dot_config/             → ~/.config/*
├── dot_gitconfig.tmpl      → ~/.gitconfig (templated)
├── dot_local/              → ~/.local/*
├── dot_ssh/                → ~/.ssh/*
├── .chezmoi.toml.tmpl      manual-fallback Chezmoi config
└── .chezmoiignore          in-source skip list
```

Chezmoi owns the *contents* of these files. Ansible never edits them. If a
config needs per-machine variation, it is a `.tmpl` that reads Chezmoi data
(rendered by Ansible into `chezmoi.toml`; see below).

## `.chezmoiignore`

`chezmoi/.chezmoiignore` lists paths that live *inside* `chezmoi/` but must
not be applied into `$HOME`.

Repo-only top-level directories (`ansible/`, `docs/`) are **not** listed here
— they are already invisible thanks to `.chezmoiroot`.

## Chezmoi config ownership

`~/.config/chezmoi/chezmoi.toml` holds Chezmoi's settings and the data
fields templates read (`email`, `profile`, `osid`, `gpu`, derived
`window_manager`, etc.).

- **Normal path**: Ansible's `chezmoi` role renders `chezmoi.toml` from
  inventory vars, so there are no interactive prompts on managed hosts.
- **Fallback path**: `chezmoi/.chezmoi.toml.tmpl` prompts for those values
  when bootstrapping a machine not in Ansible inventory. See
  [`02-bootstrap-fallback.md`](02-bootstrap-fallback.md).

Both paths produce the same data keys; templates don't care which rendered
the config.
