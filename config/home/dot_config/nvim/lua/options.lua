-- Options, and the few mappings and autocommands that belong to an option
-- rather than to the keymap scheme. Every other binding is in keymaps.lua.

-- Before any mapping: Vim captures the leader at definition time.
vim.g.mapleader = " "
vim.g.maplocalleader = ","

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
vim.o.showmode = false -- the statusline has a mode block
vim.o.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

-- Yanking is the one edit that leaves no trace in the buffer, so nothing else
-- confirms that `yap` took the paragraph you meant.
vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight yanked text",
  callback = function() vim.hl.on_yank() end,
})

-- Splits open where the eye expects them
vim.o.splitright = true
vim.o.splitbelow = true

-- Completion is native in 0.12, so no plugin.
--
-- Asked for, never volunteered: a menu that appears while you are still
-- thinking interrupts more than it helps. Off is also Vim's and Neovim's own
-- default. The trigger is Vim's: <C-n>/<C-p> walk 'complete', <C-x><C-o> asks
-- the language server alone — no mapping needed, and they work in any vi.
--
-- Costs nothing: autotrigger off only skips an InsertCharPre autocommand, so
-- snippets and auto-imports still arrive through those keys.
--
-- In 'complete', "o" is 'omnifunc', which the LSP client sets on attach —
-- without it the menu never reaches the server. "noselect" means the first
-- candidate is never inserted on your behalf.
vim.o.autocomplete = false
vim.o.complete = ".,w,b,u,o"
vim.o.completeopt = "menu,menuone,popup,noselect,fuzzy"

-- The cross-editor key, but many terminals never send it — it is the NUL byte,
-- which readline, some tmux configs and macOS input switching all eat. Nothing
-- depends on it working; <C-n> always arrives.
vim.keymap.set("i", "<C-Space>", "<C-n>", { desc = "Completion menu" })

-- Esc with the menu open would keep what is selected, turning a glance at the
-- list into an edit you did not ask for. <C-e> restores what you typed; a
-- second Esc leaves insert. With nothing selected, Esc behaves as it always has.
vim.keymap.set("i", "<Esc>", function()
  return vim.fn.complete_info({ "selected" }).selected ~= -1 and "<C-e>" or "<Esc>"
end, { expr = true, desc = "Dismiss completion, else leave insert mode" })

-- Accepts only once something is selected, so the popup never changes what
-- ordinary typing does: Enter still gives a newline unless you moved to a
-- candidate. Every other editor accepts on Enter, so the habit stays portable.
-- <C-y> accepts regardless, <C-e> dismisses.
vim.keymap.set("i", "<CR>", function()
  return vim.fn.complete_info({ "selected" }).selected ~= -1 and "<C-y>" or "<CR>"
end, { expr = true, desc = "Accept selected completion, else newline" })

-- Folds via treesitter, all open on entry.
vim.o.foldmethod = "expr"
vim.o.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.o.foldlevel = 99

-- Same terms as insert mode, with <Tab> as the trigger (Vim's default, and
-- every shell's). Popup rather than a line of matches, and fuzzy, so :e cfg
-- finds config. "lastused" sorts buffers by recency. Once open, the keys are
-- insert mode's: <C-n>/<C-p>, <C-y>, <C-e>.
vim.o.wildmode = "full:lastused"
vim.o.wildoptions = "pum,fuzzy,tagfile"

-- Keep <Up>/<Down> on history; the menu is <C-n>/<C-p> and <Tab>.
for _, key in ipairs({ "<Up>", "<Down>" }) do
  vim.keymap.set("c", key, function()
    return vim.fn.wildmenumode() == 1 and ("<C-E>" .. key) or key
  end, { expr = true, desc = "Command history" })
end

-- Recursive 'path' so :find works as a fallback where fzf is absent.
vim.o.path = vim.o.path .. ",**"

-- Both fill the quickfix list, which ]q / [q navigate.
if vim.fn.executable("rg") == 1 then
  vim.o.grepprg = "rg --vimgrep --smart-case"
  vim.o.grepformat = "%f:%l:%c:%m"
end

-- Undo history is not persisted, on purpose.
-- vim.o.undofile = true

-- Bundled with Neovim: no plugin, no churn.
vim.cmd.colorscheme("default")
