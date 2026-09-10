-- How problems are shown. Nvim 0.12 enables diagnostics automatically when an
-- LSP attaches; this only adjusts presentation.

vim.diagnostic.config({
  -- Every diagnostic, on its own line beneath the code. Virtual lines have
  -- room for the whole message where end-of-line text would truncate it, and
  -- they do not push the code sideways.
  virtual_lines = true,
  underline = true,
  severity_sort = true,
  update_in_insert = false, -- do not churn while typing
  float = { border = "single", source = true },
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = "E",
      [vim.diagnostic.severity.WARN] = "W",
      [vim.diagnostic.severity.INFO] = "I",
      [vim.diagnostic.severity.HINT] = "H",
    },
  },
})

-- Virtual lines are the most readable way to show a diagnostic and the most
-- intrusive: a file with many warnings becomes mostly warnings. Rather than a
-- plain on/off, <leader>ud steps down through how much is shown, which is
-- usually the thing you actually want when a file gets noisy.
local LEVELS = {
  { label = "all", min = vim.diagnostic.severity.HINT },
  { label = "warnings and errors", min = vim.diagnostic.severity.WARN },
  { label = "errors only", min = vim.diagnostic.severity.ERROR },
  { label = "off", min = nil },
}

local level = 1

local function apply()
  local l = LEVELS[level]
  vim.diagnostic.config({
    virtual_lines = l.min and { severity = { min = l.min } } or false,
  })
  vim.notify("Diagnostics: " .. l.label)
end

function _G.CycleDiagnostics()
  level = level % #LEVELS + 1
  apply()
end
