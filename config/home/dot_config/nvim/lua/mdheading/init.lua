-- mdheading: markdown heading depth you can see.
--
-- Markdown encodes depth in character count, so "######" looks heavier than
-- "#" while meaning less. The visual weight runs backwards from the semantic
-- weight, and in a long file headings are hard to pick out at all.
--
-- So: a background colour on the heading line, strongest at level 1 and
-- fading as it goes deeper. Depth reads at a glance, and headings become
-- landmarks while scrolling. The file is untouched — this is display only,
-- one extmark per heading line carrying line_hl_group.
--
-- The colour is derived, not configured. The six @markup.heading.N groups are
-- identical in most schemes (they are in Neovim's default: same fg, same
-- bold), so there is no existing ordered scale to read — a ramp has to be
-- computed. One source colour is blended toward the Normal background, and the
-- whole ramp is recomputed on ColorScheme, so changing scheme changes the
-- headings with it. See "Colour" for what bounds the ramp and why the deepest
-- levels share a shade.
--
-- Headings are found by scanning lines, not parsing, for the same reason
-- mdtable does it: the syntax is regular, and a line scan works on a machine
-- with no compiler. The one thing it must get right is fenced code blocks —
-- a README quoting markdown is full of "#" lines that are not headings — so
-- fence tracking is copied from mdtable, CommonMark rules and all.
--
-- Creates no keymaps. README.md lists the functions to bind.

local M = {}

local ns = vim.api.nvim_create_namespace("mdheading")
local group = vim.api.nvim_create_augroup("mdheading", { clear = true })

-- Only "markdown", like mdtable: a filetype that happens to contain markdown
-- is somebody else's call to make, through setup().
local config = { filetypes = { "markdown" } }

-- ── Headings ────────────────────────────────────────────────────────────────

-- What may come before the first "#": indentation, and the ">" markers of a
-- blockquote, since "> ## x" is a heading inside a quote.
local PREFIX = "^[%s>]*"

-- An ATX heading: one to six "#" then whitespace, or nothing else on the line.
-- "#nospace" is not a heading and neither is "#######" (seven), both per
-- CommonMark 4.2. Returns the level.
--
-- Setext headings ("===" or "---" underneath text) are not supported: they
-- need lookahead, and the "---" form is ambiguous with a table separator and
-- a thematic break. README.md says so rather than half-supporting them.
local function heading_at(line)
  local hashes = line:match(PREFIX .. "(#+)")
  if not hashes or #hashes > 6 then return nil end
  local rest = line:sub(#line:match(PREFIX) + #hashes + 1)
  if rest ~= "" and not rest:find("^%s") then return nil end
  return #hashes
end

-- A fence line, as { marker, closing }. Copied from mdtable, including the two
-- CommonMark 4.5 rules that were each a bug there: a closing fence carries
-- nothing but the marker, and a backtick fence's info string may not contain a
-- backtick. So ```lua opens a block but never closes one, and ``` `` is not a
-- fence at all.
local function fence_at(line)
  local marker, info = line:match(PREFIX .. "([`~][`~][`~]+)(.*)$")
  if not marker then return nil end
  if marker:sub(1, 1) == "`" and info:find("`") then return nil end
  return marker, info:find("%S") == nil
end

-- Every heading in `lines`, as { lnum, level }. Fenced code blocks are skipped
-- whole — the one thing a naive line scan would get wrong that a parser
-- would not.
local function scan(lines)
  local found, fence = {}, nil
  for i, line in ipairs(lines) do
    local marker, closing = fence_at(line)
    if fence then
      -- A block closes on a bare fence of the same character, at least as long.
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

-- Three numbers, each settled by looking at real files rather than by taste.
-- What they trade against each other is the whole design, so: separation
-- between levels is bounded, and every way of buying more costs something.
--
-- BRIGHTNESS — how much background is mixed in, level 1 least. Both ends are
-- pinned. The bottom is the background itself; the top is that a heading line
-- still has TEXT on it, drawn in Normal's foreground, so the tint may not get
-- bright enough to swallow it. In the default scheme 0.62 is where that text
-- sits at WCAG AA (4.5:1) and 0.50 is where it reaches 3.1:1 — AA's threshold
-- for bold text, which heading text is. Below that it stops being readable
-- rather than merely tight.
--
-- SATURATION — level 1 keeps the source colour, and each level is mixed
-- further toward its own grey. This one is free: desaturating preserves
-- luminance, so it costs no contrast at all, and the eye reads hue separately
-- from brightness. Colour draining away is a second signal on top of darkness.
--
-- COUNT — levels past DISTINCT_LEVELS share its shade. A bounded range over
-- fewer steps makes each step bigger, which is the only lever that actually
-- moved the needle. Measured in the default scheme, smallest gap between
-- adjacent shades:
--
--     6 levels at 0.62    12      the first version; too close to read
--     6 levels at 0.50    16
--     5 levels at 0.50    21
--     4 levels at 0.50    27      <- here
--
-- Two things that look like they should help and do not, both measured before
-- being rejected: mixing white into the top levels raises luminance, so it hits
-- the same readability cap for +0.4 units of separation at a cost of 0.3 in
-- contrast; and front-loading the curve only starves the deep levels that had
-- least room already (25,14,10,7,6 against a flat 12).
--
-- The cost here is that ####, ##### and ###### are one shade. That is a real
-- loss — #### is common enough — accepted because a distinction too fine to
-- see is not a distinction, and three unmistakable levels beat six blurred
-- ones. Raise DISTINCT_LEVELS to 5 or 6 to trade it back; nothing else needs
-- to change.
--
-- For scale, in the default scheme CursorLine sits 24 units from the
-- background and Visual 60: level 1 lands well past Visual, level 2 near it,
-- level 4 below CursorLine but still present.
local BLEND_FIRST, BLEND_LAST = 0.50, 0.92
local DESATURATE_LAST = 1.0
local DISTINCT_LEVELS = 4

-- Groups tried in order for the source colour. The heading groups come first
-- so a scheme that does colour its headings is honoured, but in schemes where
-- they match Normal's fg (Neovim's default does) blending them would give six
-- greys, so a genuinely coloured group is preferred over a grey one.
local SOURCES = { "@markup.heading.1.markdown", "@markup.heading", "Directory", "Function", "Special", "Title" }

local function rgb(n)
  return math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256
end

-- Grey means the three channels sit within a few points of each other, which
-- is what makes a source useless for a tinted ramp.
local function is_grey(n)
  local r, g, b = rgb(n)
  return math.max(r, g, b) - math.min(r, g, b) < 24
end

local function hl_of(name)
  local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
  return ok and hl or {}
end

-- The colour to blend from: the first source that resolves to something
-- non-grey, falling back to the first that resolves at all, and finally to a
-- fixed cyan for a scheme that defines none of them.
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

-- Neovim's default dark background, for a scheme that leaves Normal's bg unset
-- (a transparent terminal background, typically). The ramp still needs
-- something to blend toward; the alternative is drawing nothing.
local function background()
  return hl_of("Normal").bg or (vim.o.background == "light" and 0xffffff or 0x14161b)
end

-- Define MdHeading1..6 as backgrounds along the ramp. Called at load and on
-- every ColorScheme, so the headings follow the scheme.
local function define_highlights()
  local src, bg = source_colour(), background()
  local sr, sg, sb = rgb(src)
  local br, bgr, bb = rgb(bg)
  for level = 1, 6 do
    -- Levels past DISTINCT_LEVELS share its shade, which is what buys the
    -- others their separation: the same range over fewer steps makes each
    -- step bigger.
    local t = (math.min(level, DISTINCT_LEVELS) - 1) / (DISTINCT_LEVELS - 1)

    -- Toward this colour's own grey, which is its luminance: mixing toward
    -- that rather than toward a fixed grey is what leaves brightness alone.
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

-- b:mdheading_on drives the drawing below, and b:mdheading_ft records what the
-- filetype last made it: while the two agree nobody has overridden anything
-- and the filetype still decides, and once they differ the user has, so
-- re-detecting the filetype — :e, autoread, an ftplugin running again —
-- leaves their choice alone. Same scheme as mdtable, for the same reason.
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

-- Colour headings automatically in these filetypes.
--
--   require("mdheading").setup({ filetypes = { "markdown", "rmd" } })
--
-- Optional: the default is useful as it is.
function M.setup(opts)
  config = vim.tbl_extend("force", config, opts or {})
end

-- Listening on every filetype, not just the configured ones, is what lets a
-- buffer that leaves the list stop drawing as well as one that joins it start.
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
-- One stored extmark per heading, carrying line_hl_group, which colours the
-- whole line to the window edge.
--
-- Stored rather than ephemeral, like mdtable — but here that is a free choice
-- rather than a forced one. An ephemeral mark cannot do inline virtual text,
-- which is what ruled a decoration provider out there; highlights it can do.
-- A provider is not used anyway because the state is cheap to keep correct:
-- one mark per heading, a handful per file, and a tick check that makes a
-- no-op re-render free. What follows is the list of things that can stale it,
-- and each entry is a bug somebody found in mdtable:
--
--   TextChanged, InsertLeave   the text changed
--   BufWinEnter, WinEnter      a window is showing it that may not have been
--   ModeChanged i:*            insert mode ends, including via <C-c>, which
--                              fires no InsertLeave
--   ColorScheme                the ramp has to be recomputed
--
-- Not copied from mdtable: OptionSet (no widths here, so 'tabstop' is not
-- read) and WinScrolled (marks cover the whole buffer, not just what is
-- visible, so scrolling changes nothing).

local function clear(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  vim.b[buf].mdheading_tick = nil
end

-- The effect goes away while typing, to match mdtable — there the padding
-- must go, because it shifts the columns under the cursor, and a background
-- colour has no such problem. This is consistency rather than necessity: one
-- rule for both plugins, and the buffer you are editing shows you what is
-- actually in the file.
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

-- Everything that can change what should be drawn.
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

-- Clear while typing, restore on the way out. ModeChanged rather than
-- InsertLeave alone: Neovim fires no InsertLeave for i_CTRL-C.
vim.api.nvim_create_autocmd("ModeChanged", {
  group = group,
  pattern = { "*:i*", "i*:*" },
  callback = function(ev) render(ev.buf) end,
})

-- A new scheme means a new ramp, and the marks name the groups rather than
-- the colours, so redefining them is enough.
vim.api.nvim_create_autocmd("ColorScheme", {
  group = group,
  callback = define_highlights,
})

define_highlights()

-- For test.lua. Not API.
M._internal = { scan = scan, heading_at = heading_at, render = render, define_highlights = define_highlights }

return M
