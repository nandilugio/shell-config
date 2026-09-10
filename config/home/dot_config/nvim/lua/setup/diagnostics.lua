-- How problems are shown. Nvim 0.12 enables diagnostics automatically when an
-- LSP attaches; this only adjusts presentation.

vim.diagnostic.config({
  -- Errors inline, everything else in the sign column and on hover. Keeps the
  -- buffer readable in files with many warnings.
  virtual_text = { severity = { min = vim.diagnostic.severity.ERROR }, spacing = 2 },
  underline = true,
  severity_sort = true,
  update_in_insert = false, -- do not churn while typing
  float = { border = "rounded", source = true },
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = "E",
      [vim.diagnostic.severity.WARN] = "W",
      [vim.diagnostic.severity.INFO] = "I",
      [vim.diagnostic.severity.HINT] = "H",
    },
  },
})
