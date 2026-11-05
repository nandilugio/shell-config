-- How problems are shown. Nvim 0.12 enables diagnostics automatically when an
-- LSP attaches; this only adjusts presentation.
--
-- Two independent settings, each with its own toggle:
--
--   scope     where messages are written out: the cursor line, every line, or
--             nowhere. Underlines only with every line: elsewhere they would
--             mark the whole file while the messages are hidden. <leader>ud.
--   severity  the least severe one written out and underlined. <leader>uD.
--
-- Signs are outside both, deliberately: the gutter always marks every
-- diagnostic, so a filter can hide a message but never the fact that there is
-- one.

local M = {}

local severity = vim.diagnostic.severity

-- Cursor line first, and the default: messages written under every line push
-- the code around as you type, which is when you least want to read them.
-- At the end of the line rather than beneath it, so nothing moves as the cursor
-- does either; a long message is cut off there, and <C-w>d shows it whole.
-- Every line is for surveying a file, so there each message gets lines of its
-- own and is never cut off.
local SCOPES = { "current line", "every line", "none" }

local SEVERITIES = {
  { label = "all", min = severity.HINT },
  { label = "warnings and errors", min = severity.WARN },
  { label = "errors only", min = severity.ERROR },
}

local state = { scope = SCOPES[1], severity = SEVERITIES[1].label }

local function min_of(label)
  for _, s in ipairs(SEVERITIES) do
    if s.label == label then return s.min end
  end
end

local function apply()
  local filter = { severity = { min = min_of(state.severity) } }
  vim.diagnostic.config({
    virtual_text = state.scope == "current line" and vim.tbl_extend("force", filter, { current_line = true }) or false,
    virtual_lines = state.scope == "every line" and filter or false,
    underline = state.scope == "every line" and filter or false,
  })
end

vim.diagnostic.config({
  severity_sort = true,
  update_in_insert = false, -- do not churn while typing
  float = { source = true },
  signs = {
    text = {
      [severity.ERROR] = "E",
      [severity.WARN] = "W",
      [severity.INFO] = "I",
      [severity.HINT] = "H",
    },
  },
})
apply()

--- The current settings, as labels.
--- @return { scope: string, severity: string }
function M.get() return vim.deepcopy(state) end

--- Sets either or both, by label, without a message: callers that change
--- several things at once (setup/review.lua) report them together.
--- @param new { scope?: string, severity?: string }
function M.set(new)
  if new.scope then
    assert(vim.tbl_contains(SCOPES, new.scope), "unknown diagnostics scope: " .. new.scope)
    state.scope = new.scope
  end
  if new.severity then
    assert(min_of(new.severity), "unknown diagnostics severity: " .. new.severity)
    state.severity = new.severity
  end
  apply()
end

local function next_of(list, current)
  for i, v in ipairs(list) do
    if v == current then return list[i % #list + 1] end
  end
  return list[1]
end

function M.cycle_scope()
  M.set({ scope = next_of(SCOPES, state.scope) })
  vim.notify("Diagnostics written out: " .. state.scope)
end

function M.cycle_severity()
  local labels = vim.tbl_map(function(s) return s.label end, SEVERITIES)
  M.set({ severity = next_of(labels, state.severity) })
  vim.notify("Diagnostics shown: " .. state.severity)
end

return M
