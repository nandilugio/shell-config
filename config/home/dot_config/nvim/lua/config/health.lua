-- :checkhealth config
--
-- Reports on the things this config depends on but does not control: external
-- binaries, language servers that must actually attach, parsers that must be
-- compiled, and keymaps that might have been claimed by a plugin.
--
-- Everything here is optional by design — the config degrades rather than
-- breaks — so a missing tool is a warning, never an error.

local H = vim.health
local M = {}

-- What each external tool buys, and what happens without it.
local tools = {
  { "fzf", "fuzzy finding", "<leader>f* fall back to :find and :grep" },
  { "rg", "fast :grep", "falls back to the built-in grep" },
  { "fd", "fast file listing", "fzf-lua uses its own walker" },
  { "git", "hunk signs and navigation", "gitsigns does nothing outside a repo" },
  { "lazygit", "<leader>gg", "mapping is not created" },
  { "tree-sitter", "parser compilation", "regex syntax highlighting only" },
}

local servers = {
  { "basedpyright", "python" },
  { "ruff", "python" },
  { "lua-language-server", "lua" },
}

local function check_tools()
  H.start("External tools")
  for _, t in ipairs(tools) do
    local exe, buys, without = t[1], t[2], t[3]
    if vim.fn.executable(exe) == 1 then
      H.ok(("%s — %s"):format(exe, buys))
    else
      H.warn(("%s not found — %s"):format(exe, without))
    end
  end
end

local function check_servers()
  H.start("Language servers")
  for _, s in ipairs(servers) do
    local exe, lang = s[1], s[2]
    if vim.fn.executable(exe) == 1 then
      H.ok(("%s (%s)"):format(exe, lang))
    else
      H.warn(("%s not found — no %s support"):format(exe, lang))
    end
  end

  -- ruby-lsp needs Ruby >= 3.0 even to analyse a 2.x project, so the shim on
  -- PATH is not proof: check for an interpreter that can actually run it.
  local modern = require("setup.lsp").modern_ruby_lsp()
  if modern then
    H.ok("ruby-lsp (ruby, via " .. modern .. ")")
  elseif vim.fn.executable("ruby-lsp") == 1 then
    H.warn("ruby-lsp is on PATH but no rbenv Ruby >= 3 has it installed", {
      "Ruby < 3 projects need one: RBENV_VERSION=3.x gem install ruby-lsp",
    })
  else
    H.warn("ruby-lsp not found — no ruby support")
  end

  -- Composition fails on a Gemfile pinning Ruby < 3; this bundle is the way out.
  local bundle = vim.fn.stdpath("config") .. "/ruby-lsp/Gemfile"
  if vim.uv.fs_stat(bundle) then
    if vim.uv.fs_stat(bundle .. ".lock") then
      H.ok("ruby-lsp standalone bundle (for Ruby < 3 projects)")
    else
      H.warn("ruby-lsp/Gemfile has no lockfile", {
        "cd " .. vim.fn.stdpath("config") .. "/ruby-lsp && bundle install",
      })
    end
  else
    H.warn("no ruby-lsp/Gemfile — Ruby < 3 projects will fail to start a server")
  end
end

local function check_parsers()
  H.start("Treesitter parsers")
  local ok, ts = pcall(require, "nvim-treesitter")
  if not ok then
    H.warn("nvim-treesitter is not installed — regex syntax highlighting only")
    return
  end

  local installed = {}
  for _, lang in ipairs(ts.get_installed()) do
    installed[lang] = true
  end

  -- Only the languages actually edited here are worth reporting individually.
  local want = { "python", "ruby", "lua", "markdown", "bash", "json", "yaml" }
  local missing = vim.tbl_filter(function(l) return not installed[l] end, want)

  if #missing == 0 then
    H.ok(("%d parsers installed, including all primary languages"):format(#ts.get_installed()))
  else
    H.warn("missing parsers: " .. table.concat(missing, ", "), {
      "They install on next start when tree-sitter-cli is present.",
    })
  end
end

local function check_keymaps()
  H.start("Keymaps")
  local spec = require("keymaps")

  -- Anything with a requirement but no fallback simply vanishes on a machine
  -- that lacks the tool. That is sometimes right (no git, no hunks) and
  -- sometimes an oversight, so list them rather than judging.
  local silent = {}
  for _, m in ipairs(spec.maps) do
    if m.needs and not m.fallback then
      table.insert(silent, m[1])
    end
  end

  H.info(("%d mappings defined"):format(#spec.maps))
  if #silent > 0 then
    H.info("no fallback (absent when their tool is): " .. table.concat(silent, " "))
  end

  -- A plugin claiming one of our keys is the failure this catches.
  local function norm(lhs)
    return (lhs:gsub("<[Ll]eader>", vim.g.mapleader or "\\"))
  end

  local ours = {}
  for _, m in ipairs(spec.maps) do
    local modes = type(m.mode) == "table" and m.mode or { m.mode or "n" }
    for _, mo in ipairs(modes) do
      -- "v" covers x and s, which is how nvim_get_keymap() reports them.
      for _, real in ipairs(mo == "v" and { "x", "s" } or { mo }) do
        ours[real .. " " .. norm(m[1])] = m.desc
      end
    end
  end

  local stolen = {}
  for _, mo in ipairs({ "n", "x", "o", "i", "t" }) do
    for _, m in ipairs(vim.api.nvim_get_keymap(mo)) do
      local key = mo .. " " .. m.lhs
      if ours[key] and m.desc ~= ours[key] then
        table.insert(stolen, ("%s is now %q, expected %q"):format(key, m.desc or "", ours[key]))
      end
    end
  end

  if #stolen == 0 then
    H.ok("no mappings overridden by plugins")
  else
    for _, s in ipairs(stolen) do
      H.error(s, { "Run :KeymapAudit for the full picture." })
    end
  end
end

function M.check()
  check_tools()
  check_servers()
  check_parsers()
  check_keymaps()
end

return M
