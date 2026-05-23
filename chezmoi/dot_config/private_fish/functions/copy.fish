function copy --description "Smart copy wrapper that handles directories automatically"
    argparse h/help -- $argv
    or return 1

    if set -q _flag_help
        echo "Usage: copy [OPTIONS] SOURCE... DEST"
        echo ""
        echo "Smart wrapper around 'cp' that automatically uses -r for directories."
        echo ""
        echo "Options:"
        echo "  --help, -h      Show this help message"
        echo ""
        echo "Arguments:"
        echo "  SOURCE          Source file(s) or directory"
        echo "  DEST            Destination path"
        return 0
    end

    set count (count $argv | tr -d \n)
    if test "$count" = 2; and test -d "$argv[1]"; or test -d "$argv[2]"
        set from (echo $argv[1] | string trim --right --chars=/)
        set to (echo $argv[2])
        command cp -r $from $to
    else
        command cp $argv
    end
end

