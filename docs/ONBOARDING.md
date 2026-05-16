# Onboarding a New Machine

Add the host to `ansible/hosts.yml` under its OS group, create a
`ansible/host_vars/<hostname>.yml` file, then run the site playbook.

## 0. Prerequisites

On the new machine, before running any Ansible:

1. Install `git`, `age` (1.2.0+), `chezmoi` (2.52.2+), and `ansible-core` (2.15+).
2. Generate an SSH key (ed25519 recommended) and add the public key to the matching GitHub account. For SSO-enforced orgs, also authorize the key per-org at `https://github.com/settings/keys`.
3. Confirm SSH access:

   ```sh
   ssh -T git@github.com-personal   # expect: Hi <user>! ...
   ```

4. Clone the dotfiles repo into the Chezmoi source path:

   ```sh
   git clone git@github.com-personal:Manas73/dotfiles.git ~/.local/share/chezmoi
   ```

5. Install the Ansible collection(s):

   ```sh
   cd ~/.local/share/chezmoi
   ansible-galaxy install -r ansible/requirements.yml
   ```

## Rules

- `host_vars/<hostname>.yml` contains only true machine-specific values:
  primary user, chezmoi data fields, profile membership, feature flags.
- Shared package lists and role behavior live in `group_vars/`.
  OS-wide intent in `group_vars/{arch,darwin}.yml`; profile bundles in
  `group_vars/all/profiles.yml`.
- Profile membership (Hyprland, i3, gaming) is declared as a `profiles:`
  list in host_vars, **not** as inventory group membership. Single source
  of truth per host: removing a profile is one edit, not two.
- Linux-only host_vars like `plasma_window_manager` are simply omitted on
  macOS hosts. Roles guard reads with `is defined` or default filters.
- The chezmoi data keys (`email`, `profile`, `osid`, `gpu`) live unprefixed
  in host_vars. The chezmoi role and the `chezmoi.toml.j2` template read
  them directly. The `chezmoi_*` prefix is reserved for shared paths and
  the age recipient in `group_vars/all/main.yml`.

## Example: Arch/Garuda Linux Machine

Create `ansible/host_vars/<hostname>.yml`:

```yaml
---
# Host-specific values only. Shared behavior lives in group_vars/.

ansible_python_interpreter: /usr/bin/python

primary_user: <linux-username>

# Chezmoi inventory data. Rendered into ~/.config/chezmoi/chezmoi.toml by
# the chezmoi role. No chezmoi_ prefix needed at the inventory layer.
email: "you@example.com"
profile: "personal"
osid: "linux-arch"
gpu: "nvidia"          # nvidia | amd | intel

# Plasma custom window manager. Consumed by the plasma_custom_wm role.
# Set to "kwin" or omit to keep stock KWin.
plasma_window_manager: "i3"

# Profile membership. Single source of truth for the package profiles
# this host opts into. Each entry resolves against profile_apps in
# group_vars/all/profiles.yml. The chezmoi.toml.j2 template also derives
# its window_manager data field from this list.
profiles:
  - hyprland
  - i3
  - gaming

# Feature flags.
docker_enabled: true
kanata_enabled: true
```

Wire the host into `ansible/hosts.yml` under `linux → arch`:

```yaml
all:
  children:
    linux:
      children:
        arch:
          hosts:
            alfred:
            <hostname>:

    darwin:
      hosts: {}
```

That's the only edit hosts.yml needs. Profiles (hyprland/i3/gaming) are
not inventory groups; they come in via the host's `profiles:` list and the
packages orchestrator unions `profile_apps[<name>]` for each entry on top
of `arch_apps`. `ansible_connection: local` is set globally in
`group_vars/all/main.yml`, so personal hosts don't repeat it.

## Validate

`ansible.cfg` already sets `inventory = hosts.yml`, so commands run from
the `ansible/` directory can omit `-i`.

```sh
cd ~/.local/share/chezmoi/ansible

# UTF-8 locale is required by Ansible on Garuda.
export LC_ALL=C.UTF-8 LANG=C.UTF-8

ansible-inventory --graph
ansible-inventory --host <hostname>
ansible-playbook playbooks/site.yml --syntax-check
ansible-playbook playbooks/site.yml --limit <hostname> --check --diff
```

Expect:

- `--graph` shows `<hostname>` under `linux → arch`. No `hyprland`/`i3`/
  `gaming` groups appear; those are profile data, not inventory groups.
- `--host <hostname>` dumps merged vars including `email`, `profile`,
  `osid`, `gpu`, `profiles`, `arch_apps`, `darwin_apps`, and
  `profile_apps`.
- `--syntax-check` is silent (parses successfully).
- `--check --diff` runs up to the first sudo-gated task without
  `--ask-become-pass`; add `--ask-become-pass` to exercise the full check
  flow.

## Run

```sh
ansible-playbook playbooks/site.yml --limit <hostname> --ask-become-pass
```

First run additionally prompts once for the age passphrase (to decrypt
`~/.config/chezmoi/key.txt`).

### Dotfiles only

```sh
ansible-playbook playbooks/dotfiles.yml --limit <hostname>
```

### Post-install

- Log out and back in so group membership changes (`docker`, `input`,
  `uinput`) take effect.
- If `kanata_enabled: true`, verify `systemctl --user status kanata.service`.
- If `plasma_window_manager` is not `kwin`, log out and back in to pick up
  the new Plasma WM session.

## Example: macOS (MacBook Pro) — Placeholder

> **Status**: deferred. The full Mac bootstrap flow (Homebrew install,
> ansible-core via brew, first-run checklist) is tracked by `chezmoi-qxl`
> and will be filled in when a real MacBook is onboarded. The package
> dispatch and chezmoi rendering on darwin already work end-to-end through
> the SOLID four-layer architecture; what's missing is the
> bare-metal-to-ansible-ready bootstrap. The schema below is what host_vars
> should look like on day one.

Create `ansible/host_vars/<hostname>.yml`:

```yaml
---
ansible_python_interpreter: /usr/bin/python3

primary_user: <mac-username>

# Chezmoi inventory data (unprefixed; chezmoi role reads directly).
email: "you@example.com"
profile: "personal"
osid: "darwin"
gpu: "none"

# Profile membership. macOS hosts typically have no desktop or gaming
# profiles; populate if you adopt aerospace/yabai or similar later.
profiles: []

# Feature flags.
docker_enabled: false   # Docker Desktop on Mac is a separate install
kanata_enabled: false   # Kanata on macOS needs different setup; defer

# Intel Mac only: uncomment.
# provider_brew_path: /usr/local/bin/brew
# provider_cask_brew_path: /usr/local/bin/brew
```

`plasma_window_manager` and any other Linux-only keys are simply omitted on
macOS. Roles guard reads with `is defined`.

Inventory wiring in `ansible/hosts.yml`:

```yaml
all:
  children:
    darwin:
      hosts:
        <hostname>:
```

The macOS bootstrap (Homebrew install, `ansible-core` install, first-run
walkthrough, validation, troubleshooting) will be documented under
`chezmoi-qxl` when the real Mac arrives.
