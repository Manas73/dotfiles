# Role: chezmoi

Owns Chezmoi installation, `~/.config/chezmoi/chezmoi.toml` rendering, and non-interactive apply.

## Responsibilities

- Ensure Chezmoi is installed on the host.
- Ensure `~/.config/chezmoi/` exists for the primary user.
- Render `~/.config/chezmoi/chezmoi.toml` from Ansible inventory vars.
- Ensure the age identity is present or document the manual unlock step.
- Initialize this repository as the Chezmoi source when needed.
- Run `chezmoi apply` non-interactively.

## Does Not

- Install desktop/dev packages.
- Configure system services.
- Manage anything outside of `$HOME`.

## Inputs

Consumes these vars from `host_vars`/`group_vars`:

- `chezmoi_email`
- `chezmoi_profile`
- `chezmoi_osid`
- `chezmoi_gpu`
- `chezmoi_window_manager`
- `chezmoi_plasma_window_manager`
- `chezmoi_source_repo`
- `chezmoi_source_path`
- `chezmoi_config_path`
- `chezmoi_age_identity`
- `chezmoi_age_recipient`

## Implementation Task

Tracked by Beads issue `chezmoi-g19`.
