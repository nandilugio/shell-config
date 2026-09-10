-- Editor behaviour. No plugins, no keymaps.

-- Leaders must be set before any mapping is defined: Vim captures the value at
-- definition time, so changing them later would not affect existing maps.
vim.g.mapleader = " "
vim.g.maplocalleader = ","

vim.g.have_nerd_font = true

-- netrw is deprecated, unmaintained, and ships a code-execution path via
-- .netrwhist (GHSA-crm5-rh6j-2c7c, unpatched in 0.12.5). mini.files replaces it.
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Timing
vim.o.updatetime = 250
vim.o.timeoutlen = 300

-- Search
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.inccommand = "split" -- live preview for :s

-- Editing
vim.o.clipboard = "unnamedplus"
vim.o.mouse = "a"
vim.o.confirm = true -- ask instead of failing on unsaved changes
vim.o.virtualedit = "block"
vim.o.expandtab = true
vim.o.shiftwidth = 2
vim.o.softtabstop = 2
vim.o.tabstop = 2
vim.o.fixendofline = false -- do not silently add a trailing newline

-- Appearance
vim.o.number = true
vim.o.scrolloff = 10
vim.o.signcolumn = "yes"
vim.o.cursorline = true
vim.o.breakindent = true
vim.o.showmode = true -- nothing else reports the mode
vim.o.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

-- Splits open where the eye expects them
vim.o.splitright = true
vim.o.splitbelow = true

-- Completion: Neovim 0.12 does this natively, so no completion plugin.
-- `autocomplete` triggers the menu as you type; sources come from 'complete'.
-- `fuzzy` gives fzf-style matching; `popup` shows documentation alongside.
-- LSP candidates are added per-buffer in setup/lsp.lua, and <C-y> applies side
-- effects (snippet expansion, auto-imports) — the standard Vim accept key.
vim.o.autocomplete = true
vim.o.complete = ".,w,b,u"
vim.o.completeopt = "menu,menuone,popup,noselect,fuzzy"

-- Folds via treesitter, all open on entry.
vim.o.foldmethod = "expr"
vim.o.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.o.foldlevel = 99

-- For the no-fzf fallback: keymaps.lua falls back to :find and :grep, which
-- are close to useless without a recursive 'path' and fuzzy wildmenu.
vim.o.path = vim.o.path .. ",**"
vim.o.wildmenu = true
vim.o.wildoptions = "pum,fuzzy"

-- Prefer ripgrep for :grep when present; both fill the quickfix list, which
-- ]q / [q navigate.
if vim.fn.executable("rg") == 1 then
  vim.o.grepprg = "rg --vimgrep --smart-case"
  vim.o.grepformat = "%f:%l:%c:%m"
end

-- Undo history is deliberately not persisted.
-- vim.o.undofile = true

-- Bundled with Neovim: no plugin, no churn.
vim.cmd.colorscheme("default")
