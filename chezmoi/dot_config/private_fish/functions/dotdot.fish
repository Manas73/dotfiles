# Function to go up multiple directories
# Usage: up 3
function up
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
for i in (seq 1 9)
    function .$i --inherit-variable i
        up $i
    end
end
