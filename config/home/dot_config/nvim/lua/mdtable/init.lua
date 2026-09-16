-- mdtable: readable markdown tables without touching the file.
--
-- Two halves, because reading and writing are different problems:
--
--   render  (automatic)  inline virtual text pads the columns on screen; the
--                        file is untouched
--   align   (on demand)  pads the table under the cursor in the buffer, as one
--                        undoable edit
--
-- Both measure with the same code, so the pipes land in the same columns. They
-- differ in one way, and it shapes most of what follows: RENDER MAY ONLY ADD.
-- So a column is never narrower than a cell already is, the author's whitespace
-- counts towards its padding, and align — which rebuilds each cell from trimmed
-- text — can move text that render had to leave alone.
--
-- Tables are found by scanning lines, not parsing: the syntax is regular, and a
-- scan works where treesitter cannot (no compiler). README.md lists the limits.
--
-- Creates no keymaps. README.md lists the functions to bind.

local M = {}

local ns = vim.api.nvim_create_namespace("mdtable")
local group = vim.api.nvim_create_augroup("mdtable", { clear = true })

-- Only "markdown". A filetype that merely contains markdown is somebody else's
-- call, through setup().
local config = { filetypes = { "markdown" } }

-- ── Rows ────────────────────────────────────────────────────────────────────

-- Indentation and blockquote markers may precede a row's first pipe.
local PREFIX = "^[%s>]*"
local ROW = PREFIX .. "|"

local function prefix_of(line)
  return line:match(PREFIX)
end

local function is_row(line)
  return line:find(ROW) ~= nil
end

-- A fence line, as { marker, closing }. Two CommonMark 4.5 rules, each once a
-- bug here: a closing fence carries only its marker, and a backtick fence's
-- info string may not contain a backtick. So ```lua opens a block but never
-- closes one, and ``` `` is not a fence.
local function fence_at(line)
  local marker, info = line:match(PREFIX .. "([`~][`~][`~]+)(.*)$")
  if not marker then return nil end
  if marker:sub(1, 1) == "`" and info:find("`") then return nil end
  return marker, info:find("%S") == nil
end

-- Split a row into cells, each { text, from, stop }: 1-based byte indices, stop
-- being the closing pipe (one past the end when the row has no trailing pipe).
--
-- A backslash escapes what follows, itself included, so the pair is skipped
-- together — which is what keeps "\\|" right: an escaped backslash, then a
-- pipe that still separates cells.
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

-- A cell of the |---|:--:| row: dashes, colon allowed at either end. That row
-- is what makes a run of rows a table, and its colons carry the alignment.
local function is_delimiter(cell)
  return cell.text:find("^%s*:?%-+:?%s*$") ~= nil
end

-- :--- left, ---: right, :---: centre. "left" and "none" lay out identically
-- and differ only in whether the author wrote the colon, which align() puts back.
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

-- Display width, not byte length. `at` is the starting screen column and `ts`
-- the 'tabstop'; both matter only for tabs, which reach the next multiple of ts
-- from wherever they sit.
--
-- NOT strdisplaywidth: it is window-relative, counting the extra rows a wrapped
-- line takes past 'columns', so a cell wider than the window measured too wide.
-- nvim_strwidth has no window notion, so tabs are expanded by hand.
local function width(s, at, ts)
  if not s:find("\t", 1, true) then return vim.api.nvim_strwidth(s) end

  local col = at
  for part, tab in s:gmatch("([^\t]*)(\t?)") do
    col = col + vim.api.nvim_strwidth(part)
    if tab == "\t" then col = col + ts - (col % ts) end
  end
  return col - at
end

-- What a cell needs once padded: trimmed, each tab as the single space align()
-- writes in its place. A tab cannot be measured once and stay true, since
-- padding moves it.
local function content_width(text)
  return vim.api.nvim_strwidth((vim.trim(text):gsub("\t", " ")))
end

-- ── Finding tables ──────────────────────────────────────────────────────────

-- The lines first..last all start with a pipe; returns a table if they form
-- one, else nil. Everything 1-based and inclusive; rows[lnum] holds that line's
-- cells.
local function table_at(lines, first, last, ts)
  if last == first then return nil end
  local rows = {}
  for n = first, last do rows[n] = cells(lines[n]) end

  -- What a grammar would enforce: row 2 is the separator, every cell of it a
  -- delimiter, with as many cells as the header. The last guard is what tells a
  -- table from lines that merely start with a pipe.
  local sep = first + 1
  if #rows[sep] == 0 or #rows[sep] ~= #rows[first] then return nil end
  for _, cell in ipairs(rows[sep]) do
    if not is_delimiter(cell) then return nil end
  end

  -- Never narrower than a cell already occupies, since render can only add. The
  -- separator counts only for what it occupies, and every column needs three
  -- dashes or it renders as no rule at all.
  --
  -- Left to right, each cell at the column it will have once those before it are
  -- padded, because a tab's width depends on where it lands.
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

-- Every table in `lines`. Runs of consecutive rows are candidates; table_at()
-- decides. Fenced blocks are skipped whole — the one thing a line scan would
-- otherwise get wrong that a parser would not.
local function scan(lines, ts)
  ts = ts or vim.bo.tabstop
  local tables, fence, i = {}, nil, 1
  while i <= #lines do
    local marker, closing = fence_at(lines[i])
    if fence then
      -- Closes on a bare fence of the same character, at least as long.
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

-- The padding one row needs, as { col, text, hl } in byte order: dashes on the
-- separator, spaces elsewhere. Pure, so it serves both the drawing and the tests.
--
-- The half that may only ADD, so a cell written "|   3 |" keeps those three
-- spaces and gets the rest around them. build_row() is the half that may move
-- the text itself.
local function padding(t, lnum)
  local out, at = {}, nil
  for n, cell in ipairs(t.rows[lnum]) do
    local w = t.widths[n]
    at = at or cell.from - 1

    if lnum == t.sep then
      -- Fill goes before a trailing colon so the marker stays at its edge.
      -- Same group as the real dashes.
      local need = w + 2 - cell.occupied
      if need > 0 then
        local head = cell.text:match("^(.-):?%s*$")
        out[#out + 1] = { cell.from - 1 + #head, ("-"):rep(need), "@punctuation.special.markdown" }
      end
    else
      -- The author's whitespace counts towards the side it is on. When it
      -- fights the alignment the text cannot reach its edge, but the pipes meet.
      local lead = cell.text:match("^%s*")
      local left = pad_for(t.align[n], w - cell.content)
      local before = math.max(math.min(left + 1 - width(lead, at, t.tabstop), w + 2 - cell.occupied), 0)
      if before > 0 then out[#out + 1] = { cell.from - 1 + #lead, (" "):rep(before) } end

      -- Measured with `before` in place, not from cell.occupied: padding ahead
      -- of the text moves any tab inside it.
      local after = w + 2 - width((" "):rep(before) .. cell.text, at, t.tabstop)
      if after > 0 then out[#out + 1] = { cell.stop - 1, (" "):rep(after) } end
    end

    at = at + w + 3
  end
  return out
end

-- ── Rewriting ───────────────────────────────────────────────────────────────

-- One row as align() writes it: "| a | b |", the separator rebuilt from the
-- parsed alignment so a ragged |:-|--:| comes out even. Short rows gain empty
-- cells; nothing is dropped, since the widths span the longest row.
--
-- The half that REWRITES: each cell is rebuilt from its trimmed text, putting it
-- where the alignment says. Same columns as padding(), but this one also
-- normalises what sits inside them.
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

-- One nvim_buf_set_lines call, so one undo step. Outside a table it does
-- nothing, so it can be bound globally.
function M.align()
  local buf = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)[1]
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  for _, t in ipairs(scan(lines, vim.bo[buf].tabstop)) do
    if cursor >= t.first and cursor <= t.last then
      -- Checked here, not on entry: bound globally, so with nothing to align
      -- there is nothing to complain about.
      if not vim.bo[buf].modifiable then
        vim.notify("mdtable: buffer is not modifiable", vim.log.levels.WARN)
        return
      end
      -- Each row keeps its own prefix: writing one row's ">" markers onto
      -- another would change the text, not just its padding.
      local out = {}
      for n = t.first, t.last do out[#out + 1] = prefix_of(lines[n]) .. build_row(t, n) end
      vim.api.nvim_buf_set_lines(buf, t.first - 1, t.last, false, out)
      return
    end
  end
end

-- ── State ───────────────────────────────────────────────────────────────────

-- While b:mdtable_on and b:mdtable_ft agree, the filetype still decides; once
-- they differ the user has, so re-detection (:e, autoread, an ftplugin running
-- again) leaves their choice alone.
local render -- defined under "Drawing"

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

--   require("mdtable").setup({ filetypes = { "markdown", "rmd" } })
--
-- Filetypes that merely contain markdown opt in deliberately: vimwiki is
-- written more than read, and inline padding moves the columns under the cursor.
function M.setup(opts)
  config = vim.tbl_extend("force", config, opts or {})
end

-- Every filetype, not just the configured ones: that is what lets a buffer
-- leaving the list stop drawing as well as one joining it start.
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
-- Stored extmarks for the whole buffer, replaced when anything that could change
-- them happens. b:mdtable_tick makes a no-op re-render free.
--
-- DO NOT REWRITE THIS AS A DECORATION PROVIDER. It is the tidier shape — per
-- frame, only visible lines, nothing to invalidate — and it was tried and
-- reverted: a provider's marks must be `ephemeral`, and an ephemeral mark cannot
-- carry inline virtual text. nvim_buf_set_extmark sets
-- MT_FLAG_DECOR_VIRT_TEXT_INLINE only on the stored path (api/extmark.c), and
-- that flag is what makes the renderer reserve the columns, so the mark is
-- accepted, placed, and silently not drawn. Providers suit overlays,
-- end-of-line text and highlights, not inserted columns.
--
-- The cost of storing is that every event which can stale a mark must be
-- caught. Each one below was a bug.

-- Everything a render depends on. 'tabstop' is the only option that changes a
-- width, now that measuring is by nvim_strwidth rather than against a window.
local function state_of(buf)
  return vim.api.nvim_buf_get_changedtick(buf) .. "\0" .. vim.bo[buf].tabstop
end

local function clear(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  vim.b[buf].mdtable_tick = nil
end

-- Padding must not show while typing: it shifts the columns, so the cursor
-- would sit away from the character under it.
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

  -- The buffer's own 'tabstop': a render can be triggered from anywhere.
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

-- ModeChanged rather than InsertLeave alone: none fires for i_CTRL-C.
vim.api.nvim_create_autocmd("ModeChanged", {
  group = group,
  pattern = { "*:i*", "i*:*" },
  callback = function(ev) render(ev.buf) end,
})

-- A buffer edited while another is current gets no TextChanged; WinScrolled
-- covers a window that was already showing it.
vim.api.nvim_create_autocmd("WinScrolled", {
  group = group,
  callback = function() render(vim.api.nvim_get_current_buf()) end,
})

-- For test.lua, which applies the padding to the text rather than reading a
-- screen, since `nvim -l` attaches no UI. Not API.
M._internal = { scan = scan, cells = cells, padding = padding, render = render, typing_in = typing_in }

return M
