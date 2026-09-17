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

# TODO: Update this. Now everything to be linked is in the `config/` dir. Also, link dot_donfig, lib_app_support, etc.

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

### tmux

Config is XDG: `config/home/dot_config/tmux` links to `~/.config/tmux`. Don't
also keep a `~/.tmux.conf` — tmux 3.1+ loads both if both exist.

Plugins are third-party checkouts, referenced from `tmux.conf` and guarded by
`if-shell`, so a missing one is simply skipped:

```sh
git clone https://github.com/tmux-plugins/tmux-resurrect ~/Projects/thirds/tmux-resurrect

# Optional, currently not installed:
git clone https://github.com/Morantron/tmux-fingers ~/Projects/thirds/tmux-fingers
```

Resurrect saves with `prefix + Ctrl-s` and restores with `prefix + Ctrl-r`. It
also restores the `claude --resume <id>` command into each pane that was
running Claude Code (typed, not executed; see `bin/n.tmux-claude-sessions-*`).

Its saves go to resurrect's default dir, `~/.local/share/tmux/resurrect`
(it switches to `~/.tmux/resurrect` if that directory exists; `@resurrect-dir`
overrides both). They include pane contents — whatever was on screen — so:

```sh
mkdir -p ~/.local/share/tmux/resurrect && chmod 700 ~/.local/share/tmux/resurrect
```

Don't start a session name with `%`: that is tmux's pane-id sigil, so a target
like `-t '% Planning:1'` is read as a pane id and never resolves. Resurrect
creates the session but then fails to split its panes, restoring only the
first one of each window. Prefix with `#` instead, or pass `=` to force an
exact name match.

## Linux

### Gnome shell

```sh
gsettings set org.gnome.shell.app-switcher current-workspace-only true
```

## Mac OS X

https://macos-defaults.com/keyboard/applepressandholdenabled.html
https://stackoverflow.com/questions/33152551/how-can-i-disable-applepressandholdenabled-for-a-specific-application-repeat

Nvim config uses Ctrl+Space for showing docs on autocompletion with blink. This is taken by the system for selecting input sources. Unmap on System Settings > Keyboard > Keyboard Shortcuts... > Input Sources

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
