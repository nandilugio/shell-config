-- Syntax and folds from real parse trees.
--
-- The `main` branch has a narrower job than the old one: it installs parsers
-- and ships queries, and Neovim's own vim.treesitter does the rest, so
-- highlighting is started per buffer below rather than by the plugin.
--
-- Parsers are compiled on install, so this needs a C compiler and the
-- tree-sitter CLI. Without them Neovim falls back to regex highlighting.

local ok, ts = pcall(require, "nvim-treesitter")
if not ok then return end

ts.setup({})

local parsers = {
  "bash", "c", "css", "diff", "dockerfile", "gitcommit", "git_rebase",
  "html", "javascript", "json", "lua", "luadoc", "markdown",
  "markdown_inline", "python", "query", "ruby", "sql", "toml", "tsx",
  "typescript", "vim", "vimdoc", "yaml",
}

local installed = {}
for _, lang in ipairs(ts.get_installed()) do
  installed[lang] = true
end

local missing = vim.tbl_filter(function(p) return not installed[p] end, parsers)

if #missing > 0 then
  if vim.fn.executable("tree-sitter") == 1 then
    -- Installs run asynchronously; mark them present so buffers opened later
    -- in this session pick them up without a restart.
    ts.install(missing)
    for _, lang in ipairs(missing) do
      installed[lang] = true
    end
  else
    -- Not fatal, but easy to mistake for a broken colourscheme.
    vim.schedule(function()
      vim.notify(
        ("%d treesitter parsers are missing and tree-sitter-cli is not installed "):format(#missing)
          .. "(brew install tree-sitter-cli). Using regex highlighting.",
        vim.log.levels.WARN
      )
    end)
  end
end

vim.treesitter.language.register("markdown", "vimwiki")

local function start(buf)
  local lang = vim.treesitter.language.get_lang(vim.bo[buf].filetype)
  if not lang or not installed[lang] then return end

  pcall(vim.treesitter.start, buf, lang)

  -- Ruby is the exception: its legacy indent rules beat the treesitter ones.
  if vim.bo[buf].filetype ~= "ruby" then
    vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
  end
end

vim.api.nvim_create_autocmd("FileType", {
  callback = function(args) start(args.buf) end,
})

-- A file named on the command line fired FileType before this module loaded.
for _, buf in ipairs(vim.api.nvim_list_bufs()) do
  if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype ~= "" then
    start(buf)
  end
end
