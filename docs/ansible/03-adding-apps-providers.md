# Ansible 03 — Adding Apps, Profiles, and Providers

How to extend the package layer. For the model these steps operate on, read
[`01-architecture.md`](01-architecture.md) first. The authoritative schema
reference is [`../../ansible/README.md`](../../ansible/README.md).

## Add a new app

1. Add the **logical name** to the right intent bucket
   ([`01-architecture.md`](01-architecture.md), Layer 1):
   - OS-wide on every Arch host → `group_vars/arch.yml` (`arch_apps`).
   - OS-wide on every macOS host → `group_vars/darwin.yml` (`darwin_apps`).
   - Tied to a desktop/feature profile → the relevant key under
     `profile_apps` in `group_vars/all/profiles.yml`.

2. Decide whether it needs a **catalog entry**
   (`group_vars/all/package_catalog.yml`):
   - **No entry** if the package name is the same on the target OS's default
     provider (pacman on Arch, brew on macOS). It falls through.
   - **Add an entry** if the app is cross-OS, needs AUR/cask, or has a
     different package name per OS.

3. Verify resolution:

   ```sh
   cd ~/.local/share/chezmoi/ansible
   ansible-playbook playbooks/site.yml \
     --limit <host> --check --diff --tags packages
   ```

## Catalog schema

```yaml
package_catalog:

  # Cross-OS GUI app: per-OS keys, each a {provider, packages}.
  vivaldi:
    arch:   { provider: pacman, packages: [vivaldi, vivaldi-ffmpeg-codecs] }
    darwin: { provider: cask,   packages: [vivaldi] }

  # Roll-up: one logical name -> N concrete packages per OS.
  docker:
    arch:   { provider: pacman, packages: [docker, docker-buildx, docker-compose] }
    darwin: { provider: brew,   packages: [docker, docker-buildx, docker-compose] }

  # Multi-provider per OS: a LIST of {provider, packages} blocks.
  python:
    arch:
      - { provider: pacman, packages: [python, python-pip, python-poetry] }
      - { provider: aur,    packages: [pyrefly] }
    darwin: { provider: brew, packages: [black, python, uv] }

  # Arch-only routing (AUR). Darwin hosts skip it silently.
  pacseek:
    arch: { provider: aur, packages: [pacseek] }
```

Rules:

- Each entry has per-OS keys (`arch`, `darwin`, …). A per-OS value is either a
  single `{provider, packages}` mapping or a list of such mappings (one per
  provider) when multiple providers are needed on the same OS.
- The same provider must not appear twice in one per-OS list — merge the
  `packages:` lists. The resolver fails fast on duplicates.
- A logical name **not** in the catalog falls through to the default provider
  for the OS.
- An entry without a key for the current target OS is silently dropped
  (arch-only entries don't fail on darwin and vice versa).
- Output buckets are deduped and sorted per provider for stable diffs.

## Add a new profile

1. Add a key under `profile_apps` in `group_vars/all/profiles.yml` with its
   list of logical app names.
2. Add any per-OS routing those apps need to the catalog.
3. Opt hosts in by adding the profile name to their `profiles:` list in
   host_vars. Unknown profile names are silently ignored, so removing a
   profile from `profile_apps` won't break hosts that still reference it.

## Add a new provider

The dispatcher is Open/Closed — adding a provider touches no existing role or
inventory. To add, e.g., a Flatpak provider:

1. Create `roles/provider_flatpak/tasks/main.yml`. Accept `provider_packages`
   as input; assert OS, install idempotently, self-bootstrap if needed.
2. Add `"flatpak"` to `VALID_PROVIDERS` in `filter_plugins/catalog.py`.
3. Add `provider: flatpak` entries to the catalog apps that should use it.

No edits to `roles/packages`, existing provider roles, or inventory.
