-- The cheatsheet, in a float over the whole editor.
--
-- Read-only scratch buffer, so the usual motions work. The file is written as
-- aligned plain text rather than markdown tables: this window shows the source,
-- and unrendered pipes are harder to read than columns.

local M = {}

function M.open()
  local path = vim.fn.stdpath("config") .. "/cheatsheet.md"
  if not vim.uv.fs_stat(path) then
    vim.notify("No cheatsheet at " .. path, vim.log.levels.WARN)
    return
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.fn.readfile(path))
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].modifiable = false
  vim.bo[buf].buftype = "nofile"

  local width = math.min(84, math.floor(vim.o.columns * 0.9))
  local height = math.floor(vim.o.lines * 0.85)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "single",
    title = " Cheatsheet ",
    title_pos = "center",
  })

  vim.wo[win].wrap = false
  vim.wo[win].cursorline = true

  for _, key in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", key, function()
      if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
    end, { buffer = buf, nowait = true, desc = "Close cheatsheet" })
  end
end

return M
