# FINAL DECISIONS — nvim 0.12.5 config rebuild
Agreed with user 2026-09-10. Companions: keymaps.md · language-servers.md ·
research-plugins.md · research-keybindings.md

## GUIDING PRINCIPLES (user's words)
- "small, do one thing right, mostly done, very little churn and surface for vulnerabilities"
- "avoid big things changing every day", "reliable and reproducible for years"
- "prefer built-ins over plugins"
- **PORTABILITY**: "install nvim on a server, pull my config and have something workable
  without installing any other tool" => ALL external deps must be OPTIONAL, with graceful
  degradation. Same keys, less power.
- tmux is the base of the workflow, but must NOT be a hard dependency of the nvim config.

## FINAL PLUGIN LIST — 8 (from 24), then 7 (lazydev dropped 2026-11-04, see below)
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
Added 2026-09-15, settling the "re-add later if concealment is missed" note above.
What was missed was not concealment but alignment, which conceal cannot do: it removes
characters, and alignment needs them added. ~400 lines of dependency-free Lua instead of
render-markdown (1.4M, 10,790 LOC, 99 commits/yr) for one feature out of many.
Two halves: render (<leader>um) pads with inline virt_text, file untouched; align
(<LocalLeader>t) rewrites the table under the cursor. NOT enabled for vimwiki, and that
exclusion is passed from init.lua, not baked into the plugin.
Design notes, measurements and the bug history: lua/mdtable/DESIGN.md

### Statusline: BUILT-IN. Colorscheme: BUILT-IN default (user likes the grey/green they have).
0.12 default statusline already shows filename, modified/RO, LSP progress, ◐ busy indicator,
diagnostic counts, ruler.

### File browser: mini.files (user explicitly wants a browser AND a fuzzy finder — different
jobs: "what's in here" vs "where is X")
NOT netrw: live RCE path in this build (GHSA-crm5-rh6j-2c7c) — autoload/netrw.vim:2905 writes
dir names UNESCAPED into single-quoted vimscript in .netrwhist, and NetrwBookHistRead SOURCES
it at startup. Fix not in 0.12.5 (it landed in 0.12.6, 2026-10-09, as vim patch 9.2.0495;
the other two reasons stand). Plus core is dismantling netrw (#32280) and 0.13's dir.lua
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
  REVISED 2026-11-04: lazydev DROPPED. It was never setup() -- found in a review,
  lua_ls had no workspace library the whole time (client.settings.Lua.workspace was
  nil after attach). What it does lazily, $VIMRUNTIME plus luv's stubs as
  workspace.library does in two lines of lua_ls settings, so no plugin.

## Done during implementation
1. save.nvim removed; replaced by a built-in toggle on <leader>oa. <F4> freed.
   MOVED 2026-11-04 to <leader>ua: it is a setting, and <leader>u is where settings
   toggle; <leader>o keeps the actions (cheatsheet, whitespace, wiki).
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

### Markdown heading depth: SECOND LOCAL PLUGIN (lua/mdheading)
Added 2026-09-16. Colours each heading line by depth, strongest at 1 — markdown
encodes depth in character count, so "######" looks heavier than "#" while meaning
less. Display only; the file is untouched. <leader>uH toggles.
Four distinct shades, not six: a bounded range over fewer steps is the only lever that
widened the gap without costing contrast, so #### and deeper share one colour.
Design notes, measurements and the colour derivation: lua/mdheading/DESIGN.md

### Diagnostics: two toggles, cursor line by default (2026-11-04)
Was: virtual_lines on every line, one <leader>ud cycling all/warn/errors/off,
which filtered the virtual lines only (signs and underlines showed everything).
Now two independent settings (setup/diagnostics.lua):
- scope, <leader>ud: current line -> every line -> none. DEFAULT current line.
  Messages under every line push code around while typing, the user's complaint.
  Current line is virtual_text with current_line=true, at end of line, so the
  view does not move as the cursor does either (virtual_lines current_line would
  insert lines below the cursor on every landing). Long messages truncate there;
  <C-w>d shows them whole. "Every line" keeps virtual_lines: a survey, never cut off.
  Underlines only in "every line" (2026-11-04, after trying it): in the other two
  they marked the whole file while its messages were hidden. Underlining just
  the cursor line would need a custom handler; <C-w>d covers that case.
- severity, <leader>uD: all -> warnings+errors -> errors. Filters messages AND
  underlines. Signs are NEVER filtered, by decision: the gutter must always say
  something is there, so a filter never hides an error's existence.
Review mode (setup/review.lua) sets both: every line, errors only.

### Review mode (2026-11-04) — setup/review.lua, <leader>uR
One toggle between two PRESETS, each a complete set of absolute values (not
save-and-restore): edit is the normal state, named; leaving review always lands
in the same place.
  review: gitsigns base = merge-base · diagnostics every line, errors · basedpyright
          standard · deleted lines, word diff, line blame on · 'write' off
- NO HOSTS: only local git, no gh. On a branch, branch review; on a detached HEAD,
  that commit vs its parent (works when nvim starts detached).
- BASE = the nearest merge-base among develop/master/main and each remote's default
  branch, local and remote. Nearest, not first: a stale local develop loses to a
  fresher origin/develop, a hotfix off master is reviewed against master.
  gitsigns gets the merge-base SHA: given "develop" it would diff against develop's
  TIP (verified it rejects a range like develop...HEAD).
- Git records no "branched from" (the reflog's "Created from" is local and
  expires). A stacked branch's nearer fork is found from the graph -- the
  branch's own first-parent commits, one rev-list -- but a parent and a child
  branch look alike from there, so it is a HINT in the entry message, never a
  prompt. Only shown when the fork is newer than the conventional base, which
  drops a child that forked before develop was merged in.
- :Review toggles, like <leader>uR, so the mode can be left from the command
  line too; :Review <ref> enters or switches the base, and <Tab> offers the
  detected bases first. (Was :ReviewBase with a picker: one command, and
  completion instead of a picker, is one concept fewer.)
- Fetch on entry, never awaited: detached (no terminal for ssh to prompt on),
  GIT_TERMINAL_PROMPT=0, 60s timeout. If it moves the base, switch and say so.
- 'write' off, edits allowed: in review the working tree IS the branch, and a
  saved edit is a hunk the same colour as the author's (gitsigns dims only
  index-staged hunks). The LSP reads buffers, so experiments need no write.
- Staging/resetting refuse whenever the base is not the index (setup/git.lua):
  a hunk is the base's diff, and reset would rewrite the file to the base.
- Statusline: base..head (two dots) for a base set by hand -- what gitsigns
  compares; develop...head (three) only where review set the merge-base.
- Measured on the work monorepo (1524 refs): detection's git calls < 0.2s.
- Two kinds, shown as bR / cR in the statusline. Commit review = HEAD vs its
  parent, placed on a line of history: a feature branch's own commits
  (feature-x~3 4/7, bounded), else a trunk's first-parent line, else none.
  Without a position the label is the comparison itself, master^..master,
  master~3^..master~3 or abc1234^..abc1234: a bare "master" read as if the
  whole branch were under review. A branch with nothing to compare against (master
  in a repo that only commits there) falls back to commit review of its tip,
  NOT to the upstream: that would hide commit review whenever you are ahead,
  and :Review @{u} says it explicitly.
- Messages fit v:echospace: longer raises hit-enter, which ate the next keys.
- 2026-11-05, from the test suite: gitsigns' gitdir watcher can put an older
  base back after a checkout (TODO 29, upstream). keep_base re-applies the
  review's base on the buffer's GitSignsUpdate, once per buffer and base.
- 2026-11-06, hunk colours: deleted lines and word diff are backgrounds only
  (setup/git.lua), the editor's bg mixed with a red or green tint, so the
  syntax colours gitsigns captures show through and <leader>ub keeps working.
  gitsigns' defaults were DiffDelete fg+bold and reverse video, which hid them.
- Tested by lua/setup/review_test.lua against a repository it builds: the
  branch shapes, the walk, the guards, :Review, the fetch. Kept a module, not
  a local plugin: the seam is documented in the header, see there.

### :help for the config's own features (2026-11-05) — doc/config.txt
The cheatsheet says what to press; doc/config.txt says how things behave, as
real Vim help (:help review-mode, :help :Review, <leader>fh); this file says
why. Neovim reads doc/ from every runtimepath entry, the config dir included.
init.lua runs :helptags only when config.txt is newer than doc/tags, which is
gitignored. Index tag is config.txt, not config: :help config is Neovim's own
(starting.txt).
