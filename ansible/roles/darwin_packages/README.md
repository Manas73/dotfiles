# Role: darwin_packages

Installs macOS packages via Homebrew.

## Responsibilities

- Ensure Homebrew is installed (or document the manual prerequisite).
- Install formulas from `darwin_common_brews` and `development_brews`.
- Install casks from `darwin_common_casks` and `development_casks`.
- Remain idempotent.

## Does Not

- Manage Linux packages.
- Configure services or dotfiles.

## Inputs

- `darwin_common_brews`
- `darwin_common_casks`
- `development_brews`
- `development_casks`

## Implementation Task

Tracked by Beads issue `chezmoi-7tw`.
