# Functions needed for !! and !$
function __history_previous_command
  switch (commandline -t)
  case "!"
    commandline -t $history[1]; commandline -f repaint
  case "*"
    commandline -i !
  end
end

function __history_previous_command_arguments
  switch (commandline -t)
  case "!"
    commandline -t ""
    commandline -f history-token-search-backward
  case "*"
    commandline -i '$'
  end
end

# The bindings for !! and !$
function fish_user_key_bindings --description "Set up custom key bindings for history navigation"
  argparse h/help -- $argv
  or return 1

  if set -q _flag_help
    echo "Usage: fish_user_key_bindings [OPTIONS]"
    echo ""
    echo "Set up custom key bindings for the fish shell."
    echo "This function is called automatically by fish on startup."
    echo ""
    echo "Options:"
    echo "  --help, -h      Show this help message"
    echo ""
    echo "Current bindings:"
    echo "  !!              Run the previous command"
    echo "  !\$              Insert the last argument from previous command"
    return 0
  end

  bind ! __history_previous_command
  bind '$' __history_previous_command_arguments
end
