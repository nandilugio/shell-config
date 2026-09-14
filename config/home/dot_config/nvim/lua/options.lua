-- Editor behaviour. No plugins, no keymaps.

-- Leaders must be set before any mapping is defined: Vim captures the value at
-- definition time, so changing them later would not affect existing maps.
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

-- Splits open where the eye expects them
vim.o.splitright = true
vim.o.splitbelow = true

-- Completion: Neovim 0.12 does this natively, so no completion plugin.
--
-- Asked for, never volunteered. 'autocomplete' would show the menu on a pause,
-- but a menu that appears while you are still thinking interrupts more than it
-- helps. Off is also the default in both Vim and Neovim — the option arrived in
-- Vim 9.1.1590 and Neovim ported it, and neither turns it on.
--
-- The trigger is Vim's own: <C-n> and <C-p> walk the sources in 'complete',
-- and <C-x><C-o> asks the language server alone. They need no mapping and
-- work in any vi you sit down at.
--
-- Turning autotrigger off costs nothing else: vim.lsp.completion.enable() only
-- skips an InsertCharPre autocommand, so the language server, its snippets and
-- its auto-imports all still arrive through the keys above.
--
-- Sources come from 'complete', in order. "o" means 'omnifunc', which the LSP
-- client sets on attach — without it the menu never reaches the language
-- server. "noselect" opens the menu with nothing highlighted, so the first
-- candidate is never inserted on your behalf.
vim.o.autocomplete = false
vim.o.complete = ".,w,b,u,o"
vim.o.completeopt = "menu,menuone,popup,noselect,fuzzy"

-- <C-Space> is the cross-editor key, but many terminals never send it: it is
-- the NUL byte, and emacs-style readline, some tmux configurations and macOS
-- input-source switching all eat it before Neovim sees it. <C-n> is the one
-- that always arrives, so nothing depends on this working.
vim.keymap.set("i", "<C-Space>", "<C-n>", { desc = "Completion menu" })

-- Esc with the menu open keeps whatever is selected, which turns a glance at
-- the list into an edit you did not ask for. Make it dismiss instead: <C-e>
-- restores what you actually typed, and a second Esc leaves insert mode.
-- With nothing selected the menu is only a suggestion, so Esc goes straight
-- out and insert mode ends in one press, as it always has.
vim.keymap.set("i", "<Esc>", function()
  return vim.fn.complete_info({ "selected" }).selected ~= -1 and "<C-e>" or "<Esc>"
end, { expr = true, desc = "Dismiss completion, else leave insert mode" })

-- <CR> accepts only once something is actually selected. The menu opens with
-- nothing highlighted, so pressing Enter with it open still gives a newline:
-- the popup never changes what ordinary typing does. Move to a candidate with
-- <C-n> and Enter accepts, which is the state where you are choosing from the
-- list rather than writing.
--
-- Every other editor accepts on Enter, so this keeps the habit portable.
-- <C-y> accepts regardless, and <C-e> dismisses without accepting.
vim.keymap.set("i", "<CR>", function()
  return vim.fn.complete_info({ "selected" }).selected ~= -1 and "<C-y>" or "<CR>"
end, { expr = true, desc = "Accept selected completion, else newline" })

-- Folds via treesitter, all open on entry.
vim.o.foldmethod = "expr"
vim.o.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.o.foldlevel = 99

-- Command-line completion, on the same terms as insert mode: asked for, not
-- volunteered. <Tab> is the trigger, which is both Vim's default and what
-- every shell does, so the habit is already yours. A popup menu rather than a
-- single line of matches, and fuzzy, so :e cfg finds config.
--
-- "lastused" sorts buffer names by recency. "tagfile" is part of the default
-- and kept. <C-n>/<C-p> walk the menu once it is open, <C-y> accepts and
-- <C-e> dismisses — the same keys as insert mode.
vim.o.wildmode = "full:lastused"
vim.o.wildoptions = "pum,fuzzy,tagfile"

-- With the menu open <Up>/<Down> would walk it; keep them on history instead
-- and leave the menu to <C-n>/<C-p> and <Tab>.
for _, key in ipairs({ "<Up>", "<Down>" }) do
  vim.keymap.set("c", key, function()
    return vim.fn.wildmenumode() == 1 and ("<C-E>" .. key) or key
  end, { expr = true, desc = "Command history" })
end

-- Recursive 'path' so :find works as a fallback where fzf is absent.
vim.o.path = vim.o.path .. ",**"

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
