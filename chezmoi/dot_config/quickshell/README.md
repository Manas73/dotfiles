# Quickshell

Hyprland bar, notifications, and OSD. Layout is `shell.qml` — there is no JSON config.

```
shell.qml          composition root (what sits on the bar)
shell.toml         font/size overrides
theme/             matugen colors
components/        shared style + panel chrome
bar/               per-monitor bar window
widgets/           one folder per widget
notifications/
osd/
bin/               helpers on PATH via bin/launch
```

Add or remove widgets by editing `shell.qml`. Theme colors come from matugen (`theme/shell.toml`).

```
~/.config/quickshell/bin/launch
```

Hyprland: `Super+Shift+R` restarts the shell, `Super+N` shows notification history, volume keys drive the OSD.
