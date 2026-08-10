# Machine recipes

A **recipe** is a shared “kind of machine” config: package profiles, feature
flags, plasma WM, class-level chezmoi fields (`profile`, `email`).

Hosts pick a recipe in `hosts.yml`:

```yaml
arch:
  hosts:
    alfred:
      recipe: personal_workstation
      gpu: nvidia
```

Playbooks load `recipes/<recipe>.yml` at the start of each play
(`playbooks/tasks/load_recipe.yml`).

| File | Typical use |
|------|-------------|
| `personal_workstation.yml` | Personal Arch/Garuda desktops and laptops |
| `mac_work.yml` | Work Mac |

## Add a host (existing recipe)

1. Under the right OS group in `hosts.yml`, add the hostname with `recipe`
   and any deltas (`gpu`, …).
2. Dry-run: `ansible-playbook playbooks/site.yml --limit <host> --check`

## Add a new recipe

1. Copy an existing file in this directory; edit `profiles:`, flags, email.
2. Point hosts at it via `recipe: <name>` (filename without `.yml`).

## Not here

| Concern | Where |
|---------|--------|
| OS package list | `group_vars/<os>/apps.yml` (`os_apps`) |
| Package bundles (cli, hyprland, …) | `group_vars/all/profiles.yml` |
| Catalog / providers | `group_vars/all/package_catalog.yml` |
| One-off host override | host vars in `hosts.yml` or `host_vars/` |
