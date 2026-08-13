# Role: services

Cross-OS service (daemon) enablement. Sibling to `packages`: packages install
binaries, this role runs daemons. Runs after `packages` and `chezmoi`.

```
Intent     os_services + profiles_catalog[].services (via profiles:) + recipe services:
Catalog    group_vars/all/service_catalog.yml
Resolve    resolve_services filter
Managers   tasks/{systemd,brew_services,command}.yml
```

## Catalog schema

- `manager: systemd` — `name`, `scope` (system|user, default system),
  `enabled` (bool, default true), optional `state`.
- `manager: brew` — `name`, `state` (default started). No `scope`/`enabled`.
- `manager: command` (macOS) — self-servicing tools that own their daemon via
  CLI subcommands (e.g. `skhd`/`yabai --install-service` + `--start-service`),
  not `brew services`. Keys: `name`, `start` (required), `install` + `creates`
  (optional, idempotent install), `restart`, `stop`, `state` (default started).
  No `scope`/`enabled`.
- Per-OS value is one block or a list of blocks (e.g. libvirt → two sockets).
- Exhaustive catalog; missing OS key = silent skip.

Does not install packages, render unit files, or replace roles that template
their own units with handler wiring (`kanata`, `plasma_custom_wm`).
