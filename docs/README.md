# Documentation

Deep-dive docs for this dotfiles + provisioning repo. The top-level
[`../README.md`](../README.md) is the quick orientation (requirements,
quickstart, authentication); everything else lives here.

## Reading order

Read top to bottom to build a mental model of the repo:

1. [`00-overview.md`](00-overview.md) — the two-layer model (Chezmoi +
   Ansible), repo layout, and the Chezmoi/repo boundary invariant.

### Chezmoi (user dotfiles under `$HOME`)

2. [`chezmoi/01-dotfiles-model.md`](chezmoi/01-dotfiles-model.md) —
   `.chezmoiroot`, source state, the age identity, and `.chezmoiignore`.
3. [`chezmoi/02-bootstrap-fallback.md`](chezmoi/02-bootstrap-fallback.md) —
   the manual `chezmoi init --apply` path for machines not in Ansible
   inventory.

### Ansible (packages, services, system setup)

4. [`ansible/01-architecture.md`](ansible/01-architecture.md) — the
   four-layer package model (Intent → Catalog → Dispatcher → Providers).
5. [`ansible/02-onboarding.md`](ansible/02-onboarding.md) — add a new host:
   `host_vars`, inventory wiring, validation, and the run steps.
6. [`ansible/03-adding-apps-providers.md`](ansible/03-adding-apps-providers.md)
   — add an app, a profile, or a whole provider; catalog schema reference.
7. [`ansible/04-tags-and-validation.md`](ansible/04-tags-and-validation.md) —
   tags for operational slicing, validation recipes, and troubleshooting.

## See also

- [`../ansible/README.md`](../ansible/README.md) — the authoritative,
  in-tree reference for the Ansible layer (layout, schema, roles).
- [`history/`](history/) — historical design records (kept for context, not
  current how-to).
