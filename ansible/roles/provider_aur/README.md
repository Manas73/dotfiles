# Role: provider_aur

Layer 4 provider for the Arch User Repository (yay). Replaces the legacy
`aur_packages` role.

## Liskov contract

- **Input**: `provider_packages` (list[str]) — concrete AUR package names.
- **Empty input**: no-op (all install tasks gated by `when: length > 0`).
- **Asserts**: host `os_family == "Archlinux"`.
- **Idempotent**: `yay -S --needed`.
- **Self-bootstraps**: clones `yay-bin` from the AUR via `git` + `makepkg`
  when yay is missing. Requires `git` and `base-devel` (installed if
  absent).
- **Side effects**: only package installation; cleans up its bootstrap dir.

## Check mode

AUR install is skipped under `--check` because yay/makepkg can't dry-run.
A debug message reports the skip.

## Sudo

Requires NOPASSWD pacman for the primary user (handled by the `sudoers`
role). Yay invokes sudo for pacman dependency resolution and refuses to
run as root.

## Inputs / knobs

- `provider_packages` (required) — set by the orchestrator.
- `provider_aur_bootstrap_dir: /tmp/yay-bin-bootstrap` — clone location
  for the yay bootstrap. Cleaned up after install.

## Tags

`packages`, `aur`, `arch`.
