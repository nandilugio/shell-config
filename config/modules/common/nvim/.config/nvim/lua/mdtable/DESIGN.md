# mdtable — design notes

Why the plugin is built the way it is, and what was measured to decide. The
README is the user-facing half: what it does, how to install and configure it.
These are the working notes behind it — terse, dated, and appended to as things
change. Moved here 2026-09-16 from the config's docs/decisions.md, where the
rebuild log had been carrying them.

## Chosen over render-markdown (2026-09-15)

Settles the "re-add later if concealment is missed" note left against render-markdown
in the config's docs/decisions.md.
What was actually missed was NOT concealment: it was that a markdown table nobody
padded is unreadable, and conceal cannot fix that — it only removes characters,
and alignment needs characters ADDED.
Measured the candidates rather than trusting reputation:
  | plugin             | size | LOC    | commits/yr |
  | render-markdown    | 1.4M | 10,790 | 99         |
  | mini.align         | 280K |  2,049 | 16         |
  | vim-easy-align     | 408K |  1,313 | 0          |
  | lua/mdtable (ours) |  12K |    ~400| —          |
mini.align and vim-easy-align are EDITING operators: they rewrite the buffer, so they
cannot help with a file you are only reading, which is the whole case. Ruled out.
render-markdown does do display-only alignment, but it is 5x the size and 6x the churn
for one feature out of many, and its icons want a Nerd Font (see the symbols section
in docs/decisions.md).
A markdown table is regular enough to align in ~400 lines of dependency-free Lua, which
is the same call already made for venv detection (~20 lines) over venv-selector.nvim.
Two halves, because reading and writing are different problems:
  render  (default on for markdown, <leader>um toggles) inline virt_text, file untouched
  align   (<LocalLeader>t) rewrites the table under the cursor, one undo step
Both measure with strdisplaywidth, so CJK and emoji align; both honour :--- ---: :---:.
NOT enabled for vimwiki: notes are written, not just read, and inline padding shifts the
real columns (which is also why render clears itself in insert mode). That exclusion is
NOT in the plugin — it is passed from init.lua as setup({ filetypes = {...} }), so the
plugin carries no opinion about one config's notes setup.
Kept in-config rather than a standalone repo: same code either way, and extraction is a
git mv plus a vim.pack line if it ever earns one.

DETECTION: line scan, NOT treesitter. Considered treesitter-if-available with a scan
fallback, and rejected it: the only false positive treesitter actually prevents is a table
inside a fenced code block, which the scan handles by tracking ``` / ~~~ in a few lines.
Everything else a parser would reject, the scan rejects too — and it works on the bare box
with no compiler, which treesitter cannot. The dual path would have meant two
implementations that must agree, to fix one case the single one already covers.
What makes the scan trustworthy is validation rather than detection: a candidate is a table
only if the separator has a header above it, the run is longer than the separator alone, and
the separator's column count matches the header's (which is what CommonMark requires).

TESTS: lua/mdtable/test.lua, run with `nvim -l lua/mdtable/test.lua`. No framework —
`nvim -l` runs a script directly, and exit code is 0/1 for CI. 80 checks. Detection goes
through scan()/cells(); everything else through the public functions on scratch buffers,
with rendering read back off the actual screen (screenstring), since that is the only
place buffer text and virtual text combine — and the assertion is "the pipes land on the
same columns", not "the lines are the same width", because the latter lets one cell over-
padded and another under-padded cancel out.
Every bug found so far is in there as a named regression. In order of discovery: separator
two dashes short per column; fill after a trailing colon; left ":--" normalised away;
leading whitespace counted twice; over-padded cells (padding cannot shrink); tabs measured
from column 0; separator wider than content; "\\|" treated as an escaped pipe; and from the
2026-09-15 review pass: trailing whitespace in right/centre cells overshooting, indent
ignored when measuring tabs, separator fill after a colon when spaces surround it, align()
dropping a table's indent (breaks tables in list items), and the debounce leaking one libuv
timer per edit (vim.defer_fn only closes on fire) while a single global timer left a
buffer stale if you switched away inside 150ms.

REVIEW 2026-09-15 (full pass: consistency, minimalism, performance). Structural changes:
one tokenizer — cells() returns byte positions, so render_row() no longer walks the line
itself and the escape logic exists once (the "\\|" fix had to be applied twice before);
scan() splits each line once and hands the cells to render and align; scan() split into
run detection and table_at() validation, no goto; separator must be row 2 (GFM), which is
both stricter and simpler than "anywhere in the run"; separator fill uses
@punctuation.special.markdown, the group treesitter gives the real dashes, so the rule is
one colour with treesitter and plain without; setup() enables already-open buffers (lazy
loading on ft= would otherwise miss the buffer that triggered the load); enable/disable/
toggle all take an optional buf. 538 -> 402 lines with more behaviour.

SPEC GAPS, settled 2026-09-15 by the rule "support it iff it is strict GFM":
  blockquoted tables (> | a | b |)  YES — blockquotes are container blocks; GitHub renders
                                    them. One PREFIX pattern "^[%s>]*" replaces "^%s*" in
                                    is_row/is_separator/fence_at/start_column; align() keeps
                                    the first row's prefix.
  pipeless tables (a | b / --|--)   NO — valid GFM, but the row test would become "any line
                                    with a pipe", which is the false-positive door. Documented:
                                    add the pipes.
  conceal                           LIMIT — strdisplaywidth() cannot see concealed text, so a
                                    cell with hidden ** or link targets renders short under
                                    conceallevel>0. No cheap fix (screenpos() per visible line
                                    per redraw). Not an issue here: conceallevel is 0.

PERFORMANCE, measured 2026-09-15. Cost scales with table cells, not lines: 10k lines of
prose + one table renders in 1.3ms; a 2000-row x 3 table in ~10ms (was 12.4: the two
widths are now measured once in scan and kept on the cell, and cells() jumps between
delimiters with find() instead of stepping bytes). Extmarks are the floor (~1 per cell,
no batch API). The bigger win was not doing the work: render records b:mdtable_tick
(changedtick) and returns early when it is unchanged, so BufEnter (added for API edits
to background buffers, which TextChanged does not report) and InsertLeave without
typing cost 0.01ms instead of a full render. Normal-mode edits still coalesce on one
shared 150ms timer. Not done, on purpose: incremental re-render of only the changed
table, and rendering only visible lines — both add state for a cost that is already
below a frame.

SECOND REVIEW 2026-09-15 (correctness first). Found and fixed:
  * A REGRESSION FROM THE PERF PASS: caching a cell's occupied width in scan measured it
    at the UNPADDED column; a tab in a cell after a padded one shifts and changes width.
    Fix is not "measure again in render" but measuring correctly once: columns left to
    right, each cell at the column it will land on once the columns before it are padded.
    Exact, because no cell ends up wider than its column — which also means render_row
    no longer needs the "cell wider than column" branch. Same speed.
  * Deferred renders measured with the CURRENT buffer's 'tabstop' (and window's 'list'),
    not the dirty buffer's. render() now runs inside nvim_buf_call(buf).
  * The separator test was per line ("at least one dash somewhere"); GFM is per cell.
    is_separator(line) replaced by is_delimiter(cell) applied to every cell of row 2 —
    stricter and a plainer definition. |:|---| is no longer a table.
  * Two wiring tests were checking the wrong thing: they rebuilt a fresh buffer from the
    edited text and checked that, so BufEnter catch-up and the debounce could have done
    nothing and still passed. Now they read the actual buffer off the screen, and the
    helper only switches buffers when it must, so BufEnter cannot rescue a timer test.
Config side reviewed (init.lua setup call, keymaps.lua entries, cheatsheet, docs):
nothing to change. setup({ filetypes = { "markdown" } }) restates the default on purpose —
it is the one place in the config where the vimwiki exclusion is visible, and it pins the
behaviour if the plugin is extracted and its default ever moves. 90 checks.

## WIRING REBUILT 2026-09-16: decoration provider, not stored marks
Two independent /code-review passes (different sessions, different models) each returned 8
confirmed correctness bugs, 6 in common, 9 distinct. Six of the nine were the SAME bug:
marks were stored, so every event that could stale them had to be enumerated — <C-c> fires
no InsertLeave; a normal-mode edit then `i` within 150ms repainted while typing; :e revived
a toggled-off buffer; a filetype leaving the list never disabled; 'tabstop'/'list' changes
went unnoticed (real trigger: .editorconfig sets tab_width AFTER the ftplugin sets
tabstop, so the first render is wrong); a split edited via API got neither TextChanged nor
BufEnter. That enumeration is unbounded, which is the argument: the last two were found by
the reviewers, not by use.
Now nvim_set_decoration_provider places EPHEMERAL marks per frame, for visible lines only.
Nothing is stored, so nothing can stale. Deleted: the debounce timer, the dirty set,
BufEnter, InsertEnter, InsertLeave, the changedtick gate, nvim_buf_call, the would-be
OptionSet handler, render() and clear(). Insert mode became one mode() check in the draw
gate, which is why every exit works. Option changes are picked up on the next frame free.
PERFORMANCE: 0.099ms per frame on a 2000-row table (50 visible), vs ~10ms per full render
before — and the scan is cached on (changedtick, tabstop, vartabstop, list+listchars), so
the cache key names everything it reads. 60 frames of scrolling = 3.9ms.
Also fixed, same pass:
  * CommonMark 4.5 both ways: a closing fence carries only its marker (```lua opens but
    never closes — getting this wrong INVERTS the fence state and kills every table below),
    and a backtick fence's info string may not contain a backtick (``` `` is not a fence).
  * align() wrote row 1's prefix onto every row, changing >> to > — content, not padding.
    Each row keeps its own now.
  * align() warned about `modifiable` before looking for a table, so the global
    <LocalLeader>t nagged in :help and in the cheatsheet float. Checked after.
  * Tabs in right/centre cells: padding BEFORE the text moves the tab and changes its
    width, so `after` is measured with `before` already applied rather than from the
    cached occupied width.
  * b:mdtable_on vs b:mdtable_ft: while they agree the filetype decides, once they differ
    the user has, and re-detection leaves it alone. Replaces one-way enablement.
TEST HARNESS LIMIT, stated in the README: `nvim -l` attaches no UI, so screenstring()
sees bare text; and with no main loop, neither feedkeys() nor nvim_input() can enter
insert mode. Both are checked one layer down — the padding as actual extmarks, and the
draw gate with mode() stubbed. A pty would fix both; the sandbox here denies openpty.

## REVERTED 2026-09-16: the decoration provider cannot do this
The rebuild above shipped and drew NOTHING. An ephemeral mark cannot carry inline virtual
text: nvim_buf_set_extmark sets MT_FLAG_DECOR_VIRT_TEXT_INLINE only on the stored path
(src/nvim/api/extmark.c), and that flag is what makes the renderer reserve the columns.
The ephemeral branch calls decor_range_add_virt and never sets it, so the mark is
accepted, placed, and silently not drawn — 408 marks, blank screen. Providers suit
overlays, eol text and highlights (which is what render-markdown and indent-blankline use
them for); inserting columns is not available to them. Both reviewers proposed the
provider and I endorsed it; none of us checked that it could do the one thing this does.
Back to stored marks, keeping every correctness fix. The event list is now explicit about
why each entry exists: TextChanged/InsertLeave (text), BufWinEnter/WinEnter/WinScrolled
(edited while not current), OptionSet ('tabstop'), ModeChanged i*:* (<C-c> fires no
InsertLeave). The debounce timer is gone: the tick check makes a no-op render ~3us, so
there is nothing to debounce.
LESSON, worth keeping: "marks placed" was treated as "marks drawn" for three rounds. The
user's screenshots were the only real evidence and were right every time. Tests now read
back actual extmarks rather than recomputing what padding should be, so this failure mode
would now be a red suite rather than a green one.

## WIDTH IS NOT strdisplaywidth() — found 2026-09-16 from a user report
A table rendered ragged: rows 186/186/184/185 where all four should be 184. Cause:
strdisplaywidth() is WINDOW-RELATIVE. Past 'columns' it counts the extra rows a wrapped
line would occupy — the same 157-column cell measures 159 at columns=80, 158 at 120, 157
at 200+. So in any window narrower than the widest cell, that column was sized too wide,
the short row got too much padding and the widest row got none.
Now: nvim_strwidth() (no window notion) plus tabs expanded by hand against 'tabstop',
verified to match strdisplaywidth exactly on every tab-boundary case. Also faster: full
render of a 2000-row table 10ms -> 7.6ms.
This was the SECOND bug from the same function — the first was its tab-position argument.
strdisplaywidth answers "how many cells would this take in this window", which is not
"how wide is this text". Every synthetic test had passed because the harness sets
columns=400, so nothing ever wrapped; there is now a narrow-window regression test.

## REVIEW 2026-09-16 (correctness, consistency, portability, performance)
  * width() read vim.bo.tabstop, i.e. the CURRENT buffer's, so a render or an align of a
    buffer with a different 'tabstop' measured with the wrong one. 'tabstop' is now
    threaded: scan(lines, ts) -> table_at(..., ts) -> width(s, at, ts), and kept on the
    table for padding(). nvim_buf_call() in render() existed only to paper over this and
    is gone.
  * state_of() keyed the cache on 'list'/'listchars'; with nvim_strwidth those no longer
    affect widths. Key is now (changedtick, tabstop) — everything it actually reads.
  * content_width() went through width() only to pass no tabs; it calls nvim_strwidth.
  * 'vartabstop' is NOT honoured (tabs measure against 'tabstop'). Documented, not faked.
PORTABILITY: pure Lua and core API only — no filesystem, shell, paths or platform calls,
so Linux/macOS/Windows are the same. Needs 0.10 for inline virtual text; everything else
used is older. 112 checks, startup +0.18ms.

## THE TWO HALVES AGREE ON COLUMNS, NOT ON TEXT POSITION (settled 2026-09-16)
User noticed ,t moving text that already looked aligned: a cell written "|   3 |" shows
with its three spaces kept and gets the rest of its padding after them, while ,t rewrites
it to "| 3 " + padding. Pipes identical either way; the text sits differently.
This is not a bug and cannot be made symmetric without a third mechanism. render may only
ADD columns — it must not touch the file — so whatever whitespace the author wrote stays.
align REWRITES, so it can put the text where the alignment says.
Three ways to close the gap were considered:
  1. leave align canonical, correct the claim   <- CHOSEN
  2. make align additive too (keep the author's whitespace): true symmetry, but ,t stops
     normalising, a file never converges, and two identical-looking tables differ in bytes
  3. have render conceal the whitespace and repad: symmetric AND canonical, but needs
     conceallevel >= 1, which is 0 in this config and would degrade invisibly elsewhere
Rejected 3 for the setting dependency (1 and 2 work regardless), 2 because align earning
its keep as a formatter is worth more than byte-identity with the display.
WHAT WAS ACTUALLY WRONG was the documentation: "what render draws is what align writes"
overstates it. The guarantee is "the pipes land in the same columns"; align additionally
normalises what sits inside them. README and both function headers now say so — padding()
is the half that may only add, build_row() the half that rewrites.
NOTE: an already-canonical table round-trips byte-for-byte through ,t (torture test #3),
so this only shows up where the author left stray whitespace.

## SEPARATOR STYLE: "| --- |", not "|---|" (settled 2026-09-16, MEASURED)
User asked whether the delimiter row should be contiguous — |----|----| reads as a rule,
and it is what the DISPLAY draws (render can only add dashes, and most sources have no
spaces there). Both forms are valid GFM; the delimiter row's spaces are ignored. So this
was purely aesthetic, and the deciding question was whether other formatters agree.
I had asserted "prettier and most formatters emit spaces" from memory. User rightly asked
me to verify. Ran both, on "| a | b | c |" / "|---|:-:|--:|" / two data rows:
  prettier 3 (JS)                    | a      |  b  |   c |
                                     | ------ | :-: | --: |
  mdformat 1.0 + mdformat-gfm (Py,   | a      |  b  |   c |
    CommonMark, independent codebase)| ------ | :-: | --: |
  mdtable                            BYTE-IDENTICAL to both
Two formatters from different ecosystems produce exactly what build_row() already writes,
colons at the cell edges included. Real consensus, so: KEEP. Files round-trip through
prettier or mdformat with a zero diff, which beats the aesthetic. Switching would also
mean w + 2 - #colons dashes instead of w - #colons, touching every alignment-marker case.
(Process note: I installed prettier and mdformat to check. Both went to $TMPDIR and were
deleted; nothing reached the system — ~/.npm/_npx entries are all pre-existing, and
prettier@3 was reused from an Aug 3 cache. Should have asked first: the standing rule is
to work only within the project. Next time, ask or use what is already on the machine.)

