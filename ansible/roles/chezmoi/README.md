# Role: chezmoi

Renders `~/.config/chezmoi/chezmoi.toml` from Ansible inventory vars and applies the dotfiles non-interactively.

## Responsibilities

- Verify `chezmoi` is installed (installation is a package role's job).
- Ensure `~/.config/chezmoi/` exists.
- Decrypt the age identity from `key.txt.age` if it is missing (interactive passphrase).
- Verify the Chezmoi source repo exists at `chezmoi_source_path`.
- Render `chezmoi.toml` from inventory vars.
- Run `chezmoi apply --force` non-interactively.

## Does Not

- Install Chezmoi, the age CLI, or any packages.
- Clone the source repo.
- Configure system services or mutate OS state.
- Manage any file outside `~/.config/chezmoi/`; dotfile ownership stays with Chezmoi itself.

## Inputs

From `group_vars/all.yml`:

- `chezmoi_source_repo`
- `chezmoi_source_path`
- `chezmoi_config_path`
- `chezmoi_age_identity`
- `chezmoi_age_recipient`

From `host_vars/<hostname>.yml`:

- `primary_user`
- `chezmoi_email`
- `chezmoi_profile`
- `chezmoi_osid`
- `chezmoi_gpu`
- `chezmoi_window_manager` (Linux only)
- `chezmoi_plasma_window_manager` (Linux only)

## Interactive Prompts

The role is non-interactive except for one case: if `~/.config/chezmoi/key.txt` is missing and the encrypted `key.txt.age` is present in the source repo, the role runs `chezmoi age decrypt --passphrase`, which prompts once for the passphrase. Subsequent runs skip this task.

## Rendered Output

```toml
encryption = "age"

[age]
    identity = "~/.config/chezmoi/key.txt"
    recipient = "age1..."

[data]
    email = "..."
    profile = "..."
    osid = "..."
    gpu = "..."
    window_manager = ["i3", "hyprland"]
    plasma_window_manager = "i3"
```

## Failure Modes

- `chezmoi` binary missing → fails with instructions to install via the relevant package role.
- Chezmoi source repo missing → fails with the clone command.
- Required host vars missing → fails via `assert` with a pointer to `docs/ONBOARDING.md`.
