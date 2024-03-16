# EXPORT
set fish_greeting                                 # Supresses fish's intro message
set TERM "xterm-256color"                         # Sets the terminal type
set --export PYENV_ROOT $HOME/.pyenv
# set VIRSH_DEFAULT_CONNECT_URI "qemu:///system"
set VIRSH_DEFAULT_CONNECT_URI qemu:///system
export VIRSH_DEFAULT_CONNECT_URI=qemu:///system

# AUTOCOMPLETE AND HIGHLIGHT COLORS
set fish_color_normal brcyan
set fish_color_autosuggestion '#7d7d7d'
set fish_color_command brcyan
set fish_color_error '#ff6c6b'
set fish_color_param brcyan

if status is-interactive
    # Commands to run in interactive sessions can go here
    set -Ux PYENV_ROOT $HOME/.pyenv
    set -U fish_user_paths $PYENV_ROOT/bin $fish_user_paths
end


# Aliases
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'

alias ls='lsd'
alias lt='ls --tree'
alias weather='curl wttr.in'
alias monitor='btop --utf-force'
alias battery='system_profiler SPPowerDataType | grep -A3 -B7 "Condition"'
alias find='fzf -q'
alias lg='lazygit'

# confirm before overwriting something
# alias cp="cp -i"
# alias mv='mv -i'
alias rm='rm -i'


# RANDOM COLOR SCRIPT
# Get this script from my GitLab: gitlab.com/dwt1/shell-color-scripts
# Or install it from the Arch User Repository: shell-color-scripts
# colorscript --blacklist pipes2
# colorscript --blacklist pipes2-slim
# colorscript random

# SETTING THE STARSHIP PROMPT
starship init fish | source


# pyenv init
status is-login; and pyenv init --path | source
status is-interactive; and pyenv init - | source
set PATH $PYENV_ROOT/shims:$PATH

# zoxide
zoxide init fish | source

# atuin (SQL Database to search history)
atuin init fish | source
