# Update!
#pushd ~/shell-config; git pull; popd

# FZF
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
export FZF_DEFAULT_COMMAND="find . -type f -not -path '*/\.git/*'"

PATH=~/bin:$PATH
PS1=$PS1$'\n'"%# "  # Newline after prompt
setopt HIST_IGNORE_SPACE
alias g=git

