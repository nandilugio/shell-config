-- Every keybinding, as data. Applied by setup/keymaps.lua after plugins load.
--
-- Entry shape:
--   { lhs, rhs, desc = "...", mode = "n"|{"n","x"}, needs = "...", fallback = rhs, expr = true }
--
--   mode      "x" for a selection, never "v": that is Visual AND Select, and a
--             snippet placeholder is in Select mode, where a leader map would
--             swallow the space typed into it.
--
--   needs     what `rhs` depends on: a bare name is an executable on PATH,
--             "mod:x" a Lua module, "cmd:X" an Ex command.
--             When missing, `fallback` is used instead; with no fallback the
--             mapping is skipped entirely. This is what lets the config work on
--             a bare server with nothing installed.
--   fallback  a built-in that does the same job, less well: an Ex command
--             string or a function. Never the name of a mapping (gO, grr):
--             mappings are applied noremap, so a mapped key would not fire.
--   expr      rhs is a function returning the keys to run (:h map-expression).
--
-- Design rule:  g jumps · gr acts on symbols · <leader> opens tools
--               [ ] iterate lists · <C-w> windows · F-keys bridge other editors
-- Nvim 0.12 defaults we deliberately do NOT redefine (they are already right):
--   grn gra grr grx gO   K   ]d [d ]D [D   ]q [q ]Q [Q   ]b [b   ]<Space> [<Space>
--   gc gcc   <C-]> <C-t>   an in (x/o)   ]n [n (x)

local M = {}

-- Labels only: these create no mappings, they give which-key a name for a
-- prefix so <leader> shows "find / git / toggle" rather than bare letters.
--
--   { lhs, label, mode? }
M.groups = {
  -- Leader namespaces
  { "<leader>f", "find" },
  { "<leader>g", "git", mode = { "n", "x" } },
  { "<leader>u", "toggle (ui)" },
  { "<leader>ug", "git" }, -- the only nested group: git has three of its own
  { "<leader>b", "buffer" },
  { "<leader>o", "own" }, -- reserved: no plugin or convention may claim it
  { "<leader>x", "lists" },
  { "<LocalLeader>", "filetype" },
  { "<LocalLeader>p", "python" },

  -- Not ours, but the popup is where you look having forgotten them.
  { "g", "goto / extended" },
  { "gr", "LSP actions" },
  { "z", "folds, scroll, spelling" },
  { "]", "next" },
  { "[", "previous" },
  { "<C-w>", "window" },
}

-- For the fold commands: an expr map that sets the window's fold column, then
-- runs the built-in key, so counts and visual selections work unchanged.
local function setting_foldcolumn(keys, width)
  return function()
    vim.wo.foldcolumn = tostring(width)
    return keys
  end
end

-- For ]e [e ]w [w: a diagnostic step that shows the message in a float
-- afterwards, as core's ]d does. `float` was the pre-0.12 spelling of this
-- option and is deprecated for `on_jump`.
local severity = vim.diagnostic.severity

local function jumping(count, sev)
  return function()
    vim.diagnostic.jump({
      count = count,
      severity = sev,
      on_jump = function(_, buf) vim.diagnostic.open_float({ bufnr = buf, scope = "cursor", focus = false }) end,
    })
  end
end

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
  { "]e", jumping(1, severity.ERROR), desc = "Next error" },
  { "[e", jumping(-1, severity.ERROR), desc = "Previous error" },
  { "]w", jumping(1, severity.WARN), desc = "Next warning" },
  { "[w", jumping(-1, severity.WARN), desc = "Previous warning" },
  -- The commits under review (setup/review.lua): each is checked out in turn.
  -- v for revision: ]r is Neovim's "next rare word", and the other free
  -- letters mean hunk or something else in Helix, LazyVim or unimpaired.
  { "]v", function() require("setup.review").step(1) end, desc = "Next commit under review", needs = "mod:gitsigns" },
  { "[v", function() require("setup.review").step(-1) end, desc = "Previous commit under review", needs = "mod:gitsigns" },

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
    fallback = vim.lsp.buf.document_symbol,
  },
  {
    "<leader>fS",
    function() require("setup.fzf").lsp_live_workspace_symbols() end,
    desc = "Workspace symbols",
    needs = "fzf",
    fallback = vim.lsp.buf.workspace_symbol,
  },
  {
    "<leader>/",
    function() require("setup.fzf").live_grep() end,
    desc = "Grep project",
    needs = "fzf",
    fallback = ":grep ",
  },
  -- References through the picker when available; what grr runs otherwise.
  {
    "<leader>fR",
    function() require("setup.fzf").lsp_references() end,
    desc = "References",
    needs = "fzf",
    fallback = vim.lsp.buf.references,
  },
  -- fzf-lua ships 124 pickers and this binds a dozen; the rest are invisible
  -- unless you already know they exist. This is the way in.
  {
    "<leader>f?",
    function() require("setup.fzf").builtin() end,
    desc = "All pickers",
    needs = "fzf",
  },
  -- The last picker, with its query and position intact: grep, jump to the
  -- third hit, realise you wanted the fifth.
  {
    "<leader>f.",
    function() require("setup.fzf").resume() end,
    desc = "Resume last picker",
    needs = "fzf",
  },

  -- ── Git: <leader>g ────────────────────────────────────────────────────────
  -- Hunk-level only; commits and rebases are a tmux pane's job. Without
  -- gitsigns these keep Vim's own meaning: next/previous change in diff mode.
  { "]c", function() require("gitsigns").nav_hunk("next") end, desc = "Next hunk", needs = "mod:gitsigns", fallback = "]c" },
  { "[c", function() require("gitsigns").nav_hunk("prev") end, desc = "Previous hunk", needs = "mod:gitsigns", fallback = "[c" },
  -- Through setup/git.lua, which refuses while the signs compare against
  -- anything but the index (review mode, a :Gitsigns change_base).
  { "<leader>gs", function() require("setup.git").stage_hunk() end, desc = "Stage hunk", needs = "mod:gitsigns" },
  { "<leader>gr", function() require("setup.git").reset_hunk() end, desc = "Reset hunk", needs = "mod:gitsigns" },
  -- On a selection, only the selected lines: without the range gitsigns takes
  -- the whole hunk under the cursor. It sorts the two ends itself.
  {
    "<leader>gs",
    function() require("setup.git").stage_hunk({ vim.fn.line("v"), vim.fn.line(".") }) end,
    desc = "Stage selection",
    mode = "x",
    needs = "mod:gitsigns",
  },
  {
    "<leader>gr",
    function() require("setup.git").reset_hunk({ vim.fn.line("v"), vim.fn.line(".") }) end,
    desc = "Reset selection",
    mode = "x",
    needs = "mod:gitsigns",
  },
  { "<leader>gp", function() require("gitsigns").preview_hunk() end, desc = "Preview hunk", needs = "mod:gitsigns" },
  { "<leader>gb", function() require("gitsigns").blame_line({ full = true }) end, desc = "Blame line", needs = "mod:gitsigns" },
  { "<leader>gd", function() require("gitsigns").diffthis() end, desc = "Diff this", needs = "mod:gitsigns" },
  -- The side panel: every line's commit, scroll-bound to the buffer. Capital
  -- pairs with gb, the single-line float. Inside it, r and R walk back through
  -- history -- see TODO 14, they throw across a rename.
  { "<leader>gB", "<Cmd>Gitsigns blame<CR>", desc = "Blame file", needs = "mod:gitsigns" },
  -- Capitals of the hunk actions, meaning "all of them", as gitsigns names
  -- them: stage_hunk/stage_buffer, reset_hunk/reset_buffer.
  { "<leader>gS", function() require("setup.git").stage_buffer() end, desc = "Stage buffer", needs = "mod:gitsigns" },
  { "<leader>gR", function() require("setup.git").reset_buffer() end, desc = "Reset buffer", needs = "mod:gitsigns" },
  -- q as in <leader>xq: the quickfix list, which ]q and [q then walk. The
  -- capital is every changed file in the repository, open or not, against the
  -- same base -- in review mode, the whole branch.
  { "<leader>gq", function() require("gitsigns").setqflist() end, desc = "Hunks to quickfix", needs = "mod:gitsigns" },
  { "<leader>gQ", function() require("gitsigns").setqflist("all") end, desc = "All files' hunks to quickfix", needs = "mod:gitsigns" },
  -- The changed files themselves, against the signs' base: capital of gd, as
  -- "the diff, every file". An empty ref is the index, which is what the signs
  -- show; fzf-lua's own default would be HEAD.
  {
    "<leader>gD",
    function()
      local git = require("setup.git")
      require("setup.fzf").git_diff({ ref = git.base(0) or "", cwd = git.root() })
    end,
    desc = "Changed files",
    needs = "fzf",
    fallback = function() require("setup.git").changed_files() end,
  },
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
    mode = "x",
    needs = "git",
  },
  -- The whole function, tracked as it moves and is renamed. Better than gl on
  -- a definition line, where the cursor-scoped -L hides the body.
  {
    "<leader>gt",
    function() require("setup.git").function_history() end,
    desc = "Function history (trace)",
    needs = "git",
  },
  -- Every commit touching this file, as a picker: fzf-lua already runs it,
  -- with the diff in a preview pane and <CR> to open the file at that commit.
  {
    "<leader>gf",
    function() require("setup.fzf").git_bcommits({ follow = true }) end,
    desc = "File history",
    needs = "fzf",
    -- Without fzf, the same question as a patch dump: file_history is ours and
    -- needs only git, so the key keeps working on a bare server.
    fallback = function() require("setup.git").file_history() end,
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
  -- Two dimensions, two keys (setup/diagnostics.lua): where messages are
  -- written out, and how severe they must be. Signs always show everything.
  { "<leader>ud", function() require("setup.diagnostics").cycle_scope() end, desc = "Diagnostics: cursor line, every line, none" },
  { "<leader>uD", function() require("setup.diagnostics").cycle_severity() end, desc = "Diagnostics: all, warnings+errors, errors" },
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
  -- Off by default. z for the fold commands; a string option, so no set x!.
  {
    "<leader>uz",
    function() vim.o.foldcolumn = vim.o.foldcolumn == "0" and "1" or "0" end,
    desc = "Fold column",
  },
  -- A setting like the rest, so a toggle here rather than an action under
  -- <leader>o. Off by default (setup/autosave.lua says why).
  { "<leader>ua", function() require("setup.autosave").toggle() end, desc = "Autosave" },
  -- Many settings at once, as two presets (setup/review.lua). Capital R:
  -- <leader>ur is relative numbers.
  { "<leader>uR", function() require("setup.review").toggle() end, desc = "Review mode", needs = "mod:gitsigns" },
  -- Git's own toggles, nested because there are three of them and <leader>u's
  -- single letters are spoken for (ud diagnostics, uw wrap, ub background).
  {
    "<leader>ugd",
    function() require("gitsigns").toggle_deleted() end,
    desc = "Deleted lines",
    needs = "mod:gitsigns",
  },
  {
    "<leader>ugw",
    function() require("gitsigns").toggle_word_diff() end,
    desc = "Word diff",
    needs = "mod:gitsigns",
  },
  -- The ambient layer: blame for the cursor line, as virtual text, following
  -- the cursor. Off by default in gitsigns, hence a toggle rather than config.
  {
    "<leader>ugb",
    function() require("gitsigns").toggle_current_line_blame() end,
    desc = "Current-line blame",
    needs = "mod:gitsigns",
  },

  -- ── Buffers and windows ───────────────────────────────────────────────────
  -- Mirrors tmux's M-hjkl for panes: two levels, two modifiers.
  { "<C-h>", "<C-w><C-h>", desc = "Window left" },
  { "<C-j>", "<C-w><C-j>", desc = "Window down" },
  { "<C-k>", "<C-w><C-k>", desc = "Window up" },
  { "<C-l>", "<C-w><C-l>", desc = "Window right" },
  -- tmux's mnemonic: | is a vertical divider, - a horizontal one.
  { "<leader>-", "<Cmd>split<CR>", desc = "Split below" },
  { "<leader>|", "<Cmd>vsplit<CR>", desc = "Split right" },
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
  { "<leader>=", function() vim.lsp.buf.format({ timeout_ms = 2000 }) end, desc = "Format buffer" },
  -- format() takes the selection by itself in visual mode.
  { "<leader>=", function() vim.lsp.buf.format({ timeout_ms = 2000 }) end, desc = "Format selection", mode = "x" },

  -- ── Folds: z ──────────────────────────────────────────────────────────────
  -- The built-ins, showing the fold column (off by default) once something is
  -- folded and hiding it once everything is open. <leader>uz toggles it by hand.
  -- Labels say what the key does to the view: zm "fold more" lowers
  -- 'foldlevel', which masks one more level. zC closes the fold and the ones
  -- containing it, not the ones inside (fold.c:1221); zO opens everything in
  -- the outermost fold.
  { "zc", setting_foldcolumn("zc", 1), desc = "Close fold", mode = { "n", "x" }, expr = true },
  { "zC", setting_foldcolumn("zC", 1), desc = "Close fold and those containing it", mode = { "n", "x" }, expr = true },
  { "za", setting_foldcolumn("za", 1), desc = "Toggle fold", mode = { "n", "x" }, expr = true },
  { "zA", setting_foldcolumn("zA", 1), desc = "Toggle fold, as zC or zO", mode = { "n", "x" }, expr = true },
  { "zm", setting_foldcolumn("zm", 1), desc = "Mask one more level (fold more)", expr = true },
  { "zM", setting_foldcolumn("zM", 1), desc = "Mask all", expr = true },
  { "zR", setting_foldcolumn("zR", 0), desc = "Reveal all", expr = true },
  { "zn", setting_foldcolumn("zn", 0), desc = "No folding (zN restores)", expr = true },
  -- Mapped to itself only for the label; the column stays as it is.
  { "zr", "zr", desc = "Reveal one more level (fold less)" },

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

  -- ── Filetype actions: <LocalLeader> ───────────────────────────────────────
  -- Global rather than per-filetype, since setup/keymaps has no ft field. The
  -- cost is that they must no-op where they do not apply, which
  -- mdtable.align() does.
  { "<LocalLeader>t", function() require("mdtable").align() end, desc = "Align markdown table" },
  -- Global state, like <leader>ud, so it also works before a Python file is open.
  { "<LocalLeader>pt", function() require("setup.lsp").pick_type_checking() end, desc = "Type checking mode" },

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
