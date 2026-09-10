# Neovim

A small configuration built on Neovim's own features, with keybindings chosen
to transfer to other editors. Around 1300 lines, 8 plugins, ~25ms startup.

## Principles

**Prefer the built-in.** Neovim 0.12 ships a plugin manager, a completion
engine, a statusline, colorschemes and an LSP client. Each one used here is a
plugin not installed, a lockfile entry not pinned, and an upgrade that cannot
break.

**Small, finished dependencies.** A plugin that has not changed in a year is
usually done, not abandoned. Preferred over a larger one that changes weekly,
even when the larger one is more popular.

**Every external tool is optional.** Clone this onto a bare server and it
works: bindings fall back to built-ins, and `:checkhealth config` says what is
missing and what that costs. Nothing has to be installed for the editor to be
usable.

**Bindings should transfer.** Muscle memory is expensive to build, so it is
spent on keys that also work in Helix, Zed, VS Code and RubyMine — not on keys
that only work here.

## Keys

The whole scheme is one sentence:

> `g` jumps · `gr` acts on symbols · `<leader>` opens tools · `[`/`]` iterate
> lists · `<C-w>` windows · function keys bridge other editors

### Why these keys

**`gd` `gD` `gy` `gI` for navigation.** Neovim 0.12 provides `gri` and `grt`
for two of these, but `gd`/`gy`/`gI` is what Helix, LazyVim, AstroNvim and Zed
use, and IdeaVim ships `gd` natively. Vim's own `gd` already meant "goto local
declaration", so the LSP version deepens an existing meaning rather than
replacing one.

**`gr*` for actions, kept exactly as Neovim defines it.** `grn` rename, `gra`
code action, `grr` references, `grx` codelens. The prefix has no mnemonic — it
won by elimination when `cr` and `gl` were rejected — but the suffixes are
plain, and these work in any stock Neovim you SSH into. They are relabelled
here, not remapped: core describes them as `vim.lsp.buf.rename()`, which is
accurate and unreadable.

**`[` and `]` follow tpope's rule**, which Neovim 0.12 adopted into core:
*"`[` always comes before `]`"*. Lowercase steps, uppercase jumps to the first
or last. `]d` diagnostics, `]q` quickfix, `]c` changes, `]f` functions.

**`<leader>` is namespaced by domain, not by plugin**: `<leader>g` is git
whether gitsigns or something else provides it. Plugin-keyed namespaces break
when the plugin is replaced.

**Function keys, because Vim leaves them free.** Only `<F1>` is taken, and
`F2` rename / `F12` definition / `Shift-F12` references are the one layer that
survives the macOS-vs-Windows modifier split unchanged.

**`<leader>o` is reserved.** Nothing from any convention may claim it, so
personal bindings never collide with a future default. Borrowed from Spacemacs,
which is also where `<Space>` as leader comes from — chosen there for the
thumb, to avoid modifier strain.

`<leader>oh` shows the cheatsheet in a float. `:checkhealth config` reports
conflicts and missing tools; `:KeymapAudit` explains a conflict in detail.

## Plugins

Eight, each doing one thing:

| | |
|---|---|
| `nvim-lspconfig` | server definitions only, never `require`d |
| `nvim-treesitter` | compiles parsers; Neovim does the parsing |
| `gitsigns` | hunk signs, navigation, staging |
| `fzf-lua` | wraps the `fzf` binary; no build step, no dependencies |
| `mini.files` | file browser as an editable buffer |
| `lazydev` | teaches `lua_ls` the Neovim API |
| `which-key` | shows what a prefix contains |
| `vimwiki` | notes |

### Not installed, and why

**No plugin manager.** `vim.pack` is built in and writes a committed lockfile.
It has no lazy-loading, which costs nothing at this size — startup is faster
than the previous 24-plugin lazy-loaded config.

**No completion plugin.** `'autocomplete'` with `completeopt=fuzzy` plus
`vim.lsp.completion` gives autotrigger, fuzzy matching, snippets and
auto-imports. `<C-y>` accepts, as it has since Vim.

**No `mason`.** It installs a second, untracked, editor-only copy of tools the
system already manages, and Shopify warns against using it for `ruby-lsp` at
all. Servers come from `uv`, `brew` and `gem`, so the shell and CI use the same
binary.

**No statusline or colorscheme plugin.** The bundled colorscheme is used as
is. The default statusline already shows LSP progress, diagnostic counts and
a busy spinner; `setup/statusline.lua` appends the git branch and filetype,
colouring them from groups the colorscheme already defines so they follow it
when it changes.

**No `netrw`.** Deprecated upstream, and 0.12 still carries an unpatched path
that executes code from `.netrwhist`. Disabled; `mini.files` replaces it.

**No formatter or linter plugin.** `gq` formats through the LSP because 0.12
sets `'formatexpr'`. Ruff and RuboCop already publish diagnostics.

## Layout

```
init.lua              load order
lua/options.lua       editor behaviour
lua/plugins.lua       what loads, and when
lua/keymaps.lua       every binding, as data
lua/setup/*.lua       per-feature configuration
lua/config/health.lua :checkhealth config
cheatsheet.md         key reference, shown by <leader>oh
```

Three questions, three answers: *what are my keys* is `keymaps.lua`, *what am I
running* is `plugins.lua`, *how does it behave* is `options.lua` plus `setup/`.

Keymaps are **data, not calls**. Each entry carries an optional `needs` and
`fallback`:

```lua
{ "<leader>ff", function() require("setup.fzf").files() end,
  desc = "Files", needs = "fzf", fallback = ":find " },
```

One loop in `setup/keymaps.lua` applies them, substituting the fallback when a
requirement is absent and reporting anything it had to skip. That is what makes
the config portable, and it keeps every binding in one readable file.

## Language support

| | server | installed with |
|---|---|---|
| Python | `basedpyright` + `ruff` | `uv tool install` |
| Ruby | `ruby-lsp` | `gem install`, per Ruby version |
| Lua | `lua_ls` + `lazydev` | `brew` |

`basedpyright` bundles its own Node, so projects pinning different Node
versions cannot disturb it. Virtualenvs are detected per project — `VIRTUAL_ENV`,
then `CONDA_PREFIX`, then `.venv` — with no plugin.

Ruby needs one trick. `ruby-lsp` requires Ruby ≥ 3.0 but does not have to *be*
the project's Ruby, so a 2.7 codebase is analysed by a modern server. Where the
Gemfile pins `ruby "2.7.x"`, Bundler refuses to compose a bundle, so
`ruby-lsp/Gemfile` here is used instead: the project's own code is indexed, its
gems are not. RuboCop still runs through `:make`, using the project's own gem
and `.rubocop.yml`, into the quickfix list. Ruby 3 projects need none of this
and the config needs no change when the migration happens.

## Setting up elsewhere

Clone and start Neovim; plugins install on first run. Then, for full function:

```sh
brew install fzf ripgrep fd lazygit tree-sitter-cli lua-language-server
uv tool install ruff
uv tool install basedpyright
RBENV_VERSION=3.3.9 gem install ruby-lsp
```

`:checkhealth config` reports what is present and what each gap costs.
