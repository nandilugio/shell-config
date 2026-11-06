-- Where you are inside the file: Sideqik › SerializeSupport › serialize.
-- 'winbar' is built in and evaluated like 'statusline'.
--
-- The symbol tree comes from the language server, which is slow to ask, so it
-- is fetched on a pause and cached per buffer; the bar only reads the cache.

local M = {}

-- Variables and fields would make the trail noisy without saying much.
local WANTED = {
  Class = true, Method = true, Function = true, Module = true,
  Namespace = true, Struct = true, Interface = true, Constructor = true,
}

local function innermost_path(symbols, line, trail)
  for _, s in ipairs(symbols or {}) do
    local range = s.range or (s.location and s.location.range)
    if range and line >= range.start.line and line <= range["end"].line then
      if WANTED[vim.lsp.protocol.SymbolKind[s.kind]] then
        table.insert(trail, s.name)
      end
      innermost_path(s.children, line, trail)
      break
    end
  end
  return trail
end

local function refresh(buf)
  local clients = vim.lsp.get_clients({ bufnr = buf, method = "textDocument/documentSymbol" })
  if #clients == 0 then return end

  clients[1]:request("textDocument/documentSymbol", {
    textDocument = vim.lsp.util.make_text_document_params(buf),
  }, function(err, symbols)
    if err or not symbols then return end
    -- Asynchronous: the window may show another buffer by now.
    local win = vim.fn.bufwinid(buf)
    if win == -1 then return end
    local line = vim.api.nvim_win_get_cursor(win)[1] - 1
    vim.b[buf].winbar_trail = table.concat(innermost_path(symbols, line, {}), " › ")
    vim.cmd.redrawstatus()
  end, buf)
end

vim.api.nvim_create_autocmd({ "CursorHold", "BufEnter" }, {
  callback = function(args) pcall(refresh, args.buf) end,
})

function M.render()
  -- %#..# with no closing %* paints to the end of the line. An empty trail
  -- still paints: toggling the option would change the window height and shove
  -- the buffer around as the cursor moves.
  return "%#WinBarPath# " .. (vim.b.winbar_trail or "") .. " "
end

-- The cursor line's background, so it reads as the same "where you are" cue
-- rather than another band of chrome.
local function set_highlight()
  vim.api.nvim_set_hl(0, "WinBarPath", {
    fg = vim.api.nvim_get_hl(0, { name = "Comment", link = false }).fg,
    bg = vim.api.nvim_get_hl(0, { name = "CursorLine", link = false }).bg,
  })
end
set_highlight()
vim.api.nvim_create_autocmd("ColorScheme", { callback = set_highlight })

-- A window shows the bar while its buffer has a server that can supply
-- symbols: decided when a buffer enters a window and when a server attaches
-- or leaves, so a window that moves on to a plain file loses the band and
-- one that comes to a code file gains it. Stable within a buffer, whereas
-- gating on the trail itself would add and remove a screen line as the
-- cursor moves.
local BAR = "%{%v:lua.require'setup.winbar'.render()%}"

local function wants_bar(buf)
  if vim.bo[buf].buftype ~= "" then return false end
  return #vim.lsp.get_clients({ bufnr = buf, method = "textDocument/documentSymbol" }) > 0
end

local function decide(win, buf)
  if vim.api.nvim_win_get_config(win).relative ~= "" then return end
  local bar = wants_bar(buf) and BAR or ""
  if vim.wo[win].winbar ~= bar then vim.wo[win].winbar = bar end
end

vim.api.nvim_create_autocmd("BufWinEnter", {
  callback = function(args) decide(vim.api.nvim_get_current_win(), args.buf) end,
})

vim.api.nvim_create_autocmd({ "LspAttach", "LspDetach" }, {
  callback = function(args)
    -- On detach the client is still attached while this runs, so look again
    -- once it has gone.
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(args.buf) then return end
      for _, win in ipairs(vim.fn.win_findbuf(args.buf)) do
        decide(win, args.buf)
      end
    end)
  end,
})

return M
