# FINAL DECISIONS — nvim 0.12.5 config rebuild
Agreed with user 2026-09-10. Companions: keymaps.md · plugins.md ·
language-servers.md · research-plugins.md · research-keybindings.md

## GUIDING PRINCIPLES (user's words)
- "small, do one thing right, mostly done, very little churn and surface for vulnerabilities"
- "avoid big things changing every day", "reliable and reproducible for years"
- "prefer built-ins over plugins"
- **PORTABILITY**: "install nvim on a server, pull my config and have something workable
  without installing any other tool" => ALL external deps must be OPTIONAL, with graceful
  degradation. Same keys, less power.
- tmux is the base of the workflow, but must NOT be a hard dependency of the nvim config.

## FINAL PLUGIN LIST — 8 (from 24)
1. nvim-lspconfig   — DATA ONLY (415 server configs). Never require() it.
2. nvim-treesitter  — `main` branch (master is frozen/0.11-scoped). Needs tree-sitter-cli.
3. gitsigns.nvim    — zero deps; ambient git layer (signs, ]c/[c, stage hunk, blame)
4. fzf-lua          — zero Lua deps, no build step; wraps the `fzf` binary
5. mini.files       — file browser (standalone repo, NOT the mini.nvim monorepo)
6. lazydev.nvim     — lua_ls knows the nvim API (user edits nvim config)
7. which-key.nvim   — KEEP: user is deliberately relearning a new scheme; 7 commits/yr
8. vimwiki          — personal notes

## DROPPED (16)
mason.nvim, mason-lspconfig, mason-tool-installer  -> uv/brew/gem + vim.lsp.enable()
telescope + telescope-fzf-native + telescope-ui-select -> fzf-lua (also provides vim.ui.select)
plenary.nvim            -> built-in vim.system / vim.fs / vim.iter
LuaSnip                 -> built-in vim.snippet
mini.nvim (monorepo)    -> built-in statusline (+ standalone mini.files)
fidget.nvim             -> built-in statusline (vim.ui.progress_status + busy indicator)
save.nvim               -> nothing (PRIORITY REMOVAL: unmaintained since 2024-02, unknown
                           author, runs on every text change, owns <F4>)
todo-comments           -> :grep TODO / fzf-lua grep
nvim-web-devicons       -> nothing
nvim-treesitter-textobjects -> nothing. ]f/[f, af/if, ac/ic are gone; core's an/in select
                           syntax nodes. Re-add (main branch) if missed.
render-markdown         -> DROPPED: collides with vimwiki; syntax colour comes from treesitter
                           anyway. Re-add later if concealment is missed.
                           SETTLED 2026-09-15: concealment was never the gap; table alignment
                           was. lua/mdtable does that in ~400 lines. See the markdown section.
guess-indent            -> .editorconfig (built-in support)
lazy.nvim               -> vim.pack (AFTER the cull; see below)
conform.nvim            -> not needed; LSP formatting via 'formatexpr'
stylua                  -> DROPPED per user; lua_ls formats
colorscheme plugin      -> NEVER NEEDED
netrw                   -> DISABLE (vim.g.loaded_netrwPlugin = 1); mini.files replaces it

## KEY DECISIONS + RATIONALE
### Plugin manager: vim.pack (built-in), after the cull
Verified end-to-end: installs on first run, require-able immediately, committable lockfile
with pinned revs at <config>/nvim-pack-lock.json. No lazy-loading (only real tradeoff).
BONUS: because it's just a function call, conditional loading is trivial —
  if vim.fn.executable('fzf') == 1 then vim.pack.add{...} end
lazy.nvim's declarative spec makes that clumsier. Portability requirement ARGUES FOR vim.pack.
Sequence: cull to 8 first, measure startup (now ~55ms w/ lazy-loading; clean nvim ~6ms), then migrate.

### Completion: BUILT-IN, drop blink.cmp
completeopt=menu,menuone,popup,noselect,fuzzy + vim.lsp.completion.enable()
=> LSP, snippets, auto-imports, fuzzy matching, accept with <C-y>
(<C-y> is the same key blink's `default` preset uses => ZERO retraining)
Drops the churniest dependency (197 commits/yr, 15k LOC) + the LuaSnip dep.

REVISED 2026-09-14, after a few days of use: MANUAL, not automatic.
'autocomplete' is off. Tried it on with autocompletedelay=500; a menu that
appears while you are still thinking interrupts more than it helps.
- Off is the DEFAULT in both editors. The option originated in **Vim**
  (patch 9.1.1590, 2025-07-25, Girish Palya); nvim ported it. Neither enables it.
  vim.lsp.completion.enable() likewise defaults autotrigger=false.
- Costs nothing: autotrigger only adds an InsertCharPre autocmd
  ($VIMRUNTIME/lua/vim/lsp/completion.lua:1175). Omnifunc, <C-y> side effects,
  snippets and auto-imports are all outside that branch.
- Also removes a documented wart: with 'autocomplete' ON, :h ins-autocompletion
  says you must press <C-e> before i_CTRL-N behaves.
- The completeopt flags become fully live again. The docs' claim that only
  fuzzy/longest/popup/preinsert/preview matter is scoped to autocomplete=ON —
  that sentence is what misled an earlier trim to "popup,fuzzy" and broke typing.
TRIGGER KEY: <C-Space>, mapped to <C-n>. Verified as the cross-editor standard
(VS Code, Zed, RubyMine, Sublime, blink.cmp, nvim-cmp, kickstart/LazyVim/
AstroNvim/NvChad). Helix is the outlier at <C-x>. The NUL-collision folklore was
TESTED, not assumed: raw 0x00 fires the <C-Space> mapping (not <Nul>) under
xterm-256color and screen-256color, and through tmux 3.5a. Caveats: real Vim
still needs <C-@>, Windows terminals have open bugs, macOS may claim it for
input-source switching. <C-n>/<C-x><C-o> stay as the unambiguous fallbacks.
NOT copied from the "manual-only gurus" folklore — checked, and ThePrimeagen,
TJ DeVries and folke all leave autocompletion ON. This is a personal preference,
landing on the editors' own default.

### Command line: MANUAL too (revised 2026-09-14)
Was: wildtrigger() on CmdlineChanged + wildmode=noselect:lastused,full, i.e. the
menu appeared as you typed (the recipe from :h cmdline-autocompletion).
Now: no autocmd; <Tab> opens the menu, which is Vim's default AND every shell's.
wildmode=full:lastused — "noselect" was there so <CR> would not accept a
preselected match while the menu auto-showed; with <Tab> as the trigger it would
just cost a second <Tab> to pick the first match. wildoptions keeps pum+fuzzy.
Separate mechanism from insert mode: :h completeopt says it does not apply to
cmdline-completion; 'wildoptions'/'wildmode' govern it.

### Markdown tables: LOCAL PLUGIN (lua/mdtable), not render-markdown
Added 2026-09-15, settling the "re-add later if concealment is missed" note below.
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
for one feature out of many, and its icons want a Nerd Font (see the symbols section).
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

### Statusline: BUILT-IN. Colorscheme: BUILT-IN default (user likes the grey/green they have).
0.12 default statusline already shows filename, modified/RO, LSP progress, ◐ busy indicator,
diagnostic counts, ruler.

### File browser: mini.files (user explicitly wants a browser AND a fuzzy finder — different
jobs: "what's in here" vs "where is X")
NOT netrw: live RCE path in this build (GHSA-crm5-rh6j-2c7c) — autoload/netrw.vim:2905 writes
dir names UNESCAPED into single-quoted vimscript in .netrwhist, and NetrwBookHistRead SOURCES
it at startup. Fix not in 0.12.5. Plus core is dismantling netrw (#32280) and 0.13's dir.lua
replacement is READ-ONLY BY DESIGN (file manipulation permanently out of core scope).
NOT oil.nvim: 2 open MAINTAINER-UNACKNOWLEDGED double-free crashes on delete (#761, #768),
one credible data-loss (deleted a project tree incl. .git).
mini.files settings: use_as_default_explorer=true (takes over :Ex), permanent_delete=FALSE (trash).
Defaults are vim-idiomatic: h/l in-out, q close, m/' marks, = synchronize, g? help.

### Fuzzy finder: fzf-lua
Replaces 4 plugins (~20k LOC + a C build) with 1 (zero Lua deps, no build).
Reads $FZF_DEFAULT_OPTS; optional fzf-tmux popup (fzf_tmux_opts, OFF by default).
HARD DEP: the `fzf` binary. tmux is NOT a dep.
Counterargument accepted: 508 commits/yr (highest measured). mini.pick (48/yr) was the
alternative; chose fzf-lua for the fzf/tmux convergence with the existing workflow.
CORRECTION recorded: "telescope is in maintenance mode" is MISATTRIBUTED — no maintainer said
it. Case against telescope = deps + LOC, not abandonment.

### Formatting: no plugin, and NO format-on-save initially
0.12 sets 'formatexpr' => `gq` formats via LSP, zero config. <leader>= for whole buffer.
"ruff/rubocop vs LSP formatting" is a FALSE CHOICE — LSP is the transport, ruff/rubocop are
what sits behind it. Deliberately manual because work agreements are loose: never reformat a
file the team hasn't agreed to reformat. Enabling later = one autocmd.

### Linting: nothing. ruff server + ruby-lsp publish diagnostics over LSP into vim.diagnostic.

### GRACEFUL DEGRADATION TABLE (the portability requirement)
| feature      | needs                        | fallback on a bare box                |
| fzf-lua      | `fzf` binary                 | :find (path+=**, wildmenu) / :grep, SAME KEYS |
| treesitter   | C compiler + tree-sitter-cli | built-in regex syntax highlighting     |
| LSP          | the server binary            | <C-]> via tags, <C-n> keyword completion |
| gitsigns     | `git`                        | nothing lost outside a repo            |
| mini.files   | nothing (pure lua)           | —                                      |
| lazydev      | nothing (pure lua)           | —                                      |
| which-key    | nothing (pure lua)           | —                                      |
Needs NOTHING: whole keymap layer, built-in completion, statusline, colorscheme, mini.files.

## LANGUAGE SERVERS
Python (MAIN): pyright + ruff server   -> `uv tool install`
  (NOTE: PyPI pyright is a Node wrapper — user has node v26.4.0 so OK;
   brew install pyright or uv tool install basedpyright avoid Node)
  ty: DO NOT ADOPT (0.0.x, beta, 94 releases/yr). Revisit at 1.0. pyrefly: revisit when calmer.
  venv detection: NO PLUGIN — ~20 lines with before_init (root_dir resolved there):
  VIRTUAL_ENV -> CONDA_PREFIX -> .venv -> venv. uv puts .venv in project root => common case covered.
  REJECT venv-selector.nvim (dormant, ~0 commits/12mo).
  Debugging: SKIP nvim-dap. breakpoint()/PYTHONBREAKPOINT=ipdb.set_trace in a tmux pane.
Ruby (work, 2.7 -> 3 soon): see the Ruby section in language-servers.md — SOLVED + tested on the
  real work repo. ruby-lsp 0.26.11 under 3.3.9 + BUNDLE_GEMFILE=<standalone> ; 2941 project
  files indexed. rubocop 1.28.2 works natively on 2.7 => reach it via built-in compiler/rubocop.vim
  into quickfix. Zero config changes at Ruby 3 migration.
Lua (tertiary): lua_ls + lazydev. No stylua.

## Done during implementation
1. save.nvim removed; replaced by a built-in toggle on <leader>oa. <F4> freed.
2. The dead mason-lspconfig `handlers` block replaced by vim.lsp.config/enable.
   (It had been silently discarding the lua_ls settings.)
3. `rbenv global` left alone — NOT needed. For Ruby < 3 projects the config finds
   the newest rbenv Ruby >= 3 that has ruby-lsp installed (nothing pinned), so the
   global stays `system`.
4. nvim-treesitter migrated master -> main; tree-sitter-cli installed via brew
   (note: the CLI is the `tree-sitter-cli` formula, not `tree-sitter`).
5. `.ruby-lsp/` added to config/home/gitignore_global.
6. Standalone ruby-lsp Gemfile + lock committed at dot_config/nvim/ruby-lsp/.

## Symbols: plain UTF-8, never a Nerd Font
Nerd Font glyphs live in the Unicode private-use area (U+E000-F8FF) and render
as boxes without a patched font — an invisible dependency, and one that breaks
over SSH or in a console. Everything here stays in the Basic Multilingual
Plane, which any monospace font of the last two decades covers:

  gutter      + ~ -        ASCII
              ‾  U+203E    deletion above the first line
              ≃  U+2243    line both changed and partly deleted
              ┆  U+2506    untracked
  statusline  ⇡  U+21E1    ahead of upstream
              ⇣  U+21E3    behind upstream
              ◐  U+25D0    busy (Neovim's own default)

The arrows match the zsh prompt (Pure) and the Claude Code statusline, which
use the same glyphs for the same reason.

`vim.g.have_nerd_font` was dropped with this: nothing needs one, and the only
reader was a which-key option already set to its default.
