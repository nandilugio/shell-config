-- Entry point.
--
--   options.lua   editor behaviour
--   plugins.lua   what gets loaded, and when
--   keymaps.lua   every binding, as data
--   setup/*.lua   per-feature configuration
--   mdtable/      local plugin: markdown table alignment
--   config/health.lua  :checkhealth config
--
-- Order matters: vim.pack has no lazy-loading, so plugins must be on the
-- runtimepath before anything configures them, and keymaps come last so
-- everything they reference exists.

require("options")
require("plugins")

-- setup.fzf is absent by design: it is a lazy wrapper keymaps.lua pulls in on
-- first use, so requiring it here would defeat the point.
require("setup.autosave")
require("setup.cheatsheet")
require("setup.diagnostics")
require("setup.statusline")
require("setup.winbar")
require("setup.lsp")
require("setup.treesitter")
require("setup.files")
require("setup.git")
require("setup.wiki")

-- Local plugin. Structured as one so it can move to its own repo unchanged,
-- which is why the filetype list is passed in rather than assumed: vimwiki is
-- markdown to treesitter but is written rather than read, and inline padding
-- shifts the real columns.
require("mdtable").setup({ filetypes = { "markdown" } })

require("setup.keymaps")
