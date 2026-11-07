-- Reading help: the cheatsheet in a float, and q to leave any help window.
--
-- The cheatsheet is a help file (doc/cheatsheet.txt), so everything help
-- does works in it: K on a key opens its page, <C-]> follows a link, <C-o>
-- comes back, <leader>fh finds its sections, :help cheatsheet-git jumps to
-- one. The float is for the glance; the same file opens as any help does.

local M = {}

-- :help gives the buffer its help-ness (buftype, read-only, the tags), so it
-- opens the file, and the window it made is closed in favour of the float.
-- From inside a help window :help reuses it, so that one is left alone.
function M.cheatsheet()
  local before = vim.api.nvim_get_current_win()
  local ok, err = pcall(vim.cmd, "silent keepalt help cheatsheet")
  if not ok then
    vim.notify(err, vim.log.levels.WARN)
    return
  end
  local buf = vim.api.nvim_get_current_buf()
  if vim.api.nvim_get_current_win() ~= before then vim.cmd.close() end

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
  -- What :help's own window sets and a new window does not inherit: the
  -- tag stars and link bars hidden, the cursor line marked.
  vim.wo[win].conceallevel = 2
  vim.wo[win].concealcursor = "nc"
  vim.wo[win].cursorline = true
end

-- q closes a help window, as it closes the cheatsheet, the file browser and
-- the git windows here. Buffer-local, so it travels with the buffer into the
-- float and back. <Esc> closes the float as it closes every float.
vim.api.nvim_create_autocmd("FileType", {
  pattern = "help",
  callback = function(args)
    vim.keymap.set("n", "q", "<Cmd>close<CR>", { buffer = args.buf, nowait = true, desc = "Close" })
  end,
})

return M
