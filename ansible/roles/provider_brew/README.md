# Role: provider_brew

Layer 4 provider for Homebrew formulae (macOS CLI / library packages).
Casks are handled by the separate `provider_cask` role.

## Liskov contract

- **Input**: `provider_packages` (list[str]) — concrete brew formula names.
- **Empty input**: no-op.
- **Asserts**: host `os_family == "Darwin"`.
- **Idempotent**: `community.general.homebrew state: present`.
- **Self-bootstraps**: installs Homebrew via the official script with
  `NONINTERACTIVE=1 CI=1` when `brew` is absent.
- **Side effects**: only Homebrew install + package install.

## Architecture support

`provider_brew_path` defaults to `/opt/homebrew/bin/brew` (Apple Silicon).
On Intel macs, override in host_vars:

```yaml
provider_brew_path: "/usr/local/bin/brew"
```

## Inputs / knobs

- `provider_packages` (required) — set by the orchestrator.
- `provider_brew_path: /opt/homebrew/bin/brew` — bootstrap detection path.
- `provider_brew_update: true` — runs `brew update` before installing.

## Tags

`packages`, `brew`, `darwin`.
