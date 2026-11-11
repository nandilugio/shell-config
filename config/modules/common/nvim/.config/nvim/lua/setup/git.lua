-- Only the part that belongs in the editor: which lines changed, hunk
-- navigation, staging without leaving the buffer. Commits and rebases are a
-- git UI's job, in a tmux pane; the editor need not know about it.

local ok, gitsigns = pcall(require, "gitsigns")
if ok then
  gitsigns.setup({
    -- Characters rather than gitsigns' bars, which leave the colour to carry
    -- the meaning. + and ~ sit on the line they describe, so they read as
    -- diff output does. A deletion has no line to sit on -- the text is gone
    -- -- so _ and ‾ mark the edge it went from instead: _ on the line below
    -- the gap, ‾ on line 1 when the gap is above it. ≃ is a change that also
    -- shortened. Plain UTF-8 throughout, no Nerd Font.
    --
    -- show_count only on the deletions, the three where the lines are not on
    -- screen to be counted: 2 gone looks exactly like 200. It is free --
    -- 'signcolumn' reserves two cells whether or not anything fills the
    -- second -- and reads 1-9 then > for more.
    signs = {
      add = { text = "+" },
      change = { text = "~" },
      delete = { text = "_", show_count = true },
      topdelete = { text = "‾", show_count = true },
      changedelete = { text = "≃", show_count = true },
      untracked = { text = "┆" },
    },
    -- Same characters again: staged-ness is already in the colour, which
    -- gitsigns dims to half brightness. Unset, this defaults back to the bars.
    signs_staged = {
      add = { text = "+" },
      change = { text = "~" },
      delete = { text = "_", show_count = true },
      topdelete = { text = "‾", show_count = true },
      changedelete = { text = "≃", show_count = true },
    },
  })

  -- One palette for every diff display: the inline diff (M.inline_diff, on in
  -- review mode) and the <leader>gp popup. Four tints, a line and a word one
  -- per side: removed lines and words red, added and changed ones green. A
  -- changed line is the new text, so it is green too; its old text shows as
  -- removed lines. In the default dark scheme: lines #3e1216 and #193524,
  -- words #6b1a24 and #226432, each word tint a clear step above its line.
  --
  -- Backgrounds only. gitsigns' defaults borrow DiffAdd, DiffChange and
  -- DiffDelete, whose foregrounds hide the syntax colours it captures for the
  -- old text, and reverse video for removed words. Each tint is the editor's
  -- background mixed with a colour, so it follows <leader>ub and the scheme.
  local function mix(from, to, t)
    local out = 0
    for shift = 16, 0, -8 do
      local a, b = bit.band(bit.rshift(from, shift), 0xff), bit.band(bit.rshift(to, shift), 0xff)
      out = out + bit.lshift(math.floor(a + (b - a) * t + 0.5), shift)
    end
    return out
  end

  local function set_highlights()
    local bg = vim.api.nvim_get_hl(0, { name = "Normal", link = false }).bg
      or (vim.o.background == "light" and 0xffffff or 0x000000) -- a transparent terminal
    local removed_line = { bg = mix(bg, 0xff0000, 0.18) }
    local removed_word = { bg = mix(bg, 0xff2133, 0.37) }
    local added_line = { bg = mix(bg, 0x32c34d, 0.18) }
    local added_word = { bg = mix(bg, 0x32c34d, 0.45) }
    -- Removed: the inline diff's virtual lines and the popup's old side.
    vim.api.nvim_set_hl(0, "GitSignsDeleteVirtLn", removed_line)
    vim.api.nvim_set_hl(0, "GitSignsDeletePreview", removed_line)
    vim.api.nvim_set_hl(0, "GitSignsDeleteVirtLnInLine", removed_word)
    vim.api.nvim_set_hl(0, "GitSignsDeleteInline", removed_word)
    -- The removed lines' gutter (their old line numbers) as any other line's:
    -- gitsigns tints it red, while the added lines' gutter is gitsigns' signs
    -- on the plain column, so the two sides differed at the left edge.
    vim.api.nvim_set_hl(0, "GitSignsVirtLnum", { link = "LineNr" })
    -- Word diff also marks, on a new line, the character after a cut, for when
    -- the old text is not on screen. Ours always is (the removed lines), and a
    -- red character reads as a changed one, so the mark takes the line's green,
    -- as other diff views show nothing there. A link, which gitsigns counts as
    -- defined: an empty group it would define again on :Gitsigns refresh.
    vim.api.nvim_set_hl(0, "GitSignsDeleteLnInline", { link = "InlineDiffLine" })
    -- Added and changed: the buffer's own lines (ours, see M.inline_diff) and
    -- the popup's new side; the buffer's word diff links
    -- GitSigns{Add,Change}LnInline to the word groups.
    vim.api.nvim_set_hl(0, "InlineDiffLine", added_line)
    vim.api.nvim_set_hl(0, "GitSignsAddPreview", added_line)
    vim.api.nvim_set_hl(0, "GitSignsAddInline", added_word)
    vim.api.nvim_set_hl(0, "GitSignsChangeInline", added_word)
  end

  set_highlights()
  -- A colourscheme change clears every group; gitsigns' own are only defaults.
  vim.api.nvim_create_autocmd("ColorScheme", { callback = set_highlights })
end

-- RuboCop via :make, because on Ruby 2.x the server runs under a newer
-- interpreter and cannot reach the project's own rubocop. Neovim ships the
-- compiler definition; results land in the quickfix list.
vim.api.nvim_create_autocmd("FileType", {
  pattern = "ruby",
  callback = function(args)
    vim.cmd("compiler rubocop")
    -- From the file, not the cwd: they differ when opening by path.
    local gemfile = vim.fs.find("Gemfile", {
      upward = true,
      path = vim.fs.dirname(vim.api.nvim_buf_get_name(args.buf)),
    })[1]
    if gemfile then
      vim.bo[args.buf].makeprg = "bundle exec rubocop --format emacs"
    end
  end,
})

-- ── Line history ────────────────────────────────────────────────────────────
-- `git log -L` answers the question blame cannot: not "who touched this last"
-- but "how did this line get here". It follows the line through renames and
-- reindentation, printing each commit with the diff of just that line.
--
-- gitsigns is hunk-scoped by design and has no equivalent.
--
-- The function form, `git log -L :name:file`, is the better tool on a
-- definition line: -L is cursor-scoped, so on a `def` it shows the signature
-- changing and hides the body that changed with it. Naming the function asks
-- for the whole thing, every time.

local M = {}

-- Every one of these addresses the file as a bare basename run from its own
-- directory, because -L resolves its path against the cwd and takes no
-- pathspec. Returns nil after notifying, so callers just bail.
local function buffer_file()
  local name = vim.api.nvim_buf_get_name(0)
  if name == "" then
    vim.notify("No file in this buffer", vim.log.levels.WARN)
    return nil
  end
  return vim.fn.fnamemodify(name, ":t"), vim.fs.dirname(name)
end

-- A split rather than a float: this is output you scroll and read down, where
-- the floats here are for a glance. filetype=git gives it the diff colours
-- treesitter already has, and q closes it as everywhere else.
local function show(title, lines)
  vim.cmd("botright split")
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = "git"
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].modifiable = false
  -- The title goes in the statusline rather than the buffer name: naming the
  -- buffer makes a second look at the same range fail with E95.
  vim.wo.statusline = title

  vim.keymap.set("n", "q", "<Cmd>close<CR>", { buffer = buf, nowait = true, desc = "Close" })
end

-- Runs git in the file's own directory and shows the output, or says why there
-- is none. `hint` is appended to a non-zero exit, where git's own message is
-- accurate but not actionable.
local function run(args, cwd, title, hint)
  local res = vim.system(args, { cwd = cwd, text = true }):wait()

  if res.code ~= 0 then
    local err = vim.trim(res.stderr or "git failed")
    if hint and hint.when and err:match(hint.when) then
      err = err .. "\n\n" .. hint.say
    end
    vim.notify(err, vim.log.levels.WARN)
    return
  end

  local lines = vim.split(res.stdout, "\n", { trimempty = true })
  if #lines == 0 then
    -- Exit 0 with nothing to show: the file is tracked but this line, function
    -- or path has no commits of its own.
    vim.notify("No history found", vim.log.levels.INFO)
    return
  end

  show(title, lines)
end

-- Normal mode gives the cursor line; visual mode the selection. `'<` and `'>`
-- are only set on leaving visual mode, which has not happened while the
-- mapping body runs, so the live selection is read from `v` and the cursor.
function M.line_history(range)
  local file, cwd = buffer_file()
  if not file then return end

  local first, last
  if range then
    first, last = vim.fn.line("v"), vim.api.nvim_win_get_cursor(0)[1]
    if first > last then first, last = last, first end
    -- Leave visual mode, as the selection has been consumed.
    vim.cmd("normal! \27")
  else
    first = vim.api.nvim_win_get_cursor(0)[1]
    last = first
  end

  run(
    { "git", "log", "-L", ("%d,%d:%s"):format(first, last, file) },
    cwd,
    ("git log -L %d,%d"):format(first, last)
  )
end

-- Only what can sensibly follow `-L :name:`. setup/winbar.lua walks the same
-- tree for its breadcrumb, but wants the opposite of this: classes and modules
-- are most of what makes a trail worth reading, and none of them are things
-- git can trace. Two similar walks answering different questions, kept apart.
local TRACEABLE = { Function = true, Method = true, Constructor = true }

local function innermost_function(symbols, line, found)
  for _, s in ipairs(symbols or {}) do
    local range = s.range or (s.location and s.location.range)
    if range and line >= range.start.line and line <= range["end"].line then
      if TRACEABLE[vim.lsp.protocol.SymbolKind[s.kind]] then
        found = s.name
      end
      return innermost_function(s.children, line, found)
    end
  end
  return found
end

-- Asked for on demand: winbar's cache holds a display string, and only
-- refreshes on CursorHold.
local function enclosing_function(buf, line)
  local clients = vim.lsp.get_clients({ bufnr = buf, method = "textDocument/documentSymbol" })
  if #clients == 0 then return nil end

  local res = clients[1]:request_sync("textDocument/documentSymbol", {
    textDocument = vim.lsp.util.make_text_document_params(buf),
  }, 1000, buf)
  if not res or res.err or not res.result then return nil end

  return innermost_function(res.result, line, nil)
end

-- `-L :name:file`. git finds the function with a per-language "funcname"
-- pattern, and ships one for most languages -- but SHIPPING IS NOT ENABLING:
-- the pattern lies dormant until a .gitattributes marks the file as using it,
-- which many repositories never do. Without that, -L falls back to a plain
-- regex over the name, which does not match a definition line, and git says
-- only "no match". The check below turns that into the actual instruction.
function M.function_history()
  local file, cwd = buffer_file()
  if not file then return end

  local line = vim.api.nvim_win_get_cursor(0)[1]
  local name = enclosing_function(vim.api.nvim_get_current_buf(), line - 1)
  if not name then
    -- No server, or the cursor is not inside anything the server names. Asking
    -- beats failing: the name is often on screen.
    name = vim.fn.input("Function: ")
    if name == "" then return end
  end

  run({ "git", "log", "-L", (":%s:%s"):format(name, file) }, cwd, (":%s:"):format(name), {
    -- "no match" usually means the pattern was never enabled here, not that
    -- the name is wrong, and git's own message does not say so.
    when = "no match",
    say = "funcname patterns are per-repository: add e.g. `*.py diff=python`"
      .. "\nto .gitattributes. Until then <leader>gl gives line history.",
  })
end

-- Every commit touching this file. fzf-lua's git_bcommits is the good version
-- of this -- a picker with the diff in a preview -- so <leader>gf prefers it
-- and falls back here, where there is no fzf. --follow crosses renames;
-- --oneline because a file's whole patch history is far more than is wanted.
function M.file_history()
  local file, cwd = buffer_file()
  if not file then return end

  run({ "git", "log", "--follow", "--oneline", "--", file }, cwd, file)
end

-- ── Base ────────────────────────────────────────────────────────────────────
-- What a buffer's signs compare against: the index, unless something changed
-- it with :Gitsigns change_base (or setup/review.lua did). Everything that
-- reads a hunk depends on it -- the statusline's counts, staging.
--
-- gitsigns has no getter, so this reads its cache, an internal table. Each
-- attached buffer keeps its own effective base there (git_obj.revision), set
-- by a global change_base and a per-buffer one alike, so reading it per buffer
-- is right either way. The string is kept as given: "develop", a sha, or
-- HEAD~2 (a bare ~2 gets HEAD prepended). nil means the index.
--
-- Guarded: if gitsigns reshapes its cache this returns nil, as if comparing
-- against the index, and :checkhealth config reports the breakage.
--- @param buf integer?
--- @return string?
function M.base(buf)
  buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf
  local ok, rev = pcall(function() return require("gitsigns.cache").cache[buf].git_obj.revision end)
  return ok and rev or nil
end

-- The files git leaves in its directory while an operation is under way.
local OPERATIONS = {
  { "rebase-merge", "rebase" },
  { "rebase-apply", "rebase" },
  { "MERGE_HEAD", "merge" },
  { "CHERRY_PICK_HEAD", "cherry-pick" },
  { "REVERT_HEAD", "revert" },
  { "BISECT_LOG", "bisect" },
}

--- The operation in progress in a git directory, as git names it -- "rebase",
--- "merge" -- or nil. The statusline shows it; review mode refuses to check
--- anything out during one.
--- @param gitdir string
--- @return string?
function M.operation(gitdir)
  for _, op in ipairs(OPERATIONS) do
    if vim.uv.fs_stat(gitdir .. "/" .. op[1]) then return op[2] end
  end
end

--- A revision as the eye wants it: a full sha cut to git's default 7.
--- @param rev string
function M.short_rev(rev)
  if #rev > 7 and rev:match("^%x+$") then return rev:sub(1, 7) end
  return rev
end

--- The git directory of the current buffer's repository: .git, or where a
--- worktree's .git file points. Where git keeps MERGE_HEAD and the like.
--- @return string?
function M.gitdir()
  local d = vim.b.gitsigns_status_dict
  if d and d.gitdir then return d.gitdir end
  local res = vim.system({ "git", "rev-parse", "--absolute-git-dir" }, { cwd = M.root() or vim.uv.cwd(), text = true }):wait()
  return res.code == 0 and vim.trim(res.stdout) or nil
end

--- The repository holding the current buffer's file, or nil outside one.
--- @return string?
function M.root()
  local d = vim.b.gitsigns_status_dict
  if d and d.root then return d.root end
  local name = vim.api.nvim_buf_get_name(0)
  local dir = name ~= "" and vim.fs.dirname(name) or vim.uv.cwd()
  local res = vim.system({ "git", "rev-parse", "--show-toplevel" }, { cwd = dir, text = true }):wait()
  return res.code == 0 and vim.trim(res.stdout) or nil
end

-- The files whose signs show something, against the same base: unstaged
-- changes normally, the whole branch in review mode. <leader>gD prefers
-- fzf-lua's git_diff, a picker with each file's diff as preview; this is the
-- fallback where there is no fzf -- the argument list, which ]a and [a walk.
-- Deleted files are left out: there is nothing to open.
function M.changed_files()
  local root = M.root()
  if not root then
    vim.notify("Not in a git repository", vim.log.levels.WARN)
    return
  end
  local cmd = { "git", "-C", root, "diff", "--name-only", "--diff-filter=d" }
  local base = M.base(0)
  if base then table.insert(cmd, base) end
  local res = vim.system(cmd, { text = true }):wait()
  local files = vim.split(res.stdout or "", "\n", { trimempty = true })
  if res.code ~= 0 or #files == 0 then
    vim.notify(res.code ~= 0 and vim.trim(res.stderr) or "No changed files", vim.log.levels.INFO)
    return
  end
  vim.cmd.args(vim.tbl_map(function(f) return vim.fn.fnameescape(root .. "/" .. f) end, files))
  vim.notify(("%d changed files in the argument list: ]a and [a walk them"):format(#files))
end

-- ── Commits ─────────────────────────────────────────────────────────────────
-- <leader>gi shows a commit as `git show --stat --patch` prints it: header,
-- message, the files with their counts, the patch. HEAD's, which is the
-- commit under review while walking and the last commit otherwise, so it
-- needs no notion of review mode. --first-parent, as the signs compare:
-- without it a merge shows no patch at all, unless it had conflicts. The
-- <leader>gc picker is fzf-lua's git_commits, its preview fzf-lua's own.

-- fzf-lua's own line for git_commits, set here so the lists review mode makes
-- look like the plain log.
local LOG = [[git log --color --pretty=format:"%C(yellow)%h%Creset %Cgreen(%><(12)%cr%><|(12))%Creset %s %C(blue)<%an>%Creset"]]

--- Shows a commit (HEAD by default) in a float: header, message, files, patch.
--- @param rev? string
function M.commit_info(rev)
  local root = M.root()
  if not root then return vim.notify("Not in a git repository", vim.log.levels.WARN) end
  local res = vim.system({ "git", "-C", root, "show", "--stat", "--patch", "--first-parent", "--no-color", rev or "HEAD", "--" }, { text = true })
    :wait()
  if res.code ~= 0 then return vim.notify(vim.trim(res.stderr), vim.log.levels.WARN) end
  local lines = vim.split(res.stdout, "\n", { trimempty = true })

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = "git" -- the diff colours, as in the history splits
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  vim.keymap.set("n", "q", "<Cmd>close<CR>", { buffer = buf, nowait = true, desc = "Close" })

  -- As the cheatsheet's float: centred, square, most of the screen.
  local width = math.min(100, math.floor(vim.o.columns * 0.9))
  local height = math.floor(vim.o.lines * 0.85)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "single",
    title = (" Commit %s "):format(M.short_rev(lines[1]:match("^commit (%x+)") or rev or "HEAD")),
    title_pos = "center",
  })
  vim.wo[win].cursorline = true
end

--- The commits, as a picker whose Enter goes to the one picked. Elsewhere it
--- is fzf-lua's git_commits as it comes: the log from HEAD, Enter a checkout,
--- asked first. In review mode the list is where ]v and [v go -- a branch's
--- own commits and the whole branch, or the history a trunk walk goes back
--- through -- and Enter moves the review there, with ]v's checks.
function M.commits()
  local review = require("setup.review")
  local reach = review.reachable()
  -- The review's repository while there is one: its commits are the list.
  local root = reach and reach.root or M.root()
  if not root then return vim.notify("Not in a git repository", vim.log.levels.WARN) end
  local fzf = require("setup.fzf")
  if not reach then return fzf.git_commits({ cwd = root }) end

  local opts = {
    cwd = root,
    actions = {
      -- What a pick has to say, it says once the picker is gone, and a
      -- refusal waits for a key: printed, it would be wiped as the picker
      -- closes. The routine line is not missed: the statusline shows it.
      enter = function(selected)
        local rev = selected[1] and selected[1]:match("^%S+")
        if not rev then return end
        local _, why_not
        if rev:find("..", 1, true) then _, why_not = review.go_to(nil, true) else _, why_not = review.go_to(rev) end
        if why_not then vim.fn.confirm(why_not, "&OK", 1, "Warning") end
      end,
      -- fzf-lua's own opens its diff picker with this picker's options,
      -- which would list these commits there.
      ["ctrl-d"] = false,
    },
  }
  if reach.list then
    -- The whole branch as one entry, a range: its preview is then every
    -- commit, newest first. Then its own commits, when it has any that are
    -- not merges: with none to name, git log would list HEAD.
    local w = reach.whole
    local whole = ("\27[33m%s..%s\27[0m whole branch: %s"):format(M.short_rev(w.base), M.short_rev(w.tip), w.label)
    opts.cmd = ("printf '%%s\\n' %s"):format(vim.fn.shellescape(whole))
    if #reach.list > 0 then opts.cmd = ("%s; %s --no-walk=unsorted %s"):format(opts.cmd, LOG, table.concat(reach.list, " ")) end
    opts.winopts = { title = (" Commits under review: %s "):format(w.label) }
  else
    -- Without the root, which has no parent to be reviewed against. Titled,
    -- since a whole history in review mode looks like a list gone wrong.
    opts.cmd = ("%s --first-parent --min-parents=1 %s"):format(LOG, reach.from)
    opts.winopts = { title = (" History back from %s "):format(reach.label) }
  end
  fzf.git_commits(opts)
end

-- ── Staging ─────────────────────────────────────────────────────────────────
-- Staging writes the index, which only makes sense while the hunks are
-- measured against it. Against another base a hunk is that base's diff:
-- staging it puts the wrong text in the index, and resetting rewrites the
-- file to the base -- in review mode, undoing the author's change in your
-- working tree. gitsigns does both without asking, so <leader>gs/gS/gr/gR go
-- through these, which refuse instead. (:Gitsigns stage_hunk still works.)

local function against_index(what)
  local base = M.base(0)
  if not base then return true end
  local review = package.loaded["setup.review"]
  local name = review and review.label(base) or M.short_rev(base)
  vim.notify(
    ("Signs compare against %s, not the index: %s is off"):format(name, what),
    vim.log.levels.WARN
  )
  return false
end

--- @param range [integer, integer]?
function M.stage_hunk(range)
  if against_index("staging") then require("gitsigns").stage_hunk(range) end
end

--- @param range [integer, integer]?
function M.reset_hunk(range)
  if against_index("resetting") then require("gitsigns").reset_hunk(range) end
end

function M.stage_buffer()
  if against_index("staging") then require("gitsigns").stage_buffer() end
end

function M.reset_buffer()
  if against_index("resetting") then require("gitsigns").reset_buffer() end
end

-- ── Inline diff ─────────────────────────────────────────────────────────────
-- The inline diff: each change's old text shown under the new, as a pull
-- request's unified view does. Removed lines, word diff and line backgrounds
-- only read together -- word diff marks the removed words inside the removed
-- lines, and green lines without them hide what they replaced -- so they
-- switch as one. nil toggles; returns whether it is now on.
--
-- The line backgrounds are drawn here, not with gitsigns' linehl: Neovim lets a
-- sign's line highlight cover every decoration on its line (drawline.c: "TODO:
-- line_attr should not take priority over decoration!"), so linehl hid the
-- added words. An ordinary highlight sits under word diff (priority 1000) and
-- over syntax (100). mdheading's tints are line highlights too, so an added
-- heading keeps its tint rather than the green.
--
-- Drawn at each redraw from gitsigns' current hunks, as gitsigns draws word
-- diff, so they always match what it shows: a toggle or a change of base
-- (review mode) recomputes the hunks without any event to repaint on.
local inline_ns = vim.api.nvim_create_namespace("inline_diff")
local inline_on = false
local added_rows = {} -- {first, last} 0-based, for the window being drawn

vim.api.nvim_set_decoration_provider(inline_ns, {
  on_win = function(_, _, buf)
    if not inline_on then return false end
    local hunks = require("gitsigns").get_hunks(buf)
    if not hunks then return false end
    added_rows = {}
    for _, hunk in ipairs(hunks) do
      if hunk.added.count > 0 then
        added_rows[#added_rows + 1] = { hunk.added.start - 1, hunk.added.start + hunk.added.count - 2 }
      end
    end
  end,
  on_line = function(_, _, buf, row)
    for _, rows in ipairs(added_rows) do
      if row >= rows[1] and row <= rows[2] then
        vim.api.nvim_buf_set_extmark(buf, inline_ns, row, 0, {
          end_row = row + 1, hl_group = "InlineDiffLine", hl_eol = true, priority = 500, ephemeral = true,
        })
        return
      end
    end
  end,
})

function M.inline_diff(value)
  local gs = require("gitsigns")
  inline_on = gs.toggle_deleted(value)
  gs.toggle_word_diff(inline_on)
  return inline_on
end

return M
