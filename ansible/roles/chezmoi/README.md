# Role: chezmoi

Renders `~/.config/chezmoi/chezmoi.toml` from Ansible inventory vars and applies the dotfiles non-interactively.

## Responsibilities

- Verify `chezmoi` is installed (installation is a package role's job).
- Ensure `~/.config/chezmoi/` exists.
- Verify the Chezmoi source repo is cloned at `chezmoi_repo_path`.
- Render `chezmoi.toml` from inventory vars.
- Run `chezmoi apply --force` non-interactively.

## Does Not

- Install Chezmoi or any packages.
- Clone the source repo.
- Configure system services or mutate OS state.
- Manage any file outside `~/.config/chezmoi/`; dotfile ownership stays with Chezmoi itself.

## Inputs

From `group_vars/all/main.yml` (paths, prefixed with `chezmoi_`):

- `chezmoi_source_repo`
- `chezmoi_repo_path` — git-clone root (contains `.chezmoiroot`, `ansible/`, `chezmoi/`, `docs/`).
- `chezmoi_config_path`

From the host's recipe + inventory (unprefixed):

- `primary_user`
- `email`
- `profile`
- `osid`
- `gpu`
- `plasma_window_manager` (Linux only; consumed by `plasma_custom_wm` role)
- `profiles` (template derives the `window_manager` data field by
  intersecting this list with `[hyprland, i3, qtile]`)

The role is fully non-interactive.

## Rendered Output

```toml
[data]
    email = "..."
    profile = "..."
    osid = "..."
    gpu = "..."
    window_manager = ["hyprland"]
    plasma_window_manager = "kwin"
```

## Failure Modes

- `chezmoi` binary missing → fails with instructions to install via the relevant package role.
- Chezmoi source repo missing → fails with the clone command.
- Required host vars missing → fails via `assert` with a pointer to `docs/ansible/02-onboarding.md`.
