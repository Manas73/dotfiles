# Role: aur_packages

Installs AUR packages via `yay`. Bootstraps `yay` itself from `yay-bin` when missing.

## Responsibilities

- Assert the host is Arch-based and `makepkg` is available.
- Bootstrap `yay` via `makepkg -si` if `yay` is not installed.
- Install AUR packages with `yay -S --needed --noconfirm --removemake`.

## Does Not

- Install pacman packages (owned by `arch_packages`).
- Run as root. `yay` and `makepkg` refuse root; the role runs as the primary user and relies on the user's sudo rights for pacman invocations inside `yay`.

## Inputs

Aggregated across groups:

- `arch_aur_packages`, `hyprland_aur_packages`, `i3_aur_packages`, `gaming_aur_packages`

Gaming lists are included only when `gaming_enabled: true`.

Behavior knobs (defaults):

- `aur_bootstrap_dir: /tmp/yay-bin-bootstrap`

## Prerequisites

- `pacman -S --needed git base-devel` is handled by the bootstrap block automatically.
- The user must be able to run `sudo pacman` (`yay` calls sudo internally).

## Check Mode

AUR installs are skipped in `--check` because `yay` and `makepkg` cannot preview installs without writing to disk. A debug message reports the skip when the AUR list is non-empty. Pacman-side tasks elsewhere in the playbook remain fully check-compatible.

## Example

```sh
ansible-playbook -i inventories/personal/hosts.yml playbooks/site.yml \
    --limit alfred --tags packages --ask-become-pass
```

AUR only:

```sh
ansible-playbook ... --tags aur --ask-become-pass
```
