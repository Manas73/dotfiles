# Role: chezmoi

Renders `~/.config/chezmoi/chezmoi.toml` from Ansible inventory vars and applies the dotfiles non-interactively.

## Responsibilities

- Verify `chezmoi` is installed (installation is a package role's job).
- Ensure `~/.config/chezmoi/` exists.
- Decrypt the age identity from `key.txt.age` if it is missing (interactive passphrase).
- Verify the Chezmoi source repo is cloned at `chezmoi_repo_path`.
- Render `chezmoi.toml` from inventory vars.
- Run `chezmoi apply --force` non-interactively.

## Does Not

- Install Chezmoi, the age CLI, or any packages.
- Clone the source repo.
- Configure system services or mutate OS state.
- Manage any file outside `~/.config/chezmoi/`; dotfile ownership stays with Chezmoi itself.

## Inputs

From `group_vars/all/main.yml` (paths and age config, prefixed with `chezmoi_`):

- `chezmoi_source_repo`
- `chezmoi_repo_path` — git-clone root (contains `.chezmoiroot`, `ansible/`, `chezmoi/`, `docs/`).
- `chezmoi_source_path` — resolved Chezmoi source dir (the `chezmoi/` subdir pointed at by `.chezmoiroot`). Holds `key.txt.age` and all `dot_*` source state.
- `chezmoi_config_path`
- `chezmoi_age_identity`
- `chezmoi_age_recipient`

From the host's recipe + inventory (unprefixed):

- `primary_user`
- `email`
- `profile`
- `osid`
- `gpu`
- `plasma_window_manager` (Linux only; consumed by `plasma_custom_wm` role)
- `profiles` (template derives the `window_manager` data field by
  intersecting this list with `[hyprland, i3, qtile]`)

## Interactive Prompts

The role is non-interactive except for one case: if `~/.config/chezmoi/key.txt` is missing and the encrypted `key.txt.age` is present in the source repo, the age identity must be decrypted with a passphrase.

The playbooks (`dotfiles.yml`, `site.yml`) collect this once via `vars_prompt` (`chezmoi_age_passphrase`). Leave the prompt blank if the key already exists — the role skips decryption when the passphrase is empty. Because Ansible has no controlling TTY, the role invokes `chezmoi --no-tty age decrypt --passphrase` and feeds the passphrase on stdin rather than letting chezmoi open `/dev/tty` (which fails with "could not open a new TTY"). The decrypt task is `no_log: true`. Subsequent runs skip this task since `key.txt` already exists.

For non-interactive runs, pass `-e chezmoi_age_passphrase=...` (mind shell history) or supply it via an Ansible Vault-encrypted variable.

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
    window_manager = ["hyprland"]
    plasma_window_manager = "kwin"
```

## Failure Modes

- `chezmoi` binary missing → fails with instructions to install via the relevant package role.
- Chezmoi source repo missing → fails with the clone command.
- Required host vars missing → fails via `assert` with a pointer to `docs/ansible/02-onboarding.md`.
