-- Folds: what the built-in keys leave out. Tested by folds_test.lua, next to
-- this file: nvim -l lua/setup/folds_test.lua
--
-- The native keys act on the folds containing the cursor line, and the
-- cursor is never inside a closed fold (it lands on the first line), so zC
-- closes outward, to the top level, and leaves the folds nested inside as
-- they were: zo afterwards shows the state you left. zS closes the fold at
-- the cursor and everything nested in it, parents and siblings untouched, so
-- zo then opens one level at a time. The mirror of zO, which Vim lacks.
--
-- Done with Vim's own keys: a closed fold selected in Visual mode covers all
-- its lines, and a visual zC closes every fold touching them, nested ones
-- and ancestors alike (fold.c, opFoldRange). The ancestors are then reopened
-- from the outermost down to this fold, since zo opens the topmost closed one.

local M = {}

function M.shut()
  local line = vim.fn.line(".")
  if vim.fn.foldlevel(line) == 0 then
    vim.notify("No fold here", vim.log.levels.WARN)
    return
  end
  -- zc on an already closed fold would close its parent instead.
  if vim.fn.foldclosed(line) == -1 then vim.cmd("normal! zc") end
  local start = vim.fn.foldclosed(line)
  vim.cmd("normal! VzC")
  while vim.fn.foldclosed(start) ~= start do
    vim.fn.cursor(vim.fn.foldclosed(start), 1)
    vim.cmd("normal! zo")
  end
  vim.fn.cursor(start, 1)
  -- As the built-in closing keys do (keymaps.lua): a closed fold shows the column.
  vim.wo.foldcolumn = "1"
end

return M
