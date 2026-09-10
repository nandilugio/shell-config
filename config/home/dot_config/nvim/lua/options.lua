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
--
-- Sources come from 'complete', in order. "o" is the one that matters: it means
-- 'omnifunc', which the LSP client sets on attach, so the menu reaches the
-- language server. Without it you get buffer words and nothing else.
--
-- The menu appears on a pause rather than on every keystroke — 'autocompletedelay'
-- is set a little above typing speed, which is what the option is for. Helix
-- does the same thing by default. To summon it sooner, <C-n> completes from all
-- sources and <C-x><C-o> asks the server alone.
--
-- Under 'autocomplete' most of 'completeopt' is ignored: the docs say only
-- fuzzy, longest, popup, preinsert and preview still apply, and "noselect" is
-- turned on regardless. So there are two flags worth setting, not five.
-- Note fuzzy and preinsert are mutually exclusive; fuzzy matching wins here.
vim.o.autocomplete = true
vim.o.autocompletedelay = 250
vim.o.complete = ".,w,b,u,o"
vim.o.completeopt = "popup,fuzzy"

-- <CR> accepts only once something is actually selected. The menu opens with
-- nothing highlighted, so typing straight through it and pressing Enter still
-- gives a newline: the popup never changes what ordinary typing does. Press
-- <C-n> first and Enter accepts, which is the state where you are choosing
-- from the list rather than writing.
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

-- Command-line completion, arranged to match insert mode: the menu appears as
-- you type, <C-n>/<C-p> move through it, <C-y> accepts and <C-e> dismisses.
-- Those last three are already built in here — only the auto-showing needs
-- setting up, which is what wildtrigger() is for. See :h cmdline-autocompletion.
--
-- "noselect" keeps <CR> executing the command rather than accepting whatever
-- happens to be highlighted. "tagfile" is part of the default and kept.
vim.o.wildmode = "noselect:lastused,full"
vim.o.wildoptions = "pum,fuzzy,tagfile"

vim.api.nvim_create_autocmd("CmdlineChanged", {
  pattern = { ":", "/", "?" },
  callback = function() vim.fn.wildtrigger() end,
})

-- With the menu open <Up>/<Down> would walk it; keep them on history instead
-- and leave the menu to <C-n>/<C-p> and <Tab>.
for _, key in ipairs({ "<Up>", "<Down>" }) do
  vim.keymap.set("c", key, function()
    return vim.fn.wildmenumode() == 1 and ("<C-E>" .. key) or key
  end, { expr = true, desc = "Command history" })
end

-- Recursive 'path' so :find works as a fallback where fzf is absent.
vim.o.path = vim.o.path .. ",**"
vim.o.wildmenu = true

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
