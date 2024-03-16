function copy
    set count (count $argv | tr -d \n)
    if test "$count" = 2; and test -d "$argv[1]"; or test -d "$argv[2]"
        set from (echo $argv[1] | string trim --right --chars=/)
        set to (echo $argv[2])
        command cp -r $from $to
    else
        command cp $argv
    end
end

