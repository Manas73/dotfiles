# Role: provider_cask

Layer 4 provider for Homebrew Casks (macOS GUI apps). Companion to
`provider_brew`.

## Liskov contract

- **Input**: `provider_packages` (list[str]) — concrete cask names.
- **Empty input**: no-op.
- **Asserts**: host `os_family == "Darwin"`.
- **Idempotent**: `community.general.homebrew_cask state: present`.
- **Side effects**: only cask installation.

## Bootstrap

This role does **not** install Homebrew itself. `provider_brew` does that.
If you want only casks (no formulae), either install Homebrew manually
on the Mac, or list at least one trivial formula in `darwin_apps` so
`provider_brew` runs and bootstraps brew.

The orchestrator naturally runs `provider_brew` first when both buckets
are non-empty (Ansible iterates `dict2items` alphabetically: brew < cask).

## Inputs / knobs

- `provider_packages` (required) — set by the orchestrator.
- `provider_cask_brew_path: /opt/homebrew/bin/brew` — Homebrew check path.
  Override to `/usr/local/bin/brew` on Intel macs.

## Tags

`packages`, `cask`, `darwin`.
