-- Everything this config loads, and when.
--
-- vim.pack is built into 0.12: nothing to install, and nvim-pack-lock.json
-- pins exact revisions. No lazy-loading, which at this size costs nothing and
-- buys the plain function calls the conditionals below depend on.

local function have(exe) return vim.fn.executable(exe) == 1 end

local function gh(repo) return "https://github.com/" .. repo end

local specs = {
  -- Server configurations only, never require()d: Neovim reads lsp/ from the
  -- runtimepath and setup/lsp.lua enables servers by name.
  gh("neovim/nvim-lspconfig"),

  -- Shows pending keys after <leader>, while the scheme is being learned.
  gh("folke/which-key.nvim"),

  -- File browser as an editable buffer. Pure Lua.
  gh("nvim-mini/mini.files"),

  -- Teaches lua_ls the Neovim API. Only useful for editing this config.
  gh("folke/lazydev.nvim"),

  -- Notes.
  gh("vimwiki/vimwiki"),
}

-- Parsers must be compiled, so this needs a toolchain.
if have("cc") or have("gcc") or have("clang") then
  table.insert(specs, { src = gh("nvim-treesitter/nvim-treesitter"), version = "main" })
end

-- Wraps the fzf binary. Without it, <leader>f* fall back to :find and :grep.
if have("fzf") then
  table.insert(specs, gh("ibhagwan/fzf-lua"))
end

-- Signs, hunk navigation and staging.
if have("git") then
  table.insert(specs, gh("lewis6991/gitsigns.nvim"))
end

vim.pack.add(specs)
