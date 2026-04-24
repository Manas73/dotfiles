#!/usr/bin/env bash
#
# migrate-github-origins-to-ssh.sh
#
# Scan ~/Repositories/github.com/<owner>/<repo>/.git/config clones and
# rewrite github.com remote + submodule URLs to the correct SSH alias
# declared in ~/.ssh/config.
#
# Owner -> alias mapping is declared inline below. Owners not listed
# fall through to the personal alias.
#
# Rewrites these URL shapes:
#   https://[user(:token)?@]github.com/<owner>/<repo>(.git)?
#   git@github.com:<owner>/<repo>(.git)?
#   ssh://git@github.com/<owner>/<repo>(.git)?
#
# Leaves non-github.com URLs alone. Already-migrated URLs
# (git@github.com-personal:... or git@github.com-turing:...) are
# skipped.
#
# Dry-run by default. Pass --apply to actually rewrite.
# Never prints credentials; any user/token embedded in the source URL
# is redacted in output.
#
# Usage:
#   scripts/migrate-github-origins-to-ssh.sh                 # dry run
#   scripts/migrate-github-origins-to-ssh.sh --apply         # rewrite
#   scripts/migrate-github-origins-to-ssh.sh --root <dir>    # override scan root
#   scripts/migrate-github-origins-to-ssh.sh --remote <name> # rewrite a
#                                                            #   remote other
#                                                            #   than origin
#   scripts/migrate-github-origins-to-ssh.sh --all-remotes   # scan every remote

set -euo pipefail

ROOT="${HOME}/Repositories/github.com"
REMOTE="origin"
APPLY=0
ALL_REMOTES=0

# Owner -> SSH alias mapping. Keep in sync with ~/.ssh/config.
# Owners not listed use the personal alias.
declare -A OWNER_ALIAS=(
    [manas-turing]="github.com-turing"
    [TuringEnterprises]="github.com-turing"
    [TuringGpt]="github.com-turing"
    [turing-genai-apps]="github.com-turing"
)
DEFAULT_ALIAS="github.com-personal"

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
            sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
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

alias_for_owner() {
    local owner="$1"
    if [[ -n "${OWNER_ALIAS[$owner]:-}" ]]; then
        echo "${OWNER_ALIAS[$owner]}"
    else
        echo "$DEFAULT_ALIAS"
    fi
}

redact_url() {
    # Replace any embedded credentials with <redacted> for safe printing.
    local url="$1"
    # shellcheck disable=SC2001
    echo "$url" | sed -E 's|(https?://)[^@/]+@|\1<redacted>@|'
}

rewrite_github_url() {
    # Rewrite a single github.com URL to the correct SSH alias.
    # Print the rewritten URL on stdout. Return 0 if rewritten, 1 if
    # unchanged (not a github.com URL, or already using a github.com-*
    # alias that matches the expected owner mapping).
    local url="$1"
    local owner repo rest alias

    # https://[user[:token]@]github.com/<owner>/<repo>(.git)?
    if [[ "$url" =~ ^https?://([^/]+@)?github\.com/([^/]+)/([^/]+)$ ]]; then
        owner="${BASH_REMATCH[2]}"
        repo="${BASH_REMATCH[3]}"
        alias="$(alias_for_owner "$owner")"
        echo "git@${alias}:${owner}/${repo}"
        return 0
    fi

    # ssh://git@github.com/<owner>/<repo>(.git)?
    if [[ "$url" =~ ^ssh://git@github\.com/([^/]+)/([^/]+)$ ]]; then
        owner="${BASH_REMATCH[1]}"
        repo="${BASH_REMATCH[2]}"
        alias="$(alias_for_owner "$owner")"
        echo "git@${alias}:${owner}/${repo}"
        return 0
    fi

    # git@github.com:<owner>/<repo>(.git)?   (bare github.com, no alias)
    if [[ "$url" =~ ^git@github\.com:([^/]+)/([^/]+)$ ]]; then
        owner="${BASH_REMATCH[1]}"
        repo="${BASH_REMATCH[2]}"
        alias="$(alias_for_owner "$owner")"
        echo "git@${alias}:${owner}/${repo}"
        return 0
    fi

    # git@github.com-<alias>:<owner>/<repo>(.git)?  (already aliased)
    # Keep it if the alias matches the expected mapping; rewrite if it
    # doesn't (e.g. a Turing repo incorrectly pointing at -personal).
    if [[ "$url" =~ ^git@github\.com-([^:]+):([^/]+)/([^/]+)$ ]]; then
        local current_alias_suffix="${BASH_REMATCH[1]}"
        owner="${BASH_REMATCH[2]}"
        repo="${BASH_REMATCH[3]}"
        alias="$(alias_for_owner "$owner")"
        if [[ "github.com-${current_alias_suffix}" == "$alias" ]]; then
            return 1
        fi
        echo "git@${alias}:${owner}/${repo}"
        return 0
    fi

    # Not a github.com URL; leave alone.
    return 1
}

process_remote() {
    local repo_dir="$1"
    local remote_name="$2"

    local -a urls=()
    while IFS= read -r u; do
        [[ -z "$u" ]] && continue
        urls+=("$u")
    done < <(git -C "$repo_dir" config --get-all "remote.${remote_name}.url" 2>/dev/null || true)

    (( ${#urls[@]} == 0 )) && return 0

    local -a new_urls=()
    local -a changed_flags=()
    local any_changed=0
    local u new
    for u in "${urls[@]}"; do
        if new="$(rewrite_github_url "$u")"; then
            # Preserve the original .git suffix if any.
            if [[ "$u" == *.git ]] && [[ "$new" != *.git ]]; then
                new="${new}.git"
            fi
            new_urls+=("$new")
            changed_flags+=(1)
            any_changed=1
        else
            new_urls+=("$u")
            changed_flags+=(0)
        fi
    done

    (( any_changed )) || return 0

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

    local -a fetch_specs=()
    while IFS= read -r spec; do
        [[ -z "$spec" ]] && continue
        fetch_specs+=("$spec")
    done < <(git -C "$repo_dir" config --get-all "remote.${remote_name}.fetch" 2>/dev/null || true)

    git -C "$repo_dir" remote remove "$remote_name"
    git -C "$repo_dir" remote add "$remote_name" "${new_urls[0]}"

    local j
    for (( j = 1; j < ${#new_urls[@]}; j++ )); do
        git -C "$repo_dir" remote set-url --add "$remote_name" "${new_urls[j]}"
    done

    if (( ${#fetch_specs[@]} > 0 )); then
        git -C "$repo_dir" config --unset-all "remote.${remote_name}.fetch" || true
        local spec
        for spec in "${fetch_specs[@]}"; do
            git -C "$repo_dir" config --add "remote.${remote_name}.fetch" "$spec"
        done
    fi
}

process_submodule_urls() {
    # Rewrite submodule.<name>.url entries in the local .git/config to
    # their SSH equivalents.
    local repo_dir="$1"
    local keys_urls
    keys_urls="$(git -C "$repo_dir" config --local --get-regexp '^submodule\..*\.url$' 2>/dev/null || true)"
    [[ -z "$keys_urls" ]] && return 0

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local key="${line%% *}"
        local url="${line#* }"
        local new
        if ! new="$(rewrite_github_url "$url")"; then
            continue
        fi
        if [[ "$url" == *.git ]] && [[ "$new" != *.git ]]; then
            new="${new}.git"
        fi
        submodule_changed=$((submodule_changed + 1))

        local tag
        if (( APPLY )); then tag="[APPLIED]"; else tag="[DRY RUN]"; fi
        printf '  %s %s [%s]\n     before: %s\n     after:  %s\n' \
            "$tag" "${repo_dir}" "$key" \
            "$(redact_url "$url")" "$new"

        if (( APPLY )); then
            git -C "$repo_dir" config --local "$key" "$new"
        fi
    done <<< "$keys_urls"
}

remote_has_github_url() {
    local repo_dir="$1"
    local remote_name="$2"
    local u
    while IFS= read -r u; do
        [[ -z "$u" ]] && continue
        if rewrite_github_url "$u" >/dev/null; then
            return 0
        fi
    done < <(git -C "$repo_dir" config --get-all "remote.${remote_name}.url" 2>/dev/null || true)
    return 1
}

total=0
changed=0
submodule_changed=0

while IFS= read -r -d '' git_dir; do
    repo_dir="$(dirname "$git_dir")"
    [[ -d "$git_dir" ]] || continue
    total=$((total + 1))

    if (( ALL_REMOTES )); then
        while IFS= read -r rname; do
            [[ -z "$rname" ]] && continue
            if remote_has_github_url "$repo_dir" "$rname"; then
                changed=$((changed + 1))
                process_remote "$repo_dir" "$rname"
            fi
        done < <(git -C "$repo_dir" remote 2>/dev/null)
    else
        if remote_has_github_url "$repo_dir" "$REMOTE"; then
            changed=$((changed + 1))
            process_remote "$repo_dir" "$REMOTE"
        fi
    fi

    process_submodule_urls "$repo_dir"
done < <(find "$ROOT" -maxdepth 4 -type d -name '.git' -print0)

echo
if (( APPLY )); then
    echo "Scanned $total clone(s) under $ROOT."
    echo "Rewrote $changed remote(s) and $submodule_changed submodule URL(s)."
    echo
    echo "Remotes now use github.com-personal / github.com-turing SSH aliases"
    echo "declared in ~/.ssh/config. HTTPS auth via credential helpers is no"
    echo "longer exercised for these clones."
else
    echo "Scanned $total clone(s) under $ROOT."
    echo "$changed remote(s) and $submodule_changed submodule URL(s) would be rewritten."
    echo "Re-run with --apply to perform the rewrite."
fi
