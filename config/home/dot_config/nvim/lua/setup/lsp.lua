-- Language servers.
--
-- Neovim 0.12 has everything needed built in: vim.lsp.config() adjusts a
-- server, vim.lsp.enable() starts it when a matching file opens. nvim-lspconfig
-- is on the runtimepath purely so Neovim can read its lsp/ directory for the
-- stock definitions (cmd, filetypes, root markers) — it is never require()d,
-- and there is no framework, no on_attach plumbing, no mason.
--
-- Servers are installed with the system's own tools, so the same binary serves
-- the shell, CI and the editor, and nothing is pinned to a Neovim-only
-- install directory:
--     uv tool install ruff
--     uv tool install basedpyright
--     brew install lua-language-server
--     RBENV_VERSION=3.x gem install ruby-lsp   # any Ruby >= 3 rbenv manages

local M = {}

local function have(exe) return vim.fn.executable(exe) == 1 end

-- ── Python ──────────────────────────────────────────────────────────────────
-- pyright does not look for .venv on its own, which is the usual source of
-- phantom import errors. Resolve the interpreter per project instead. This runs
-- in before_init, where root_dir is already known, so two projects with
-- different virtualenvs both work in one session.
local function project_python(root)
  for _, dir in ipairs({ vim.env.VIRTUAL_ENV, vim.env.CONDA_PREFIX }) do
    if dir and vim.uv.fs_stat(dir .. "/bin/python") then
      return dir .. "/bin/python"
    end
  end
  for _, rel in ipairs({ "/.venv/bin/python", "/venv/bin/python" }) do
    if root and vim.uv.fs_stat(root .. rel) then
      return root .. rel
    end
  end
  return nil
end

-- basedpyright is a fork of pyright that ships its own Node inside the tool
-- venv, so it does not care which Node is on PATH. That matters when projects
-- pin different Node versions through nvm.
local pyright_settings = {
  before_init = function(_, config)
    local python = project_python(config.root_dir)
    if python then
      config.settings = vim.tbl_deep_extend("force", config.settings or {}, {
        python = { pythonPath = python },
      })
    end
  end,
  -- Nothing else to set: nvim-lspconfig already supplies cmd, filetypes, root
  -- markers and diagnosticMode = "openFilesOnly".
}

vim.lsp.config("basedpyright", pyright_settings)
vim.lsp.config("pyright", pyright_settings)

-- ruff runs alongside pyright by design: ruff lints and formats, pyright does
-- types. Both would offer hover, so ruff's is switched off below.
vim.lsp.config("ruff", {})

-- ── Ruby ────────────────────────────────────────────────────────────────────
-- ruby-lsp needs Ruby >= 3.0, but it does not have to be the project's Ruby: it
-- re-execs with whichever interpreter launched it. So a legacy 2.x project is
-- analysed by a modern server.
--
-- The catch is Bundler. Normally ruby-lsp composes a bundle from the project's
-- Gemfile, which fails when that Gemfile pins `ruby "2.7.x"`. Pointing
-- BUNDLE_GEMFILE at a standalone Gemfile skips composition: the project's own
-- source is still indexed (definitions, references, completion across your
-- code), but its gems are not, so gem APIs do not autocomplete.
--
-- Ruby 3 projects take the first branch and need nothing special. After the
-- migration the legacy branch is simply dead code.

-- The newest Ruby >= 3 under rbenv that has ruby-lsp installed. Nothing is
-- pinned: install a newer Ruby, `gem install ruby-lsp` into it, and it is used.
-- Strict parsing so "jruby-9.x" is skipped rather than misread.
function M.modern_ruby_lsp()
  local best, best_v
  for _, path in ipairs(vim.fn.glob("~/.rbenv/versions/*/bin/ruby-lsp", true, true)) do
    local v = vim.version.parse(path:match("/versions/([^/]+)/") or "", { strict = true })
    if v and v.major >= 3 and (not best_v or vim.version.gt(v, best_v)) then
      best, best_v = path, v
    end
  end
  return best
end

local RUBY_LSP_MODERN = M.modern_ruby_lsp()
local RUBY_LSP_BUNDLE = vim.fn.stdpath("config") .. "/ruby-lsp/Gemfile"

local function project_ruby_major(root)
  local f = root and io.open(root .. "/.ruby-version")
  if not f then return nil end
  local line = f:read("l")
  f:close()
  return tonumber((line or ""):match("^(%d+)"))
end

-- An rbenv shim always exists as a file, so vim.fn.executable() says yes even
-- when rbenv cannot resolve it for this directory. Ask rbenv instead.
local function shim_resolves(root)
  if vim.fn.executable("rbenv") == 0 then
    return vim.fn.executable("ruby-lsp") == 1
  end
  local out = vim.system({ "rbenv", "which", "ruby-lsp" }, { cwd = root, text = true }):wait()
  return out.code == 0
end

vim.lsp.config("ruby_lsp", {
  cmd = function(dispatchers, config)
    local root = (config and config.root_dir) or vim.uv.cwd()
    local major = project_ruby_major(root)
    local env = nil
    local exe = "ruby-lsp" -- the rbenv shim: right for Ruby 3.x projects

    if RUBY_LSP_MODERN then
      if major and major < 3 then
        -- Legacy project: run a modern server against it, and skip bundle
        -- composition, which bundler refuses when the Gemfile pins Ruby < 3.
        exe = RUBY_LSP_MODERN
        if vim.uv.fs_stat(RUBY_LSP_BUNDLE) then
          env = { BUNDLE_GEMFILE = RUBY_LSP_BUNDLE }
        end
      elseif major == nil and not shim_resolves(root) then
        -- No .ruby-version to steer the shim, and the shim resolves to nothing
        -- for this directory (rbenv global is commonly the system Ruby, which
        -- is too old). Use the known-good interpreter rather than not starting.
        exe = RUBY_LSP_MODERN
      end
    end

    return vim.lsp.rpc.start({ exe }, dispatchers, { cwd = root, env = env })
  end,
  init_options = {
    -- Uses the project's own rubocop and .rubocop.yml, so the editor and CI
    -- agree. Only reachable when the server shares the project's bundle, i.e.
    -- on Ruby 3.x; setup/git.lua's :make path covers the 2.x case.
    formatter = "auto",
  },
})

-- ── Lua ─────────────────────────────────────────────────────────────────────
-- lazydev supplies the Neovim API types, so no workspace library is needed.
-- The `vim` global still has to be declared here: lazydev types the module,
-- it does not stop lua_ls treating a bare `vim` as undefined.
vim.lsp.config("lua_ls", {
  settings = {
    Lua = {
      completion = { callSnippet = "Replace" },
      diagnostics = { globals = { "vim" } },
    },
  },
})

-- ── Enable whatever this machine can actually run ───────────────────────────
local servers = {}
-- basedpyright first: it bundles its own Node, so it is immune to whichever
-- version nvm has active. Only one type checker should run at a time.
if have("basedpyright") then
  table.insert(servers, "basedpyright")
elseif have("pyright") then
  table.insert(servers, "pyright")
end
if have("ruff") then table.insert(servers, "ruff") end
if have("lua-language-server") then table.insert(servers, "lua_ls") end
-- The rbenv shim always exists, so test a real interpreter instead.
if have("ruby-lsp") or RUBY_LSP_MODERN then table.insert(servers, "ruby_lsp") end

if #servers > 0 then
  vim.lsp.enable(servers)
end

-- Floating windows get a border. Without one the text runs straight into the
-- buffer behind it and reads as corruption; the border also gives the content
-- a column of breathing room on each side.
--
-- Square borders, matching the file browser and the cheatsheet. keymaps.lua
-- binds Esc to close these.
local float = { border = "single", max_width = 80 }

vim.lsp.buf.hover = (function(orig)
  return function(opts) return orig(vim.tbl_extend("force", float, opts or {})) end
end)(vim.lsp.buf.hover)

vim.lsp.buf.signature_help = (function(orig)
  return function(opts) return orig(vim.tbl_extend("force", float, opts or {})) end
end)(vim.lsp.buf.signature_help)

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if not client then return end

    -- Completion from the language server, feeding Neovim's own popup menu.
    -- <C-y> accepts and applies side effects: snippet expansion, auto-imports.
    if client:supports_method("textDocument/completion") then
      vim.lsp.completion.enable(true, client.id, args.buf, { autotrigger = true })
    end

    -- ruff and pyright both answer hover; pyright's is the useful one.
    if client.name == "ruff" then
      client.server_capabilities.hoverProvider = false
    end

    -- Folds from the language server where it offers them: it knows an import
    -- block or a region comment is one thing, which treesitter cannot see.
    -- Treesitter stays the default everywhere else (set in options.lua).
    if client:supports_method("textDocument/foldingRange") then
      for _, win in ipairs(vim.fn.win_findbuf(args.buf)) do
        vim.wo[win][0].foldexpr = "v:lua.vim.lsp.foldexpr()"
      end
    end

    -- Highlight other uses of the symbol under the cursor. The autocommands
    -- are buffer-local, so they die with the buffer and need no cleanup.
    if client:supports_method("textDocument/documentHighlight") then
      vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
        buffer = args.buf,
        callback = vim.lsp.buf.document_highlight,
      })
      vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
        buffer = args.buf,
        callback = vim.lsp.buf.clear_references,
      })
    end
  end,
})

return M
