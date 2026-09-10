-- Every keybinding, as data. Applied by setup/keymaps.lua after plugins load.
--
-- Entry shape:
--   { lhs, rhs, desc = "...", mode = "n"|{"n","x"}, needs = "...", fallback = rhs }
--
--   needs     what `rhs` depends on: a bare name is an executable on PATH,
--             "mod:x" a Lua module, "cmd:X" an Ex command.
--             When missing, `fallback` is used instead; with no fallback the
--             mapping is skipped entirely. This is what lets the config work on
--             a bare server with nothing installed.
--   fallback  a built-in that does the same job, less well.
--
-- Design rule:  g jumps · gr acts on symbols · <leader> opens tools
--               [ ] iterate lists · <C-w> windows · F-keys bridge other editors
-- Nvim 0.12 defaults we deliberately do NOT redefine (they are already right):
--   grn gra grr grx gO   K   ]d [d ]D [D   ]q [q ]Q [Q   ]b [b   ]<Space> [<Space>
--   gc gcc   <C-]> <C-t>   an in ]n [n

local M = {}

-- Documentation for key chains that are not mappings themselves.
--
-- These create nothing: they only give which-key a label for a prefix, so that
-- pressing <leader> shows "find / git / toggle" instead of a bare letter. The
-- same applies to Vim's own prefixes, which are worth labelling precisely
-- because nobody defined them here and they are easy to forget.
--
--   { lhs, label, mode? }
M.groups = {
  -- Leader namespaces
  { "<leader>f", "find" },
  { "<leader>g", "git", mode = { "n", "v" } },
  { "<leader>u", "toggle (ui)" },
  { "<leader>b", "buffer" },
  { "<leader>o", "own" }, -- reserved: no plugin or convention may claim it
  { "<leader>x", "lists" },

  -- Built-in prefixes. Not ours, but the popup is where you look when you
  -- have forgotten what lives under them.
  { "g", "goto / extended" },
  { "gr", "LSP actions" },
  { "z", "folds, scroll, spelling" },
  { "]", "next" },
  { "[", "previous" },
  { "<C-w>", "window" },
}

M.maps = {

  -- ── Jump: g + letter ────────────────────────────────────────────────────
  -- gd/gy/gI are the cross-editor convention (Helix, LazyVim, AstroNvim, Zed,
  -- and IdeaVim ships gd natively). Vim's own gd already meant "goto local
  -- declaration", so the LSP versions upgrade an existing meaning.
  -- No `needs`: with no LSP attached these error politely, same as core's gr*.
  { "gd", vim.lsp.buf.definition, desc = "Definition" },
  { "gD", vim.lsp.buf.declaration, desc = "Declaration" },
  { "gy", vim.lsp.buf.type_definition, desc = "Type definition" },
  { "gI", vim.lsp.buf.implementation, desc = "Implementation" },

  -- ── Iterate: [ and ] ────────────────────────────────────────────────────
  -- tpope's rule: "[ always comes before ]". Lowercase steps, capital jumps to
  -- the first/last. Core already provides ]d ]q ]b ]<Space> and friends.
  {
    "]e",
    function() vim.diagnostic.jump({ count = 1, severity = vim.diagnostic.severity.ERROR, float = true }) end,
    desc = "Next error",
  },
  {
    "[e",
    function() vim.diagnostic.jump({ count = -1, severity = vim.diagnostic.severity.ERROR, float = true }) end,
    desc = "Previous error",
  },
  {
    "]w",
    function() vim.diagnostic.jump({ count = 1, severity = vim.diagnostic.severity.WARN, float = true }) end,
    desc = "Next warning",
  },
  {
    "[w",
    function() vim.diagnostic.jump({ count = -1, severity = vim.diagnostic.severity.WARN, float = true }) end,
    desc = "Previous warning",
  },

  -- ── Find: <leader>f ─────────────────────────────────────────────────────
  -- Falls back to :find / :grep, which fill the quickfix list that ]q / [q
  -- already navigate. Same keys, less power.
  {
    "<leader><leader>",
    function() require("setup.fzf").buffers() end,
    desc = "Switch buffer",
    needs = "fzf",
    fallback = ":buffer ",
  },
  {
    "<leader>ff",
    function() require("setup.fzf").files() end,
    desc = "Files",
    needs = "fzf",
    fallback = ":find ",
  },
  {
    "<leader>fg",
    function() require("setup.fzf").live_grep() end,
    desc = "Grep",
    needs = "fzf",
    fallback = ":grep ",
  },
  {
    "<leader>fw",
    function() require("setup.fzf").grep_cword() end,
    desc = "Word under cursor",
    needs = "fzf",
    fallback = function() vim.cmd("grep " .. vim.fn.shellescape(vim.fn.expand("<cword>"))) end,
  },
  {
    "<leader>fr",
    function() require("setup.fzf").oldfiles() end,
    desc = "Recent files",
    needs = "fzf",
    fallback = ":browse oldfiles<CR>",
  },
  {
    "<leader>fb",
    function() require("setup.fzf").buffers() end,
    desc = "Buffers",
    needs = "fzf",
    fallback = ":ls<CR>:buffer ",
  },
  {
    "<leader>fh",
    function() require("setup.fzf").helptags() end,
    desc = "Help",
    needs = "fzf",
    fallback = ":help ",
  },
  {
    "<leader>fk",
    function() require("setup.fzf").keymaps() end,
    desc = "Keymaps",
    needs = "fzf",
    fallback = ":map<CR>",
  },
  {
    "<leader>fd",
    function() require("setup.fzf").diagnostics_document() end,
    desc = "Diagnostics",
    needs = "fzf",
    fallback = function() vim.diagnostic.setqflist() end,
  },
  {
    "<leader>fs",
    function() require("setup.fzf").lsp_document_symbols() end,
    desc = "Symbols",
    needs = "fzf",
    fallback = "gO",
  },
  {
    "<leader>fS",
    function() require("setup.fzf").lsp_live_workspace_symbols() end,
    desc = "Workspace symbols",
    needs = "fzf",
  },
  {
    "<leader>/",
    function() require("setup.fzf").live_grep() end,
    desc = "Grep project",
    needs = "fzf",
    fallback = ":grep ",
  },
  -- References through the picker when available; core's grr otherwise.
  {
    "<leader>fR",
    function() require("setup.fzf").lsp_references() end,
    desc = "References",
    needs = "fzf",
    fallback = "grr",
  },

  -- ── Git: <leader>g ──────────────────────────────────────────────────────
  -- Hunk-level only. Commits, rebases and branches live in lazygit in tmux.
  -- Without gitsigns these keep Vim's built-in meaning: next/previous change
  -- in diff mode. Same concept, narrower scope.
  { "]c", function() require("gitsigns").nav_hunk("next") end, desc = "Next hunk", needs = "mod:gitsigns", fallback = "]c" },
  { "[c", function() require("gitsigns").nav_hunk("prev") end, desc = "Previous hunk", needs = "mod:gitsigns", fallback = "[c" },
  {
    "<leader>gs",
    function() require("gitsigns").stage_hunk() end,
    desc = "Stage hunk",
    mode = { "n", "v" },
    needs = "mod:gitsigns",
  },
  {
    "<leader>gr",
    function() require("gitsigns").reset_hunk() end,
    desc = "Reset hunk",
    mode = { "n", "v" },
    needs = "mod:gitsigns",
  },
  { "<leader>gp", function() require("gitsigns").preview_hunk() end, desc = "Preview hunk", needs = "mod:gitsigns" },
  { "<leader>gb", function() require("gitsigns").blame_line({ full = true }) end, desc = "Blame line", needs = "mod:gitsigns" },
  { "<leader>gd", function() require("gitsigns").diffthis() end, desc = "Diff this", needs = "mod:gitsigns" },
  { "<leader>gg", "<Cmd>terminal lazygit<CR>", desc = "Lazygit", needs = "lazygit" },

  -- ── Toggle: <leader>u (ui) ──────────────────────────────────────────────
  -- Only the seven letters LazyVim and AstroNvim agree on.
  { "<leader>uw", "<Cmd>set wrap!<CR>", desc = "Wrap" },
  { "<leader>us", "<Cmd>set spell!<CR>", desc = "Spell" },
  { "<leader>ul", "<Cmd>set number!<CR>", desc = "Line numbers" },
  { "<leader>ur", "<Cmd>set relativenumber!<CR>", desc = "Relative numbers" },
  -- Steps through all / warnings and errors / errors only / off, rather than
  -- a plain on-off: a noisy file usually wants less, not none.
  { "<leader>ud", function() _G.CycleDiagnostics() end, desc = "Diagnostics shown (cycle)" },
  {
    "<leader>uh",
    function() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({})) end,
    desc = "Inlay hints",
  },
  {
    "<leader>ub",
    function() vim.o.background = vim.o.background == "dark" and "light" or "dark" end,
    desc = "Background",
  },

  -- ── Buffers and windows ─────────────────────────────────────────────────
  -- <C-hjkl> for windows deliberately mirrors tmux's M-hjkl for panes: two
  -- levels, two modifiers.
  { "<C-h>", "<C-w><C-h>", desc = "Window left" },
  { "<C-j>", "<C-w><C-j>", desc = "Window down" },
  { "<C-k>", "<C-w><C-k>", desc = "Window up" },
  { "<C-l>", "<C-w><C-l>", desc = "Window right" },
  -- Same mnemonic as tmux's split bindings: | is a vertical divider, - a horizontal one.
  { "<leader>-", "<Cmd>split<CR>", desc = "Split below" },
  { "<leader>|", "<Cmd>vsplit<CR>", desc = "Split right" },
  { "<S-h>", "<Cmd>bprevious<CR>", desc = "Previous buffer" },
  { "<S-l>", "<Cmd>bnext<CR>", desc = "Next buffer" },
  { "<leader>bd", "<Cmd>bdelete<CR>", desc = "Delete buffer" },

  -- ── Lists: <leader>x ────────────────────────────────────────────────────
  -- The quickfix list is Vim's list of places — :make, :grep and the pickers
  -- all fill it, and ]q / [q walk it. The location list is the same, scoped
  -- to one window.
  { "<leader>xq", "<Cmd>copen<CR>", desc = "Quickfix list" },
  { "<leader>xl", "<Cmd>lopen<CR>", desc = "Location list" },
  { "<leader>xd", vim.diagnostic.setqflist, desc = "Diagnostics to quickfix" },

  -- ── Files ───────────────────────────────────────────────────────────────
  {
    "<leader>e",
    function() require("mini.files").open(vim.api.nvim_buf_get_name(0)) end,
    desc = "File browser",
    needs = "mod:mini.files",
    fallback = "<Cmd>edit .<CR>",
  },

  -- ── Edit ────────────────────────────────────────────────────────────────
  -- = is Vim's own format operator, so <leader>= reads as "format everything".
  { "<leader>=", function() vim.lsp.buf.format({ timeout_ms = 2000 }) end, desc = "Format buffer", mode = { "n", "v" } },

  -- ── F-keys: the only layer that transfers unchanged to other editors ────
  -- Nvim binds only <F1>, so F2-F12 are free. These match VS Code, Visual
  -- Studio and Zed, and cost nothing here.
  { "<F2>", vim.lsp.buf.rename, desc = "Rename symbol" },
  { "<F12>", vim.lsp.buf.definition, desc = "Definition" },
  { "<S-F12>", vim.lsp.buf.references, desc = "References" },

  -- ── Own namespace: <leader>o ────────────────────────────────────────────
  -- Reserved. Nothing from any plugin or convention may claim these.
  {
    "<leader>ox",
    [[:%s/\s\+$//e<CR>:nohlsearch<CR>:echo "Cleared trailing whitespace"<CR>]],
    desc = "Clear trailing whitespace",
  },
  -- vimwiki's own <leader>w* mappings are disabled in setup/wiki.lua because
  -- they collide with the window namespace; these are the ones worth keeping.
  { "<leader>ow", "<Cmd>VimwikiIndex<CR>", desc = "Wiki index", needs = "cmd:VimwikiIndex" },
  { "<leader>od", "<Cmd>VimwikiMakeDiaryNote<CR>", desc = "Wiki diary today", needs = "cmd:VimwikiMakeDiaryNote" },
  { "<leader>oD", "<Cmd>VimwikiDiaryIndex<CR>", desc = "Wiki diary index", needs = "cmd:VimwikiDiaryIndex" },
  { "<leader>oh", function() require("setup.cheatsheet").open() end, desc = "Cheatsheet" },
  { "<leader>oa", function() require("setup.autosave").toggle() end, desc = "Autosave on/off" },

  -- ── Odds and ends ───────────────────────────────────────────────────────
  -- One key for "dismiss whatever is in the way": a hover or diagnostic float
  -- if one is open, the search highlight otherwise. Neovim closes floats when
  -- the cursor moves but not on a keypress, and after a plain K the cursor is
  -- still in the buffer, so Esc has to reach across to them.
  {
    "<Esc>",
    function()
      local closed = false
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_get_config(win).relative ~= "" then
          pcall(vim.api.nvim_win_close, win, false)
          closed = true
        end
      end
      if not closed then vim.cmd("nohlsearch") end
    end,
    desc = "Close float, else clear search highlight",
  },
  { "<Esc><Esc>", "<C-\\><C-n>", desc = "Leave terminal mode", mode = "t" },
}

return M
