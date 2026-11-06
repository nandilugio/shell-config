-- Tests for review mode:  nvim -l lua/setup/review_test.lua
--
-- No framework; exit code is 0 when all pass. -l loads the real config, so
-- gitsigns and setup.review are the ones in use. Skips, exiting 0, where git
-- or gitsigns is missing: the mode is absent there too.
--
-- A repository is built in a temp dir with the shapes detection has to tell
-- apart -- stacked, sibling, merged-in, rebased parent, an orphan commit, a
-- bare remote whose develop is ahead of the stale origin/develop -- and every
-- check reads real state back: git's HEAD, the base gitsigns holds, the
-- statusline text. Never what the module says it did.
--
-- The repository, as `git log --graph` would draw it, newest first:
--
--   feature-e   e1'                  (rebased onto d4; d's old parent is orphaned)
--   feature-p   p1 p2 p3             on d4; origin/feature-p twin; upstream set
--   develop     d1 d2 d3 d4          origin/develop is STALE at d4; the bare
--                                    remote has d5
--   feature-a   a1 a2 a3 M(develop)  on d2; develop merged in after a3
--   feature-b   b1 b2                on a2: stacked on feature-a
--   feature-c   c1                   on a3: a sibling, cut from a later
--   feature-m   m_1 M(feature-x) m_2 on d3; feature-x (x1, on d3) merged in
--   feature-d   e1 dd1               on the old, orphaned e1
--   feature-q   q1                   on d5, i.e. on the remote's develop
--   master      m1 m2                origin/master twin, as its upstream

local passed, failed = 0, 0

local function check(name, got, want)
  if vim.deep_equal(got, want) then
    passed = passed + 1
  else
    failed = failed + 1
    io.write(("FAIL  %s\n        got:  %s\n        want: %s\n"):format(name, vim.inspect(got), vim.inspect(want)))
  end
end

-- `got` contains `want`, for messages the width guard may cut.
local function check_has(name, got, want)
  check(name, type(got) == "string" and got:find(want, 1, true) ~= nil and want or got, want)
end

-- -l runs the script in place of the editor's startup, so the config is
-- loaded here: the same init.lua, hence the same gitsigns and setup.review.
if not package.loaded["setup.review"] then dofile(vim.fn.stdpath("config") .. "/init.lua") end

if vim.fn.executable("git") == 0 or not pcall(require, "gitsigns") then
  io.write("review mode needs git and gitsigns: nothing to test here\n")
  os.exit(0)
end

-- ── Fixture ─────────────────────────────────────────────────────────────────

local top = vim.fn.tempname()
local repo = top .. "/repo"
local remote = top .. "/remote.git"
vim.fn.mkdir(repo, "p")

local function sh(cmd, cwd)
  local res = vim.system({ "sh", "-c", cmd }, { cwd = cwd or repo, text = true }):wait()
  assert(res.code == 0, ("fixture: `%s` failed:\n%s"):format(cmd, res.stderr))
  return vim.trim(res.stdout)
end

-- One file per commit, so merges never conflict and every commit names a
-- file that exists from then on.
sh([[
  git init -q -b master && git config user.email t@t && git config user.name t
  c() { echo "$1" > "$1.txt"; git add "$1.txt"; git commit -q -m "$1"; }
  c m1; c m2
  git checkout -q -b develop; c d1; c d2
  git checkout -q -b feature-a; c a1; c a2
  git checkout -q -b feature-b; c b1; c b2
  git checkout -q feature-a; c a3
  git checkout -q -b feature-c; c c1
  git checkout -q develop; c d3
  git checkout -q feature-a; git merge -q --no-edit develop
  git checkout -q develop; git checkout -q -b feature-x; c x1
  git checkout -q develop; git checkout -q -b feature-m; c m_1; git merge -q --no-edit feature-x; c m_2
  git checkout -q develop; git checkout -q -b feature-e; c e1
  git checkout -q -b feature-d; c dd1
  git checkout -q develop; c d4
  git checkout -q feature-e; git rebase -q develop
  git checkout -q develop; git checkout -q -b feature-p; c p1; c p2; c p3
  git checkout -q master
]])
-- The remote: a clone that moves develop on, so a fetch has something to bring.
sh(("git clone -q --bare . %s && git remote add origin %s && git fetch -q origin"):format(remote, remote))
sh(([[
  git clone -q %s clone && cd clone && git config user.email t@t && git config user.name t
  git checkout -q develop && echo d5 > d5.txt && git add d5.txt && git commit -q -m d5 && git push -q origin develop
]]):format(remote), top)
-- feature-q forks from the remote's develop while origin/develop here is still d4.
sh(([[
  git fetch -q %s develop:refs/tmp/d5 && git checkout -q -b feature-q refs/tmp/d5 && git update-ref -d refs/tmp/d5
  echo q1 > q1.txt && git add q1.txt && git commit -q -m q1
  git update-ref refs/remotes/origin/develop develop
  git branch -q --set-upstream-to=origin/master master
  git checkout -q master
]]):format(remote))

-- ── Harness ─────────────────────────────────────────────────────────────────

vim.cmd.cd(repo)
local review = require("setup.review")
local G = require("setup.git")

local msgs = {}
vim.notify = function(m) msgs[#msgs + 1] = m end
local function last_msg() return msgs[#msgs] end

local function head() return sh("git rev-parse HEAD") end
local function subject(rev) return sh("git log -1 --format=%s " .. (rev or "HEAD")) end
local function on_branch() return sh("git symbolic-ref --short -q HEAD || true") end

-- Opens a file and waits for gitsigns to attach, which is when the base can
-- be read. Attaching is asynchronous and quick.
local function open(file)
  vim.cmd.edit(repo .. "/" .. file)
  local buf = vim.api.nvim_get_current_buf()
  assert(vim.wait(5000, function() return require("gitsigns.cache").cache[buf] ~= nil end), "gitsigns did not attach to " .. file)
  return buf
end

local function wait_for(fn) return vim.wait(5000, fn, 50) end

-- The review block and the git segment's label, as the statusline renders
-- them: highlight groups stripped, and the hunk counts too, which belong to
-- the file opened rather than to the review. gitsigns updates its head name
-- asynchronously after a checkout, so the text is awaited rather than read once.
local function statusline()
  local sl = require("setup.statusline")
  local strip = function(s) return (s:gsub("%%#[%w]+#", ""):gsub("%%%*", "")) end
  local text = strip(sl.review()) .. strip(sl.git())
  return (vim.trim(text):gsub("%s+", " "):gsub(" [+~-]%d+", ""))
end

local function statusline_is(name, want)
  wait_for(function() return statusline() == want end)
  check(name, statusline(), want)
end

-- Enters or leaves, then waits for gitsigns to apply the base to the buffer.
local function toggle()
  local want = not review.active()
  review.toggle()
  if want ~= review.active() then return end -- refused; the message says why
  local base = review.active() and review.kind() and true
  wait_for(function() return (G.base(0) ~= nil) == (base == true) end)
end

local function step(dir)
  local before = head()
  review.step(dir)
  wait_for(function() return head() ~= before end)
  vim.wait(200) -- the base and gitsigns' head follow
end

local function git_checkout(ref)
  sh("git checkout -q " .. ref)
  vim.cmd("silent! checktime")
end

-- ── Entry: which base, which kind ───────────────────────────────────────────

local function entry(branch, file, want_msg, want_sl)
  git_checkout(branch)
  open(file)
  toggle()
  check_has("entry on " .. branch .. ": message", last_msg(), want_msg)
  statusline_is("entry on " .. branch .. ": statusline", want_sl)
  toggle()
  check("leave " .. branch .. ": edit mode", { review.active(), vim.o.write, G.base(0) }, { false, true, nil })
end

entry("feature-p", "p1.txt", "Branch review: develop...feature-p", "bR develop...feature-p")
entry("feature-m", "m_1.txt", "Branch review: develop...feature-m", "bR develop...feature-m")
entry("feature-d", "dd1.txt", "Branch review: develop...feature-d", "bR develop...feature-d")
entry("develop", "d1.txt", "Branch review: master...develop", "bR master...develop")
-- Stacked and sibling: the conventional base still wins, with a hint.
entry("feature-b", "b1.txt", "feature-a, feature-c fork nearer (:Review <Tab>)", "bR develop...feature-b")
entry("feature-c", "c1.txt", "feature-a fork nearer (:Review <Tab>)", "bR develop...feature-c")
-- A parent with a child would be hinted too, but feature-c forked before
-- develop was merged into feature-a: older than the base, so not nearer.
entry("feature-a", "a1.txt", "Branch review: develop...feature-a", "bR develop...feature-a")
-- Nothing to compare master against: its last commit.
entry("master", "m2.txt", "Commit review: master^..master", "cR master^..master")
-- Detached: placed on the branch containing it, or the trunk, or nowhere.
entry("--detach feature-p~1", "p1.txt", "Commit review: feature-p~1 2/3", "cR feature-p~1 2/3")
entry("--detach develop~1", "d1.txt", "Commit review: develop~1^..develop~1", "cR develop~1^..develop~1")

-- ── Presets ─────────────────────────────────────────────────────────────────

git_checkout("feature-p")
open("p1.txt")
toggle()
do
  local c = vim.diagnostic.config()
  check("review: diagnostics every line, errors only", {
    type(c.virtual_lines) == "table" and c.virtual_lines.severity.min, c.virtual_text, type(c.underline) == "table",
  }, { vim.diagnostic.severity.ERROR, false, true })
  local gc = require("gitsigns.config").config
  check("review: hunk details on", { gc.show_deleted, gc.word_diff, gc.current_line_blame }, { true, true, true })
  check("review: writes refused", { vim.o.write, (pcall(vim.cmd.write)) }, { false, false })
  G.stage_hunk()
  check_has("review: staging refused", last_msg(), "Signs compare against develop...feature-p, not the index: staging is off")
  check("review: index untouched", sh("git diff --cached --name-only"), "")
end
toggle()
do
  local c = vim.diagnostic.config()
  check("edit: diagnostics cursor line, all", {
    type(c.virtual_text) == "table" and c.virtual_text.current_line, c.virtual_lines, c.underline,
  }, { true, false, false })
  local gc = require("gitsigns.config").config
  check("edit: hunk details off", { gc.show_deleted, gc.word_diff, gc.current_line_blame }, { false, false, false })
end

-- ── The walk ────────────────────────────────────────────────────────────────

-- A cycle through the branch: 0 (the whole branch), 1, 2, 3, 0 again.
toggle()
step(1)
check("walk 1/3: at p1, detached", { subject(), on_branch() }, { "p1", "" })
statusline_is("walk 1/3: statusline", "cR feature-p~2 1/3")
check_has("walk 1/3: message names the commit", last_msg(), "Commit review: feature-p~2 1/3  p1")
check("walk 1/3: base is the parent", G.base(0), sh("git rev-parse HEAD^"))
step(1)
step(1)
check("walk 3/3: the tip, back on the branch", { subject(), on_branch() }, { "p3", "feature-p" })
statusline_is("walk 3/3: statusline", "cR feature-p 3/3")
step(1)
check_has("walk past the tip: branch review again", last_msg(), "Branch review: develop...feature-p")
check("walk past the tip: base is the merge-base", G.base(0), sh("git merge-base feature-p develop"))
step(-1)
check("walk back from 0: the tip", subject(), "p3")
step(-1)
check("walk back: 2/3", subject(), "p2")
-- Leaving mid-walk goes home.
toggle()
check("leave mid-walk: back on the branch", { on_branch(), review.active() }, { "feature-p", false })
check_has("leave mid-walk: says so", last_msg(), "back on feature-p")

-- Guards: each refuses with its reason, and nothing moves.
toggle()
vim.api.nvim_buf_set_lines(0, 0, 0, false, { "an edit" })
review.step(1)
check_has("guard: a buffer with edits", last_msg(), "p1.txt has edits: :e! to drop them first")
vim.cmd("e!")
sh("echo dirt >> p2.txt")
review.step(1)
check_has("guard: a dirty tree", last_msg(), "Uncommitted changes would travel along")
sh("git checkout -- p2.txt")
-- Mid-walk, so that leaving would otherwise go home: a hand move is left alone.
step(1)
sh("git checkout -q --detach feature-p~1")
review.step(1)
check_has("guard: HEAD moved by hand", last_msg(), "HEAD was moved outside review mode")
check("guard: HEAD where the hand left it", subject(), "p2")
toggle()
check_has("leave after a hand move: stays", last_msg(), "HEAD was moved by hand, so it stays")
check("leave after a hand move: still there", { subject(), review.active() }, { "p2", false })

-- A trunk walk has no total and stops at the tip; it stops before the root too.
git_checkout("--detach develop~1")
open("d1.txt")
toggle()
step(1)
check_has("trunk walk forward", last_msg(), "Commit review: develop^..develop  d4")
review.step(1)
check_has("trunk walk: the tip", last_msg(), "At the tip of develop")
toggle()
git_checkout("master")
open("m1.txt")
toggle()
review.step(-1)
check_has("walk stops before the root", last_msg(), "root commit")
toggle()

-- A commit no branch has: only back.
git_checkout("--detach feature-p")
sh("echo o > o.txt && git add o.txt && git commit -q -m orphan")
open("o.txt")
toggle()
check_has("orphan: labelled by sha", last_msg(), "Commit review: " .. sh("git rev-parse --short HEAD") .. "^..")
review.step(1)
check_has("orphan: no way forward", last_msg(), "git records no children")
step(-1)
check("orphan: back to its parent", subject(), "p3")
toggle()
check("orphan: leave returns to it", subject(), "orphan")

-- ── :Review ─────────────────────────────────────────────────────────────────

git_checkout("feature-b")
open("b1.txt")
vim.cmd("Review")
check("command: toggles on", review.kind(), "branch")
check("completion: detected bases first", vim.list_slice(vim.fn.getcompletion("Review ", "cmdline"), 1, 3), { "develop", "feature-a", "feature-c" })
check("completion: no bare remote", vim.tbl_contains(vim.fn.getcompletion("Review ", "cmdline"), "origin"), false)
vim.cmd("Review feature-a")
wait_for(function() return G.base(0) == sh("git merge-base feature-b feature-a") end)
check_has("command: against a ref", last_msg(), "Branch review: feature-a...feature-b")
statusline_is("command: statusline follows", "bR feature-a...feature-b")
-- The walk follows the base: feature-b's own commits, not feature-a's.
step(1)
check("switched base: walk starts on b1", subject(), "b1")
statusline_is("switched base: 1/2", "cR feature-b~1 1/2")
step(-1)
check_has("switched base: back to the switched range", last_msg(), "Branch review: feature-a...feature-b")
vim.cmd("Review")
check("command: toggles off", { review.active(), on_branch() }, { false, "feature-b" })
vim.cmd("Review nope")
check_has("command: a bad ref", last_msg(), "nope: no such ref")
check("command: a bad ref enters nothing", review.active(), false)

-- @{u}: offered when there is something unpushed, and resolved in the label.
git_checkout("master")
open("m2.txt")
sh("git update-ref refs/remotes/origin/master master~1")
check("completion: @{u} when ahead", vim.tbl_contains(vim.list_slice(vim.fn.getcompletion("Review ", "cmdline"), 1, 3), "@{u}"), true)
vim.cmd("Review @{u}")
wait_for(function() return review.active() end)
check_has("review @{u}: resolved name", last_msg(), "Branch review: origin/master...master")
vim.cmd("Review")
sh("git update-ref refs/remotes/origin/master master")

-- ── The fetch ───────────────────────────────────────────────────────────────
-- feature-q forks from the remote's develop, so a stale origin/develop gives
-- d4 as the base until the fetch brings d5. Every branch entry above fetched
-- already, so the ref is made stale again here.

git_checkout("feature-q")
sh("git update-ref refs/remotes/origin/develop develop")
open("q1.txt")
toggle()
check_has("fetch: stale base first", last_msg(), "Branch review: develop...feature-q")
check("fetch: moves the base", wait_for(function() return (last_msg() or ""):find("Fetched: Branch review: origin/develop...feature-q", 1, true) ~= nil end), true)
do
  local want = sh("git rev-parse origin/develop")
  wait_for(function() return G.base(0) == want end)
  check("fetch: base is the remote's develop", G.base(0), want)
end
toggle()

-- ── Report ──────────────────────────────────────────────────────────────────

vim.fn.delete(top, "rf")
io.write(("\n%d passed, %d failed\n"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
