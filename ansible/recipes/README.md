# Machine recipes

A **recipe** is a shared “kind of machine” config: package profile bundles,
recipe-local apps, feature flags, plasma WM, and chezmoi data fields.

Hosts pick a recipe in `hosts.yml`:

```yaml
arch:
  hosts:
    alfred:
      recipe: personal_workstation
      gpu: nvidia

darwin:
  hosts:
    mbp:
      recipe: mac_turing
      gpu: none
```

Playbooks load `recipes/<recipe>.yml` at the start of each play
(`playbooks/tasks/load_recipe.yml`).

| File | Typical use |
|------|-------------|
| `personal_workstation.yml` | Personal Arch/Garuda desktops and laptops |
| `mac_turing.yml` | Turing work Mac |

## Fields

| Field | Purpose |
|-------|---------|
| `profile` (singular) | Chezmoi identity/context: `personal`, `turing`, … Written to `chezmoi.toml` data. Non-`personal` skips personal SSH keys in `.chezmoiignore`. |
| `email` | Chezmoi / git identity |
| `profiles` (plural) | Package *bundles* from `group_vars/all/profiles.yml` (`cli`, `cloud`, …) |
| `apps` | Recipe-local logical app names (unioned after profile bundles) |
| Feature flags / plasma | As needed |

## Add a host (existing recipe)

1. Under the right OS group in `hosts.yml`, add the hostname with `recipe`
   and any deltas (`gpu`, …).
2. Dry-run: `ansible-playbook playbooks/site.yml --limit <host> --check`

## Add a new recipe (e.g. another employer Mac)

1. Copy `mac_turing.yml` → `mac_<employer>.yml`.
2. Set `profile: "<employer>"` (not a generic `"work"`), `email`, `apps`,
   and `profiles:` as needed.
3. Point the host at `recipe: mac_<employer>`.
4. Bootstrap choices: add the new profile id to
   `chezmoi/.chezmoi.toml.tmpl` if you use manual `chezmoi init`.

## Not here

| Concern | Where |
|---------|--------|
| OS package list | `group_vars/<os>/apps.yml` (`os_apps`) |
| Package bundles (cli, hyprland, …) | `group_vars/all/profiles.yml` |
| Catalog / providers | `group_vars/all/package_catalog.yml` |
| One-off host override | host vars in `hosts.yml` or `host_vars/` |
