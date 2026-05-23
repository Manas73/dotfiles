function git-deep-copy --description "Track all remote branches locally and pull all changes"
    argparse h/help -- $argv
    or return 1

    if set -q _flag_help
        echo "Usage: git-deep-copy [OPTIONS]"
        echo ""
        echo "Create local tracking branches for all remote branches and pull all changes."
        echo ""
        echo "Options:"
        echo "  --help, -h      Show this help message"
        return 0
    end

    bash -c 'git branch -r | grep -v "\->" | while read remote; do git branch --track "${remote#origin/}" "$remote"; done'
    git fetch --all
    git pull --all
end
