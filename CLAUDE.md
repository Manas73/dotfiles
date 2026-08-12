# Project Instructions for AI Agents

This file provides instructions and context for AI coding agents working on this project.

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:ca08a54f -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd dolt push
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
<!-- END BEADS INTEGRATION -->


## Build & Test

Task running is handled by `mise` (tasks live in `./mise.toml` at the repo
root). Run from the repo root:

```bash
mise tasks      # list all tasks
mise run check  # full pre-commit validation (syntax-check, inventory,
                # --check --diff dry-run, chezmoi diff, boundary guard)
mise run test   # chezmoi-boundary guard only (no repo-only paths in $HOME)
mise run apply  # full site playbook for this host (prompts for sudo)
mise run dotfiles  # re-apply dotfiles only
mise run packages  # install packages only
mise run diff   # pending dotfile changes
```

`mise.toml` sets `LC_ALL=C.UTF-8 LANG=C.UTF-8` for every task (Ansible
requires a UTF-8 locale on this machine) and runs ansible steps from the
`ansible/` directory so `ansible.cfg`'s inventory/collections paths resolve.
It also pins the repo toolchain (`ansible-core`, `chezmoi`, `age`) so those
binaries do not have to be preinstalled.

## Architecture Overview

Two layers in one repo (see README.md for detail):

- **Chezmoi** manages user dotfiles under `$HOME`. Source state lives in
  `chezmoi/` (pinned by `.chezmoiroot`).
- **Ansible** manages OS packages, services, and system setup, and renders
  the Chezmoi config. Lives in `ansible/`.

`mise.toml`, `ansible/`, and `docs/` are OUTSIDE `.chezmoiroot`, so
`chezmoi apply` never deploys them into `$HOME`. `mise run test` enforces this.

## Conventions & Patterns

- Run `mise run check` before committing non-trivial Ansible/Chezmoi changes.
- Packages: add to a profile in `ansible/group_vars/all/profiles.yml`; if the
  package name differs per-OS, add a `package_catalog.yml` entry. Names that
  match on both Arch (pacman) and macOS (brew) fall through without a catalog
  entry.
