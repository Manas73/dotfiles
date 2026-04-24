#!/usr/bin/env bash
#
# strip-git-origin-tokens.sh
#
# Find git clones under ~/Repositories/github.com/<owner>/<repo> that have
# credentials embedded in their remote URLs (most commonly GitHub Personal
# Access Tokens of the form ghp_*, gho_*, ghu_*, ghs_*, or github_pat_*)
# and rewrite each remote URL to its canonical form:
#
#   https://<user>:<TOKEN>@github.com/<owner>/<repo>(.git)?
#     -> https://github.com/<owner>/<repo>(.git)?
#   https://<user>@github.com/<owner>/<repo>(.git)?
#     -> https://github.com/<owner>/<repo>(.git)?
#
# Cleans credentials from both remote URLs (e.g. remote.origin.url) and
# submodule URLs recorded in the local .git/config (submodule.<name>.url).
# Entries in a tracked .gitmodules file are left alone; this script only
# modifies local .git/config state.
#
# Credentials remain available through ~/.git-credentials via the 'store'
# helper, and identity routing (personal vs turing) is handled by
# ~/.gitconfig's includeIf blocks. Per-repo origin URLs therefore do not
# need to carry a token.
#
# Default mode: dry-run. Pass --apply to actually rewrite origins.
# Never prints secrets; affected URLs are shown with credentials
# replaced by <redacted>.
#
# Usage:
#   scripts/strip-git-origin-tokens.sh                 # dry run
#   scripts/strip-git-origin-tokens.sh --apply         # rewrite
#   scripts/strip-git-origin-tokens.sh --root <dir>    # override scan root
#   scripts/strip-git-origin-tokens.sh --remote <name> # rewrite a remote
#                                                     #   other than origin
#   scripts/strip-git-origin-tokens.sh --all-remotes   # scan every remote
#                                                     #   per repo, not just
#                                                     #   origin

set -euo pipefail

ROOT="${HOME}/Repositories/github.com"
REMOTE="origin"
APPLY=0
ALL_REMOTES=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --apply)
            APPLY=1
            shift
            ;;
        --root)
            ROOT="$2"
            shift 2
            ;;
        --remote)
            REMOTE="$2"
            shift 2
            ;;
        --all-remotes)
            ALL_REMOTES=1
            shift
            ;;
        -h|--help)
            sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "unknown argument: $1" >&2
            exit 2
            ;;
    esac
done

if [[ ! -d "$ROOT" ]]; then
    echo "root does not exist: $ROOT" >&2
    exit 1
fi

redact_url() {
    # Replace credentials in an https URL with <redacted>.
    # Input examples:
    #   https://user:token@github.com/foo/bar.git
    #   https://user@github.com/foo/bar.git
    # Output:
    #   https://<redacted>@github.com/foo/bar.git
    local url="$1"
    # shellcheck disable=SC2001
    echo "$url" | sed -E 's|(https?://)[^@/]+@|\1<redacted>@|'
}

canonicalize_url() {
    # Strip user:token@ or user@ credentials from an https URL.
    local url="$1"
    # shellcheck disable=SC2001
    echo "$url" | sed -E 's|(https?://)[^@/]+@|\1|'
}

has_embedded_credentials() {
    # Return 0 if the URL has embedded credentials; 1 otherwise.
    # Matches https://<something>@<host>/.
    [[ "$1" =~ ^https?://[^/@]+@[^/] ]]
}

remote_has_embedded_credentials() {
    # Return 0 if ANY url for this remote has embedded credentials.
    local repo_dir="$1"
    local remote_name="$2"
    local u
    while IFS= read -r u; do
        [[ -z "$u" ]] && continue
        if has_embedded_credentials "$u"; then
            return 0
        fi
    done < <(git -C "$repo_dir" config --get-all "remote.${remote_name}.url" 2>/dev/null || true)
    return 1
}

process_remote() {
    # Handle both single-URL and multi-URL remotes. A git remote can have
    # multiple [remote "<name>"] url entries for push-to-multiple-remotes
    # setups; we rewrite every URL that has embedded credentials and
    # leave clean ones alone.
    local repo_dir="$1"
    local remote_name="$2"

    # Collect all URL values for this remote, in order.
    local -a urls=()
    while IFS= read -r u; do
        [[ -z "$u" ]] && continue
        urls+=("$u")
    done < <(git -C "$repo_dir" config --get-all "remote.${remote_name}.url" 2>/dev/null || true)

    (( ${#urls[@]} == 0 )) && return 0

    # Build the rewritten list alongside a per-URL change flag.
    local -a new_urls=()
    local -a changed_flags=()
    local any_changed=0
    local u canonical
    for u in "${urls[@]}"; do
        if has_embedded_credentials "$u"; then
            canonical="$(canonicalize_url "$u")"
            new_urls+=("$canonical")
            changed_flags+=(1)
            any_changed=1
        else
            new_urls+=("$u")
            changed_flags+=(0)
        fi
    done

    (( any_changed )) || return 0

    # Report before/after for each URL that would change.
    local i
    for (( i = 0; i < ${#urls[@]}; i++ )); do
        (( changed_flags[i] )) || continue
        local tag
        if (( APPLY )); then tag="[APPLIED]"; else tag="[DRY RUN]"; fi
        printf '  %s %s [url #%d]\n     before: %s\n     after:  %s\n' \
            "$tag" "${repo_dir}#${remote_name}" "$i" \
            "$(redact_url "${urls[i]}")" "${new_urls[i]}"
    done

    (( APPLY )) || return 0

    # Git does not expose a clean "replace all URLs" primitive for
    # multi-URL remotes; set-url replaces only the first match. To
    # rewrite cleanly we remove the remote block and recreate it.
    #
    # Preserve fetch refspec(s); other per-remote options (pushurl,
    # mirror, etc.) are not used in this dotfiles setup. If they ever
    # are, extend the preservation block below.
    local -a fetch_specs=()
    while IFS= read -r spec; do
        [[ -z "$spec" ]] && continue
        fetch_specs+=("$spec")
    done < <(git -C "$repo_dir" config --get-all "remote.${remote_name}.fetch" 2>/dev/null || true)

    # Remove the remote, then recreate it with the first URL.
    git -C "$repo_dir" remote remove "$remote_name"
    git -C "$repo_dir" remote add "$remote_name" "${new_urls[0]}"

    # Add any additional URLs.
    local j
    for (( j = 1; j < ${#new_urls[@]}; j++ )); do
        git -C "$repo_dir" remote set-url --add "$remote_name" "${new_urls[j]}"
    done

    # Restore fetch refspec(s). `remote add` installs a default
    # +refs/heads/*:refs/remotes/<name>/* which is usually what we want;
    # override only if the original had something different.
    if (( ${#fetch_specs[@]} > 0 )); then
        git -C "$repo_dir" config --unset-all "remote.${remote_name}.fetch" || true
        local spec
        for spec in "${fetch_specs[@]}"; do
            git -C "$repo_dir" config --add "remote.${remote_name}.fetch" "$spec"
        done
    fi
}

process_submodule_urls() {
    # Strip credentials from submodule.<name>.url entries in the local
    # .git/config. Uses git config --get-regexp to enumerate keys.
    local repo_dir="$1"
    local keys_urls
    keys_urls="$(git -C "$repo_dir" config --local --get-regexp '^submodule\..*\.url$' 2>/dev/null || true)"
    [[ -z "$keys_urls" ]] && return 0

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local key="${line%% *}"
        local url="${line#* }"
        has_embedded_credentials "$url" || continue

        local canonical
        canonical="$(canonicalize_url "$url")"
        [[ "$canonical" == "$url" ]] && continue

        submodule_changed=$((submodule_changed + 1))

        local before_redacted
        before_redacted="$(redact_url "$url")"

        local tag
        if (( APPLY )); then tag="[APPLIED]"; else tag="[DRY RUN]"; fi

        printf '  %s %s [%s]\n     before: %s\n     after:  %s\n' \
            "$tag" "${repo_dir}" "$key" \
            "$before_redacted" "$canonical"

        if (( APPLY )); then
            git -C "$repo_dir" config --local "$key" "$canonical"
        fi
    done <<< "$keys_urls"
}

total=0
changed=0
submodule_changed=0

# Enumerate candidate clones: anything that looks like <root>/<owner>/<repo>/.git
while IFS= read -r -d '' git_dir; do
    repo_dir="$(dirname "$git_dir")"
    # Only handle regular clones; skip worktrees or submodules that have
    # a .git file instead of a directory.
    [[ -d "$git_dir" ]] || continue
    total=$((total + 1))

    if (( ALL_REMOTES )); then
        while IFS= read -r rname; do
            [[ -z "$rname" ]] && continue
            if remote_has_embedded_credentials "$repo_dir" "$rname"; then
                changed=$((changed + 1))
                process_remote "$repo_dir" "$rname"
            fi
        done < <(git -C "$repo_dir" remote 2>/dev/null)
    else
        if remote_has_embedded_credentials "$repo_dir" "$REMOTE"; then
            changed=$((changed + 1))
            process_remote "$repo_dir" "$REMOTE"
        fi
    fi

    # Always clean submodule URLs regardless of --all-remotes.
    process_submodule_urls "$repo_dir"
done < <(find "$ROOT" -maxdepth 4 -type d -name '.git' -print0)

echo
if (( APPLY )); then
    echo "Scanned $total clone(s) under $ROOT."
    echo "Rewrote $changed remote(s) and $submodule_changed submodule URL(s)."
    echo
    echo "Tokens remain available via ~/.git-credentials. If you want to"
    echo "rotate them, revoke the old PATs on github.com and re-run any"
    echo "push to repopulate the store helper with the new tokens."
else
    echo "Scanned $total clone(s) under $ROOT."
    echo "$changed remote(s) and $submodule_changed submodule URL(s) would be rewritten."
    echo "Re-run with --apply to perform the rewrite."
fi
