# Ansible

Provisioning layer for OS packages, services, groups, and Chezmoi configuration.

See `docs/ansible/02-onboarding.md` for adding a new machine and
`docs/history/ANSIBLE_MIGRATION_PLAN.md` for the original migration plan.

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
├── ansible.cfg
├── hosts.yml                    # OS groups + hosts (recipe + gpu on each host)
├── recipes/                     # machine recipes (NOT inventory groups)
│   ├── README.md
│   ├── personal_workstation.yml
│   └── mac_turing.yml
├── group_vars/                  # one dir per OS inventory group
│   ├── README.md
│   ├── all/
│   │   ├── main.yml             # connection, primary_user, chezmoi paths, feature defaults
│   │   ├── os_providers.yml     # facts.os_family → target_os + default provider
│   │   ├── package_catalog.yml  # logical name → per-OS install instructions
│   │   └── profiles.yml         # profile_apps (cli/cloud/…/kde)
│   ├── arch/
│   │   ├── main.yml             # osid, python
│   │   └── apps.yml             # os_apps
│   └── darwin/
│       ├── main.yml
│       ├── apps.yml             # os_apps
│       └── macos_defaults.yml   # osx_defaults prefs (https://macos-defaults.com)
├── playbooks/
│   ├── site.yml
│   ├── dotfiles.yml
│   ├── validate.yml
│   └── tasks/load_recipe.yml    # loads recipes/<recipe>.yml
└── roles/
    ├── packages/
    ├── system/
    ├── macos_defaults/          # Darwin user defaults
    ├── sudoers/
    ├── chezmoi/
    ├── kanata/
    └── plasma_custom_wm/
```

Mental model:

| Question | Answer |
|----------|--------|
| Add a host? | `hosts.yml` under an OS group: `recipe:` + `gpu:` |
| Change a kind of machine? | `recipes/<name>.yml` |
| OS-wide packages? | `group_vars/<os>/apps.yml` (`os_apps`) |
| Package bundles? | `group_vars/all/profiles.yml` + recipe `profiles:` |
| macOS prefs (defaults)? | `group_vars/darwin/macos_defaults.yml` (+ recipe `macos_defaults_extra`) |
| New OS family? | inventory group + `group_vars/<os>/` + `os_providers.yml` row |

- Inventory groups are **OS only** (`linux → arch`, `darwin`). No machine-class groups.
- Each host sets `recipe:` (loads `recipes/<recipe>.yml`) and host deltas (`gpu`, …).
- `primary_user` defaults to `ansible_facts['user_id']` in `group_vars/all`.
- Provider install logic: `roles/packages/tasks/{pacman,aur,brew,cask}.yml`.

## Package Architecture

```text
Intent       os_apps + profile_apps (via recipe profiles:)
Catalog      group_vars/all/package_catalog.yml
packages     roles/packages
```

### Layer 1: Intent

1. **OS-family list** — same variable name on every OS group:

   | Group    | Var       | File                         |
   |----------|-----------|------------------------------|
   | `arch`   | `os_apps` | `group_vars/arch/apps.yml`   |
   | `darwin` | `os_apps` | `group_vars/darwin/apps.yml` |

2. **Profile bundles** in `group_vars/all/profiles.yml`:

   ```yaml
   profile_apps:
     cli:          [atuin, bat, fish, fzf, neovim, git, go, nodejs, python, ...]
     cloud:        [aws-cli, aws-session-manager-plugin, cloud-sql-proxy, google-cloud-cli]
     development:  [beads, datagrip, gitkraken, opencode, postman, pycharm, sublime-text, webstorm, zed, ...]
     fonts:        [ttf-dejavu, ttf-fira-code, ...]
     gaming:       [steam, lutris, umu-launcher]
     hyprland:     [waybar, hyprland, hyprlock, matugen, ...]
     i3:           [i3-wm, picom, polybar, sxhkd, xclip, ...]
     kde:          [dolphin, gwenview, plasma-x11-session, ...]
   ```

   | Profile        | Scope     | Purpose                                              |
   |----------------|-----------|------------------------------------------------------|
   | `cli`          | cross-OS  | Shell experience, navigation, editors, runtimes.     |
   | `cloud`        | cross-OS  | AWS / GCP toolchain.                                 |
   | `development`  | cross-OS  | IDEs, editors, and dev tools (JetBrains, Postman, …).|
   | `fonts`        | Linux     | ttf-* font set. macOS uses homebrew-cask-fonts.      |
   | `gaming`       | Linux     | Steam, Lutris, umu-launcher.                         |
   | `hyprland`     | Linux     | Hyprland window manager and adjacent tools.          |
   | `i3`           | Linux     | i3 + X11 ecosystem (xclip, xorg-xev, ...).           |
   | `kde`          | Linux     | KDE Plasma desktop integration.                      |

   A recipe opts into profiles via `profiles:`:

   ```yaml
   # recipes/personal_workstation.yml
   profiles:
     - cli
     - cloud
     - development
     - hyprland
     - i3
   ```

   Profiles are NOT inventory groups. The dispatcher unions `os_apps` with
   `profile_apps` for every name in the recipe's `profiles:` list. Unknown
   profile names are silently ignored.

All sources are pure lists of logical app names. They know nothing about
pacman, AUR, brew, or cask.

### Layer 2: Catalog

`group_vars/all/package_catalog.yml` maps logical app names to concrete
per-OS install instructions.

Schema:

```yaml
package_catalog:

  # Cross-OS GUI app: per-OS keys, each holding a provider and a list of
  # concrete packages. Both keys are independent and can contain multiple
  # packages -- this is the "roll-up" pattern.
  vivaldi:
    arch:   { provider: pacman, packages: [vivaldi, vivaldi-ffmpeg-codecs] }
    darwin: { provider: cask,   packages: [vivaldi] }

  # Roll-up: one logical name expands to N concrete packages per OS.
  # Differences between OSes are encoded inline. Used for docker, nodejs,
  # the JetBrains IDEs (with their -jre companion on Arch), etc.
  docker:
    arch:   { provider: pacman, packages: [docker, docker-buildx, docker-compose] }
    darwin: { provider: brew,   packages: [docker, docker-buildx, docker-compose] }

  nodejs:
    arch:   { provider: pacman, packages: [nodejs, npm, nvm] }
    darwin: { provider: brew,   packages: [node, nvm] }

  # Third-party tap: declare taps next to the provider. Formula names
  # stay unqualified; brew.yml writes them into the Brewfile.
  fresh-editor:
    darwin: { provider: brew, packages: [fresh-editor], taps: [sinelaw/fresh] }

  # Multi-provider per OS: the per-OS value is a LIST of {provider, packages}
  # blocks. Use this when one logical name installs packages from different
  # providers on the same OS (e.g. most of python from pacman, plus pyrefly
  # from AUR on Arch).
  python:
    arch:
      - { provider: pacman, packages: [python, python-pip, python-poetry] }
      - { provider: aur,    packages: [pyrefly] }
    darwin: { provider: brew, packages: [black, python, uv] }

  # Arch-only routing: AUR package that wouldn't be reachable via plain
  # `pacman -S`. Has only an `arch:` key; darwin hosts skip it silently.
  pacseek:
    arch: { provider: aur, packages: [pacseek] }
```

Rules:

- Each entry has per-OS keys (`arch`, `darwin`, ...). A per-OS value is
  either a single `{provider, packages}` mapping or a list of such mappings
  (one per provider) when multiple providers are needed on the same OS.
- The same provider must not appear twice in one per-OS list — merge the
  `packages:` lists instead. The resolver fails fast on duplicates.
- A logical name **not** in the catalog falls through to the default
  provider for the target OS (`pacman` on arch, `brew` on darwin). This is
  why everyday Arch packages like `alacritty`, `networkmanager`, and most
  pacman fonts do not need catalog entries.
- An entry without a key for the current `target_os` is silently dropped, so
  arch-only entries (like `pacseek`) don't fail on darwin and vice versa.
- Output buckets are deduped and sorted per provider for stable diffs.

The catalog currently has ~45 entries: cross-OS GUI apps (vivaldi,
1password, firefox, vlc, slack, zoom, google-chrome, dropbox), cross-OS
runtime/dev bundles (docker, nodejs, python, datagrip, pycharm,
webstorm), AUR routing for Arch-only packages (pacseek, redshift, ...),
and miscellaneous Arch / darwin name-mapping (e.g. `aws-cli` ->
`aws-cli-v2` on AUR, `awscli` on brew).

### packages role (resolve + install)

`roles/packages` does the following (see `roles/packages/tasks/main.yml`):

1. Map `ansible_facts['os_family']` → `packages_target_os` and
   `packages_default_provider` via `os_family_map`
   (`group_vars/all/os_providers.yml`).
2. Aggregate logical app names: `os_apps` unioned with each
   `profile_apps[<name>]` for every entry in the recipe's `profiles:` list.
   Unknown profile names are silently ignored via `extract(..., default=[])`.
3. Resolve the aggregated list through the catalog via the `resolve_catalog`
   filter, producing
   `packages_resolved = {packages: {provider: [pkg, ...]}, taps: {provider: [tap, ...]}}`.
4. Include provider task files in fixed order for each non-empty bucket:
   `pacman.yml` → `aur.yml` → `brew.yml` (formulae + casks).

### Provider task files

Each file under `roles/packages/tasks/` installs for one package manager:

| File | OS | Bootstrap behavior |
|------|-----|--------------------|
| `pacman.yml` | Archlinux | Verifies pacman; optional `-Sy` / `-Syu`. |
| `aur.yml` | Archlinux | Clones `yay-bin` and builds it when yay is missing. |
| `brew.yml` | Darwin | Official installer to `/opt/homebrew` (or `/usr/local`); one Brewfile / `brew bundle`. |

Shared contract: input `provider_packages` (list), no-op when empty, assert
OS family, idempotent install, side effects limited to packages.

Multilib is a pacman *repo*, not a separate manager, so `steam` and friends
route to `provider: pacman` (with multilib enabled in `/etc/pacman.conf`).

## Adding a New App

1. Pick the right intent bucket and add the logical name there:
   - OS-wide on every Arch host: `group_vars/arch/apps.yml` (`os_apps`).
   - OS-wide on every macOS host: `group_vars/darwin/apps.yml` (`os_apps`).
   - Tied to a desktop or feature profile: the relevant key under
     `profile_apps` in `group_vars/all/profiles.yml` (and the recipe's
     `profiles:` list).
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

To add, for example, a Flatpak provider:

1. Create `roles/packages/tasks/flatpak.yml`. Accept `provider_packages`
   as input. Assert OS, install idempotently, self-bootstrap if needed.
2. Add an `include_tasks` block for it in `roles/packages/tasks/main.yml`.
3. Add `"flatpak"` to `VALID_PROVIDERS` in `filter_plugins/catalog.py`.
4. Add `provider: flatpak` entries to catalog apps that should use it.

## Adding a Host

Same recipe as an existing machine (e.g. second personal Arch box):

```yaml
# hosts.yml under linux → arch
arch:
  hosts:
    alfred:
      recipe: personal_workstation
      gpu: nvidia
    desk2:
      recipe: personal_workstation
      gpu: amd
```

Dry-run: `ansible-playbook playbooks/site.yml --limit desk2 --check --diff`

## Mac Onboarding

Recipe: `recipes/mac_turing.yml` (`profile: turing`). `osid` from
`group_vars/darwin/`. Add under `darwin` in `hosts.yml`:

```yaml
darwin:
  hosts:
    <your-hostname>:
      recipe: mac_turing
      gpu: none
      # packages_brew_path: /usr/local/bin/brew   # Intel only
```

Optionally trim `os_apps` in `group_vars/darwin/apps.yml`. Dry-run with
`--limit <your-hostname> --check --diff --tags packages`.

Full Mac bootstrap (Homebrew, ansible-core) is tracked by `chezmoi-qxl`.

## Adding an OS Family

1. Inventory group (under `linux` or top-level).
2. `group_vars/<os>/main.yml` + `apps.yml` with `os_apps:`.
3. Row in `group_vars/all/os_providers.yml`.
4. Catalog / provider tasks if the package manager is new.
5. Playbook `hosts:` patterns if needed for OS-scoped plays.

## Adding a Recipe

Copy `recipes/personal_workstation.yml` (or `mac_turing.yml`), edit
`profiles:` / `apps` / flags / email / `profile`, point hosts at
`recipe: <new-name>`.

## Tags

| Tag        | Scope                                                |
|------------|------------------------------------------------------|
| `packages` | Whole packages role (all providers).                 |
| `pacman`   | Pacman task file only.                               |
| `aur`      | AUR task file only.                                  |
| `brew`     | Homebrew formulae + casks (one Brewfile).            |
| `cask`     | Same as `brew` (merged job).                         |
| `arch`     | All arch-OS package work.                            |
| `darwin`   | All darwin-OS package work.                          |
| `upgrade`  | `pacman -Syu` task.                                  |
| `dotfiles` | Chezmoi render + apply.                              |
| `chezmoi`  | Alias for the chezmoi role play (same as `dotfiles`).|
| `system`   | sudoers, system role, kanata, plasma (umbrella).     |
| `sudoers`  | sudoers drop-in only.                                |
| `fish`     | Fish login shell only.                               |
| `docker`   | Docker group/socket only.                            |
| `libvirt`  | libvirt groups/sockets only.                         |
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
