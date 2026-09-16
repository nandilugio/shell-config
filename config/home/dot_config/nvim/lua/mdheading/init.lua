-- mdheading: markdown heading depth you can see.
--
-- Markdown encodes depth in character count, so "######" looks heavier than "#"
-- while meaning less. This puts a background colour on the heading line,
-- strongest at level 1. Display only: one extmark per heading, line_hl_group.
--
-- The colour is derived, not configured. The six @markup.heading.N groups are
-- identical in most schemes, so there is no ordered scale to read and a ramp
-- has to be computed. See "Colour".
--
-- Headings are found by scanning lines, not parsing: the syntax is regular, and
-- a scan works where treesitter cannot (no compiler). Fence tracking is copied
-- from mdtable — a README quoting markdown is full of "#" lines that are not
-- headings.
--
-- Creates no keymaps. README.md lists the functions to bind.

local M = {}

local ns = vim.api.nvim_create_namespace("mdheading")
local group = vim.api.nvim_create_augroup("mdheading", { clear = true })

-- Only "markdown". A filetype that merely contains markdown is somebody else's
-- call, through setup().
local config = { filetypes = { "markdown" } }

-- ── Headings ────────────────────────────────────────────────────────────────

-- Indentation and blockquote markers may precede the first "#".
local PREFIX = "^[%s>]*"

-- ATX heading (CommonMark 4.2): one to six "#" then whitespace or end of line.
-- Returns the level. "#nospace" and "#######" are not headings.
--
-- Setext ("===" underneath text) is unsupported: it needs lookahead, and the
-- "---" form is ambiguous with a table separator and a thematic break.
local function heading_at(line)
  local hashes = line:match(PREFIX .. "(#+)")
  if not hashes or #hashes > 6 then return nil end
  local rest = line:sub(#line:match(PREFIX) + #hashes + 1)
  if rest ~= "" and not rest:find("^%s") then return nil end
  return #hashes
end

-- A fence line, as { marker, closing }. Copied from mdtable, including the two
-- CommonMark 4.5 rules that were each a bug there: a closing fence carries only
-- its marker, and a backtick fence's info string may not contain a backtick.
-- So ```lua opens a block but never closes one, and ``` `` is not a fence.
local function fence_at(line)
  local marker, info = line:match(PREFIX .. "([`~][`~][`~]+)(.*)$")
  if not marker then return nil end
  if marker:sub(1, 1) == "`" and info:find("`") then return nil end
  return marker, info:find("%S") == nil
end

-- Every heading in `lines`, as { lnum, level }, skipping fenced blocks whole.
local function scan(lines)
  local found, fence = {}, nil
  for i, line in ipairs(lines) do
    local marker, closing = fence_at(line)
    if fence then
      -- Closes on a bare fence of the same character, at least as long.
      if closing and marker:sub(1, 1) == fence:sub(1, 1) and #marker >= #fence then fence = nil end
    elseif marker then
      fence = marker
    else
      local level = heading_at(line)
      if level then found[#found + 1] = { lnum = i, level = level } end
    end
  end
  return found
end

-- ── Colour ──────────────────────────────────────────────────────────────────

-- Separation between levels is bounded, and every way of buying more costs
-- something. All three were settled by looking at real files; DESIGN.md has the
-- measurements behind each.
--
-- BRIGHTNESS — how much background is mixed in, level 1 least. Both ends are
-- pinned: the bottom is the background itself, the top is that a heading line
-- still has TEXT on it in Normal's fg, so the tint may not get bright enough to
-- swallow it. BLEND_FIRST sits at the darkest end that keeps that text legible
-- against WCAG's threshold for bold text, which heading text is. Lowering it
-- buys separation directly out of readability.
--
-- SATURATION — each level mixed further toward its own grey. Free: it preserves
-- luminance, so it costs no contrast, and hue reads separately from brightness.
--
-- COUNT — levels past DISTINCT_LEVELS share its shade. The same range over
-- fewer steps makes each step bigger, and it is the only lever that moved the
-- needle without costing contrast. The cost is that the deepest levels become
-- one shade; raise it to trade that back, at the price of finer steps.
--
-- Rejected, both measured: white into the top levels raises luminance, so it
-- hits the same readability cap as brightness; a front-loaded curve only
-- starves the deep levels, which had least room already.
local BLEND_FIRST, BLEND_LAST = 0.50, 0.92
local DESATURATE_LAST = 1.0
local DISTINCT_LEVELS = 4

-- Tried in order. Heading groups first so a scheme that colours its headings is
-- honoured, but where they match Normal's fg (the default scheme) blending
-- would give six greys, so a coloured group beats a grey one.
local SOURCES = { "@markup.heading.1.markdown", "@markup.heading", "Directory", "Function", "Special", "Title" }

local function rgb(n)
  return math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256
end

local function is_grey(n)
  local r, g, b = rgb(n)
  return math.max(r, g, b) - math.min(r, g, b) < 24
end

local function hl_of(name)
  local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
  return ok and hl or {}
end

-- First non-grey source, else the first that resolves, else a fixed cyan.
local function source_colour()
  local fallback
  for _, name in ipairs(SOURCES) do
    local fg = hl_of(name).fg
    if fg then
      if not is_grey(fg) then return fg end
      fallback = fallback or fg
    end
  end
  return fallback or 0x8cf8f7
end

-- Falls back to Neovim's own default when Normal has no bg (a transparent
-- terminal background); the ramp still needs something to blend toward.
local function background()
  return hl_of("Normal").bg or (vim.o.background == "light" and 0xffffff or 0x14161b)
end

local function define_highlights()
  local src, bg = source_colour(), background()
  local sr, sg, sb = rgb(src)
  local br, bgr, bb = rgb(bg)
  for level = 1, 6 do
    local t = (math.min(level, DISTINCT_LEVELS) - 1) / (DISTINCT_LEVELS - 1)

    -- Toward the colour's own luminance-grey, which is what leaves brightness
    -- (and so contrast) alone.
    local grey = 0.299 * sr + 0.587 * sg + 0.114 * sb
    local d = DESATURATE_LAST * t
    local dr = sr + (grey - sr) * d
    local dg = sg + (grey - sg) * d
    local db = sb + (grey - sb) * d

    local a = BLEND_FIRST + (BLEND_LAST - BLEND_FIRST) * t
    local r = math.floor(dr * (1 - a) + br * a + 0.5)
    local g = math.floor(dg * (1 - a) + bgr * a + 0.5)
    local b = math.floor(db * (1 - a) + bb * a + 0.5)
    vim.api.nvim_set_hl(0, "MdHeading" .. level, { bg = r * 65536 + g * 256 + b, default = true })
  end
end

-- ── State ───────────────────────────────────────────────────────────────────

-- While b:mdheading_on and b:mdheading_ft agree, the filetype still decides;
-- once they differ the user has, so re-detection (:e, autoread, an ftplugin
-- running again) leaves their choice alone. Same scheme as mdtable.
local render -- defined under "Drawing"

local function choose(buf, on)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  vim.b[buf].mdheading_on = on
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
  local on = not vim.b[buf].mdheading_on
  choose(buf, on)
  vim.notify("Markdown heading colours " .. (on and "on" or "off"))
end

--   require("mdheading").setup({ filetypes = { "markdown", "rmd" } })
function M.setup(opts)
  config = vim.tbl_extend("force", config, opts or {})
end

-- Every filetype, not just the configured ones: that is what lets a buffer
-- leaving the list stop drawing as well as one joining it start.
vim.api.nvim_create_autocmd("FileType", {
  group = group,
  callback = function(ev)
    local b = vim.b[ev.buf]
    if b.mdheading_on ~= b.mdheading_ft then return end -- the user has overridden
    local on = vim.tbl_contains(config.filetypes, ev.match) or nil
    b.mdheading_on, b.mdheading_ft = on, on
    render(ev.buf)
  end,
})

vim.api.nvim_create_user_command("MdHeadingToggle", function() M.toggle() end, {
  desc = "Toggle markdown heading colours",
})

-- ── Drawing ─────────────────────────────────────────────────────────────────
--
-- Stored marks, like mdtable — but here that is a free choice, not a forced
-- one: what ruled out a decoration provider there was inline virtual text,
-- which ephemeral marks cannot carry. Highlights they can. A provider is still
-- not worth it, since the state is cheap: one mark per heading and a tick check
-- that makes a no-op re-render free.

local function clear(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  vim.b[buf].mdheading_tick = nil
end

-- Clearing while typing is consistency with mdtable, not necessity: there the
-- padding must go because it shifts the columns under the cursor.
local function typing_in(buf)
  return vim.api.nvim_get_current_buf() == buf and vim.fn.mode():sub(1, 1) == "i"
end

function render(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(buf) then return end
  if not vim.b[buf].mdheading_on or typing_in(buf) then return clear(buf) end

  local tick = vim.api.nvim_buf_get_changedtick(buf)
  if vim.b[buf].mdheading_tick == tick then return end
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  for _, h in ipairs(scan(vim.api.nvim_buf_get_lines(buf, 0, -1, false))) do
    vim.api.nvim_buf_set_extmark(buf, ns, h.lnum - 1, 0, {
      line_hl_group = "MdHeading" .. h.level,
    })
  end
  vim.b[buf].mdheading_tick = tick
end

-- Each of these was a bug found in mdtable. Not needed here: OptionSet (no
-- widths, so 'tabstop' is never read) and WinScrolled (marks cover the whole
-- buffer, not just visible lines).
vim.api.nvim_create_autocmd({
  "TextChanged", -- the text changed
  "InsertLeave", -- ...including on the way out of insert
  "BufWinEnter", -- a window is showing this buffer
  "WinEnter", -- ...or has become current
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

-- The marks name the groups rather than the colours, so redefining is enough.
vim.api.nvim_create_autocmd("ColorScheme", {
  group = group,
  callback = define_highlights,
})

define_highlights()

-- For test.lua. Not API.
M._internal = { scan = scan, heading_at = heading_at, render = render, define_highlights = define_highlights }

return M
