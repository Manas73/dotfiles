# Onboarding a New Machine

Add the host to `ansible/inventories/personal/hosts.yml` under the groups it belongs to, create a `host_vars/<hostname>.yml` file, then run the site playbook.

## Rules

- `host_vars/<hostname>.yml` contains only true machine-specific values.
- Shared package lists and role behavior live in `group_vars/`.
- Linux-only keys (`window_managers`, `plasma_window_manager`, `gpu_vendor`) are omitted on macOS hosts. Roles guard reads with `is defined` or default filters. Group membership (`linux`, `arch`, `hyprland`, `i3`) is the primary selector.

## Example: Arch/Garuda Linux Laptop

`inventories/personal/host_vars/<hostname>.yml`:

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

Add to `hosts.yml`:

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

## Example: macOS (MacBook Pro)

`inventories/personal/host_vars/<hostname>.yml`:

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

Note: `window_managers`, `plasma_window_manager`, `gpu_vendor`, and `chezmoi_window_manager`/`chezmoi_plasma_window_manager` are omitted on macOS.

Add to `hosts.yml`:

```yaml
all:
  children:
    darwin:
      hosts:
        <hostname>:
```

## Validate

```sh
cd ansible
ansible-inventory -i inventories/personal/hosts.yml --host <hostname>
ansible-playbook -i inventories/personal/hosts.yml playbooks/site.yml --syntax-check
```

## Run

```sh
cd ansible
ansible-playbook -i inventories/personal/hosts.yml playbooks/site.yml --limit <hostname> --ask-become-pass
```

Dotfiles only:

```sh
ansible-playbook -i inventories/personal/hosts.yml playbooks/dotfiles.yml --limit <hostname>
```
