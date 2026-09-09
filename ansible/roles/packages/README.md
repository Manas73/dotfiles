# Role: packages

Cross-OS package installation. Resolves logical app names through the catalog
and installs via provider task files.

## Architecture

```
Intent       os_apps + profiles_catalog[].apps (via recipe profiles:)
Catalog      group_vars/all/package_catalog.yml
Resolve      THIS ROLE (resolve_catalog filter)
Providers    tasks/{pacman,aur,brew,mise,uv}.yml  # brew = formulae + casks
Post-install tasks/post_install.yml + tasks/post_install/<action>.yml
```

## Responsibilities

1. Map `ansible_facts.os_family` → `packages_target_os` / default provider
   via `os_family_map` (`group_vars/all/os_providers.yml`).
2. Aggregate `os_apps` + recipe `profiles` → `profiles_catalog[].apps`.
3. Resolve through the catalog into per-provider buckets.
4. Include the matching provider task file for each non-empty bucket
   (fixed order: pacman → aur → brew → mise → uv). Homebrew formulae and
   casks use community.general.homebrew / homebrew_cask. AUR installs via
   `yay` (bootstraps `yay-bin` from the AUR if missing). mise installs
   pinned CLI tools into the user mise prefix (`mise use --global --pin`).
   uv installs Python CLIs via `uv tool install --quiet`.
5. Run catalog `post_install` actions (typed; currently `chmod` and
   `desktop_exec`) after every provider so package-dropped files can be
   patched in the same play. No-op when the resolved list is empty.

## Does not

- Manage configuration, services, or dotfiles beyond catalog-declared
  `post_install` actions (mise.yml writes pins into
  `~/.config/mise/config.toml` additively via `mise use --global`; Chezmoi
  does not own that file).
- Own package *lists* (`group_vars/<os>/apps.yml` and recipes).

## Inputs

- `package_catalog` — from `group_vars/all/package_catalog.yml`
- `os_apps` — OS-family intent list (same var name on every OS group)
- `profiles` + `profiles_catalog` — recipe profile opt-in (recipe loaded by playbook)
- `os_family_map` — from `group_vars/all/os_providers.yml`
- Provider defaults in `defaults/main.yml`

## Live output

yay and mise run with stdout on a PTY into
`~/.cache/dotfiles/ansible-packages.log`. The `live_log` callback tails
that file and prints each new line as it arrives, or `| … still running`
after 10s of silence. Override the path with `ANSIBLE_PACKAGES_LIVE_LOG`.

## Outputs (set_fact)

- `packages_target_os`, `packages_default_provider`
- `packages_logical_apps`, `packages_resolved`
