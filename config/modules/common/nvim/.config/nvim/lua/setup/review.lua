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
--   hunk display  the inline diff (setup/git.lua), the cursor line's blame
--   'write'       off, see PRESETS
--
-- Nothing here knows about pull requests or any host: only local git. Two
-- kinds, shown as bR and cR in the statusline: on a branch, branch review --
-- the branch against its base; on a detached HEAD, or a branch with nothing
-- to compare against, commit review -- one commit against its parent. ]v and
-- [v walk the commits, checking each out. Staging is refused while the base
-- is not the index (setup/git.lua), so a review cannot touch the index either.
--
-- How it behaves, for the user: :help review-mode (doc/config.txt).
-- Tested by review_test.lua, next to this file: nvim -l lua/setup/review_test.lua
--
-- A setup module, not a local plugin, though it is shaped to become one. The
-- seam, should it ever be wanted elsewhere:
--   generic   everything from "git" to "Walk", the :Review command, and the
--             git helpers it borrows from setup/git.lua (root, gitdir, base,
--             short_rev, operation): git and gitsigns only. As a plugin
--             they would move in here, and the statusline and the staging
--             guard would call the plugin's kind(), label() and base()
--             instead -- the dependency then points at the plugin, never back.
--   ours      PRESETS: the diagnostics scope and the type-checking mode are
--             this config's setters. A plugin would take them as on_enter /
--             on_leave hooks in setup(), keeping only what must stay
--             consistent -- the base, HEAD's position and 'write'.
--   health    the base read from gitsigns' cache (config/health.lua) would be
--             the plugin's own :checkhealth.
-- Kept a module because the split costs an API and hooks and buys nothing
-- until there is a second home.

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
--   head     the commit under review (a branch review: the branch's tip)
--   base     the sha the signs compare against
--   name     how to show a branch review's base: "develop", a ref you gave
--   branch   the line of history the commit sits on, and ]v [v walk: the
--            branch under review, or for a commit the one containing it.
--            nil for a commit no branch contains
--   list     that branch's own commits, oldest first: its first-parent line
--            from the base, merges left out. nil on a trunk, where the line
--            has no start (master~3 has no n/m)
--   pos      for a commit with a list, its index in it
--   back     for a commit with a branch, its distance from the tip (the ~N)
--   conv     { sha, name }: the base a walk returns to for branch review
--   nearer   branches forking nearer than the conventional base (nearer_forks)
--   choices  what :Review <Tab> offers first: the conventional base, then those
--   by_hand  the base came from :Review <ref>, so a fetch must not replace it
--   home     where review started, to go back to on leaving: { branch = name }
--            or { sha = commit } for a detached HEAD
--   at       where review has left HEAD; anything else means it moved outside
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
    -- @{u} and friends read better resolved: origin/master...master.
    local ok, resolved = git(root, { "rev-parse", "--abbrev-ref", "--symbolic-full-name", ref })
    s.name = (ref:find("@{", 1, true) and ok and resolved ~= "") and resolved or ref
    s.by_hand = true
  else
    -- Nothing to compare the branch with: the third return asks the caller to
    -- review its last commit instead.
    if not conv then return nil, nil, true end
    s.base, s.name = conv.sha, conv.name
  end
  s.head = sha(root, "HEAD")
  if s.base == s.head then
    if not ref then return nil, nil, true end
    return nil, ("%s is already in %s: nothing to review"):format(branch, s.name)
  end
  s.conv = { sha = s.base, name = s.name }
  s.list = lines(select(2, git(root, { "rev-list", "--first-parent", "--no-merges", "--reverse", s.base .. "..HEAD" })))
  return s
end

-- HEAD against its parent, placed on a line of history when there is one, so
-- the label can say where it is (and ]v [v can move along it):
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
      s.conv = { sha = conv.sha, name = conv.name }
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
  G.inline_diff(preset.hunk_details)
  gs.toggle_current_line_blame(preset.hunk_details)
  require("setup.diagnostics").set(preset.diagnostics)
  vim.o.write = preset.write
  return require("setup.lsp").set_type_checking(preset.type_checking)
end

-- Every autocmd a review registers lives in this group, cleared on leaving.
local group = vim.api.nvim_create_augroup("review", { clear = true })

-- ── Keeping the base ────────────────────────────────────────────────────────
-- gitsigns watches .git/HEAD and, after a checkout, refreshes every attached
-- buffer with the revision it had when the refresh began, writing it back
-- when its git calls return. Nothing locks that against change_base, so a
-- refresh still in flight from the previous step lands after the next step's
-- base change and puts the old base back: wrong hunks, and the statusline
-- falls to the two-dot form. Two quick steps, or slow git, is all it takes
-- (TODO 29, an upstream bug).
--
-- The refresh ends by raising GitSignsUpdate for the buffer, so that is where
-- to look: a buffer whose base is not the review's gets it again. Once per
-- buffer and base, so it cannot loop, and only for files in the working tree,
-- since gitsigns leaves a file absent from it on the index by design.

local function keep_base(s)
  local applied = {}
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "GitSignsUpdate",
    callback = function(ev)
      local buf = ev.data and ev.data.buffer
      if not buf or state ~= s or G.base(buf) == s.base then return end
      local key = buf .. ":" .. s.base
      local name = vim.api.nvim_buf_get_name(buf)
      if applied[key] or name == "" or not vim.uv.fs_stat(name) then return end
      applied[key] = true
      require("gitsigns").change_base(s.base, true)
    end,
  })
end

-- Cut to the width a message can take without the hit-enter prompt, which
-- would swallow the key typed next. Only for the routine messages -- entering,
-- each step, leaving -- which come in quick succession and say little the
-- statusline does not. Refusals and warnings are meant to be read, and carry
-- the git commands: those Neovim shows whole, "Press ENTER" and all, and
-- :messages keeps them whole.
local function fit(msg)
  local room = math.max(20, vim.v.echospace - 1)
  if vim.fn.strdisplaywidth(msg) <= room then return msg end
  return vim.fn.strcharpart(msg, 0, room - 1) .. "…"
end

-- Branch review names a range. Commit review on a feature branch names the
-- commit and its place among the branch's own (feature-x~3 4/7); elsewhere
-- there is no place to give, so it names the comparison itself, in git's
-- notation: master^..master, the parent of master to master.
local function describe(s)
  if s.kind == "branch" then return ("%s...%s"):format(s.name, s.branch) end
  local at = not s.branch and G.short_rev(s.head)
    or s.back == 0 and s.branch
    or ("%s~%d"):format(s.branch, s.back)
  return s.list and ("%s %d/%d"):format(at, s.pos, #s.list) or ("%s^..%s"):format(at, at)
end

-- "Branch review: develop...feature-x", "Commit review: feature-x~3 4/7":
-- the statusline's bR and cR, in words.
local function headline(s)
  return (s.kind == "branch" and "Branch review: " or "Commit review: ") .. describe(s)
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
      -- Not mid-walk: the kind is then "commit".
      if state ~= s or s.by_hand or res.code ~= 0 or s.kind ~= "branch" then return end
      local conv = conventional_base(s.root, "HEAD", s.branch)
      if conv and conv.sha ~= s.base then
        s.base, s.name, s.conv = conv.sha, conv.name, { sha = conv.sha, name = conv.name }
        s.list = lines(select(2, git(s.root, { "rev-list", "--first-parent", "--no-merges", "--reverse", s.base .. "..HEAD" })))
        set_base(s.base)
        vim.notify(fit("Fetched: " .. headline(s)))
      end
    end)
  end)
end

-- ── Walk ────────────────────────────────────────────────────────────────────
-- ]v and [v check out the next and previous commit under review, so each is
-- read in a real working tree: the language server, tests, everything sees
-- that commit. Along a branch's own commits it is a cycle through the whole
-- branch: branch review, its oldest commit, ..., its tip, branch review again.
-- On a trunk, back through history and forward to the tip.
--
-- Checkouts are the one thing review mode does to the repository, so they
-- are guarded against surprises:
--   - the first one of a review asks, showing the git command it runs;
--   - HEAD returns to where review started on leaving, and on quitting
--     Neovim -- silently when it can, since quitting can't be refused;
--   - none happens while anything could be lost or carried along: unsaved
--     edits, uncommitted changes, an operation in progress, a HEAD moved by
--     hand. Refused, not worked around: whoever made the tree dirty cleans
--     it up. Every guard is checked afresh at each attempt.
--   - a HEAD left away -- a "no" at exit, a crash -- is recorded, and the
--     way back offered the next time review mode is entered there.
--
-- Messages name the git commands that fix what is in the way, so the git is
-- learnt along the way, and offer to run them when one is the clear choice.

local function unsaved_buffer()
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(b)
    if vim.bo[b].modified and vim.bo[b].buftype == "" and name ~= "" then
      return vim.fn.fnamemodify(name, ":~:.")
    end
  end
end

local function quoted(cmds, sep)
  return table.concat(vim.tbl_map(function(c) return "`" .. c .. "`" end, cmds), sep or " or ")
end

-- The commands that end each operation git can be in the middle of.
local FINISH = {
  rebase = { "git rebase --continue", "git rebase --abort" },
  merge = { "git merge --continue", "git merge --abort" },
  ["cherry-pick"] = { "git cherry-pick --continue", "git cherry-pick --abort" },
  revert = { "git revert --continue", "git revert --abort" },
  bisect = { "git bisect reset" },
}

-- Why a checkout cannot happen now, or nil. A reason is
--   cause  what is in the way, as a sentence
--   hint   the way out, its git commands quoted
--   fix    { text, args }: the one command that clears it, when there is a
--          clear one -- offered to run at exit, and on entering review
--          where a review was left behind
-- At exit, unsaved buffers do not count: quitting has discarded them.
local function blocked(s, exiting)
  if sha(s.root, "HEAD") ~= s.at then
    return { cause = "HEAD was moved outside review mode", hint = ":Review twice to start again from here" }
  end
  local op = G.operation(s.gitdir)
  if op then
    local cmds = FINISH[op]
    local fix = #cmds == 1 and { text = cmds[1], args = vim.list_slice(vim.split(cmds[1], " "), 2) } or nil
    return { cause = ("A %s is in progress"):format(op), hint = quoted(cmds), fix = fix }
  end
  local name = not exiting and unsaved_buffer()
  if name then return { cause = name .. " has edits", hint = ":e! to drop them" } end
  local files = lines(select(2, git(s.root, { "diff", "--name-only", "HEAD" })))
  if #files > 0 then
    local which = #files == 1 and files[1] or ":/" -- :/ is the whole repository
    return {
      cause = (#files == 1 and "%s has" or "%s and %d more have"):format(files[1], #files - 1) .. " uncommitted changes",
      hint = ("`git stash` them, or `git restore -SW %s` to drop them"):format(which),
      fix = { text = "git stash", args = { "stash" } },
    }
  end
end

local function refusal(why)
  return why.hint and why.hint ~= "" and (why.cause .. ": " .. why.hint) or why.cause
end

-- Where review started, and the command that goes back there.
local function home_sha(root, home) return home.branch and sha(root, home.branch) or home.sha end
local function home_name(home) return home.branch or G.short_rev(home.sha) end

-- The switch to `target`: attached when it is the tip of the branch review
-- started on, so coming back to it leaves you on the branch, not detached.
local function switch_to(s, target)
  local b = s.home.branch
  if b and sha(s.root, b) == target then return { "switch", "-q", b }, "git switch " .. b end
  return { "switch", "-q", "--detach", target }, "git switch --detach " .. G.short_rev(target)
end

local function back_home(root, home)
  if home.branch then return { "switch", "-q", home.branch }, "git switch " .. home.branch end
  return { "switch", "-q", "--detach", home.sha }, "git switch --detach " .. G.short_rev(home.sha)
end

-- The record: that a review is going on in this repository, by which Neovim,
-- and where it has left HEAD. In Neovim's state directory, outside the
-- repository, so keeping it is not itself a git change. Written on entering
-- and at each step; gone when review ends with HEAD home. A record whose
-- Neovim is no longer running means a review left behind.
local RECORDS = vim.fn.stdpath("state") .. "/review"

local function record_path(root) return RECORDS .. "/" .. root:gsub("[/\\:]", "%%") .. ".json" end

local function write_record(s)
  vim.fn.mkdir(RECORDS, "p")
  local record = { pid = vim.uv.os_getpid(), home = s.home, at = s.at, label = describe(s) }
  vim.fn.writefile({ vim.json.encode(record) }, record_path(s.root))
end

local function drop_record(root) os.remove(record_path(root)) end

local function read_record(root)
  local f = io.open(record_path(root))
  if not f then return nil end
  local ok, rec = pcall(vim.json.decode, f:read("a"))
  f:close()
  if ok and type(rec) == "table" and type(rec.home) == "table" and type(rec.at) == "string" then return rec end
  drop_record(root)
end

-- Running, and a Neovim: a pid can be reused once its process is gone. The
-- second half needs ps; without it, running is close enough.
local function alive(pid)
  if type(pid) ~= "number" then return false end
  local ok, _, name = vim.uv.kill(pid, 0)
  if ok ~= 0 and name ~= "EPERM" then return false end
  if vim.fn.executable("ps") == 0 then return true end
  local ps = vim.system({ "ps", "-p", tostring(pid), "-o", "comm=" }, { text = true }):wait()
  return ps.code == 0 and ps.stdout:find("nvim", 1, true) ~= nil
end

local function has_ui() return #vim.api.nvim_list_uis() > 0 end

-- A yes-or-no question, Neovim's own: confirm() shows a message of any
-- length and its choices, and waits. `yes` is the default.
local function ask(text, yes)
  return vim.fn.confirm(text, "&Yes\n&No", yes and 1 or 2, "Question") == 1
end

-- The way back to `home` for a HEAD review could not return, after `first`,
-- the line saying so. Offered to run when there is one clear command, or
-- chain -- by default only when nothing would be touched but HEAD; otherwise
-- said, and at exit held until read, since the screen goes next.
local function offer_back(root, home, first, why, exiting)
  local args, switch = back_home(root, home)
  if why and not why.fix then
    local text = ("%s\nTo go back: %s, then `%s`."):format(first, why.hint, switch)
    if exiting then
      vim.fn.confirm(text, "&Quit", 1, "Warning") -- held until read: the screen goes next
    else
      vim.notify(text, vim.log.levels.WARN)
    end
    return false
  end
  local chain = why and { why.fix.text, switch } or { switch }
  if not ask(("%s\nTo go back: `%s`. Run?"):format(first, table.concat(chain, "; ")), why == nil) then return false end
  for _, step in ipairs(why and { why.fix.args, args } or { args }) do
    local ok, _, err = git(root, step)
    if not ok then
      vim.notify(err, vim.log.levels.WARN)
      return false
    end
  end
  drop_record(root)
  vim.cmd("silent! checktime")
  return true
end

local function checkout(s, target)
  local args = switch_to(s, target)
  local ok, _, err = git(s.root, args)
  if not ok then return false, err end
  s.at = target
  -- Reload what changed; a file absent at this commit keeps its text, quietly.
  vim.cmd("silent! checktime")
  return true
end

-- Back to where review started. Returns a reason when it cannot, and a note
-- when HEAD stays for a reason that is not review's doing.
local function go_home(s, exiting)
  local home = home_sha(s.root, s.home)
  if s.at == home then return nil end
  -- Neither of these is review's doing, so HEAD stays and leaving still
  -- works: a refusal would keep you in review for good.
  if not home then return nil, s.home.branch .. " no longer exists, so HEAD stays" end
  if sha(s.root, "HEAD") ~= s.at then return nil, "HEAD was moved by hand, so it stays" end
  local why = blocked(s, exiting)
  if why then return why end
  local ok, err = checkout(s, home)
  if not ok then return { cause = err } end
end

-- Quitting can be neither refused nor undone, so a clean tree goes home
-- quietly. Otherwise, with a screen to show it on, say why and offer the way
-- back before the screen goes; the record stays either way, for the next
-- start, unless the offer was taken.
local function return_on_exit(s)
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      if state ~= s then return end
      local why = go_home(s, true)
      if not why then return drop_record(s.root) end
      if not has_ui() then return end
      local first = ("Review mode can't take HEAD back to %s: %s."):format(home_name(s.home), why.cause)
      offer_back(s.root, s.home, first, why, true)
    end,
  })
end

-- A record left in this repository by another review: one still running in
-- another Neovim, or one left behind -- a "no" at exit, a crash -- whose
-- HEAD is still where it left it, marked `gone`. A record HEAD has since
-- left is stale, and goes.
local function other_review(root)
  local rec = read_record(root)
  if not rec then return nil end
  if rec.pid ~= vim.uv.os_getpid() and alive(rec.pid) then return rec end
  local home = home_sha(root, rec.home)
  if sha(root, "HEAD") ~= rec.at or rec.at == home or not home then
    drop_record(root)
    return nil
  end
  rec.gone = true
  return rec
end

-- The way back for a review left behind, offered when there is a screen to
-- ask on. Whether taken or declined, entering goes on from wherever HEAD is.
local function offer_way_back(root, rec, gitdir)
  if not has_ui() then return end
  local why = blocked({ root = root, at = rec.at, gitdir = gitdir }, true)
  local first = ("Review mode left HEAD at %s (%s)"):format(G.short_rev(rec.at), rec.label)
    .. (why and (": " .. why.cause .. ".") or ".")
  offer_back(root, rec.home, first, why, false)
end

-- ── Entering ────────────────────────────────────────────────────────────────

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
  -- Not in the middle of git's own business: the base and the signs would
  -- mean little there, and the first step would refuse anyway.
  local gitdir = G.gitdir()
  local op = G.operation(gitdir)
  if op then
    vim.notify(("A %s is in progress: %s first"):format(op, quoted(FINISH[op])), vim.log.levels.WARN)
    return
  end
  -- One review per repository: two would each see the other's checkouts as
  -- HEAD moved by hand. A review left behind is offered its way back first.
  local rec = other_review(root)
  if rec and not rec.gone then
    vim.notify(("Neovim %d is reviewing in this repository"):format(rec.pid), vim.log.levels.WARN)
    return
  end
  if rec then offer_way_back(root, rec, gitdir) end
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

  -- Declining the way back must not lose it: a review started on the commit
  -- the last one left HEAD at keeps that review's home, so leaving still
  -- returns where the walk began.
  local inherited = rec and rec.gone and sha(root, "HEAD") == rec.at and rec.home
  s.home = on_branch and { branch = branch } or inherited or { sha = s.head }
  s.at = s.head
  s.gitdir = gitdir
  state = s
  write_record(s)
  keep_base(s)
  return_on_exit(s)
  local tc, tc_level = apply(PRESETS.review, s.base)

  -- The statusline already shows the range and the R, so when there is
  -- something to act on, the message is only that, and whole (see fit); the
  -- preset's own settings are in the cheatsheet.
  local warnings = {}
  if tc_level == vim.log.levels.WARN then table.insert(warnings, tc) end
  if #s.nearer > 0 and not s.by_hand then
    table.insert(warnings, table.concat(s.nearer, ", ") .. " fork nearer (:Review <Tab>)")
  end
  local _, dirty = git(root, { "status", "--porcelain", "--untracked-files=no" })
  if dirty ~= "" then table.insert(warnings, "uncommitted changes included") end
  if #warnings > 0 then
    vim.notify(table.concat(warnings, "; "), vim.log.levels.WARN)
  else
    -- The walk keys are the one thing review adds that no other key hints at.
    -- Last, so a narrow window cuts the hint rather than the range.
    local walk = s.branch and "]v [v walk the commits" or "[v walks back"
    vim.notify(fit(headline(s) .. "; " .. walk))
  end

  if s.kind == "branch" and not s.by_hand then refresh_after_fetch(s) end
end

-- ── Stepping and leaving ────────────────────────────────────────────────────

--- Steps to the next (1) or previous (-1) commit under review.
--- @param dir 1|-1
function M.step(dir)
  local s = state
  if not s then
    vim.notify("]v and [v walk the commits under review: <leader>uR first")
    return
  end

  local target, whole_branch
  if s.list then
    -- Position 0 is the whole branch, so the cycle passes through it.
    local pos = s.kind == "branch" and 0 or s.pos
    local new = (pos + dir) % (#s.list + 1)
    if new == 0 then
      target, whole_branch = sha(s.root, s.branch), true
    else
      target = s.list[new]
    end
  elseif dir < 0 then
    target = sha(s.root, s.head .. "^")
    if not target then return vim.notify("A root commit: there is nothing older") end
    -- A root commit has no parent to review it against.
    if not sha(s.root, target .. "^") then return vim.notify("The next one back is the root commit, which has no parent to compare against") end
  elseif s.branch then
    target = lines(select(2, git(s.root, { "rev-list", "--first-parent", "--reverse", s.head .. ".." .. s.branch })))[1]
    if not target then return vim.notify("At the tip of " .. s.branch) end
  else
    return vim.notify("No branch has this commit, and git records no children: only [v goes on")
  end

  local why = blocked(s)
  if why then return vim.notify(refusal(why), vim.log.levels.WARN) end
  if not s.confirmed then
    local _, cmd = switch_to(s, target)
    local text = ("]v and [v check out each commit; HEAD returns to %s when you leave review mode or quit Neovim.\nNow: `%s`. Run?")
      :format(home_name(s.home), cmd)
    if not ask(text, true) then return end
    s.confirmed = true
  end
  local ok, err = checkout(s, target)
  if not ok then return vim.notify(err, vim.log.levels.WARN) end

  s.head = target
  if whole_branch then
    s.kind, s.base, s.name = "branch", s.conv.sha, s.conv.name
  else
    s.kind, s.base = "commit", sha(s.root, target .. "^")
    if s.list then s.pos = vim.fn.index(s.list, target) + 1 end
    if s.branch then
      s.back = tonumber((select(2, git(s.root, { "rev-list", "--count", "--first-parent", target .. ".." .. s.branch }))))
    end
  end
  write_record(s) -- again: the label moved with the step
  set_base(s.base)
  local subject = s.kind == "commit" and select(2, git(s.root, { "log", "-1", "--format=%s", target })) or ""
  vim.notify(fit(headline(s) .. (subject ~= "" and "  " .. subject or "")))
end

local function leave()
  local s = state
  local moved = s.at ~= home_sha(s.root, s.home)
  local why, note = go_home(s)
  if why then return vim.notify("Still reviewing. " .. refusal(why), vim.log.levels.WARN) end
  local _, back = back_home(s.root, s.home)
  note = note and "; " .. note or moved and ("; back on %s (`%s`)"):format(home_name(s.home), back) or ""
  drop_record(s.root)
  state = nil
  vim.api.nvim_clear_autocmds({ group = group })
  local tc, tc_level = apply(PRESETS.edit, nil)
  local warn = tc_level == vim.log.levels.WARN
  vim.notify(fit("Edit mode" .. note .. (warn and "; " .. tc or "")), warn and tc_level or nil)
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
  -- The walk follows the base: its list and its return point come along.
  state.base, state.name, state.by_hand = s.base, s.name, true
  state.conv, state.list = s.conv, s.list
  set_base(state.base)
  vim.notify(fit(headline(state)))
end

-- What <Tab> offers: the detected bases first -- the ones this review would
-- consider, or would if it were on -- then every other ref, for anything else.
local function complete(arglead)
  local root = G.root()
  if not root then return {} end
  local on_branch, branch = git(root, { "symbolic-ref", "--short", "-q", "HEAD" })
  local first = vim.deepcopy(state and state.choices or (on_branch and select(3, detected(root, branch))) or {})
  -- The upstream, when there is something unpushed: review before pushing.
  local _, ahead = git(root, { "rev-list", "--count", "@{u}..HEAD" })
  if on_branch and (tonumber(ahead) or 0) > 0 then table.insert(first, "@{u}") end
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
