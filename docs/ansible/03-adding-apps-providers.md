# Ansible 03 — Adding Apps, Profiles, and Providers

How to extend the package layer. For the model these steps operate on, read
[`01-architecture.md`](01-architecture.md) first. The authoritative schema
reference is [`../../ansible/README.md`](../../ansible/README.md).

## Add a new app

1. Add the **logical name** to the right intent bucket
   ([`01-architecture.md`](01-architecture.md)):
   - OS-wide on every Arch host → `group_vars/arch/apps.yml` (`os_apps`).
   - OS-wide on every macOS host → `group_vars/darwin/apps.yml` (`os_apps`).
   - Tied to a desktop/feature profile → the `apps:` list of the relevant
     profile under `profiles_catalog` in `group_vars/all/profiles.yml` (and
     the recipe's `profiles:` list).

2. Add a **catalog entry** (`group_vars/all/package_catalog.yml`). The
   catalog is exhaustive; a missing entry fails resolution.
   - Cross-OS CLI tool → `all: { provider: mise, packages: ["tool@version"] }`.
   - GUI / OS package → per-OS `arch:` / `darwin:` blocks (pacman, aur,
     brew, cask).
   - Mixed (user CLI + system package) → `all:` unioned with a per-OS block.

3. Verify resolution:

   ```sh
   cd ~/.local/share/chezmoi/ansible
   ansible-playbook playbooks/site.yml \
     --limit <host> --check --diff --tags packages
   ```

## Catalog schema

```yaml
package_catalog:

  # Cross-OS CLI via mise. Pin a concrete version; `@latest` is rejected.
  bat:
    all: { provider: mise, packages: ["bat@0.26.1"] }

  # Cross-OS GUI app: per-OS keys, each a {provider, packages}.
  vivaldi:
    arch:   { provider: pacman, packages: [vivaldi, vivaldi-ffmpeg-codecs] }
    darwin: { provider: cask,   packages: [vivaldi] }

  # Roll-up: one logical name -> N concrete packages per OS.
  docker:
    arch:   { provider: pacman, packages: [docker, docker-buildx, docker-compose] }
    darwin: { provider: brew,   packages: [docker, docker-buildx, docker-compose] }

  # `all:` unioned with a per-OS block (user python via mise, system python
  # on the OS package manager).
  python:
    all:  { provider: mise, packages: ["python@3.14.7", "uv@0.12.3"] }
    arch: { provider: pacman, packages: [python, python-gpgme] }
    darwin: { provider: brew, packages: [python] }

  # Arch-only routing (AUR). Darwin hosts skip it silently.
  pacseek:
    arch: { provider: aur, packages: [pacseek] }
```

Rules:

- Each entry has `all:` and/or per-OS keys (`arch`, `darwin`, …). A value is
  either a single `{provider, packages}` mapping or a list of such mappings
  (one per provider) when multiple providers are needed.
- `all:` is applied on every OS, then unioned with the matching per-OS block.
  The same provider must not appear twice after that union — merge the
  `packages:` lists. The resolver fails fast on duplicates.
- `provider: mise` packages must be pinned `tool@version`. Use a backend
  prefix when the short name is not in the mise registry
  (`github:sinelaw/fresh@0.4.10`).
- The catalog is exhaustive: a logical name **not** in the catalog is an
  error. There is no default-provider fall-through.
- Optional `taps: [user/repo, …]` on a `brew` or `cask` block is collected
  by the resolver and tapped before install. Formula/cask names stay
  unqualified.
- An entry without `all:` and without a key for the current target OS is
  silently dropped (arch-only entries don't fail on darwin and vice versa).
- Output buckets are deduped and sorted per provider for stable diffs.

## Add a new profile

1. Add a key under `profiles_catalog` in `group_vars/all/profiles.yml` with an
   `apps:` list of logical app names (and an optional `services:` list).
2. Add any per-OS routing those apps/services need to the catalogs.
3. Opt machines in by adding the profile name to the `profiles:` list on the
   relevant recipe (`recipes/personal_workstation.yml`,
   `recipes/mac_turing.yml`, …), or override on the host.
   Unknown profile names are silently ignored, so removing a profile from
   `profiles_catalog` won't break hosts that still reference it.

## Add a new provider

To add, e.g., a Flatpak provider:

1. Create `roles/packages/tasks/flatpak.yml`. Accept `provider_packages` as
   input; assert OS, install idempotently, self-bootstrap if needed.
2. Add an `include_tasks` block in `roles/packages/tasks/main.yml`.
3. Add `"flatpak"` to `VALID_PROVIDERS` in `filter_plugins/catalog.py`.
4. Add `provider: flatpak` entries to the catalog apps that should use it.
