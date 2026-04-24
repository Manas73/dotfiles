# Role: sudoers

Installs narrowly scoped `/etc/sudoers.d/` drop-ins required by other roles. Kept separate so privilege grants are not coupled to the roles that consume them.

## Responsibilities

- Ensure `/etc/sudoers.d` exists with `0750` and root ownership.
- Install a `NOPASSWD` grant for `/usr/bin/pacman` scoped to `primary_user`, so `yay` can invoke `sudo pacman` non-interactively from Ansible (no TTY is available for password prompts during AUR installs).
- Validate every drop-in with `visudo -cf` before writing. A malformed sudoers file can lock the user out of `sudo` entirely.

## Does Not

- Grant blanket `NOPASSWD: ALL`. Grants are scoped to specific binaries.
- Manage the main `/etc/sudoers` file.

## Inputs

- `primary_user` (from `host_vars`).

## Prerequisites

- Root privileges (the role uses `become: true` on the file tasks).
- The playbook must be run with `--ask-become-pass` on first provision, since the bootstrap sudo call itself needs credentials until this role has run.

## Why This Role Exists

`yay` shells out to `sudo pacman` internally during AUR builds. When invoked from Ansible there is no controlling TTY, so `sudo` cannot prompt and the install aborts:

```
sudo: a terminal is required to read the password
 -> error installing repo packages
```

A `NOPASSWD` rule scoped to `pacman` is the conventional fix. The `aur_packages` role's `yay` task is not marked `become: true` because `yay` and `makepkg` refuse to run as root; the grant here is what makes that design work.

## Example

Played automatically by `site.yml` before `aur_packages`:

```sh
ansible-playbook -i inventories/personal/hosts.yml playbooks/site.yml \
    --limit alfred --tags system --ask-become-pass
```

Sudoers only:

```sh
ansible-playbook ... --tags sudoers --ask-become-pass
```
