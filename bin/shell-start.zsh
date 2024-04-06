# Update!
#pushd ~/shell-config; git pull; popd

# Homebrew
eval "$(/opt/homebrew/bin/brew shellenv)"  # NOTE: You may have already added this to .zprofile or .zshrc already
#export PATH="/usr/local/sbin:$PATH"

# libpq (psql, etc.) from Homebrew
export PATH="/opt/homebrew/opt/libpq/bin:$PATH"

# FZF
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh  # NOTE: Vim plug may have already installed FZF, adding this command to .zprofile or .zshrc already
export FZF_DEFAULT_COMMAND="find . -type f -not -path '*/\.git/*'"

# Perl (and therefore pgtap, etc.)
#PATH=$PATH:"/usr/local/Cellar/perl/5.32.0/bin"

# Rbenv
eval "$(rbenv init - zsh)"

# Pyenv
export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# Pipx
#PATH=$PATH:~/.local/bin

# Direnv
#eval "$(direnv hook zsh)"

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Me
#export PS1=$PS1$'\n'"%# "  # Newline after prompt for agnoster ohmyzsh theme
export KEYTIMEOUT=1
export PATH=~/bin:$PATH
export EDITOR='vim'
export VISUAL='vim'
setopt HIST_IGNORE_SPACE
alias g=git

