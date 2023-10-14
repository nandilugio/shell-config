# Environment config

Or what others call _dotfiles_.

## Common config on all platforms

- Install zsh, prezto, etc.
- Install git, configure ssh github access, etc.
- Install vim, tmux, etc.
- Then:

```sh
# Clone the project
git clone git@github.com:nandilugio/shell-config.git ~/.shell-config

# Link/copy dotfiles
for f in $(ls ~/.shell-config/common_dotfiles); do ln -s ~/.shell-config/common_dotfiles/$f ~/.$f; done
ln -s ~/.shell-config/bin ~/bin
# TODO: Check if there's anything specific for the platform

# Configure the shell
echo -e "\n\n# Me\nsource bin/shell-start.zsh\n" >> ~/.zprofile
vim ~/bin/shell-start.zsh ~/.zprofile ~/.zshrc # <---

# Set git profiles
cp ~/.shell-config/gitconfig_host.example ~/.gitconfig_host
vim ~/.gitconfig_host # <---

# ...and set git profile for the project
pushd ~/.shell-config
g profile-pers
popd
```

## Linux

### Gnome shell

```sh
gsettings set org.gnome.shell.app-switcher current-workspace-only true
```

## Mac OS X

```sh
defaults write com.apple.Finder AppleShowAllFiles true
killall Finder
```

### SSH and Keychain

https://apple.stackexchange.com/questions/48502/how-can-i-permanently-add-my-ssh-private-key-to-keychain-so-it-is-automatically

### iTerm2 & tmux

Set this command to run for new windows:

```sh
/bin/sh -c 'PATH=/usr/local/bin:$PATH ~/bin/n.tmux-new-terminal-window'
```

### Keys setup

https://stackoverflow.com/questions/33270381/delete-forward-character-iterm2-osx

Then, to be as compatible to my Linux `i3` setup as possible, without much of a hassle:

#### System

- Swap Cmd and Opt
- Remap Spotlight so it's in center key (old Option/Meta, now Cmd)

#### iTerm2

- Clear _all_ general keybindings (including nav shortcuts, etc.)
- In profile > keys:
  - Both Option/Meta keys to send `Esc+` (for `tmux`)
  - Load preset: Natural text editing
  - Remove `M-left` and `M-right`, now conflicting with `tmux` mappings

#### Rectangle

Remember now Option/Meta, in the center, is Command. We want Rectangle in that center key (`M` below).
Unmap everything, then map:
- \* Half: `S-M-*`
- Fullscreen: `M-f`
- Prev/Next Display: `C-S-M-Left/Right`

