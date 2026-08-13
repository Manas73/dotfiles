# Ansible 02 — Onboarding a New Machine

## Mental model

| Question | Where |
|----------|--------|
| Which OS? | Inventory group in `hosts.yml` (`arch`, `darwin`, …) |
| What kind of machine? | `recipe:` → `ansible/recipes/<recipe>.yml` |
| What differs on this box? | Host vars on the inventory entry (`gpu`, …) |
| OS-wide packages? | `group_vars/<os>/apps.yml` (`os_apps`) |
| Package bundles? | `group_vars/all/profiles.yml` + recipe `profiles:` |

See also [`ansible/recipes/README.md`](../../ansible/recipes/README.md) and
[`ansible/group_vars/README.md`](../../ansible/group_vars/README.md).

## 0. Prerequisites

On the new machine, before running any Ansible:

1. Install [`mise`](https://mise.run) (`curl https://mise.run | sh`) and
   `git` (skip if already present; otherwise `mise use -g git`). The
   repo's `mise.toml` supplies `ansible-core`, `chezmoi`, and `age`.
2. Generate an SSH key (ed25519 recommended) and add the public key to the
   matching GitHub account. For SSO-enforced orgs, also authorize the key
   per-org at `https://github.com/settings/keys`.
3. Confirm SSH access:

   ```sh
   ssh -T git@github.com-personal   # expect: Hi <user>! ...
   ```

4. Clone the repo into the Chezmoi source path:

   ```sh
   git clone git@github.com-personal:Manas73/dotfiles.git ~/.local/share/chezmoi
   ```

5. Trust the repo config and install the Ansible collection(s):

   ```sh
   cd ~/.local/share/chezmoi
   mise trust
   mise run deps
   ```

## Example: second personal Arch workstation

```yaml
# ansible/hosts.yml — under linux → arch
arch:
  hosts:
    alfred:
      recipe: personal_workstation
      gpu: nvidia
    <hostname>:
      recipe: personal_workstation
      gpu: nvidia   # or amd / intel
```

No `host_vars` file required. No new recipe unless this machine should
differ in profiles/flags/email.

`primary_user` defaults to the user running ansible
(`group_vars/all/main.yml`). `osid` comes from `group_vars/arch/main.yml`.
Recipe supplies `email`, `profile`, `profiles:`, feature flags, plasma WM.

### New recipe

If this machine should not match an existing recipe:

1. Copy `ansible/recipes/personal_workstation.yml` to `recipes/<new>.yml`.
2. Edit `profiles:`, flags, email, etc.
3. Set `recipe: <new>` on the host.

## Validate

```sh
cd ~/.local/share/chezmoi/ansible
export LC_ALL=C.UTF-8 LANG=C.UTF-8

ansible-inventory --graph
ansible-inventory --host <hostname>
ansible-playbook playbooks/site.yml --syntax-check
ansible-playbook playbooks/validate.yml --limit <hostname>
```

(From the repo root, `mise run check` runs the full validation block. It does
**not** require sudo; full `site.yml --check` still needs become.)

Expect:

- `--graph` shows `<hostname>` under `linux → arch` (or `darwin`). No
  recipe/class groups in the graph.
- `--host` shows `recipe`, `gpu`, `os_apps`, `osid`. Recipe fields
  (`profiles`, `email`, …) appear after the play loads
  `recipes/<recipe>.yml` (not in raw inventory dump).
- `validate.yml` loads the recipe, asserts required vars, and resolves
  packages without installing.

## Run

```sh
ansible-playbook playbooks/site.yml --limit <hostname> --ask-become-pass
```

### Dotfiles only

```sh
ansible-playbook playbooks/dotfiles.yml --limit <hostname>
```

### Post-install

- Log out and back in so group membership changes take effect.
- If `kanata_enabled: true`, verify `systemctl --user status kanata.service`.
- If `plasma_window_manager` is set, log out and back in for the new Plasma WM.

## macOS

Package dispatch and chezmoi rendering work on darwin. Homebrew
is installed with the official script to `/opt/homebrew` (arm64)
or `/usr/local` (Intel) so bottles work:

```sh
NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

The installer cannot prompt for sudo (Ansible closes stdin). Re-run
with `--ask-become-pass` as a macOS Administrator; the role forwards
that password via `SUDO_ASKPASS`.

```yaml
darwin:
  hosts:
    <hostname>:
      recipe: mac_turing
      gpu: none
      # packages_brew_path: /opt/custom/bin/brew  # override official brew
```

## Add an OS family

1. Inventory group in `hosts.yml`.
2. `group_vars/<os>/main.yml` + `apps.yml` (`os_apps`).
3. Row in `group_vars/all/os_providers.yml`.
4. Catalog / provider tasks if needed.
5. Playbook host patterns for OS-scoped plays if needed.
