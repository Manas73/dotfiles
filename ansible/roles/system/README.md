# Role: system

Thin OS user and service wiring that is not package install and not
multi-step specialty setup (those stay in `kanata`, `plasma_custom_wm`,
`chezmoi`, `sudoers`).

## Tasks

| File | Tag | Gate | What it does |
|------|-----|------|----------------|
| `fish.yml` | `fish` | always | Register fish in `/etc/shells`, set login shell |
| `docker.yml` | `docker` | `docker_enabled` + Linux | docker group + `docker.socket` |
| `libvirt.yml` | `libvirt` | `libvirt_enabled` + Linux | kvm/libvirt groups + sockets |

Package binaries must already be present (installed by `roles/packages`).

## Tags

```sh
ansible-playbook ... --tags system
ansible-playbook ... --tags fish
ansible-playbook ... --tags docker
ansible-playbook ... --tags libvirt
```
