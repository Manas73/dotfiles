# group_vars layout

One directory per **inventory group name** (Ansible requirement). Inventory
groups are **OS only** (`arch`, `darwin`, …). Machine recipes live in
`../recipes/`, not here.

```text
hosts.yml                         group_vars/              recipes/
───────────────────────────────   ──────────────────────   ────────────────────
all                               all/
│                                   main.yml
│                                   package_catalog.yml
│                                   profiles.yml
│                                   os_providers.yml
├── linux                         (play target; no vars)
│   └── arch                      arch/
│         hosts:                    main.yml   # osid, python
│           alfred:                 apps.yml   # os_apps
│             recipe: personal_…  ─────────────────────────► personal_workstation.yml
│             gpu: nvidia
└── darwin                        darwin/
      hosts:                        main.yml
        mbp:                        apps.yml
          recipe: mac_turing        macos_defaults.yml   # osx_defaults
                                  ─────────────────────────► mac_turing.yml
```

## Add a host

1. Under `arch` or `darwin` in `hosts.yml`, set `recipe:` + `gpu:` (and any
   other host deltas).
2. Done — no new group_vars, no host_vars file unless you prefer one.

## Add an OS family

1. Inventory group under `linux` or as a top-level sibling (see `hosts.yml`).
2. `group_vars/<os>/main.yml` — `osid`, `ansible_python_interpreter`.
3. `group_vars/<os>/apps.yml` — `os_apps: […]` (same variable name always).
4. Row in `all/os_providers.yml` (`os_family` → `target_os` + default provider).
5. Catalog keys / provider task files if the package manager is new.
6. Playbook `hosts:` patterns if you need OS-scoped plays.

## Add a recipe

See `../recipes/README.md`.
