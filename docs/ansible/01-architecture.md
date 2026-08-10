# Ansible 01 — Package Architecture

The Ansible layer installs packages through intent lists, a catalog, and one
packages role with per-manager task files.

> The authoritative, in-tree reference is
> [`../../ansible/README.md`](../../ansible/README.md). This page is the
> orientation; that file has the full schema, role contracts, and edge cases.

```text
Intent       <group>_apps / profile_apps   (lists of logical names)
Catalog      group_vars/all/package_catalog.yml
packages     roles/packages (resolve + tasks/{pacman,aur,brew,cask}.yml)
```

## Intent

Pure lists of *logical* app names. They know nothing about pacman, AUR, brew,
or cask. Two sources feed the packages role:

1. **OS-family lists** — `arch_apps` (`group_vars/arch/apps.yml`) and
   `darwin_apps` (`group_vars/darwin/apps.yml`).
2. **Profile bundles** — `profile_apps` in `group_vars/all/profiles.yml`. A
   host opts into a profile via the `profiles:` list on its **machine class**
   (nested under OS in `hosts.yml`; vars in `group_vars/workstation_personal/`,
   `group_vars/mac_work/`, …), optionally overridden in host_vars; the
   packages role unions the matching `profile_apps[<name>]` lists on top of
   the OS-family list.

Profiles are **not** inventory groups — the machine-class (or host)
`profiles:` list is the single source of truth for package-bundle
membership. Available profiles:

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

`group_vars/all/package_catalog.yml` maps each logical name to concrete,
per-OS install instructions (provider + package list). It handles three
patterns:

- **Cross-OS name mapping** — e.g. `aws-cli` → `aws-cli-v2` on AUR,
  `awscli` on brew.
- **Roll-ups** — one logical name expands to N concrete packages per OS
  (`docker`, `nodejs`, `python`, the JetBrains IDEs with their `-jre`
  companions, …).
- **Multi-provider per OS** — a per-OS value can be a list of
  `{provider, packages}` blocks (e.g. most of `python` from pacman plus
  `pyrefly` from AUR on Arch).

A logical name **not** in the catalog falls through to the default provider
for the OS (`pacman` on Arch, `brew` on Darwin). That's why everyday
same-name packages need no catalog entry.

Full schema and rules: [`03-adding-apps-providers.md`](03-adding-apps-providers.md).

## packages role

`roles/packages`:

1. Computes the target OS (`arch`/`darwin`) and default provider.
2. Aggregates logical names: OS-family list ∪ each opted-in profile's list.
3. Resolves them through the catalog (`resolve_catalog` filter) into
   `{provider: [pkg, …]}`.
4. Includes provider task files in fixed order for each non-empty bucket:
   pacman → aur → brew → cask.

### Provider task files

| File | OS | Bootstrap |
|------|-----|-----------|
| `tasks/pacman.yml` | Archlinux | Verifies pacman; folds in multilib. |
| `tasks/aur.yml` | Archlinux | Builds `yay-bin` when yay is missing. |
| `tasks/brew.yml` | Darwin | Official Homebrew installer (`NONINTERACTIVE=1`). |
| `tasks/cask.yml` | Darwin | None; relies on brew. |

Each accepts `provider_packages`, no-ops on empty input, asserts the OS
family, and installs idempotently.

## How it ties back to Chezmoi

The site playbook runs packages first, then the `chezmoi` role renders
`~/.config/chezmoi/chezmoi.toml` from inventory vars and runs `chezmoi
apply`, then system wiring (`roles/system`: fish, docker, libvirt) and
specialty roles (kanata, plasma). Packages and dotfiles never duplicate
each other.
