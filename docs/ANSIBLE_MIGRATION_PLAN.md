# Ansible Migration Plan

## Goal

Split this repository into two clear responsibilities:

- Chezmoi manages user-owned dotfiles under `$HOME`.
- Ansible manages machine provisioning, packages, OS services, groups, udev rules, and Chezmoi configuration.

The long-term target is that Ansible owns `~/.config/chezmoi/chezmoi.toml` and runs Chezmoi non-interactively. Chezmoi should no longer prompt for machine choices or mutate system state.

## Chezmoi Boundary

Chezmoi must only manage files that are intended to land in the user's home directory.

Repo-only paths must be ignored by Chezmoi:

- `docs/`
- `ansible/`
- `bootstrap/`
- `AGENTS.md`
- `CLAUDE.md`
- `README.md`
- `key.txt.age`

This prevents Ansible playbooks, migration docs, agent instructions, and bootstrap scripts from being copied into `$HOME` as managed files.

Before adding any new top-level repo-only directory, add it to `.chezmoiignore` first.

## Target Repository Layout

```text
.
├── README.md
├── .chezmoi.toml.tmpl
├── .chezmoiignore
├── dot_config/
├── dot_gitconfig.tmpl
├── dot_local/
├── dot_ssh/
├── key.txt.age
├── docs/
│   └── ANSIBLE_MIGRATION_PLAN.md
├── ansible/
│   ├── README.md
│   ├── ansible.cfg
│   ├── requirements.yml
│   ├── inventories/
│   │   └── personal/
│   │       ├── hosts.yml
│   │       ├── group_vars/
│   │       │   ├── all.yml
│   │       │   ├── linux.yml
│   │       │   ├── darwin.yml
│   │       │   ├── arch.yml
│   │       │   ├── desktop.yml
│   │       │   ├── development.yml
│   │       │   ├── hyprland.yml
│   │       │   ├── i3.yml
│   │       │   ├── workstations.yml
│   │       │   └── laptops.yml
│   │       └── host_vars/
│   │           ├── alfred.yml
│   │           ├── future-linux-laptop.yml
│   │           └── future-macbook.yml
│   ├── playbooks/
│   │   ├── site.yml
│   │   ├── packages.yml
│   │   ├── dotfiles.yml
│   │   ├── desktop.yml
│   │   └── system.yml
│   └── roles/
│       ├── chezmoi/
│       ├── arch_packages/
│       ├── aur_packages/
│       ├── darwin_packages/
│       ├── fish/
│       ├── docker/
│       ├── kanata/
│       ├── plasma_custom_wm/
│       ├── hyprland/
│       ├── i3/
│       ├── development/
│       └── gaming/
└── bootstrap/
    ├── arch.sh
    └── macos.sh
```

## Inventory Model

Use inventory groups to express shared behavior. Hosts should opt into capabilities by group membership instead of duplicating package lists per host.

Suggested groups:

- `all`: universal package/config intent.
- `linux`: shared Linux behavior.
- `darwin`: shared macOS behavior.
- `arch`: Arch/Garuda package implementation.
- `desktop`: graphical desktop machines.
- `workstations`: desktop-class machines.
- `laptops`: portable machines.
- `development`: machines used for software development.
- `hyprland`: Wayland/Hyprland desktop profile.
- `i3`: i3 desktop profile.
- `gaming`: optional gaming packages.
- `personal` and `work`: profile-specific behavior.

Example inventory shape:

```yaml
all:
  children:
    linux:
      children:
        arch:
          hosts:
            alfred:
            future-linux-laptop:

    darwin:
      hosts:
        future-macbook:

    workstations:
      hosts:
        alfred:

    laptops:
      hosts:
        future-linux-laptop:
        future-macbook:

    development:
      hosts:
        alfred:
        future-linux-laptop:
        future-macbook:

    hyprland:
      hosts:
        alfred:
        future-linux-laptop:

    i3:
      hosts:
        alfred:
```

## Variable Layering

Keep host-specific files small. Most package and behavior declarations should live in group vars.

Use this layering:

- `group_vars/all.yml`: cross-platform intent such as Fish, Git, Vivaldi, PyCharm, Neovim, Starship, Zoxide.
- `group_vars/linux.yml`: Linux-only common tooling.
- `group_vars/darwin.yml`: Homebrew formulae/casks for macOS.
- `group_vars/arch.yml`: Arch/Garuda pacman and AUR package lists.
- `group_vars/development.yml`: Docker, cloud CLIs, IDEs, language tooling, project tools.
- `group_vars/desktop.yml`: graphical desktop packages common to Linux desktops.
- `group_vars/hyprland.yml`: Hyprland, Waybar, SwayNC, SwayOSD, Hyprlock, Hypridle, UWSM, portal, Wayland clipboard, Matugen.
- `group_vars/i3.yml`: i3, Picom, Polybar, sxhkd, rofi plugins.
- `host_vars/*.yml`: true machine differences only.

Example host vars for the current workstation:

```yaml
ansible_connection: local
primary_user: ms-garuda
machine_profile: workstation

chezmoi_email: manas.sambare@gmail.com
chezmoi_profile: personal
chezmoi_osid: linux-arch
chezmoi_gpu: nvidia
chezmoi_window_manager:
  - i3
  - hyprland
chezmoi_plasma_window_manager: i3

window_managers:
  - i3
  - hyprland
plasma_window_manager: i3
gpu_vendor: nvidia

docker_enabled: true
kanata_enabled: true
gaming_enabled: true
```

Example future MacBook host vars:

```yaml
primary_user: manas
machine_profile: laptop

chezmoi_email: manas.sambare@gmail.com
chezmoi_profile: personal
chezmoi_osid: darwin
chezmoi_gpu: none
chezmoi_window_manager: []
chezmoi_plasma_window_manager: ""

docker_enabled: true
kanata_enabled: false
gaming_enabled: false
```

## Chezmoi Ownership Model

Ansible should own `~/.config/chezmoi/chezmoi.toml`.

The `chezmoi` role should:

- Install Chezmoi if missing.
- Ensure `~/.config/chezmoi` exists.
- Render `chezmoi.toml` from Ansible host/group vars.
- Ensure the age identity is present or document the required manual unlock step.
- Initialize this repository as the Chezmoi source if needed.
- Run `chezmoi apply` non-interactively.

Long-term, `.chezmoi.toml.tmpl` should no longer be the primary source of machine configuration. It can remain as a fallback for manual Chezmoi-only bootstrap, but the normal path should be Ansible-rendered config.

## Role Responsibilities

Each role should have one reason to change.

`chezmoi`:

- Owns Chezmoi installation and `~/.config/chezmoi/chezmoi.toml` rendering.
- Runs Chezmoi apply.
- Does not install desktop packages or configure system services.

`arch_packages`:

- Installs pacman packages for Arch/Garuda.
- Does not install AUR packages.

`aur_packages`:

- Ensures `yay` exists.
- Installs AUR packages.

`darwin_packages`:

- Ensures Homebrew exists.
- Installs formulas and casks.

`fish`:

- Ensures Fish is installed and configured as the user's login shell.
- Does not own Fish dotfiles.

`docker`:

- Installs/enables Docker where supported.
- Adds Linux user to `docker` group.
- Handles macOS separately or skips service management there.

`kanata`:

- Installs Kanata.
- Configures Linux groups, udev rules, and systemd user service.
- Runs only when `kanata_enabled` is true.

`plasma_custom_wm`:

- Configures Plasma to launch a selected custom WM or restores KWin.
- Uses `plasma_window_manager` from Ansible vars.

`hyprland`:

- Installs Hyprland ecosystem packages.
- Does not own `~/.config/hypr`; Chezmoi owns those files.

`i3`:

- Installs i3 ecosystem packages.
- Does not own `~/.config/i3`; Chezmoi owns those files.

`development`:

- Installs development tools and IDEs appropriate to the platform.

`gaming`:

- Installs optional gaming packages only when enabled.

## Playbooks

Start with one primary playbook and a few focused entry points.

`playbooks/site.yml` should orchestrate the full machine:

```yaml
- hosts: all
  roles:
    - chezmoi

- hosts: arch
  roles:
    - arch_packages
    - aur_packages

- hosts: darwin
  roles:
    - darwin_packages

- hosts: all
  roles:
    - fish

- hosts: development
  roles:
    - development

- hosts: hyprland
  roles:
    - hyprland

- hosts: i3
  roles:
    - i3

- hosts: all
  roles:
    - docker
      when: docker_enabled | default(false)

- hosts: linux
  roles:
    - kanata
      when: kanata_enabled | default(false)

- hosts: linux
  roles:
    - plasma_custom_wm
      when: plasma_window_manager is defined
```

Also provide focused playbooks:

- `packages.yml`: package installation only.
- `dotfiles.yml`: Chezmoi config/apply only.
- `desktop.yml`: desktop/window-manager setup only.
- `system.yml`: groups, services, udev, shell, Docker, Kanata.

## Tags

Use tags for common operational slices:

- `packages`
- `aur`
- `dotfiles`
- `fish`
- `docker`
- `kanata`
- `hyprland`
- `i3`
- `plasma`
- `development`
- `gaming`
- `linux`
- `darwin`

Keep tags coarse. Avoid one tag per task unless there is a real operational need.

## Migration Phases

### Phase 1: Safety Boundary

- Add repo-only paths to `.chezmoiignore`.
- Verify `chezmoi managed` does not include `docs/`, `ansible/`, or `bootstrap/`.
- Add this migration plan.

### Phase 2: Ansible Skeleton

- Add `ansible/ansible.cfg`.
- Add `ansible/requirements.yml`.
- Add `inventories/personal/hosts.yml`.
- Add initial `group_vars` and `host_vars/alfred.yml`.
- Add empty role skeletons with README files describing ownership.

### Phase 3: Chezmoi Role

- Implement `chezmoi` role.
- Render `~/.config/chezmoi/chezmoi.toml` from Ansible vars.
- Make Chezmoi apply non-interactive.
- Preserve age identity handling.
- Validate that `chezmoi apply --dry-run` does not try to manage repo-only files.

### Phase 4: Package Roles

- Move package data from `.chezmoidata/packages/linux/arch/*.yaml` into Ansible group vars.
- Implement `arch_packages` for pacman packages.
- Implement `aur_packages` for yay/AUR packages.
- Implement `darwin_packages` using Homebrew formulas/casks.
- Keep package lists layered by group rather than copied per host.

### Phase 5: System Roles

- Move Fish shell switching into `fish` role.
- Move Docker group/socket setup into `docker` role.
- Move Kanata groups, udev, and service setup into `kanata` role.
- Move Plasma custom WM service/masking into `plasma_custom_wm` role.

### Phase 6: Desktop Roles

- Implement `hyprland` role for Hyprland ecosystem dependencies.
- Implement `i3` role for i3 ecosystem dependencies.
- Keep desktop config files in Chezmoi.
- Ensure group membership controls which desktop package sets are installed.

### Phase 7: Remove Chezmoi Provisioning Scripts

- Remove or neutralize Chezmoi scripts that install packages or mutate system state.
- Keep only Chezmoi-specific secret/decryption support if still needed.
- Verify `chezmoi apply` is safe to run repeatedly without sudo or OS provisioning side effects.

### Phase 8: Documentation and Validation

- Update README with separate workflows for dotfiles-only and full provisioning.
- Add validation commands for Ansible syntax, check mode, and Chezmoi dry-run.
- Document bootstrap commands for Arch/Garuda and macOS.

## Validation Targets

Use these checks during migration:

```sh
chezmoi managed | grep -E '^(docs|ansible|bootstrap)/' && false || true
chezmoi diff
ansible-playbook -i ansible/inventories/personal/hosts.yml ansible/playbooks/site.yml --syntax-check
ansible-playbook -i ansible/inventories/personal/hosts.yml ansible/playbooks/site.yml --check --limit alfred --ask-become-pass
```

Long-term, `chezmoi apply` should not require sudo and should not install packages.

## Design Rules

Follow these rules while implementing the migration:

- Keep Chezmoi and Ansible responsibilities separate.
- Put shared package lists in group vars, not host vars.
- Use host vars only for true machine-specific differences.
- Avoid hostname-specific conditionals inside roles.
- Keep role logic boring and explicit.
- Prefer idempotent Ansible modules over shell commands.
- Use shell commands only when there is no good module or the target command is the supported interface.
- Do not duplicate the same package list in Chezmoi and Ansible.
- Add new groups only when they represent a real reusable capability.

## Open Decisions

- Whether to keep `.chezmoi.toml.tmpl` as a fallback manual bootstrap path after Ansible owns `chezmoi.toml`.
- Whether age identity decryption remains Chezmoi-driven or becomes an Ansible pre-task with a manual passphrase step.
- Whether macOS support should be implemented immediately or as a scaffold until the MacBook exists.
