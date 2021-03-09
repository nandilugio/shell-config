# Environment config
Or what others call _dotfiles_.

## Linux

### Config for gnome shell

```sh
gsettings set org.gnome.shell.app-switcher current-workspace-only true
```

## Mac OS X

```
defaults write com.apple.Finder AppleShowAllFiles true
killall Finder
```

### SSH and Keychain

https://apple.stackexchange.com/questions/48502/how-can-i-permanently-add-my-ssh-private-key-to-keychain-so-it-is-automatically

### iterm & tmux

/bin/sh -c 'PATH=/usr/local/bin:$PATH ~/bin/n.tmux-new-terminal-window'

### Keys setup

https://stackoverflow.com/questions/33270381/delete-forward-character-iterm2-osx

Then, to be as compatible to my Linux i3 setup as possible, without much of a hassle:

#### System
- Swap Cmd and Opt
- Defaults keybindings
- Remap Spotlight so it's in center key (old Option/Meta, now Cmd)

#### iTerm
- Clear _all_ general keybindings (including nav shortcuts, etc.)
- In profile > keys:
  - Both Option/Meta keys to send `Esc+` (for `termux`)
  - Load preset: Natural text editing
  - Remove `M-left` and `M-right`, now conflicting with `tmux` mappings

#### Spectacle
Remember now Option/Meta, in the center, is Command. We want Spectacle in that center key (M below).
Unmap everything, then map:
- * Half: `S-M-*`
- Fullscreen: M-f
- Prev/Next Display: C-S-M-Left/Right

