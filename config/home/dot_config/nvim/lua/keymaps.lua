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

-- Labels only: these create no mappings, they give which-key a name for a
-- prefix so <leader> shows "find / git / toggle" rather than bare letters.
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
  { "<LocalLeader>", "filetype" },

  -- Not ours, but the popup is where you look having forgotten them.
  { "g", "goto / extended" },
  { "gr", "LSP actions" },
  { "z", "folds, scroll, spelling" },
  { "]", "next" },
  { "[", "previous" },
  { "<C-w>", "window" },
}

M.maps = {

  -- ── Jump: g + letter ──────────────────────────────────────────────────────
  -- The cross-editor convention (Helix, LazyVim, AstroNvim, Zed; IdeaVim ships
  -- gd natively). Vim's gd already meant "goto local declaration", so these
  -- deepen a meaning rather than replace one.
  -- No `needs`: with no LSP these error politely, as core's gr* do.
  { "gd", vim.lsp.buf.definition, desc = "Definition" },
  { "gD", vim.lsp.buf.declaration, desc = "Declaration" },
  { "gy", vim.lsp.buf.type_definition, desc = "Type definition" },
  { "gI", vim.lsp.buf.implementation, desc = "Implementation" },

  -- ── Iterate: [ and ] ──────────────────────────────────────────────────────
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

  -- ── Find: <leader>f ───────────────────────────────────────────────────────
  -- Falls back to :find / :grep, which fill the quickfix list. Same keys,
  -- less power.
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

  -- ── Git: <leader>g ────────────────────────────────────────────────────────
  -- Hunk-level only; lazygit does the rest. Without gitsigns these keep Vim's
  -- own meaning: next/previous change in diff mode.
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
  -- How a line got here, as opposed to who touched it last: git log -L, which
  -- blame and gitsigns have no equivalent for. Normal mode takes the cursor
  -- line, visual the selection.
  {
    "<leader>gl",
    function() require("setup.git").line_history(false) end,
    desc = "Line history",
    needs = "git",
  },
  {
    "<leader>gl",
    function() require("setup.git").line_history(true) end,
    desc = "Line history (selection)",
    mode = "v",
    needs = "git",
  },
  -- A hunk as a text object, so dih and yih read like diw and yiw.
  {
    "ih",
    function() require("gitsigns").select_hunk() end,
    desc = "Hunk",
    mode = { "o", "x" },
    needs = "mod:gitsigns",
  },

  -- ── Toggle: <leader>u (ui) ────────────────────────────────────────────────
  -- Only the seven letters LazyVim and AstroNvim agree on.
  { "<leader>uw", "<Cmd>set wrap!<CR>", desc = "Wrap" },
  { "<leader>us", "<Cmd>set spell!<CR>", desc = "Spell" },
  { "<leader>ul", "<Cmd>set number!<CR>", desc = "Line numbers" },
  { "<leader>ur", "<Cmd>set relativenumber!<CR>", desc = "Relative numbers" },
  -- Steps all / warnings+errors / errors / off: a noisy file usually wants
  -- less, not none.
  { "<leader>ud", function() require("setup.diagnostics").cycle() end, desc = "Diagnostics shown (cycle)" },
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
  -- The eighth letter, and not a convention: nothing else here renders
  -- anything. On by default for markdown, so this is the way out.
  { "<leader>um", function() require("mdtable").toggle() end, desc = "Markdown table alignment" },
  -- Capital H because <leader>uh is inlay hints. Both markdown toggles live
  -- under <leader>u: display layers over a file neither one changes.
  { "<leader>uH", function() require("mdheading").toggle() end, desc = "Markdown heading colours" },

  -- ── Buffers and windows ───────────────────────────────────────────────────
  -- Mirrors tmux's M-hjkl for panes: two levels, two modifiers.
  { "<C-h>", "<C-w><C-h>", desc = "Window left" },
  { "<C-j>", "<C-w><C-j>", desc = "Window down" },
  { "<C-k>", "<C-w><C-k>", desc = "Window up" },
  { "<C-l>", "<C-w><C-l>", desc = "Window right" },
  -- tmux's mnemonic: | is a vertical divider, - a horizontal one.
  { "<leader>-", "<Cmd>split<CR>", desc = "Split below" },
  { "<leader>|", "<Cmd>vsplit<CR>", desc = "Split right" },
  { "<S-h>", "<Cmd>bprevious<CR>", desc = "Previous buffer" },
  { "<S-l>", "<Cmd>bnext<CR>", desc = "Next buffer" },
  { "<leader>bd", "<Cmd>bdelete<CR>", desc = "Delete buffer" },

  -- ── Lists: <leader>x ──────────────────────────────────────────────────────
  -- Vim's list of places: :make, :grep and the pickers all fill it, ]q / [q
  -- walk it. The location list is the same, scoped to one window.
  { "<leader>xq", "<Cmd>copen<CR>", desc = "Quickfix list" },
  { "<leader>xl", "<Cmd>lopen<CR>", desc = "Location list" },
  { "<leader>xd", vim.diagnostic.setqflist, desc = "Diagnostics to quickfix" },

  -- ── Files ─────────────────────────────────────────────────────────────────
  -- netrw is disabled, so without mini.files the command line is the browser:
  -- Tab walks directories.
  {
    "<leader>e",
    function() require("mini.files").open(vim.api.nvim_buf_get_name(0)) end,
    desc = "File browser",
    needs = "mod:mini.files",
    fallback = ":edit ",
  },

  -- ── Edit ──────────────────────────────────────────────────────────────────
  -- = is Vim's own format operator, so <leader>= reads as "format everything".
  { "<leader>=", function() vim.lsp.buf.format({ timeout_ms = 2000 }) end, desc = "Format buffer", mode = { "n", "v" } },

  -- ── F-keys: the only layer that transfers unchanged to other editors ──────
  -- Only <F1> is bound, so F2-F12 are free. These match VS Code and Zed.
  { "<F2>", vim.lsp.buf.rename, desc = "Rename symbol" },
  { "<F12>", vim.lsp.buf.definition, desc = "Definition" },
  { "<S-F12>", vim.lsp.buf.references, desc = "References" },

  -- ── Own namespace: <leader>o ──────────────────────────────────────────────
  -- Reserved. Nothing from any plugin or convention may claim these.
  {
    "<leader>ox",
    [[:%s/\s\+$//e<CR>:nohlsearch<CR>:echo "Cleared trailing whitespace"<CR>]],
    desc = "Clear trailing whitespace",
  },
  -- vimwiki's <leader>w* are disabled in setup/wiki.lua (they collide with the
  -- window namespace); these are the ones worth keeping.
  { "<leader>ow", "<Cmd>VimwikiIndex<CR>", desc = "Wiki index", needs = "cmd:VimwikiIndex" },
  { "<leader>od", "<Cmd>VimwikiMakeDiaryNote<CR>", desc = "Wiki diary today", needs = "cmd:VimwikiMakeDiaryNote" },
  { "<leader>oD", "<Cmd>VimwikiDiaryIndex<CR>", desc = "Wiki diary index", needs = "cmd:VimwikiDiaryIndex" },
  { "<leader>oh", function() require("setup.cheatsheet").open() end, desc = "Cheatsheet" },
  { "<leader>oa", function() require("setup.autosave").toggle() end, desc = "Autosave on/off" },

  -- ── Filetype actions: <LocalLeader> ───────────────────────────────────────
  -- Global rather than per-filetype, since setup/keymaps has no ft field. The
  -- cost is that they must no-op where they do not apply, which
  -- mdtable.align() does.
  { "<LocalLeader>t", function() require("mdtable").align() end, desc = "Align markdown table" },

  -- ── Odds and ends ─────────────────────────────────────────────────────────
  -- One key for "dismiss whatever is in the way": a float if one is open, the
  -- search highlight otherwise. Neovim closes floats when the cursor moves but
  -- not on a keypress, so Esc has to reach across to them.
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
