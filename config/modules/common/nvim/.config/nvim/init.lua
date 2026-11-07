-- Entry point.
--
--   options.lua   editor behaviour
--   plugins.lua   what gets loaded, and when
--   keymaps.lua   every binding, as data
--   setup/*.lua   per-feature configuration
--   mdtable/      local plugin: markdown table alignment
--   mdheading/    local plugin: markdown heading colours
--   config/health.lua  :checkhealth config
--
-- Order matters: vim.pack has no lazy-loading, so plugins must be on the
-- runtimepath before anything configures them; keymaps come last.

-- Built on 0.12: vim.pack, vim.lsp.config, 'winborder', 'autocomplete'. An
-- older Neovim would fail at the first of those with an error naming none of
-- this, so say it, and leave a bare editor rather than a broken one.
if vim.fn.has("nvim-0.12") == 0 then
  vim.notify(("This config needs Neovim 0.12 or later; this is %s. Nothing loaded."):format(vim.version()), vim.log.levels.ERROR)
  return
end

require("options")
require("plugins")

require("setup.autosave")
require("setup.diagnostics")
require("setup.statusline")
require("setup.winbar")
require("setup.lsp")
require("setup.treesitter")
require("setup.files")
require("setup.fzf") -- defines the loader only; the plugin is set up on first use
require("setup.git")
require("setup.help") -- the cheatsheet, and q in help windows
require("setup.review") -- for :Review; does nothing until asked
require("setup.wiki")

-- Local plugins, structured so they could move to their own repos unchanged —
-- hence the filetype list passed in rather than assumed. vimwiki is markdown to
-- treesitter but is written rather than read, and inline padding shifts the real
-- columns. mdheading takes the same list for consistency, though its colouring
-- would be harmless in notes.
require("mdtable").setup({ filetypes = { "markdown" } })
require("mdheading").setup({ filetypes = { "markdown" } })

require("setup.keymaps")

-- :help for this config's own features (doc/config.txt) and the cheatsheet
-- (doc/cheatsheet.txt). The tags file is generated, so not in git; rebuilt
-- only when a help file is newer.
local doc = vim.fn.stdpath("config") .. "/doc"
local tags = vim.fn.getftime(doc .. "/tags")
for _, f in ipairs(vim.fn.glob(doc .. "/*.txt", true, true)) do
  if vim.fn.getftime(f) > tags then
    vim.cmd.helptags(vim.fn.fnameescape(doc))
    break
  end
end
