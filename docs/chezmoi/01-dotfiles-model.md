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
├── .chezmoiignore          in-source skip list
├── .chezmoiscripts/        Chezmoi-run scripts (age decrypt only)
└── key.txt.age             encrypted age identity
```

Chezmoi owns the *contents* of these files. Ansible never edits them. If a
config needs per-machine variation, it is a `.tmpl` that reads Chezmoi data
(rendered by Ansible into `chezmoi.toml`; see below).

## `.chezmoiignore`

`chezmoi/.chezmoiignore` lists paths that live *inside* `chezmoi/` but must
not be applied into `$HOME`. The key entry is `key.txt.age`: the encrypted
age identity ships in the source tree for first-run bootstrap but must not be
copied into the home directory verbatim.

Repo-only top-level directories (`ansible/`, `docs/`) are **not** listed here
— they are already invisible thanks to `.chezmoiroot`.

## The age identity

Secrets in templates are decrypted with an [age](https://age-encryption.org)
identity. The flow:

1. `chezmoi/key.txt.age` is the passphrase-encrypted identity, committed to
   the repo.
2. On first run, it is decrypted with `chezmoi age decrypt --passphrase`
   (prompts once, interactively) to `~/.config/chezmoi/key.txt`.
3. Subsequent runs are non-interactive — the decrypted identity persists.

Two things trigger the decrypt, both calling the same flow:

- `chezmoi/.chezmoiscripts/run_once_before_decrypt-private-key.sh.tmpl`
  (the Chezmoi-only bootstrap path).
- The Ansible `chezmoi` role (the provisioned path).

If Chezmoi reports it cannot find the age identity, re-run the first-run
decrypt; see [`../ansible/04-tags-and-validation.md`](../ansible/04-tags-and-validation.md)
(Troubleshooting).

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
