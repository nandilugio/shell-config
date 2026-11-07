-- Tests for setup/folds.lua:  nvim -l lua/setup/folds_test.lua
--
-- No framework; exit code is 0 when all pass. -l loads the real config, so
-- zS is the mapping in use. Indent folds on a buffer built here, since the
-- function only reads fold state and treesitter would add a parser to need.
-- Indent folds merge adjacent siblings, hence the level-1 line between the
-- two level-2 folds.
--
--    1  a
--    2    b         A  2-10
--    3      c       B  3-6, inside A
--    4        d     C  4-5, inside B
--    5        d2
--    6      c2
--    7    mid
--    8      e       D  8-9, inside A
--    9        f     E  9, inside D
--   10    g
--   11  h

local passed, failed = 0, 0

local function check(name, got, want)
  if vim.deep_equal(got, want) then
    passed = passed + 1
  else
    failed = failed + 1
    io.write(("FAIL  %s\n        got:  %s\n        want: %s\n"):format(name, vim.inspect(got), vim.inspect(want)))
  end
end

if not package.loaded["setup.keymaps"] then dofile(vim.fn.stdpath("config") .. "/init.lua") end

vim.api.nvim_buf_set_lines(0, 0, -1, false, {
  "a", "  b", "    c", "      d", "      d2", "    c2", "  mid", "    e", "      f", "  g", "h",
})
vim.wo.foldmethod = "indent"
vim.bo.shiftwidth = 2
vim.wo.foldlevel = 99
vim.wo.foldcolumn = "0"

local function closed(l) return vim.fn.foldclosed(l) end
local function all_open() vim.cmd("normal! zR") end
local function zS(l)
  vim.fn.cursor(l, 1)
  vim.cmd("normal zS")
end

-- From inside B, on a line no deeper fold holds: B shuts, A and D untouched.
all_open()
zS(6)
check("B closed", closed(3), 3)
check("B ends at 6", vim.fn.foldclosedend(3), 6)
check("A open", closed(2), -1)
check("D open", closed(8), -1)
check("cursor on B's first line", vim.fn.line("."), 3)
check("fold column shown", vim.wo.foldcolumn, "1")
vim.cmd("normal! zo")
check("zo reopens B", closed(3), -1)
check("C inside is closed: one level at a time", closed(4), 4)

-- Depth three: C from its own header; B and A stay open.
all_open()
zS(4)
check("C closed", closed(4), 4)
check("B open", closed(3), -1)
check("A open", closed(2), -1)

-- A top-level fold has no ancestor to reopen.
all_open()
zS(10)
check("A closed", closed(2), 2)
check("A ends at 10", vim.fn.foldclosedend(2), 10)
check("cursor on A's first line", vim.fn.line("."), 2)
vim.cmd("normal! zo")
check("zo reopens A", closed(2), -1)
check("B closed inside", closed(3), 3)
check("D closed inside", closed(8), 8)

-- A line in no fold: a message, not an error.
all_open()
local message
local notify = vim.notify
vim.notify = function(m) message = m end
local ok = pcall(zS, 1)
vim.notify = notify
check("no error outside a fold", ok, true)
check("message outside a fold", message, "No fold here")

-- An already closed fold whose insides are open: the insides reset, the
-- parent stays open. zc here would have closed the parent instead.
all_open()
vim.fn.cursor(3, 1)
vim.cmd("normal! zc")
zS(3)
check("B stays closed", closed(3), 3)
check("A still open", closed(2), -1)
vim.cmd("normal! zo")
check("C closed after the reset", closed(4), 4)

io.write(("%d passed, %d failed\n"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
