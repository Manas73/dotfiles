# Onboarding a New Machine

Add the host to `ansible/inventories/personal/hosts.yml` under the groups it belongs to, create a `host_vars/<hostname>.yml` file, then run the site playbook.

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

- `host_vars/<hostname>.yml` contains only true machine-specific values.
- Shared package lists and role behavior live in `group_vars/`.
- Linux-only keys (`window_managers`, `plasma_window_manager`, `gpu_vendor`) are omitted on macOS hosts. Roles guard reads with `is defined` or default filters. Group membership (`linux`, `arch`, `hyprland`, `i3`) is the primary selector.

## Example: Arch/Garuda Linux Machine

Create `ansible/inventories/personal/host_vars/<hostname>.yml`:

```yaml
---
primary_user: manas

chezmoi_email: "manas.sambare@gmail.com"
chezmoi_profile: "personal"
chezmoi_osid: "linux-arch"
chezmoi_gpu: "amd"
chezmoi_window_manager:
  - hyprland
chezmoi_plasma_window_manager: "kwin"

gpu_vendor: "amd"
window_managers:
  - hyprland
plasma_window_manager: "kwin"

docker_enabled: true
kanata_enabled: true
gaming_enabled: false
```

Wire it into `ansible/inventories/personal/hosts.yml`:

```yaml
all:
  children:
    linux:
      children:
        arch:
          hosts:
            alfred:
            <hostname>:
        hyprland:
          hosts:
            alfred:
            <hostname>:
```

`hyprland`, `i3`, and `gaming` are children of `linux`, so a host in any of them is automatically in `linux`. Package roles also check `group_names` before including profile-specific packages, so adding a host to only `arch` and `i3` (for example) will not install Hyprland or gaming packages.

## Validate

```sh
cd ~/.local/share/chezmoi/ansible

# UTF-8 locale is required by Ansible on Garuda.
export LC_ALL=C.UTF-8 LANG=C.UTF-8

ansible-inventory -i inventories/personal/hosts.yml --graph
ansible-inventory -i inventories/personal/hosts.yml --host <hostname>
ansible-playbook -i inventories/personal/hosts.yml playbooks/site.yml --syntax-check
ansible-playbook -i inventories/personal/hosts.yml playbooks/site.yml \
    --limit <hostname> --check --diff
```

Expect:

- `--graph` shows `<hostname>` under `linux → arch` (and any desktop-profile groups you added).
- `--host <hostname>` dumps merged vars with correct `arch_pacman_packages`, `hyprland_*` etc.
- `--syntax-check` is silent (parses successfully).
- `--check --diff` runs up to the first sudo-gated task without --ask-become-pass; add `--ask-become-pass` to exercise the full check flow.

## Run

```sh
ansible-playbook -i inventories/personal/hosts.yml playbooks/site.yml \
    --limit <hostname> --ask-become-pass
```

First run will additionally prompt once for the age passphrase (to decrypt `~/.config/chezmoi/key.txt`).

### Dotfiles only

```sh
ansible-playbook -i inventories/personal/hosts.yml playbooks/dotfiles.yml \
    --limit <hostname>
```

### Post-install

- Log out and back in so group membership changes (`docker`, `input`, `uinput`) take effect.
- If `kanata_enabled: true`, verify `systemctl --user status kanata.service`.
- If `plasma_window_manager` is not `kwin`, log out and back in to pick up the new Plasma WM session.

## Example: macOS (MacBook Pro) — Placeholder

> **Status**: deferred. The darwin_packages role is tracked by Beads issue `chezmoi-7tw` (currently deferred until a MacBook exists), and the actual docs for this path are tracked by `chezmoi-qxl` (blocked on `chezmoi-7tw`). The skeleton below is the expected schema; expect it to evolve when the role is implemented.

Create `ansible/inventories/personal/host_vars/<hostname>.yml`:

```yaml
---
primary_user: manas

chezmoi_email: "manas.sambare@gmail.com"
chezmoi_profile: "personal"
chezmoi_osid: "darwin"
chezmoi_gpu: "none"

docker_enabled: true
kanata_enabled: false
gaming_enabled: false
```

`window_managers`, `plasma_window_manager`, `gpu_vendor`, `chezmoi_window_manager`, and `chezmoi_plasma_window_manager` are omitted on macOS.

Inventory wiring:

```yaml
all:
  children:
    darwin:
      hosts:
        <hostname>:
```

The macOS run, validation, and troubleshooting will be documented under `chezmoi-qxl` once the Homebrew role is in.
