-- Applies lua/keymaps.lua. The only place mappings are created.

local spec = require("keymaps")

-- ── Requirements ────────────────────────────────────────────────────────────
-- A `needs` value names something the machine may not have. The prefix says
-- what kind, so the check never has to guess:
--   "fzf"           an executable on PATH
--   "mod:gitsigns"  a Lua module
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

local function apply(m)
  local rhs = m[2]
  if not available(m.needs) then
    rhs = m.fallback
    if rhs == nil then
      table.insert(skipped, ("%s (needs %s)"):format(m[1], m.needs))
      return
    end
  end
  vim.keymap.set(m.mode or "n", m[1], rhs, { desc = m.desc, silent = true })
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
  { "i", "<C-S>", "Signature help" },
  { "s", "<C-S>", "Signature help" },
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

-- Plugins map keys of their own, and a Vimscript plugin can quietly claim a
-- whole namespace (vimwiki takes <leader>w unless told otherwise). Run this
-- after adding a plugin.
vim.api.nvim_create_user_command("KeymapAudit", function()
  -- nvim_get_keymap() reports lhs with <leader> already expanded, so expand
  -- ours the same way before comparing. "v" covers both x and s.
  local function norm(lhs)
    return (lhs:gsub("<[Ll]eader>", vim.g.mapleader or "\\"))
  end

  local ours = {}
  for _, m in ipairs(spec.maps) do
    local modes = type(m.mode) == "table" and m.mode or { m.mode or "n" }
    for _, mo in ipairs(modes) do
      if mo == "v" then
        ours["x " .. norm(m[1])], ours["s " .. norm(m[1])] = m.desc, m.desc
      else
        ours[mo .. " " .. norm(m[1])] = m.desc
      end
    end
  end

  local overridden, foreign, buflocal = {}, {}, {}

  for _, mo in ipairs({ "n", "x", "o", "i", "t" }) do
    for _, m in ipairs(vim.api.nvim_get_keymap(mo)) do
      local key = mo .. " " .. m.lhs
      if ours[key] then
        if m.desc ~= ours[key] then
          table.insert(overridden, ("%s (ours: %s)"):format(key, ours[key]))
        end
      elseif m.lhs:match("^ ") and not m.lhs:match("^<Plug>") then
        table.insert(foreign, ("%s  %s"):format(key, m.desc or "(no description)"))
      end
    end
  end

  -- Buffer-local maps too: ftplugins and LspAttach set these, and they are
  -- invisible to nvim_get_keymap(). This is where a conflict hides.
  for _, mo in ipairs({ "n", "x", "o" }) do
    for _, m in ipairs(vim.api.nvim_buf_get_keymap(0, mo)) do
      local key = mo .. " " .. m.lhs
      if ours[key] and m.desc ~= ours[key] then
        table.insert(buflocal, ("%s (ours: %s)"):format(key, ours[key]))
      end
    end
  end

  local out = {
    ("%d of our mappings overridden"):format(#overridden),
  }
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
    icons = { mappings = vim.g.have_nerd_font },
  })

  local groups = {}
  for _, g in ipairs(spec.groups) do
    table.insert(groups, { g[1], group = g[2], mode = g.mode })
  end
  wk.add(groups)
end
