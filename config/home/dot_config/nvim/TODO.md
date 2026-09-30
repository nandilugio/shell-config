# nvim config — changes to make later

Items 1-7 were found 2026-09-16 while investigating the `<leader>gb` blame
popup; 8-16 on 2026-09-18/19 while working on the git setup; 17-22 on
2026-09-28 in a read-through of the nvim and tmux configs; 23-24 on 2026-09-30
while setting up a Python project. Paths are relative to this directory.

---

## 1. ~~Remove the lazygit binding~~ DONE 2026-09-19

**Where:** `lua/keymaps.lua:203`

```lua
{ "<leader>gg", "<Cmd>terminal lazygit<CR>", desc = "Lazygit", needs = "lazygit" },
```

**Why:** It is a bad integration, not a plugin — just a custom binding shelling
out to the `lazygit` binary. As written it opens the TUI in normal mode, so it
renders once and freezes: keystrokes go to Vim, not lazygit. It also replaces
the current window and inherits Neovim's cwd rather than the current file's
repo.

Making it *work* (own tab, `startinsert`, `vim.fs.root` for cwd) is possible but
misses the point — what is actually wanted from the editor is "show me this
commit", not "launch a git UI rooted somewhere". That is a real integration
question, deferred deliberately. See item 5.

**Done:** the binding, the `config/health.lua` row, the `brew install` line in
`README.md`, the `docs/keymaps.md` entry, and the cheatsheet mentions.
`<leader>gg` is now free.

The deferred question in this item — "what is actually wanted is *show me this
commit*" — was answered in the meantime by `<leader>gB` (item 6): the blame
panel's `D` opens the commit under the cursor, all hunks, in a tab.

---

## 2. Completion autotrigger contradicts `'autocomplete'`

**Where:** `lua/options.lua:67` vs `lua/setup/lsp.lua:184`

```lua
-- options.lua:67
vim.o.autocomplete = false

-- setup/lsp.lua:184
vim.lsp.completion.enable(true, client.id, args.buf, { autotrigger = true })
```

**Why:** These fight. The long comment in `options.lua` says the menu should be
"asked for, never volunteered", and notes that turning `'autocomplete'` off
"only skips an InsertCharPre autocommand" — which is exactly what
`autotrigger = true` puts back. In any buffer with a language server attached
the menu most likely pops up on its own, contrary to the documented intent.

**Do:** Set `autotrigger = false` in `setup/lsp.lua`, then confirm in a Python
or Lua buffer that the menu only appears on `<C-n>` / `<C-x><C-o>` /
`<C-Space>`.

**Not yet verified:** whether the menu actually auto-appears in practice, or
whether `'autocomplete' = false` suppresses it anyway. Check before deciding
which of the two is wrong — the fix might equally be to drop the
`options.lua` comment if autotrigger is what is wanted.

**Source says (2026-09-28, v0.12.5):** `'autocomplete'` does not suppress it.
`autotrigger = true` registers its own buffer-local `InsertCharPre` autocmd
(`$VIMRUNTIME/lua/vim/lsp/completion.lua:1175`), independent of the option.
It fires on the server's `triggerCharacters` only (`completion.lua:1141`,
`:1232`), not on every keystroke — so expect the menu to open by itself after
`.` (or whatever the server declares), and nowhere else. Still worth
confirming by typing, but the contradiction is real.

---

## 3. ~~`<C-s>` vs `<C-S>` in the cheatsheet~~ DONE 2026-09-21

**Where:** `lua/setup/keymaps.lua:79-80`.

**Was:** the cheatsheet wrote `<C-s>`, the core-label table wrote `<C-S>`.
Cosmetic only — Ctrl strips case, so both spellings are the same key.

**Done:** standardised on lowercase `<C-s>`, which is the spelling the
cheatsheet and `docs/keymaps.md` already used, so the code now matches its own
documentation rather than the other way round.

The label is applied by a `maparg` lookup, so the spelling had to keep
resolving to the same core mapping. Verified it does: `maparg("<C-s>", "i")`
and `maparg("<C-S>", "i")` both return `lhs = "<C-S>"` with the callback
present — Neovim normalises the case internally.

---

## 4. ~~`<leader>gr` vs `grr` — naming collision~~ NOT AN ISSUE 2026-09-21

**Closed without action.** There is no collision. `gr` is core's LSP prefix
(`grr`, `gri`, `grn`); `<leader>gr` is reset-hunk. `<leader>` is a distinct
key, so the two sequences never race — no shadowing, no timeout ambiguity.
Each namespace is coherent on its own terms: everything under `g` acts on
symbols, everything under `<leader>g` is git.

What this item actually described was that the *letters* `g`+`r` mean different
things depending on whether leader was pressed first — a fact about English,
not about the config. By that reasoning `<leader>gd` would collide with `grd`
and the whole git namespace would be suspect. The leader key is the
disambiguator, and it is pressed deliberately.

---

## 5. Review `undofile` and swap settings

**Where:** `lua/options.lua` — `undofile` is present but commented out:

```lua
-- Undo history is deliberately not persisted.
-- vim.o.undofile = true
```

Swap is untouched entirely, so it is stock Neovim: swap on, in
`~/.local/state/nvim/swap/`.

**Why:** Prompted 2026-09-16 by an "ATTENTION / found a swap file" warning on
opening a big file. The current state is a deliberate choice (the comment says
so) but worth re-deciding as a pair, because together they are the whole
crash-recovery story:

- With `undofile` off, undo history dies with the session. After a crash,
  the swap file is the *only* recovery path — and recovering from swap is
  clumsy, especially in a large file where the changed lines must be found
  by diffing.
- With `undofile` on, `~/.local/state/nvim/undo/` persists undo across
  sessions, so `u` still works after reopening. It also writes a file per
  edited file, which is the cost.

Note the config's autosave (`setup/autosave.lua`) is **off by default**, so
there is no background write covering for either.

**Do:** Decide whether persistent undo is wanted, and whether swap should stay
default. Options, roughly:

1. Leave as is — accept that a crash means swap recovery or nothing.
2. `vim.o.undofile = true` — cheap, survives reopen, no prompt on open.
3. Keep swap but move/raise `updatetime` awareness, or disable swap in favour
   of undofile + autosave.

Recovery recipe, for whenever the prompt appears again (recovery does not
delete the swap — it will prompt again until deleted):

```vim
:e <file>              " choose (r)ecover
:w /tmp/recovered
:e!                    " reload on-disk version
:diffsplit /tmp/recovered
```

Then `]c` / `[c` walk the differing hunks. Statusline shows `[+]` (`%m`,
`statusline.lua:285`) when the recovered buffer really does differ from disk —
if it is absent, the swap held nothing newer. Clean up with
`:call delete(swapname('%'))`.

---

## 6. ~~Add `<leader>gB` — full-file blame~~ DONE 2026-09-19

**Where:** `lua/keymaps.lua`, in the `<leader>g` git section.

```lua
{ "<leader>gB", "<Cmd>Gitsigns blame<CR>", desc = "Blame file", needs = "mod:gitsigns" },
```

**Why:** `:Gitsigns blame` opens a scroll-synced side panel with commit, author
and date for every line — the `git blame` view, in the editor. Nothing in the
config binds it today. `gB` pairs with the existing `<leader>gb` (blame line)
and is free.

Keys inside that window (gitsigns defines them, `actions/blame.lua:546+`):

| key | does |
|---|---|
| `<CR>` | context menu for the commit under the cursor |
| `r` | reblame *at* that commit — walk back through history |
| `d` | diff, in a new tab |
| `D` | diff **that commit**, in a new tab |

`D` also resolves item 7: it opens the whole commit, all hunks, without having
to copy a SHA out of the blame popup. Worth trying before building anything
there.

**Also worth a look, separately:** `current_line_blame` in the
`gitsigns.setup({})` call in `setup/git.lua` — faint virtual text at end of
line showing blame for the cursor line, updating as the cursor moves. Off by
default in gitsigns.

```lua
current_line_blame = true,
current_line_blame_opts = { delay = 300, virt_text_pos = "eol" },
```

Arguably the best fit for that file's stated purpose ("what an editor uniquely
offers is the ambient layer"), but it is a persistent visual change — try it
before keeping it.

**Done:** `<leader>gB`, plus the rest of the namespace gaps in the same pass —
`gS`/`gR` stage/reset buffer, `gq` hunks to quickfix, and the three toggles
nested under `<leader>ug` (`ugd` deleted, `ugw` word diff, `ugb` current-line
blame, the ambient layer this item suggested trying).

`undo_stage_hunk` was deliberately left unbound: gitsigns deprecates it
(`actions.lua:426`) in favour of `stage_hunk()` on a staged hunk, so
`<leader>gs` already toggles. That is only usable now that staged signs are
distinguishable — see item 8.

---

## 7. ~~Open question — seeing a commit from the editor~~ SETTLED 2026-09-21

The thing that started all this: `<leader>gb` shows "Hunk 1 of 4", meaning the
commit that last touched this line changed 4 hunks in this file, with no way to
see the other 3 — gitsigns binds only `q` in that popup (`popup.lua:244`), and
the hunks belong to a historical diff that is not on screen.

**Settled by `<leader>gB`** (item 6). The blame panel's `D` opens the commit
under the cursor, all hunks, in a tab — without copying a SHA out of the popup.
That is better than both candidates this item originally listed: `:Gitsigns
show <sha>` (still needs the SHA by hand) and diffview.nvim (a real dependency,
against the few-plugins rule).

Closed on the intended test — living with it rather than building on it.

---

## 8. ~~`signs_staged` is unconfigured, so staged hunks show the default bars~~ DONE 2026-09-19

**Where:** `lua/setup/git.lua`, the `gitsigns.setup({})` call.

**Why:** gitsigns has **two** sign tables, and only one is set here. `signs`
carries the deliberate `+ ~ - ‾ ≃ ┆` choice ("diff characters rather than
gitsigns' bars, which leave the colour to carry the meaning"). `signs_staged`
is untouched, and `signs_staged_enable` defaults to **true**
(`lua/gitsigns/config.lua:299`), so staged hunks fall back to the shipped
defaults (`config.lua:275`):

```lua
add = { text = '┃' }, change = { text = '┃' }, delete = { text = '▁' },
topdelete = { text = '▔' }, changedelete = { text = '~' },
```

That is why the bars reappear after staging — the file's own comment about
rejecting bars is silently half-applied. Found 2026-09-18.

**Done:** option 1 — same characters as unstaged, colour carries staged-ness.
`GitSignsStaged*` falls back to the unstaged group at half brightness, verified
on the `default` scheme: add `#b3f6c0` → `#597b60`, delete `#ffc0b9` →
`#7f605c`. Same hue, half luminance, so one glyph vocabulary reads for both.

Note `signs_staged` takes no `untracked` key (nothing untracked can be staged);
the other five mirror `signs`. Sign text is capped at **2 display cells**
(`E239` on three), so a prepended marker like `┃+` is possible but would widen
the gutter, which `signcolumn = "yes"` keeps at one column.

---

## 9. No way back to the working tree after `r` / `R` in the blame window

**Where:** behaviour of `:Gitsigns blame` (see item 6), nothing in this config.

**Why:** `r` (reblame at commit) and `R` (reblame at commit **parent**) do more
than move the blame panel — `reblame()` (`actions/blame.lua:279-305`) quits the
blame split, then **replaces the main window's buffer** with
`gitsigns://<gitdir>//<sha>:<relpath>`, the file at that revision, and reopens
blame against it.

Consequences:

- After a few presses you are reading a historical revision, not your file.
- Closing the blame window does **not** return you — the main window is still
  on the old revision.
- The way back is `<C-o>` (jumplist) or `:edit <path>`. gitsigns ships no
  "return to work tree" command. Fugitive does: `gq` in its blame window
  ("close blame, then |:Gedit| to return to work tree version").
- The buffers are `bufhidden = 'wipe'` so they do not accumulate, but nothing
  on screen says you are in one — the statusline shows the ordinary path.

Worth noting `r` is safer than tpope's warning suggests: it takes the sha from
the blame entry under the cursor and clamps the cursor to the new file length,
rather than blindly blaming a parent. `R` (the `^` parent jump) is where drift
can still bite.

**Do:** Two candidates, neither urgent:

1. A marker in the statusline for `gitsigns://` buffers — see item 10.
2. A "back to working tree" binding, e.g. under `<leader>o`, that re-edits the
   real path. Only worth it if the jumplist turns out to be insufficient in
   practice.

---

## 10. ~~Statusline cannot distinguish a historical revision from the real file~~ DONE 2026-09-19

**Where:** `lua/setup/statusline.lua`, `M.path()` / `refresh_path()`.

**Why:** Fallout from item 9. `refresh_path()` stores
`fnamemodify(name, ":.")`, so a buffer named
`gitsigns://<gitdir>//<sha>:<relpath>` renders as an ordinary-looking path.
Nothing indicates the buffer is read-only, historical, or which commit it is —
so "am I looking at my working tree or at 2023?" is unanswerable at a glance.
The same applies to any `fugitive://`-style scheme if one is ever added.

**Done:** `refresh_path()` detects the scheme and rewrites it to
`cheatsheet.md[d4d6c3af]`, which is the name fzf-lua already gives the same
thing (`actions.lua:1135`), so the two arrive at one shape. Before this it
rendered as a path and `pathshorten` mangled it to
`g:///U/n/.s/.g//4/h/d/n/cheatsheet.md`.

Only this direction is worth doing. `gitsigns://` is a scheme and cannot be
mistaken for a real path; recognising `path[rev]` would mean a regex over every
filename, and a file honestly called `report[abc123].md` would then be labelled
a revision it is not. A marker that lies is worse than one that is quiet.

Cost taken deliberately: an earlier version coloured the revision in
`StatuslineDelete` so it read as a warning. Matching fzf's plainer form gives
that up — `r`/`R` is a deliberate action, so the loudness matters less now the
mechanism is known. Gitsigns' own buffer name is untouched: it keys off it in
`diffthis.lua:132` and `:328`, so renaming would break reuse and refresh.

Correction to what this item first claimed: `b:gitsigns_head` does **not**
become the sha. `Status.update` merges with the existing dict
(`status.lua:29`), so the real buffer's `head` survives and the statusline goes
on saying `master` while showing a 2025 revision. The buffer name is the only
reliable source, hence parsing it.

---

## 11. ~~Git history bindings — the four operations~~ DONE 2026-09-19

**Where:** `lua/keymaps.lua`, `<leader>g` section. Partly done: `<leader>gl`
(line/selection history) shipped 2026-09-18 in `b51de90`.

**Why:** Blame answers *who touched this last*; it takes a manual walk up the
parents to learn *how the line got here*. `git log -L` answers that directly.
Four related-but-distinct operations, which the letters kept colliding over
(`l` = line or log, `f` = file or function, `h` = hunk or history):

| op | binding | status |
|---|---|---|
| line blame | `<leader>gb` | done (gitsigns) |
| line/selection history | `<leader>gl` | done (`b51de90`) |
| function history | `<leader>gt` | done |
| file history | `<leader>gf` | done |

Letters chosen against researched convention (2026-09-18, primary sources —
full notes in `docs/research-keybindings.md`, "GIT HISTORY bindings"):

- **`b` = blame** is the strongest convention found anywhere: GitLens, Zed,
  Magit, LazyVim (in name), AstroNvim's `gL`, and this config already.
- **`t` = trace** for function history, from Magit's
  `magit-log-trace-definition` (`C-c M-g t`), which is the only tool with a
  distinct default key for the operation. Frees `f` to mean *file*
  unambiguously, dissolving the file-or-function collision.
- **`f` = file history** — weak but uncontested; only LazyVim binds it, for
  exactly this.
- **`h` deliberately avoided for history**: in Neovim `h` means *hunk*
  (LazyVim's `<leader>gh` is a group literally named "hunks"; Kickstart uses
  the whole `<leader>h` namespace for them), and `ih` is already the hunk text
  object here. `h` = history is a VS Code/GitLens convention that does not
  transfer.

Also found: **no Neovim distro ships a default key for line or function
history at all.** Fugitive (`:{range}Gclog`), diffview
(`:'<,'>DiffviewFileHistory`, and the only plugin supporting `-L:funcname:`)
and Neogit (`:NeogitLogCurrent`) expose them as ex-commands only. gitsigns has
neither — its entire public API contains no `log -L`, no `--follow`. And
LazyVim's `<leader>gb`, labelled "Git Blame Line", actually runs
`git log -L <line>,+1:<file>` — i.e. line history, mislabelled.

**Open decision — output shape.** `<leader>gl` currently dumps inline patches
into a split (`setup/git.lua`). But `fzf-lua`, already installed, does much of
this: `git_bcommits` in **visual** mode runs `git log -L <range>:<file>`
(`providers/git.lua:264`) and in **normal** mode gives whole-file history; it
presents a pickable commit list with a preview pane, `<CR>` to open the file at
that commit, `<C-y>` to yank the sha. `git_blame` takes a range the same way.
So:

- the split dump suits *reading a whole evolution* and needs only `git`
  (portability rule), and handles the bare cursor line, which fzf-lua does not;
- the picker suits *navigating to a commit* and is already written, but needs
  `fzf` and is visual-only.

**Settled:** `gf` is fzf-lua's picker with our patch dump as the `needs`/
`fallback`, so it degrades to git-only on a bare server. `gl` and `gt` stay
ours — fzf-lua has no cursor-line case and no funcname form.

One thing found the hard way: git ships funcname patterns but they are inert
until a `.gitattributes` enables them per repository (`*.py diff=python`). An
earlier note here claiming Ruby and Python were "covered" was wrong — shipping
is not enabling. `gt` now says so when `-L` reports "no match".

**Also relevant to item 7:** `-L` is *cursor-scoped* where gitsigns is
*hunk-scoped*, which is why their diffs differ for the same commit. On a `def`
line, `-L <line>,<line>` shows the signature changing but hides the body lines
that changed with it; `-L :funcname:` (item's `<leader>gt`) shows the whole
method each time, and is the better tool there.

**Do:** Settle the output shape, then add `gt` and `gf`, and update
`cheatsheet.md` `## Git` and `docs/keymaps.md` §5. (The convention research is
already in `docs/research-keybindings.md`.)

---

## 12. ~~Bind bare `:FzfLua` — the picker of pickers~~ DONE 2026-09-19

**Where:** `lua/keymaps.lua`, `<leader>f` section.

**Why:** fzf-lua ships **124** pickers; this config binds 12. The rest are
invisible unless you already know they exist — which is how `<leader>gl` came
to be written without noticing that `git_bcommits` in visual mode already runs
`git log -L <range>:<file>` (`providers/git.lua:264`). Bare `:FzfLua` opens a
searchable list of all of them, which is the cheapest fix for that whole class
of mistake.

Candidates worth knowing about, none bound today: `git_hunks`, `git_stash`,
`git_reflog`, `git_status`, `blines`/`lines` (fuzzy search in buffer / all
buffers), `resume` (reopen the last picker with its query), `changes`, `jumps`,
`marks`, `registers`, `spell_suggest`, `treesitter`, `undotree`,
`lsp_finder`, `lsp_incoming_calls` / `lsp_outgoing_calls`.

**Do:** Add something like

```lua
{ "<leader>fF", function() require("setup.fzf").builtin() end,
  desc = "All pickers", needs = "fzf" },
```

**Done:** `<leader>f?` — `f?` reads as "what else is there". Cheatsheet and
`docs/keymaps.md` updated.

---

## 13. ~~Bind `FzfLua.resume` — reopen the last picker~~ DONE 2026-09-19

**Where:** `lua/keymaps.lua`, `<leader>f` section.

**Why:** Probably the highest-value unbound picker, and unlike item 12 it is a
daily action rather than a discovery aid. Reopens the previous picker *with its
query and cursor position intact* — the case is: grep for something, jump to the
third hit, realise you wanted the fifth. Without it you retype the search.

**Do:**

**Done:** `<leader>f.` — `.` as "again", which nothing else here claims.
There is no cross-distro convention to follow: LazyVim has no equivalent,
Telescope used `<leader>f<Space>`, AstroNvim `<Leader>f'`.

---

## 14. UPSTREAM BUG — reblame crashes across a rename

**Where:** gitsigns, not this config. `lua/gitsigns/git/blame.lua:230`.

**Symptom:** `r` or `R` in the `:Gitsigns blame` window, on a commit older than
a rename of the file, throws:

```
...gitsigns/git/blame.lua:230: contents must be provided for files without a
base object
```

Hitting Enter leaves you in the old revision with the blame panel gone.

**Cause:** gitsigns asks for the file at its **current** path in the target
revision. Across a rename that path does not exist, so `object_missing` is
true and the `assert(contents, ...)` guard fires. There is **no rename
handling anywhere** in `git/blame.lua`, `actions/blame.lua` or
`actions/diffthis.lua` — no `--follow`, no `-M` (grepped, zero hits, plugin at
f2421c5 2026-08-31).

Hit here because `cheatsheet.md` moved from `dot_config/nvim/` to
`config/home/dot_config/nvim/` in `682d197`, so every reblame crossing that
commit breaks. Confirmed with plain git:

```
$ git cat-file -e d4d6c3af:config/home/dot_config/nvim/cheatsheet.md
fatal: path '...' exists on disk, but not in 'd4d6c3af'
```

Note it is not commit-specific: a reblame "works" only when the line's blame
entry happens not to cross the rename. Two commits that both look broken at the
git level can behave differently depending on which line the cursor was on.

**Minimal repro (verified 2026-09-19):**

```sh
git init repro && cd repro
printf 'one\ntwo\n' > a.txt && git add a.txt && git commit -m 'add a.txt'
git mv a.txt b.txt && git commit -m 'rename a.txt to b.txt'
nvim b.txt      # :Gitsigns blame, cursor on a line from the first commit, press r
```

`git log --follow -- b.txt` traverses the rename without trouble, so the
information is available; gitsigns simply does not ask for it.

**Workarounds:** `<C-o>` back to the working tree. `<leader>gl` (`git log -L`)
follows renames, so it answers the same question without crashing.

**Do:** File upstream at lewis6991/gitsigns.nvim. Then leave it — patching
around plugin internals from this config would be fragile and is against the
few-moving-parts rule.

### Report, ready to paste

> **Title:** `blame`: reblame (`r`/`R`) asserts when the file was renamed in an
> older commit
>
> Pressing `r` (reblame at commit) or `R` (reblame at parent) in the
> `:Gitsigns blame` window throws when the target revision predates a rename of
> the file:
>
> ```
> ...gitsigns/git/blame.lua:230: contents must be provided for files without a base object
> stack traceback:
>   ...gitsigns/git/blame.lua:230: in function 'run_blame'
>   ...gitsigns/cache.lua:167: in function 'run_blame'
>   ...gitsigns/cache.lua:248: in function 'get_blame'
>   ...gitsigns/actions/blame.lua:489: in function 'blame'
>   ...gitsigns/actions/blame.lua:304
> ```
>
> After dismissing the error the window is left showing the old revision with
> the blame panel closed.
>
> **Repro** (gitsigns f2421c5, Neovim 0.12.5):
>
> ```sh
> git init repro && cd repro
> printf 'one\ntwo\n' > a.txt && git add a.txt && git commit -m 'add a.txt'
> git mv a.txt b.txt && git commit -m 'rename a.txt to b.txt'
> nvim b.txt
> ```
>
> `:Gitsigns blame`, put the cursor on a line attributed to the first commit,
> press `r`.
>
> **Cause:** `reblame()` resolves the revision and then requests the file at its
> *current* path. Across a rename that path does not exist in the target
> revision, so `object_missing` is set and the `assert(contents, ...)` at
> `git/blame.lua:230` fires. `git log --follow` traverses the rename fine, so
> the information is available.
>
> **Expected:** follow the rename (as `git log --follow` / `git blame -C` do),
> or fail gracefully with a message rather than an assertion.

---

## 15. ~~Statusline segments kept the active background in inactive windows~~ DONE 2026-09-19

**Where:** `lua/setup/statusline.lua`, `set_highlights()`.

**Was:** every segment group pinned `bg` to `StatusLine`'s background:

```lua
local bg = hl("StatusLine", "bg")
vim.api.nvim_set_hl(0, "StatuslineAccent", { fg = ..., bg = bg })
```

An inactive window draws its line with `StatusLineNC` instead, which in the
`default` scheme is `#2c2e33` against `StatusLine`'s `#4f5258`. So in every
split that did not have focus, each coloured segment stayed lit at the active
colour and read as a patch on a darker line — visible wherever two windows are
open, not just beside the blame panel.

**Done:** the five segment groups are foreground-only, so they inherit whichever
statusline group the window is actually using. The mode blocks keep an explicit
`bg`, which is right — a mode block is meant to be a solid colour in both
states.

First misdiagnosed as a gitsigns interaction, because the blame panel's span
highlight (`CursorLine`, painted to the window edge with `hl_eol`) happens to be
*exactly* `StatusLineNC` in this scheme, which made the boundary vanish there
too. That part is real but incidental; the patches were ours.

---

## 16. UPSTREAM BUG — blame panel throws once its file buffer is wiped

**Where:** gitsigns, not this config. `lua/gitsigns/actions/blame.lua:389`.

**Symptom:** every cursor move in the `:Gitsigns blame` panel throws, until the
panel is closed:

```
Error in CursorMoved Autocommands for "<buffer=127>":
...gitsigns/actions/blame.lua:36: Invalid buffer id: 126
stack traceback:
  [C]: in function 'nvim_buf_set_extmark'
  ...blame.lua:36:  in function 'hl_line'
  ...blame.lua:389: in function 'on_cursor_moved'
  ...blame.lua:644
```

**Cause:** `r`/`R` put a revision buffer in the file window, and revision
buffers are created with `bufhidden = 'wipe'` (`actions/diffthis.lua:69`). Show
anything else in that window — `<leader><leader>`, `]b`, `:bnext`, closing it —
and Neovim wipes the buffer, because nothing displays it any more.

The panel's `CursorMoved` autocmd still holds the `bufnr` captured when blame
opened (`blame.lua:643-645`). `on_cursor_moved` then calls
`hl_line(bufnr, ...)` at `:391` with no validity check, and
`nvim_buf_set_extmark` rejects the dead id.

Verified directly: a buffer with `bufhidden = 'wipe'` goes invalid the moment
its window shows another buffer, and `nvim_buf_set_extmark` on it returns
`Invalid buffer id`.

**This is an oversight rather than a design problem.** The `CursorMoved` /
`BufLeave` autocmd registered immediately above, at `blame.lua:628-637`, already
guards the same variable:

```lua
if api.nvim_buf_is_valid(bufnr) then
  api.nvim_buf_clear_namespace(bufnr, ns_hl, 0, -1)
end
```

as does the `WinClosed` handler at `:662`. Only the `CursorMoved` at `:643`
omits it. A one-line guard in `on_cursor_moved`, or a `BufWipeout` autocmd
closing the panel with its buffer, would fix it.

**Repro:**

```sh
nvim <file>          # any file in a git repo with history
:Gitsigns blame      # then r on any older commit
<C-l>                # focus the file window
:bnext               # or <leader><leader>, or any buffer switch
<C-h>                # back to the panel, move the cursor -> throws
```

**Independent of item 14.** That one is a missing object at a revision across a
rename; this is a wiped buffer and an unguarded autocmd. Same file, separate
fixes. File both together.

**Related:** item 9 — the panel outliving the buffer it describes is exactly the
disorientation that "no way back to the working tree" is about.

---

## 17. `M-a` in the pickers is the tmux prefix

**Where:** `cheatsheet.md:44`, and fzf-lua's default `keymap.fzf`
(`fzf-lua/lua/fzf-lua/defaults.lua:242`, `["alt-a"] = "toggle-all"`).

**Why:** The cheatsheet lists "M-a ticks all", but `tmux.conf` sets
`prefix M-a`, so tmux eats the key and fzf never sees it. Same class as the
`M-h` note two lines below it in the cheatsheet, which is already documented.
`M-a M-a` works, because `tmux.conf` binds it to `send-prefix`.

The other Alt keys the cheatsheet lists (`M-q`, `M-i`, `M-f`) are not bound in
tmux, so they get through.

**Do:** Either note in the cheatsheet that it is `M-a M-a` under tmux, or give
toggle-all another key in `setup/fzf.lua`. Careful with the second: as that
file notes, a `keymap.fzf` table *replaces* fzf-lua's defaults rather than
extending them, so the whole set would have to be restated.

---

## 18. Cheatsheet still describes the old revision marker

**Where:** `cheatsheet.md:115-116`

```
r and R land you in a read-only revision of the file: the statusline then
reads name@sha in red.
```

**Why:** Out of date since item 10. The statusline now shows `path[sha]`,
the same shape fzf-lua uses, and not in red: the colour was dropped on purpose
(item 10, "Cost taken deliberately").

**Do:** Change it to something like "the statusline then reads path[sha]".

---

## 19. `keymaps.lua` header lists `]n` / `[n` as normal-mode defaults

**Where:** `lua/keymaps.lua:15-17`

```lua
-- Nvim 0.12 defaults we deliberately do NOT redefine (they are already right):
--   grn gra grr grx gO   K   ]d [d ]D [D   ]q [q ]Q [Q   ]b [b   ]<Space> [<Space>
--   gc gcc   <C-]> <C-t>   an in ]n [n
```

**Why:** Core maps `]n` / `[n` (and `]N` / `[N`) in **visual mode only**:
incremental selection, extending the selection to the next or previous node
(`$VIMRUNTIME/lua/vim/_core/defaults.lua:454-458`). In normal mode they are
unmapped. `an` / `in` are visual and operator-pending (`:470`, `:478`), which
the comment gets right. The cheatsheet does not repeat the mistake.

**Do:** Comment only, e.g. `an in (x/o)  ]n [n (x)`. No behaviour change.

---

## 20. ~~Teach `zm` / `zr` as **m**ask / **r**eveal~~ DONE 2026-09-30

**Where:** `cheatsheet.md` (no folds section at all today) and the which-key
popup under `z`.

**Why:** Vim's own names are "Fold more" and "Reduce folding" (`:h zm`,
`:h zr`), which which-key shows as "Fold more" / "Fold less"
(`which-key.nvim/lua/which-key/plugins/presets.lua:148,150`). Both make you
translate: `zm` *lowers* `'foldlevel'` to fold *more*. **Mask / reveal**
states the effect directly, and carries over to the capitals: `zM` masks
everything, `zR` reveals everything. Worth saying it is a level at a time,
across the whole window: these set `'foldlevel'`, re-applying it to every fold
and discarding any `zo` / `zc` done by hand. One section is `za` / `zc` / `zo`.

**Do:**

1. **Cheatsheet:** add a Folds section with the mnemonic. While there, the
   one gotcha that makes `zm` look broken: `'foldlevel'` starts at 99, so the
   first `zm`s close nothing — `zM` first, then `zr` to reveal levels.
2. **which-key:** relabel the four, e.g. "Mask one more level (fold more)",
   "Reveal one more level (fold less)", "Mask all", "Reveal all". Presets load
   first so a user spec overrides them (`which-key/config.lua:280`), and they
   create no mappings (`config.lua:44`), so a desc-only
   `wk.add({ { "zm", desc = "..." } })` should be enough — not yet verified.

   The catch is where it lives. `setup/keymaps.lua` feeds which-key only
   `M.groups`, which are prefix *groups*, and `core_labels` relabels real
   mappings via `maparg` — `zm` is neither, being a built-in command. Needs a
   small third shape, e.g. `M.labels` in `keymaps.lua` (`{ lhs, desc }`, no
   mapping, which-key only). Decide that before writing it.

**Done:** the cheatsheet has a Folds section with the mnemonic and the
`'foldlevel'` gotcha. The shape question went away: `zc zC za zA zm zM zR zn`
became real mappings in `keymaps.lua` meanwhile (they show the fold column), so
their `desc` is the label. `zr` is mapped to itself for its label. The labels
also say what `zC` / `zA` really do, per item 22.

---

## 21. Learn more about `gO`

**Where:** nothing in this config yet. Core's markdown ftplugin maps `gO` to
`vim.treesitter._headings.show_toc()` (`$VIMRUNTIME/ftplugin/markdown.lua:3`),
which puts the headings in the **location list** and opens it.

**Why:** Came up 2026-09-28 while trying it. It is a quickfix window
underneath, and that shows as soon as it is resized:

- Each line is really `/full/path/file.md|<lnum>| <heading>`. `syntax/qf.lua`
  conceals everything up to the second `| ` (`conceallevel=3`), but wrapping and
  horizontal scrolling still count the hidden text. Hence wrapping far short of
  the border, blank rows with a long path, and `h` / `l` / `zl` appearing dead
  under `nowrap` — they are moving through the invisible path.
- The indent is non-breaking spaces placed *after* the hidden prefix, because
  quickfix trims ordinary leading whitespace (`treesitter/_headings.lua:98`). So
  `breakindent` sees no indent, and `'listchars'` (`nbsp:␣`) draws it as `␣`.

**Works today:** `:setlocal nowrap`, then `$` / `0` to see the end of a heading
and come back. `<C-w>L` moves it to the right, `<C-w>|` widens it.

**To learn:**

- `]]` / `[[` — the same ftplugin maps them to next / previous section.
- `gO` elsewhere: help, man (`lua/man.lua:878` uses the same `qf_toc` trick),
  `checkhealth`. Do they share these quirks?
- Location-list behaviour that applies here: one list per window, `<CR>` jumps,
  `:lclose`. The list is a snapshot, filled once, so re-run `gO` after
  adding headings (not yet checked).

**Fix, prototyped and tested 2026-09-28** (not applied): a
`'quickfixtextfunc'` that, for outline lists only, displays just the heading
with real spaces. Hidden prefix gone, so wrapping, `breakindent` and `h` / `l`
all behave, and `<CR>` still jumps to the right line.

```lua
function _G.toc_qftf(info)
  local what = { id = info.id, items = 1, title = 1 }
  local list = info.quickfix == 1 and vim.fn.getqflist(what) or vim.fn.getloclist(info.winid, what)
  if not (list.title or ""):match("Table of contents") then return {} end -- {} = default format
  local out = {}
  for i = info.start_idx, info.end_idx do
    out[#out + 1] = (list.items[i].text:gsub("\194\160", " "))
  end
  return out
end
vim.o.quickfixtextfunc = "v:lua.toc_qftf"
```

Plus `linebreak` and `breakindentopt=shift:2` in that window. Open decisions:
where it lives (a `setup/outline.lua` with a `FileType qf` autocmd, or
`options.lua`); whether to match the same titles as `syntax/qf.lua`
(`TOC`, `Table of contents`) so man pages benefit; and `conceallevel=0` there,
since the conceal regex would still hide the start of a heading containing two
`|`, e.g. `## a | b | c`.

---

## 22. A mapping to close a fold *and everything inside it*

**Where:** new, in `lua/keymaps.lua`. `<leader>o` is the obvious home: no
convention exists to follow, and no built-in does it.

**Why:** Came up 2026-09-28. `zC` reads as "close everything below" but closes
the folds that *contain* the cursor line — the fold and its ancestors — and
leaves the folds nested inside it untouched (`src/nvim/fold.c:1221-1224`). So
on a `##` heading it collapses the whole file above you, and the subsections
come back exactly as open as they were. `zA` on an open fold does the same.
`zO` is *not* its mirror: it opens every fold nested in the outermost one
containing the cursor (`foldOpenNested`, `fold.c:1232`) — contrary to
`:h zO`, which says folds not containing the cursor line are unchanged.

Wanted: close this section and everything nested in it, leave its parents and
siblings as they are, so that reopening it goes one level at a time.

**By hand** (works for a fold whose parent is the outermost one):

```
zc V zC zo
```

`zc` closes the fold, `V` on a closed fold selects all its lines, visual `zC`
closes every fold in the selection — nested ones included, and the ancestors
too, as partly selected — and `zo` reopens the outermost ancestor.

**Two traps, both verified,** which is why this wants to be a mapping rather
than a habit:

- **Deeper than two levels, `zo` is not enough.** It opens only the topmost
  closed fold. On a `###` under `##` under `#`, the `##` stays closed and hides
  the section you were on.
- **`zc` on an already-closed fold closes its parent** (`fold.c:1246`: it
  closes the innermost *open* fold), so starting on a closed section selects
  the wrong one.

**Tested version** (headless, on a `#` > `##` > `###` file): only the `###`
closed, its sibling list and the next `##` untouched.

```lua
local l = vim.fn.line(".")
if vim.fn.foldclosed(l) == -1 then vim.cmd("normal! zc") end
local s = vim.fn.foldclosed(l) -- start of the fold we mean
vim.cmd("normal! VzC")
-- reopen the ancestors that VzC closed, one at a time, down to ours
while vim.fn.foldclosed(l) ~= s do
  vim.fn.cursor(vim.fn.foldclosed(l), 1)
  vim.cmd("normal! zo")
end
vim.fn.cursor(l, 1)
```

**Do:** Pick the key, then check the cases the test did not cover: a fold
with no parent (the loop should not run), a line in no fold at all (`zc`
errors with E490), and nested folds closing at depth three — the `###` in the
test file had none.

---

## 23. The venv hook never reaches the server

**Where:** `lua/setup/lsp.lua:36-46` (`before_init`), and the comment at
`:17-19`

**Why:** `before_init` assigns a *new* table to `config.settings`, but the
client took its `settings` from `config.settings` when it was created
(`client.lua:409` in 0.12.5), before `before_init` runs (`:571`). What the
server gets — the `workspace/configuration` answer (`handlers.lua:235`) and
the `didChangeConfiguration` after `initialize` (`client.lua:602`) — is
`client.settings`, which never sees the `pythonPath`. Nvim's own docstring
example (`client.lua:36-40`) uses the same pattern, so possibly an upstream
bug.

**Verified** (2026-09-30, headless, in a project with a `.venv`):
`client.settings.python` is `nil`, while `client.config.settings.python` has
the `.venv` path.

It looks like it works because basedpyright finds `<root>/.venv/bin/python`
itself when no path is set (its `pyright-langserver.js`, "`defaultVenvPath =
'.venv'`"). So the comment at `:17` is wrong for basedpyright, and the hook is
dead in every case it exists for: `$VIRTUAL_ENV`, `$CONDA_PREFIX`, a `venv/`
without the dot, and plain pyright.

**Not understood:** after creating a `.venv`, `:lsp restart` did not pick it
up and a full nvim restart did, although basedpyright's own detection should
run on either.

**Do:** Mutate `config.settings` in place rather than replace it, then
re-check the headless test above with `VIRTUAL_ENV` set to a venv that is not
the project's `.venv`. Fix the comment. Consider reporting the docstring
upstream.

---

## 24. Pickers are full-size however few items they list

**Where:** `lua/setup/fzf.lua:41` (`fzf.register_ui_select()`)

**Why:** Every `vim.ui.select` opens at the picker's 85% × 85%, so `,pt`'s six
modes sit in a window meant for a file search. `register_ui_select` also takes
a function of `(ui_opts, items)` returning opts
(`providers/ui_select.lua:103-113`), and in fzf-lua a size above 1 is lines
rather than a fraction (`win.lua:568`).

**Decided (2026-09-30):** size every `vim.ui.select` to its items, rather than
only `,pt` through a `kind` of its own, and leave code actions alone: they
show a diff preview.

```lua
fzf.register_ui_select(function(ui_opts, items)
  if ui_opts.kind == "codeaction" then return {} end
  return { winopts = { height = math.min(#items + 4, 0.85 * vim.o.lines), width = 0.4 } }
end)
```

The `+ 4` (border, prompt, info line) is a guess.

**Related, left as is:** fzf-lua only takes over `vim.ui.select` once a
picker has loaded it, so `,pt` before any picker shows nvim's own numbered
list at the bottom. Fixing that means registering at startup, against the
point of deferring the setup.

**Do:** Apply it, then check the `+ 4` by capturing the window in a scratch
tmux pane, with and without the `default-title` border title.
