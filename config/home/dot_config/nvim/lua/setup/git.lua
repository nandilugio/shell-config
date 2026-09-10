-- Git, but only the part that belongs in the editor.
--
-- Commits, rebases and history are lazygit's job, in a tmux pane. What an
-- editor uniquely offers is the ambient layer: which lines changed, jumping
-- between hunks, staging one without leaving the buffer.

local ok, gitsigns = pcall(require, "gitsigns")
if ok then
  gitsigns.setup({
    -- Diff characters rather than gitsigns' default bars. A bar says only
    -- "something changed here" and leaves the colour to carry the meaning;
    -- + ~ - say which, and read the same way as diff output, git add -p and
    -- every review tool.
    --
    -- Plain UTF-8, no Nerd Font: these live in the Basic Multilingual Plane
    -- and render in any modern monospace font. ‾ marks a deletion above the
    -- first line, ≃ a line both changed and partly deleted.
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

-- RuboCop via :make, because ruby-lsp cannot always provide it: on a Ruby 2.x
-- project the server runs under a newer interpreter and so cannot reach the
-- project's own rubocop. Neovim ships the compiler definition; results land in
-- the quickfix list, which ]q and [q navigate.
vim.api.nvim_create_autocmd("FileType", {
  pattern = "ruby",
  callback = function(args)
    vim.cmd("compiler rubocop")
    -- Search upward from the file, not the working directory: they differ
    -- whenever a file is opened by path from elsewhere.
    local gemfile = vim.fs.find("Gemfile", {
      upward = true,
      path = vim.fs.dirname(vim.api.nvim_buf_get_name(args.buf)),
    })[1]
    if gemfile then
      vim.bo[args.buf].makeprg = "bundle exec rubocop --format emacs"
    end
  end,
})
