-- Only the part that belongs in the editor: which lines changed, hunk
-- navigation, staging without leaving the buffer. Commits and rebases are a
-- git UI's job, in a tmux pane; the editor need not know about it.

local ok, gitsigns = pcall(require, "gitsigns")
if ok then
  gitsigns.setup({
    -- Diff characters rather than gitsigns' bars, which leave the colour to
    -- carry the meaning; + ~ - read like diff output and git add -p.
    --
    -- Plain UTF-8, no Nerd Font. ‾ is a deletion above the first line, ≃ a
    -- line both changed and partly deleted.
    signs = {
      add = { text = "+" },
      change = { text = "~" },
      delete = { text = "-" },
      topdelete = { text = "‾" },
      changedelete = { text = "≃" },
      untracked = { text = "┆" },
    },
    -- Same characters again: staged-ness is already in the colour, which
    -- gitsigns dims to half brightness. Unset, this defaults back to the bars.
    signs_staged = {
      add = { text = "+" },
      change = { text = "~" },
      delete = { text = "-" },
      topdelete = { text = "‾" },
      changedelete = { text = "≃" },
    },
    preview_config = { border = "single" },
  })
end

-- RuboCop via :make, because on Ruby 2.x the server runs under a newer
-- interpreter and cannot reach the project's own rubocop. Neovim ships the
-- compiler definition; results land in the quickfix list.
vim.api.nvim_create_autocmd("FileType", {
  pattern = "ruby",
  callback = function(args)
    vim.cmd("compiler rubocop")
    -- From the file, not the cwd: they differ when opening by path.
    local gemfile = vim.fs.find("Gemfile", {
      upward = true,
      path = vim.fs.dirname(vim.api.nvim_buf_get_name(args.buf)),
    })[1]
    if gemfile then
      vim.bo[args.buf].makeprg = "bundle exec rubocop --format emacs"
    end
  end,
})

-- ── Line history ────────────────────────────────────────────────────────────
-- `git log -L` answers the question blame cannot: not "who touched this last"
-- but "how did this line get here". It follows the line through renames and
-- reindentation, printing each commit with the diff of just that line.
--
-- gitsigns is hunk-scoped by design and has no equivalent.
--
-- The function form, `git log -L :name:file`, is the better tool on a
-- definition line: -L is cursor-scoped, so on a `def` it shows the signature
-- changing and hides the body that changed with it. Naming the function asks
-- for the whole thing, every time.

local M = {}

-- Every one of these addresses the file as a bare basename run from its own
-- directory, because -L resolves its path against the cwd and takes no
-- pathspec. Returns nil after notifying, so callers just bail.
local function buffer_file()
  local name = vim.api.nvim_buf_get_name(0)
  if name == "" then
    vim.notify("No file in this buffer", vim.log.levels.WARN)
    return nil
  end
  return vim.fn.fnamemodify(name, ":t"), vim.fs.dirname(name)
end

-- A split rather than a float: this is output you scroll and read down, where
-- the floats here are for a glance. filetype=git gives it the diff colours
-- treesitter already has, and q closes it as everywhere else.
local function show(title, lines)
  vim.cmd("botright split")
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = "git"
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].modifiable = false
  -- The title goes in the statusline rather than the buffer name: naming the
  -- buffer makes a second look at the same range fail with E95.
  vim.wo.statusline = title

  vim.keymap.set("n", "q", "<Cmd>close<CR>", { buffer = buf, nowait = true, desc = "Close" })
end

-- Runs git in the file's own directory and shows the output, or says why there
-- is none. `hint` is appended to a non-zero exit, where git's own message is
-- accurate but not actionable.
local function run(args, cwd, title, hint)
  local res = vim.system(args, { cwd = cwd, text = true }):wait()

  if res.code ~= 0 then
    local err = vim.trim(res.stderr or "git failed")
    if hint and hint.when and err:match(hint.when) then
      err = err .. "\n\n" .. hint.say
    end
    vim.notify(err, vim.log.levels.WARN)
    return
  end

  local lines = vim.split(res.stdout, "\n", { trimempty = true })
  if #lines == 0 then
    -- Exit 0 with nothing to show: the file is tracked but this line, function
    -- or path has no commits of its own.
    vim.notify("No history found", vim.log.levels.INFO)
    return
  end

  show(title, lines)
end

-- Normal mode gives the cursor line; visual mode the selection. `'<` and `'>`
-- are only set on leaving visual mode, which has not happened while the
-- mapping body runs, so the live selection is read from `v` and the cursor.
function M.line_history(range)
  local file, cwd = buffer_file()
  if not file then return end

  local first, last
  if range then
    first, last = vim.fn.line("v"), vim.api.nvim_win_get_cursor(0)[1]
    if first > last then first, last = last, first end
    -- Leave visual mode, as the selection has been consumed.
    vim.cmd("normal! \27")
  else
    first = vim.api.nvim_win_get_cursor(0)[1]
    last = first
  end

  run(
    { "git", "log", "-L", ("%d,%d:%s"):format(first, last, file) },
    cwd,
    ("git log -L %d,%d"):format(first, last)
  )
end

-- Only what can sensibly follow `-L :name:`. setup/winbar.lua walks the same
-- tree for its breadcrumb, but wants the opposite of this: classes and modules
-- are most of what makes a trail worth reading, and none of them are things
-- git can trace. Two similar walks answering different questions, kept apart.
local TRACEABLE = { Function = true, Method = true, Constructor = true }

local function innermost_function(symbols, line, found)
  for _, s in ipairs(symbols or {}) do
    local range = s.range or (s.location and s.location.range)
    if range and line >= range.start.line and line <= range["end"].line then
      if TRACEABLE[vim.lsp.protocol.SymbolKind[s.kind]] then
        found = s.name
      end
      return innermost_function(s.children, line, found)
    end
  end
  return found
end

-- Asked for on demand: winbar's cache holds a display string, and only
-- refreshes on CursorHold.
local function enclosing_function(buf, line)
  local clients = vim.lsp.get_clients({ bufnr = buf, method = "textDocument/documentSymbol" })
  if #clients == 0 then return nil end

  local res = clients[1]:request_sync("textDocument/documentSymbol", {
    textDocument = vim.lsp.util.make_text_document_params(buf),
  }, 1000, buf)
  if not res or res.err or not res.result then return nil end

  return innermost_function(res.result, line, nil)
end

-- `-L :name:file`. git finds the function with a per-language "funcname"
-- pattern, and ships one for most languages -- but SHIPPING IS NOT ENABLING:
-- the pattern lies dormant until a .gitattributes marks the file as using it,
-- which many repositories never do. Without that, -L falls back to a plain
-- regex over the name, which does not match a definition line, and git says
-- only "no match". The check below turns that into the actual instruction.
function M.function_history()
  local file, cwd = buffer_file()
  if not file then return end

  local line = vim.api.nvim_win_get_cursor(0)[1]
  local name = enclosing_function(vim.api.nvim_get_current_buf(), line - 1)
  if not name then
    -- No server, or the cursor is not inside anything the server names. Asking
    -- beats failing: the name is often on screen.
    name = vim.fn.input("Function: ")
    if name == "" then return end
  end

  run({ "git", "log", "-L", (":%s:%s"):format(name, file) }, cwd, (":%s:"):format(name), {
    -- "no match" usually means the pattern was never enabled here, not that
    -- the name is wrong, and git's own message does not say so.
    when = "no match",
    say = "funcname patterns are per-repository: add e.g. `*.py diff=python`"
      .. "\nto .gitattributes. Until then <leader>gl gives line history.",
  })
end

-- Every commit touching this file. fzf-lua's git_bcommits is the good version
-- of this -- a picker with the diff in a preview -- so <leader>gf prefers it
-- and falls back here, where there is no fzf. --follow crosses renames;
-- --oneline because a file's whole patch history is far more than is wanted.
function M.file_history()
  local file, cwd = buffer_file()
  if not file then return end

  run({ "git", "log", "--follow", "--oneline", "--", file }, cwd, file)
end

return M
