-- Fuzzy finding. fzf-lua wraps the fzf binary, so FZF_DEFAULT_OPTS and the
-- shell's config apply here too; without fzf, <leader>f* fall back to :find and
-- :grep.
--
-- Nothing needs it until a picker opens, so setup is deferred to first use —
-- simpler than adopting a plugin manager for one plugin.

local loaded = nil

local function load()
  if loaded ~= nil then return loaded end

  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then
    -- fzf is on PATH (keymaps.lua checked) but the plugin is missing: most
    -- likely a failed first install.
    vim.notify("fzf-lua is not installed; run :lua vim.pack.update()", vim.log.levels.WARN)
    loaded = false
    return false
  end

  fzf.setup({
    "default-title", -- match the terminal's idiom rather than inventing one
    winopts = {
      height = 0.85,
      width = 0.85,
      -- Square, like every other float here. The text inside stays fzf's own,
      -- coloured through its ANSI palette rather than Neovim groups.
      border = "single",
      preview = { layout = "flex", border = "single" },
    },
    -- Keys stay fzf's own, as in a shell. Nothing is overridden: a
    -- `keymap.fzf` table would REPLACE fzf-lua's default set, not extend it.
    files = {
      -- fd respects .gitignore; fzf's own walker is the fallback.
      fd_opts = "--color=never --type f --hidden --follow --exclude .git",
    },
  })

  -- vim.ui.select through the picker too, so code actions share the interface.
  fzf.register_ui_select()

  loaded = fzf
  return fzf
end

-- keymaps.lua indexes this module, so the first picker call loads the plugin.
return setmetatable({}, {
  __index = function(_, name)
    return function(...)
      local fzf = load()
      if fzf then return fzf[name](...) end
    end
  end,
})
