# Documentation

Deep-dive docs for this dotfiles + provisioning repo. The top-level
[`../README.md`](../README.md) is the onboarding path (new machine,
day-to-day tasks, other paths); everything else lives here.

## Reading order

Read top to bottom to build a mental model of the repo:

1. [`00-overview.md`](00-overview.md) — the two-layer model (Chezmoi +
   Ansible), repo layout, and the Chezmoi/repo boundary invariant.
2. [`alfred.md`](alfred.md) — host portrait of the personal Arch
   workstation this repo is designed around (Garuda Dragonized substrate
   + Ansible/Chezmoi overlay). Not a how-to; the machine as it actually
   is.

### Chezmoi (user dotfiles under `$HOME`)

3. [`chezmoi/01-dotfiles-model.md`](chezmoi/01-dotfiles-model.md) —
   `.chezmoiroot`, source state, and `.chezmoiignore`.
4. [`chezmoi/02-bootstrap-fallback.md`](chezmoi/02-bootstrap-fallback.md) —
   the manual `chezmoi init --apply` path for machines not in Ansible
   inventory.

### Ansible (packages, services, system setup)

5. [`ansible/01-architecture.md`](ansible/01-architecture.md) — the
   package model (intent lists → catalog → packages role / provider tasks).
6. [`ansible/02-onboarding.md`](ansible/02-onboarding.md) — add a new host:
   `host_vars`, inventory wiring, validation, and the run steps.
7. [`ansible/03-adding-apps-providers.md`](ansible/03-adding-apps-providers.md)
   — add an app, a profile, or a whole provider; catalog schema reference.
8. [`ansible/04-tags-and-validation.md`](ansible/04-tags-and-validation.md) —
   tags for operational slicing, validation recipes, and troubleshooting.

## See also

- [`../ansible/README.md`](../ansible/README.md) — the authoritative,
  in-tree reference for the Ansible layer (layout, schema, roles).
- [`history/`](history/) — historical design records (kept for context, not
  current how-to).
