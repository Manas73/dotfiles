# Ansible 02 — Onboarding a New Machine

Add the host to `ansible/hosts.yml` under its **OS group** and **machine
class**, create a thin `ansible/host_vars/<hostname>.yml` for identity /
hardware deltas, then run the site playbook.

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
| OS family | `hosts.yml` → `arch` / `darwin`; `group_vars/{arch,darwin}.yml` | OS packages, OS-scoped plays, python interpreter |
| Machine class | `hosts.yml` → `workstation_personal` / `mac_work`; `group_vars/<class>.yml` | Shared recipe: `profiles:`, feature flags, plasma WM, class-level chezmoi fields (`profile`, `osid`) |
| Host identity | inventory key = hostname; `host_vars/<hostname>.yml` | True deltas: `primary_user`, `email`, `gpu`, one-off overrides |

Hostname is for targeting (`--limit $(hostname)`). Do **not** copy a full
host recipe into a new host_vars file — put the host in the right machine
class instead.

## Rules for host_vars

- `host_vars/<hostname>.yml` contains only true machine-specific values:
  primary user, email, GPU, and rare overrides.
- Shared package lists live in `group_vars/` — OS-wide intent in
  `group_vars/{arch,darwin}.yml`; profile bundles in
  `group_vars/all/profiles.yml`.
- Profile membership (hyprland, i3, gaming, …) is a `profiles:` list on the
  **machine class** (e.g. `group_vars/workstation_personal.yml`), **not** an
  inventory group and usually **not** host_vars. Single source of truth for
  a class of machines: one edit updates every member.
- Linux-only keys like `plasma_window_manager` live on the Linux machine
  class; roles guard reads with `is defined` or default filters.
- Chezmoi data keys (`email`, `profile`, `osid`, `gpu`) are **unprefixed**.
  Class-level fields (`profile`, `osid`) sit on the machine class; identity
  fields (`email`, `gpu`) sit in host_vars. The `chezmoi_*` prefix is
  reserved for shared paths / the age recipient in `group_vars/all/main.yml`.

## Example: Arch / Garuda Linux host (same class as alfred)

If the new machine should match the personal workstation recipe, only add
identity — do not redeclare profiles or feature flags.

Create `ansible/host_vars/<hostname>.yml`:

```yaml
---
# Identity / hardware deltas only.
# Shared recipe: group_vars/workstation_personal.yml

primary_user: <linux-username>

email: "you@example.com"
gpu: "nvidia"          # nvidia | amd | intel
```

Wire the host into `ansible/hosts.yml` under **both** `linux → arch` and
`workstation_personal`:

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

    workstation_personal:
      hosts:
        alfred:
        <hostname>:

    mac_work:
      hosts: {}
```

`ansible_connection: local` is set globally in `group_vars/all/main.yml`.
`ansible_python_interpreter` comes from `group_vars/arch.yml`.

### New machine class

If the host should *not* share an existing recipe, create
`group_vars/<new_class>.yml` with `profiles:`, feature flags, and class-level
chezmoi fields, add an inventory group of the same name, and list the host
there (plus its OS group).

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

- `--graph` shows `<hostname>` under `linux → arch` **and** under
  `workstation_personal` (or whichever class you used). No
  `hyprland`/`i3`/`gaming` inventory groups — those are profile data on the
  machine class.
- `--host <hostname>` dumps merged vars including class-level `profiles`,
  feature flags, and host-level `email` / `gpu` / `primary_user`, plus
  `arch_apps` / `darwin_apps` and `profile_apps`.
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

Shared work-Mac recipe: `group_vars/mac_work.yml`. Day-one host_vars is
identity only:

```yaml
---
primary_user: <mac-username>

email: "you@example.com"
gpu: "none"

# Intel Mac only: uncomment.
# packages_brew_path: /usr/local/bin/brew
```

Inventory wiring (both groups):

```yaml
all:
  children:
    darwin:
      hosts:
        <hostname>:

    mac_work:
      hosts:
        <hostname>:
```

`plasma_window_manager` and other Linux-only keys are simply omitted; roles
guard reads with `is defined`.
