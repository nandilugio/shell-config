-- File browsing.
--
-- mini.files shows a directory as an editable buffer: rename a line to rename
-- the file, delete a line to delete it, then `=` to apply. It replaces netrw,
-- which is deprecated and carries an unpatched code-execution path.
--
-- Its keys are Vim-shaped: h/l out and in, q close, m and ' marks, g? help.

local ok, files = pcall(require, "mini.files")
if not ok then return end

files.setup({
  options = {
    -- A bulk edit applied in one keystroke deserves a recoverable delete.
    permanent_delete = false,
    use_as_default_explorer = true,
  },
  windows = { preview = true, width_preview = 60 },
})
