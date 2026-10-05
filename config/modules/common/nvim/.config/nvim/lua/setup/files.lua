-- A directory as an editable buffer: rename a line to rename the file, then `=`
-- to apply. Keys are Vim-shaped: h/l out and in, q close, g? help.
-- Replaces netrw, which options.lua disables.

local ok, files = pcall(require, "mini.files")
if not ok then return end

-- Without mini.icons or nvim-web-devicons, mini.files falls back to Nerd Font
-- glyphs, which are boxes without a patched font. These are plain UTF-8.
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
