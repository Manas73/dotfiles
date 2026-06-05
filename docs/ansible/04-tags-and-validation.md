# Ansible 04 — Tags, Validation, and Troubleshooting

## Tags (operational slicing)

`site.yml` supports tags for targeted runs:

| Tag | What runs |
|---|---|
| `packages` | The four-layer package orchestrator (`roles/packages`) and every provider it dispatches to. |
| `pacman` / `aur` / `brew` / `cask` | A single provider role only (`roles/provider_*`). |
| `arch` / `darwin` | All package work for the matching OS. |
| `dotfiles` / `chezmoi` | `chezmoi` role only (render `chezmoi.toml` + `chezmoi apply`). |
| `system` | fish, docker, kanata, plasma_custom_wm (gated by host feature flags). Sub-tags: `sudoers`, `fish`, `docker`, `kanata`, `plasma`. |
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
```

## Validation

Run before committing non-trivial Ansible or Chezmoi changes. From the repo
root the one-liner is **`just check`** (it bakes in the UTF-8 locale and runs
everything below); **`just test`** runs only the chezmoi-boundary guard. Run
`just` to list all recipes.

The raw commands, for reference and for environments without `just`:

```sh
# UTF-8 locale is required by Ansible on this machine.
export LC_ALL=C.UTF-8 LANG=C.UTF-8

cd ~/.local/share/chezmoi/ansible

# Playbook syntax.
ansible-playbook playbooks/site.yml --syntax-check
ansible-playbook playbooks/dotfiles.yml --syntax-check

# Inventory resolves as expected (hosts, groups, merged vars).
ansible-inventory --graph
ansible-inventory --host "$(hostname)"

# Dry-run. Skips sudo-gated tasks if --ask-become-pass is omitted, which is
# useful for quickly exercising the playbook structure.
ansible-playbook playbooks/site.yml --limit "$(hostname)" --check --diff

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

(The `just` recipes set this automatically.)

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
