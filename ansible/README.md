# Ansible

Provisioning layer for OS packages, services, groups, and Chezmoi configuration.

See `docs/ANSIBLE_MIGRATION_PLAN.md` for the long-term plan and `docs/ONBOARDING.md` for adding a new machine.

## Scope

Ansible owns:

- OS/package installation (pacman, AUR via yay, Homebrew formulae, Homebrew casks).
- User groups, udev rules, and systemd user services.
- Fish login shell switching.
- Docker, Kanata, and Plasma custom-WM setup.
- Rendering `~/.config/chezmoi/chezmoi.toml` from inventory vars.
- Running `chezmoi apply` non-interactively.

Ansible does not own:

- The contents of `~/.config/*` dotfiles (Chezmoi owns these).
- `~/.gitconfig`, `~/.ssh/*`, Fish functions, Hyprland/i3 configs.

## Layout

```text
ansible/
├── ansible.cfg                  # inventory = hosts.yml; filter_plugins = filter_plugins
├── hosts.yml                    # flat inventory at the ansible/ root
├── filter_plugins/
│   └── catalog.py               # resolve_catalog jinja filter
├── group_vars/
│   ├── all/                     # directory form
│   │   ├── main.yml             # chezmoi paths, ansible_connection, feature defaults
│   │   ├── package_catalog.yml  # Layer 2: logical name -> per-OS install instructions
│   │   └── profiles.yml         # Layer 1: profile_apps dict (hyprland/i3/gaming)
│   ├── arch.yml                 # arch_apps (Layer 1)
│   └── darwin.yml               # darwin_apps (Layer 1)
├── host_vars/
│   ├── alfred.yml
│   └── mac-placeholder.yml
├── playbooks/
│   ├── site.yml
│   └── dotfiles.yml
└── roles/
    ├── chezmoi/
    ├── packages/                # Layer 3: dispatcher
    ├── provider_pacman/         # Layer 4: providers
    ├── provider_aur/
    ├── provider_brew/
    ├── provider_cask/
    ├── sudoers/
    ├── fish/
    ├── docker/
    ├── kanata/
    └── plasma_custom_wm/
```

Notes on the layout:

- The inventory is flat. There is no `inventories/personal/` wrapper layer.
  `ansible.cfg` points `inventory = hosts.yml`, so commands omit `-i` by
  default when run from the `ansible/` directory.
- Inventory hierarchy is just `all → linux → arch` and `all → darwin`.
  Desktop profiles (hyprland, i3) and feature buckets (gaming) are **not**
  inventory groups; they are declared per-host in
  `host_vars/<hostname>.yml` via the `profiles:` list and resolved against
  `profile_apps` in `group_vars/all/profiles.yml`. Single source of truth
  per host.
- Legacy roles `arch_packages`, `aur_packages`, `darwin_packages`, and the
  empty `hyprland`/`i3` profile-hook roles have been deleted. Their
  behavior is fully replaced by the four-layer model below.

## Package Architecture

Four layers, one direction of dependency. Each layer has a single
responsibility and depends only on the schema of the layer below it.

```text
Layer 1: Intent           <group>_apps   (lists of logical names per group)
Layer 2: Catalog          group_vars/all/package_catalog.yml
Layer 3: Dispatcher       roles/packages (orchestrator + OCP dispatch loop)
Layer 4: Providers        roles/provider_{pacman,aur,brew,cask}
```

### Layer 1: Intent

Two sources of intent feed the orchestrator:

1. **OS-family lists** in `group_vars/<os>.yml`:

   | Group    | Var           | File                  |
   |----------|---------------|-----------------------|
   | `arch`   | `arch_apps`   | `group_vars/arch.yml` |
   | `darwin` | `darwin_apps` | `group_vars/darwin.yml` |

2. **Profile bundles** in `group_vars/all/profiles.yml`:

   ```yaml
   profile_apps:
     hyprland: [waybar-git, hyprland, hyprlock, ...]
     i3:       [i3-wm, picom, polybar, ...]
     gaming:   [steam, lutris, umu-launcher]
   ```

   A host opts into profiles by listing them in `host_vars/<hostname>.yml`:

   ```yaml
   profiles:
     - hyprland
     - gaming
   ```

   Profiles are NOT inventory groups; declaring them in host_vars is the
   single source of truth. The dispatcher unions `arch_apps` (or
   `darwin_apps`) with the lists pulled from `profile_apps` for every
   profile the host opts into.

All four sources are pure lists of logical app names. They know nothing
about pacman, AUR, brew, or cask.

### Layer 2: Catalog

`group_vars/all/package_catalog.yml` maps logical app names to concrete
per-OS install instructions.

Schema:

```yaml
package_catalog:

  # Cross-OS GUI app: per-OS keys with provider + packages.
  vivaldi:
    arch:   { provider: pacman, packages: [vivaldi, vivaldi-ffmpeg-codecs] }
    darwin: { provider: cask,   packages: [vivaldi] }

  # Bundle: expands recursively into other logical names.
  docker:
    includes:
      - docker-engine
      - docker-buildx-plugin
      - docker-compose-plugin

  # Arch-only routing: AUR package that wouldn't be reachable via plain
  # `pacman -S`. Has only an `arch:` key.
  kanata-bin:
    arch: { provider: aur, packages: [kanata-bin] }
```

Rules:

- An entry has either `includes:` (bundle) or per-OS keys, never both.
- `includes:` expands recursively. Cycles raise `CatalogError`.
- A logical name **not** in the catalog falls through to the default
  provider for the target OS (`pacman` on arch, `brew` on darwin). This is
  why everyday Arch packages like `alacritty`, `networkmanager`, and fonts
  do not need catalog entries.
- An entry without a key for the current `target_os` is silently dropped, so
  darwin-only apps don't fail on Arch and vice versa.
- Output buckets are deduped and sorted per provider for stable diffs.

The catalog currently has ~35 entries: cross-OS GUI apps (vivaldi,
1password, firefox, vlc, slack, zoom, google-chrome, dropbox, docker
bundle), arch-only AUR routing (kanata-bin, pacseek, all JetBrains
products, opencode-bin, sublime-text-4, ...), and gaming entries
(steam, umu-launcher, waybar-git).

### Layer 3: Dispatcher

`roles/packages` is the orchestrator. It does five things, in order
(see `roles/packages/tasks/main.yml`):

1. Compute `packages_target_os` (`arch`|`darwin`) from
   `ansible_facts['os_family']`.
2. Compute `packages_default_provider` (`pacman`|`brew`) from the OS.
3. Aggregate logical app names: the OS-family list (`arch_apps` or
   `darwin_apps`, gated by `group_names` membership) unioned with each
   `profile_apps[<name>]` for every entry in the host's `profiles:` list.
   Unknown profile names are silently ignored via `extract(..., default=[])`.
4. Resolve the aggregated list through the catalog via the `resolve_catalog`
   filter, producing `packages_resolved = {provider: [pkg, ...]}`.
5. Dispatch dynamically: iterate `dict2items(packages_resolved)` and
   `include_role: provider_{{ item.key }}` with `provider_packages: {{ item.value }}`.

Step 5 is the Open/Closed pivot: the dispatcher has no hardcoded list of
providers. Adding a provider requires zero edits to this role.

### Layer 4: Providers

One role per package manager. Every provider obeys the same Liskov
contract:

- **Input**: `provider_packages` (list of concrete package names).
- **Empty input**: no-op (`when: provider_packages | length > 0`).
- **Asserts**: the host's `os_family` matches.
- **Idempotent**: `state: present` semantics.
- **Self-bootstraps** where needed.
- **Side effects**: only package installation.

| Role             | OS       | Bootstrap behavior                                              |
|------------------|----------|-----------------------------------------------------------------|
| `provider_pacman`| Archlinux| pacman is in the base system; just verifies it.                 |
| `provider_aur`   | Archlinux| Clones `yay-bin` and builds it via makepkg when yay is missing. |
| `provider_brew`  | Darwin   | Runs the official Homebrew install script with `NONINTERACTIVE=1`. |
| `provider_cask`  | Darwin   | None. Relies on `provider_brew` to install Homebrew.            |

Multilib is folded into `provider_pacman`. Multilib is a pacman *repo*,
not a separate manager, so `steam` and friends route to `provider: pacman`
and install via the same module (with multilib enabled in
`/etc/pacman.conf`).

## Adding a New App

1. Pick the right intent bucket and add the logical name there:
   - OS-wide on every Arch host: `group_vars/arch.yml` (`arch_apps`).
   - OS-wide on every macOS host: `group_vars/darwin.yml` (`darwin_apps`).
   - Tied to a desktop or feature profile: the relevant key under
     `profile_apps` in `group_vars/all/profiles.yml`.
2. If the app is cross-OS, or needs a non-default provider on Arch (AUR),
   add a catalog entry. Otherwise it falls through to the default provider
   for the OS and needs no catalog entry.
3. Verify the resolution:

   ```sh
   ansible-playbook playbooks/site.yml \
     --limit <host> --check --diff --tags packages
   ```

   (Inventory is read from `hosts.yml` by default per `ansible.cfg`; pass
   `-i hosts.yml` if you want to be explicit.)

## Adding a New Provider

Open/Closed in practice. To add, for example, a Flatpak provider:

1. Create `roles/provider_flatpak/tasks/main.yml`. Accept `provider_packages`
   as input. Assert OS, install idempotently, self-bootstrap if needed.
2. Add `"flatpak"` to `VALID_PROVIDERS` in `filter_plugins/catalog.py`.
3. Add `provider: flatpak` entries to catalog apps that should use it.

No edits to `roles/packages`. No edits to existing provider roles. No edits
to inventory.

## Mac Onboarding

The Mac host slot is scaffolded but not activated. To bring a Mac online:

1. Rename `host_vars/mac-placeholder.yml` to `host_vars/<your-hostname>.yml`.
2. Fill in the TODO fields in that file (`primary_user`, etc.). See the
   comments in the file for the full checklist. The expected schema is the
   same unprefixed data keys (`email`, `profile`, `osid`, `gpu`,
   `profiles: []`) the chezmoi role reads directly.
3. In `hosts.yml`, uncomment the host entry under the `darwin` group and
   replace `mac-placeholder` with your hostname.
4. If on an Intel Mac, set `provider_brew_path: /usr/local/bin/brew` and
   `provider_cask_brew_path: /usr/local/bin/brew` in host_vars.
5. Optionally trim `darwin_apps` in `group_vars/darwin.yml` to taste.
6. Dry-run first:

   ```sh
   ansible-playbook playbooks/site.yml \
     --limit <your-hostname> --check --diff --tags packages
   ```

The full Mac bootstrap flow (Homebrew install, ansible-core via brew,
first-run checklist) is tracked separately by `chezmoi-qxl` and will be
filled in when a real MacBook is onboarded.

## Tags

| Tag        | Scope                                                |
|------------|------------------------------------------------------|
| `packages` | Everything in the packages orchestrator.             |
| `pacman`   | Pacman provider only.                                |
| `aur`      | AUR provider only.                                   |
| `brew`     | Homebrew formula provider only.                      |
| `cask`     | Homebrew cask provider only.                         |
| `arch`     | All arch-OS package work.                            |
| `darwin`   | All darwin-OS package work.                          |
| `upgrade`  | `pacman -Syu` task in `provider_pacman`.             |
| `dotfiles` | Chezmoi render + apply.                              |
| `chezmoi`  | Alias for the chezmoi role play (same as `dotfiles`).|
| `system`   | sudoers, fish, docker, kanata, plasma (umbrella).    |
| `sudoers`  | sudoers drop-in only.                                |
| `fish`     | Fish login shell role only.                          |
| `docker`   | Docker role only.                                    |
| `kanata`   | Kanata role only.                                    |
| `plasma`   | plasma_custom_wm role only.                          |

## Usage

`ansible.cfg` sets `inventory = hosts.yml`, so `-i` can be omitted when
running from the `ansible/` directory.

```sh
cd ansible

# Full provisioning run.
ansible-playbook playbooks/site.yml --limit alfred --ask-become-pass

# Just packages, any OS.
ansible-playbook playbooks/site.yml --limit alfred --tags packages --ask-become-pass

# Just AUR.
ansible-playbook playbooks/site.yml --limit alfred --tags aur --ask-become-pass

# Just dotfiles.
ansible-playbook playbooks/dotfiles.yml --limit alfred
```

Syntax check:

```sh
ansible-playbook playbooks/site.yml --syntax-check
ansible-playbook playbooks/dotfiles.yml --syntax-check
```

## Status

| Issue          | Status     | Description                                                  |
|----------------|------------|--------------------------------------------------------------|
| `chezmoi-g19`  | done       | chezmoi role renders chezmoi.toml and runs `chezmoi apply`.  |
| `chezmoi-fwb`  | done       | Package data migrated into group vars.                       |
| `chezmoi-a2q`  | done       | Legacy `arch_packages` + `aur_packages`.                     |
| `chezmoi-c7u`  | done       | hyprland, i3 desktop profile role hooks (since removed).     |
| `chezmoi-hoz`  | done       | fish, docker, kanata, plasma_custom_wm.                      |
| `chezmoi-7tw`  | superseded | Legacy `darwin_packages`; replaced by chezmoi-97d SOLID.     |
| `chezmoi-97d`  | done       | SOLID four-layer package refactor (epic).                    |
| `chezmoi-ci1`  | done       | Phase 1: filter_plugins/catalog.py + tests.                  |
| `chezmoi-80i`  | done       | Phase 2: provider_* roles + roles/packages dispatcher.       |
| `chezmoi-88b`  | done       | Phase 3: migrate alfred (pacman=113, aur=39, zero diff).     |
| `chezmoi-vkr`  | done       | Phase 5: documentation (this README + role READMEs).         |
| `chezmoi-boe`  | active     | Epic: flat inventory + profile-list simplification.          |
| `chezmoi-87v`  | done       | Phase 1: flatten inventory (drop `inventories/personal/`).   |
| `chezmoi-ut9`  | done       | Phase 2: profiles list in host_vars + profile_apps dict.     |
| `chezmoi-6l2`  | done       | Phase 3: unprefix host_vars data keys (email/profile/...).   |
| `chezmoi-71g`  | done       | Phase 4: drop dead vars (gpu_vendor, window_managers).       |
| `chezmoi-wh5`  | active     | Phase 5: refresh documentation for the simplified layout.    |

Add more groups or roles only when they gate real behavior.
