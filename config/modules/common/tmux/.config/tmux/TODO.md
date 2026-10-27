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

## 2. tmux-fingers is loaded from a path that does not exist

**Where:** `tmux.conf:288`

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

---

## 3. 3.8 themes: decide whether to adopt them

**Where:** `tmux.conf`, `set -sq theme terminal` (Appearance)

**Why:** 3.8 added built-in light/dark themes for 256+ colour terminals, theme
colour names for styles (`themeyellow`, `themeblack`, ...), and reports the
terminal's theme to panes. The upgrade from 3.5a (2026-10-27) pinned
`theme terminal` to keep the old colours and avoid that rabbit hole.

**Do:** Try `detect` (the default) and see what changes: copy mode selection,
choose-tree, menus, and whatever we don't style. Consider moving our own
`colourNNN` styles to theme names, so tmux follows light/dark. Check that nvim
and Claude Code still pick the right background.

---

## 4. Default bindings added in 3.6-3.8: adopt, or keep ours

**Why:** Leaning towards defaults is the goal, but not at the cost of muscle
memory without a plan. Upgrading from 3.5a added these (none clash with ours):

- `Pref Tab` / `Pref S-Tab`: `switch-mode`, fast window / session switcher in a
  floating pane. Overlaps our `Pref s` (`choose-tree -O time`).
- `Pref *`: new floating pane. `Pref @`: toggle a pane floating/tiled.
- `Pref g`: key table to move/resize floating panes (arrows, `1-4` corners,
  `0` fill, `M-` variants also resize).
- `Pref T`: set the pane title (shown in our `pane-border-format`).
- Mouse: Ctrl+drag creates a floating pane, Alt+drag on a pane or border moves
  the pane, clicking the status line switches client (was `select-window`),
  right-click on empty space opens the window menu. Copy-mode `r` is now
  `refresh-now`.

**Do:** Try them, decide which replace ours (and drop ours), and note any that
should be unbound.

---

## 5. New features (3.6-3.8) worth trying

- Floating and modal panes (`new-pane`), e.g. `Pref h` as a modal pane instead
  of `display-popup`, or a scratch shell / Claude Code over nvim.
- Copy mode: `copy-mode-line-numbers` (relative/hybrid),
  `copy-mode-current-line-style`, auto refresh (`refresh-on`).
- Hooks: OSC 133 events (`pane-command-finished`, needs the prompt to emit OSC
  133) and monitor hooks (`set-hook -B`, e.g. on `pane_last_output_time`) to
  flag a finished command or an idle Claude Code pane.
- Auto-hiding `pane-scrollbars`, `focus-follows-mouse`, `remain-on-exit
  failed-key`, `capture-pane -I` (timestamps per line).
- Already on, for reference: synchronized output and OSC 9;4 progress bars are
  forwarded to Ghostty (detected since 3.8).

---

## 6. Older tmux versions: best-effort compatibility

**Why:** The config targets the latest tmux (3.8 as of 2026-10-27) but should
still load on older hosts. Current guards: `extended-keys` only from 3.6 (the
paste bug), `set -sq theme` (unknown before 3.8), the session picker's sort
order (`time` became `activity` in 3.7). The `xterm-ghostty:extkeys`
terminal feature is redundant from 3.8 and only set on 3.6-3.7.

**Do:** When adding options from new versions, use `set -q` or an `%if
#{e|>=|f|0:#{s/[^0-9.]//:version},X}` guard. The `s///` strips suffixes like
`3.7c` (otherwise the comparison is empty, i.e. false), and `|0` makes the
result `0`/`1` (plain `f` gives `0.00`, which `#{&&:}` takes as true). Drop
guards once older versions stop mattering.
