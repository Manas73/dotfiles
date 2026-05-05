function ghq-get --description 'Clone repo with ghq using a specific SSH key'
    # Help
    if contains -- --help $argv || contains -- -h $argv
        echo "Usage: ghq-get <ssh-key-name> <repository>"
        echo ""
        echo "Examples:"
        echo "  ghq-get my-work git@github.com:x-motemen/ghq.git"
        echo "  ghq-get my-work x-motemen/ghq"
        echo "  ghq-get my-personal myuser/personal-repo"
        return 0
    end

    # Argument validation
    if test (count $argv) -ne 2
        echo "Error: Exactly two arguments required" >&2
        echo "Usage: ghq-get <ssh-key-name> <repository>" >&2
        return 1
    end

    set ssh_key_name $argv[1]
    set repo $argv[2]

    set ssh_key ~/.ssh/$ssh_key_name

    # Check if key exists
    if not test -f $ssh_key
        echo "Error: SSH key not found: $ssh_key" >&2
        return 1
    end

    # Convert short form (user/repo) → git@github.com:user/repo.git
    if not string match -q '*@*' $repo && not string match -q 'ssh://*' $repo && not string match -q 'https://*' $repo
        if string match -q '*/*' $repo
            set repo "git@github.com:$repo.git"
        else
            echo "Error: Invalid repository format. Use user/repo or full git@ URL" >&2
            return 1
        end
    end

    echo "Cloning with SSH key: $ssh_key_name"
    echo "Repo: $repo"

    # Run ghq with specific identity
    GIT_SSH_COMMAND="ssh -i $ssh_key" ghq get $repo

    if test $status -eq 0
        echo (set_color green)"Successfully cloned"(set_color normal)
    else
        echo (set_color red)"Clone failed"(set_color normal) >&2
    end
end