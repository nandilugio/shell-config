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

  -- Notes.
  gh("vimwiki/vimwiki"),
}

-- Parsers must be compiled, so this needs a toolchain.
if have("cc") or have("gcc") or have("clang") then
  table.insert(specs, { src = gh("nvim-treesitter/nvim-treesitter"), version = "main" })
  -- Each revision of the plugin pins the parsers it was tested with, so an
  -- update of one means a rebuild of the others (its README: "you must make
  -- sure that all installed parsers are updated"). setup/treesitter.lua only
  -- installs what is missing.
  vim.api.nvim_create_autocmd("PackChanged", {
    callback = function(ev)
      if ev.data.kind == "update" and ev.data.spec.name == "nvim-treesitter" then
        require("nvim-treesitter").update()
      end
    end,
  })
end

-- Wraps the fzf binary. Without it, <leader>f* fall back to :find and :grep.
if have("fzf") then
  table.insert(specs, gh("ibhagwan/fzf-lua"))
end

-- Signs, hunk navigation and staging.
if have("git") then
  table.insert(specs, gh("lewis6991/gitsigns.nvim"))
end

-- An update can move what this config touches in a plugin; :checkhealth
-- config lists that surface and says what is gone. Once per update run.
local reminded = false
vim.api.nvim_create_autocmd("PackChanged", {
  callback = function(ev)
    if ev.data.kind ~= "update" or reminded then return end
    reminded = true
    vim.schedule(function()
      vim.notify("Plugins updated: :checkhealth config says whether they still fit; the tests are in the README")
    end)
  end,
})

vim.pack.add(specs)
