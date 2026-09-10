-- Everything this config loads, and the conditions under which it loads.
--
-- vim.pack is built into Neovim 0.12: no plugin manager to install, and the
-- lockfile (nvim-pack-lock.json, next to this config) pins exact revisions and
-- belongs in version control.
--
-- vim.pack has no lazy-loading. With this few plugins the cost is invisible,
-- and in exchange loading is a plain function call — which is what makes the
-- conditionals below possible.

local function have(exe) return vim.fn.executable(exe) == 1 end

local function gh(repo) return "https://github.com/" .. repo end

local specs = {
  -- Server configurations only. Never require()d: Neovim reads the lsp/
  -- directory from the runtimepath, and setup/lsp.lua enables servers by name.
  gh("neovim/nvim-lspconfig"),

  -- Shows pending keys after <leader>. Kept while the new scheme is being learned.
  gh("folke/which-key.nvim"),

  -- File browser as an editable buffer. Replaces netrw, which is deprecated
  -- and unpatched. Pure Lua, no external dependencies.
  gh("nvim-mini/mini.files"),

  -- Teaches lua_ls the Neovim API and plugin types. Only useful for editing
  -- this config, which is reason enough to keep it.
  gh("folke/lazydev.nvim"),

  -- Notes.
  gh("vimwiki/vimwiki"),
}

-- Parsers must be compiled, so treesitter needs a toolchain. Without it Neovim
-- falls back to regex syntax highlighting, which is not nothing.
if have("cc") or have("gcc") or have("clang") then
  table.insert(specs, { src = gh("nvim-treesitter/nvim-treesitter"), version = "main" })
end

-- Wraps the fzf binary rather than reimplementing it, so it is only useful
-- where fzf exists. Without it, <leader>f* fall back to :find and :grep.
if have("fzf") then
  table.insert(specs, gh("ibhagwan/fzf-lua"))
end

-- Signs, hunk navigation and staging. Pointless outside a git working tree.
if have("git") then
  table.insert(specs, gh("lewis6991/gitsigns.nvim"))
end

vim.pack.add(specs)
