function ghq-get --description "ghq get with an optional GitHub credential username"
    # Usage:
    #   ghq-get <url>                       # use the default (personal) account
    #   ghq-get <username> <url>            # clone with the given GitHub username
    #                                       #   (e.g. manas-turing)
    #
    # Examples:
    #   ghq-get https://github.com/Manas73/dotfiles.git
    #   ghq-get manas-turing https://github.com/turing-genai-apps/cerner-clone.git
    #
    # Why this exists:
    #   `ghq get` runs `git clone` before the target directory exists,
    #   so ~/.gitconfig's `includeIf gitdir:` entries do not fire during
    #   the initial clone. Without an explicit override, every clone
    #   authenticates as whichever GitHub account is the default in
    #   ~/.gitconfig (Manas73). Turing clones therefore fail with
    #   "Repository not found".
    #
    #   This function lets you pick the credential username explicitly
    #   for the clone. After the clone, ~/.gitconfig's includeIf rules
    #   take over for subsequent operations in the new repo.

    if test (count $argv) -eq 0
        echo "usage: ghq-get [<github-username>] <url>" >&2
        return 2
    end

    set -l username ""
    set -l target ""

    if test (count $argv) -eq 1
        set target $argv[1]
    else
        # Two or more args: first is the username override, the rest
        # are passed to `ghq get`. The last non-flag argument is the
        # clone URL from ghq's perspective.
        set username $argv[1]
        set -e argv[1]
        set target $argv[-1]
    end

    if test -z "$target"
        echo "ghq-get: missing <url>" >&2
        return 2
    end

    if test -n "$username"
        set -lx GIT_CONFIG_COUNT 1
        set -lx GIT_CONFIG_KEY_0 credential.https://github.com.username
        set -lx GIT_CONFIG_VALUE_0 $username
        ghq get $argv
    else
        ghq get $argv
    end
end
