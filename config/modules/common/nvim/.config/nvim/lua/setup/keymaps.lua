-- Applies lua/keymaps.lua. The only place mappings are created, and so the
-- place that knows which ones exist: overridden() reports those a plugin has
-- since replaced, for :KeymapAudit and :checkhealth config.

local M = {}

local spec = require("keymaps")

-- ── Requirements ────────────────────────────────────────────────────────────
-- The prefix says what kind, so the check never guesses:
--   "fzf"               an executable on PATH
--   "mod:gitsigns"      a Lua module
--   "cmd:VimwikiIndex"  an Ex command (Vimscript plugins define no module)

local cache = {}

local function available(needs)
  if not needs then return true end
  if cache[needs] == nil then
    local kind, name = needs:match("^(%a+):(.+)$")
    if kind == "mod" then
      cache[needs] = (pcall(require, name))
    elseif kind == "cmd" then
      cache[needs] = vim.fn.exists(":" .. name) == 2
    else
      cache[needs] = vim.fn.executable(needs) == 1
    end
  end
  return cache[needs]
end

-- ── Apply ───────────────────────────────────────────────────────────────────

local skipped = {}
local created = {} -- the entries that became mappings, for overridden()

local function apply(m)
  local rhs = m[2]
  if not available(m.needs) then
    rhs = m.fallback
    if rhs == nil then
      table.insert(skipped, ("%s (needs %s)"):format(m[1], m.needs))
      return
    end
  end
  vim.keymap.set(m.mode or "n", m[1], rhs, { desc = m.desc, silent = true, expr = m.expr })
  table.insert(created, m)
end

-- Vimscript plugins source their plugin/ files only after init.lua returns, so
-- a "cmd:" requirement cannot be judged yet. Those wait; the rest apply now so
-- they work in the first buffer.
local deferred = {}
for _, m in ipairs(spec.maps) do
  if m.needs and m.needs:match("^cmd:") then
    table.insert(deferred, m)
  else
    apply(m)
  end
end

if #deferred > 0 then
  vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = function()
      for _, m in ipairs(deferred) do apply(m) end
    end,
  })
end

-- ── Relabel Neovim's own LSP mappings ───────────────────────────────────────
-- Core describes these as "vim.lsp.buf.rename()" and so on: accurate, but it
-- reads like a stack trace in the which-key popup. Reuse core's callback so
-- behaviour is untouched, and skip silently if a future Neovim changes them.

local core_labels = {
  { "n", "grn", "Rename symbol" },
  { "n", "gra", "Code action" },
  { "x", "gra", "Code action" },
  { "n", "grr", "References" },
  { "n", "gri", "Implementation" },
  { "n", "grt", "Type definition" },
  { "n", "grx", "Run codelens" },
  { "n", "gO", "Document symbols" },
  { "i", "<C-s>", "Signature help" },
  { "s", "<C-s>", "Signature help" },
  { "i", "<Tab>", "Next snippet placeholder, else Tab" },
  { "s", "<Tab>", "Next snippet placeholder, else Tab" },
  { "i", "<S-Tab>", "Previous snippet placeholder, else Shift-Tab" },
  { "s", "<S-Tab>", "Previous snippet placeholder, else Shift-Tab" },
}

for _, entry in ipairs(core_labels) do
  local mode, lhs, desc = entry[1], entry[2], entry[3]
  local m = vim.fn.maparg(lhs, mode, false, true)
  if m and m.callback then
    vim.keymap.set(mode, lhs, m.callback, {
      desc = desc,
      silent = m.silent == 1,
      expr = m.expr == 1,
    })
  end
end

-- ── Reporting ───────────────────────────────────────────────────────────────

vim.api.nvim_create_user_command("KeymapsSkipped", function()
  if #skipped == 0 then
    vim.notify("All keymaps active.")
  else
    vim.notify("Inactive keymaps:\n  " .. table.concat(skipped, "\n  "))
  end
end, { desc = "List keymaps disabled by missing dependencies" })

-- ── Overrides ───────────────────────────────────────────────────────────────
-- Plugins map keys of their own, and a Vimscript plugin can quietly claim a
-- whole namespace (vimwiki takes <leader>w unless told otherwise). A mapping
-- is ours while the one on its key still carries our description: maparg()
-- is asked per key, so Vim does the spelling (<S-h> is H, <LocalLeader>t is
-- ,t) rather than this file guessing it. Buffer-local mappings win over
-- global ones and are what ftplugins and LspAttach create, so a check from
-- a buffer also sees what shadows ours there.

--- @return string[] global  "<mode> <lhs>: now <desc>, ours <desc>"
--- @return string[] buflocal  the same, for THIS buffer's own mappings
function M.overridden()
  local global, buflocal = {}, {}
  for _, m in ipairs(created) do
    local modes = type(m.mode) == "table" and m.mode or { m.mode or "n" }
    for _, mode in ipairs(modes) do
      local cur = vim.fn.maparg(m[1], mode, false, true)
      if cur.desc ~= m.desc then
        local line = ("%s %s: now %s, ours %q"):format(mode, m[1], cur.lhs and ("%q"):format(cur.desc or "") or "unmapped", m.desc)
        table.insert(cur.buffer == 1 and buflocal or global, line)
      end
    end
  end
  return global, buflocal
end

-- Run after adding a plugin.
vim.api.nvim_create_user_command("KeymapAudit", function()
  local overridden, buflocal = M.overridden()

  -- Leader mappings nobody here defined: a plugin's own. nvim_get_keymap()
  -- reports lhs with <leader> expanded, so match the key itself.
  local ours = {}
  for _, m in ipairs(spec.maps) do
    ours[(m[1]:gsub("<[Ll]eader>", vim.g.mapleader or "\\"))] = true
  end
  local foreign = {}
  for _, mode in ipairs({ "n", "x", "o", "i", "t" }) do
    for _, m in ipairs(vim.api.nvim_get_keymap(mode)) do
      if m.lhs:match("^ ") and not ours[m.lhs] and not m.lhs:match("^<Plug>") then
        table.insert(foreign, ("%s %s  %s"):format(mode, m.lhs, m.desc or "(no description)"))
      end
    end
  end

  local out = { ("%d of our mappings overridden"):format(#overridden) }
  vim.list_extend(out, overridden)
  table.insert(out, ("%d leader mappings we did not define"):format(#foreign))
  vim.list_extend(out, foreign)
  table.insert(out, ("%d of ours shadowed in THIS buffer"):format(#buflocal))
  vim.list_extend(out, buflocal)
  vim.notify(table.concat(out, "\n  "))
end, { desc = "Report keymap conflicts with plugins" })

-- ── which-key ───────────────────────────────────────────────────────────────
-- Only labels prefixes; the mappings themselves come from the table above.

local ok, wk = pcall(require, "which-key")
if ok then
  wk.setup({
    -- Show immediately: this is a reference you reach for on purpose.
    -- 'timeoutlen' still governs when a pending mapping resolves.
    delay = 0,
    -- Sizes itself as borderless, so it must not inherit 'winborder'.
    win = { border = "none" },
  })

  local groups = {}
  for _, g in ipairs(spec.groups) do
    table.insert(groups, { g[1], group = g[2], mode = g.mode })
  end
  wk.add(groups)
end

return M
