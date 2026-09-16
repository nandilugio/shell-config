-- Tests for mdtable. Run them with Neovim itself:
--
--   nvim -l lua/mdtable/test.lua
--
-- No framework: `nvim -l` runs a script directly, and a dependency whose job is
-- printing "ok" would cost more than it is worth. Exit code is 0 when all pass.
--
-- Detection is tested through scan() and cells(), where "how many tables" and
-- "how many cells" are the natural questions. Everything else goes through the
-- public surface: align() on a scratch buffer, and render as it lands on
-- screen, because the screen is the only place buffer text and virtual text
-- are combined — a wrong width shows up there as a crooked pipe, not an error.

vim.opt.rtp:prepend(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h"))

local md = require("mdtable")
local scan, cells = md._internal.scan, md._internal.cells
local ns = vim.api.nvim_get_namespaces().mdtable

-- One buffer line must stay one screen line, or a wide table wraps and the rows
-- below it are no longer where the checks expect them.
vim.wo.wrap = false
vim.o.columns = 400

-- toggle() announces itself; here that is noise between the results.
vim.notify = function() end

local passed, failed = 0, 0

local function check(name, got, want)
  if vim.deep_equal(got, want) then
    passed = passed + 1
  else
    failed = failed + 1
    io.write(("FAIL  %s\n        got:  %s\n        want: %s\n"):format(name, vim.inspect(got), vim.inspect(want)))
  end
end

-- ── Helpers ─────────────────────────────────────────────────────────────────
-- Sources are written as [[ ]] blocks; the newline after the opening bracket
-- and before the closing one are the block's edges, not rows.

local function lines(src)
  return vim.split(src:match("^\n?(.-)\n?$"), "\n")
end

local function text(src)
  return table.concat(lines(src), "\n")
end

local function tables(src)
  return #scan(lines(src))
end

-- A scratch buffer holding `src`, made current, with its filetype set last so
-- the FileType autocmd sees a buffer that already has its lines.
local function buffer(src, filetype)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines(src))
  vim.api.nvim_set_current_buf(buf)
  vim.bo[buf].filetype = filetype or "markdown"
  return buf
end

local function marks(buf)
  return #vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {})
end

-- Screen columns of the pipes in a rendered line. Two rows are aligned when
-- these agree; comparing widths alone would miss one cell padded too much and
-- another too little cancelling out. Measured from the display width of the
-- prefix rather than by stepping characters, because a combining accent or a
-- joined emoji is several bytes that render as one or two columns.
local function pipes(s)
  local at = {}
  for i = 1, #s do
    if s:sub(i, i) == "|" then at[#at + 1] = vim.fn.strdisplaywidth(s:sub(1, i)) end
  end
  return table.concat(at, ",")
end

-- True when every row of `buf`, as drawn, has its pipes where the first row
-- does. Switches to the buffer only if it is not already current, so a test
-- that has just waited for the timer is not rescued by BufEnter.
local function screen_aligned(buf)
  if vim.api.nvim_get_current_buf() ~= buf then vim.api.nvim_set_current_buf(buf) end
  vim.cmd("redraw")
  local first
  for row = 1, vim.api.nvim_buf_line_count(buf) do
    local s = {}
    for col = 1, vim.o.columns do s[#s + 1] = vim.fn.screenstring(row, col) end
    local p = pipes((table.concat(s):gsub("%s+$", "")))
    first = first or p
    if p ~= first then return false end
  end
  return true
end

local function renders_aligned(src)
  return screen_aligned(buffer(src))
end

-- The buffer text after align() with the cursor on the first line.
local function aligned(src)
  local buf = buffer(src)
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  md.align()
  return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
end

-- ── Finding tables ──────────────────────────────────────────────────────────

check("a plain table", tables([[
| a | b |
|---|---|
| 1 | 2 |
]]), 1)

check("prose with pipes is not a table", tables([[
Just some text with a | pipe in it.
And another | line.
]]), 0)

check("rows without a separator", tables([[
| no | separator |
| so | not a table |
]]), 0)

check("a separator alone", tables([[
|---|---|
]]), 0)

check("a separator with no header above it", tables([[
|---|---|
| a | b |
]]), 0)

check("a separator that is not the second row", tables([[
| a | b |
| c | d |
|---|---|
]]), 0)

-- The guard that matters most: anything may start with a pipe, so a run is a
-- table only if the separator agrees with the header.
check("a separator whose column count differs from the header", tables([[
| a | b | c |
|---|---|
| 1 | 2 | 3 |
]]), 0)

check("a separator with no dashes", tables([[
| a | b |
|:|:|
| 1 | 2 |
]]), 0)

-- Every delimiter cell needs a dash, not just the row as a whole.
check("a separator with one cell lacking a dash", tables([[
| a | b |
|:|---|
| 1 | 2 |
]]), 0)

check("two tables separated by prose", tables([[
| a | b |
|---|---|
| 1 | 2 |

Text between them.

| c | d |
|---|---|
| 3 | 4 |
]]), 2)

-- With no blank line between them, two tables are one run of rows, and the
-- second separator is just a row inside it.
check("back-to-back tables are one run", tables([[
| a | b |
|---|---|
| 1 | 2 |
| c | d |
|---|---|
| 3 | 4 |
]]), 1)

-- Rows whose cell counts differ from the header still belong to the table.
check("a row shorter than the header", tables([[
| a | b | c |
|---|---|---|
| 1 |
]]), 1)

check("a row longer than the header", tables([[
| a | b |
|---|---|
| 1 | 2 | 3 |
]]), 1)

check("an empty buffer", #scan({}), 0)
check("one empty line", #scan({ "" }), 0)
check("a lone pipe", #scan({ "|" }), 0)
check("dashes without pipes", #scan({ "---" }), 0)

-- ── Fenced code blocks ──────────────────────────────────────────────────────
-- The one case a real markdown parser would catch for free.

check("a table inside ``` is skipped", tables([[
```
| a | b |
|---|---|
| 1 | 2 |
```
]]), 0)

check("a table inside ~~~ is skipped", tables([[
~~~
| a | b |
|---|---|
| 1 | 2 |
~~~
]]), 0)

check("a fence with an info string still opens a block", tables([[
```markdown
| a | b |
|---|---|
| 1 | 2 |
```
]]), 0)

check("a table after a closed fence is found", tables([[
```
| not | a table |
|---|---|
```

| a | b |
|---|---|
| 1 | 2 |
]]), 1)

check("``` inside a ~~~ block does not close it", tables([[
~~~
```
| a | b |
|---|---|
~~~
]]), 0)

check("a shorter fence does not close a longer one", tables([[
````
```
| a | b |
|---|---|
````
]]), 0)

check("an unclosed fence swallows the rest", tables([[
```
| a | b |
|---|---|
]]), 0)

-- ── Splitting cells ─────────────────────────────────────────────────────────

check("the outer pipes are not columns", #cells("| a | b | c |"), 3)
check("a row without a trailing pipe", #cells("| a | b"), 2)
check("empty cells are counted", #cells("|  |  |"), 2)
check("an escaped pipe is not a delimiter", #cells([[| a \| b | c |]]), 2)
check("an escaped pipe keeps its text", vim.trim(cells([[| a \| b | c |]])[1].text), [[a \| b]])

-- A backslash escapes the backslash, so the pipe after it still splits: three
-- cells, not two. Getting this wrong merges a column into its neighbour.
check("an escaped backslash leaves the pipe live", #cells([[| x \\| y | z |]]), 3)
check("a trailing backslash does not run off the end", #cells([[| x\ | y |]]), 2)

-- ── Aligning in the buffer ──────────────────────────────────────────────────

check("columns are padded to a common width", aligned([[
| a | b |
|---|---|
| longer | x |
]]), text([[
| a      | b   |
| ------ | --- |
| longer | x   |
]]))

-- The separator is rebuilt from the parsed alignment, not copied, so a ragged
-- one comes out even — and a left ":--" keeps its colon, since "left" and "no
-- marker" lay out the same but are not the same text.
check("alignment markers are honoured and kept", aligned([[
| a | b | c |
|:--|:-:|--:|
| 1 | 2 | 3 |
]]), text([[
| a   |  b  |   c |
| :-- | :-: | --: |
| 1   |  2  |   3 |
]]))

check("a separator with spaces and colons", aligned([[
| a | b |
| :-: | --: |
| 1 | 2 |
]]), text([[
|  a  |   b |
| :-: | --: |
|  1  |   2 |
]]))

check("a table keeps its indent", aligned([[
- item:

  | a | b |
  |---|---|
  | 1 | 2 |
]]), text([[
- item:

  | a | b |
  |---|---|
  | 1 | 2 |
]]))

check("an indented table is aligned in place", (function()
  local buf = buffer([[
  | a | b |
  |---|---|
  | longer | 2 |
]])
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  md.align()
  return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
end)(), text([[
  | a      | b   |
  | ------ | --- |
  | longer | 2   |
]]))

check("a short row gains empty cells", aligned([[
| a | b | c |
|---|---|---|
| 1 |
]]), text([[
| a   | b   | c   |
| --- | --- | --- |
| 1   |     |     |
]]))

check("a long row keeps every cell", aligned([[
| a | b |
|---|---|
| 1 | 2 | extra |
]]), text([[
| a   | b   |       |
| --- | --- | ----- |
| 1   | 2   | extra |
]]))

check("tabs become spaces", aligned("| a | b |\n|---|---|\n|\t1\t| 2 |"):find("\t", 1, true), nil)

check("CJK is measured in cells, not bytes", aligned([[
| a | b |
|---|---|
| 日本語 | x |
]]), text([[
| a      | b   |
| ------ | --- |
| 日本語 | x   |
]]))

check("emoji is measured in cells, not bytes", aligned([[
| a | b |
|---|---|
| 🎉 | x |
]]), text([[
| a   | b   |
| --- | --- |
| 🎉  | x   |
]]))

check("outside a table nothing changes", aligned([[
Just prose.
]]), "Just prose.")

-- Rendering and rewriting share their measurements, so aligning an aligned
-- table must change nothing. If the two halves ever disagree, this catches it.
check("aligning is idempotent", (function()
  local once = aligned([[
| a | b |
|:-:|--:|
| longer | x |
]])
  return aligned(once) == once
end)(), true)

-- ── Rendering ───────────────────────────────────────────────────────────────

check("render aligns a ragged table", renders_aligned([[
| a | b |
|---|---|
| longer | x |
]]), true)

check("render honours alignment markers", renders_aligned([[
| a | b | c |
|:--|:-:|--:|
|   1 |   2 |   3 |
]]), true)

check("render fills a separator with spaces and colons", renders_aligned([[
| aaaa | bbbb |
| :-: | --: |
| 1 | 2 |
]]), true)

check("render leaves an already padded table alone", (function()
  local buf = buffer([[
| a      | b   |
| ------ | --- |
| longer | x   |
]])
  return marks(buf)
end)(), 0)

-- Padding can only add columns, so whitespace the author already wrote counts
-- towards what a cell needs, wherever it is. None of these may assume the
-- usual "| x |" shape.

check("leading whitespace", renders_aligned([[
| asdf | wer |
|---|---|
|   1 | 2 |
]]), true)

check("trailing whitespace", renders_aligned([[
| asdf | wer |
|---|---|
| 1    | 2 |
]]), true)

check("whitespace on both sides", renders_aligned([[
| asdf | wer |
|---|---|
|   1   |  2  |
]]), true)

check("no whitespace at all", renders_aligned([[
| asdf | wer |
|---|---|
|1|2|
]]), true)

check("no whitespace around wide content", renders_aligned([[
| a | b |
|---|---|
|longer|x|
]]), true)

check("whitespace styles mixed across cells", renders_aligned([[
| asdf | wer |
|---|---|
|1 |  2|
]]), true)

check("whitespace styles mixed across rows", renders_aligned([[
|a| b |
|---|---|
|  c|d  |
| e | f |
]]), true)

-- When the author's whitespace fights the alignment — trailing blanks in a
-- right-aligned cell — the text cannot reach its edge, but the pipes must
-- still meet.
check("trailing whitespace in a right-aligned cell", renders_aligned([[
| a |
|--:|
|1   |
]]), true)

check("trailing whitespace in a centred cell", renders_aligned([[
| abc |
|:-:|
|1   |
]]), true)

-- A tab reaches the next multiple of 'tabstop' from wherever it sits, so the
-- same cell is a different width in a different place. Measured in place.

check("a tab padding a cell", renders_aligned("| asdf | wer |\n|---|---|\n|\t1\t| 2 |"), true)
check("a tab between words", renders_aligned("| a | b |\n|---|---|\n| x\ty | z |"), true)
check("a leading tab only", renders_aligned("| asdf | wer |\n|---|---|\n|\t1 | 2 |"), true)
check("tabs in several cells", renders_aligned("| a | b |\n|---|---|\n|\tx\t|\ty\t|"), true)
check("a tab in an indented table", renders_aligned("  | asdf | wer |\n  |---|---|\n  |\t1 | 2 |"), true)

-- Padding the first column moves the second, and a tab there changes width
-- with its position: cells must be measured where they will land, not where
-- they are.
check("a tab in a cell after a padded cell", renders_aligned("| aaaaaaaaaa | bbbb |\n|---|---|\n| x |\ty |"), true)

-- With 'list' on, a tab is drawn as listchars says, and strdisplaywidth()
-- follows the same window option.
check("a tab with 'list' on", (function()
  vim.wo.list = true
  local ok = renders_aligned("| asdf | wer |\n|---|---|\n|\t1 | 2 |")
  vim.wo.list = false
  return ok
end)(), true)

-- The separator is measured for what it occupies like any other row: a rule
-- longer than the content cannot be shortened by adding to it.

check("a separator wider than its content", renders_aligned([[
| a | b |
|----------|----------|
| 1 | 2 |
]]), true)

check("a separator wider, with spaces", renders_aligned([[
| a | b |
| -------- | -------- |
| 1 | 2 |
]]), true)

check("a one-dash separator", renders_aligned([[
| a | b |
|-|-|
| 1 | 2 |
]]), true)

-- Width is display width. Each of these is a plausible way to get that wrong.

check("CJK", renders_aligned("| a | b |\n|---|---|\n| 日本語 | z |"), true)
check("emoji", renders_aligned("| a | b |\n|---|---|\n| 🎉 | z |"), true)
check("combining accents", renders_aligned("| a | b |\n|---|---|\n| e\u{0301}e\u{0301} | z |"), true)
check("a zero-width-joiner emoji", renders_aligned("| a | b |\n|---|---|\n| 👨‍👩‍👧 | z |"), true)
check("right-to-left text", renders_aligned("| a | b |\n|---|---|\n| שלום | z |"), true)

-- Shapes.

check("an escaped backslash before a pipe", renders_aligned([[
| a | b | c |
|---|---|---|
| x \\| y | z |
]]), true)

check("an indented table", renders_aligned([[
  | a | b |
  |---|---|
  | 1 | 2 |
]]), true)

check("a single column", renders_aligned([[
| a |
|---|
| 1 |
]]), true)

check("empty cells", renders_aligned([[
| a | b |
|---|---|
|  |  |
]]), true)

check("no trailing pipe", renders_aligned([[
| a | b
|---|---
| 1 | 2
]]), true)

check("a very long cell", renders_aligned("| a | b |\n|---|---|\n| " .. ("x"):rep(200) .. " | y |"), true)

-- Blockquotes are container blocks, so a table inside one is still a table.

check("a table in a blockquote is found", tables([[
> | a | b |
> |---|---|
> | 1 | 2 |
]]), 1)

check("a nested blockquote", tables([[
> > | a | b |
> > |---|---|
]]), 1)

check("quoted prose with a pipe is not a table", tables([[
> use a | b for either
> and c | d for both
]]), 0)

check("a table in a blockquote renders aligned", renders_aligned([[
> | a | b |
> |---|---|
> | longer | 2 |
]]), true)

check("align keeps the blockquote marker", aligned([[
> | a | b |
> |---|---|
> | longer | 2 |
]]), text([[
> | a      | b   |
> | ------ | --- |
> | longer | 2   |
]]))

-- ── Wiring ──────────────────────────────────────────────────────────────────

check("markdown renders on open", (function()
  local buf = buffer("| a | b |\n|---|---|\n| longer | x |")
  return vim.b[buf].mdtable_on == true and marks(buf) > 0
end)(), true)

check("other filetypes are left alone", (function()
  local buf = buffer("| a | b |\n|---|---|\n| longer | x |", "lua")
  return vim.b[buf].mdtable_on == nil and marks(buf) == 0
end)(), true)

check("toggle clears and restores", (function()
  local buf = buffer("| a | b |\n|---|---|\n| longer | x |")
  md.toggle(buf)
  local off = marks(buf)
  md.toggle(buf)
  return off == 0 and marks(buf) > 0
end)(), true)

check("the file is never modified by rendering", (function()
  local buf = buffer("| a | b |\n|---|---|\n| longer | x |")
  return vim.bo[buf].modified
end)(), false)

-- Edits re-render once they settle, not once per change.
check("edits re-render after a pause", (function()
  local buf = buffer("| a | b |\n|---|---|\n| longer | x |")
  for i = 1, 20 do
    vim.api.nvim_buf_set_lines(buf, 2, 3, false, { "| " .. ("y"):rep(i) .. " | x |" })
    vim.api.nvim_exec_autocmds("TextChanged", { buffer = buf })
  end
  vim.wait(400)
  return screen_aligned(buf)
end)(), true)

-- TextChanged does not fire for a buffer that is not current, so an edit made
-- through the API while another buffer is showing must be caught up on entry.
check("a buffer edited in the background is re-rendered on entry", (function()
  local bg = buffer("| a | b |\n|---|---|\n| 1 | 2 |")
  buffer("elsewhere", "text")
  vim.api.nvim_buf_set_lines(bg, 2, 3, false, { "| a much longer value | 2 |" })
  return screen_aligned(bg)
end)(), true)

-- A deferred render runs with whatever buffer is current then; widths must
-- still follow the dirty buffer's own 'tabstop'.
check("a deferred render uses the edited buffer's tabstop", (function()
  local bg = buffer("| asdf | wer |\n|---|---|\n|\t1 | 2 |")
  vim.bo[bg].tabstop = 4
  local other = buffer("elsewhere", "text")
  vim.bo[other].tabstop = 8
  vim.api.nvim_buf_set_lines(bg, 2, 3, false, { "|\t1 | 22 |" })
  vim.api.nvim_exec_autocmds("TextChanged", { buffer = bg })
  vim.wait(300)
  -- Entering bg must not re-render (the deferred render recorded the tick),
  -- so what is checked is what the timer drew.
  return screen_aligned(bg)
end)(), true)

check("setup enables buffers that are already open", (function()
  local buf = buffer("| a | b |\n|---|---|\n| longer | x |", "rmd")
  local before = marks(buf)
  md.setup({ filetypes = { "markdown", "rmd" } })
  local after = marks(buf)
  md.setup({ filetypes = { "markdown" } })
  return before == 0 and after > 0
end)(), true)

-- ── Report ──────────────────────────────────────────────────────────────────

io.write(("\n%d passed, %d failed\n"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
