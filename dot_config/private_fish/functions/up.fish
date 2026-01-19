# Function to go up multiple directories
function up --description "Navigate up multiple directory levels"
    argparse h/help -- $argv
    or return 1

    if set -q _flag_help
        echo "Usage: up [OPTIONS] [LEVELS]"
        echo ""
        echo "Navigate up multiple directory levels."
        echo ""
        echo "Options:"
        echo "  --help, -h      Show this help message"
        echo ""
        echo "Arguments:"
        echo "  LEVELS          Number of levels to go up (default: 1)"
        echo ""
        echo "Shortcuts:"
        echo "  .2, .3, .4, ... Navigate up 2, 3, 4, ... levels"
        return 0
    end

    set -l levels $argv[1]
    if test -z "$levels"
        set levels 1
    end

    set -l path ""
    for i in (seq $levels)
        set path "$path../"
    end

    cd $path
end

# Dynamically create .2 through .9 functions
for i in (seq 2 9)
    function .$i --inherit-variable i
        up $i
    end
end
