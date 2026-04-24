# Role: plasma_custom_wm

Configures KDE Plasma to launch a custom window manager instead of KWin, or restores KWin.

## Responsibilities

When `plasma_window_manager` is `i3`, `qtile`, or `hyprland`:

- Render `~/.config/systemd/user/plasma-wm.service` invoking the chosen WM.
- Mask `plasma-kwin_x11.service` (user scope).
- Enable `plasma-wm.service`.

When `plasma_window_manager` is `kwin` or empty:

- Disable `plasma-wm.service`.
- Remove the unit file.
- Unmask `plasma-kwin_x11.service`.

## Does Not

- Install the selected window manager (handled by `arch_packages`/desktop roles).
- Manage Plasma dotfiles (Chezmoi owns them).

## Inputs

- `plasma_window_manager` (host_vars). Values: `kwin`, `i3`, `qtile`, `hyprland`, or empty.

## Notes

- Non-Linux hosts skip the role entirely.
- Use `systemctl --user` for mask/unmask because plasma-kwin_x11.service is a user unit. `ansible.builtin.systemd_service` does not currently expose a `masked` state for user scope, so `command: systemctl --user (mask|unmask)` is used with conservative change detection.
- Log out and back in for the session change to take effect.
