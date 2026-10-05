-- Notes. vimwiki configures through globals, which must be set before its
-- plugin files load — hence init, not setup().

vim.g.vimwiki_list = {
  { path = "~/notes", syntax = "markdown", ext = ".md" },
}
vim.g.vimwiki_markdown_link_ext = 1

-- vimwiki otherwise claims every .md file in existence, including READMEs.
vim.g.vimwiki_global_ext = 0

-- vimwiki's default <leader>w* family collides with the window namespace.
-- keymaps.lua puts the entry points under <leader>o instead.
vim.g.vimwiki_key_mappings = {
  global = 0, -- <leader>ww, <leader>wt, <leader>wi, <leader>ws ...
}
