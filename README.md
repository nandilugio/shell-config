# Shell Environment Config

Or what others call _dotfiles_.

## Common config on all platforms

- Install zsh, prezto, etc.
- Install git, configure ssh github access, etc.
- Install (n)vim, tmux, etc.
- Install lazygit, etc.
- Then:

```sh
# Clone the project
git clone git@github.com:nandilugio/shell-config.git ~/.shell-config

# Link dotfiles
for f in $(ls ~/.shell-config/common_dotfiles); do ln -s ~/.shell-config/common_dotfiles/$f ~/.$f; done

# TODO: link dot_donfig and lib_app_support files

# Link bin folder
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

https://macos-defaults.com/keyboard/applepressandholdenabled.html
https://stackoverflow.com/questions/33152551/how-can-i-disable-applepressandholdenabled-for-a-specific-application-repeat

```sh
defaults write NSGlobalDomain "ApplePressAndHoldEnabled" -bool "false"
defaults write com.apple.Finder AppleShowAllFiles true
killall Finder
```

### SSH and Keychain

https://apple.stackexchange.com/questions/48502/how-can-i-permanently-add-my-ssh-private-key-to-keychain-so-it-is-automatically

### iTerm2 & tmux

Set this command to run for new windows:

```sh
/bin/sh -c 'PATH=/opt/homebrew/bin:$PATH ~/bin/n.tmux-new-terminal-window'
```

### Keys setup

This assumes aerospace/i3 window-manager is used.

#### Modifier keys

- Swap Cmd and Opt on PC keyboards
- Remap Spotlight so it's in center key (old Option/Meta, now Cmd)

The idea is to _more or less_ have (this can be refined... TODO!):
- Meta to control tmux
- Meta+Cmd to control the window-manager
- Ctrl and Cmd / Alt to behave normally

Physical order in Mac and Pc:
```
PC:             Ctrl Win    Alt*
PC in Mac(*):   Ctrl (Alt)* (Win)   <== Swaped
Mac:            Ctrl Opt*   Cmd

* = Meta
```

https://github.com/tmux/tmux/wiki/Modifier-Key://github.com/tmux/tmux/wiki/Modifier-Keys

#### Delete key

https://stackoverflow.com/questions/33270381/delete-forward-character-iterm2-osx

#### iTerm2

- Clear _all_ general keybindings (including nav shortcuts, etc.)
- In profile > keys:
  - Ensure "Report modifiers using CSI u" is checked
  - Both Option/Meta keys to send `Esc+` (for `tmux`)
  - Load preset: Natural text editing
  - Remove `M-left` and `M-right`, now conflicting with `tmux` mappings

#### Other

Some apps allow import-export of their configs from the app itself. See [`macos/app-exportable`](macos/app-exportable).

Others rely on the [UserDefaults](https://developer.apple.com/documentation/foundation/userdefaults) system to persist user settings. For those see [`macos/plists`](macos/plists).

#### TODO

##### Un-tidy info

Nvim > Mason > Install Solargraph (Ruby LSP for older projects with Ruby 2.7, etc.): https://github.com/mason-org/mason.nvim/issues/1493#issuecomment-3263742698
