# Plugin decisions — nvim 0.12.5
Criteria (user's words): "small, do one thing right, mostly done, very little churn and
surface for vulnerabilities, avoid big things changing every day, reliable and reproducible
for years." NOT popularity.
Raw evidence: `research-plugins.md`. Keymap: `keymaps.md`.

## LIVE BUG FOUND IN CURRENT CONFIG  [empirically verified, not inferred]
init.lua:959-972 passes `handlers = {...}` to require("mason-lspconfig").setup().
The `handlers` API was REMOVED in mason-lspconfig 2.x. Installed version: stable-14-gb5576cd,
grep for "handlers" in its lua/mason-lspconfig/init.lua => NO MATCHES.
TEST: opened a .lua file, inspected the attached client's config:
    lua_ls settings.Lua.completion = "NOT SET"
=> The `callSnippet = "Replace"` setting and the `capabilities` merge are SILENTLY DISCARDED.
Servers still attach (mason-lspconfig 2.x auto-enables via vim.lsp.enable()), so it LOOKS fine.
It works by accident, not by configuration. Fix regardless of other decisions.

## FINAL LIST: 24 -> 7 core
KEEP (7):
1. nvim-lspconfig      — DATA ONLY (415 configs in modern lsp/ layout). Never require() it.
                          Use vim.lsp.config()/vim.lsp.enable(). 623 commits/yr is data churn
                          (new servers), not API churn.
2. nvim-treesitter     — MANDATORY (core ships 0 parsers; ruby verified to fail without it).
                          MIGRATE master -> main. No stand-still option: master is frozen
                          (2026-03-23) and scoped to "backward compatibility with Nvim 0.11";
                          user is on 0.12.5, already outside support. main = full incompatible
                          rewrite, narrower scope (parser installer + queries). Needs
                          tree-sitter-cli >= 0.26.1 (package manager, NOT npm) + curl/tar/CC.
3. gitsigns            — zero plugin deps. Owns the AMBIENT layer lazygit can't: hunk signs,
                          ]c/[c, stage-hunk-under-cursor, inline blame. 134/yr but no deps, semver.
                          (lower-churn alt: mini.diff 17/yr, if blame/staging unneeded)
4. fzf-lua             — zero Lua deps, NO C build step, drives the fzf binary user already has.
                          Inherits FZF_DEFAULT_OPTS; has fzf_tmux_opts. Converges with existing
                          shell/tmux memory. COUNTERARGUMENT: 508 commits/yr (highest measured).
                          Lower-churn alt: mini.pick (48/yr).
5. mini.files          — THE FILE BROWSER. User explicitly wants browser AND fuzzy finder
                          (different jobs: "what's in here" vs "where is X").
                          38/yr, 3.1k LOC, 552KB, standalone repo, semver tags (v0.18.0).
6. lazydev             — small, one job, no built-in replacement, user edits nvim lua config
7. vimwiki             — personal. Least healthy thing kept (230 open issues, last tag 2024-01-24).

CONDITIONAL:
- blink.cmp  pin "1.*" (README: "V2 under active development with many breaking changes"),
  keep fuzzy.implementation="lua" (avoids the prebuilt Rust binary download).
  UNLESS the built-in completion trial succeeds -> then drop (197 commits/yr, 15k LOC = churniest kept dep)
- mini.surround (29/yr) / mini.ai (22/yr) — STANDALONE repos, not the monorepo. Currently
  commented out in user's config => probably not missed.
- conform.nvim (94/yr) — only if `ruff format` / `rubocop -a` are wanted over LSP formatting
- nvim-treesitter-textobjects (main branch) — only if af/if used. 0.12's an/in are incremental
  NODE selection, NOT semantic function/class objects. Not a replacement.
- guess-indent — or just use .editorconfig (built-in support, more reproducible)

DROP (with replacement):
| mason.nvim / mason-lspconfig / mason-tool-installer | system pkg mgrs (pyenv/uv, gem/bundler, brew) + vim.lsp.enable() |
| telescope + fzf-native + ui-select | fzf-lua (also provides vim.ui.select) |
| plenary.nvim            | built-in vim.system / vim.fs / vim.iter |
| LuaSnip                 | built-in vim.snippet (blink preset='default' instead of 'luasnip') |
| mini.nvim (monorepo)    | built-in statusline; standalone mini.* repos if needed |
| fidget.nvim             | built-in default statusline (has vim.ui.progress_status + busy indicator) |
| save.nvim               | 'autowriteall', or nothing.  ** PRIORITY REMOVAL ** |
| todo-comments           | :grep TODO / fzf-lua grep |
| nvim-web-devicons       | nothing (or standalone mini.icons, has mock_nvim_web_devicons()) |
| render-markdown         | built-in ts markdown highlighting (JUDGMENT: keep if actually used) |
| which-key               | nothing (JUDGMENT: no built-in equivalent; keep if used daily) |
| colorscheme plugin      | NEVER NEEDED — 0.12 bundles catppuccin, retrobox, sorbet, unokai, habamax, quiet |
| netrw                   | DISABLE: vim.g.loaded_netrwPlugin = 1  (see security note) |
| never add               | lazygit.nvim, fugitive, neo-tree, nvim-tree, oil.nvim, snacks.nvim |

## PLUGIN MANAGER: lazy.nvim now, vim.pack AFTER the cull
vim.pack verified working (see research-plugins.md). Built-in = zero supply chain, committable
lockfile. BUT no lazy-loading, and current 55ms startup depends on lazy-loading 24 plugins.
=> Cull to ~8 FIRST, measure, then migrate. Don't conflate two failure modes.

## netrw — DISABLE (user wants a browser, but not this one)
Live RCE path in THIS build (GHSA-crm5-rh6j-2c7c, upstream fix NOT applied here):
autoload/netrw.vim:2905 writes dir names unescaped into single-quoted vimscript in .netrwhist;
NetrwBookHistRead does `exe "... so ".savefile` => sourcing it executes injected code.
Trigger: browsing a directory whose name contains a single quote. Low likelihood, real path.
Core is dismantling netrw (#32280); 0.13's dir.lua replacement is READ-ONLY BY DESIGN —
file manipulation is permanently out of core scope. So core will never provide a file manager.
CORRECTION to an earlier claim of mine: netrw docs are NOT gone; they moved to
pack/dist/opt/netrw/doc/netrw.txt (3604 lines). :Ex works, filetype=netrw.

## oil.nvim — REJECTED despite popularity
Open, MAINTAINER-UNACKNOWLEDGED double-free crashes during delete: #761 (2026-06-16),
#768 (2026-07-16, credible data-loss: deleting a few lines removed a project tree incl. .git).
oil's design (one buffer-save = one bulk destructive transaction) makes a mid-transaction
crash worse than a per-file explorer. mini.files ranks above it.

## MISATTRIBUTED CLAIM, corrected
"Telescope is in maintenance mode" — NO maintainer ever said this. The quote is from a
different person, different repo (telescope-file-browser), 2022. The case for moving off
telescope rests on deps (plenary + C build) and 20k LOC, NOT on that rumour. State honestly.

## FOUR PRIORITY ACTIONS (do before vim.pack migration)
1. Remove save.nvim (untouched since 2024-02-18, unknown author, 7KB, runs on every text
   change, owns <F4> which conflicts with the F-key layer)
2. Fix the LSP config (dead handlers block -> vim.lsp.config()/vim.lsp.enable())
3. Drop mason (runtime binary downloader = largest attack surface; ALREADY DRIFTED:
   holds stale solargraph while the ruby-lsp actually used came from gem)
4. Migrate treesitter master -> main

## OPEN JUDGMENT CALLS FOR USER
- blink.cmp vs built-in completion (trial the built-in for a week)
- fzf-lua (zero deps, reuses fzf memory) vs mini.pick (10x less churn)
- which-key: keep? (no built-in equivalent)
- render-markdown: keep? (largest plugin at 2.4MB/18.8MB)
- conform: needed, or is LSP formatting enough?

## mini.files defaults are vim-idiomatic (fits the keymap design)
mappings: close='q', go_in='l', go_in_plus='L', go_out='h', go_out_plus='H',
  mark_set='m', mark_goto="'"  (matches vim's own mark keys!), reset='<BS>',
  reveal_cwd='@', show_help='g?', synchronize='=', trim_left='<', trim_right='>'
options: use_as_default_explorer=true  => it takes over :Ex / directory buffers, so netrw is
  bypassed naturally. permanent_delete=true by default — consider setting FALSE (trash dir)
  given the oil data-loss lesson.
Only binding needed at top level: something to open it. Candidates consistent with our map:
  `-` (parent dir — matches 0.13 dir.lua's future convention AND vim-vinegar tradition), or
  <leader>e. `-` is currently free and dir.lua guards against clobbering a user's `-`.

## fzf-lua + tmux [verified in source]
- defaults.lua:280  fzf_tmux_opts = { ["-p"] = "80%,80%", ["--margin"] = "0,0" }
  => can run the picker in a TMUX POPUP, same UX as user's existing `bind h display-popup`
- reads $FZF_DEFAULT_OPTS and $FZF_DEFAULT_OPTS_FILE (checked in _health.lua)
=> genuinely converges with the existing fzf/tmux muscle memory. Strongest argument
   for fzf-lua over mini.pick for THIS user, offsetting the 508 commits/yr concern.
