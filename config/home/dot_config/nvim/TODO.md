# nvim config — changes to make later

Items 1-7 were found 2026-09-16 while investigating the `<leader>gb` blame
popup; 8-12 on 2026-09-18 while adding line history. Paths are relative to this
directory.

---

## 1. Remove the lazygit binding

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

**Do:** Delete the line. Nothing else references it —
`plugins.lua` has no entry, and `config/health.lua` lists `lazygit` as an
optional tool that would simply stop being reported. Also drop it from the
tools table in `lua/config/health.lua` and from the `<leader>g` section of
`cheatsheet.md`.

---

## 2. Completion autotrigger contradicts `'autocomplete'`

**Where:** `lua/options.lua:76` vs `lua/setup/lsp.lua:200`

```lua
-- options.lua:76
vim.o.autocomplete = false

-- setup/lsp.lua:200
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

---

## 3. `<C-s>` vs `<C-S>` in the cheatsheet

**Where:** `cheatsheet.md:51` says `<C-s>`; `lua/setup/keymaps.lua:80-81`
relabels `<C-S>`.

**Why:** Cosmetic only — identical to Vim, since Ctrl strips case. Worth
aligning so the cheatsheet matches the code it documents.

**Do:** Pick one spelling. `<C-s>` in the cheatsheet reads better; `<C-S>`
matches how core defines it. Low priority.

---

## 4. `<leader>gr` vs `grr` — naming collision

**Where:** `lua/keymaps.lua:194` (`<leader>gr` reset hunk) vs core `grr`
(references).

**Why:** Not a real conflict — different prefixes, no shadowing, and
`:KeymapAudit` will not flag it. But "gr" means *reset hunk* under `<leader>`
and *references* under `g`, which cuts against the config's own one-sentence
rule ("`gr` acts on symbols").

**Do:** Probably nothing. Noted so it is a decision rather than an oversight.
If it ever grates, `<leader>gx` or `<leader>gu` (undo hunk) are free.

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

## 6. Add `<leader>gB` — full-file blame

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

**Do:** Add the `gB` line. Add it to `cheatsheet.md` under `## Git` too.

---

## 7. Open question — seeing a commit from the editor

The thing that started all this: `<leader>gb` shows "Hunk 1 of 4", meaning the
commit that last touched this line changed 4 hunks in this file. There is no
way to see the other 3 from the popup — gitsigns binds only `q` there
(`popup.lua:244`), and the hunks belong to a historical diff that is not on
screen.

`:Gitsigns show <sha>` opens that commit's version of the file, using the SHA
from the blame popup. That is the closest built-in answer, and may be enough —
worth living with before building anything.

If it is not enough, the want is "show me the commit under my cursor,
diff and all", which is a genuine integration to design rather than a keybinding
to fix. Candidates: a `<leader>o*` binding wrapping `:Gitsigns show`, or
diffview.nvim (a real dependency, against the config's few-plugins rule).

---

## 8. `signs_staged` is unconfigured, so staged hunks show the default bars

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

**Do:** Decide and set `signs_staged`. Two defensible answers:

1. **Same characters as unstaged.** `+ ~ -` is what `git add -p` shows either
   way, and gitsigns already uses distinct highlight groups
   (`GitSignsStagedAdd` etc.), so colour carries staged-ness. Most consistent
   with the existing comment.
2. **Keep bars for staged**, as a deliberate "already banked" signal — but then
   say so in the comment, since it contradicts the sentence above it.

Either way the current state is an oversight, not a choice.

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

## 10. Statusline cannot distinguish a historical revision from the real file

**Where:** `lua/setup/statusline.lua`, `M.path()` / `refresh_path()`.

**Why:** Fallout from item 9. `refresh_path()` stores
`fnamemodify(name, ":.")`, so a buffer named
`gitsigns://<gitdir>//<sha>:<relpath>` renders as an ordinary-looking path.
Nothing indicates the buffer is read-only, historical, or which commit it is —
so "am I looking at my working tree or at 2023?" is unanswerable at a glance.
The same applies to any `fugitive://`-style scheme if one is ever added.

**Do:** Detect the scheme in `refresh_path()` and render the revision, e.g.
`balance.rb @6fc33a0e`, reusing `StatuslineMuted` or `StatuslineAccent`. Small
and self-contained; the path is already cached per buffer, so it costs nothing
per redraw.

---

## 11. Git history bindings — the four operations

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
| function history | `<leader>gt` | **not done** |
| file history | `<leader>gf` | **not done** |

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

Undecided whether `gl`/`gf` should be fzf-lua, the custom code, or fzf-lua with
the custom code as the `needs`/`fallback` (which is what the keymap spec's
fallback mechanism is for). `gt` needs custom code either way — no installed
plugin does the funcname form.

**Also relevant to item 7:** `-L` is *cursor-scoped* where gitsigns is
*hunk-scoped*, which is why their diffs differ for the same commit. On a `def`
line, `-L <line>,<line>` shows the signature changing but hides the body lines
that changed with it; `-L :funcname:` (item's `<leader>gt`) shows the whole
method each time, and is the better tool there.

**Do:** Settle the output shape, then add `gt` and `gf`, and update
`cheatsheet.md` `## Git` and `docs/keymaps.md` §5. (The convention research is
already in `docs/research-keybindings.md`.)

---

## 12. Bind bare `:FzfLua` — the picker of pickers

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

`builtin` is the picker-of-pickers (`:FzfLua builtin`); bare `:FzfLua` is the
same thing. Letter is open — `fF` pairs with `ff`, but `f?` reads better as
"what else is there". Add to `cheatsheet.md` under `## Pickers` too.

**Note:** `resume` is arguably the more valuable daily binding of the two —
reopening the last picker with its query intact, after you jumped somewhere and
want the rest of the results.
