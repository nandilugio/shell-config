# tmux config — changes to make later

Items 1-2 were found 2026-09-28 in a read-through of the nvim and tmux
configs. Items 3-6 came from upgrading tmux 3.5a -> 3.8 on 2026-10-27. Paths
are relative to this directory.

Related, filed on the nvim side: the `M-a` prefix swallows fzf-lua's `alt-a`
(toggle-all) inside nvim's pickers — `../nvim/TODO.md` item 17.

---

## 1. ~~`S-M-h/j/k/l` pane swaps: one duplicated, one missing, probably all dead~~ DONE 2026-10-09

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

**Done:** with `extended-keys on` (added the same day for Shift+Enter in Claude
Code), the name changed again. tmux now asks Ghostty for extended keys, and
Ghostty sends Alt+Shift+h with the shifted letter, which tmux names `M-S-H`
(seen with Pref `/` on a real keypress). `M-H` and `M-S-h` don't fire. So the
binds are `M-S-H/J/K/L`, in the arrow block's directions, with the `M-H` forms
left commented for terminals without extended keys. The arrow binds fire in
both modes.

---

## 2. ~~tmux-fingers is loaded from a path that does not exist~~ DROPPED 2026-11-14

It was never cloned to `~/Projects/thirds/tmux-fingers`, so the line did nothing, and before the move to `~/Projects/thirds` its old line tested one path and ran another (`73534bc`). Not used in practice: the line and the README's clone command are gone.

---

## 3. ~~3.8 themes: decide whether to adopt them~~ CLOSED 2026-11-14: kept pinned

`set -sq theme terminal` keeps tmux's pre-3.8 colours. Adopting the themes (`detect`, theme colour names in our styles) would mean restyling for little gain.

---

## 4. ~~Default bindings added in 3.6-3.8: adopt, or keep ours~~ CLOSED 2026-11-14: ours kept

None of 3.6-3.8's new defaults (`Pref Tab` switch-mode, floating panes on `Pref *` `@` `g`, `Pref T`, the mouse changes) clashes with ours, so they are there to try, and nothing needs deciding.

---

## 5. ~~New features (3.6-3.8) worth trying~~ CLOSED 2026-11-14: a wishlist

Floating panes, copy-mode line numbers, OSC 133 and monitor hooks, scrollbars: none is needed now. 3.8's release notes list them if one becomes so.

---

## 6. ~~Older tmux versions: best-effort compatibility~~ MOVED 2026-11-14 to tmux.conf

A rule rather than a task: how to guard an option from a newer version is now the comment heading `tmux.conf`.
