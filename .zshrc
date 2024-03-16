# History Config
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000000
SAVEHIST=10000000
setopt BANG_HIST                 # Treat the '!' character specially during expansion.
setopt EXTENDED_HISTORY          # Write the history file in the ":start:elapsed;command" format.
setopt INC_APPEND_HISTORY        # Write to the history file immediately, not when the shell exits.
setopt SHARE_HISTORY             # Share history between all sessions.
setopt HIST_EXPIRE_DUPS_FIRST    # Expire duplicate entries first when trimming history.
setopt HIST_IGNORE_DUPS          # Don't record an entry that was just recorded again.
setopt HIST_IGNORE_ALL_DUPS      # Delete old recorded entry if new entry is a duplicate.
setopt HIST_FIND_NO_DUPS         # Do not display a line previously found.
setopt HIST_IGNORE_SPACE         # Don't record an entry starting with a space.
setopt HIST_SAVE_NO_DUPS         # Don't write duplicate entries in the history file.
setopt HIST_REDUCE_BLANKS        # Remove superfluous blanks before recording entry.
setopt HIST_VERIFY               # Don't execute immediately upon history expansion.
setopt HIST_BEEP                 # Beep when accessing nonexistent history.

# Aliases
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'

alias ls='colorls --dark --sort-dirs'
alias lc='colorls --dark --tree'
alias weather='curl wttr.in'
alias monitor='btop --utf-force'
alias battery='system_profiler SPPowerDataType | grep -A3 -B7 "Condition"'

# Startship
eval "$(starship init zsh)"

# Zoxide
eval "$(zoxide init zsh)"

# Pyenv
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# Peco history selection
peco_select_history() {
  # Initialize peco_flags with the constant part
  local peco_flags="--layout=bottom-up"

  # Add query to peco_flags if arguments are passed
  if [[ $# -gt 0 ]]; then
    peco_flags+=" --query \"$*\""
  fi

  # Fetch and process shell history using 'fc -l'
  local foo=$(history | peco $peco_flags)


  # Extract command number from the selection
  local selected_command_number=$(echo $foo | awk '{print $1}')

  if [[ -n $selected_command_number ]]; then
    # Retrieve the selected command and trim leading spaces
    local selected_command=$(fc -ln $selected_command_number $selected_command_number | sed 's/^[[:space:]]*//')
    BUFFER=$selected_command
  fi

  zle redisplay
}

zle -N peco_select_history
bindkey '^R' peco_select_history
