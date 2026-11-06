-- Tests the health check itself:  nvim -l lua/config/health_test.lua
--
-- :checkhealth config is where this config lists what it depends on and does
-- not control -- tools, servers, parsers, keymaps, and the surface it uses in
-- each plugin (the contract table in health.lua). Run after a plugin update,
-- or by hand, this fails on any ERROR line and prints the rest, so a plugin
-- that moved something is named here before a keypress finds it.
--
-- A WARN is a missing optional tool, which is allowed by design, so only
-- ERROR fails. The config repository is a git repository, so a file from it
-- gets gitsigns attached, which lets the status-dict fields be checked.

if not package.loaded["setup.keymaps"] then dofile(vim.fn.stdpath("config") .. "/init.lua") end

vim.cmd.edit(vim.fn.stdpath("config") .. "/init.lua")
vim.wait(3000, function() return vim.b.gitsigns_status_dict ~= nil end)

vim.cmd("checkhealth config")
local report = vim.api.nvim_buf_get_lines(0, 0, -1, false)

local errors = {}
for _, line in ipairs(report) do
  if line:find("ERROR", 1, true) then table.insert(errors, line) end
end

for _, line in ipairs(report) do
  if line:find("WARN", 1, true) or line:find("ERROR", 1, true) then io.write(line, "\n") end
end
io.write(("\n%d errors in :checkhealth config\n"):format(#errors))
os.exit(#errors == 0 and 0 or 1)
