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

-- Review mode keeps a record of each review in Neovim's state directory. Run
-- again with a temporary one, so the suite -- and the Neovims it starts --
-- never touch the real one.
if not vim.env.REVIEW_TEST_STATE then
  local state = vim.fn.tempname()
  local res = vim.system({ vim.v.progpath, "-l", debug.getinfo(1, "S").source:sub(2) }, {
    env = { REVIEW_TEST_STATE = state, XDG_STATE_HOME = state },
  }, function() end):wait()
  io.write(res.stdout or "", res.stderr or "")
  vim.fn.delete(state, "rf")
  os.exit(res.code)
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

-- Review mode's questions are Neovim's confirm(). Answered here from a queue
-- of keys -- "y", "n", or Enter, the default, when it is empty -- and every
-- question asked is kept, as its text.
local keys, asked = {}, {}
vim.fn.confirm = function(text, choices, default)
  table.insert(asked, text)
  local key = table.remove(keys, 1) or "\r"
  if key == "\r" then return default end
  for i, choice in ipairs(vim.split(choices, "\n")) do
    if choice:gsub("&", ""):sub(1, 1):lower() == key then return i end
  end
  return 0
end

-- The questions at quitting, and on entering where a review was left behind,
-- need a screen to be asked on; -l has none. Switched on where those are
-- tested.
local ui = false
local list_uis = vim.api.nvim_list_uis
vim.api.nvim_list_uis = function() return ui and { {} } or list_uis() end

-- Named after the repository as git resolves it: on macOS the temp dir is
-- behind a symlink, /var -> /private/var.
local function record()
  local root = sh("git rev-parse --show-toplevel")
  return vim.fn.stdpath("state") .. "/review/" .. root:gsub("[/\\:]", "%%") .. ".json"
end
local function has_record() return vim.uv.fs_stat(record()) ~= nil end

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

-- ── The base, kept ──────────────────────────────────────────────────────────
-- gitsigns can put an older base back after a checkout (TODO 29). The race
-- itself cannot be staged on demand; the corrector can: a buffer whose base
-- went wrong gets the review's back on gitsigns' update event. (It does so
-- once per buffer and base; gitsigns' own updates land too, so that bound is
-- not observable here.)
toggle()
local entry = require("gitsigns.cache").cache[vim.api.nvim_get_current_buf()]
local base = G.base(0)
entry.git_obj.revision = sh("git rev-parse develop~1")
vim.api.nvim_exec_autocmds("User", { pattern = "GitSignsUpdate", data = { buffer = vim.api.nvim_get_current_buf() } })
wait_for(function() return G.base(0) == base end)
check("kept base: put back on the update event", G.base(0), base)
toggle()
wait_for(function() return G.base(0) == nil end)

-- A base set by hand reads with two dots: what `git diff HEAD~2` compares.
require("gitsigns").change_base("HEAD~2", true)
statusline_is("hand-set base: two dots", "HEAD~2..feature-p")
G.stage_hunk()
check_has("hand-set base: staging refused, naming it", last_msg(), "Signs compare against HEAD~2, not the index")
-- <leader>gD's fallback lists what the signs mark, against that base.
G.changed_files()
check("hand-set base: changed files against it", vim.tbl_map(function(f) return vim.fs.basename(f) end, vim.fn.argv()), { "p2.txt", "p3.txt" })
-- :args edits its first file; back to the one the rest of the suite expects.
vim.cmd("%argdelete")
open("p1.txt")
require("gitsigns").reset_base(true)
wait_for(function() return G.base(0) == nil end)
statusline_is("index again: plain", "feature-p")

-- ── The walk ────────────────────────────────────────────────────────────────

-- The first checkout asks, naming the command; n leaves everything as it was.
toggle()
check("record: written on entering", has_record(), true)
keys = { "n" }
review.step(1)
check("first checkout: asks", #asked, 1)
check_has("first checkout: names the command", asked[1], "Now: `git switch --detach " .. sh("git rev-parse --short feature-p~2") .. "`. Run?")
check("first checkout: n checks nothing out", { subject(), on_branch() }, { "p3", "feature-p" })

-- A cycle through the branch: 0 (the whole branch), 1, 2, 3, 0 again.
step(1)
check("first checkout: asked again, Enter is yes", #asked, 2)
check("walk 1/3: at p1, detached", { subject(), on_branch() }, { "p1", "" })
statusline_is("walk 1/3: statusline", "cR feature-p~2 1/3")
check_has("walk 1/3: message names the commit", last_msg(), "Commit review: feature-p~2 1/3  p1")
check("walk 1/3: base is the parent", G.base(0), sh("git rev-parse HEAD^"))
step(1)
step(1)
check("first checkout: the walk asks only once", #asked, 2)
check("walk 3/3: the tip, back on the branch", { subject(), on_branch() }, { "p3", "feature-p" })
check("record: kept while reviewing, even at home", has_record(), true)
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
check_has("leave mid-walk: says so, with the command", last_msg(), "back on feature-p (`git switch feature-p`)")
check("leave mid-walk: record gone", has_record(), false)

-- Leaving is refused on a step's grounds, and works once they are cleared.
toggle()
step(1)
sh("echo dirt >> p1.txt")
toggle()
check_has("leave refused: a dirty tree, with the commands", last_msg(), "Still reviewing. p1.txt has uncommitted changes: `git stash` them, or `git restore -SW p1.txt` to drop them")
check("leave refused: still reviewing, still away", { review.active(), subject() }, { true, "p1" })
sh("git checkout -- p1.txt")
vim.cmd("silent! checktime")
toggle()
check("leave after cleaning: home", { review.active(), on_branch() }, { false, "feature-p" })

-- A home branch deleted mid-walk must not keep you in review.
sh("git branch -q gone feature-p && git switch -q gone")
vim.cmd("silent! checktime")
toggle()
step(1)
sh("git branch -q -D gone")
toggle()
check_has("home deleted: leaving still works", last_msg(), "gone no longer exists, so HEAD stays")
check("home deleted: out of review, no record", { review.active(), has_record() }, { false, false })
git_checkout("feature-p")

-- A home branch moved meanwhile -- reset, rebased, new commits -- is
-- returned to where it is now.
local tip = head()
toggle()
step(1)
sh("git update-ref refs/heads/feature-p feature-p~1")
toggle()
check("home moved: back on it, at its new tip", { on_branch(), subject() }, { "feature-p", "p2" })
sh("git reset -q --hard " .. tip)
vim.cmd("silent! checktime")

-- Guards: each refuses with its reason, and nothing moves.
toggle()
vim.api.nvim_buf_set_lines(0, 0, 0, false, { "an edit" })
review.step(1)
check_has("guard: a buffer with edits", last_msg(), "p1.txt has edits: :e! to drop them")
vim.cmd("e!")
sh("echo dirt >> p2.txt")
review.step(1)
check_has("guard: a dirty file", last_msg(), "p2.txt has uncommitted changes: `git stash` them, or `git restore -SW p2.txt` to drop them")
sh("echo dirt >> p3.txt")
review.step(1)
check_has("guard: dirty files", last_msg(), "p2.txt and 1 more have uncommitted changes: `git stash` them, or `git restore -SW :/` to drop them")
sh("git checkout -- p2.txt p3.txt")
sh("touch .git/MERGE_HEAD")
review.step(1)
check_has("guard: a merge, its commands", last_msg(), "A merge is in progress: `git merge --continue` or `git merge --abort`")
sh("rm .git/MERGE_HEAD && touch .git/BISECT_LOG")
review.step(1)
check_has("guard: a bisect, its command", last_msg(), "A bisect is in progress: `git bisect reset`")
sh("rm .git/BISECT_LOG")
-- Entering is refused during one too.
toggle()
sh("mkdir .git/rebase-merge")
toggle()
check_has("enter during a rebase: refused, both ways out", last_msg(), "A rebase is in progress: `git rebase --continue` or `git rebase --abort` first")
check("enter during a rebase: nothing started", review.active(), false)
sh("rmdir .git/rebase-merge")
toggle()
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

-- ── Quitting ────────────────────────────────────────────────────────────────
-- First the exit hook itself, run here without exiting, with a screen to ask
-- on. Then real quits, in Neovims of their own started in the fixture
-- repository with the same config; those have no screen, as a script's or a
-- killed terminal's would not.

local function quit_hook() vim.api.nvim_exec_autocmds("VimLeavePre", { group = "review" }) end

git_checkout("feature-p")
ui = true
toggle()
step(1)
sh("echo dirt >> p1.txt")
keys = { "\r" }
quit_hook()
check("quit, dirty: the question", asked[#asked], "Review mode can't take HEAD back to feature-p: p1.txt has uncommitted changes.\nTo go back: `git stash; git switch feature-p`. Run?")
check("quit, dirty: Enter is no, so nothing moves", { subject(), has_record(), sh("git stash list") }, { "p1", true, "" })
keys = { "y" }
quit_hook()
check("quit, dirty: y stashes and goes back", { on_branch(), has_record(), sh("git stash list | wc -l | tr -d ' '") }, { "feature-p", false, "1" })
sh("git stash drop -q")
toggle()

toggle()
step(1)
sh("mkdir .git/rebase-merge")
quit_hook()
check("quit, rebase: says why, both ways out, no offer", asked[#asked], "Review mode can't take HEAD back to feature-p: A rebase is in progress.\nTo go back: `git rebase --continue` or `git rebase --abort`, then `git switch feature-p`.")
check("quit, rebase: HEAD stays", subject(), "p1")
sh("rmdir .git/rebase-merge")
toggle()
check("quit, rebase: leaving after it, home", on_branch(), "feature-p")
ui = false

-- Real quits. The child enters review, steps once, then does what VARIANT
-- says and quits -- or is killed.
local child_script = top .. "/child.lua"
vim.fn.writefile({
  'local C = require("gitsigns.cache").cache',
  'vim.cmd.edit("p1.txt")',
  'local b = vim.api.nvim_get_current_buf()',
  'vim.wait(5000, function() return C[b] ~= nil end)',
  'vim.fn.confirm = function() return 1 end',
  'local r = require("setup.review")',
  'r.toggle()',
  'local v = vim.env.VARIANT or ""',
  'if v == "live" then vim.wait(6000) vim.cmd("qa!") end',
  'r.step(1)',
  'vim.wait(500)',
  'if v == "dirty" then vim.fn.system("echo dirt >> p1.txt") end',
  'if v == "unsaved" then vim.api.nvim_buf_set_lines(0, 0, 0, false, { "unsaved" }) end',
  'if v == "moved" then vim.fn.system("git switch -q --detach feature-p~1") end',
  'if v == "killed" then vim.uv.kill(vim.uv.os_getpid(), "sigkill") end',
  'vim.cmd("qa!")',
}, child_script)

local function child(variant, wait)
  local cmd = { vim.v.progpath, "--headless", "-n", "-c", "luafile " .. child_script }
  local proc = vim.system(cmd, { cwd = repo, env = { VARIANT = variant }, text = true })
  if wait ~= false then proc:wait() end
  return proc
end

git_checkout("feature-p")
child("clean")
check("quit mid-walk, clean: HEAD back home", { on_branch(), has_record() }, { "feature-p", false })
child("unsaved")
check("quit mid-walk, unsaved buffer: home all the same", { on_branch(), has_record() }, { "feature-p", false })
child("moved")
check("quit after a hand move: HEAD stays, no record", { subject(), has_record() }, { "p2", false })
git_checkout("feature-p")

child("dirty")
check("quit mid-walk, dirty: HEAD stays, record kept", { subject(), on_branch(), has_record() }, { "p1", "", true })
-- Entering review here offers the way back first, as the next start would.
ui = true
keys = { "n" }
toggle()
check("left behind, dirty: offered stash and switch", asked[#asked], ("Review mode left HEAD at %s (feature-p~2 1/3): p1.txt has uncommitted changes.\nTo go back: `git stash; git switch feature-p`. Run?"):format(sh("git rev-parse --short HEAD")))
check("left behind, dirty: declined, review starts here", { review.kind(), subject() }, { "commit", "p1" })
-- Declined, the new review keeps the old one's home: leaving still returns.
sh("git checkout -- p1.txt")
vim.cmd("silent! checktime")
toggle()
check("left behind, declined: leaving keeps the old promise", { on_branch(), has_record() }, { "feature-p", false })
check_has("left behind, declined: says so", last_msg(), "back on feature-p (`git switch feature-p`)")
ui = false

child("killed")
check("killed mid-walk: HEAD stays, record kept", { subject(), has_record() }, { "p1", true })
ui = true
keys = { "y" }
toggle()
check("left behind, clean: offered the switch", asked[#asked], ("Review mode left HEAD at %s (feature-p~2 1/3).\nTo go back: `git switch feature-p`. Run?"):format(sh("git rev-parse --short feature-p~2")))
check("left behind, clean: y goes back, then review starts", { on_branch(), review.kind() }, { "feature-p", "branch" })
toggle()
ui = false

-- Two Neovims, one repository: the second may not start a review of its own.
local live = child("live", false)
wait_for(function() return has_record() end)
toggle()
check_has("another Neovim reviewing: refused, naming it", last_msg(), "is reviewing in this repository")
check("another Neovim reviewing: nothing started here", review.active(), false)
live:wait()
check("another Neovim reviewing: it went home on quitting", { on_branch(), has_record() }, { "feature-p", false })

-- ── The fetch ───────────────────────────────────────────────────────────────
-- feature-q forks from the remote's develop, so a stale origin/develop gives
-- d4 as the base until the fetch brings d5. Every branch entry above fetched
-- already, so the ref is made stale again here.

git_checkout("feature-q")
sh("git update-ref refs/remotes/origin/develop develop")
open("q1.txt")
-- The fetch talks to a local remote, so it can land before this looks:
-- the entry's message is the first after entering, not necessarily the last.
local n_msgs = #msgs
toggle()
check_has("fetch: stale base first", msgs[n_msgs + 1], "Branch review: develop...feature-q")
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
