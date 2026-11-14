-- Training mode (<leader>ut): other editors' keys off, each one hinting at
-- Vim's own instead, for practising the motions and edits until they are the
-- habit. Off by default, and for this session only.
--
-- Two presets, each a complete set of the same keys and options, as review
-- mode does (setup/review.lua): applying one writes all of it, so switching
-- always lands in the same place whatever came between. compat is applied at
-- startup. Each setting has one owner: training mode owns these keys and
-- 'whichwrap', review mode its own list, so the two switch independently, in
-- any order. A setting both wanted would need one of them to give it up.
--
-- Only keys that duplicate Vim's motions and edits: arrows, Home/End,
-- PageUp/PageDown, the Shift-arrows, Tab on a selection, <C-Space> and Enter
-- for completion, and the split keys. Arrows that Vim itself uses widely stay
-- as they are: the command line's history, the completion menu, terminal mode.
--
-- A hint is an expression mapping that types nothing and says what to use, so
-- the mode is kept: insert stays insert, a selection stays selected, and an
-- operator waiting for its motion (d<Down>) is cancelled.

local M = {}

local keymaps = require("setup.keymaps")

local function say(text)
  vim.api.nvim_echo({ { "Training: " .. text, "WarningMsg" } }, false, {})
end

-- Normal, visual, select and operator-pending: everywhere a motion is typed.
local MOTION = { "n", "x", "s", "o" }

local function hint(lhs, mode, text)
  return {
    lhs,
    function()
      vim.schedule(function() say(text) end)
      return vim.api.nvim_get_mode().mode:sub(1, 2) == "no" and "<Esc>" or ""
    end,
    desc = "Training: " .. text,
    mode = mode,
    expr = true,
  }
end

-- In insert mode a motion needs <Esc> first, or <C-o> for one command.
local function hints(lhs, text, insert_text)
  return { hint(lhs, MOTION, text), hint(lhs, "i", insert_text or ("<Esc>, then " .. text)) }
end

local function concat(lists)
  local out = {}
  for _, list in ipairs(lists) do vim.list_extend(out, list) end
  return out
end

local function accepts_selected() return vim.fn.complete_info({ "selected" }).selected ~= -1 end

local PRESETS = {
  compat = {
    -- Left and right cross line ends, as in other editors; h and l stay on
    -- the line.
    whichwrap = "b,s,<,>,[,]",
    maps = {
      -- Arrows by screen line; j and k stay Vim's, by line. In every mode, so
      -- an operator takes the arrow's meaning too: d<Down> deletes to the same
      -- column a screen line down, dj whole lines.
      { "<Down>", "g<Down>", desc = "Down a screen line", mode = { "n", "x", "o" } },
      { "<Up>", "g<Up>", desc = "Up a screen line", mode = { "n", "x", "o" } },
      -- A Select mode map would type the g over the selection: <C-g> runs the
      -- motion in Visual mode and comes back.
      { "<Down>", "<C-g>g<Down><C-g>", desc = "Down a screen line", mode = "s" },
      { "<Up>", "<C-g>g<Up><C-g>", desc = "Up a screen line", mode = "s" },
      -- The completion menu keeps its own <Down> and <Up>. <C-\><C-o> rather
      -- than <C-o>, which would pull the cursor back off the end of the line.
      {
        "<Down>",
        function() return vim.fn.pumvisible() == 1 and "<Down>" or "<C-\\><C-o>g<Down>" end,
        desc = "Down a screen line, or the next completion",
        mode = "i",
        expr = true,
      },
      {
        "<Up>",
        function() return vim.fn.pumvisible() == 1 and "<Up>" or "<C-\\><C-o>g<Up>" end,
        desc = "Up a screen line, or the previous completion",
        mode = "i",
        expr = true,
      },

      -- Keeping the selection, so the key can be pressed again. Visual only:
      -- Tab is CTRL-I (jump forward) in normal mode, and Select mode's Tab
      -- jumps between snippet placeholders.
      { "<Tab>", ">gv", desc = "Indent selection", mode = "x" },
      { "<S-Tab>", "<gv", desc = "Dedent selection", mode = "x" },

      -- tmux's mnemonic: | is a vertical divider, - a horizontal one.
      { "<leader>-", "<Cmd>split<CR>", desc = "Split below" },
      { "<leader>|", "<Cmd>vsplit<CR>", desc = "Split right" },

      -- The cross-editor key, but many terminals never send it: it is the NUL
      -- byte, which readline, some tmux configs and macOS input switching all
      -- eat. Nothing depends on it working; <C-n> always arrives.
      { "<C-Space>", "<C-n>", desc = "Completion menu", mode = "i" },
      -- Accepts only once something is selected, so the menu never changes
      -- what ordinary typing does: Enter still gives a newline unless you moved
      -- to a candidate. <C-y> accepts regardless, <C-e> dismisses.
      {
        "<CR>",
        function() return accepts_selected() and "<C-y>" or "<CR>" end,
        desc = "Accept selected completion, else newline",
        mode = "i",
        expr = true,
      },
    },
  },

  strict = {
    whichwrap = "b,s", -- Neovim's default
    maps = concat({
      hints("<Down>", "j, or gj by screen line"),
      hints("<Up>", "k, or gk by screen line"),
      hints("<Left>", "h, or b by word"),
      hints("<Right>", "l, or w by word"),
      hints("<S-Down>", "<C-f> a page, <C-d> half"),
      hints("<S-Up>", "<C-b> a page, <C-u> half"),
      hints("<S-Left>", "b"),
      hints("<S-Right>", "w"),
      hints("<PageDown>", "<C-f>, or <C-d> by half"),
      hints("<PageUp>", "<C-b>, or <C-u> by half"),
      hints("<Home>", "0, or ^ to the first character", "<Esc>I, or <C-o>0"),
      hints("<End>", "$", "<Esc>A, or <C-o>$"),
      { hint("<Tab>", "x", "> then . to repeat, u to undo one") },
      { hint("<S-Tab>", "x", "< then . to repeat, u to undo one") },
      { hint("<leader>-", "n", "<C-w>s") },
      { hint("<leader>|", "n", "<C-w>v") },
      { hint("<C-Space>", "i", "<C-n>") },
      {
        {
          "<CR>",
          function()
            if not accepts_selected() then return "<CR>" end
            vim.schedule(function() say("<C-y> accepts") end)
            return ""
          end,
          desc = "Newline; training: <C-y> accepts a completion",
          mode = "i",
          expr = true,
        },
      },
    }),
  },
}

local active = "compat"

local function apply(name)
  local preset = PRESETS[name]
  for _, p in pairs(PRESETS) do keymaps.del(p.maps) end
  keymaps.set(preset.maps)
  vim.o.whichwrap = preset.whichwrap
  active = name
end

--- Whether training mode is on, for the statusline's marker.
--- @return boolean
function M.on() return active == "strict" end

function M.toggle()
  apply(M.on() and "compat" or "strict")
  vim.cmd.redrawstatus({ bang = true })
  vim.api.nvim_echo({ { M.on() and "Training mode: Vim's keys only" or "Training mode off" } }, false, {})
end

apply("compat")

return M
