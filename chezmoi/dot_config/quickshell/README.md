# Quickshell desktop shell

A standalone [Quickshell](https://quickshell.org/) desktop shell, ported from
[Omarchy's `shell/`](https://github.com/basecamp/omarchy/tree/ed7bae4ac5a570e9df307486e0202fdafcc6ee24/shell)
so it runs on a normal Hyprland session with Quickshell installed. No
`OMARCHY_PATH`, no Omarchy package, no `uwsm`.

Plugin ids stay `omarchy.*` (they are just identifiers). Helper scripts in
`bin/` keep the `omarchy-*` names the QML already calls.

## Layout

```
~/.config/quickshell/
  shell.qml              entry point
  shell.json             bar layout (which widgets, order, per-widget settings)
  Commons/ Ui/           shared QML
  plugins/               first-party bar, panels, notifications, …
  services/              plugin registry
  bin/                   portable helpers (on PATH via `bin/launch`)
  defaults/
    shell.json           factory fallback if shell.json is missing
    menu.jsonc           session menu
    theme/               fallback colors if matugen has not run
```

`shell.json` is hand-written and Chezmoi-managed. The running shell also
rewrites it when you drag widgets, pin tray icons, or change formats in the
UI — `chezmoi apply` will overwrite those live edits unless you
`chezmoi add ~/.config/quickshell/shell.json` first.

| Path | Purpose |
|------|---------|
| `~/.config/quickshell/shell.json` | bar layout + plugin settings |
| `~/.config/quickshell/local-plugins/<id>/` | third-party plugins |
| `~/.config/quickshell/menu.jsonc` | optional menu overlay |
| `~/.config/quickshell/shell.toml` | font/size overrides |
| `~/.config/quickshell/theme/` | matugen (or hand-written) colors |

## Run

```bash
~/.config/quickshell/bin/launch
```

Or `quickshell -p ~/.config/quickshell` after putting `~/.config/quickshell/bin`
on `PATH`. Hyprland autostart does this via `bin/launch`.

IPC (the running instance must already exist):

```bash
omarchy-shell shell ping
omarchy-shell shell toggle omarchy.menu '{"menu":"root"}'
omarchy-shell notifications showHistory
omarchy-shell notifications toggleDnd
```

## What works without Omarchy

- Bar: workspaces, clock, tray, audio, bluetooth, network, battery/power, weather, keyboard layout
- Panels for those widgets, notifications, OSD, polkit, app menu
- Lock via PAM `login`, with `hyprlock` as fallback from `omarchy-system-lock`
- Theming from `defaults/theme/` or `~/.config/quickshell/theme/` (matugen)

Hyprland-specific pieces (`Quickshell.Hyprland`, workspaces, idle, lock) need
Hyprland. Helpers call `brightnessctl`, `pactl`/`wpctl`, `nmcli`, `bluetoothctl`,
`powerprofilesctl`, `notify-send`, `hyprctl` when present and degrade if missing.

Intentionally stubbed or omitted from the default bar: Omarchy agents, Omarchy
system updates, wallpaper/theme switchers that shell out to `omarchy-theme-*`,
and the Omarchy screensaver. The bundled background and polkit plugins are
disabled so they do not fight `awww` and `polkit-kde`.

Stop any other notification daemon (SwayNC, Dunst, Mako) before starting the
shell — only one process can own `org.freedesktop.Notifications`.

## Dependencies

- [Quickshell](https://quickshell.org/) with Hyprland, Pipewire, UPower, and notifications support
- A Nerd Font (bar glyphs) as the `monospace` fontconfig alias
- Optional: `brightnessctl`, `pactl`, `nmcli`, `iw`, `bluetoothctl`, `jq`, `wl-clipboard`, `wtype`, `hyprlock`, `hyprsunset`, `powerprofilesctl`

Pinned upstream: Omarchy `ed7bae4ac5a570e9df307486e0202fdafcc6ee24`.
