-- Only the part that belongs in the editor: which lines changed, hunk
-- navigation, staging without leaving the buffer. Commits, rebases and history
-- are lazygit's job, in a tmux pane.

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
-- gitsigns is hunk-scoped by design and has no equivalent, and lazygit's file
-- history is `--follow` on a whole file, which is a different question.
--
-- TODO: the function form, `git log -L :name:file`, tracks a function as it
-- moves and is the more useful half. It needs the enclosing symbol's name,
-- which setup/winbar.lua already computes from the LSP document symbol tree —
-- factor that out rather than asking the server twice. Falls back to prompting
-- where no server is attached. Worth a sibling binding, <leader>gF.

local M = {}

-- -L is one range per invocation and cannot be combined with pathspecs, so the
-- file is addressed as part of the range argument.
local function log_lines(first, last, file)
  return { "git", "log", "-L", ("%d,%d:%s"):format(first, last, file) }
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

-- Normal mode gives the cursor line; visual mode the selection. `'<` and `'>`
-- are only set on leaving visual mode, which has not happened while the
-- mapping body runs, so the live selection is read from `v` and the cursor.
function M.line_history(range)
  local buf = vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(buf)
  if file == "" then
    vim.notify("No file in this buffer", vim.log.levels.WARN)
    return
  end

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

  -- From the file's own directory: cwd and the file differ when opening by path.
  local cwd = vim.fs.dirname(file)
  local res = vim.system(log_lines(first, last, vim.fn.fnamemodify(file, ":t")), {
    cwd = cwd,
    text = true,
  }):wait()

  if res.code ~= 0 then
    -- The usual causes: not a repository, or the file is untracked.
    vim.notify(vim.trim(res.stderr or "git log -L failed"), vim.log.levels.WARN)
    return
  end

  local lines = vim.split(res.stdout, "\n", { trimempty = true })
  if #lines == 0 then
    vim.notify("No history for that line", vim.log.levels.INFO)
    return
  end

  show(("git log -L %d,%d"):format(first, last), lines)
end

return M
