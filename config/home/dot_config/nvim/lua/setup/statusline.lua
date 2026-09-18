-- Built on 0.12's default (filename, %m %r, LSP progress, busy spinner,
-- diagnostic counts, ruler), adding a mode block, git branch and hunk counts,
-- attached servers, filetype, and a warning on unusual encodings.
--
-- Identity left, state right, as lualine and VS Code do:
--
--   NORMAL  lua/setup/git.lua  master* ⇡ +1 ~2 -3    E:1 W:2  lua_ls  lua  42% 15:8
--
-- The two costly calls are avoided: the path is cached per buffer, the search
-- count computed only while a search is lit.

local M = {}

-- Narrow windows drop detail rather than wrap; widest first, so this is the
-- order things disappear.
local WIDE = { indent = 120, lsp = 100, hunks = 80 }

local function wide_enough(what)
  return vim.api.nvim_win_get_width(0) >= WIDE[what]
end

-- ── Colours ─────────────────────────────────────────────────────────────────
-- Derived from the colourscheme, rebuilt when it changes. Mode blocks invert: a
-- semantic fg becomes the bg, with the editor's bg as the text.

local function hl(group, field)
  return vim.api.nvim_get_hl(0, { name = group, link = false })[field]
end

local function set_highlights()
  local dark = hl("Normal", "bg")

  -- Distinct hues in practice, not by name. StatusLine's own fg stands in for
  -- Normal, keeping the resting state calm.
  local modes = {
    StatuslineNormal = hl("StatusLine", "fg"),
    StatuslineInsert = hl("String", "fg"),
    StatuslineVisual = hl("DiagnosticWarn", "fg"),
    StatuslineReplace = hl("DiagnosticError", "fg"),
    StatuslineCommand = hl("Special", "fg"),
    StatuslineTerminal = hl("Comment", "fg"),
  }
  for name, colour in pairs(modes) do
    vim.api.nvim_set_hl(0, name, { fg = dark, bg = colour, bold = true })
  end

  -- By importance, as Pure does: path and arrows take the accent, the branch
  -- sits between them as context.
  --
  -- Foreground only, deliberately: an inactive window draws its line with
  -- StatusLineNC, and a bg pinned to StatusLine would keep painting the active
  -- colour there, leaving each coloured segment as a patch on a darker line.
  vim.api.nvim_set_hl(0, "StatuslineAccent", { fg = hl("Special", "fg") })
  vim.api.nvim_set_hl(0, "StatuslineAdd", { fg = hl("String", "fg") })
  vim.api.nvim_set_hl(0, "StatuslineChange", { fg = hl("DiagnosticWarn", "fg") })
  vim.api.nvim_set_hl(0, "StatuslineDelete", { fg = hl("DiagnosticError", "fg") })
  vim.api.nvim_set_hl(0, "StatuslineMuted", { fg = hl("Comment", "fg") })
end

set_highlights()
vim.api.nvim_create_autocmd("ColorScheme", { callback = set_highlights })

-- ── Components ──────────────────────────────────────────────────────────────

local MODES = {
  n = { "NORMAL", "StatuslineNormal" },
  i = { "INSERT", "StatuslineInsert" },
  v = { "VISUAL", "StatuslineVisual" },
  V = { "V-LINE", "StatuslineVisual" },
  ["\22"] = { "V-BLOCK", "StatuslineVisual" },
  s = { "SELECT", "StatuslineVisual" },
  S = { "S-LINE", "StatuslineVisual" },
  R = { "REPLACE", "StatuslineReplace" },
  c = { "COMMAND", "StatuslineCommand" },
  t = { "TERMINAL", "StatuslineTerminal" },
}

function M.mode()
  local m = MODES[vim.api.nvim_get_mode().mode:sub(1, 1)] or { "?", "StatuslineNormal" }
  return ("%%#%s# %s %%*"):format(m[2], m[1])
end

-- gitsigns opens a historical revision as gitsigns://<gitdir>//<rev>:<relpath>
-- (actions/diffthis.lua:130), which r/R in the blame window do to the window
-- you were working in. Rendered as a path it is unreadable, and pathshorten
-- below mangles it further, so the one thing that matters -- that this is not
-- your working tree -- is the one thing it fails to say.
--
-- The gitdir is absolute and full of slashes, so anchor on the "//" that
-- follows it and take the LAST colon: a revision cannot contain either.
local function gitsigns_revision(name)
  local rest = name:match("^gitsigns://.*//(.+)$")
  if not rest then return nil end
  local rev, relpath = rest:match("^(.-):([^:]*)$")
  if not rev or relpath == "" then return nil end
  return vim.fn.fnamemodify(relpath, ":t"), rev:sub(1, 8)
end

-- The answer only changes when the file does, so it is computed on write and
-- BufEnter rather than every redraw.
local function refresh_path(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  if name == "" then
    vim.b[buf].statusline_path = ""
    return
  end
  local file, rev = gitsigns_revision(name)
  vim.b[buf].statusline_path = file or vim.fn.fnamemodify(name, ":.")
  vim.b[buf].statusline_revision = rev
end

vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "BufFilePost" }, {
  callback = function(args) refresh_path(args.buf) end,
})

function M.path()
  local p = vim.b.statusline_path
  if not p or p == "" then return "" end
  local rev = vim.b.statusline_revision
  -- A revision is already just the basename, and shortening it would only hide
  -- what little is left.
  if not rev and #p > math.max(20, vim.api.nvim_win_get_width(0) - 60) then
    -- Shorten rather than crowd out the right-hand side, which needs ~60.
    p = vim.fn.pathshorten(p)
  end
  if rev then
    -- The path is already accented, so the revision needs its own colour to
    -- read as a warning rather than as part of the filename. Delete's red is
    -- the strongest thing the scheme gives, and "not your working tree" earns
    -- it -- this is the only cue that edits here go nowhere.
    return ("%s%%*%%#StatuslineDelete#@%s"):format(p, rev)
  end
  return p
end

-- ── Repository state ────────────────────────────────────────────────────────
-- The symbols the zsh prompt (Pure) and the Claude Code statusline use:
--
--   *  uncommitted changes     ⇡  ahead of upstream
--   ⇣  behind upstream         and the name of any operation in progress
--
-- These describe the repository; the +~- counts alongside describe the file.
-- Git is far too slow for a redraw, so this is async and cached.

local repo_state = {}

local function git_dir_action(root)
  local checks = {
    { "rebase-merge", "rebase" },
    { "rebase-apply", "rebase" },
    { "MERGE_HEAD", "merge" },
    { "CHERRY_PICK_HEAD", "cherry-pick" },
    { "REVERT_HEAD", "revert" },
    { "BISECT_LOG", "bisect" },
  }
  for _, c in ipairs(checks) do
    if vim.uv.fs_stat(root .. "/.git/" .. c[1]) then return c[2] end
  end
  return nil
end

local function refresh_repo()
  local d = vim.b.gitsigns_status_dict
  local root = d and d.root
  if not root then return end

  vim.system(
    {
      "git", "--no-optional-locks", "-C", root,
      "status", "--porcelain=v2", "--branch", "--untracked-files=no",
    },
    { text = true },
    function(res)
      if res.code ~= 0 then return end
      local state = { dirty = false, ahead = 0, behind = 0 }
      for line in res.stdout:gmatch("[^\n]+") do
        local ab = line:match("^# branch%.ab (.+)$")
        if ab then
          state.ahead = tonumber(ab:match("%+(%d+)")) or 0
          state.behind = tonumber(ab:match("%-(%d+)")) or 0
        elseif not line:match("^#") then
          state.dirty = true
        end
      end
      state.action = git_dir_action(root)

      vim.schedule(function()
        repo_state[root] = state
        vim.cmd.redrawstatus()
      end)
    end
  )
end

vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "FocusGained" }, {
  callback = function() vim.schedule(refresh_repo) end,
})
vim.api.nvim_create_autocmd("User", {
  pattern = "GitSignsUpdate",
  callback = function() vim.schedule(refresh_repo) end,
})

function M.repo()
  local d = vim.b.gitsigns_status_dict
  local st = d and d.root and repo_state[d.root]
  if not st then return "" end

  -- As Pure groups them: the dirty marker qualifies the branch and sits tight
  -- against it; the arrows are a separate fact and take a space.
  local out = ""
  if st.dirty then out = out .. "%#StatuslineDelete#*%*" end

  local arrows = ""
  if st.ahead > 0 then arrows = arrows .. "⇡" end
  if st.behind > 0 then arrows = arrows .. "⇣" end
  if arrows ~= "" then out = out .. ("%%#StatuslineAccent# %s%%*"):format(arrows) end

  if st.action then out = out .. ("%%#StatuslineDelete# %s%%*"):format(st.action) end
  return out
end

function M.git()
  local d = vim.b.gitsigns_status_dict
  if not d or not d.head or d.head == "" then return "" end

  local out = (" %s"):format(d.head) .. M.repo()
  -- Hunk counts only where there is room; they are the first thing to drop.
  if wide_enough("hunks") then
    if (d.added or 0) > 0 then out = out .. ("%%#StatuslineAdd# +%d%%*"):format(d.added) end
    if (d.changed or 0) > 0 then out = out .. ("%%#StatuslineChange# ~%d%%*"):format(d.changed) end
    if (d.removed or 0) > 0 then out = out .. ("%%#StatuslineDelete# -%d%%*"):format(d.removed) end
  end
  return out .. " "
end

-- Bracketed: servers are a different kind of fact from the file's own
-- properties beside them, so no new colour is invented.
function M.lsp()
  if not wide_enough("lsp") then return "" end
  local names = {}
  for _, c in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
    names[#names + 1] = c.name
  end
  if #names == 0 then return "" end
  return ("%%#StatuslineMuted#[%s] %%*"):format(table.concat(names, " "))
end

-- Silent unless something is unusual, which is the only time it matters.
function M.fileinfo()
  local out = {}
  local enc = vim.bo.fileencoding
  if enc ~= "" and enc ~= "utf-8" then out[#out + 1] = enc end
  if vim.bo.fileformat ~= "unix" then out[#out + 1] = vim.bo.fileformat end
  if #out == 0 then return "" end
  return ("%%#StatuslineDelete#%s %%*"):format(table.concat(out, " "))
end

function M.indent()
  if not wide_enough("indent") then return "" end
  local sw = vim.bo.shiftwidth ~= 0 and vim.bo.shiftwidth or vim.bo.tabstop
  return ("%%#StatuslineMuted#%s%d %%*"):format(vim.bo.expandtab and "sw" or "tab", sw)
end

-- searchcount() is comparatively slow, so it runs only while a search is lit.
function M.search()
  if vim.v.hlsearch == 0 then return "" end
  local ok, s = pcall(vim.fn.searchcount, { maxcount = 999, timeout = 50 })
  if not ok or not s.total or s.total == 0 then return "" end
  return ("%%#StatuslineMuted#[%d/%d] %%*"):format(s.current, s.total)
end

-- Recording is a mode of sorts, so it reads as a block beside the mode rather
-- than as another item in the line.
function M.recording()
  local reg = vim.fn.reg_recording()
  if reg == "" then return "" end
  return ("%%#StatuslineReplace# @%s %%*"):format(reg)
end

-- Verbatim from the default, so they keep whatever formatting a future version
-- gives them.
local DIAGNOSTICS = "%{% luaeval('(package.loaded[\"vim.diagnostic\"] "
  .. "and next(vim.diagnostic.count()) "
  .. "and vim.diagnostic.status() .. \" \") or \"\"') %}"

-- ── Assembly ────────────────────────────────────────────────────────────────
-- The default's own pieces verbatim: %m %r, LSP progress and busy, the
-- diagnostic counts, the ruler.

function M.render()
  return table.concat({
    M.mode(),
    M.recording(),
    " %<",
    "%#StatuslineAccent#",
    M.path(),
    "%*%m%r ",
    M.git(),
    "%=", -- right-hand side from here
    M.search(),
    DIAGNOSTICS,
    M.lsp(),
    "%#StatuslineMuted#%{&filetype} %*",
    M.fileinfo(),
    M.indent(),
    "%{% &busy > 0 ? '◐ ' : '' %}",
    -- Vim's own ruler format: line,col then how far through the file.
    " %l,%c %P ",
  })
end

vim.o.statusline = "%{%v:lua.require'setup.statusline'.render()%}"

return M
