-- mdtable: readable markdown tables without touching the file.
--
-- A markdown table is only aligned if somebody padded it. Most are not:
--
--   | Name | Description | Status |
--   |---|---|---|
--   | foo | a thing | ok |
--   | a much longer name | short | pending |
--
-- Two ways out, because reading and writing are different problems:
--
--   render  (automatic)  inline virtual text pads the columns on screen. The
--                        file is untouched, so it is safe on anything you are
--                        only reading.
--   align   (on demand)  pads the table under the cursor in the buffer. A real,
--                        undoable edit, for files you own.
--
-- Both measure with the same code, so what render draws is what align writes.
--
-- Rendering adds columns and can never take them away, and that shapes most of
-- what follows: a column is never narrower than any cell already is, whitespace
-- the author wrote counts towards the padding, and the cursor sits at a
-- different screen column than the character under it. That last one is fine
-- while reading and confusing while typing, so render clears itself in insert
-- mode and comes back on the way out.
--
-- Tables are found by scanning lines, not parsing. The syntax is regular enough
-- that a parser would add only code-block awareness, which scan() covers by
-- tracking fences, and a line scan works where treesitter cannot: on a machine
-- with no compiler. README.md lists the limits that follow from that.
--
-- Creates no keymaps. README.md lists the functions to bind.

local M = {}

local ns = vim.api.nvim_create_namespace("mdtable")
local group = vim.api.nvim_create_augroup("mdtable", { clear = true })

-- Deliberately only "markdown". A filetype that happens to contain markdown
-- (vimwiki, for one) is somebody else's call to make, through setup().
local config = { filetypes = { "markdown" } }

-- ── Rows ────────────────────────────────────────────────────────────────────

-- What may come before a row's first pipe: indentation, and the ">" markers of
-- a blockquote, since a table inside one is still a table.
local PREFIX = "^[%s>]*"
local ROW, TICKS, TILDES = PREFIX .. "|", PREFIX .. "(```+)", PREFIX .. "(~~~+)"

local function is_row(line)
  return line:find(ROW) ~= nil
end

-- A fence opens or closes a code block: ``` or ~~~, three or more, optionally
-- indented, with an info string after it. Pipes inside one are content —
-- shell output, ASCII art, a table being shown as source.
local function fence_at(line)
  return line:match(TICKS) or line:match(TILDES)
end

-- A cell of the |---|:--:| row under the header: dashes, with a colon allowed
-- at either end. That row is what makes a run of rows a table, and its colons
-- carry the column alignment.
local function is_delimiter(cell)
  return cell.text:find("^%s*:?%-+:?%s*$") ~= nil
end

-- Split a row into cells. Each is { text, from, stop }: the text between two
-- pipes and, as 1-based byte indices, where it starts and where the pipe that
-- closes it sits (one past the end when the row has no trailing pipe).
--
-- A backslash escapes whatever follows it, itself included, so the pair is
-- skipped together. That is what keeps "\\|" right: an escaped backslash, then
-- a pipe that still separates cells.
local function cells(line)
  local out, from, i = {}, nil, 1
  while true do
    local j = line:find("[\\|]", i)
    if not j then break end
    if line:sub(j, j) == "\\" then
      i = j + 2
    else
      if from then out[#out + 1] = { text = line:sub(from, j - 1), from = from, stop = j } end
      from, i = j + 1, j + 1
    end
  end
  -- Text after the last pipe is a cell only if it holds something: a row
  -- written |a|b| ends in a pipe, and what follows it is not a column.
  if from and line:sub(from):find("%S") then
    out[#out + 1] = { text = line:sub(from), from = from, stop = #line + 1 }
  end
  return out
end

-- Column alignment from the separator's cells: :--- left, ---: right, :---:
-- centre. "left" and "none" lay text out the same way and differ only in
-- whether the author wrote the colon, which align() puts back.
local function alignments(sep)
  local out = {}
  for i, cell in ipairs(sep) do
    local s = vim.trim(cell.text)
    local l, r = s:sub(1, 1) == ":", s:sub(-1) == ":"
    out[i] = (l and r and "center") or (r and "right") or (l and "left") or "none"
  end
  return out
end

-- ── Widths ──────────────────────────────────────────────────────────────────

-- Display width, not byte length: CJK and emoji take two cells, and a tab takes
-- however many reach the next multiple of 'tabstop' from where it sits, which
-- is why `at`, the screen column the text starts on, is part of the measure.
local function width(s, at)
  return vim.fn.strdisplaywidth(s, at or 0)
end

-- What a cell's text needs once padded: trimmed, each tab as the one space
-- align() will write in its place.
local function content_width(text)
  return width((vim.trim(text):gsub("\t", " ")))
end

-- Screen column just past a row's prefix and opening pipe.
local function start_column(line)
  return width(line:match(PREFIX)) + 1
end

-- ── Finding tables ──────────────────────────────────────────────────────────

-- The lines first..last all start with a pipe. Returns a table if they form
-- one, else nil. A table is { first, last, sep, rows, widths, align }, where
-- rows[lnum] holds that line's cells and everything is 1-based and inclusive.
local function table_at(lines, first, last)
  if last == first then return nil end
  local rows = {}
  for n = first, last do rows[n] = cells(lines[n]) end

  -- The guards are what a grammar would enforce: the second row is the
  -- separator, every cell of it a delimiter, with as many cells as the header.
  -- That last one is what tells a table from lines that merely start with a
  -- pipe.
  local sep = first + 1
  if #rows[sep] == 0 or #rows[sep] ~= #rows[first] then return nil end
  for _, cell in ipairs(rows[sep]) do
    if not is_delimiter(cell) then return nil end
  end

  -- A column is as wide as its widest content, and never narrower than what
  -- any cell in it already occupies: render can only add columns, so a column
  -- sized by content alone would ask an over-padded cell to shrink. The
  -- separator counts only for what it occupies — its dashes are not content —
  -- and every column needs three, or a narrow one renders as no rule at all.
  --
  -- Columns are measured left to right, each cell at the screen column it will
  -- have once the columns before it are padded. That is exact, since no cell
  -- ends up wider than its column, and it matters for tabs, whose width depends
  -- on where they land. Both measures stay on the cell for render_row().
  local widths, starts, ncols = {}, {}, 0
  for n = first, last do
    starts[n] = start_column(lines[n])
    ncols = math.max(ncols, #rows[n])
  end
  for col = 1, ncols do
    local w = 3
    for n = first, last do
      local cell = rows[n][col]
      if cell then
        cell.occupied = width(cell.text, starts[n])
        cell.content = n ~= sep and content_width(cell.text) or 0
        w = math.max(w, cell.content, cell.occupied - 2)
      end
    end
    widths[col] = w
    for n = first, last do starts[n] = starts[n] + w + 3 end -- cell, its blanks, its pipe
  end

  return { first = first, last = last, sep = sep, rows = rows, widths = widths, align = alignments(rows[sep]) }
end

-- Every table in `lines`, in order. Runs of consecutive rows are candidates;
-- table_at() decides. Fenced code blocks are skipped whole — the one thing a
-- naive line scan would get wrong that a parser would not.
local function scan(lines)
  local tables, fence, i = {}, nil, 1
  while i <= #lines do
    local f = fence_at(lines[i])
    if fence then
      -- A block closes on a fence of the same character, at least as long.
      if f and f:sub(1, 1) == fence:sub(1, 1) and #f >= #fence then fence = nil end
      i = i + 1
    elseif f then
      fence = f
      i = i + 1
    elseif is_row(lines[i]) then
      local first = i
      while i <= #lines and is_row(lines[i]) do i = i + 1 end
      local t = table_at(lines, first, i - 1)
      if t then tables[#tables + 1] = t end
    else
      i = i + 1
    end
  end
  return tables
end

-- ── Rendering ───────────────────────────────────────────────────────────────

-- How `slack` columns of padding split around a cell's text.
local function pad_for(align, slack)
  if align == "right" then return slack, 0 end
  if align == "center" then
    local left = math.floor(slack / 2)
    return left, slack - left
  end
  return 0, slack
end

local function mark(buf, lnum, col, text, hl)
  vim.api.nvim_buf_set_extmark(buf, ns, lnum - 1, col, {
    virt_text = { { text, hl } },
    virt_text_pos = "inline",
  })
end

-- Pad one row with inline virtual text so its pipes land where the widths say:
-- dashes on the separator, spaces elsewhere.
local function render_row(buf, lnum, line, t)
  local at = start_column(line)
  for n, cell in ipairs(t.rows[lnum]) do
    local w = t.widths[n]
    local need = w + 2 - cell.occupied -- never negative: the column was sized to fit

    if need > 0 and lnum == t.sep then
      -- Fill goes before a trailing colon, so the marker stays at the edge it
      -- marks, and before any blank after it. Same group as the real dashes.
      local head = cell.text:match("^(.-):?%s*$")
      mark(buf, lnum, cell.from - 1 + #head, ("-"):rep(need), "@punctuation.special.markdown")
    elseif need > 0 then
      -- Whitespace the author already wrote counts towards the side it is on:
      -- "|   1 |" is text pushed right, and what it still needs goes on the
      -- right. `before` is capped at `need` because that whitespace cannot be
      -- taken back — when it fights the alignment, the pipes still line up and
      -- the text sits where it can.
      local lead = cell.text:match("^%s*")
      local left = pad_for(t.align[n], w - cell.content)
      local before = math.min(math.max(left + 1 - width(lead, at), 0), need)
      if before > 0 then mark(buf, lnum, cell.from - 1 + #lead, (" "):rep(before)) end
      if need > before then mark(buf, lnum, cell.stop - 1, (" "):rep(need - before)) end
    end

    at = at + w + 3
  end
end

-- b:mdtable_tick is the buffer's changedtick as of its last render, and nil
-- when the marks are gone. A render finding it unchanged has nothing to do,
-- which is what makes re-entering a buffer, or leaving insert mode without
-- typing, free.
local function clear(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  vim.b[buf].mdtable_tick = nil
end

local function render(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  if not vim.b[buf].mdtable_on then return clear(buf) end
  local tick = vim.api.nvim_buf_get_changedtick(buf)
  if vim.b[buf].mdtable_tick == tick then return end

  clear(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  -- Widths follow 'tabstop' and 'list', which are read from whatever buffer and
  -- window are current — not necessarily this one, when a render was deferred.
  vim.api.nvim_buf_call(buf, function()
    for _, t in ipairs(scan(lines)) do
      for n = t.first, t.last do render_row(buf, n, lines[n], t) end
    end
  end)
  vim.b[buf].mdtable_tick = tick
end

-- ── Rewriting ───────────────────────────────────────────────────────────────

-- One row of a table as align() writes it: "| a | b |", cells padded to the
-- column widths, the separator rebuilt from the parsed alignment so a ragged
-- |:-|--:| comes out even. Rows short of the header gain empty cells; nothing
-- is ever dropped, since the widths span the longest row.
local function build_row(t, lnum)
  local out = {}
  for n, w in ipairs(t.widths) do
    local cell = t.rows[lnum][n]
    local align = t.align[n] or "none"
    if lnum == t.sep then
      local l = (align == "left" or align == "center") and ":" or ""
      local r = (align == "right" or align == "center") and ":" or ""
      out[n] = l .. ("-"):rep(w - #l - #r) .. r
    else
      local text = cell and (vim.trim(cell.text):gsub("\t", " ")) or ""
      local before, after = pad_for(align, w - (cell and cell.content or 0))
      out[n] = (" "):rep(before) .. text .. (" "):rep(after)
    end
  end
  return "| " .. table.concat(out, " | ") .. " |"
end

-- Pad the table under the cursor in the buffer. One nvim_buf_set_lines call,
-- so one undo step. Outside a table it does nothing, so it can be bound
-- globally.
function M.align()
  local buf = vim.api.nvim_get_current_buf()
  if not vim.bo[buf].modifiable then
    vim.notify("mdtable: buffer is not modifiable", vim.log.levels.WARN)
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(0)[1]
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  for _, t in ipairs(scan(lines)) do
    if cursor >= t.first and cursor <= t.last then
      -- Keep the prefix: a table inside a list item or a blockquote is part
      -- of it. The first row's, for every row, so the result lines up.
      local prefix, out = lines[t.first]:match(PREFIX), {}
      for n = t.first, t.last do out[#out + 1] = prefix .. build_row(t, n) end
      vim.api.nvim_buf_set_lines(buf, t.first - 1, t.last, false, out)
      render(buf)
      return
    end
  end
end

-- ── State ───────────────────────────────────────────────────────────────────

function M.enable(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  vim.b[buf].mdtable_on = true
  render(buf)
end

function M.disable(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  vim.b[buf].mdtable_on = false
  clear(buf)
end

function M.toggle(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if vim.b[buf].mdtable_on then M.disable(buf) else M.enable(buf) end
  vim.notify("Markdown table alignment " .. (vim.b[buf].mdtable_on and "on" or "off"))
end

-- Render automatically in these filetypes, now and as they open.
--
--   require("mdtable").setup({ filetypes = { "markdown", "rmd" } })
--
-- Optional: the default is useful as it is. A filetype that contains markdown
-- is not markdown — vimwiki, for one, is written more than read, and inline
-- padding moves the columns under the cursor — so such filetypes are opted in
-- here deliberately rather than assumed.
function M.setup(opts)
  config = vim.tbl_extend("force", config, opts or {})

  vim.api.nvim_clear_autocmds({ group = group, event = "FileType" })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = config.filetypes,
    callback = function(ev) M.enable(ev.buf) end,
  })

  -- Buffers already open: setup() often runs after the first file has loaded.
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.tbl_contains(config.filetypes, vim.bo[buf].filetype) then
      M.enable(buf)
    end
  end
end

-- ── Wiring ──────────────────────────────────────────────────────────────────

-- A render walks the whole buffer, about 10ms on a 2000-row table: fine once,
-- too slow on every step of a macro. Changes mark their buffer dirty and
-- restart one shared timer; when it fires, every dirty buffer is rendered. One
-- timer, reused, so nothing leaks, and a buffer changed and left within the
-- delay still gets its turn.
local dirty, timer = {}, assert(vim.uv.new_timer())

local function render_soon(buf)
  dirty[buf] = true
  timer:start(150, 0, vim.schedule_wrap(function()
    local bufs = dirty
    dirty = {}
    for b in pairs(bufs) do render(b) end
  end))
end

vim.api.nvim_create_autocmd("TextChanged", {
  group = group,
  callback = function(ev)
    if vim.b[ev.buf].mdtable_on then render_soon(ev.buf) end
  end,
})

-- TextChanged fires only for the current buffer, so a buffer edited while
-- another is current — by the LSP, :bufdo, a plugin — is stale until it is
-- looked at. Catch up on the way in.
vim.api.nvim_create_autocmd("BufEnter", {
  group = group,
  callback = function(ev)
    if vim.b[ev.buf].mdtable_on then render(ev.buf) end
  end,
})

-- Inline padding moves the real columns under the cursor, so it goes away
-- while typing and comes straight back on the way out.
vim.api.nvim_create_autocmd("InsertEnter", {
  group = group,
  callback = function(ev)
    if vim.b[ev.buf].mdtable_on then clear(ev.buf) end
  end,
})

vim.api.nvim_create_autocmd("InsertLeave", {
  group = group,
  callback = function(ev)
    if vim.b[ev.buf].mdtable_on then render(ev.buf) end
  end,
})

vim.api.nvim_create_user_command("MdTableToggle", function() M.toggle() end, {
  desc = "Toggle markdown table alignment (display only)",
})

vim.api.nvim_create_user_command("MdTableAlign", function() M.align() end, {
  desc = "Pad the markdown table under the cursor in the buffer",
})

M.setup()

-- The pure functions, for test.lua. Not API.
M._internal = { scan = scan, cells = cells }

return M
