-- File browsing.
--
-- mini.files shows a directory as an editable buffer: rename a line to rename
-- the file, delete a line to delete it, then `=` to apply. It replaces netrw,
-- which is deprecated and carries an unpatched code-execution path.
--
-- Its keys are Vim-shaped: h/l out and in, q close, m and ' marks, g? help.

local ok, files = pcall(require, "mini.files")
if not ok then return end

-- mini.files falls back to Nerd Font glyphs when neither mini.icons nor
-- nvim-web-devicons is installed, and there is no plainer fallback behind
-- those — so it would show boxes on a machine without a patched font. This
-- prefix keeps to characters any monospace font has.
local ICONS = {
  directory = { "▸ ", "MiniFilesDirectory" },
  lua = { "· " }, py = { "· " }, rb = { "· " }, js = { "· " }, ts = { "· " },
  sh = { "$ " }, bash = { "$ " }, zsh = { "$ " },
  json = { "⚙ " }, toml = { "⚙ " }, yaml = { "⚙ " }, yml = { "⚙ " }, ini = { "⚙ " },
  md = { "¶ " }, txt = { "¶ " }, rst = { "¶ " },
  lock = { "⊘ " },
}

local function prefix(entry)
  if entry.fs_type == "directory" then
    return ICONS.directory[1], ICONS.directory[2]
  end
  local ext = entry.name:match("%.([^.]+)$")
  local icon = ext and ICONS[ext:lower()]
  return icon and icon[1] or "  ", icon and icon[2] or "MiniFilesFile"
end

files.setup({
  content = { prefix = prefix },
  options = {
    -- A bulk edit applied in one keystroke deserves a recoverable delete.
    permanent_delete = false,
    use_as_default_explorer = true,
  },
  windows = { preview = true, width_preview = 60 },
})
