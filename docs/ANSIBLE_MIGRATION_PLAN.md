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

Hierarchy reflects semantic relationships:

```text
all
├── linux        every Linux host
│   ├── arch     Arch/Garuda package implementation
│   ├── hyprland Wayland/Hyprland desktop profile (Linux only)
│   ├── i3       i3 desktop profile (Linux only)
│   └── gaming   optional gaming packages (Linux only today)
└── darwin       every macOS host
```

A Hyprland host is automatically in `linux`. A macOS host cannot end up in `hyprland` or `arch` because those groups are children of `linux`.

Package aggregation in `arch_packages` and `aur_packages` further guards each profile's contribution by checking `group_names`, so a host that is in `arch` but not `hyprland` does not pick up Hyprland packages, even though `hyprland_*` vars exist in `group_vars`.

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

### Phase 1 — Safety Boundary ✓

- Added repo-only paths to `.chezmoiignore`.
- Verified `chezmoi managed` excludes `docs/`, `ansible/`, and `bootstrap/`.
- Added this plan and `docs/ONBOARDING.md`.

### Phase 2 — Ansible Skeleton ✓

- Added `ansible/ansible.cfg`, inventory, group_vars, `host_vars/alfred.yml`.
- Added `site.yml` and `dotfiles.yml`.
- Added role skeletons with ownership READMEs.

### Phase 3 — Chezmoi Role ✓

- `chezmoi` role renders `~/.config/chezmoi/chezmoi.toml` from Ansible vars.
- Runs `chezmoi apply` non-interactively.
- Preserves the age identity (interactive passphrase only on first run).

### Phase 4 — Package Data ✓

- Moved package lists from `.chezmoidata/packages/linux/arch/*.yaml` into Ansible group vars.
- Layered by OS (`arch.yml`, `darwin.yml`) and profile (`hyprland.yml`, `i3.yml`, `gaming.yml`).

### Phase 5 — Package Roles ✓

- `arch_packages`, `aur_packages` implemented.
- `darwin_packages` scaffold present; full implementation tracked by `chezmoi-7tw`.
- Aggregation guards by `group_names` so each host only gets its profile's packages.

### Phase 6 — System Roles ✓

- `fish`, `docker`, `kanata`, `plasma_custom_wm` implemented.
- Gated by `docker_enabled`, `kanata_enabled`, `plasma_window_manager` respectively.

### Phase 7 — Desktop Roles ✓

- `hyprland` and `i3` assert group membership and act as explicit hooks for future non-package work.
- Desktop dotfiles stay with Chezmoi.

### Phase 8 — Remove Chezmoi Provisioning ✓

- Removed `.chezmoiscripts/linux/arch/*install*.sh.tmpl` and `.chezmoiscripts/linux/run_*.sh` for shell/Docker/Kanata/Plasma.
- Removed `.chezmoidata/packages/linux/arch/*.yaml`.
- Kept `.chezmoiscripts/run_once_before_decrypt-private-key.sh.tmpl`; it is Chezmoi-specific.
- `.chezmoi.toml.tmpl` retained as a manual-fallback bootstrap path.
- `chezmoi apply` no longer runs pacman, yay, chsh, systemctl, groupadd, usermod, modprobe, or udevadm.

### Phase 9 — Documentation and Validation ✓ (non-macOS)

Tracked by `chezmoi-16a` (non-macOS, Linux bootstrap + validation) and `chezmoi-qxl` (macOS bootstrap, blocked on `chezmoi-7tw`).

- README covers the two-layer split, full-provisioning vs dotfiles-only flows, tags, validation commands, and troubleshooting.
- `docs/ONBOARDING.md` covers prerequisites, host_vars/inventory wiring for Linux hosts, validation, and run steps. macOS section is a placeholder pointing at `chezmoi-qxl`.
- Validation command set (see below) is authoritative.

### Phase 10 — Inventory Hierarchy Cleanup ✓

Tracked by `chezmoi-8dn`. Corrected two defects found during review:

- Inventory: `hyprland`, `i3`, `gaming` became children of `linux` rather than siblings, so Linux-only profiles can't be applied to macOS hosts by mistake.
- Aggregation: `arch_packages` and `aur_packages` now check `group_names` when combining profile package vars, so a host in `arch` but not `hyprland` never picks up Hyprland packages.

## Validation Targets

Ansible requires a UTF-8 locale on Garuda; export one before running:

```sh
export LC_ALL=C.UTF-8 LANG=C.UTF-8
```

Boundary and inventory checks:

```sh
# Chezmoi must not manage any repo-only path.
chezmoi managed | grep -E '^(ansible|docs|bootstrap)/' && echo FAIL || echo OK

# Inventory resolves to the expected groups and hosts. Run from `ansible/`
# so `ansible.cfg`'s relative paths resolve.
cd ~/.local/share/chezmoi/ansible
ansible-inventory -i inventories/personal/hosts.yml --graph
ansible-inventory -i inventories/personal/hosts.yml --host "$(hostname)"
```

Playbook checks (run from `ansible/` so `ansible.cfg`'s `roles_path` resolves):

```sh
cd ~/.local/share/chezmoi/ansible

ansible-playbook -i inventories/personal/hosts.yml playbooks/site.yml --syntax-check
ansible-playbook -i inventories/personal/hosts.yml playbooks/dotfiles.yml --syntax-check

# Dry-run. Without --ask-become-pass the sudo-gated tasks stop early, which
# is fine for validating structure and non-become tasks.
ansible-playbook -i inventories/personal/hosts.yml playbooks/site.yml \
    --check --diff --limit "$(hostname)" --ask-become-pass
```

Chezmoi checks:

```sh
chezmoi diff            # pending dotfile deltas
chezmoi managed         # full list of managed targets
```

Long-term invariant: `chezmoi apply` should not require sudo and should not install packages.

## Design Rules

- Keep Chezmoi and Ansible responsibilities separate.
- Put shared package lists in group vars. Never in host vars.
- Use host vars only for true machine-specific differences.
- Avoid hostname conditionals inside roles.
- Prefer idempotent modules over shell commands.
- Use shell only when the target command is the supported interface.
- Do not duplicate package lists between Chezmoi and Ansible.
- Add groups, roles, and playbooks only when they gate real, recurring behavior.

## Resolved Decisions

- `.chezmoi.toml.tmpl` stays as a manual-fallback bootstrap path for `chezmoi init --apply` on machines not yet modeled in Ansible inventory.
- Age identity decryption stays in `.chezmoiscripts/run_once_before_decrypt-private-key.sh.tmpl` and is additionally exposed by the Ansible `chezmoi` role. Both call the same `chezmoi age decrypt --passphrase` flow; the passphrase prompt is accepted as interactive.
- Inventory hierarchy puts `hyprland`, `i3`, and `gaming` under `linux`. Package roles guard profile-specific aggregation by `group_names`.

## Open Decisions

- Whether macOS Docker uses Homebrew cask, Docker Desktop, or is skipped. (Decide when the MacBook arrives.)
