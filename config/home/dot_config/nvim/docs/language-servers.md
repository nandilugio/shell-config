# Language server decisions — Python (main) + Ruby (work) + Lua
nvim 0.12.5. Criteria: low churn, MIT-ish, reproducible for years, minimal plugins.
Status: investigation notes, in the order the work happened. Both items under "BROKEN
RIGHT NOW" were fixed by the rebuild, and later sections supersede earlier ones (the
shim-only advice gives way to the Ruby 2.7 resolution). The config no longer pins 3.3.9:
it uses the newest rbenv Ruby >= 3 that has ruby-lsp installed.

## TWO THINGS ARE BROKEN RIGHT NOW  [both verified on this machine]

### 1. Ruby LSP does not run
  rbenv global      => system      (Ruby 2.6.10)
  rbenv which ruby-lsp => "rbenv: ruby-lsp: command not found"
  ruby --version    => 2.6.10  (ruby-lsp requires >= 3.0)
  rbenv versions: system*, 2.7.4, 2.7.5, 3.2.9, 3.3.9, jruby-9.2.21.0
  ruby-lsp gem (0.26.1) is installed ONLY under 3.2.9.
  CORRECTION to my earlier note: I said "ruby-lsp YES on PATH" — that was an rbenv SHIM STUB,
  not a working command. It resolves to nothing under the current global Ruby.
  FIX: rbenv global 3.3.9 ; rbenv shell 3.3.9 && gem install ruby-lsp (repeat per Ruby used)

### 2. Config uses removed API (also in plugins.md)
  init.lua:959-972 mason-lspconfig `handlers` + require("lspconfig")[s].setup()
  => lua_ls settings verified NOT APPLIED.

### CORRECTION: solargraph is NOT gone
  ~/.local/share/nvim/mason/bin/solargraph -> packages/solargraph/solargraph, v0.57.0, present.
  It's just not on the SHELL PATH (mason prepends its bin dir only inside nvim).
  So the "drift" is narrower than I first said: mason's copy works inside nvim; it's simply
  a second, unpinned, nvim-only toolchain parallel to rbenv/uv. That's still the real argument.

## PYTHON  [verified via GitHub API 2026-09-10]
| tool | latest | date | license | releases/12mo | commits/12mo |
| pyright | 1.1.414 | 2026-09-09 | **MIT** | 10 | 205 |
| basedpyright | 1.40.0 | 2026-09-07 | MIT | 33 | 505 |
| ty (Astral) | **0.0.80** | 2026-09-09 | MIT | **94** | 463 |
| pyrefly (Meta) | 1.2.0 | 2026-08-01 | MIT | monthly | **8205** |
| pylsp | 1.14.0 | 2025-12-06 | MIT | 2 | **17** |
| jedi-language-server | 0.47.0 | 2026-05-31 | MIT | 2 | **28** |

**DECISION: pyright.** MIT (the LICENSE.txt is verbatim MIT — the proprietary thing is PYLANCE,
a separate VS Code-only extension that Neovim cannot use under any license, so nothing is lost).
10 releases/yr = lowest churn among real type-checkers. 151 contributors, MS-backed.
- Large existing codebase => pyright + diagnosticMode='openFilesOnly' (lspconfig default)
- Greenfield => basedpyright defensible (stricter defaults, PyPI-installable, no Node)
**ty: DO NOT ADOPT YET.** README: "ty is currently in beta", "does not yet have a stable API;
breaking changes ... may occur between any two versions". Still 0.0.x, 94 releases/yr
(~1 every 4 days). Exact opposite of the criteria. Revisit at 1.0.
**pyrefly**: Meta shipped 1.0 May 2026, at 1.2.0 — beat Astral to stable. Default checker for
Instagram (20M LOC), PyTorch, JAX. But 8205 commits/yr; lspconfig still says "still in
development, please report any errors". Promising, not boring yet.
**pylsp / jedi-ls**: only ones meeting the churn bar (17/28) but NEITHER DOES TYPE CHECKING.
jedi-ls bus factor = 1 (pappasam 519/600 commits).

**ruff 0.16.6** (MIT, 48 releases/yr): README claims "Drop-in parity with Flake8, isort, and
Black". `ruff server` stabilized in ruff 0.5.3, built into the binary (no separate ruff-lsp).
Running ruff + pyright together on one buffer is the INTENDED design (Astral: "intended to be
used alongside another Python Language Server"). ONE conflict: both provide hover; disable
ruff's via LspAttach `client.server_capabilities.hoverProvider = false`.

**venv detection: NO PLUGIN.** pyright does NOT auto-detect .venv (its docs confirm:
venv/venvPath -> python.pythonPath -> PATH fallback). ~20 lines using `before_init`
(config.root_dir is resolved there) + vim.env.VIRTUAL_ENV / CONDA_PREFIX / .venv / venv.
uv puts .venv in project root by default => covers the common case.
Poetry needs `poetry config virtualenvs.in-project true`, else rely on VIRTUAL_ENV
(natural in tmux). pyright also ships :LspPyrightSetPythonPath.
REJECT venv-selector.nvim: last commit 2026-05-20, ~0 commits/12mo, no tags. Dormant, and
solves a problem 20 lines already solve.

**Python debugging: SKIP nvim-dap.** nvim-dap-python last commit 2025-12-20 (~9mo stale).
`breakpoint()` builtin since 3.7; PYTHONBREAKPOINT=ipdb.set_trace. In a tmux pane you get the
full REPL with zero config. Largest complexity-per-benefit item in the report. Add later if needed.

## RUBY
ruby-lsp v0.26.11 (MIT, Shopify, 553 commits/yr, 170 contributors) is clearly standard.
solargraph 0.60.4 alive but effectively 1 maintainer (castwide 3867/4100 commits), 247 open issues,
lost the ecosystem. Finish the migration.
ruby-lsp handles rubocop via init_options={formatter="auto"} — auto-detects rubocop in the
bundle, routes BOTH formatting and lint diagnostics through LSP. RuboCop must be a PROJECT GEM
(>=1.4.0); ruby-lsp shells into the project's copy => editor and CI use identical .rubocop.yml.
No separate nvim plugin needed.

**DO NOT USE MASON FOR ruby-lsp** — Shopify's docs explicitly warn: "Using Mason to manage your
installation of the Ruby LSP may cause errors" because mason installs into ONE shared folder
across all Ruby versions while ruby-lsp has C extensions bound to a specific Ruby ABI.
With 5 rbenv Rubies this breaks constantly.
INSTALL MODEL: gem install ruby-lsp once per Ruby version used; launch via the rbenv SHIM
(never an absolute versioned path — that defeats version switching). On first run per project
ruby-lsp creates `.ruby-lsp/` with a composed Gemfile merging the server with project deps,
then re-execs as BUNDLE_GEMFILE=.ruby-lsp/Gemfile bundle exec ruby-lsp. Full access to project
gems WITHOUT polluting the shared Gemfile. Add `.ruby-lsp/` to global gitignore.
CRITICAL: lspconfig's ruby_lsp entry sets cmd_cwd = root_dir. The shim only picks the right
Ruby if the process STARTS in the project dir. lspconfig does this for you => don't override cmd.

sorbet: only if the work codebase already uses it (sorbet/ dir, `# typed:` sigils). All-in.
standardrb: rubocop preset; its GH *releases* are stale (2023) but commits current — judge by gem.

## MASON  [decision: drop mason-lspconfig + mason-tool-installer; mason.nvim optional]
mason.nvim: last commit 2026-06-19 (~3mo), v2.3.1, 28 commits/12mo, 277 open issues. Stagnating.
mason-lspconfig README concedes: "Since the introduction of :h vim.lsp.config in Neovim 0.11,
this plugin's feature set has been reduced."
Against reproducibility: fetches prebuilt binaries from npm/PyPI/GH releases/rubygems (broad,
heterogeneous supply chain + link rot); state is UNTRACKED (~/.local/share/nvim/mason not in
dotfiles => new machine is a coin flip); Neovim-only (can't use the tools from shell/tmux/git
hooks/CI => you install ruff twice); actively harmful for Ruby (ABI).
SYSTEM-MANAGER APPROACH (user already has all of it):
    uv tool install ruff            # also gives shell + CI the same binary; pin: ruff==0.16.6
    uv tool install pyright         # NOTE: PyPI pyright is a wrapper that downloads Node at runtime
       -> alternatives: brew install pyright (uses brew node), or uv tool install basedpyright
          (pure PyPI, NO Node). Real differentiator that's easy to miss.
    rbenv shell 3.3.9 && gem install ruby-lsp
    brew install lua-language-server stylua
[verified: mason's pyright IS a node script (#!/usr/bin/env node); user has node v26.4.0]
MIDDLE GROUND: keep mason.nvim for ad-hoc experimentation, drop mason-lspconfig +
mason-tool-installer, let daily drivers come from uv/brew/gem.

## FORMATTING: drop conform (for THIS stack)
0.12 sets 'formatexpr' = vim.lsp.formatexpr() => `gq` already formats via LSP, zero config.
ruff format arrives via ruff server; rubocop via ruby-lsp formatter="auto". Neither needs conform.
conform adds: chaining, non-LSP CLI formatters, format-on-save w/ timeouts+filters,
stop_after_first fallbacks, injected-language formatting (code blocks in markdown). Not needed here.
ONE GAP: stylua. lua_ls has a formatter but if stylua's specific output is wanted -> conform or
a small autocmd. Decide deliberately.
Format-on-save w/o plugin: BufWritePre autocmd -> vim.lsp.buf.format({timeout_ms=2000})
Organize imports on save (ruff exposes source.organizeImports): code_action{context={only=
{"source.organizeImports"}}, apply=true} before format.

## LINTING: nothing needed
ruff server sends textDocument/publishDiagnostics for all lint rules + quick-fix code actions
(ruff.codeAction.fixViolation.enable default true) + source.fixAll.
ruby-lsp surfaces rubocop offenses as LSP diagnostics with autocorrect actions.
Both land in vim.diagnostic => ]d/[d work. nvim-lint is for tools with NO language server
(shellcheck, hadolint, yamllint). Add only if those are wanted.

## BOTTOM LINE
Python:  pyright (MIT, low churn) + ruff server   -> uv tool install
Ruby:    ruby-lsp via rbenv shim + project rubocop -> gem install per Ruby version
Lua:     lua_ls (+ stylua if wanted)               -> brew
Config:  vim.lsp.config() + vim.lsp.enable()       -> drop mason-lspconfig
Skip:    ty (beta), venv-selector, conform, nvim-lint, nvim-dap
Revisit: ty at 1.0; pyrefly once churn settles

## AGENT'S OWN CAVEATS (worth keeping)
- "will it work in 3 years" judgments are extrapolations from release cadence + governance,
  NOT guarantees. pyright's low churn is the best available proxy, not proof.
- The venv `before_init` hook was verified for config-merge correctness in 0.12.5 but NOT
  observed end-to-end against a live pyright session. Test before relying on it.

## RUBY 2.7 (work codebase) — RESOLVED. Modern ruby-lsp works.  [verified end-to-end]
User's work codebase is entirely Ruby 2.7 (migrating to 3 "soon"). rbenv.
Gemspec facts (verified from source):
  ruby-lsp   required_ruby_version >= 3.0
  solargraph required_ruby_version >= 3.1
  rubocop 1.90.0 (latest) still requires only >= 2.7.0  => RUBOCOP IS A NON-ISSUE, no pinning

### KEY INSIGHT: ruby-lsp does NOT have to run on the project's Ruby
exe/ruby-lsp + lib/ruby_lsp/setup_bundler.rb: when BUNDLE_GEMFILE is unset, ruby-lsp writes
.ruby-lsp/Gemfile containing `eval_gemfile(<project Gemfile>)` + its own gems, then re-execs
`bundle exec ruby-lsp` using **Gem.ruby — the interpreter that launched it**, NOT the project's.
=> Run ruby-lsp under 3.3.9 while ANALYZING a 2.7 codebase. Full modern features.
VERIFIED ON THIS MACHINE: ~/.rbenv/versions/3.3.9/bin/ruby-lsp --version => 0.26.11 (runs)

### THE ONE BLOCKER: a `ruby "2.7.x"` directive in the project Gemfile
eval_gemfile inherits it =>  "Your Ruby version is 3.3.9, but your Gemfile specified 2.7.5"
| project Gemfile            | result |
| no `ruby` directive        | WORKS. composed bundle resolves under 3.3.9, indexes project gems |
| has `ruby "2.7.5"`         | FAILS |
Escape hatch: BUNDLE_GEMFILE=<standalone lsp Gemfile> bypasses composition. Still indexes
project SOURCE, but only LSP's own gems => lose completion for project dependencies.
** ACTION: check the work Gemfile for a `ruby` directive BEFORE committing to a mode. **
NOTE: this is derived from source + experiment, NOT documented. Shopify #1688 closed
"not planned"; the composed-bundle docs are silent on server-vs-project Ruby.

### Last 2.7-compatible versions (if ever needed — NOT recommended)
ruby-lsp 0.5.1 (2023-05-04; 0.6.0 moved to >=3.0). 3+ yrs stale, pre-Prism. No.
solargraph 0.52.0 (2025-02-28; 0.53.0 -> >=3.0, 0.59.0 -> >=3.1). Works but frozen/EOL branch.
  Caveat: `gem install solargraph -v 0.52.0` FAILS on 2.7.5 (transitive parallel needs >=3.3);
  via Bundler it backsolves OK.

### CONFIG (validated on both a 2.7 and a 3.3 project, unchanged)
lspconfig's ruby_lsp uses bare cmd={'ruby-lsp'} + cwd=root_dir => hits the rbenv shim, which
reads .ruby-version=2.7.5 and dies "rbenv: ruby-lsp: command not found". So override cmd:

vim.lsp.config('ruby_lsp', {
  cmd = function(dispatchers, config)
    local root = (config and config.root_dir) or vim.uv.cwd()
    local exe = 'ruby-lsp'                      -- shim: correct for Ruby 3.x projects
    local f = io.open(root .. '/.ruby-version')
    if f then
      local v = f:read('l'); f:close()
      local major = tonumber((v or ''):match('^(%d+)'))
      if major and major < 3 then
        exe = vim.fn.expand('~/.rbenv/versions/3.3.9/bin/ruby-lsp')  -- legacy project
      end
    end
    return vim.lsp.rpc.start({ exe }, dispatchers, { cwd = root })
  end,
  filetypes = { 'ruby', 'eruby' },
  root_markers = { 'Gemfile', '.git' },
  init_options = { formatter = 'auto' },
})
vim.lsp.enable('ruby_lsp')

Setup: RBENV_VERSION=3.3.9 gem install ruby-lsp   [DONE - 0.26.11 verified installed]
       add `.ruby-lsp/` to global gitignore
MIGRATION TO RUBY 3: **zero config changes**. The .ruby-version check falls through to the
plain shim. The legacy branch becomes dead code, deletable whenever.

### RuboCop fallback with NO plugin — nvim ships compiler/rubocop.vim  [verified]
$VIMRUNTIME/compiler/rubocop.vim:
   CompilerSet makeprg=rubocop\ --format\ emacs
   CompilerSet errorformat=%f:%l:%c:\ %t:\ %m,%-G%.%#
Usage: :compiler rubocop  (set makeprg to 'bundle exec rubocop --format emacs') then :make % / :copen
=> straight to quickfix, works with our ]q/[q bindings. Zero plugins.
(also bundled: compiler/ruby.vim, eruby.vim, rubyunit.vim)

### CAVEATS TO WATCH
1. Composed-bundle mode installs project gems a SECOND time under vendor/bundle/ruby/3.3.0/.
   Disk cost; gems that can't build on 3.3 break composition. (nokogiri 1.13.10 + json 2.3.1
   rebuilt fine in test, but the real work Gemfile is larger — main risk.)
2. 2.7-only edge-case syntax may mis-parse (ruby-lsp uses Prism at a modern level). Untested at scale.
3. RUN THIS IN THE WORK REPO BEFORE COMMITTING:
     ~/.rbenv/versions/3.3.9/bin/ruby-lsp --doctor

## FORMATTING — clarified (I mis-stated this earlier)
"ruff/rubocop VS LSP formatting" is a FALSE CHOICE. The LSP is the transport; ruff/rubocop are
what sits behind it.
  Python: ruff server  -> formatter is `ruff format` (Black-compatible)
  Ruby:   ruby-lsp     -> formatter is the PROJECT'S rubocop (init_options.formatter='auto')
  Lua:    lua_ls       -> its own formatter (stylua only if its specific style is wanted)
0.12 sets 'formatexpr' => `gq` formats via LSP with zero config; vim.lsp.buf.format() for buffer.
Value for THIS user: ruby-lsp shells into the PROJECT'S rubocop reading the project's
.rubocop.yml => editor and CI apply identical rules. Given "loose work agreements", this means
applying whatever the repo says rather than imposing personal preference.
RECOMMENDATION: do NOT enable format-on-save initially. Use gq / <leader>= manually so you never
reformat a file the team hasn't agreed to reformat. Enabling later = one autocmd.

## LUA — one plugin, justified
lazydev.nvim: teaches lua_ls the nvim API + plugin types. Without it lua_ls flags `vim` as
undefined and gives no nvim API completion. Small, one job, no built-in equivalent.
Zero-plugin fallback: a .luarc.json in the config dir (manual, won't know plugin types).
stylua: optional; lua_ls formats. Only if its specific style is wanted.

## MASON — decision firmed to DROP ENTIRELY (removing my earlier hedge)
The "keep for ad-hoc experimentation" middle ground doesn't survive the criteria:
second untracked toolchain, runtime binary downloads, nvim-only (=> ruff installed twice),
harmful for Ruby. Trying a new server = `uv tool install X` / `brew install X`, one command,
and you get it in the shell too. Strictly better than mason.

## RUBY 2.7 — RESOLVED AGAINST THE REAL WORK REPO  [all verified 2026-09-10]
Repo: ~/Projects/hatchet/sideqik/monorepo/sideqik
- Gemfile line 9: `ruby '2.7.5'`  => THE BLOCKED CASE. Composed bundle CANNOT work.
  --doctor output: "Your Ruby version is 3.3.9, but your Gemfile specified 2.7.5" (x4), then
  "rbenv: ruby-lsp: command not found" (2.7.5 has no ruby-lsp gem).
- Project HAS rubocop + rubocop-performance + rubocop-rails in a :rubocop group, and a .rubocop.yml
- BUNDLED WITH 2.4.22
- ruby-lsp gems by version: 2.7.4 => 0.5.1 (stale), 2.7.5 => none, 3.2.9 => 0.26.1, 3.3.9 => 0.26.11
- The 2.7.5 project bundle IS fully installed ("The Gemfile's dependencies are satisfied")
  and `RBENV_VERSION=2.7.5 bundle exec rubocop --version` => **1.28.2** works natively.

### THE ESCAPE HATCH WORKS — TESTED ON THE REAL REPO
  cd <work repo>
  BUNDLE_GEMFILE=<standalone>/Gemfile ~/.rbenv/versions/3.3.9/bin/ruby-lsp --doctor
Standalone Gemfile = just `source "https://rubygems.org"; gem "ruby-lsp"` + bundle install (exit 0).
RESULT: **4562 files indexed, 2941 of them the project's OWN source.**
=> go-to-definition / references / completion / symbols across YOUR code all work.
=> LOST: completion for GEM APIs (Rails methods etc.) — only ruby-lsp's own gems are in the bundle.
That's the honest tradeoff, and it's a good one: the 80% (your own code) works.

### RUBOCOP: keep it on 2.7, reach it via quickfix (NOT via ruby-lsp)
ruby-lsp running on 3.3.9 CANNOT shell into the project's 2.7 rubocop, so
init_options.formatter='auto' will NOT give rubocop formatting on this project.
BUT rubocop 1.28.2 runs fine natively under 2.7.5 via bundle exec.
=> Use nvim's BUILT-IN compiler/rubocop.vim (verified present):
     makeprg=rubocop --format emacs ; errorformat=%f:%l:%c: %t: %m,%-G%.%#
   with makeprg overridden to `bundle exec rubocop --format emacs`
   :make % -> :copen  => lands in quickfix, works with our ]q/[q bindings. ZERO plugins.
Tested: `RBENV_VERSION=2.7.5 bundle exec rubocop --format emacs app/api/.../api_form_fields.rb`
runs clean (no offenses on that file) — pipeline confirmed.
On Ruby 3.x projects, formatter='auto' will work normally and this fallback is just a bonus.

### CONFIG IMPLICATION
For <3 projects: cmd = { <3.3.9 ruby-lsp> } AND env BUNDLE_GEMFILE=<standalone Gemfile>
For >=3 projects: cmd = { 'ruby-lsp' } (rbenv shim), no BUNDLE_GEMFILE => composed bundle,
                  full gem completion + rubocop via formatter='auto'
Same config handles both; branch on .ruby-version major. Zero changes at migration time.
Standalone Gemfile should live in the dotfiles repo (e.g. dot_config/nvim/ruby-lsp/Gemfile)
so it's reproducible; its Gemfile.lock too.
Also: add `.ruby-lsp/` to ~/.gitignore_global (tracked at config/home/gitignore_global).
NOTE `**/vendor/bundle/` is ALREADY ignored there — covers the composed bundle's gem dir.
