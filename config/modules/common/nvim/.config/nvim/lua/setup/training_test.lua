-- Tests for setup/training.lua:  nvim -l lua/setup/training_test.lua
--
-- No framework; exit code is 0 when all pass. -l loads the real config, so the
-- keys are the ones in use, pressed through feedkeys. The risky part is the
-- way back: leaving training mode must put every compat key back as it was and
-- leave none of the hints behind.

local passed, failed = 0, 0

local function check(name, got, want)
  if vim.deep_equal(got, want) then
    passed = passed + 1
  else
    failed = failed + 1
    io.write(("FAIL  %s\n        got:  %s\n        want: %s\n"):format(name, vim.inspect(got), vim.inspect(want)))
  end
end

if not package.loaded["setup.keymaps"] then dofile(vim.fn.stdpath("config") .. "/init.lua") end

local training = require("setup.training")
local keymaps = require("setup.keymaps")

-- A line long enough to wrap, then two short ones.
local LONG = string.rep("word ", 40)

local function reset(lines)
  vim.cmd("silent! only! | enew!")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines or { LONG, "next", "last" })
  vim.api.nvim_win_set_cursor(0, { 1, 3 })
end

local function press(keys) vim.api.nvim_feedkeys(vim.keycode(keys), "xt", false) end
local function pos() return vim.api.nvim_win_get_cursor(0) end
local function buf() return vim.api.nvim_buf_get_lines(0, 0, -1, false) end
local function mode() return vim.api.nvim_get_mode().mode end

-- Every mapping on the keys either preset touches, as maparg() reports it.
local KEYS = {
  "<Down>", "<Up>", "<Left>", "<Right>", "<S-Down>", "<S-Up>", "<S-Left>", "<S-Right>",
  "<PageDown>", "<PageUp>", "<Home>", "<End>", "<Tab>", "<S-Tab>", "<leader>-", "<leader>|",
  "<C-Space>", "<CR>",
}
local function snapshot()
  local out = {}
  for _, key in ipairs(KEYS) do
    for _, m in ipairs({ "n", "x", "s", "o", "i" }) do
      local d = vim.fn.maparg(key, m, false, true)
      if d.lhs then out[m .. " " .. key] = { desc = d.desc, rhs = d.rhs, expr = d.expr, lua = d.callback ~= nil } end
    end
  end
  return out
end

-- ── compat, at startup ──────────────────────────────────────────────────────

check("starts in compat", training.on(), false)
local compat = snapshot()

reset()
press("<Down>")
check("compat: <Down> moves a screen line, within the line", pos()[1], 1)
check("compat: <Down> moves at all", pos()[2] > 3, true)

reset()
press("j")
check("compat: j moves a line", pos(), { 2, 3 })

reset({ "a", "b", "c" })
vim.api.nvim_win_set_cursor(0, { 1, 0 })
press("Vj<Tab><Tab>")
check("compat: <Tab> indents the selection, twice", buf(), { "    a", "    b", "c" })
check("compat: <Tab> keeps the selection", mode(), "V")
press("<Esc>")

reset({ "ab" })
vim.api.nvim_win_set_cursor(0, { 1, 1 })
press("i<CR><Esc>")
check("compat: <CR> without a menu is a newline", buf(), { "a", "b" })

-- Two candidates, so the first <C-n> opens the menu (noselect) and the second
-- selects alpha.
reset({ "alpha", "alpine", "" })
vim.api.nvim_win_set_cursor(0, { 3, 0 })
press("ial<C-n><C-n><CR><Esc>")
check("compat: <CR> accepts the selected completion, no newline", buf(), { "alpha", "alpine", "alpha" })

reset()
press(" -")
check("compat: <leader>- splits", #vim.api.nvim_tabpage_list_wins(0), 2)

check("compat: whichwrap crosses line ends", vim.o.whichwrap, "b,s,<,>,[,]")
check("compat: nothing overridden", { keymaps.overridden() }, { {}, {} })

-- ── strict ──────────────────────────────────────────────────────────────────

training.toggle()
check("toggle turns it on", training.on(), true)
check("statusline marks it", require("setup.statusline").mode():match("NORMAL%*") ~= nil, true)
check("strict: whichwrap is Neovim's", vim.o.whichwrap, "b,s")
check("strict: nothing overridden", { keymaps.overridden() }, { {}, {} })

for _, key in ipairs({ "<Down>", "<Up>", "<Left>", "<Right>", "<S-Down>", "<S-Right>", "<PageDown>", "<Home>", "<End>" }) do
  reset()
  press(key)
  check("strict: normal " .. key .. " stays put", { pos(), mode() }, { { 1, 3 }, "n" })
end

reset()
press("j")
check("strict: j still moves", pos(), { 2, 3 })

-- In Visual and Select mode only the cursor is checked: under feedkeys(), a
-- mapping that types nothing ends Visual mode even with --clean and <Nop>,
-- which a real keypress does not (checked by hand in a terminal, 2026-11-14).
reset()
press("v<Down>")
check("strict: visual <Down> stays put", pos(), { 1, 3 })
press("<Esc>")

reset()
press("gh<Right>")
check("strict: select <Right> stays put", pos(), { 1, 3 })
press("<Esc>")

reset()
press("d<Down>")
check("strict: d<Down> deletes nothing", buf(), { LONG, "next", "last" })
check("strict: d<Down> leaves no operator pending", mode(), "n")

reset()
press("i<Down><End>X<Esc>")
check("strict: insert arrows and End type nothing and stay in insert", buf()[1], "worX" .. LONG:sub(4))

reset({ "a", "b", "c" })
vim.api.nvim_win_set_cursor(0, { 1, 0 })
press("Vj<Tab>")
check("strict: <Tab> does not indent", buf(), { "a", "b", "c" })
press("<Esc>")

reset({ "ab" })
vim.api.nvim_win_set_cursor(0, { 1, 1 })
press("i<CR><Esc>")
check("strict: <CR> without a menu is still a newline", buf(), { "a", "b" })

-- As in compat above. Accepted, alpha would stay; left open, the <Esc> that follows
-- dismisses it (options.lua) and puts back what was typed.
reset({ "alpha", "alpine", "" })
vim.api.nvim_win_set_cursor(0, { 3, 0 })
press("ial<C-n><C-n><CR><Esc>")
check("strict: <CR> on a selected completion accepts nothing, adds no line", buf(), { "alpha", "alpine", "al" })

reset()
press(" -")
check("strict: <leader>- does not split", #vim.api.nvim_tabpage_list_wins(0), 1)

-- ── back to compat ──────────────────────────────────────────────────────────

training.toggle()
check("toggle turns it off", training.on(), false)
check("back: every compat key as it was, no hint left", snapshot(), compat)
check("back: whichwrap restored", vim.o.whichwrap, "b,s,<,>,[,]")
check("back: nothing overridden", { keymaps.overridden() }, { {}, {} })
check("back: statusline unmarked", require("setup.statusline").mode():match("NORMAL%*") == nil, true)

reset()
press("<Down>")
check("back: <Down> moves a screen line again", pos()[1] == 1 and pos()[2] > 3, true)

io.write(("%d passed, %d failed\n"):format(passed, failed))
vim.cmd(failed == 0 and "qa!" or "cq!")
