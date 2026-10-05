# Shared by every target (macOS, Linux, aiws guests): tools that may be missing are behind checks.

# Homebrew
[ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"  # NOTE: You may have already added this to .zprofile or .zshrc already
#export PATH="/usr/local/sbin:$PATH"

# libpq (psql, etc.) from Homebrew
[ -d /opt/homebrew/opt/libpq/bin ] && export PATH="/opt/homebrew/opt/libpq/bin:$PATH"

# FZF
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh  # NOTE: Vim plug may have already installed FZF, adding this command to .zprofile or .zshrc already
export FZF_DEFAULT_COMMAND="find . -type f -not -path '*/\.git/*'"

# Perl (and therefore pgtap, etc.)
#PATH=$PATH:"/usr/local/Cellar/perl/5.32.0/bin"

# Rbenv
command -v rbenv >/dev/null && eval "$(rbenv init - zsh)"

# Pyenv
export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
command -v pyenv >/dev/null && eval "$(pyenv init -)"

# Pipx
#PATH=$PATH:~/.local/bin

# AWS ElasticBeanstalk CLI (https://github.com/aws/aws-elastic-beanstalk-cli-setup)
[ -d ~/.ebcli-virtual-env/executables ] && export PATH=~/.ebcli-virtual-env/executables:$PATH

# Direnv
#eval "$(direnv hook zsh)"

# NVM
export NVM_DIR="/opt/homebrew/opt/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Github
alias ghcs='gh copilot suggest'
alias ghce='gh copilot explain'


# Me
#export PS1=$PS1$'\n'"%# "  # Newline after prompt for agnoster ohmyzsh theme
export KEYTIMEOUT=1
export PATH=~/bin:$PATH
export EDITOR='nvim'
export VISUAL='nvim'
setopt HIST_IGNORE_SPACE
alias g=git
alias lg='git fetch && lazygit'
export LG_CONFIG_FILE=~/.config/lazygit/config.yml  # macOS would default to ~/Library/Application Support
alias ttofu='tofu workspace show; read -n 1; tofu'
alias notes='pushd ~/notes && git pull; nvim -c VimwikiIndex; git add .; git commit -am wip && git push; popd'

