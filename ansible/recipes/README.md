# Machine recipes

A **recipe** is a shared “kind of machine” config: package profile bundles,
recipe-local apps, feature flags, plasma WM, wallpaper, and chezmoi data fields.

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
| `macos_defaults_extra` | Extra Darwin prefs (appended to `group_vars/darwin/macos_defaults.yml`) |
| `wallpaper` | Desktop image applied after chezmoi. Filename under `~/.config/.settings/`, absolute/`~` path, or `{image, source_color_index}`. Linux runs matugen; Darwin sets the desktop picture. Omit or `""` to skip. |
| Feature flags / plasma | As needed |

## Wallpaper

1. Add the image under `chezmoi/dot_config/dot_settings/` (deploys to
   `~/.config/.settings/`).
2. Set `wallpaper:` on the recipe (filename, absolute path, or
   `{image: desktop_wallpaper.jpeg, source_color_index: 0}`).
3. `mise run dotfiles` applies it: matugen on Linux, System Events
   desktop picture on Darwin.

Hyprland is not the source of truth; it only restores the last awww
image at session start.

## Add a host (existing recipe)

1. Under the right OS group in `hosts.yml`, add the hostname with `recipe`
   and any deltas (`gpu`, …).
2. Dry-run: `ansible-playbook playbooks/site.yml --limit <host> --check`

## Add a new recipe (e.g. another employer Mac)

1. Copy `mac_turing.yml` → `mac_<employer>.yml`.
2. Set `profile: "<employer>"` (not a generic `"work"`), `email`, `apps`,
   `profiles:`, and `wallpaper:` as needed.
3. Point the host at `recipe: mac_<employer>`.
4. Bootstrap choices: add the new profile id to
   `chezmoi/.chezmoi.toml.tmpl` if you use manual `chezmoi init`.

## Not here

| Concern | Where |
|---------|--------|
| OS package list | `group_vars/<os>/apps.yml` (`os_apps`) |
| Package bundles (cli, hyprland, …) | `group_vars/all/profiles.yml` |
| Catalog / providers | `group_vars/all/package_catalog.yml` |
| Wallpaper image files | Chezmoi `chezmoi/dot_config/dot_settings/` |
| One-off host override | host vars in `hosts.yml` or `host_vars/` |
