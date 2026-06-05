# Ansible 02 — Onboarding a New Machine

Add the host to `ansible/hosts.yml` under its OS group, create
`ansible/host_vars/<hostname>.yml`, then run the site playbook.

## 0. Prerequisites

On the new machine, before running any Ansible:

1. Install `git`, `age` (1.2.0+), `chezmoi` (2.52.2+), `just`, and
   `ansible-core` (2.15+).
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

5. Install the Ansible collection(s):

   ```sh
   cd ~/.local/share/chezmoi
   ansible-galaxy install -r ansible/requirements.yml
   ```

## Rules for host_vars

- `host_vars/<hostname>.yml` contains only true machine-specific values:
  primary user, chezmoi data fields, profile membership, feature flags.
- Shared package lists and role behavior live in `group_vars/` — OS-wide
  intent in `group_vars/{arch,darwin}.yml`; profile bundles in
  `group_vars/all/profiles.yml`.
- Profile membership (hyprland, i3, gaming, …) is a `profiles:` list in
  host_vars, **not** inventory group membership. Single source of truth:
  removing a profile is one edit, not two.
- Linux-only keys like `plasma_window_manager` are simply omitted on macOS
  hosts; roles guard reads with `is defined` or default filters.
- Chezmoi data keys (`email`, `profile`, `osid`, `gpu`) live **unprefixed**
  in host_vars. The chezmoi role and `chezmoi.toml.j2` read them directly.
  The `chezmoi_*` prefix is reserved for shared paths / the age recipient in
  `group_vars/all/main.yml`.

## Example: Arch / Garuda Linux host

Create `ansible/host_vars/<hostname>.yml`:

```yaml
---
# Host-specific values only. Shared behavior lives in group_vars/.

ansible_python_interpreter: /usr/bin/python

primary_user: <linux-username>

# Chezmoi inventory data. Rendered into ~/.config/chezmoi/chezmoi.toml.
email: "you@example.com"
profile: "personal"
osid: "linux-arch"
gpu: "nvidia"          # nvidia | amd | intel

# Plasma custom window manager. Consumed by the plasma_custom_wm role.
# Set to "kwin" or omit to keep stock KWin.
plasma_window_manager: "i3"

# Profile membership. Single source of truth for the package profiles this
# host opts into. Each entry resolves against profile_apps in
# group_vars/all/profiles.yml.
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

That's the only edit `hosts.yml` needs. Profiles are not inventory groups;
they come in via the `profiles:` list. `ansible_connection: local` is set
globally in `group_vars/all/main.yml`, so personal hosts don't repeat it.

## Validate

```sh
cd ~/.local/share/chezmoi/ansible
export LC_ALL=C.UTF-8 LANG=C.UTF-8     # Ansible needs a UTF-8 locale

ansible-inventory --graph
ansible-inventory --host <hostname>
ansible-playbook playbooks/site.yml --syntax-check
ansible-playbook playbooks/site.yml --limit <hostname> --check --diff
```

(From the repo root, `just check` runs the full validation block with the
locale baked in.)

Expect:

- `--graph` shows `<hostname>` under `linux → arch`. No
  `hyprland`/`i3`/`gaming` groups — those are profile data, not inventory
  groups.
- `--host <hostname>` dumps merged vars including `email`, `profile`,
  `osid`, `gpu`, `profiles`, `arch_apps`, `darwin_apps`, and `profile_apps`.
- `--syntax-check` is silent (parses successfully).
- `--check --diff` runs up to the first sudo-gated task without
  `--ask-become-pass`; add it to exercise the full check flow.

## Run

```sh
ansible-playbook playbooks/site.yml --limit <hostname> --ask-become-pass
```

The first run additionally prompts once for the age passphrase (to decrypt
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

## macOS (placeholder)

> **Status: deferred.** Package dispatch and chezmoi rendering on darwin
> already work end-to-end through the four-layer architecture; what's missing
> is the bare-metal-to-ansible-ready bootstrap (Homebrew install, ansible-core
> via brew, first-run checklist). Tracked by beads `chezmoi-qxl` and filled in
> when a real MacBook is onboarded.

Day-one host_vars schema:

```yaml
---
ansible_python_interpreter: /usr/bin/python3

primary_user: <mac-username>

# Chezmoi inventory data (unprefixed; chezmoi role reads directly).
email: "you@example.com"
profile: "personal"
osid: "darwin"
gpu: "none"

# macOS hosts typically have no desktop/gaming profiles.
profiles: []

# Feature flags.
docker_enabled: false   # Docker Desktop on Mac is a separate install
kanata_enabled: false   # Kanata on macOS needs different setup; defer

# Intel Mac only: uncomment.
# provider_brew_path: /usr/local/bin/brew
# provider_cask_brew_path: /usr/local/bin/brew
```

Inventory wiring:

```yaml
all:
  children:
    darwin:
      hosts:
        <hostname>:
```

`plasma_window_manager` and other Linux-only keys are simply omitted; roles
guard reads with `is defined`.
