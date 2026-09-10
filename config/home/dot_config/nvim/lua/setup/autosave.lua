-- Autosave, replacing save.nvim (unmaintained since 2024, ran on every
-- text change). Two modes, toggled rather than cycled:
--
--   off   (default) nothing is written unless you ask
--   on    write the buffer when it loses focus or you leave insert mode
--
-- Deliberately not "save on every keystroke": that fights format-on-save,
-- file watchers and test runners, and makes every intermediate state a real
-- file on disk.

local M = { enabled = false }

local group = vim.api.nvim_create_augroup("autosave", { clear = true })

local function save_if_sensible()
  if not M.enabled then return end
  local buf = vim.api.nvim_get_current_buf()
  if not vim.bo[buf].modified then return end
  if vim.bo[buf].buftype ~= "" then return end -- terminals, quickfix, help
  if vim.bo[buf].readonly or not vim.bo[buf].modifiable then return end
  if vim.api.nvim_buf_get_name(buf) == "" then return end -- never named
  vim.cmd("silent! write")
end

vim.api.nvim_create_autocmd({ "InsertLeave", "FocusLost", "BufLeave" }, {
  group = group,
  callback = save_if_sensible,
})

function M.toggle()
  M.enabled = not M.enabled
  vim.notify("Autosave " .. (M.enabled and "on" or "off"))
end

return M
