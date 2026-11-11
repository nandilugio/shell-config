# nvim config — changes to make later

Items 1-7 were found 2026-09-16 while investigating the `<leader>gb` blame
popup; 8-16 on 2026-09-18/19 while working on the git setup; 17-22 on
2026-09-28 in a read-through of the nvim and tmux configs; 23-24 on 2026-09-30
while setting up a Python project; 25 the same day, while reworking folds; 26
the same day, as a feature request; 27-29 on 2026-11-05, while trying out and
then testing review mode (26); 30 on 2026-11-06, from a review of the whole
config. Paths are relative to this directory.

Done items are cut to their outcome, with the commit where known; the full
notes are in this file's history before 2026-11-06.

---

## 1. ~~Remove the lazygit binding~~ DONE 2026-09-19

The binding, its health row, install line and docs went. The deferred question, "show me this commit", was answered by `<leader>gB`'s `D` (item 6).

---

## 2. ~~Completion autotrigger contradicts `'autocomplete'`~~ DONE 2026-11-04 (f84d88f)

`autotrigger = false` in `setup/lsp.lua`, honouring `options.lua`. Keeping the trigger-character popups and rewriting the docs was parked.

---

## 3. ~~`<C-s>` vs `<C-S>` in the cheatsheet~~ DONE 2026-09-21

Standardised on lowercase `<C-s>`; `maparg()` resolves both spellings to the same core mapping.

---

## 4. ~~`<leader>gr` vs `grr` — naming collision~~ NOT AN ISSUE 2026-09-21

No collision: `<leader>` is pressed deliberately and disambiguates `<leader>gr` from `grr`.

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

`<leader>gB`, plus `gS`/`gR`, `gq` and the `<leader>ug*` toggles in the same pass. `undo_stage_hunk` left unbound: `stage_hunk()` on a staged hunk unstages, once item 8 made staged signs visible.

---

## 7. ~~Open question — seeing a commit from the editor~~ SETTLED 2026-09-21

Settled by `<leader>gB`: `D` in the blame panel opens the commit under the cursor, all hunks, in a tab.

---

## 8. ~~`signs_staged` is unconfigured, so staged hunks show the default bars~~ DONE 2026-09-19

`signs_staged` mirrors `signs`; the colour carries staged-ness, at half brightness on the `default` scheme.

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

`gitsigns://` buffers render as `path[sha]`, the shape fzf-lua gives the same thing. The buffer name is the only reliable source: `b:gitsigns_head` keeps the real buffer's branch.

---

## 11. ~~Git history bindings — the four operations~~ DONE 2026-09-19

`<leader>gl` line, `gt` function (trace), `gf` file history (fzf-lua's picker, ours as fallback). git's funcname patterns are inert until `.gitattributes` enables them, and `gt` says so.

---

## 12. ~~Bind bare `:FzfLua` — the picker of pickers~~ DONE 2026-09-19

`<leader>f?` opens fzf-lua's picker of pickers.

---

## 13. ~~Bind `FzfLua.resume` — reopen the last picker~~ DONE 2026-09-19

`<leader>f.` resumes the last picker with its query.

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

The five segment groups are foreground-only, so they inherit `StatusLineNC` in inactive windows.

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

## 17. ~~`M-a` in the pickers is the tmux prefix~~ DONE 2026-11-04 (7353c47)

The cheatsheet says `M-a M-a`, next to the `M-h` note.

---

## 18. ~~Cheatsheet still describes the old revision marker~~ DONE 2026-11-04 (7353c47)

The cheatsheet says `path[sha]`.

---

## 19. ~~`keymaps.lua` header lists `]n` / `[n` as normal-mode defaults~~ DONE 2026-11-04 (7353c47)

Comment fixed: `an in (x/o)  ]n [n (x)`.

---

## 20. ~~Teach `zm` / `zr` as **m**ask / **r**eveal~~ DONE 2026-09-30

Folds section in the cheatsheet with the mask/reveal mnemonic and the `'foldlevel'` gotcha; the `z` keys became real mappings, so their `desc` is the label.

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

## 22. ~~A mapping to close a fold *and everything inside it*~~ DONE 2026-11-06

`zS`, beside the native keys rather than under `<leader>o`, so that `zc`
`zo` `zC` `zO` stay what they are in any Vim. The three untested cases from
the draft pass: no parent, no fold, nested folds at depth three. If it turns
out to be always followed by `zo`, reconsider an outline key instead: open
the fold one level, insides reset.

---

## 23. ~~The venv hook never reaches the server~~ DONE 2026-11-04 (87d435b)

`config.settings.python` is assigned into the table the client already holds. Verified headless with `VIRTUAL_ENV` outside the project.

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

**Related, done 2026-11-06:** fzf-lua only took over `vim.ui.select` once a
picker had loaded it, so `,pt` before any picker showed nvim's own numbered
list. `setup/fzf.lua` now stands in for `vim.ui.select` until the first call,
which loads the plugin and hands over: the same lazy trick as the pickers.

**Do:** Apply it, then check the `+ 4` by capturing the window in a scratch
tmux pane, with and without the `default-title` border title.

---

## 25. ~~Visual-mode maps: Select mode, and selections they ignore~~ DONE 2026-11-04 (f18726e)

All five are `"x"`; `gs`/`gr`/`=` have selection entries, the hunk ones passing the range. Not decided: leaving Visual mode afterwards.

---

## 26. ~~A "review mode": one toggle that sets the editor up for code review~~ DONE 2026-11-05 (ae5f1a4)

`setup/review.lua` on `<leader>uR` and `:Review`, `:help review-mode`, reasoning in `docs/decisions.md`. Changed from the plan: local git only, nearest merge-base among develop/master/main and the remotes' defaults; branch and commit review (`bR`/`cR`); `]v`/`[v` walk the commits; presets instead of save-and-restore; staging refuses off the index.

---

## 27. Review mode's hunk display is noisy

**Where:** `lua/setup/review.lua`, `PRESETS.review.hunk_details`.

**Why:** Found 2026-11-05 trying review mode. Entering it switches on three of
gitsigns' displays at once: deleted lines (as virtual lines), word diff and
the cursor line's blame. Together they are a lot on screen, especially on a
branch with many hunks.

**Do:** Try review with each on its own and decide which earn a place in the
preset. Each already has its own toggle (`<leader>ugd`, `ugw`, `ugb`), so
whatever the preset leaves off is one key away. `hunk_details` is a single
flag today; splitting it is a three-line change in `apply()`.

**Partly done 2026-11-06:** most of the noise was styling, not the number of
displays. Deleted lines used `DiffDelete` (bright foreground, bold) and word
diff used reverse video, both overriding the syntax colours gitsigns already
captures for the old text. Now backgrounds only, derived from the scheme in
`setup/git.lua`: deleted lines on dark red, removed words on a stronger red,
added words on green, syntax colours showing through. Still open: whether
the cursor line's blame belongs in the preset.

**Changed 2026-11-10:** deleted lines and word diff are no longer separate:
with the new line backgrounds they make one display, the inline diff
(`setup/git.lua`, `<leader>ugd`; `ugw` is gone), since apart they only made
half a diff. So the question above is now inline diff and blame, each with its
own toggle.

---

## 28. Undo emptied a buffer, during review mode (unexplained)

**Where:** unknown.

**Why:** 2026-11-05, while in review mode against `origin/master`, editing
`lua/setup/statusline.lua` and pressing `u` repeatedly to clean up left the
buffer **empty**: with deleted lines shown, every line of the file displayed
as removed. Leaving review mode showed an empty buffer with a deletion sign.
The file on disk was untouched (writes are refused in review). That session
was closed before `:messages` could be read.

Not reproduced: opening the file, entering review, editing and undoing in a
clean session stops at the original text, as it should. Undo can only reach an
empty state if the buffer's history holds one, which happens when Neovim
reloads a file mid-session (`'undoreload'` keeps the reload undoable) or when
something fills a buffer that was created empty.

**Do:** If it happens again, read `:messages` before quitting (a W11 "file has
changed" or similar), note how the file was opened (`<leader>gD`, quickfix,
mini.files, `:e`), and whether `<leader>gd` or `<leader>gR` were used on it.
`:undolist` would also show whether a reload sits in the history.

---

## 29. UPSTREAM BUG — a checkout's refresh puts an older base back

**Where:** gitsigns, not this config. `lua/gitsigns/git.lua`, the local
`refresh(self, revision)` that `Obj:refresh()` calls with `self.revision`, and
the gitdir watcher in `lua/gitsigns/attach.lua` that calls it.

**Symptom:** found 2026-11-05 by `lua/setup/review_test.lua`. Walking commits
in review mode (`]v`, a checkout then `change_base`), two steps in quick
succession leave a buffer on the *previous* step's base: wrong hunks, and
the statusline falls back to `sha..branch` because the base no longer matches
the review's. Deterministic in the suite with eight buffers attached; never
seen with one buffer and slow steps. Slow git (a big repository) widens the
window.

**Cause:** a checkout changes `.git/HEAD`; the watcher's handler runs
`git_obj:refresh()` for each attached buffer. That reads `self.revision` when
it starts, awaits git, and assigns it back when done (`git.lua:58`). Nothing
locks it against `change_base`, whose `change_revision` writes the same field.
A refresh in flight across a base change restores the old value. Logged in the
failing run, for one buffer (`d4`, `p1`, `p2` are the fixture's commits):

```
change_revision  index -> d4          enter review
change_revision  d4 -> p1             step: base p1   now=p1
refresh          started at d4 ...    now=d4          the watcher, late
change_revision  d4 -> p2             step: base p2   now=p2
refresh          started at d4 ...    now=d4          and again
```

**Worked around** in `setup/review.lua` (`keep_base`): the refresh ends by
raising `GitSignsUpdate` for the buffer, so on that event a buffer whose base
is not the review's gets `change_base` again, once per buffer and base.
Public API only, so it stays. Remove it when upstream fixes this.

**Do:** file at lewis6991/gitsigns.nvim. Fix candidates upstream: re-read
`self.revision` after the awaits in `refresh`, or take `Obj:lock` in both the
watcher handler and `change_revision`.

**Related, seen once in four suite runs (2026-11-06):** with deleted lines
shown, a base change can race the preview's scheduled flush:
`hunk_preview.lua:130: assertion failed!` from `prepare_removed_source`,
which asserts `bcache.compare_text`, nil while `change_base` has invalidated
the buffer and not yet refilled it. A scheduled-callback error only: nothing
is left wrong. Same family -- gitsigns' async paths do not lock against each
other. Worth a line in the report.

### Report, ready to paste

> **Title:** gitdir watcher's refresh can revert a `change_base` made while it
> was running
>
> `Obj:refresh()` passes `self.revision` into the local `refresh(self,
> revision)`, which awaits git and then assigns `self.revision = revision`
> (`git.lua:58`). The gitdir watcher calls it for every attached buffer after
> a checkout. If `change_base` runs while such a refresh is in flight, the
> refresh completes afterwards and writes the earlier revision back, so the
> buffer silently returns to the previous base.
>
> **Repro** (gitsigns 4bcd991, Neovim 0.12.6): with several buffers attached,
> `git checkout --detach <commit>` then `require("gitsigns").change_base(<sha>,
> true)`, twice within ~200ms with different shas. Some buffers end on the
> first sha. Wrapping `Obj.change_revision` and `Obj.refresh` to log their
> writes shows the refresh's late assignment.
>
> **Expected:** the base set last wins. Re-reading `self.revision` after the
> awaits in `refresh`, or holding `Obj:lock` in both the watcher handler and
> `change_revision`, would do it.

---

## 30. Review mode: walk the commits in a worktree instead of moving HEAD

**Where:** `lua/setup/review.lua`, the Walk section and everything that
exists because of it.

**Why:** Checking out is the one thing review mode does to the repository,
and most of the module's weight is the consequence: four guards (unsaved
edits, a dirty tree, an operation in progress, a HEAD moved by hand), the
record in `stdpath("state")` with its pid check, the `VimLeavePre` prompt, and
the offers to run `git stash` or `git switch`. A `git worktree add --detach
<commit>` under `stdpath("cache")`, with `:cd` into it for the walk, would
leave HEAD and the working tree alone: nothing to guard, nothing to record,
and leaving would remove the worktree. The language server and the pickers
would see the commit's tree through the cwd, as they do now.

**The cost, found 2026-11-06:** untracked dependencies are not in a worktree.
Reading loses nothing. Running the commit does: `.venv` is absent, so
`setup/lsp.lua`'s detection falls back to `VIRTUAL_ENV` (export it in the
pane) and `uv run` would build a venv there; `node_modules` is absent. Ruby
loses nothing: gems live per rbenv Ruby, and the 2.7 path uses the standalone
bundle anyway. When that matters: verifying a commit's claim by running the
test it adds, bisecting which commit broke a test, running a script at that
commit. The current design chose a real checkout for exactly those; how often
they happen mid-walk is the question.

**Do:** Decide whether tests-on-a-commit is a walk-time need or a "cd to the
worktree in a pane" need. If the latter, prototype: `worktree add`, `:cd`,
`gitsigns` base as today, `worktree remove` on leaving, and measure what the
guards section shrinks to.
