# Role: fish

Ensures Fish is the login shell for the primary user.

## Responsibilities

- Verify `fish` is on the host (installation is the package role's job).
- Register the fish binary in `/etc/shells` if missing.
- Set Fish as the login shell for `primary_user` via `ansible.builtin.user`.

## Does Not

- Install Fish.
- Manage Fish config (`~/.config/fish/` stays with Chezmoi).

## Inputs

- `primary_user` (from host_vars).

## Notes

- `ansible.builtin.user` is idempotent; re-runs are no-ops.
- Users must log out and back in for the shell change to take effect.
