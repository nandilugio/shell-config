-- Winbar: where you are inside the file.
--
-- 'winbar' is a built-in option, evaluated like 'statusline', drawn at the top
-- of each window. It carries the breadcrumb — Sideqik › SerializeSupport ›
-- serialize — which in a deep file answers "what am I inside?" without
-- scrolling up to find out.
--
-- The symbol tree comes from the language server, which is slow to ask, so it
-- is fetched on a pause and cached per buffer; the winbar itself only reads
-- the cache.

local M = {}

-- Symbol kinds worth naming. Variables and fields would make the trail noisy
-- without saying much.
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
    local line = vim.api.nvim_win_get_cursor(0)[1] - 1
    vim.b[buf].winbar_trail = table.concat(innermost_path(symbols, line, {}), " › ")
    vim.cmd.redrawstatus()
  end, buf)
end

vim.api.nvim_create_autocmd({ "CursorHold", "BufEnter" }, {
  callback = function(args) pcall(refresh, args.buf) end,
})

function M.render()
  -- %#..# with no closing %* paints to the end of the line, so the whole bar
  -- carries the colour rather than just the text. An empty trail still paints
  -- the bar: turning the option on and off would change the window height and
  -- shove the buffer around while you move.
  return "%#WinBarPath# " .. (vim.b.winbar_trail or "") .. " "
end

-- The whole bar takes the cursor line's background, so it reads as part of
-- the same "where you are" cue rather than as another band of chrome.
local function set_highlight()
  vim.api.nvim_set_hl(0, "WinBarPath", {
    fg = vim.api.nvim_get_hl(0, { name = "Comment", link = false }).fg,
    bg = vim.api.nvim_get_hl(0, { name = "CursorLine", link = false }).bg,
  })
end
set_highlight()
vim.api.nvim_create_autocmd("ColorScheme", { callback = set_highlight })

-- Enabled once, when a language server that can supply symbols attaches. That
-- is both the condition for ever having a breadcrumb and a stable one: gating
-- on the trail itself would add and remove a screen line as the cursor moves,
-- which shifts the buffer under you.
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if not client or not client:supports_method("textDocument/documentSymbol") then return end
    if vim.bo[args.buf].buftype ~= "" then return end

    for _, win in ipairs(vim.fn.win_findbuf(args.buf)) do
      if vim.api.nvim_win_get_config(win).relative == "" then
        vim.wo[win].winbar = "%{%v:lua.require'setup.winbar'.render()%}"
      end
    end
  end,
})

return M
