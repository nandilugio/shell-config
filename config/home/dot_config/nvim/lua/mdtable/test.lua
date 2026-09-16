-- Tests for mdtable. Run them with Neovim itself:
--
--   nvim -l lua/mdtable/test.lua
--
-- No framework: `nvim -l` runs a script directly, and a dependency whose job is
-- printing "ok" would cost more than it is worth. Exit code is 0 when all pass.
--
-- Detection is tested through scan() and cells(), where "how many tables" and
-- "how many cells" are the natural questions. Everything else goes through the
-- public surface: align() on a scratch buffer, and the padding by reading back
-- the extmarks actually placed and applying them to the buffer's own text — a
-- wrong width shows up as a crooked pipe, not an error.
--
-- Read back, never recomputed. An earlier suite asked whether the arithmetic
-- was right rather than whether anything was drawn, and passed 109 green while
-- the plugin painted nothing at all. `nvim -l` attaches no UI, so screenstring()
-- cannot tell the difference; the marks can.
--
-- Which is why torture.md, next to this file, is the other half of the suite:
-- open it in a real editor and look. Wide characters, tabs and a cell wider
-- than the window are all things these checks measure but nobody here can see,
-- and the last two bugs in those came from reading it, not from a red suite.

vim.opt.rtp:prepend(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h"))

local md = require("mdtable")
local scan, cells = md._internal.scan, md._internal.cells

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

local TABLE_SRC = "| a | b |\n|---|---|\n| longer | x |"

-- A scratch buffer holding `src`, made current, with its filetype set last so
-- the FileType autocmd sees a buffer that already has its lines.
local function buffer(src, filetype)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines(src))
  vim.api.nvim_set_current_buf(buf)
  vim.bo[buf].filetype = filetype or "markdown"
  return buf
end

-- What a buffer's rows look like once drawn: its text with the padding marks
-- inserted where they sit.
--
-- Read from the extmarks rather than off the screen with screenstring(), which
-- needs an attached UI that `nvim -l` does not have. Same marks the terminal
-- draws, one step short of the pixels.
local function drawn(buf)
  local ns = vim.api.nvim_get_namespaces().mdtable
  local out = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  local by_line = {}
  for _, m in ipairs(vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })) do
    local row, col, det = m[2] + 1, m[3], m[4]
    by_line[row] = by_line[row] or {}
    table.insert(by_line[row], { col, det.virt_text[1][1] })
  end

  for row, marks in pairs(by_line) do
    -- Back to front, so the earlier byte offsets stay valid.
    table.sort(marks, function(a, b) return a[1] > b[1] end)
    for _, m in ipairs(marks) do
      out[row] = out[row]:sub(1, m[1]) .. m[2] .. out[row]:sub(m[1] + 1)
    end
  end
  return out
end

-- Screen columns of the pipes in a drawn line. Two rows are aligned when these
-- agree; comparing widths alone would miss one cell padded too much and another
-- too little cancelling out. Measured from the display width of the prefix
-- rather than by stepping characters, because a combining accent or a joined
-- emoji is several bytes that render as one or two columns.
local function pipes(s)
  local at = {}
  for i = 1, #s do
    if s:sub(i, i) == "|" then at[#at + 1] = vim.fn.strdisplaywidth(s:sub(1, i)) end
  end
  return table.concat(at, ",")
end

-- True when every row of `buf`, as drawn, has its pipes where the first does.
local function screen_aligned(buf)
  local first
  for _, line in ipairs(drawn(buf)) do
    local p = pipes(line)
    first = first or p
    if p ~= first then return false end
  end
  return true
end

local function renders_aligned(src)
  return screen_aligned(buffer(src))
end

-- True when the buffer is drawn exactly as it is stored: no padding anywhere.
local function drawn_bare(buf)
  return table.concat(drawn(buf), "\n")
    == table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
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

-- CommonMark 4.5: a closing fence carries nothing but its marker, so a fence
-- with an info string opens a block and never closes one. Getting this wrong
-- inverts the fence state and stops every table below from rendering.
check("a fence with an info string does not close a block", tables([[
```
```lua
| a | b |
|---|---|
| 1 | 2 |
```
]]), 0)

check("a closing fence may be followed by blanks", tables([[
```
| a | b |
```

| c | d |
|---|---|
| 1 | 2 |
]]), 1)

-- Also 4.5: a backtick fence's info string may not contain a backtick, so this
-- line is not a fence and the table below it is real.
check("backticks after the run are not a fence", tables([[
``` ``
| a | b |
|---|---|
| 1 | 2 |
]]), 1)

check("a tilde fence may carry backticks", tables([[
~~~ ``
| a | b |
|---|---|
| 1 | 2 |
~~~
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
  return drawn_bare(buf)
end)(), true)

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

-- Right and centre alignment put padding BEFORE the text, which moves a tab
-- inside it and changes its width. The content measure normalises tabs for
-- exactly this reason.
check("a tab in a right-aligned cell", renders_aligned("| aaaaaaaaaa | b |\n|----------:|---|\n| x\ty | z |"), true)
check("a tab in a centred cell", renders_aligned("| aaaaaaaaaa | b |\n|:--------:|---|\n| x\ty | z |"), true)

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

-- A cell wider than the window. Widths must not depend on how much of the line
-- fits on screen: strdisplaywidth() counts the extra rows a wrapped line takes,
-- which made a long cell measure wider than it is, so its column was padded to
-- a width no other row reached.
check("a cell wider than the window", (function()
  local columns = vim.o.columns
  vim.o.columns = 80
  local ok = renders_aligned(
    "| a | b |\n|---|---|\n| " .. ("x"):rep(150) .. " | y |\n| short | z |"
  )
  vim.o.columns = columns
  return ok
end)(), true)

-- Same, through the rewrite: both halves share width(), so both were wrong.
check("align is unaffected by the window width", (function()
  local src = "| a | b |\n|---|---|\n| " .. ("x"):rep(150) .. " | y |"
  local columns = vim.o.columns
  vim.o.columns = 80
  local narrow = aligned(src)
  vim.o.columns = 400
  local wide = aligned(src)
  vim.o.columns = columns
  return narrow == wide
end)(), true)

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

-- Each row keeps its own prefix. Rewriting one row's ">" markers onto another
-- would change the text, not just its padding.
check("align keeps each row's own prefix", aligned([[
> | a | b |
>> |---|---|
> | longer | 2 |
]]), text([[
> | a      | b   |
>> | ------ | --- |
> | longer | 2   |
]]))

-- Bound globally, so in a read-only buffer with no table it must say nothing.
check("align is silent in a read-only buffer with no table", (function()
  local buf = buffer("Just prose.\nNo table here.")
  vim.bo[buf].modifiable = false
  local said = {}
  local notify = vim.notify
  vim.notify = function(msg) said[#said + 1] = msg end
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  md.align()
  vim.notify = notify
  return said
end)(), {})

check("align warns on a table it cannot write", (function()
  local buf = buffer(TABLE_SRC)
  vim.bo[buf].modifiable = false
  local said = {}
  local notify = vim.notify
  vim.notify = function(msg) said[#said + 1] = msg end
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  md.align()
  vim.notify = notify
  return #said
end)(), 1)

-- ── Wiring ──────────────────────────────────────────────────────────────────

local TABLE = "| a | b |\n|---|---|\n| longer | x |"

check("markdown is padded on open", (function()
  local buf = buffer(TABLE)
  return vim.b[buf].mdtable_on == true and screen_aligned(buf)
end)(), true)

check("other filetypes are left alone", (function()
  local buf = buffer(TABLE, "lua")
  return vim.b[buf].mdtable_on == nil and drawn_bare(buf)
end)(), true)

check("the buffer is never modified by drawing", (function()
  local buf = buffer(TABLE)
  drawn(buf)
  return vim.bo[buf].modified
end)(), false)

-- Typing fires TextChanged, which re-pads.
check("an edit is picked up", (function()
  local buf = buffer(TABLE)
  vim.api.nvim_buf_set_lines(buf, 2, 3, false, { "| a much longer value | x |" })
  vim.api.nvim_exec_autocmds("TextChanged", { buffer = buf })
  return screen_aligned(buf)
end)(), true)

-- A buffer edited while another is current gets no TextChanged, so it catches
-- up when a window shows it.
check("an edit from another buffer is picked up on entry", (function()
  local bg = buffer(TABLE)
  buffer("elsewhere", "text")
  vim.api.nvim_buf_set_lines(bg, 2, 3, false, { "| a much longer value | x |" })
  vim.api.nvim_set_current_buf(bg)
  vim.api.nvim_exec_autocmds("BufWinEnter", { buffer = bg })
  return screen_aligned(bg)
end)(), true)

-- Widths follow 'tabstop', which is the buffer's own wherever it is drawn.
-- Widths follow the measured buffer's 'tabstop', not whichever buffer happens
-- to be current when the render runs.
check("tabstop comes from the buffer being rendered", (function()
  local buf = buffer("| a | b |\n|---|---|\n|\tx | y |")
  vim.bo[buf].tabstop = 4
  local narrow = drawn(buf)

  local other = buffer("elsewhere", "text")
  vim.bo[other].tabstop = 16
  vim.b[buf].mdtable_tick = nil
  md._internal.render(buf)

  return table.concat(drawn(buf), "\n") == table.concat(narrow, "\n")
end)(), true)

check("a change to tabstop is picked up", (function()
  local buf = buffer("| asdf | wer |\n|---|---|\n|\t1 | 2 |")
  vim.bo[buf].tabstop = 4
  local at4 = screen_aligned(buf)
  vim.bo[buf].tabstop = 8
  return at4 and screen_aligned(buf)
end)(), true)

check("a change to list is picked up", (function()
  local buf = buffer("| asdf | wer |\n|---|---|\n|\t1 | 2 |")
  vim.wo.list = true
  local listed = screen_aligned(buf)
  vim.wo.list = false
  return listed and screen_aligned(buf)
end)(), true)

-- ── Turning it off and on ───────────────────────────────────────────────────

check("toggle clears and restores", (function()
  local buf = buffer(TABLE)
  md.toggle(buf)
  local off = drawn_bare(buf)
  md.toggle(buf)
  return off and screen_aligned(buf)
end)(), true)

-- b:mdtable_on survives a reload, so re-detecting the filetype must not undo
-- what the user asked for.
check("re-detecting the filetype keeps a toggle off", (function()
  local buf = buffer(TABLE)
  md.disable(buf)
  vim.bo[buf].filetype = "markdown"
  return vim.b[buf].mdtable_on == false and drawn_bare(buf)
end)(), true)

check("re-detecting the filetype keeps a toggle on", (function()
  local buf = buffer(TABLE, "text")
  md.enable(buf)
  vim.bo[buf].filetype = "text"
  return vim.b[buf].mdtable_on == true and screen_aligned(buf)
end)(), true)

-- ...but a filetype the user never spoke for follows the filetype, in both
-- directions.
check("leaving the filetype list stops the padding", (function()
  local buf = buffer(TABLE)
  local on = screen_aligned(buf)
  vim.bo[buf].filetype = "text"
  return on and vim.b[buf].mdtable_on == nil and drawn_bare(buf)
end)(), true)

check("entering the filetype list starts it", (function()
  local buf = buffer(TABLE, "text")
  local off = drawn_bare(buf)
  vim.bo[buf].filetype = "markdown"
  return off and vim.b[buf].mdtable_on == true and screen_aligned(buf)
end)(), true)

check("setup chooses the filetypes", (function()
  md.setup({ filetypes = { "markdown", "rmd" } })
  local opted = buffer(TABLE, "rmd")
  local on = screen_aligned(opted)
  md.setup({ filetypes = { "markdown" } })
  local plain = buffer(TABLE, "rmd")
  return on and drawn_bare(plain)
end)(), true)

-- ── Insert mode ─────────────────────────────────────────────────────────────
-- Padding shifts the columns under the cursor, so it must not be drawn while
-- typing. It is a per-frame check on the mode rather than a pair of
-- autocommands, which is what makes every way out of insert mode work,
-- including <C-c>, for which Neovim fires no InsertLeave.
--
-- `nvim -l` has no main loop, so insert mode cannot be entered here: neither
-- feedkeys() nor nvim_input() changes the mode. The gate is checked directly
-- instead, with mode() stubbed — one step short of the keystroke.

local function drawn_in_mode(buf, mode)
  local real = vim.fn.mode
  vim.fn.mode = function() return mode end
  md._internal.render(buf)
  local padded = not drawn_bare(buf)
  vim.fn.mode = real
  md._internal.render(buf)
  return padded
end

check("no padding while typing", drawn_in_mode(buffer(TABLE), "i"), false)
check("padding in normal mode", drawn_in_mode(buffer(TABLE), "n"), true)
check("padding in visual mode", drawn_in_mode(buffer(TABLE), "v"), true)
check("padding in replace mode", drawn_in_mode(buffer(TABLE), "R"), true)

-- Only the buffer being typed in loses its padding; one shown elsewhere keeps
-- it, which is why the check is "is this the current buffer".
check("another buffer keeps its padding while one is in insert", (function()
  local other = buffer(TABLE)
  buffer(TABLE) -- now current
  return drawn_in_mode(other, "i")
end)(), true)

-- ── Report ──────────────────────────────────────────────────────────────────

io.write(("\n%d passed, %d failed\n"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
