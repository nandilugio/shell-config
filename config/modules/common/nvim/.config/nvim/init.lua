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

require("options")
require("plugins")

-- setup.fzf is absent by design: keymaps.lua pulls it in on first use.
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

-- Local plugins, structured so they could move to their own repos unchanged —
-- hence the filetype list passed in rather than assumed. vimwiki is markdown to
-- treesitter but is written rather than read, and inline padding shifts the real
-- columns. mdheading takes the same list for consistency, though its colouring
-- would be harmless in notes.
require("mdtable").setup({ filetypes = { "markdown" } })
require("mdheading").setup({ filetypes = { "markdown" } })

require("setup.keymaps")
