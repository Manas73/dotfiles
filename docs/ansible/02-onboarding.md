# Ansible 02 — Onboarding a New Machine

Add the host once under its **machine class** in `ansible/hosts.yml` (classes
nest under OS), create a thin `ansible/host_vars/<hostname>.yml` for hardware
deltas, then run the site playbook.

`group_vars/` uses one directory per inventory group name (same names as in
`hosts.yml`). See [`ansible/group_vars/README.md`](../../ansible/group_vars/README.md)
for the side-by-side map.

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

## Identity vs recipe

| Layer | Where | What |
|-------|--------|------|
| OS family | `linux → arch` / `darwin`; `group_vars/arch/`, `group_vars/darwin/` | OS packages (`apps.yml`), `osid` / python (`main.yml`), OS-scoped plays |
| Machine class | nested under OS; `group_vars/<class>/` | Shared recipe: `profiles:`, feature flags, plasma WM, class-level chezmoi (`profile`, `email`) |
| Host identity | inventory key = hostname; `host_vars/<hostname>.yml` | True deltas: usually `gpu` only |
| Defaults | `group_vars/all/main.yml` | `ansible_connection: local`, `primary_user: "{{ ansible_facts['user_id'] }}"`, feature flags off |

Hostname is for targeting (`--limit $(hostname)`). Do **not** copy a full
host recipe into a new host_vars file — put the host in the right machine
class instead.

## Rules for host_vars

- Prefer a **one-line** host_vars file: `gpu: nvidia` (or `amd` / `intel` /
  `none`).
- Shared package lists live in `group_vars/` — OS-wide intent in
  `group_vars/{arch,darwin}/apps.yml`; profile bundles in
  `group_vars/all/profiles.yml`.
- Profile membership is a `profiles:` list on the **machine class**, not an
  inventory group and not host_vars (unless you need a one-off override).
- Linux-only keys like `plasma_window_manager` live on the Linux machine
  class; roles guard reads with `is defined` or default filters.
- Chezmoi data keys (`email`, `profile`, `osid`, `gpu`) are **unprefixed**.
  Class/OS group_vars supply most of them; host_vars supplies `gpu`. The
  `chezmoi_*` prefix is reserved for paths / age recipient in
  `group_vars/all/main.yml`.

## Example: Arch / Garuda Linux host (same class as alfred)

If the new machine should match the personal workstation recipe, only add
identity — do not redeclare profiles or feature flags.

Create `ansible/host_vars/<hostname>.yml`:

```yaml
---
# Hardware delta only. Recipe: group_vars/workstation_personal/
gpu: "nvidia"          # nvidia | amd | intel
```

Wire the host once under `linux → arch → workstation_personal`:

```yaml
all:
  children:
    linux:
      children:
        arch:
          children:
            workstation_personal:
              hosts:
                alfred:
                <hostname>:

    darwin:
      hosts: {}
```

`ansible_connection: local` and `primary_user` come from
`group_vars/all/main.yml`. `osid` and `ansible_python_interpreter` come from
`group_vars/arch/main.yml`. Email, profiles, and feature flags come from
`group_vars/workstation_personal/main.yml`.

### New machine class

If the host should *not* share an existing recipe, create
`group_vars/<new_class>/main.yml` with `profiles:`, feature flags, and
class-level chezmoi fields, nest an inventory group of the same name under
the right OS, and list the host there only.

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

- `--graph` shows `<hostname>` under `linux → arch → workstation_personal`
  (or whichever class you used). Host listed once. No
  `hyprland`/`i3`/`gaming` inventory groups — those are profile data on the
  machine class.
- `--host <hostname>` dumps merged vars including class-level `profiles`,
  feature flags, `email`, OS-level `osid`, and host-level `gpu`.
  `primary_user` may still show as a Jinja template until facts are gathered.
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

Shared work-Mac recipe: `group_vars/mac_work/` (ready; unused until a host
joins the group). Day-one host_vars is hardware only:

```yaml
---
gpu: "none"

# Intel Mac only: uncomment.
# packages_brew_path: /usr/local/bin/brew
```

Inventory wiring (host listed once under the class):

```yaml
darwin:
  children:
    mac_work:
      hosts:
        <hostname>:
```

`plasma_window_manager` and other Linux-only keys are simply omitted; roles
guard reads with `is defined`.
