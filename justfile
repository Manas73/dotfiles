# Task runner for the dotfiles + provisioning repo.
#
# This justfile lives at the repo root, OUTSIDE .chezmoiroot (chezmoi/), so
# `chezmoi apply` never deploys it into $HOME. The `test` recipe verifies that
# invariant (along with ansible/ and docs/) still holds.
#
# Run `just` (or `just --list`) to see available recipes.

# Ansible on this machine needs a UTF-8 locale, otherwise it warns/errors on
# ISO-8859-1. Exporting here means every recipe inherits it; no more manual
# `export LC_ALL=C.UTF-8 LANG=C.UTF-8` before validation.
export LC_ALL := "C.UTF-8"
export LANG := "C.UTF-8"

# Show available recipes.
default:
    @just --list

# Install required Ansible collections (run once on a fresh machine).
deps:
    cd ansible && ansible-galaxy install -r requirements.yml

# Full pre-commit validation (syntax, inventory, dry-run, diff, boundary).
check: test
    # ansible.cfg pins `inventory = hosts.yml`, so the ansible steps run from
    # the ansible/ directory for inventory + collections paths to resolve.
    cd ansible && ansible-playbook playbooks/site.yml --syntax-check
    cd ansible && ansible-playbook playbooks/dotfiles.yml --syntax-check
    cd ansible && ansible-inventory --graph
    cd ansible && ansible-inventory --host "$(hostname)"
    cd ansible && ansible-playbook playbooks/site.yml --limit "$(hostname)" --check --diff
    chezmoi diff

# Alias for `check`.
validate: check

# Guard the chezmoi/repo boundary (no repo-only paths managed into $HOME).
test:
    @if chezmoi managed | grep -E '^(ansible|docs|bootstrap)/'; then \
        echo "FAIL: repo-only paths are chezmoi-managed (.chezmoiroot/.chezmoiignore broken)"; \
        exit 1; \
    else \
        echo "chezmoi boundary ok"; \
    fi

# Show pending dotfile changes.
diff:
    chezmoi diff

# Provision this host fully: packages + dotfiles + system setup (sudo).
apply:
    cd ansible && ansible-playbook playbooks/site.yml --limit "$(hostname)" --ask-become-pass

# Re-apply dotfiles only for this host (render chezmoi.toml + chezmoi apply).
dotfiles:
    cd ansible && ansible-playbook playbooks/dotfiles.yml --limit "$(hostname)"

# Install packages only for this host, no dotfiles/system setup (sudo).
packages:
    cd ansible && ansible-playbook playbooks/site.yml --limit "$(hostname)" --tags packages --ask-become-pass
