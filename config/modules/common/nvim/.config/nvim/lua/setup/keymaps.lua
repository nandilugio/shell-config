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

-- ── Labels ──────────────────────────────────────────────────────────────────
-- The mnemonic, bracketed: the key's last letter where it starts a word of
-- the label, in the key's own case, "[f]iles", "Hunks to [q]uickfix",
-- "[b]lame line" and "[B]lame file". A label with no such letter is left
-- alone rather than given a false one, and a label that already has brackets
-- was written by hand (keymaps.lua says when).

--- @param lhs string
--- @param label string
--- @return string
local function with_mnemonic(lhs, label)
  if label:find("[", 1, true) then return label end
  -- The last key: the letter of a <C-x>, else the last character outside <>.
  local key = lhs:gsub("<[^>]+>", function(k) return k:match("^<[CMSA]%-(%a)>$") or "" end):sub(-1)
  if not key:match("%a") then return label end
  local at = label:find("%f[%a][" .. key:lower() .. key:upper() .. "]")
  if not at then return label end
  return label:sub(1, at - 1) .. "[" .. key .. "]" .. label:sub(at + 1)
end

M.with_mnemonic = with_mnemonic

-- ── Apply ───────────────────────────────────────────────────────────────────

local skipped = {}
local created = {} -- { lhs, mode, desc } of the entries that became mappings

local function apply(m)
  local rhs = m[2]
  if not available(m.needs) then
    rhs = m.fallback
    if rhs == nil then
      table.insert(skipped, ("%s (needs %s)"):format(m[1], m.needs))
      return
    end
  end
  local desc = with_mnemonic(m[1], m.desc)
  vim.keymap.set(m.mode or "n", m[1], rhs, { desc = desc, silent = true, expr = m.expr })
  table.insert(created, { lhs = m[1], mode = m.mode, desc = desc })
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

-- ── Relabel Neovim's own mappings ───────────────────────────────────────────
-- What the label set is for: which-key is the first place to look for a
-- key, so every label there should read as one sentence of plain words,
-- with the mnemonic bracketed (with_mnemonic, above), whatever defined the
-- key. Ours come from keymaps.lua; which-key's presets cover most of Vim's
-- built-ins (presets(), below); this block covers Neovim's own default
-- mappings, whose descriptions are written for :map rather than for a
-- popup. Behaviour is never touched: core's callback or rhs is reused with
-- its flags, only the description changes, and an entry whose key a future
-- Neovim no longer maps is skipped silently.
--
-- When a default mapping gains a good description upstream, drop its row;
-- when a new default arrives with a bad one, add a row. The ugly shapes to
-- look for in `:map`: a function name ("vim.lsp.buf.rename()"), a bare Ex
-- command (":cnext"), a help pointer (":help Y-default"), or a sentence too
-- long for a popup column.

local core_labels = {
  -- LSP, described upstream by the function they call.
  { "n", "grn", "Re[n]ame symbol" },
  { "n", "gra", "Code action" },
  { "x", "gra", "Code action" },
  { "n", "grr", "References" },
  { "n", "gri", "Implementation" },
  { "n", "grt", "Type definition" },
  { "n", "grx", "Execute codelens" },
  { "n", "gO", "Outline: this file's symbols" },
  { "i", "<C-s>", "Signature help" },
  { "s", "<C-s>", "Signature help" },
  { "i", "<Tab>", "Next snippet placeholder, else Tab" },
  { "s", "<Tab>", "Next snippet placeholder, else Tab" },
  { "i", "<S-Tab>", "Previous snippet placeholder, else Shift-Tab" },
  { "s", "<S-Tab>", "Previous snippet placeholder, else Shift-Tab" },

  -- Diagnostics, described upstream in a sentence too long for the popup;
  -- these sit next to our "Next [e]rror" and should read the same.
  { "n", "]d", "Next diagnostic" },
  { "n", "[d", "Previous diagnostic" },
  { "n", "]D", "Last diagnostic" },
  { "n", "[D", "First diagnostic" },

  -- The bracket family (unimpaired, absorbed by core), described upstream
  -- by the Ex command each runs: "]q :cnext". The ] popup is the one a
  -- learner opens most, so these read as prose like the rest of it.
  { "n", "]q", "Next quickfix item" },
  { "n", "[q", "Previous quickfix item" },
  { "n", "]Q", "Last quickfix item" },
  { "n", "[Q", "First quickfix item" },
  { "n", "]<C-Q>", "Next file in the quickfix list" },
  { "n", "[<C-Q>", "Previous file in the quickfix list" },
  { "n", "]l", "Next location-list item" },
  { "n", "[l", "Previous location-list item" },
  { "n", "]L", "Last location-list item" },
  { "n", "[L", "First location-list item" },
  { "n", "]<C-L>", "Next file in the location list" },
  { "n", "[<C-L>", "Previous file in the location list" },
  { "n", "]b", "Next buffer" },
  { "n", "[b", "Previous buffer" },
  { "n", "]B", "Last buffer" },
  { "n", "[B", "First buffer" },
  { "n", "]a", "Next argument" },
  { "n", "[a", "Previous argument" },
  { "n", "]A", "Last argument" },
  { "n", "[A", "First argument" },
  { "n", "]t", "Next tag match" },
  { "n", "[t", "Previous tag match" },
  { "n", "]T", "Last tag match" },
  { "n", "[T", "First tag match" },
  { "n", "]<C-T>", "Next tag match, in the preview window" },
  { "n", "[<C-T>", "Previous tag match, in the preview window" },

  -- Described upstream by a pointer to their help (":help Y-default").
  { "n", "Y", "Yank to end of line" },
  { "n", "&", "Repeat last substitute, with its flags" },
  { "x", "*", "Search the selection forwards" },
  { "x", "#", "Search the selection backwards" },
  { "x", "@", "Run a macro on each selected line" },
  { "x", "Q", "Repeat the last macro on each selected line" },

  -- Described upstream at length.
  { "n", "gx", "Open the file or URL under the cursor" },
  { "x", "gx", "Open the selected file or URL" },
}

for _, entry in ipairs(core_labels) do
  local mode, lhs, desc = entry[1], entry[2], entry[3]
  local m = vim.fn.maparg(lhs, mode, false, true)
  -- A Lua mapping carries its callback; a Vimscript one its rhs, kept with
  -- the remap flag it was defined with.
  local rhs = m and (m.callback or m.rhs)
  if rhs then
    vim.keymap.set(mode, lhs, rhs, {
      desc = with_mnemonic(lhs, desc),
      silent = m.silent == 1,
      expr = m.expr == 1,
      remap = m.noremap == 0,
      replace_keycodes = m.expr == 1 and m.replace_keycodes == 1 or nil,
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
      local cur = vim.fn.maparg(m.lhs, mode, false, true)
      if cur.desc ~= m.desc then
        local line = ("%s %s: now %s, ours %q"):format(mode, m.lhs, cur.lhs and ("%q"):format(cur.desc or "") or "unmapped", m.desc)
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

--- which-key's preset labels, bracketed. Empty when the presets module is
--- not as expected.
--- @return table[]
function M.presets()
  local ok, presets = pcall(require, "which-key.plugins.presets")
  if not ok or type(presets) ~= "table" then return {} end
  local out = {}
  for _, set in pairs(presets) do
    if type(set) == "table" and set.preset then
      for _, item in ipairs(set) do
        if type(item) == "table" and type(item[1]) == "string" and type(item.desc) == "string" then
          table.insert(out, { item[1], desc = with_mnemonic(item[1], item.desc), mode = set.mode })
        end
      end
    end
  end
  return out
end

-- ── which-key ───────────────────────────────────────────────────────────────
-- Only labels prefixes; the mappings themselves come from the table above.

local ok, wk = pcall(require, "which-key")
if ok then
  wk.setup({
    -- A full second: the popup is for a real pause, never a quick sequence.
    -- Independent of 'timeoutlen', which still resolves pending mappings.
    delay = 1000,
    -- Sizes itself as borderless, so it must not inherit 'winborder'.
    win = { border = "none" },
    -- No picture per label. The special keys keep which-key's glyphs: Nerd
    -- Font ones, which the terminal's font draws, so they survive SSH; a
    -- plain font shows a box in that one cell, the columns unmoved.
    icons = { mappings = false },
    -- Groups first, then key order as the eye scans for a letter: letters
    -- before symbols, lowercase before uppercase. which-key's own "group"
    -- sorter puts groups last, hence the function.
    sort = { "local", function(item) return item.group and 0 or 1 end, "alphanum" },
  })

  local groups = {}
  for _, g in ipairs(spec.groups) do
    table.insert(groups, { g[1], group = with_mnemonic(g[1], g[2]), mode = g.mode })
  end
  wk.add(groups)

  -- Vim's own keys too, as which-key labels them in its presets ("gi: Go to
  -- last insert"), so the popup reads as one: each label through the same
  -- bracketing, handed back as a label-only entry, which is how the presets
  -- themselves work. A learning aid, to drop once the keys are familiar.
  --
  -- The presets module is not API. Everything here is guarded, so a which-key
  -- that reshapes it loses the brackets and nothing else; :checkhealth config
  -- says so (presets()).
  wk.add(M.presets())
end

return M
