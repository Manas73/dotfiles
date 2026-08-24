# Ansible 01 — Package Architecture

The Ansible layer installs packages through intent lists, a catalog, and one
packages role with per-manager task files.

> The authoritative, in-tree reference is
> [`../../ansible/README.md`](../../ansible/README.md). This page is the
> orientation; that file has the full schema, role contracts, and edge cases.

```text
Intent       os_apps + profiles_catalog[].apps (via recipe profiles:)
Catalog      group_vars/all/package_catalog.yml
packages     roles/packages (resolve + tasks/{pacman,aur,brew,mise}.yml)
```

## Intent

Pure lists of *logical* app names. They know nothing about pacman, AUR, brew,
cask, or mise. Two sources feed the packages role:

1. **OS-family list** — `os_apps` in `group_vars/<os>/apps.yml` (same variable
   name on every OS group: `arch`, `darwin`, …).
2. **Profile bundles** — `profiles_catalog[<name>].apps` (and optional
   `.services`) in `group_vars/all/profiles.yml`. A
   host opts into profiles via `profiles:` on its **recipe**
   (`recipes/<name>.yml`), loaded by the playbook at the start of each play.

Profiles are **not** inventory groups. Available profiles:

| Profile       | Scope    | What it brings                                  |
|---------------|----------|-------------------------------------------------|
| `cli`         | cross-OS | Shell, navigation, editors, version control, runtimes. |
| `cloud`       | cross-OS | AWS / GCP toolchain.                            |
| `development` | cross-OS | IDEs, editors, dev tools (JetBrains, Postman, …). |
| `fonts`       | Linux    | ttf-* font set.                                 |
| `gaming`      | Linux    | Steam, Lutris, umu-launcher.                    |
| `hyprland`    | Linux    | Hyprland window manager and adjacent tools.     |
| `i3`          | Linux    | i3 + X11 ecosystem (xclip, xorg-xev, …).        |
| `kde`         | Linux    | KDE Plasma desktop integration.                 |

## Catalog

`group_vars/all/package_catalog.yml` maps each logical name to concrete
install instructions (provider + package list). It handles:

- **Cross-OS CLI via mise** — `all: { provider: mise, packages: ["bat@0.26.1"] }`.
  Same pin on every OS. `all:` unions with an optional per-OS block.
- **Cross-OS GUI name mapping** — e.g. `vivaldi` → pacman on Arch, cask on Darwin.
- **Roll-ups** — one logical name expands to N concrete packages
  (`docker`, JetBrains IDEs with their `-jre` companions, …).
- **Multi-provider** — `python` is mise (user toolchain) plus pacman/brew
  (system interpreter).

The catalog is exhaustive: a logical name **not** in the catalog is an error.
An entry with neither `all:` nor a key for the current OS is silently skipped.

OS detection uses `group_vars/all/os_providers.yml` (`os_family_map`).

Full schema and rules: [`03-adding-apps-providers.md`](03-adding-apps-providers.md).

## packages role

`roles/packages`:

1. Maps `ansible_facts.os_family` → `packages_target_os` / default provider.
2. Aggregates `os_apps` ∪ each opted-in profile's list.
3. Resolves them through the catalog (`resolve_catalog` filter) into
   `{packages: {provider: [pkg, …]}, taps: {provider: [tap, …]}}`.
4. Includes provider task files in fixed order for each non-empty bucket:
   pacman → aur → brew (formulae + casks) → mise.

### Provider task files

| File | OS | Bootstrap |
|------|-----|-----------|
| `tasks/pacman.yml` | Archlinux | Verifies pacman; folds in multilib. |
| `tasks/aur.yml` | Archlinux | Builds `yay-bin` when yay is missing. |
| `tasks/brew.yml` | Darwin | Official installer; community.general.homebrew / homebrew_tap / homebrew_cask. |
| `tasks/mise.yml` | all | Requires `mise` on PATH. `mise use --global --pin` for `tool@version` specs. |

Each accepts `provider_packages`, no-ops on empty input, asserts the OS
family (except mise), and installs idempotently.

## How it ties back to Chezmoi

The site playbook loads the host's recipe, runs packages, then the `chezmoi`
role renders `~/.config/chezmoi/chezmoi.toml` from inventory + recipe vars
and runs `chezmoi apply`, then system wiring and specialty roles. Packages
and dotfiles never duplicate each other.
