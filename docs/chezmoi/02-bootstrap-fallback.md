# Chezmoi 02 — Bootstrap Fallback (Dotfiles Only)

The normal way to bring a machine online is the Ansible site playbook
([`../ansible/02-onboarding.md`](../ansible/02-onboarding.md)), which renders
the Chezmoi config and runs `chezmoi apply` for you. This page covers the two
cases where you bypass Ansible and drive Chezmoi directly.

## Case 1: Already-provisioned host, dotfiles-only refresh

On a machine already in Ansible inventory, re-apply just the dotfiles without
touching packages or system state:

```sh
cd ~/.local/share/chezmoi/ansible
ansible-playbook playbooks/dotfiles.yml --limit "$(hostname)"
```

Or, with the task runner:

```sh
just dotfiles
```

This runs the `chezmoi` role only (render `chezmoi.toml` + `chezmoi apply`).

## Case 2: Host not in Ansible inventory

For a machine you don't plan to fully provision, or before it's wired into
`hosts.yml`, use Chezmoi's own init:

```sh
chezmoi init --apply git@github.com-personal:Manas73/dotfiles.git
```

Because there is no Ansible-rendered `chezmoi.toml`, the
`chezmoi/.chezmoi.toml.tmpl` fallback prompts interactively for:

- commit email
- profile
- window-manager choice(s)
- GPU vendor

These prompts are the manual equivalent of the data Ansible fills in
automatically on inventory-managed hosts. The first run also prompts once for
the age passphrase to decrypt the identity (see
[`01-dotfiles-model.md`](01-dotfiles-model.md)).

## When to graduate to Ansible

The fallback only deploys dotfiles. It does **not** install packages, set the
login shell, or configure Docker/Kanata/Plasma. Once a machine is something
you maintain, add it to Ansible inventory
([`../ansible/02-onboarding.md`](../ansible/02-onboarding.md)) so the full
provisioning + non-interactive config rendering applies.
