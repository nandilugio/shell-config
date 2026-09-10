-- Fuzzy finding, driven by the fzf binary.
--
-- fzf-lua wraps fzf rather than reimplementing it, so it inherits
-- FZF_DEFAULT_OPTS and the shell's configuration applies here too. Where fzf
-- is absent the plugin is never installed and <leader>f* fall back to :find
-- and :grep.
--
-- Loading costs ~10ms and nothing needs it until a picker opens, so setup is
-- deferred to first use. vim.pack has no lazy-loading; for one plugin this is
-- simpler than adopting a manager that does.

local loaded = nil

local function load()
  if loaded ~= nil then return loaded end

  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then
    -- fzf is on PATH (keymaps.lua checked) but the plugin is missing, most
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
      -- Square, like every other float here. fzf still colours its own text
      -- through the fzf binary's ANSI palette rather than Neovim highlight
      -- groups, so the picker stays visually its own thing inside the frame.
      border = "single",
      preview = { layout = "flex", border = "single" },
    },
    -- Keys are fzf's own, so this behaves like the fzf already used in a
    -- shell: <C-j>/<C-k> move, <Enter> opens, <C-u> clears the query.
    -- Nothing is overridden — passing a `keymap.fzf` table would replace
    -- fzf-lua's whole default set rather than adding to it.
    files = {
      -- fd respects .gitignore; fzf's own walker is the fallback.
      fd_opts = "--color=never --type f --hidden --follow --exclude .git",
    },
  })

  -- Send vim.ui.select through the picker too, so LSP code actions and similar
  -- prompts share one interface.
  fzf.register_ui_select()

  loaded = fzf
  return fzf
end

-- keymaps.lua indexes this module, so the first picker call loads the plugin
-- and then runs the requested command.
return setmetatable({}, {
  __index = function(_, name)
    return function(...)
      local fzf = load()
      if fzf then return fzf[name](...) end
    end
  end,
})
