# Environment config
Or what others call _dotfiles_.

## Keys setup in Mac OSX

...to be as compatible to my Linux i3 setup as possible, without much of a hassle.

### System
- Swap Cmd and Opt
- Defaults keybindings
- Remap Spotlight so it's in center key (old Option/Meta, now Cmd)

### iTerm
- Clear _all_ general keybindings (including nav shortcuts, etc.)
- In profile > keys:
  - Both Option/Meta keys to send `Esc+` (for `termux`)
  - Load preset: Natural text editing
  - Remove `M-left` and `M-right`, now conflicting with `tmux` mappings

### Spectacle
Remember now Option/Meta, in the center, is Command. We want Spectacle in that center key (M below).
Unmap everything, then map:
- * Half: `S-M-*`
- Fullscreen: M-f
- Prev/Next Display: C-S-M-Left/Right

