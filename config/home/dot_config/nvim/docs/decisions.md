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
set autocomplete + completeopt=menu,menuone,popup,noselect,fuzzy + vim.lsp.completion.enable()
(every flag spelled out: trimming to popup,fuzzy on the docs' word made the first
candidate insert itself while typing — see options.lua)
=> autotrigger, LSP, snippets, auto-imports, fuzzy matching, accept with <C-y>
(<C-y> is the same key blink's `default` preset uses => ZERO retraining)
Drops the churniest dependency (197 commits/yr, 15k LOC) + the LuaSnip dep.

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
