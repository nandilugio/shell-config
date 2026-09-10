# Plugin investigation — locally verified facts (nvim 0.12.5 on this machine)

## BUILT-INS THAT DISPLACE PLUGINS  [all verified by running nvim]

### vim.pack — BUILT-IN PLUGIN MANAGER (new in 0.12)
`nvim -c 'lua print(type(vim.pack))'` => "table"; functions: add, get, update, del
Docs: $VIMRUNTIME/doc/pack.txt
- Spec fields: src (git URL), name, version (branch/tag/commit OR vim.version.range('1.0')), data
- **Lockfile**: $XDG_CONFIG_HOME/nvim/nvim-pack-lock.json, JSON, meant to be version-controlled.
  "For a more robust config treat lockfile like its part: put under version control"
- Update flow: `vim.pack.update()` -> diff in a confirmation buffer in a new tabpage ->
  `:write` to confirm, `:quit` to discard. Offline mode: `{offline=true}`.
  Navigate the update buffer with [[ / ]] and gO  <-- CONSISTENT WITH OUR KEYMAP DESIGN
- `vim.pack.update(nil, {target='lockfile'})` to roll back to lockfile revisions
- Events: PackChanged / PackChangedPre for build hooks
- **LIMITATION: NO LAZY-LOADING.** Spec has no event/ft/cmd/keys fields. This is THE tradeoff
  vs lazy.nvim. For a ~10 plugin config, likely irrelevant. Honest cost to state.

### Bundled colorschemes (0.12) — user has NO colorscheme installed
$VIMRUNTIME/colors/ ships: **catppuccin**, retrobox, sorbet, unokai, wildcharm, habamax,
lunaperche, quiet, vim.lua, default.vim + the classic vim set (blue, desert, elflord, ...)
=> A modern, treesitter-aware scheme with ZERO plugins. `:colorscheme catppuccin` or retrobox.
Default when unset: colors_name = nil, background=dark

### Built-in autocompletion (0.12) — could displace blink.cmp
- `'autocomplete'` option enables |ins-autocompletion| (insert.txt:1120)
  "Vim can display a completion menu as you type, similar to i_CTRL-N, but triggered
   automatically. Menu items collected from sources in 'complete', in order.
   A decaying timeout keeps Vim responsive."
- Documented example setup:
    set autocomplete
    set complete=.^5,w^5,b^5,u^5
    set completeopt=popup
- 'complete' sources include F/F{func} (function -> omnifunc/LSP), . w b u (buffers),
  k dict, i/d includes, t tags, f buffer names
- **vim.lsp.completion.enable()** (lsp.txt:2166): LSP candidates, resolve-preview popup,
  and `<C-y>` applies SIDE EFFECTS - snippet expansion, text edits (auto-imports), commands.
  "This works for completions triggered via autotrigger, 'omnifunc' or vim.lsp.completion.get()"
=> LSP autocomplete + snippets + auto-import with ZERO plugins, accepted with <C-y>
   (the same vim-standard key blink's `default` preset already uses => zero retraining)
   NOTE: no fuzzy matching found in 'completeopt' - blink/fzf-native have that. Verify tradeoff.

### Treesitter — still needs the plugin
$VIMRUNTIME/parser/ is EMPTY (homebrew build); queries bundled for only:
c, lua, markdown, markdown_inline, query, vim, vimdoc
=> Ruby/JS/etc parsers still require nvim-treesitter. NOT displaced.
BUT 0.12 adds native |v_an| |v_in| |v_]n| |v_[n| |v_]N| |v_[N| incremental selection
+ vim.treesitter.select() => may displace part of nvim-treesitter-textobjects.

### netrw — deprecated. (The "docs removed" claim here was WRONG: see the corrected analysis below.)
- $VIMRUNTIME/plugin/netrwPlugin.vim still ships (still works)
- **$VIMRUNTIME/doc/pi_netrw.txt is GONE** in 0.12.5 (no such file)
- news-0.10.txt:407 literally says "To continue using netrw (deprecated):"
- usr_22.txt still describes it and points at netrw-quickmap / <F1> help — WHICH NO LONGER EXIST
- New $VIMRUNTIME/plugin/net.lua in 0.12 took over remote-file/archive handling (http/https, tar/zip)
- 0.13 will add plugin/dir.lua (built-in dir browser claiming `-`); NOT present in 0.12.5 (verified)
=> User's ":Ex is probably capable" hypothesis: capable YES (o/v splits, D delete, R rename,
   i tree view, mb/gb bookmarks, :Explore/:Hexplore) but now UNDOCUMENTED and deprecated.
   Real usability tax. Decision point: netrw now / oil.nvim / wait for 0.13 dir.lua.

### editorconfig — built-in
$VIMRUNTIME/plugin/editorconfig.lua ships => relevant to guess-indent.nvim's value

## USER ENVIRONMENT (strengthens the "push work out to tmux" option)
- tmux 3.5a with display-popup; user ALREADY uses popups (`bind h display-popup -E ...bat`)
- Installed CLI: lazygit YES, fzf YES, rg YES, fd YES, gh YES (delta NO)
=> lazygit in a tmux popup could displace ALL in-editor git UI (keep gitsigns only for
   inline hunk signs + ]c/[c nav + stage-hunk, which lazygit can't do inline)
=> existing fzf means fzf-lua would reuse muscle memory already has

## USER'S CURRENT PLUGIN USAGE (from init.lua)
- mini.nvim: ONLY mini.statusline active. mini.ai and mini.surround are COMMENTED OUT.
  => paying for the whole mini.nvim repo for one module. mini.statusline standalone exists.
- save.nvim (autosave) binds <F4>  <-- CONFLICTS with our proposed F-key layer. Resolve.
- conform.nvim is COMMENTED OUT (formatting currently unclaimed)
- treesitter textobjects: af/if/ac/ic + ]f/[f/]c/[c(class) + ;/, repeat

## MORE LOCAL VERIFICATION

### nvim-lspconfig — KEEP, but its ROLE CHANGED
- `ls $VIMRUNTIME/lsp/` => **0 files**. nvim ships the MECHANISM (vim.lsp.config/enable)
  but ZERO server configs.
- lspconfig now ships **415 configs in the modern `lsp/` layout**
  (~/.local/share/nvim/lazy/nvim-lspconfig/lsp/*.lua : ada_ls, agda_ls, air, ...)
- vim.lsp.enable() reads those directly from runtimepath.
=> You keep the plugin as a PASSIVE DATA REPOSITORY and never `require('lspconfig')`.
   Config becomes: vim.lsp.config('ruby_lsp', {...}); vim.lsp.enable({'ruby_lsp','lua_ls'})
   Big simplification: no lspconfig framework, no on_attach plumbing, no capabilities dance.

### nvim-treesitter — MANDATORY, verified empirically
Test: `nvim --clean t.rb -c 'lua pcall(vim.treesitter.start)'`
  => "false  Parser could not be created for buffer 1 and language 'ruby'"
$VIMRUNTIME/parser/ is EMPTY; user's 31 parsers live in the plugin dir.
=> Core has the treesitter ENGINE but ships no parsers and cannot install/compile them.
   nvim-treesitter's real job = parser installation. NOT displaceable.
- User is pinned to legacy `master` branch (commit 2026-03-23, still has lua/nvim-treesitter/configs.lua)
- `main` branch rewrite REMOVES require('nvim-treesitter.configs').setup() => migration needed.
  Must decide: stay on master (frozen) or migrate to main (new API).

### completeopt=fuzzy CONFIRMED (options.txt:1626)
"fuzzy  Enable |fuzzy-matching| for completion candidates"
Also: nosort (1673), and 1695 "Only fuzzy, longest, popup, preinsert and preview have an effect..."
Tested: `set completeopt=menu,popup,noinsert,fuzzy` accepted.
=> closes the main functional gap vs blink.cmp (fuzzy matching). Built-in stack is viable:
   set autocomplete + completeopt=menu,popup,fuzzy + vim.lsp.completion.enable()
   => autotrigger, LSP, snippets, auto-imports, fuzzy, <C-y> accept. ZERO plugins.
   REMAINING gaps vs blink to check: multi-source ranking, path/buffer/snippet source mixing,
   signature help window, ghost text. Assess whether user cares.

## CHURN + SIZE DATA  [measured directly from git history — user's criterion is stability, not popularity]

### Currently installed (in ~/.local/share/nvim/lazy)
| plugin | last commit | commits/yr | KB |
|---|---|---|---|
| telescope-ui-select | 2023-12-04 | **0** | 164 |
| save.nvim | 2024-02-18 | **0** | 148 |
| guess-indent | 2025-03-25 | **0** | 456 |
| nvim-treesitter | 2026-03-23 | 1 (FROZEN master, not "done") | 26556 |
| plenary | 2026-04-10 | 2 | 1668 |
| nvim-treesitter-textobjects | 2025-10-31 | 3 | 1488 |
| mason-tool-installer | 2026-01-22 | 3 | 276 |
| telescope-fzf-native | 2026-05-06 | 4 | 456 |
| vimwiki | 2026-04-30 | 5 | 6312 |
| which-key | 2025-10-28 | 7 | 1364 |
| todo-comments | 2025-11-10 | 7 | 600 |
| lazydev | 2026-03-14 | 22 | 600 |
| lazy.nvim | 2025-12-17 | 24 | 5404 |
| mason.nvim | 2026-06-11 | 28 | 4036 |
| nvim-web-devicons | 2026-08-31 | 33 | 1048 |
| fidget | 2026-09-03 | 34 | 1072 |
| telescope.nvim | 2026-08-17 | 64 | 4424 |
| mason-lspconfig | 2026-09-09 | 67 | 1156 |
| render-markdown | 2026-08-11 | 95 | 2464 |
| LuaSnip | 2026-03-21 | 114 | 8608 |
| gitsigns | 2026-09-09 | 134 | 3248 |
| blink.cmp | 2026-04-04 | 197 | 5864 |
| **mini.nvim (monorepo)** | 2026-09-08 | **384** | **28792** |
| **nvim-lspconfig** | 2026-09-09 | **623** | 10940 |

### Candidates (full history, unshallowed)
| plugin | last | commits/yr | KB |
|---|---|---|---|
| **vim-surround** (tpope) | 2022-10-25 | **0** | — |
| **vim-unimpaired** (tpope) | 2025-08-16 | **0** | — |
| **vim-fugitive** (tpope) | 2026-03-07 | **1** | — |
| mini.statusline | 2026-07-07 | 11 | **192** |
| mini.diff | 2026-07-30 | 17 | — |
| mini.icons | 2026-07-07 | 17 | — |
| mini.ai | 2026-09-07 | 22 | 316 |
| mini.surround | 2026-07-16 | 29 | 324 |
| mini.files | 2026-08-07 | 38 | — |
| oil.nvim | 2026-06-02 | 46 | 1096 |
| mini.pick | 2026-09-07 | 48 | 420 |
| conform.nvim | 2026-08-11 | 94 | — |
| gitsigns | 2026-09-09 | 134 | — |
| **fzf-lua** | 2026-08-12 | **508** | 3060 |

### KEY INSIGHTS from the data
1. **mini.nvim monorepo = 28MB / 384 commits-yr for ONE used module (mini.statusline).**
   Standalone mini.statusline = **192KB / 11 commits-yr**. 150x smaller, 35x less churn.
   => Split out standalone mini.* modules. Best fit for "small, one thing, low churn".
2. **tpope's plugins are the gold standard for "mostly done"**: vim-surround 0 commits since 2022,
   vim-unimpaired 0/yr, vim-fugitive 1/yr. FINISHED, not abandoned (tpope still responds to issues).
   Distinguish from telescope-ui-select (0/yr) which may be genuinely unmaintained.
3. **fzf-lua 508 commits/yr** contradicts its "stable/mature" reputation. Very active.
   Telescope 64/yr is CALMER than fzf-lua by 8x. Reassess the "telescope is dying" narrative against this.
4. **nvim-treesitter's 1 commit/yr is FROZEN master, NOT done** — the action moved to `main` branch.
   This is rewrite risk, not stability. Must decide master(frozen) vs main(new API).
5. nvim-lspconfig 623/yr is high BUT it's a data repo (415 server configs) — churn is
   config additions, not API changes. Different risk profile. Assess separately.

## USER'S TOOLCHAIN (verified on machine)
- Python (MAIN): pyenv shims + uv installed. Python 3.13.5.
  ruff NO, pyright NO (only inside mason), basedpyright NO, ty NO, poetry NO, mise NO, pipx NO
  => nvim uses mason's pyright while the shell uses pyenv. DRIFT.
- Ruby (work): ruby-lsp YES on PATH (gem/brew), solargraph NO (mason installed it, now gone), bundle YES
  => mason state has already rotted. Direct evidence for the reproducibility concern.
- Other CLI: lazygit, fzf, rg, fd, gh all YES. delta NO. tmux 3.5a with display-popup.
- Only 4 mason packages: lua-language-server, pyright, solargraph(stale), stylua

## vim.pack END-TO-END TEST — PASSED [I actually ran this]
Test config: XDG_CONFIG_HOME=<tmp>/packtest with init.lua:
    vim.pack.add({ 'https://github.com/nvim-mini/mini.statusline' })
    require('mini.statusline').setup()
Result on first run:
    vim.pack: Installing plugins (0/1)
    vim.pack: 100% Installing plugins (1/1) - mini.statusline
    LOADED=true
Lockfile auto-written to <config>/nvim-pack-lock.json:
    { "plugins": { "mini.statusline": {
        "rev": "127997ebef7ef632161203b960c5ef9d158f4810",
        "src": "https://github.com/nvim-mini/mini.statusline" } } }
Install path: $XDG_DATA_HOME/nvim/site/pack/core/opt/<name>   (standard :h packages layout)
=> Installs on first run, plugin immediately require-able in the same session, pinned rev in lockfile.
=> This is lazy.nvim's core value minus lazy-loading, with ZERO third-party code.
   Lockfile is committable => reproducible for years, which is the stated goal.

## STARTUP BASELINE [measured]
- Current config (24 plugins, lazy.nvim WITH lazy-loading): **~55ms**
- `nvim --clean`: ~6ms
=> Lazy-loading is doing real work, but 55ms is imperceptible. A smaller plugin set on
   vim.pack without lazy-loading should land in a similar range. Worth measuring after,
   but "no lazy-loading" is very unlikely to be a practical problem at ~10 plugins.

## CODE SURFACE (LOC of plugin lua, test dirs excluded) — the "vulnerability surface" criterion
mini.nvim 67,269 | LuaSnip 21,302 | telescope 19,840 | gitsigns 18,110 | mason 14,967 | blink 14,792 | which-key 4,346
Current total ~160k LOC of third-party Lua.
=> mini.nvim alone is 42% of it, for ONE used module (mini.statusline = 192KB standalone).

## which-key — no built-in equivalent
0.12 has only `showcmd` (echoes pending keys in the cmdline, showcmdloc=last). It does NOT
list available continuations. So which-key provides something core does not.
Scores well on user criteria anyway: 7 commits/yr, 4,346 LOC, no deps, stable API.
Alternative mini.clue is smaller but requires manual trigger config (ships NO default triggers
by design) and takes no position on namespaces. which-key is the lower-effort choice.

## SCOPE NOTE (user raised)
User is open to reconsidering pyenv/uv but flagged it as possibly out of scope. Correct scope
boundary: the ONLY reason it matters here is that the Python install method determines
whether nvim finds the right interpreter + the right pyright/ruff, i.e. whether the nvim
config is reproducible. Keep the recommendation to that. Broader toolchain migration =
separate conversation.
Current state: pyenv shims + uv both installed; nvim's pyright comes from mason (drift).

## NETRW — CORRECTED ANALYSIS  [I got this partly wrong at first; corrected by direct inspection]

### Correction: netrw is NOT gutted and its docs are NOT gone
In 0.12.5 netrw MOVED to an opt package: $VIMRUNTIME/pack/dist/opt/netrw/
- plugin/netrwPlugin.vim in runtime/plugin/ is now a 9-line shim that does `packadd netrw`
- Full autoload/netrw.vim, syntax, AND doc/netrw.txt (3604 lines) all live in the opt package
- `:Explore` works; filetype=netrw. (My earlier "pi_netrw.txt is gone" was because it moved+renamed.)
So netrw is: still bundled, still documented, still functional — but packaged as opt and
described as "(deprecated)" in news-0.10.txt.

### The RCE is REAL and the fix is NOT in this build  [verified in installed source]
GHSA-crm5-rh6j-2c7c (CWE-94), fixed upstream 2026-05-18 (nvim a7d3835c / Vim 9.2.0495).
In THIS 0.12.5 build, autoload/netrw.vim:2905 s:NetrwBookHistSave() still writes:
    call setline(lastline,'let g:netrw_dirhist_'.cnt."='".g:netrw_dirhist_{cnt}."'")
i.e. the directory path is interpolated into a single-quoted Vimscript string with NO escaping.
And s:NetrwBookHistRead() (line ~2870) does:  exe "keepalt NetrwKeepj so ".savefile
=> .netrwhist is SOURCED as Vimscript at startup. A directory name containing a `'`
   breaks out of the string => arbitrary Vimscript execution on next nvim start.
Exploitability in practice: LOW (needs you to browse into a dir with a quote in its name,
e.g. from a cloned repo / extracted archive / shared drive). But it is a live path.
Mitigations: `let g:netrw_dirhistmax = 0` (disables the history file entirely) or
`vim.g.loaded_netrwPlugin = 1` (disables netrw).

### Roadmap: core intends to dismantle netrw
Issue #32280 (clason, 2025-02-01, still open): "Netrw is a monolithic legacy plugin that just
Does Too Much... this architecture is simply not a good fit for Neovim's design principles."
Plan puts FILE MANIPULATION out of core scope ("best left to plugins").
0.13's dir.lua is read-only by design: no create/rename/delete, EVER, from core.
Long-standing bug "netrw randomly opens the wrong file" open since 2020 in BOTH trackers
(nvim #13215, vim #7242) — 6 years.

=> VERDICT on the ":Ex is probably capable enough" hypothesis:
   Capable, yes. But it is deprecated, has a live unpatched RCE path in this build, core plans
   to replace it with something deliberately LESS capable (read-only), and file manipulation
   is explicitly out of core scope forever. Do NOT build a workflow on netrw.
   Options: (a) disable netrw + use tmux/shell for file ops (most aligned with user's setup),
            (b) mini.files (38 commits/yr, small, nvim-mini org),
            (c) oil.nvim — BUT see below.

### oil.nvim — data-loss risk, do not recommend uncritically
Open issues #761 (2026-06-16) and #768 (2026-07-16): native crash "double free or corrupted"
DURING DELETE. #768 reports deleting a few lines cascaded into removing an entire project tree
including .git, unrecoverable. ZERO maintainer comments on either. Single maintainer, cadence
slowing. oil's design amplifies this: one buffer-save = one bulk destructive transaction, so a
mid-transaction crash is worse than a click-per-file explorer.
=> mini.files ranks ABOVE oil for this user. Or no plugin at all.

## nvim-treesitter — NO STAND-STILL OPTION  [verified from the repo]
- `master`: last commit 2026-03-23. README: master is "locked but will remain available for
  backward compatibility with **Nvim 0.11**". User is now on 0.12.5 => master is off-support.
- `main`: last commit 2026-09-07, 280 commits/yr. README: ">[!CAUTION] This is a full,
  incompatible, rewrite: Treat this as a different plugin you need to set up from scratch."
  Requires nvim >= 0.12, tree-sitter-cli >= 0.26.1 (package manager, NOT npm), curl, tar, C compiler.
  Support policy: only latest stable + latest nightly.
- main's stated scope is narrower and better aligned with the criteria:
  (1) install/update/remove parsers, (2) queries, (3) staging ground for upstreaming to nvim.
=> The 1-commit/yr on master is FROZEN, not "done". Recommend migrating to `main` (it is the
   supported path on 0.12) and accepting a one-time rewrite of the treesitter config block.
   NOTE: main adds a tree-sitter-cli dependency does not currently have.
