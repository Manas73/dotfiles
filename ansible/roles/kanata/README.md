# Role: kanata

Configures the Kanata keyboard remapper on Linux hosts.

## Responsibilities

- Install Kanata (via package role).
- Ensure `input` and `uinput` groups exist and include the user.
- Install `/etc/udev/rules.d/99-input.rules`.
- Load the `uinput` module.
- Create and enable the `kanata.service` user unit.
- Only runs when `kanata_enabled: true`.

## Does Not

- Manage the Kanata config file (Chezmoi owns `~/.config/kanata/config.kbd`).

## Inputs

- `primary_user`
- `kanata_enabled`

## Implementation Task

Tracked by Beads issue `chezmoi-hoz`.
