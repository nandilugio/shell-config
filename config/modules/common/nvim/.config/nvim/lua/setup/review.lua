-- Review mode: one switch that sets the editor up to read changes the way a
-- pull request shows them, and one that puts it back. <leader>uR.
--
-- Two presets, each a complete set of absolute values, so leaving always lands
-- in the same place: edit mode is the editor's normal state, named. A setting
-- changed by hand while in a mode is overwritten on the next switch.
--
-- What review changes:
--   base          the merge-base with the branch this one forked from, so the
--                 signs, ]c, <leader>gd/gD/gQ and the hunk counts all show the
--                 branch's changes, as the PR does
--   diagnostics   written out on every line, errors only
--   type checking basedpyright's "standard", not its stricter default
--   hunk display  deleted lines, word diff, the cursor line's blame
--   'write'       off, see PRESETS
--
-- Nothing here knows about pull requests or any host: only local git. On a
-- branch it reviews the branch; on a detached HEAD, that one commit against
-- its parent. Staging is refused while the base is not the index
-- (setup/git.lua), so a review cannot touch the index either.

local M = {}

local G = require("setup.git")

local PRESETS = {
  edit = {
    diagnostics = { scope = "current line", severity = "all" },
    type_checking = nil, -- the checker's own default
    hunk_details = false,
    -- Edits are not dimmed, see review.write.
    write = true,
  },
  review = {
    diagnostics = { scope = "every line", severity = "errors only" },
    type_checking = "standard",
    hunk_details = true,
    -- Writes refused, edits allowed. In review the working tree IS the change
    -- under review: an edit saved by accident becomes a hunk against the
    -- merge-base, in the same colour as the author's -- gitsigns dims only what
    -- is staged in the index, and this base is not the index -- and nothing
    -- tells the two apart. Edits stay possible because the language server
    -- reads the buffer, not the disk: change a type to see what breaks, and
    -- nothing is saved. To run tests on an edit, :set write, deliberately.
    -- Quitting with such edits wants :qa!, since saving them is refused.
    write = false,
  },
}

-- nil in edit mode. In review:
--   kind     "branch" or "commit"
--   root     the repository
--   base     the sha the signs compare against
--   name     how to show the base: "develop", "origin/develop", a ref you gave
--   branch   the branch under review (for a commit, the one containing it)
--   nearer   branches forking nearer than the conventional base (nearer_forks)
--   choices  what :Review <Tab> offers first: the conventional base, then those
--   by_hand  the base came from :Review <ref>, so a fetch must not replace it
--   list, pos, back   for a commit: the branch's own commits oldest first,
--                     this one's index in them, and its distance from the tip
local state = nil

-- ── git ─────────────────────────────────────────────────────────────────────

local function git(root, args)
  local res = vim.system(vim.list_extend({ "git", "-C", root }, args), { text = true }):wait()
  return res.code == 0, vim.trim(res.stdout or ""), vim.trim(res.stderr or "")
end

local function lines(s) return vim.split(s, "\n", { trimempty = true }) end

local function sha(root, rev)
  local ok, out = git(root, { "rev-parse", "--verify", "-q", rev .. "^{commit}" })
  return ok and out or nil
end

local CONVENTIONAL = { "develop", "master", "main" }

-- The branches a pull request usually targets, as refs that exist here: develop,
-- master and main, plus whatever each remote names as its default branch (so a
-- repository whose default is called something else still works). Each local
-- and remote, minus the branch under review, ordered so ties go to the first.
local function trunk_names(root)
  local names = vim.deepcopy(CONVENTIONAL)
  local _, defaults = git(root, { "for-each-ref", "--format=%(symref:lstrip=3)", "refs/remotes/*/HEAD" })
  for _, d in ipairs(lines(defaults)) do
    if not vim.tbl_contains(names, d) then table.insert(names, d) end
  end
  return names
end

local function conventional_refs(root, branch)
  local names = trunk_names(root)

  local patterns = { "for-each-ref", "--format=%(refname)" }
  for _, n in ipairs(names) do
    vim.list_extend(patterns, { "refs/heads/" .. n, "refs/remotes/*/" .. n })
  end
  local _, out = git(root, patterns)

  local refs = {}
  for _, full in ipairs(lines(out)) do
    local short = full:gsub("^refs/heads/", ""):gsub("^refs/remotes/", "")
    local name = short:match("[^/]+$")
    local remote = full:find("^refs/remotes/") ~= nil
    if short ~= branch and not (remote and name == branch) then
      local rank = vim.fn.index(names, name) * 2 + (remote and 1 or 0)
      table.insert(refs, { ref = short, rank = rank })
    end
  end
  table.sort(refs, function(a, b) return a.rank < b.rank end)
  return refs
end

-- Of those, the one whose merge-base with `tip` is nearest to it. Nearest
-- rather than first, so a stale local develop loses to a fresher
-- origin/develop, and a hotfix cut from master is reviewed against master
-- even where develop exists.
local function conventional_base(root, tip, branch)
  local best
  for _, c in ipairs(conventional_refs(root, branch)) do
    local ok, mb = git(root, { "merge-base", tip, c.ref })
    if ok then
      local _, n = git(root, { "rev-list", "--count", mb .. ".." .. tip })
      n = tonumber(n)
      if not best or n < best.distance then best = { sha = mb, name = c.ref, distance = n } end
    end
  end
  return best
end

-- Branches that fork from `branch` nearer than `base`: a stacked branch's
-- parent, typically. Git records no "branched from", so this asks the graph:
-- the commits on the branch's first-parent line that no other branch has are
-- its own (one rev-list, whatever the repository's size), and the parent of
-- the oldest is where it left someone else's history. When that is the base
-- already, or older than it, there is nothing nearer. Otherwise every branch
-- containing it is a candidate -- including, unavoidably, a branch cut from
-- this one later, which the graph cannot tell from a parent. Hence a hint, not
-- a question.
local function nearer_forks(root, tip, branch, base)
  local _, out = git(root, {
    "rev-list", "--first-parent", tip, "--not",
    "--exclude=" .. branch, "--branches", "--exclude=*/" .. branch, "--remotes",
  })
  local own = lines(out)
  if #own == 0 then return {} end
  local fork = sha(root, own[#own] .. "^")
  if not fork or fork == base then return {} end
  if not git(root, { "merge-base", "--is-ancestor", base, fork }) then return {} end

  -- A local branch and its remote twin are one name; local ones list first.
  local _, refs = git(root, { "for-each-ref", "--contains", fork, "--format=%(refname)", "refs/heads", "refs/remotes" })
  local seen, names = {}, {}
  for _, full in ipairs(lines(refs)) do
    local name = full:gsub("^refs/heads/", ""):gsub("^refs/remotes/[^/]+/", "")
    if name ~= branch and name ~= "HEAD" and not seen[name] then
      seen[name] = true
      table.insert(names, name)
    end
  end
  return names
end

-- For a detached HEAD: the branch it belongs to, as the one containing it
-- whose tip is nearest -- local or remote, so a colleague's branch checked out
-- as origin/x counts; local wins a tie. With trunk = false the conventional
-- branches are left out (containing it there means it was merged, not that it
-- is theirs); with trunk = true only they are considered.
--
-- The ref is named as measured, origin/ included when remote: a ~N counted
-- on origin/x would be wrong on a local x that has moved.
local function containing_branch(root, trunk)
  local trunks = trunk_names(root)
  local _, out = git(root, { "for-each-ref", "--contains", "HEAD", "--format=%(refname)", "refs/heads", "refs/remotes" })
  local best
  for _, full in ipairs(lines(out)) do
    local short = full:gsub("^refs/heads/", ""):gsub("^refs/remotes/", "")
    local name = short:match("[^/]+$")
    local remote = full:find("^refs/remotes/") ~= nil
    if name ~= "HEAD" and vim.tbl_contains(trunks, name) == trunk then
      local _, n = git(root, { "rev-list", "--count", "HEAD.." .. short })
      n = tonumber(n)
      if not best or n < best.distance or (n == best.distance and best.remote and not remote) then
        best = { ref = short, distance = n, remote = remote }
      end
    end
  end
  return best
end

-- ── Detection ───────────────────────────────────────────────────────────────

-- The conventional base and the nearer forks, in that order, as names.
local function detected(root, branch)
  local conv = conventional_base(root, "HEAD", branch)
  if not conv then return nil, {}, {} end
  local nearer = nearer_forks(root, "HEAD", branch, conv.sha)
  return conv, nearer, vim.list_extend({ conv.name }, vim.deepcopy(nearer))
end

local function detect_branch(root, branch, ref)
  local s = { kind = "branch", root = root, branch = branch }
  -- Detected even when a ref is given, so :Review <Tab> can offer them.
  local conv
  conv, s.nearer, s.choices = detected(root, branch)
  if ref then
    s.base = select(2, git(root, { "merge-base", "HEAD", ref }))
    if not sha(root, ref) or s.base == "" then return nil, ("%s: no such ref, or nothing in common with HEAD"):format(ref) end
    s.name, s.by_hand = ref, true
  else
    -- Nothing to compare the branch with: the third return asks the caller to
    -- review its last commit instead.
    if not conv then return nil, nil, true end
    s.base, s.name = conv.sha, conv.name
  end
  if s.base == sha(root, "HEAD") then
    if not ref then return nil, nil, true end
    return nil, ("%s is already in %s: nothing to review"):format(branch, s.name)
  end
  return s
end

-- HEAD against its parent, placed on a line of history when there is one, so
-- the label can say where it is (and ]r [r can move along it):
--   a feature branch's own commits   feature-x~3 4/7   bounded, hence n/m
--   a trunk's history                master~3          unbounded: no total
--   no branch at all                 abc1234
-- `branch` is given when HEAD is the tip of it: the fallback for a branch
-- with nothing to compare against, master in a repo that commits only there.
local function detect_commit(root, branch)
  local head = sha(root, "HEAD")
  local parent = sha(root, "HEAD^")
  if not parent then return nil, "A root commit has no parent to compare against" end
  local s = { kind = "commit", root = root, base = parent, head = head, nearer = {} }
  if branch then
    s.branch, s.back = branch, 0
    return s
  end

  local b = containing_branch(root, false)
  local conv = b and conventional_base(root, b.ref, (b.ref:gsub("^[^/]+/", "")))
  if conv then
    local _, out = git(root, { "rev-list", "--first-parent", "--no-merges", "--reverse", conv.sha .. ".." .. b.ref })
    local list = lines(out)
    local pos = vim.fn.index(list, head) + 1
    if pos > 0 then
      local _, back = git(root, { "rev-list", "--count", "--first-parent", "HEAD.." .. b.ref })
      s.branch, s.list, s.pos, s.back = b.ref, list, pos, tonumber(back)
      return s
    end
  end

  -- On a trunk, ~N is exact only along its first-parent line: a commit that
  -- arrived through a merge's other side has no such name, and keeps the sha.
  local t = containing_branch(root, true)
  if t then
    local _, back = git(root, { "rev-list", "--count", "--first-parent", "HEAD.." .. t.ref })
    back = tonumber(back)
    if sha(root, ("%s~%d"):format(t.ref, back)) == head then s.branch, s.back = t.ref, back end
  end
  return s
end

-- ── Apply ───────────────────────────────────────────────────────────────────

local function set_base(base)
  local gs = require("gitsigns")
  if base then gs.change_base(base, true) else gs.reset_base(true) end
end

-- Returns the type checker's report, for the caller's message.
local function apply(preset, base)
  local gs = require("gitsigns")
  set_base(base)
  gs.toggle_deleted(preset.hunk_details)
  gs.toggle_word_diff(preset.hunk_details)
  gs.toggle_current_line_blame(preset.hunk_details)
  require("setup.diagnostics").set(preset.diagnostics)
  vim.o.write = preset.write
  return require("setup.lsp").set_type_checking(preset.type_checking)
end

-- Cut to the width a message can take without the hit-enter prompt.
local function fit(msg)
  local room = math.max(20, vim.v.echospace - 1)
  if vim.fn.strdisplaywidth(msg) <= room then return msg end
  return vim.fn.strcharpart(msg, 0, room - 1) .. "…"
end

-- Branch review names a range; commit review names one commit, since the
-- statusline's cR already says "against its parent".
local function describe(s)
  if s.kind == "branch" then return ("%s...%s"):format(s.name, s.branch) end
  if not s.branch then return G.short_rev(s.head) end
  local at = s.back == 0 and s.branch or ("%s~%d"):format(s.branch, s.back)
  return s.list and ("%s %d/%d"):format(at, s.pos, #s.list) or at
end

-- A fetch on entry, so the base reflects the remote rather than whenever you
-- last fetched -- without waiting for it. Detached, so git and ssh have no
-- terminal to ask for a password on (a prompt would draw over the editor);
-- GIT_TERMINAL_PROMPT=0 for https. No network, no credentials: it fails
-- quietly and the local answer stands. If it lands and the base moved, switch.
local function refresh_after_fetch(s)
  vim.system({ "git", "-C", s.root, "fetch", "--quiet" }, {
    detach = true,
    timeout = 60000,
    env = { GIT_TERMINAL_PROMPT = "0" },
  }, function(res)
    vim.schedule(function()
      if state ~= s or s.by_hand or res.code ~= 0 then return end
      local conv = conventional_base(s.root, "HEAD", s.branch)
      if conv and conv.sha ~= s.base then
        s.base, s.name = conv.sha, conv.name
        set_base(s.base)
        vim.notify(fit("Fetched: reviewing " .. describe(s)))
      end
    end)
  end)
end

local function enter(ref)
  if not pcall(require, "gitsigns") then
    vim.notify("Review mode needs gitsigns", vim.log.levels.WARN)
    return
  end
  local root = G.root()
  if not root then
    vim.notify("Not in a git repository", vim.log.levels.WARN)
    return
  end
  local on_branch, branch = git(root, { "symbolic-ref", "--short", "-q", "HEAD" })
  if ref and not on_branch then
    vim.notify("A detached HEAD is reviewed against its parent; :Review <ref> needs a branch", vim.log.levels.WARN)
    return
  end
  local s, err, fallback
  if on_branch then s, err, fallback = detect_branch(root, branch, ref) end
  if not on_branch or fallback then s, err = detect_commit(root, fallback and branch or nil) end
  if not s then
    vim.notify(err, vim.log.levels.WARN)
    return
  end

  state = s
  local tc, tc_level = apply(PRESETS.review, s.base)

  -- The message must fit beside the ruler (v:echospace): anything longer, or a
  -- second line, raises the hit-enter prompt, which swallows the keys typed
  -- next. The statusline already shows the range and the R, so when there is
  -- something to act on, the message is only that; the preset's own settings
  -- are in the cheatsheet.
  local warnings = {}
  if tc_level == vim.log.levels.WARN then table.insert(warnings, tc) end
  if #s.nearer > 0 and not s.by_hand then
    table.insert(warnings, table.concat(s.nearer, ", ") .. " fork nearer (:Review <Tab>)")
  end
  local _, dirty = git(root, { "status", "--porcelain", "--untracked-files=no" })
  if dirty ~= "" then table.insert(warnings, "uncommitted changes included") end
  if #warnings > 0 then
    vim.notify(fit(table.concat(warnings, "; ")), vim.log.levels.WARN)
  else
    vim.notify(fit("Review mode: " .. describe(s)))
  end

  if s.kind == "branch" and not s.by_hand then refresh_after_fetch(s) end
end

local function leave()
  state = nil
  local tc, tc_level = apply(PRESETS.edit, nil)
  local warn = tc_level == vim.log.levels.WARN
  vim.notify(fit("Edit mode" .. (warn and "; " .. tc or "")), warn and tc_level or nil)
end

-- ── Public ──────────────────────────────────────────────────────────────────

function M.active() return state ~= nil end

--- "branch" or "commit" while reviewing, nil otherwise.
function M.kind() return state and state.kind end

function M.toggle()
  if state then leave() else enter() end
end

--- The statusline's reading of the base, or nil when review mode did not set
--- the base this buffer compares against -- the buffer then gets the plain
--- two-dot form (setup/statusline.lua). Three dots on a branch: the base is the
--- merge-base, which is what git's "..." means.
--- @param base string? the buffer's base, from setup/git.lua
function M.label(base)
  if not state or base ~= state.base then return nil end
  return describe(state)
end

--- Reviews the current branch against `ref`'s merge-base, entering review
--- mode if needed. The base then stays until you leave.
--- @param ref string
function M.review_against(ref)
  if not state then return enter(ref) end
  if state.kind ~= "branch" then
    vim.notify("A single commit is reviewed against its parent", vim.log.levels.WARN)
    return
  end
  local s, err = detect_branch(state.root, state.branch, ref)
  if not s then
    vim.notify(err, vim.log.levels.WARN)
    return
  end
  state.base, state.name, state.by_hand = s.base, s.name, true
  set_base(state.base)
  vim.notify("Reviewing " .. describe(state))
end

-- What <Tab> offers: the detected bases first -- the ones this review would
-- consider, or would if it were on -- then every other ref, for anything else.
local function complete(arglead)
  local root = G.root()
  if not root then return {} end
  local first = state and state.choices
  if not first then
    local on_branch, branch = git(root, { "symbolic-ref", "--short", "-q", "HEAD" })
    first = on_branch and select(3, detected(root, branch)) or {}
  end
  -- Not refs/remotes/*/HEAD: it only points at the remote's default branch,
  -- already listed, and its short name is the bare remote ("origin").
  local _, out = git(root, { "for-each-ref", "--format=%(refname)", "refs/heads", "refs/remotes" })
  local all = vim.deepcopy(first)
  for _, full in ipairs(lines(out)) do
    local r = full:gsub("^refs/heads/", ""):gsub("^refs/remotes/", "")
    if not full:match("^refs/remotes/[^/]+/HEAD$") and not vim.tbl_contains(all, r) then table.insert(all, r) end
  end
  return arglead == "" and all or vim.fn.matchfuzzy(all, arglead)
end

-- :Review toggles, as <leader>uR does. :Review <ref> reviews the current
-- branch against that ref's merge-base, entering review mode or switching the
-- base of the one in progress.
vim.api.nvim_create_user_command("Review", function(o)
  if o.args == "" then return M.toggle() end
  M.review_against(o.args)
end, {
  nargs = "?",
  desc = "Toggle review mode, or review against a ref's merge-base",
  complete = complete,
})

return M
