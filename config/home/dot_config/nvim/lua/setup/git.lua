-- Only the part that belongs in the editor: which lines changed, hunk
-- navigation, staging without leaving the buffer. Commits, rebases and history
-- are lazygit's job, in a tmux pane.

local ok, gitsigns = pcall(require, "gitsigns")
if ok then
  gitsigns.setup({
    -- Diff characters rather than gitsigns' bars, which leave the colour to
    -- carry the meaning; + ~ - read like diff output and git add -p.
    --
    -- Plain UTF-8, no Nerd Font. ‾ is a deletion above the first line, ≃ a
    -- line both changed and partly deleted.
    signs = {
      add = { text = "+" },
      change = { text = "~" },
      delete = { text = "-" },
      topdelete = { text = "‾" },
      changedelete = { text = "≃" },
      untracked = { text = "┆" },
    },
    preview_config = { border = "single" },
  })
end

-- RuboCop via :make, because on Ruby 2.x the server runs under a newer
-- interpreter and cannot reach the project's own rubocop. Neovim ships the
-- compiler definition; results land in the quickfix list.
vim.api.nvim_create_autocmd("FileType", {
  pattern = "ruby",
  callback = function(args)
    vim.cmd("compiler rubocop")
    -- From the file, not the cwd: they differ when opening by path.
    local gemfile = vim.fs.find("Gemfile", {
      upward = true,
      path = vim.fs.dirname(vim.api.nvim_buf_get_name(args.buf)),
    })[1]
    if gemfile then
      vim.bo[args.buf].makeprg = "bundle exec rubocop --format emacs"
    end
  end,
})
