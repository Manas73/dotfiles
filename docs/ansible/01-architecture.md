# Ansible 01 — Package Architecture

The Ansible layer installs packages through a four-layer model with one
direction of dependency. Each layer has a single responsibility and depends
only on the schema of the layer below it.

> The authoritative, in-tree reference is
> [`../../ansible/README.md`](../../ansible/README.md). This page is the
> orientation; that file has the full schema, role contracts, and edge cases.

```text
Layer 1: Intent       <group>_apps / profile_apps   (lists of logical names)
Layer 2: Catalog      group_vars/all/package_catalog.yml
Layer 3: Dispatcher   roles/packages (orchestrator + OCP dispatch loop)
Layer 4: Providers    roles/provider_{pacman,aur,brew,cask}
```

## Layer 1 — Intent

Pure lists of *logical* app names. They know nothing about pacman, AUR, brew,
or cask. Two sources feed the orchestrator:

1. **OS-family lists** — `arch_apps` (`group_vars/arch.yml`) and
   `darwin_apps` (`group_vars/darwin.yml`).
2. **Profile bundles** — `profile_apps` in `group_vars/all/profiles.yml`. A
   host opts into a profile by listing it in `profiles:` in its host_vars;
   the dispatcher unions the matching `profile_apps[<name>]` lists on top of
   the OS-family list.

Profiles are **not** inventory groups — host_vars is the single source of
truth per host. Available profiles:

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

## Layer 2 — Catalog

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

## Layer 3 — Dispatcher

`roles/packages` is the orchestrator. It:

1. Computes the target OS (`arch`/`darwin`) and default provider.
2. Aggregates logical names: OS-family list ∪ each opted-in profile's list.
3. Resolves them through the catalog (`resolve_catalog` filter) into
   `{provider: [pkg, …]}`.
4. Dispatches dynamically: for each provider bucket, `include_role:
   provider_<name>`.

Step 4 is the Open/Closed pivot — there is no hardcoded list of providers, so
adding one requires zero edits here.

## Layer 4 — Providers

One role per package manager, all obeying the same contract: accept
`provider_packages`, no-op on empty input, assert the OS family, install
idempotently (`state: present`), self-bootstrap where needed, and have no
side effects beyond installation.

| Role              | OS        | Bootstrap                                       |
|-------------------|-----------|-------------------------------------------------|
| `provider_pacman` | Archlinux | pacman is in the base system; verifies it. Folds in multilib. |
| `provider_aur`    | Archlinux | Clones and builds `yay-bin` when yay is missing. |
| `provider_brew`   | Darwin    | Runs the official Homebrew installer (`NONINTERACTIVE=1`). |
| `provider_cask`   | Darwin    | None; relies on `provider_brew`.                |

## How it ties back to Chezmoi

The site playbook runs packages first, then the `chezmoi` role renders
`~/.config/chezmoi/chezmoi.toml` from inventory vars and runs `chezmoi
apply`, then system roles (fish, docker, kanata, plasma). Packages and
dotfiles never duplicate each other.
