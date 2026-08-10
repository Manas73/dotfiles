# Role: macos_defaults

Applies macOS preference keys via `community.general.osx_defaults` (the
`defaults` subsystem documented at https://macos-defaults.com).

Ported intent from the archived nix-darwin
`hosts/darwin_system.nix` `system.defaults` block.

## Responsibilities

- Skip non-Darwin hosts.
- Union `macos_defaults` (OS group) + `macos_defaults_extra` (recipe).
- Write each entry; notify Dock / Finder / SystemUIServer handlers when
  entries set `notify:`.

## Does not

- Install packages (roles/packages).
- Manage shell / Touch ID PAM (system role or future work).
- Manage raw plists under `~/Library/Preferences` as files.

## Inputs

| Var | Source | Purpose |
|-----|--------|---------|
| `macos_defaults` | `group_vars/darwin/macos_defaults.yml` | Shared Darwin prefs |
| `macos_defaults_extra` | recipe (optional) | Per-recipe additions |

Each list item:

```yaml
- domain: com.apple.dock    # default NSGlobalDomain
  key: autohide
  type: bool                # bool | string | int | float | array | dict
  value: true
  host: currentHost         # optional; ByHost prefs
  notify:                   # optional handler names
    - Restart Dock
```

## Tags

Play tags: `system`, `macos`, `defaults`.
