# TODO

Open items, by module. Numbers are per section and never reused, so commit
messages can cite them ("nvim TODO 29"). Closed items are removed; their notes
are in git history: until 2026-11-16 in each module's own `TODO.md`.

## nvim

Paths are relative to `config/modules/common/nvim/.config/nvim/`. Of items
1-33, all but these four are closed: the next is 34.

### 14. UPSTREAM BUG — reblame crashes across a rename

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

#### Report, ready to paste

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

### 16. UPSTREAM BUG — blame panel throws once its file buffer is wiped

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

---

### 29. UPSTREAM BUG — a checkout's refresh puts an older base back

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

**Worked around** in `setup/review.lua` (The base): a buffer left on a base
review asked for earlier has the base applied again, up to three times per
base asked for, in review and after leaving it. Looked for when a pass ends,
on `GitSignsUpdate`, and two seconds later, since the event only comes when a
buffer's counts change. Public API only, so it stays. Remove the re-applying
when upstream fixes this; the one-pass-at-a-time part answers a second race,
between two `change_base` calls, and stays either way (2026-11-11).

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

#### Report, ready to paste

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

### 30. Review mode: walk the commits in a worktree instead of moving HEAD

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

## tmux

Nothing open. Items 1-6 are closed: the next is 7.

## claude

### 1. AGENTS.md: generic sections on how to deal with git, docker, etc.

**Where:** `config/modules/common/agents/AGENTS.md`, linked as
`~/.claude/CLAUDE.md` and opencode's `AGENTS.md`.

**Do:** Check it has a generic section for each tool an agent commonly has to
deal with: git, docker, and so on. Today only git has one ("Working with git",
under Access and Boundaries).
