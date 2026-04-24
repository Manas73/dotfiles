# Role: fish

Ensures Fish is the login shell for the primary user.

## Responsibilities

- Ensure Fish is installed (via the appropriate package role).
- Set Fish as the login shell for `primary_user`.
- Work on Linux and macOS.

## Does Not

- Manage Fish config files (Chezmoi owns those).

## Inputs

- `primary_user`

## Implementation Task

Tracked by Beads issue `chezmoi-hoz`.
