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

# Editor
set -gx EDITOR "nvim"

# GHQ Variables
set GHQ_ROOT '~/Repositories'

# Zellij Variables
set ZELLIJ_AUTO_ATTACH true
# set ZELLIJ_AUTO_EXIT false

if status is-interactive
    # Commands to run in interactive sessions can go here
    set -Ux PYENV_ROOT $HOME/.pyenv
    set -U fish_user_paths $PYENV_ROOT/bin $fish_user_paths
    
    # Read the content of terminal.sh into a variable
    set terminal_name (cat ~/.config/.settings/terminal.sh | string trim)
    
    if test "$TERM_PROGRAM" = $terminal_name
        eval (zellij setup --generate-auto-start fish | string collect)
    end

end


# Aliases
alias grep='grep --color=auto'

alias ls='eza -l'
alias lt='ls --tree'
alias weather='curl wttr.in'
alias btop='btop --utf-force'
alias find='fzf -q'
alias nv='nvim'
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
alias cd="z"

# atuin (SQL Database to search history)
atuin init fish | source
