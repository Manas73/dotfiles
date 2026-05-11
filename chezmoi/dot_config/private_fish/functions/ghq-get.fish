function ghq-get --description 'Clone with ghq via an SSH host alias from ~/.ssh/config'
    # Help
    if contains -- --help $argv || contains -- -h $argv
        echo "Usage: ghq-get <ssh-host-alias> <user/repo | full-url>"
        echo ""
        echo "Examples:"
        echo "  ghq-get github.com-personal x-motemen/ghq"
        echo "  ghq-get github.com-turing myorg/work-repo"
        echo "  ghq-get gitlab.com mygroup/myrepo"
        echo ""
        echo "<ssh-host-alias> must be a 'Host' entry in ~/.ssh/config."
        return 0
    end

    # Argument validation
    if test (count $argv) -ne 2
        echo "Error: Exactly two arguments required" >&2
        echo "Usage: ghq-get <ssh-host-alias> <repository>" >&2
        return 1
    end

    set alias $argv[1]
    set repo $argv[2]

    # Convert short form user/repo → git@<alias>:user/repo.git
    if not string match -q '*@*' $repo
        and not string match -q 'ssh://*' $repo
        and not string match -q 'https://*' $repo
        if string match -q '*/*' $repo
            set repo "git@$alias:$repo.git"
        else
            echo "Error: Invalid repository format. Use user/repo or full git@ URL" >&2
            return 1
        end
    end

    echo "Cloning via SSH host alias: $alias"
    echo "Repo: $repo"

    ghq get $repo

    if test $status -eq 0
        echo (set_color green)"Successfully cloned"(set_color normal)
    else
        echo (set_color red)"Clone failed"(set_color normal) >&2
    end
end
