function yy --description "Yazi file manager wrapper that changes directory on exit"
	argparse h/help -- $argv
	or return 1

	if set -q _flag_help
		echo "Usage: yy [OPTIONS] [PATH]"
		echo ""
		echo "Launch Yazi file manager and change to the directory on exit."
		echo ""
		echo "Options:"
		echo "  --help, -h      Show this help message"
		echo ""
		echo "Arguments:"
		echo "  PATH            Directory to open (default: current directory)"
		return 0
	end

	set tmp (mktemp -t "yazi-cwd.XXXXXX")
	yazi $argv --cwd-file="$tmp"
	if set cwd (command cat -- "$tmp"); and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
		cd -- "$cwd"
	end
	rm -f -- "$tmp"
end
