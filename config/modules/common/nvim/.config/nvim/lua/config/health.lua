-- :checkhealth config
--
-- Reports on the things this config depends on but does not control: external
-- binaries, language servers that must actually attach, parsers that must be
-- compiled, keymaps that might have been claimed by a plugin, and the surface
-- it uses in each plugin, which an update can move (the contract, below).
-- lua/config/health_test.lua runs it headless and fails on any error.
--
-- Everything here is optional by design — the config degrades rather than
-- breaks — so a missing tool is a warning, never an error.

local H = vim.health
local M = {}

-- What each external tool buys, and what happens without it. `min` is the
-- oldest version the plugin using it states it wants (fzf-lua for fzf,
-- nvim-treesitter's main branch for the CLI); older is a warning, since the
-- tool still mostly works.
local tools = {
  { "fzf", "fuzzy finding", "<leader>f* fall back to :find and :grep", min = "0.53" },
  { "rg", "fast :grep", "falls back to the built-in grep" },
  { "fd", "fast file listing", "fzf-lua uses its own walker" },
  { "git", "hunk signs and navigation", "gitsigns does nothing outside a repo" },
  { "tree-sitter", "parser compilation", "regex syntax highlighting only", min = "0.26.1" },
}

-- The first version-looking thing `exe --version` prints, or nil.
local function version_of(exe)
  local res = vim.system({ exe, "--version" }, { text = true }):wait()
  if res.code ~= 0 then return nil end
  local v = (res.stdout or ""):match("%d+%.%d+%.?%d*")
  return v and vim.version.parse(v) or nil
end

-- A row with several names is satisfied by any of them: setup/lsp.lua runs
-- one type checker, basedpyright first.
local servers = {
  { { "basedpyright", "pyright" }, "python" },
  { "ruff", "python" },
  { "lua-language-server", "lua" },
}

local function check_tools()
  H.start("External tools")
  for _, t in ipairs(tools) do
    local exe, buys, without = t[1], t[2], t[3]
    if vim.fn.executable(exe) == 0 then
      H.warn(("%s not found — %s"):format(exe, without))
    else
      local v = t.min and version_of(exe)
      if t.min and v and vim.version.lt(v, t.min) then
        H.warn(("%s %s — %s wants %s or newer"):format(exe, tostring(v), exe == "fzf" and "fzf-lua" or "nvim-treesitter", t.min))
      else
        H.ok(("%s%s — %s"):format(exe, v and (" " .. tostring(v)) or "", buys))
      end
    end
  end
end

local function check_servers()
  H.start("Language servers")
  for _, s in ipairs(servers) do
    local names, lang = type(s[1]) == "table" and s[1] or { s[1] }, s[2]
    local found
    for _, exe in ipairs(names) do
      if not found and vim.fn.executable(exe) == 1 then found = exe end
    end
    if found then
      H.ok(("%s (%s)"):format(found, lang))
    else
      H.warn(("%s not found — no %s support"):format(table.concat(names, " or "), lang))
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
  for _, lang in ipairs(ts.get_installed("parsers")) do
    installed[lang] = true
  end

  -- Only the languages actually edited here are worth reporting individually.
  local want = { "python", "ruby", "lua", "markdown", "bash", "json", "yaml" }
  local missing = vim.tbl_filter(function(l) return not installed[l] end, want)

  if #missing == 0 then
    H.ok(("%d parsers installed, including all primary languages"):format(#ts.get_installed("parsers")))
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
  -- setup/keymaps.lua knows which entries became mappings and asks maparg()
  -- for each, so Vim does the spelling of the key.
  local stolen, shadowed = require("setup.keymaps").overridden()
  if #stolen == 0 then
    H.ok("no mappings overridden by plugins")
  else
    for _, s in ipairs(stolen) do
      H.error(s, { "Run :KeymapAudit for the full picture." })
    end
  end
  for _, s in ipairs(shadowed) do
    H.info("shadowed in the current buffer: " .. s)
  end
end

-- ── The contract ────────────────────────────────────────────────────────────
-- What this config touches in each plugin: the functions it calls, the
-- commands, highlight groups and server definitions it names, the one
-- internal it reads. An update can move any of it, and would otherwise show
-- up as an error at a keypress days later. Listed as data, checked here and
-- by lua/config/health_test.lua, so the breakage is named at once:
-- "gitsigns.toggle_word_diff is gone". Not a wrapper: the calls stay where
-- they are, this only says what they are.
local CONTRACT = {
  {
    "gitsigns",
    functions = {
      "setup", "change_base", "reset_base", "toggle_deleted", "toggle_word_diff", "get_hunks",
      "toggle_current_line_blame", "stage_hunk", "reset_hunk", "stage_buffer",
      "reset_buffer", "setqflist", "nav_hunk", "preview_hunk", "blame_line",
      "diffthis", "select_hunk", "attach", "detach",
    },
    commands = { "Gitsigns" },
    highlights = {
      "GitSignsDeleteVirtLn", "GitSignsDeleteVirtLnInLine", "GitSignsDeletePreview", "GitSignsDeleteInline",
      "GitSignsDeleteLnInline", "GitSignsVirtLnum",
      "GitSignsAddPreview", "GitSignsAddInline", "GitSignsChangeInline",
    },
    -- b:gitsigns_status_dict, read by the statusline and setup/git.lua.
    status_fields = { "head", "root", "gitdir" },
  },
  {
    "fzf-lua",
    functions = {
      "setup", "register_ui_select", "files", "live_grep", "grep_cword", "oldfiles",
      "helptags", "keymaps", "diagnostics_document", "lsp_document_symbols",
      "lsp_live_workspace_symbols", "lsp_references", "builtin", "resume", "buffers",
      "git_bcommits", "git_commits", "git_diff",
    },
    commands = { "FzfLua" },
  },
  -- The main branch: its README calls it a rewrite to set up from scratch.
  { "nvim-treesitter", functions = { "setup", "install", "get_installed", "update", "indentexpr" } },
  { "mini.files", functions = { "setup", "open" }, highlights = { "MiniFilesDirectory", "MiniFilesFile" } },
  { "which-key", functions = { "setup", "add" } },
}

-- Server definitions nvim-lspconfig ships, enabled by name in setup/lsp.lua.
local SERVER_DEFINITIONS = { "basedpyright", "pyright", "ruff", "ruby_lsp", "lua_ls" }

local function check_contract()
  H.start("Plugin surface this config uses")
  for _, c in ipairs(CONTRACT) do
    local ok, mod = pcall(require, c[1])
    if not ok then
      -- Absent by design where its tool is (fzf-lua without fzf): the
      -- keymaps fall back, and the tools section above says what is missing.
      H.info(c[1] .. " is not installed")
    else
      local gone = {}
      for _, f in ipairs(c.functions) do
        if type(mod[f]) ~= "function" then table.insert(gone, c[1] .. "." .. f) end
      end
      for _, cmd in ipairs(c.commands or {}) do
        if vim.fn.exists(":" .. cmd) ~= 2 then table.insert(gone, ":" .. cmd) end
      end
      for _, hl in ipairs(c.highlights or {}) do
        if vim.fn.hlexists(hl) ~= 1 then table.insert(gone, "highlight " .. hl) end
      end
      if c.status_fields then
        -- Any attached buffer: :checkhealth runs in a window of its own.
        local d
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          d = d or vim.b[buf].gitsigns_status_dict
        end
        if d then
          for _, f in ipairs(c.status_fields) do
            if d[f] == nil then table.insert(gone, "b:gitsigns_status_dict." .. f) end
          end
        else
          H.info(c[1] .. ": b:gitsigns_status_dict unchecked, no buffer attached here (open a tracked file first)")
        end
      end
      if #gone == 0 then
        H.ok(("%s: %d functions%s"):format(c[1], #c.functions, c.highlights and ", commands and highlights" or ""))
      else
        H.error(c[1] .. " no longer has: " .. table.concat(gone, ", "), {
          "A plugin update moved it. See where the config uses it: grep the name.",
        })
      end
    end
  end

  local missing = {}
  for _, s in ipairs(SERVER_DEFINITIONS) do
    if #vim.api.nvim_get_runtime_file("lsp/" .. s .. ".lua", false) == 0 then table.insert(missing, s) end
  end
  if #missing == 0 then
    H.ok(("nvim-lspconfig defines the %d servers setup/lsp.lua enables"):format(#SERVER_DEFINITIONS))
  else
    H.error("nvim-lspconfig has no definition for: " .. table.concat(missing, ", "))
  end
end

-- setup/git.lua reads each buffer's gitsigns base from gitsigns' cache, an
-- internal table with no public getter. If gitsigns reshapes it, the read
-- quietly returns nil -- as if every buffer compared against the index --
-- so this is the place that says so.
local function check_gitsigns_internals()
  H.start("gitsigns internals")
  if not pcall(require, "gitsigns") then
    H.info("gitsigns is not installed")
    return
  end
  local ok, cache = pcall(require, "gitsigns.cache")
  if not ok or type(cache.cache) ~= "table" then
    H.error("gitsigns.cache.cache is gone: the statusline no longer shows a changed base", {
      "Update M.base in lua/setup/git.lua for this gitsigns revision.",
    })
    return
  end
  local _, entry = next(cache.cache)
  if not entry then
    H.info("no buffer attached to gitsigns, so its base field went unchecked: run this from a file in a repository")
  elseif type(entry.git_obj) == "table" and type(entry.git_obj.change_revision) == "function" then
    H.ok("the base of each buffer is readable (cache[buf].git_obj.revision)")
  else
    H.error("gitsigns' cache entries changed shape: the statusline no longer shows a changed base", {
      "Update M.base in lua/setup/git.lua for this gitsigns revision.",
    })
  end
end

-- setup/keymaps.lua brackets the mnemonic in which-key's own labels for
-- Vim's keys, read from its presets module, which is not API. Guarded there,
-- so a reshaped module costs only the brackets; this is where that shows.
local function check_whichkey_presets()
  H.start("which-key internals")
  if not pcall(require, "which-key") then
    H.info("which-key is not installed")
    return
  end
  local n = #require("setup.keymaps").presets()
  if n > 0 then
    H.ok(("%d of which-key's preset labels relabelled with their mnemonic"):format(n))
  else
    H.warn("which-key's presets module changed shape: Vim's own keys show without brackets", {
      "Update M.presets in lua/setup/keymaps.lua for this which-key revision, or drop it.",
    })
  end
end

function M.check()
  check_tools()
  check_servers()
  check_parsers()
  check_keymaps()
  check_contract()
  check_gitsigns_internals()
  check_whichkey_presets()
end

return M
