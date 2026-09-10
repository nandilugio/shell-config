-- Notes. vimwiki is configured through globals, which must be set before its
-- plugin files load — hence init, not a setup() call.

vim.g.vimwiki_list = {
  { path = "~/notes", syntax = "markdown", ext = ".md" },
}
vim.g.vimwiki_markdown_link_ext = 1

-- vimwiki otherwise claims every .md file in existence, including READMEs.
vim.g.vimwiki_global_ext = 0

-- By default vimwiki maps <leader>w plus a family of <leader>w* keys, which
-- collides with the window namespace. Suppress them; keymaps.lua puts the
-- entry points under <leader>o instead, where nothing else competes.
vim.g.vimwiki_key_mappings = {
  global = 0, -- <leader>ww, <leader>wt, <leader>wi, <leader>ws ...
}
