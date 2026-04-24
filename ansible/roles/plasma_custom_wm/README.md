# Role: plasma_custom_wm

Configures KDE Plasma to use a custom window manager, or restores KWin.

## Responsibilities

- When `plasma_window_manager` is a non-`kwin` value:
  - Create `~/.config/systemd/user/plasma-wm.service` for the chosen WM.
  - Mask `plasma-kwin_x11.service`.
  - Enable `plasma-wm.service`.
- When `plasma_window_manager` is `kwin`:
  - Disable `plasma-wm.service`.
  - Unmask `plasma-kwin_x11.service`.

## Does Not

- Install the actual window manager (handled by `i3`/`hyprland`/etc.).

## Inputs

- `plasma_window_manager`
- `primary_user`

## Implementation Task

Tracked by Beads issue `chezmoi-hoz`.
