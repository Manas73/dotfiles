# Role: wallpaper

Applies the recipe wallpaper after Chezmoi has deployed the image file.

Runs from the same playbooks as the chezmoi role (`site.yml` and
`dotfiles.yml`), so `mise run apply` and `mise run dotfiles` both apply it.
Hyprland does **not** choose or generate the wallpaper.

## Responsibilities

- Skip when `wallpaper` / `wallpaper_path` is empty.
- Fail if the image file is missing (Chezmoi should have placed it).
- **Linux:** `matugen image <path> --source-color-index N --continue-on-error`.
  Theme templates come from `~/.config/matugen/` (Chezmoi). Wallpaper set
  via matugen's `[config.wallpaper]` command (awww) when a session is up.
- **Darwin:** `osascript` + System Events `desktop picture` (built-in).
- Skip re-apply when the image checksum, source-color index, and (Linux)
  matugen config are unchanged.

## Does Not

- Own wallpaper image files (Chezmoi: `chezmoi/dot_config/dot_settings/`).
- Install matugen or awww (packages role / `hyprland` profile).
- Start awww-daemon (Hyprland autostart restores the last awww wallpaper).

## Inputs

| Var | Source | Purpose |
|-----|--------|---------|
| `wallpaper` | recipe (optional) | Filename under `wallpaper_dir`, absolute/`~` path, or `{image, source_color_index}` |
| `wallpaper_dir` | `group_vars/all` | Default `~/.config/.settings` |
| `wallpaper_source_color_index` | recipe / default `0` | matugen `--source-color-index` (Linux) |
| `wallpaper_path` | `playbooks/tasks/normalize_wallpaper.yml` | Resolved absolute path |
| `wallpaper_state_path` | default | Idempotency token at `~/.local/state/dotfiles/wallpaper.applied` |

## Tags

Play tags: `dotfiles`, `wallpaper`.
