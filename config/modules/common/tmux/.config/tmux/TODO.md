# tmux config — changes to make later

Items 1-2 were found 2026-09-28 in a read-through of the nvim and tmux
configs. Paths are relative to this directory.

Related, filed on the nvim side: the `M-a` prefix swallows fzf-lua's `alt-a`
(toggle-all) inside nvim's pickers — `../nvim/TODO.md` item 17.

---

## 1. `S-M-h/j/k/l` pane swaps: one duplicated, one missing, probably all dead

**Where:** `tmux.conf:121-125`

```tmux
# Move panes using Shift-Alt-vim_arrow without prefix
bind -n S-M-h swap-pane -U
bind -n S-M-k swap-pane -U
bind -n S-M-h swap-pane -D
bind -n S-M-j swap-pane -D
```

**Why:** Two problems, the second of which makes the first moot.

- **Typo.** `S-M-h` is bound twice; the second wins, so it swaps *down*, and
  `S-M-l` is never bound. The arrow block above (`:116-119`) has the intended
  shape: left/up = `-U`, right/down = `-D`. `list-keys` on the live server
  confirms `M-S-h swap-pane -D` and no `M-S-l`.
- **Wrong key name.** With `extended-keys off` (the default, and what this
  server runs), Alt+Shift+h reaches tmux as `ESC H`, which tmux names `M-H`,
  not `M-S-h`. Checked on a scratch server (`tmux -L`, `-f /dev/null`, a
  client attached through `script`) with `send-keys -K`, which feeds keys
  through the client's key tables as typing would:

  | bound as | sent | fired |
  |---|---|---|
  | `M-S-h` | `M-H` | no |
  | `M-K` | `M-K` | yes |
  | `S-M-Left` | `M-S-Left` | yes |

  So the letter variants most likely never fire, while the arrow variants
  work: arrows carry their modifiers in the escape sequence (`CSI 1;4D`),
  letters only in their case.

**Not yet verified:** a physical keypress. `send-keys -K` is the closest
simulation, but press Alt+Shift+k in a split window once to confirm nothing
happens.

**Do:** Bind the uppercase forms, keeping the arrow block's directions:

```tmux
bind -n M-H swap-pane -U
bind -n M-K swap-pane -U
bind -n M-L swap-pane -D
bind -n M-J swap-pane -D
```

Then check nothing else wants `M-H`/`M-J`/`M-K`/`M-L`: tmux takes them for
every program in every pane, as it already does `M-h/j/k/l`. The nvim config
avoids Meta for that reason (`../nvim/docs/keymaps.md`, design decision 5).

---

## 2. tmux-fingers is loaded from a path that does not exist

**Where:** `tmux.conf:277`

```tmux
if-shell 'test -f ~/Projects/thirds/tmux-fingers/tmux-fingers.tmux' 'run-shell ~/Projects/thirds/tmux-fingers/tmux-fingers.tmux'
```

**Why:** `~/Projects/thirds/` has `tmux-resurrect` but no `tmux-fingers`, so
the `if-shell` is false and the line does nothing, silently. Pref `F` (its
default trigger) is unbound on the live server.

It has not worked for longer than that: `73534bc`'s message records that the
old line tested `~/.tmux-plugins/` but ran `~/.tmux/plugins/`, "two paths that
were never both present". The move fixed the path mismatch, but the plugin was
never cloned to the new location. So it may not have been in use at all.

**Do:** Decide whether it is wanted. If yes, clone it to
`~/Projects/thirds/tmux-fingers` and check its README for the install step. If
not, drop the line.
