function git-pull-all --description "Fetch and pull all branches from remote"
    argparse h/help -- $argv
    or return 1

    if set -q _flag_help
        echo "Usage: git-pull-all [OPTIONS]"
        echo ""
        echo "Fetch and pull all branches from remote repositories."
        echo ""
        echo "Options:"
        echo "  --help, -h      Show this help message"
        return 0
    end

    git fetch --all
    git pull --all
end
