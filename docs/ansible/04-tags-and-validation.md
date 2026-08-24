# Ansible 04 — Tags, Validation, and Troubleshooting

## Tags (operational slicing)

`site.yml` supports tags for targeted runs:

| Tag | What runs |
|---|---|
| `packages` | `roles/packages` (resolve + all provider task files). |
| `pacman` / `aur` | A single provider task file under `roles/packages/tasks/`. |
| `brew` / `cask` | Homebrew formulae + casks. |
| `mise` | mise CLI tools (`mise use --global --pin`). |
| `arch` / `darwin` | All package work for the matching OS. |
| `dotfiles` / `chezmoi` | `chezmoi` role only (render `chezmoi.toml` + `chezmoi apply`). |
| `system` | sudoers, `roles/system` (fish/docker/libvirt), macos_defaults (darwin), kanata, plasma_custom_wm (gated by flags). Sub-tags: `sudoers`, `fish`, `docker`, `libvirt`, `macos` / `defaults`, `kanata`, `plasma`. |
| `macos` / `defaults` | `roles/macos_defaults` only (Darwin user prefs via `osx_defaults`). |
| `upgrade` | `pacman -Syu` (only when you explicitly want a full upgrade). |

Examples:

```sh
cd ~/.local/share/chezmoi/ansible

# Just install packages, no dotfiles or system setup.
ansible-playbook playbooks/site.yml --tags packages --ask-become-pass

# Just AUR.
ansible-playbook playbooks/site.yml --tags aur --ask-become-pass

# Just re-apply dotfiles.
ansible-playbook playbooks/dotfiles.yml

# macOS defaults only (on a Darwin host).
ansible-playbook playbooks/site.yml --limit <mac-hostname> --tags macos
```

## Validation

Run before committing non-trivial Ansible or Chezmoi changes. From the repo
root the one-liner is **`mise run check`** (it bakes in the UTF-8 locale and
runs everything below); **`mise run test`** runs only the chezmoi-boundary
guard. Run `mise tasks` to list all tasks.

The raw commands, for reference and for environments without `mise`:

```sh
# UTF-8 locale is required by Ansible on this machine.
export LC_ALL=C.UTF-8 LANG=C.UTF-8

cd ~/.local/share/chezmoi/ansible

# Playbook syntax.
ansible-playbook playbooks/site.yml --syntax-check
ansible-playbook playbooks/dotfiles.yml --syntax-check
ansible-playbook playbooks/validate.yml --syntax-check

# Inventory resolves as expected (hosts, groups, merged vars).
ansible-inventory --graph
ansible-inventory --host "$(hostname)"

# Unprivileged validation: load recipe, assert vars, resolve packages
# through the catalog (no become / no installs). This is what `mise run check`
# uses — a full site.yml --check still needs sudo for packages/sudoers.
ansible-playbook playbooks/validate.yml --limit "$(hostname)"

# Dotfiles dry-run (user-level).
ansible-playbook playbooks/dotfiles.yml --limit "$(hostname)" --check --diff

# Privileged site dry-run (optional; needs a sudo password or NOPASSWD).
# ansible-playbook playbooks/site.yml --limit "$(hostname)" --check --diff --ask-become-pass

# Chezmoi side.
chezmoi diff                                    # pending dotfile changes
chezmoi managed | grep -E '^(ansible|docs|bootstrap)/' && echo FAIL \
    || echo "chezmoi boundary ok"
```

`chezmoi managed` returning any line under `ansible/`, `docs/`, or
`bootstrap/` means the `.chezmoiroot`/`.chezmoiignore` setup is broken and
repo-only files would be deployed into `$HOME`. See
[`../00-overview.md`](../00-overview.md) for why this can't normally happen.

## Troubleshooting

### Ansible locale warning

If `ansible --version` complains about `ISO-8859-1`, set a UTF-8 locale:

```sh
export LC_ALL=C.UTF-8 LANG=C.UTF-8
```

(The `mise` tasks set this automatically.)

### Chezmoi cannot find the age identity

On the very first run, the Chezmoi source directory (`chezmoi/`, via
`.chezmoiroot`) contains `key.txt.age` (passphrase-encrypted). The chezmoi
role — and `run_once_before_decrypt-private-key.sh.tmpl` — decrypt it with
`chezmoi age decrypt --passphrase`, prompting once for the passphrase. After
that, `~/.config/chezmoi/key.txt` persists and runs are non-interactive. See
[`../chezmoi/01-dotfiles-model.md`](../chezmoi/01-dotfiles-model.md).

### SSH: "Repository not found" from a Turing org

The SSH key works (`ssh -T git@github.com-turing` greets you) but
`git fetch`/`git push` on a specific org's repo fails. That org enforces SAML
SSO. At `https://github.com/settings/keys`, logged in as the matching
account, click **Configure SSO** on the key and authorize it for that org.

### Beads Dolt push fails

`bd dolt push` errors with `403` or `Permission denied` usually mean the
configured remote points at an account lacking push rights. The Dolt remote
URL lives in `.beads/config.yaml` (`sync.remote`) and in
`.beads/embeddeddolt/<prefix>/.dolt/repo_state.json`. Both should point at
`git+ssh://git@github.com-personal/Manas73/dotfiles.git`.

### ansible-galaxy: collection already installed elsewhere

If Ansible can't find `community.general` despite `ansible-galaxy install`
succeeding, check that `ansible.cfg`'s `collections_path` matches where
`ansible-galaxy` actually installed the collection. This repo sets
`collections_path = collections` under `ansible/`, so install and run must
both happen from the `ansible/` working directory.
