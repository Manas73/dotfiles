# Ansible Migration Plan

## Goal

Split this repository into two clear responsibilities:

- Chezmoi manages user-owned dotfiles under `$HOME`.
- Ansible manages machine provisioning, packages, OS services, groups, udev rules, and Chezmoi configuration.

The long-term target: Ansible owns `~/.config/chezmoi/chezmoi.toml` and runs Chezmoi non-interactively. Chezmoi no longer prompts for machine choices or mutates system state.

## Guiding Principles

- **KISS**: groups, roles, and playbooks exist only when they gate real behavior. Speculative scaffolding is removed.
- **DRY**: shared package/config intent lives in `group_vars/`. Host vars contain only true per-machine values.
- **SOLID (light touch)**: each role has one responsibility; host vars declare intent; roles implement it.
- **Chezmoi safety**: repo-only paths stay outside managed home files.

## Chezmoi Boundary

Chezmoi must only manage files intended for `$HOME`. Repo-only paths are ignored:

- `docs/`
- `ansible/`
- `bootstrap/` (if added later)
- `AGENTS.md`
- `CLAUDE.md`
- `README.md`
- `key.txt.age`

Add new top-level repo-only directories to `.chezmoiignore` before adding files under them.

## Repository Layout

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
│   ├── ANSIBLE_MIGRATION_PLAN.md
│   └── ONBOARDING.md
└── ansible/
    ├── README.md
    ├── ansible.cfg
    ├── inventories/
    │   └── personal/
    │       ├── hosts.yml
    │       ├── group_vars/
    │       │   ├── all.yml
    │       │   ├── linux.yml
    │       │   ├── darwin.yml
    │       │   ├── arch.yml
    │       │   ├── hyprland.yml
    │       │   ├── i3.yml
    │       │   └── gaming.yml
    │       └── host_vars/
    │           └── alfred.yml
    ├── playbooks/
    │   ├── site.yml
    │   └── dotfiles.yml
    └── roles/
        ├── chezmoi/
        ├── arch_packages/
        ├── aur_packages/
        ├── darwin_packages/
        ├── fish/
        ├── docker/
        ├── kanata/
        ├── plasma_custom_wm/
        ├── hyprland/
        └── i3/
```

New groups, roles, or playbooks are added only when they earn their keep.

## Inventory Model

Groups used today:

- `all`: universal intent (Chezmoi, dotfiles).
- `linux`: Linux-only behavior.
- `darwin`: macOS-only behavior.
- `arch`: Arch/Garuda package implementation.
- `hyprland`: Hyprland ecosystem packages.
- `i3`: i3 ecosystem packages.
- `gaming`: optional gaming packages, gated per-host by `gaming_enabled`.

Groups to add **only when they gate real behavior**:

- `desktop`, `workstations`, `laptops`, `development`, `personal`, `work`.

Today none of these change provisioning logic, so they do not exist.

## Variable Layering

- `group_vars/all.yml`: Chezmoi defaults and feature-flag defaults (`docker_enabled`, `kanata_enabled`, `gaming_enabled`).
- `group_vars/linux.yml`: Linux-only common package lists (populated in `chezmoi-fwb`).
- `group_vars/darwin.yml`: Homebrew formulas and casks (populated in `chezmoi-fwb`).
- `group_vars/arch.yml`: Arch core/extra/multilib/AUR lists.
- `group_vars/hyprland.yml`, `group_vars/i3.yml`, `group_vars/gaming.yml`: profile package lists.
- `host_vars/<hostname>.yml`: per-machine intent only.

Host vars stay small. A host var file should contain user, GPU, WM choices, Chezmoi intent, and feature flags. Nothing package-shaped.

### Platform-Specific Keys

Linux-only keys are omitted on macOS hosts rather than faked with empty values. Roles guard reads with `is defined` or default filters. Group membership (`linux`, `arch`, `hyprland`, `i3`) is the primary selector.

Linux-only keys:

- `window_managers`
- `plasma_window_manager`
- `gpu_vendor`
- `chezmoi_window_manager`
- `chezmoi_plasma_window_manager`
- `chezmoi_gpu` (set to `"none"` on darwin where Chezmoi templating still expects it, if needed)

## Chezmoi Ownership Model

Ansible owns `~/.config/chezmoi/chezmoi.toml`. The `chezmoi` role:

- Installs Chezmoi if missing.
- Ensures `~/.config/chezmoi/` exists.
- Renders `chezmoi.toml` from inventory vars.
- Ensures the age identity is present or documents the required manual unlock step.
- Initializes this repository as the Chezmoi source if needed.
- Runs `chezmoi apply` non-interactively.

Long-term, `.chezmoi.toml.tmpl` stays as a manual-fallback path for Chezmoi-only bootstrap. The normal path is Ansible-rendered config.

## Role Responsibilities

Each role has one reason to change.

- `chezmoi`: installs Chezmoi, renders `chezmoi.toml`, runs apply. Does not install packages or manage services.
- `arch_packages`: installs pacman packages from inventory vars.
- `aur_packages`: ensures `yay` exists and installs AUR packages.
- `darwin_packages`: ensures Homebrew exists and installs formulas and casks.
- `fish`: installs Fish and sets it as the login shell.
- `docker`: installs Docker, manages the group and socket/service. Gated by `docker_enabled`.
- `kanata`: installs Kanata, manages input/uinput groups, udev, and the user systemd service. Gated by `kanata_enabled`.
- `plasma_custom_wm`: masks KWin and enables a `plasma-wm.service` for the chosen WM, or restores KWin. Gated by `plasma_window_manager`.
- `hyprland`, `i3`: install their ecosystem packages. They do not manage dotfiles.

Gaming and development are **not roles**. They are group vars that feed into the package roles. If a host is in the `gaming` group, `arch_packages`/`aur_packages` install the gaming lists. Development tooling follows the same pattern on Arch/darwin.

## Playbooks

- `site.yml`: full machine provisioning. Uses tags (`packages`, `system`, `dotfiles`, etc.) for slicing.
- `dotfiles.yml`: Chezmoi config/apply only. Kept separate because dotfile-only applies are frequent.

Additional playbooks are not added until there is a recurring operation that cannot be expressed as a tag on `site.yml`.

## Tags

Used on plays in `site.yml` for operational slicing:

- `packages`, `aur`, `darwin`
- `system`, `fish`, `docker`, `kanata`, `plasma`
- `desktop`, `hyprland`, `i3`
- `dotfiles`, `chezmoi`

Tags stay coarse. One tag per role or per operational slice, not per task.

## How Chezmoi and Ansible Interact

```text
Ansible answers: what should this machine have installed and enabled?
Chezmoi answers: what should this user's home config look like?
```

Ansible renders Chezmoi config from host vars and runs `chezmoi apply`. Chezmoi never installs packages or mutates services.

## Migration Phases

### Phase 1 — Safety Boundary

- Add repo-only paths to `.chezmoiignore`.
- Verify `chezmoi managed` does not include `docs/`, `ansible/`, or `bootstrap/`.
- Add the migration plan and onboarding doc.

### Phase 2 — Ansible Skeleton

- Add `ansible/ansible.cfg`.
- Add minimal inventory, group vars, and `host_vars/alfred.yml`.
- Add `site.yml` and `dotfiles.yml`.
- Add role skeletons with READMEs describing ownership.

### Phase 3 — Chezmoi Role

- Implement `chezmoi` role.
- Render `~/.config/chezmoi/chezmoi.toml` from Ansible vars.
- Make Chezmoi apply non-interactive.
- Preserve age identity handling.

### Phase 4 — Package Data

- Move package lists from `.chezmoidata/packages/linux/arch/*.yaml` into Ansible group vars.
- Layer by OS (`arch.yml`, `darwin.yml`, `linux.yml`) and profile (`hyprland.yml`, `i3.yml`, `gaming.yml`).

### Phase 5 — Package Roles

- Implement `arch_packages`, `aur_packages`, `darwin_packages`.
- Wire them into `site.yml` with tags.

### Phase 6 — System Roles

- Implement `fish`, `docker`, `kanata`, `plasma_custom_wm`.
- Gate each by its feature flag or relevant host var.

### Phase 7 — Desktop Roles

- Implement `hyprland` and `i3` package installation.
- Desktop dotfiles stay with Chezmoi.

### Phase 8 — Remove Chezmoi Provisioning

- Remove `.chezmoiscripts/linux/arch/*install*` and system-mutation scripts.
- Keep age decryption support if still needed.
- Verify `chezmoi apply` runs without sudo and without OS side effects.

### Phase 9 — Documentation and Validation

- Update README with separate flows: dotfiles-only vs full provisioning.
- Keep `docs/ONBOARDING.md` current.
- Add validation commands for Ansible syntax, check mode, and Chezmoi dry-run.

## Validation Targets

```sh
chezmoi managed | grep -E '^(docs|ansible|bootstrap)/' && false || true
chezmoi diff
ansible-playbook -i ansible/inventories/personal/hosts.yml ansible/playbooks/site.yml --syntax-check
ansible-playbook -i ansible/inventories/personal/hosts.yml ansible/playbooks/site.yml --check --limit alfred --ask-become-pass
```

Long-term, `chezmoi apply` should not require sudo and should not install packages.

## Design Rules

- Keep Chezmoi and Ansible responsibilities separate.
- Put shared package lists in group vars. Never in host vars.
- Use host vars only for true machine-specific differences.
- Avoid hostname conditionals inside roles.
- Prefer idempotent modules over shell commands.
- Use shell only when the target command is the supported interface.
- Do not duplicate package lists between Chezmoi and Ansible.
- Add groups, roles, and playbooks only when they gate real, recurring behavior.

## Open Decisions

- Whether `.chezmoi.toml.tmpl` remains a manual-fallback bootstrap path after Ansible owns `chezmoi.toml`.
- Whether age identity decryption remains Chezmoi-driven or becomes an Ansible pre-task.
- Whether macOS Docker uses Homebrew cask, Docker Desktop, or is skipped.
