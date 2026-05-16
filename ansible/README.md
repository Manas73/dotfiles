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
├── ansible.cfg                  # filter_plugins = filter_plugins
├── filter_plugins/
│   └── catalog.py               # resolve_catalog jinja filter
├── inventories/
│   └── personal/
│       ├── hosts.yml
│       ├── group_vars/
│       │   ├── all/             # directory form
│       │   │   ├── main.yml
│       │   │   └── package_catalog.yml
│       │   ├── linux.yml
│       │   ├── darwin.yml
│       │   ├── arch.yml
│       │   ├── hyprland.yml
│       │   ├── i3.yml
│       │   └── gaming.yml
│       └── host_vars/
│           ├── alfred.yml
│           └── mac-placeholder.yml
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
    ├── plasma_custom_wm/
    ├── hyprland/
    └── i3/
```

The legacy roles `arch_packages`, `aur_packages`, and `darwin_packages` have
been deleted. Their behavior is fully replaced by the four-layer model below.

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

One list per inventory group, in `group_vars/<group>.yml`:

| Group     | Var             |
|-----------|-----------------|
| `linux`   | `linux_apps`    |
| `arch`    | `arch_apps`     |
| `darwin`  | `darwin_apps`   |
| `hyprland`| `hyprland_apps` |
| `i3`      | `i3_apps`       |
| `gaming`  | `gaming_apps`   |

These are pure lists of logical app names. They know nothing about pacman,
AUR, brew, or cask. Gaming packages install only when `gaming_enabled: true`
is set per host.

### Layer 2: Catalog

`inventories/personal/group_vars/all/package_catalog.yml` maps logical app
names to concrete per-OS install instructions.

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
3. Aggregate `<group>_apps` lists from every inventory group the host is in,
   using explicit `group_names` membership checks (not just var presence)
   so a host in `arch` but not `hyprland` does not pick up Hyprland apps.
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

1. Add the logical name to the relevant `<group>_apps` list.
2. If the app is cross-OS, or needs a non-default provider on Arch (AUR),
   add a catalog entry. Otherwise it falls through to the default provider
   for the OS and needs no catalog entry.
3. Verify the resolution:

   ```sh
   ansible-playbook -i inventories/personal/hosts.yml playbooks/site.yml \
     --limit <host> --check --diff --tags packages
   ```

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
   comments in the file for the full checklist.
3. In `inventories/personal/hosts.yml`, uncomment the `mac-placeholder`
   block under the `darwin` group and replace it with your hostname.
4. If on an Intel Mac, set `provider_brew_path: /usr/local/bin/brew` and
   `provider_cask_brew_path: /usr/local/bin/brew` in host_vars.
5. Optionally trim `darwin_apps` in `group_vars/darwin.yml` to taste.
6. Dry-run first:

   ```sh
   ansible-playbook -i inventories/personal/hosts.yml playbooks/site.yml \
     --limit <your-hostname> --check --diff --tags packages
   ```

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
| `system`   | sudoers, fish, docker, kanata, plasma.               |
| `desktop`  | Hyprland, i3 profile hooks.                          |

## Usage

```sh
cd ansible

# Full provisioning run.
ansible-playbook -i inventories/personal/hosts.yml playbooks/site.yml \
  --limit alfred --ask-become-pass

# Just packages, any OS.
ansible-playbook ... --tags packages

# Just AUR.
ansible-playbook ... --tags aur

# Just dotfiles.
ansible-playbook -i inventories/personal/hosts.yml playbooks/dotfiles.yml \
  --limit alfred
```

Syntax check:

```sh
ansible-playbook -i inventories/personal/hosts.yml playbooks/site.yml --syntax-check
ansible-playbook -i inventories/personal/hosts.yml playbooks/dotfiles.yml --syntax-check
```

## Status

| Issue          | Status | Description                                                  |
|----------------|--------|--------------------------------------------------------------|
| `chezmoi-g19`  | done   | chezmoi role renders chezmoi.toml and runs `chezmoi apply`.  |
| `chezmoi-fwb`  | done   | Package data migrated into group vars.                       |
| `chezmoi-a2q`  | done   | Legacy `arch_packages` + `aur_packages`.                     |
| `chezmoi-c7u`  | done   | hyprland, i3 desktop profile roles.                          |
| `chezmoi-hoz`  | done   | fish, docker, kanata, plasma_custom_wm.                      |
| `chezmoi-7tw`  | done   | Legacy `darwin_packages`.                                    |
| `chezmoi-97d`  | active | SOLID four-layer package refactor (epic).                    |
| `chezmoi-ci1`  | done   | Phase 1: filter_plugins/catalog.py + tests.                  |
| `chezmoi-80i`  | done   | Phase 2: provider_* roles + roles/packages dispatcher.       |
| `chezmoi-88b`  | done   | Phase 3: migrate alfred (pacman=113, aur=39, zero diff).     |
| `chezmoi-vkr`  | active | Phase 5: documentation (this README + role READMEs).         |

Add more groups or roles only when they gate real behavior.
