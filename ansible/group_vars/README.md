# group_vars layout

Ansible loads vars by **group name**, not by inventory tree path. Each
inventory group that has shared vars gets a directory here with the **same
name**. Nested folders like `linux/arch/` would *not* map to the `arch`
group — only `group_vars/arch/` does.

## hosts.yml → group_vars

```text
hosts.yml                              group_vars/
─────────────────────────────────────  ────────────────────────────────
all                                    all/
│                                        main.yml              # connection, primary_user, chezmoi paths, feature defaults
│                                        package_catalog.yml   # logical name → provider (unchanged)
│                                        profiles.yml          # profile_apps bundles (unchanged)
├── linux                              (no group_vars — play target only)
│   └── arch                           arch/
│       │                                main.yml              # osid, python
│       │                                apps.yml              # arch_apps
│       └── workstation_personal       workstation_personal/
│                                        main.yml              # profiles, flags, plasma, email, profile
└── darwin                             darwin/
    │                                    main.yml              # osid, python
    │                                    apps.yml              # darwin_apps
    └── mac_work  (when onboarded)     mac_work/
                                         main.yml              # profiles, email, profile
```

## Rules of thumb

| Change this… | Edit… |
|--------------|--------|
| Packages every Arch box gets | `arch/apps.yml` |
| Packages every Mac gets | `darwin/apps.yml` |
| Package *bundles* (cli, hyprland, …) | `all/profiles.yml` + catalog |
| Which bundles a *kind* of machine uses | `workstation_personal/main.yml` or `mac_work/main.yml` (`profiles:`) |
| Feature flags / plasma / class email | machine-class `main.yml` |
| One machine’s GPU (etc.) | `host_vars/<hostname>.yml` |

Add a new machine class: create `group_vars/<class>/main.yml` and nest
`<class>` under the right OS in `hosts.yml`.
