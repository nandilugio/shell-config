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
-- Both measure with the same code, so both put the pipes in the same columns.
-- They differ in what they may do to get there, and only in one way: render may
-- only add, so the author's whitespace stays where it is, while align rebuilds
-- each cell from its trimmed text and so also normalises what sits inside the
-- columns. Pressing ",t" on a table that already looks aligned can therefore
-- shift text — to where the alignment says it belongs.
--
-- Rendering adds columns and can never take them away, and that shapes most of
-- what follows: a column is never narrower than any cell already is, and
-- whitespace the author wrote counts towards the padding.
--
-- The padding is stored extmarks, placed for the whole buffer and replaced when
-- something that could change them happens. Drawing it per frame instead would
-- be tidier — nothing kept, so nothing to go stale — but is not available here:
-- an ephemeral mark cannot carry inline virtual text. So the state is stored,
-- and everything that can stale it has to be caught. "Drawing" at the bottom
-- lists those events and why each one is there.
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
local ROW = PREFIX .. "|"

local function prefix_of(line)
  return line:match(PREFIX)
end

local function is_row(line)
  return line:find(ROW) ~= nil
end

-- A fence line, as { marker, closing }: three or more backticks or tildes,
-- optionally indented. CommonMark 4.5 says a closing fence carries nothing but
-- the marker, and that a backtick fence's info string may not contain a
-- backtick — so ```lua opens a block but never closes one, and ``` `` is not a
-- fence at all. Pipes inside a block are content: shell output, ASCII art, a
-- table being shown as source.
local function fence_at(line)
  local marker, info = line:match(PREFIX .. "([`~][`~][`~]+)(.*)$")
  if not marker then return nil end
  if marker:sub(1, 1) == "`" and info:find("`") then return nil end
  return marker, info:find("%S") == nil
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

-- A cell of the |---|:--:| row under the header: dashes, with a colon allowed
-- at either end. That row is what makes a run of rows a table, and its colons
-- carry the column alignment.
local function is_delimiter(cell)
  return cell.text:find("^%s*:?%-+:?%s*$") ~= nil
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

-- Display width, not byte length: CJK and emoji take two cells. `at` is the
-- screen column the text starts on and `ts` the buffer's 'tabstop', both of
-- which matter only for tabs, since a tab reaches the next multiple of ts from
-- wherever it sits.
--
-- Tabs are expanded here and the rest measured with nvim_strwidth, rather than
-- handing the whole string to strdisplaywidth. strdisplaywidth is relative to
-- the window: past 'columns' it counts the extra rows a wrapped line takes, so
-- a cell wider than the window measures too wide and its column comes out
-- padded to a width nothing else reaches. nvim_strwidth has no such notion —
-- it is the width of the text, which is what a column is sized by.
local function width(s, at, ts)
  if not s:find("\t", 1, true) then return vim.api.nvim_strwidth(s) end

  local col = at
  for part, tab in s:gmatch("([^\t]*)(\t?)") do
    col = col + vim.api.nvim_strwidth(part)
    if tab == "\t" then col = col + ts - (col % ts) end
  end
  return col - at
end

-- What a cell's text needs once padded: trimmed, each tab as the one space
-- align() will write in its place. A tab inside the text is normalised for the
-- same reason align() rewrites it — its width depends on where it lands, and
-- padding moves it, so it cannot be measured once and stay true.
local function content_width(text)
  return vim.api.nvim_strwidth((vim.trim(text):gsub("\t", " ")))
end

-- ── Finding tables ──────────────────────────────────────────────────────────

-- The lines first..last all start with a pipe. Returns a table if they form
-- one, else nil. A table is { first, last, sep, rows, widths, align }, where
-- rows[lnum] holds that line's cells and everything is 1-based and inclusive.
-- `ts` is the 'tabstop' of the buffer the lines came from.
local function table_at(lines, first, last, ts)
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

  -- A column is as wide as its widest content, and never narrower than what any
  -- cell in it already occupies: render can only add columns, so a column sized
  -- by content alone would ask an over-padded cell to shrink. The separator
  -- counts only for what it occupies — its dashes are not content — and every
  -- column needs three, or a narrow one renders as no rule at all.
  --
  -- Columns are measured left to right, each cell at the screen column it will
  -- have once the columns before it are padded, because a tab's width depends
  -- on where it lands. Text inside a cell is measured from the column its text
  -- starts at rather than the cell's, since padding inserted before the text
  -- moves any tab within it. Both measures stay on the cell for draw_row().
  local widths, at, ncols = {}, {}, 0
  for n = first, last do
    at[n] = width(prefix_of(lines[n]), 0, ts) + 1
    ncols = math.max(ncols, #rows[n])
  end
  for col = 1, ncols do
    local w = 3
    for n = first, last do
      local cell = rows[n][col]
      if cell then
        cell.occupied = width(cell.text, at[n], ts)
        cell.content = n ~= sep and content_width(cell.text) or 0
        w = math.max(w, cell.content, cell.occupied - 2)
      end
    end
    widths[col] = w
    for n = first, last do at[n] = at[n] + w + 3 end -- cell, its blanks, its pipe
  end

  return {
    first = first,
    last = last,
    sep = sep,
    rows = rows,
    widths = widths,
    align = alignments(rows[sep]),
    tabstop = ts,
  }
end

-- Every table in `lines`, in order. Runs of consecutive rows are candidates;
-- table_at() decides. Fenced code blocks are skipped whole — the one thing a
-- naive line scan would get wrong that a parser would not.
local function scan(lines, ts)
  ts = ts or vim.bo.tabstop
  local tables, fence, i = {}, nil, 1
  while i <= #lines do
    local marker, closing = fence_at(lines[i])
    if fence then
      -- A block closes on a bare fence of the same character, at least as long.
      if closing and marker:sub(1, 1) == fence:sub(1, 1) and #marker >= #fence then fence = nil end
      i = i + 1
    elseif marker then
      fence = marker
      i = i + 1
    elseif is_row(lines[i]) then
      local first = i
      while i <= #lines and is_row(lines[i]) do i = i + 1 end
      local t = table_at(lines, first, i - 1, ts)
      if t then tables[#tables + 1] = t end
    else
      i = i + 1
    end
  end
  return tables
end

-- ── Padding ─────────────────────────────────────────────────────────────────

-- How `slack` columns of padding split around a cell's text.
local function pad_for(align, slack)
  if align == "right" then return slack, 0 end
  if align == "center" then
    local left = math.floor(slack / 2)
    return left, slack - left
  end
  return 0, slack
end

-- The padding one row needs, as a list of { col, text, hl } in byte order:
-- dashes on the separator, spaces elsewhere. Pure, so the same function serves
-- the drawing below and the tests.
--
-- This is the half that may only ADD. Whatever the author wrote stays exactly
-- where it is, so a cell written "|   3 |" keeps those three spaces and gets
-- the rest of what it needs around them. That puts the pipes in the right
-- columns without touching the buffer, which is the whole point — but it
-- cannot move the text itself. build_row() below can, and does.
local function padding(t, lnum)
  local out, at = {}, nil
  for n, cell in ipairs(t.rows[lnum]) do
    local w = t.widths[n]
    at = at or cell.from - 1

    if lnum == t.sep then
      -- Fill goes before a trailing colon, so the marker stays at the edge it
      -- marks, and before any blank after it. Same group as the real dashes.
      local need = w + 2 - cell.occupied
      if need > 0 then
        local head = cell.text:match("^(.-):?%s*$")
        out[#out + 1] = { cell.from - 1 + #head, ("-"):rep(need), "@punctuation.special.markdown" }
      end
    else
      -- Whitespace the author already wrote counts towards the side it is on:
      -- "|   1 |" is text pushed right, and what it still needs goes on the
      -- right. When that whitespace fights the alignment the text cannot reach
      -- its edge, but the pipes still meet.
      local lead = cell.text:match("^%s*")
      local left = pad_for(t.align[n], w - cell.content)
      local before = math.max(math.min(left + 1 - width(lead, at, t.tabstop), w + 2 - cell.occupied), 0)
      if before > 0 then out[#out + 1] = { cell.from - 1 + #lead, (" "):rep(before) } end

      -- Measured with `before` in place, not from cell.occupied: padding ahead
      -- of the text moves any tab inside it, and a tab's width depends on where
      -- it lands. Everything still short of the column goes on the right.
      local after = w + 2 - width((" "):rep(before) .. cell.text, at, t.tabstop)
      if after > 0 then out[#out + 1] = { cell.stop - 1, (" "):rep(after) } end
    end

    at = at + w + 3
  end
  return out
end

-- ── Rewriting ───────────────────────────────────────────────────────────────

-- One row of a table as align() writes it: "| a | b |", cells padded to the
-- column widths, the separator rebuilt from the parsed alignment so a ragged
-- |:-|--:| comes out even. Rows short of the header gain empty cells; nothing
-- is ever dropped, since the widths span the longest row.
--
-- This is the half that REWRITES, so unlike padding() it is not confined to
-- adding: the cell is rebuilt from its trimmed text, which puts that text
-- where the alignment says rather than wherever the author's whitespace left
-- it. Both halves agree on the columns — the pipes land in the same places —
-- and this one additionally normalises what sits inside them, which is what
-- makes ",t" worth pressing on a table that already looks aligned.
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

-- Pad the table under the cursor in the buffer. One nvim_buf_set_lines call, so
-- one undo step. Outside a table it does nothing, so it can be bound globally.
function M.align()
  local buf = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)[1]
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  for _, t in ipairs(scan(lines, vim.bo[buf].tabstop)) do
    if cursor >= t.first and cursor <= t.last then
      -- Checked here rather than on entry: with nothing to align there is
      -- nothing to complain about, and this is bound globally.
      if not vim.bo[buf].modifiable then
        vim.notify("mdtable: buffer is not modifiable", vim.log.levels.WARN)
        return
      end
      -- Each row keeps its own prefix. A table whose rows sit at different
      -- indents or blockquote depths is unusual, but rewriting one row's ">"
      -- markers onto another would change the text, not just its padding.
      local out = {}
      for n = t.first, t.last do out[#out + 1] = prefix_of(lines[n]) .. build_row(t, n) end
      vim.api.nvim_buf_set_lines(buf, t.first - 1, t.last, false, out)
      return
    end
  end
end

-- ── State ───────────────────────────────────────────────────────────────────

-- b:mdtable_on drives the drawing below. It is set either by the filetype or
-- by the user, and b:mdtable_ft records what the filetype last made it: while
-- the two agree, nobody has overridden anything and the filetype still decides.
-- Once they differ the user has spoken, and re-detecting the filetype — :e,
-- autoread, an ftplugin running again — leaves their choice alone.
local render -- defined under "Drawing"; the padding is redrawn whenever this changes

local function choose(buf, on)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  vim.b[buf].mdtable_on = on
  render(buf)
end

function M.enable(buf)
  choose(buf or vim.api.nvim_get_current_buf(), true)
end

function M.disable(buf)
  choose(buf or vim.api.nvim_get_current_buf(), false)
end

function M.toggle(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  local on = not vim.b[buf].mdtable_on
  choose(buf, on)
  vim.notify("Markdown table alignment " .. (on and "on" or "off"))
end

-- Render automatically in these filetypes.
--
--   require("mdtable").setup({ filetypes = { "markdown", "rmd" } })
--
-- Optional: the default is useful as it is. A filetype that contains markdown
-- is not markdown — vimwiki, for one, is written more than read, and inline
-- padding moves the columns under the cursor — so such filetypes are opted in
-- here deliberately rather than assumed.
function M.setup(opts)
  config = vim.tbl_extend("force", config, opts or {})
end

-- Listening on every filetype, not just the configured ones, is what lets a
-- buffer that leaves the list stop drawing as well as one that joins it start.
vim.api.nvim_create_autocmd("FileType", {
  group = group,
  callback = function(ev)
    local b = vim.b[ev.buf]
    if b.mdtable_on ~= b.mdtable_ft then return end -- the user has overridden
    local on = vim.tbl_contains(config.filetypes, ev.match) or nil
    b.mdtable_on, b.mdtable_ft = on, on
    render(ev.buf)
  end,
})

vim.api.nvim_create_user_command("MdTableToggle", function() M.toggle() end, {
  desc = "Toggle markdown table alignment (display only)",
})

vim.api.nvim_create_user_command("MdTableAlign", function() M.align() end, {
  desc = "Pad the markdown table under the cursor in the buffer",
})

-- ── Drawing ─────────────────────────────────────────────────────────────────
--
-- The padding is stored extmarks, placed for the whole buffer and replaced when
-- something that could change them happens.
--
-- Not a decoration provider, which would be the tidier shape — per frame, only
-- what is visible, nothing to invalidate. Its marks have to be `ephemeral`, and
-- an ephemeral mark cannot do inline virtual text: nvim_buf_set_extmark only
-- sets MT_FLAG_DECOR_VIRT_TEXT_INLINE on the stored path (api/extmark.c), and
-- that flag is what makes the renderer reserve the columns. An ephemeral inline
-- mark is accepted, placed, and silently not drawn. Providers suit overlays,
-- end-of-line text and highlights; inserting columns is not available to them.
--
-- So the state is stored, and everything that can stale it has to be caught.
-- What follows is that list, and each entry is a bug somebody found:
--
--   TextChanged, InsertLeave   the text changed
--   BufWinEnter, WinScrolled   a window is showing it that may not have been
--   OptionSet                  'tabstop' & co. change how wide things are
--   InsertEnter                padding must go away while typing
--   ModeChanged i:*            ...and come back, including via <C-c>, which
--                              fires no InsertLeave
--
-- b:mdtable_tick records the buffer and options as of the last render, so a
-- re-render that would change nothing does nothing.

-- Everything a render depends on: the text, and 'tabstop', which is the only
-- option that changes how wide anything is now that widths are measured with
-- nvim_strwidth rather than against a window.
local function state_of(buf)
  return vim.api.nvim_buf_get_changedtick(buf) .. "\0" .. vim.bo[buf].tabstop
end

local function clear(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  vim.b[buf].mdtable_tick = nil
end

-- Padding must not show in the buffer being typed in: it shifts the columns, so
-- the cursor would sit away from the character under it.
local function typing_in(buf)
  return vim.api.nvim_get_current_buf() == buf and vim.fn.mode():sub(1, 1) == "i"
end

function render(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(buf) then return end
  if not vim.b[buf].mdtable_on or typing_in(buf) then return clear(buf) end

  local state = state_of(buf)
  if vim.b[buf].mdtable_tick == state then return end
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  -- The buffer's own 'tabstop', not whichever buffer happens to be current: a
  -- render can be triggered from anywhere.
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  for _, t in ipairs(scan(lines, vim.bo[buf].tabstop)) do
    for lnum = t.first, t.last do
      for _, p in ipairs(padding(t, lnum)) do
        vim.api.nvim_buf_set_extmark(buf, ns, lnum - 1, p[1], {
          virt_text = { { p[2], p[3] } },
          virt_text_pos = "inline",
          right_gravity = false,
        })
      end
    end
  end
  vim.b[buf].mdtable_tick = state
end

-- Everything that can change what should be drawn, or where.
vim.api.nvim_create_autocmd({
  "TextChanged", -- the text changed
  "InsertLeave", -- ...including on the way out of insert
  "BufWinEnter", -- a window is showing this buffer
  "WinEnter", -- ...or has become current
  "OptionSet", -- 'tabstop' and friends change the widths
}, {
  group = group,
  pattern = "*",
  callback = function(ev) render(ev.buf) end,
})

-- Clear while typing, restore on the way out. ModeChanged rather than
-- InsertLeave: Neovim fires no InsertLeave for i_CTRL-C.
vim.api.nvim_create_autocmd("ModeChanged", {
  group = group,
  pattern = { "*:i*", "i*:*" },
  callback = function(ev) render(ev.buf) end,
})

-- A buffer edited while another is current gets no TextChanged, so catch up
-- when it is shown or entered; the tick check makes that free when nothing
-- moved. WinScrolled covers a window that was already showing it.
vim.api.nvim_create_autocmd("WinScrolled", {
  group = group,
  callback = function() render(vim.api.nvim_get_current_buf()) end,
})

-- For test.lua, which applies the padding to the text itself rather than
-- reading a screen: `nvim -l` attaches no UI, so nothing is ever drawn. Not API.
M._internal = { scan = scan, cells = cells, padding = padding, render = render, typing_in = typing_in }

return M
