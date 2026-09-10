-- Statusline.
--
-- Neovim 0.12's default already carries the filename, modified and readonly
-- flags, LSP progress, a busy spinner, diagnostic counts and the ruler. The
-- mode comes from 'showmode', in the command line below. Two things are
-- missing, and are added here: the git branch and the filetype.
--
-- Built by extending the default rather than replacing it, so anything Neovim
-- adds later arrives for free.

-- Colours are derived from the active colourscheme rather than hardcoded, so
-- they follow it when it changes. Foregrounds come from groups that already
-- mean the right thing; the background is the statusline's own.
local function set_highlights()
  local function fg_of(group)
    return vim.api.nvim_get_hl(0, { name = group, link = false }).fg
  end

  local bg = vim.api.nvim_get_hl(0, { name = "StatusLine", link = false }).bg

  vim.api.nvim_set_hl(0, "StatuslineBranch", { fg = fg_of("Special"), bg = bg })
  vim.api.nvim_set_hl(0, "StatuslineFiletype", { fg = fg_of("Comment"), bg = bg })
end

set_highlights()
vim.api.nvim_create_autocmd("ColorScheme", { callback = set_highlights })

local function git_branch()
  local head = vim.b.gitsigns_head
  return head and ("  " .. head .. " ") or ""
end

local function filetype()
  local ft = vim.bo.filetype
  return ft ~= "" and (" " .. ft .. " ") or ""
end

_G.Statusline = { branch = git_branch, filetype = filetype }

-- %= splits left from right; insert ours just before the default's right-hand
-- group so the ruler stays where the eye expects it. %#Group# switches colour,
-- %* returns to the statusline default.
vim.o.statusline = vim.o.statusline:gsub(
  "%%=",
  "%%=%%#StatuslineBranch#%%{v:lua.Statusline.branch()}"
    .. "%%#StatuslineFiletype#%%{v:lua.Statusline.filetype()}%%*",
  1
)
