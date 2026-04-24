# Role: kanata

Sets up the Kanata keyboard remapper on Linux hosts.

## Responsibilities

- Verify `kanata` is installed (via `aur_packages`).
- Ensure the `uinput` group exists.
- Add `primary_user` to `input` and `uinput`.
- Install `/etc/udev/rules.d/99-input.rules` and reload udev.
- Persist the `uinput` kernel module load via `/etc/modules-load.d/uinput.conf` and load it immediately.
- Install `~/.config/systemd/user/kanata.service` and enable+start it.

## Does Not

- Install Kanata.
- Manage the Kanata config file (`~/.config/kanata/config.kbd` stays with Chezmoi).

## Inputs

- `primary_user` (host_vars).
- `kanata_enabled` (host_vars). Role runs only when true; gated at site.yml.
- `kanata_config_path` (defaults to `~/.config/kanata/config.kbd`).

## Notes

- The systemd user service runs kanata with the user-owned config; Chezmoi must have placed the config before this role runs.
- Users must log out and back in for group membership changes to take effect.
- The role persists the kernel module load across reboots via `/etc/modules-load.d/`, which is a small improvement over the original Chezmoi script that only `modprobe`d once.
