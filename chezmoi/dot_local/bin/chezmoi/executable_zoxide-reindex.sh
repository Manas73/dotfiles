#!/usr/bin/env bash
# zoxide-reindex.sh — Reproducible zoxide DB seeding.
#
#   Step 1: ~/Repositories indexed at .git-parent granularity (+5 for repo roots)
#   Step 2: ~/Sambare's Dropbox/Sambare's Team Folder (full recursion, filtered)
#   Step 3: manas_sambare subtree boost (+10)
#   Step 4: 'current' folder boost (+2)
#   Step 5: Family-member root + 'passport' parent dirs extra boost (+5)
#           So `z manas` → manas_sambare root; `z manas passport` → passport parent.
#
# Source-of-truth: chezmoi → dot_local/bin/chezmoi/executable_zoxide-reindex.sh
# Deployed to:    ~/.local/bin/chezmoi/zoxide-reindex.sh
# Usage: zoxide-reindex.sh [--force] [--dry-run] [-h|--help]

set -euo pipefail

# ────── Configuration ──────────────────────────────────────────────
readonly REPOS_ROOT="${HOME}/Repositories"
readonly DROPBOX_ROOT="${HOME}/Sambare's Dropbox/Sambare's Team Folder"
readonly MANAS_DIR="${DROPBOX_ROOT}/family_members/manas_sambare"
readonly FAMILY_MEMBERS_DIR="${DROPBOX_ROOT}/family_members"

# Boost factors (each unit = one additional `zoxide add` call)
readonly REPO_BASE_BOOST=5      # repo roots get 5x so they outweigh deep Dropbox dirs
readonly MANAS_BOOST=10         # manas_sambare subtree
readonly CURRENT_BOOST=2        # 'current' folders
readonly KEY_DIR_BOOST=5        # family-member roots + 'passport' parent dirs

readonly EXCLUDE_NAMES=(
  .git node_modules .venv __pycache__ target dist build
  .next .cache .direnv vendor
)

readonly REPO_EXCLUDE_PATTERNS=(
  "/multi-swe-bench/multi-swe-bench/data/workdir/"
  "/.cache/"
)

# Specific basenames to treat as "key parent" dirs and boost extra under family_members
readonly KEY_PARENT_NAMES=(passport)

# ────── Flags ──────────────────────────────────────────────────────
FORCE=0
DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --force)   FORCE=1 ;;
    --dry-run) DRY_RUN=1 ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) printf 'Unknown arg: %s\n' "$arg" >&2; exit 2 ;;
  esac
done

# ────── Helpers ────────────────────────────────────────────────────
log()  { printf '\033[1;34m[zoxide-reindex]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[zoxide-reindex]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[zoxide-reindex]\033[0m %s\n' "$*" >&2; exit 1; }

zadd() {
  local p="$1" n="$2" i
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '  [dry-run] zoxide add (x%d): %s\n' "$n" "$p"
    return 0
  fi
  for ((i=0; i<n; i++)); do
    zoxide add -- "$p"
  done
}

# Build a find -prune clause: \( -name a -o -name b -o … \)
prune_clause() {
  local n first=1
  printf '\\('
  for n in "${EXCLUDE_NAMES[@]}"; do
    if [[ $first -eq 1 ]]; then first=0; else printf ' -o'; fi
    printf ' -name %q' "$n"
  done
  printf ' \\)'
}

# ────── Preflight ──────────────────────────────────────────────────
command -v zoxide >/dev/null || die "zoxide not found in PATH"
[[ -d "$REPOS_ROOT"   ]] || die "Missing: $REPOS_ROOT"
[[ -d "$DROPBOX_ROOT" ]] || die "Missing: $DROPBOX_ROOT"
[[ -d "$MANAS_DIR"    ]] || warn "Missing: $MANAS_DIR (Step 3 will no-op)"

existing_count="$(zoxide query -l 2>/dev/null | wc -l)"
if [[ "$existing_count" -gt 0 ]]; then
  if [[ "$FORCE" -ne 1 ]]; then
    die "zoxide DB already has $existing_count entries. Use --force to wipe & re-index."
  fi
  log "Wiping $existing_count existing zoxide entries (--force)…"
  if [[ "$DRY_RUN" -eq 0 ]]; then
    while IFS= read -r entry; do
      [[ -n "$entry" ]] && zoxide remove -- "$entry" 2>/dev/null || true
    done < <(zoxide query -l)
  fi
fi

# ────── Step 1: Repositories ───────────────────────────────────────
step1_index_repos() {
  log "Step 1: indexing repo roots under $REPOS_ROOT (+$REPO_BASE_BOOST each)"
  local count=0 gitdir skip pat
  while IFS= read -r -d '' gitdir; do
    skip=0
    for pat in "${REPO_EXCLUDE_PATTERNS[@]}"; do
      [[ "$gitdir" == *"$pat"* ]] && { skip=1; break; }
    done
    [[ "$skip" -eq 1 ]] && continue
    zadd "${gitdir%/.git}" "$REPO_BASE_BOOST"
    count=$((count+1))
  done < <(find "$REPOS_ROOT" -type d -name .git -prune -print0 2>/dev/null)
  log "  indexed $count repo roots"
}

# ────── Step 2: Dropbox Team Folder (full recursion) ───────────────
step2_index_dropbox() {
  log "Step 2: indexing $DROPBOX_ROOT (full recursion, filtered)"
  local count=0 dir
  local pc; pc="$(prune_clause)"
  while IFS= read -r -d '' dir; do
    zadd "$dir" 1
    count=$((count+1))
  done < <(eval "find \"\$DROPBOX_ROOT\" -type d $pc -prune -o -type d -print0" 2>/dev/null)
  log "  indexed $count Dropbox dirs"
}

# ────── Step 3: manas_sambare boost ────────────────────────────────
step3_boost_manas() {
  [[ -d "$MANAS_DIR" ]] || return 0
  log "Step 3: +$MANAS_BOOST boost to manas_sambare subtree"
  local count=0 dir
  local pc; pc="$(prune_clause)"
  while IFS= read -r -d '' dir; do
    zadd "$dir" "$MANAS_BOOST"
    count=$((count+1))
  done < <(eval "find \"\$MANAS_DIR\" -type d $pc -prune -o -type d -print0" 2>/dev/null)
  log "  boosted $count dirs by +$MANAS_BOOST"
}

# ────── Step 4: 'current' folder boost ─────────────────────────────
step4_boost_current() {
  log "Step 4: +$CURRENT_BOOST boost to all 'current' folders under Team Folder"
  local count=0 dir
  while IFS= read -r -d '' dir; do
    zadd "$dir" "$CURRENT_BOOST"
    count=$((count+1))
  done < <(find "$DROPBOX_ROOT" -type d -iname current -print0 2>/dev/null)
  log "  boosted $count 'current' dirs by +$CURRENT_BOOST"
}

# ────── Step 5: Key parent dirs (family roots + passport) ──────────
# Goal:
#   - `z manas`           → manas_sambare root (not a random sub-doc with "Manas" in name)
#   - `z manas passport`  → manas_sambare/.../passport (parent, holds current/ + previous/)
step5_boost_key_dirs() {
  log "Step 5: +$KEY_DIR_BOOST boost to family-member roots + key parent dirs"
  local count=0 dir name

  # 5a: each family member's root dir
  if [[ -d "$FAMILY_MEMBERS_DIR" ]]; then
    while IFS= read -r -d '' dir; do
      zadd "$dir" "$KEY_DIR_BOOST"
      count=$((count+1))
    done < <(find "$FAMILY_MEMBERS_DIR" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
  fi

  # 5b: 'passport' (and any other key parents) under family_members/*
  for name in "${KEY_PARENT_NAMES[@]}"; do
    while IFS= read -r -d '' dir; do
      zadd "$dir" "$KEY_DIR_BOOST"
      count=$((count+1))
    done < <(find "$FAMILY_MEMBERS_DIR" -type d -iname "$name" -print0 2>/dev/null)
  done

  log "  boosted $count key parent dirs by +$KEY_DIR_BOOST"
}

# ────── Verification ───────────────────────────────────────────────
verify() {
  log "Verification:"
  printf '  total entries: %s\n' "$(zoxide query -l | wc -l)"
  echo "  --- top 15 by score ---"
  zoxide query -ls | head -15 | sed 's/^/    /'
  echo "  --- probes ---"
  local q
  for q in "manas" "manas passport" "manas current" "mangesh passport" "image" "image_service" "current"; do
    printf '    z %-22s → %s\n' "$q" "$(zoxide query $q 2>/dev/null || echo '(no match)')"
  done
}

# ────── Run ────────────────────────────────────────────────────────
step1_index_repos
step2_index_dropbox
step3_boost_manas
step4_boost_current
step5_boost_key_dirs
verify
log "Done."
