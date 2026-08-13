# Role: services

Cross-OS service (daemon) enablement. Sibling to `packages`: packages install
binaries, this role runs daemons. Runs after `packages` and `chezmoi`.

```
Intent     os_services + profiles_catalog[].services (via profiles:) + recipe services:
Catalog    group_vars/all/service_catalog.yml
Resolve    resolve_services filter
Managers   tasks/{systemd,brew_services}.yml
```

## Catalog schema

- `manager: systemd` — `name`, `scope` (system|user, default system),
  `enabled` (bool, default true), optional `state`.
- `manager: brew` — `name`, `state` (default started). No `scope`/`enabled`.
- Per-OS value is one block or a list of blocks (e.g. libvirt → two sockets).
- Exhaustive catalog; missing OS key = silent skip.

Does not install packages, render unit files, or replace roles that template
their own units with handler wiring (`kanata`, `plasma_custom_wm`).
