# Function to recursively index a directory into zoxide
# Usage: zindex <directory> [depth]
# Examples:
#   zindex ~/Repositories      # Index all subdirectories
#   zindex ~/Repositories 2    # Index only 2 levels deep
function zindex
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
