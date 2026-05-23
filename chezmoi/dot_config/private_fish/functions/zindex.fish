# Function to recursively index a directory into zoxide
function zindex --description "Recursively index directories into zoxide"
    argparse h/help -- $argv
    or return 1

    if set -q _flag_help
        echo "Usage: zindex [OPTIONS] DIRECTORY [DEPTH]"
        echo ""
        echo "Recursively index directories into zoxide for faster navigation."
        echo ""
        echo "Options:"
        echo "  --help, -h      Show this help message"
        echo ""
        echo "Arguments:"
        echo "  DIRECTORY       Directory to index"
        echo "  DEPTH           Maximum depth to index (optional)"
        echo ""
        echo "Examples:"
        echo "  zindex ~/Repositories      # Index all subdirectories"
        echo "  zindex ~/Repositories 2    # Index only 2 levels deep"
        return 0
    end

    set -l target_dir $argv[1]
    set -l depth $argv[2]

    if test -z "$target_dir"
        echo "Usage: zindex <directory> [depth]"
        return 1
    end

    if not test -d "$target_dir"
        echo "Error: '$target_dir' is not a directory"
        return 1
    end

    if test -n "$depth"
        echo "Indexing directories under $target_dir (max depth: $depth) into zoxide..."
        find "$target_dir" -maxdepth $depth -type d -exec zoxide add {} \;
    else
        echo "Indexing directories under $target_dir into zoxide..."
        find "$target_dir" -type d -exec zoxide add {} \;
    end

    echo "Done!"
end
