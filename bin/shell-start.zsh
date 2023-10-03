# Update!
#pushd ~/shell-config; git pull; popd

# FZF
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
export FZF_DEFAULT_COMMAND="find . -type f -not -path '*/\.git/*'"

# Perl (and therefore pgtap, etc.)
PATH=$PATH:"/usr/local/Cellar/perl/5.32.0/bin"

# Homebrew
export PATH="/usr/local/sbin:$PATH"

# Pyenv
export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# Pipx
PATH=$PATH:~/.local/bin

# Me
PATH=~/bin:$PATH
PS1=$PS1$'\n'"%# "  # Newline after prompt
setopt HIST_IGNORE_SPACE
alias g=git

