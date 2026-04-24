# Role: development

Installs development tooling across supported platforms.

## Responsibilities

- Install development packages declared in inventory vars.
- Composes with the underlying package roles (`arch_packages`, `aur_packages`, `darwin_packages`).

## Does Not

- Configure dotfiles.
- Install desktop packages.

## Inputs

- `development_packages`
- `development_aur_packages`
- `development_brews`
- `development_casks`

## Implementation Task

Tracked by Beads issue `chezmoi-a2q` (Arch side) and `chezmoi-7tw` (macOS side).
