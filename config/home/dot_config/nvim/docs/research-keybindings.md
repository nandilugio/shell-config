# Verified findings (from primary sources)

## nvim 0.11.1 core defaults (`:h default-mappings`, verified locally)
- gr prefix (LSP): grn rename, gra code action (n+x), grr references, gri implementation, gO document symbols
- i_CTRL-S = signature help; K = hover (unless keywordprg customized)
- ]d/[d diagnostics, ]D/[D first/last  <-- OVERRIDES vim's classic [d = show #define
- ]q/[q/]Q/[Q quickfix; ]l/[l loclist; ]t/[t tags; ]a/[a args; ]b/[b buffers; [<Space>/]<Space> blank lines
- <C-W>d = show diagnostic in float
- gc/gcc comment (nvim 0.10+, from vim-commentary)
- LSP sets 'tagfunc' => <C-]>, <C-w>], g<C-]> work as goto-definition for free
- LSP sets 'formatexpr' => gq formats via LSP
- LSP sets 'omnifunc' => i_CTRL-X_CTRL-O completion

## Namespace semantics (vim docs)
- `g{char}` = "extended commands" (index.txt:389) -- documented namespace
- `gd` = "Goto local Declaration" (heuristic text search, pattern.txt). LSP `gd` is an UPGRADE of existing semantics, not a hijack.
- `gD` = goto global declaration (file-scope search)
- `gr` was vim's "virtual replace" operator -- nvim SACRIFICED it for the gr* LSP namespace
- `[`/`]` = "square bracket commands"; `[` backward/previous, `]` forward/next; CAPITAL = first/last
- Leader defaults to `\`; vim documents NO convention for leader contents. Space-as-leader = pure community convention.
- `:h map-which-keys` officially suggests: function keys F2-F12, Meta keys, `_` and `,` prefixes, <Leader>
- ONLY <F1> is bound in nvim. F2-F12 entirely FREE. (verified: grep index.txt)

## vim-unimpaired (tpope) -- the systematic bracket design
- [x/]x prev/next, [X/]X first/last  (a=args b=buffer l=loclist q=quickfix t=tag f=file n=conflict)
- [<Space>/]<Space> blank lines; [e/]e exchange lines
- yo<x> TOGGLE option (mnemonic: "y tilted looks like a switch"); [o<x>=on, ]o<x>=off
- Documented mnemonic: "encoding always comes before decoding; [ always comes before ]"
- nvim 0.11 ABSORBED the next/prev bracket half into core, but NOT yo toggles

## Helix (deliberate redesign; credits unimpaired explicitly)
- g = goto (jumps): gd def, gD decl, gy type def, gr references, gi impl, gg/ge file start/end, gh/gl line start/end, gs first non-blank, gt/gc/gb screen top/center/bottom, gn/gp buffers, ga alternate file
- Space = pickers/actions: <spc>f file, <spc>F cwd, <spc>b buffers, <spc>s doc symbols, <spc>S workspace symbols,
  <spc>d/<spc>D diagnostics, <spc>r rename, <spc>a code action, <spc>k hover, <spc>/ global search, <spc>? command palette,
  <spc>c comment, <spc>y/<spc>p clipboard, <spc>j jumplist, <spc>g changed files, <spc>' last picker, <spc>w window mode
- [/] unimpaired-style: ]d/[d diag, ]f/[f function, ]t/[t type, ]a/[a argument, ]c/[c comment, ]g/[g change(hunk), ]T/[T test
- <C-w> window mode kept VERBATIM from vim (h/j/k/l/v/s/q/o/H/J/K/L)
- CLEAN SPLIT: g = navigate/jump, Space = act/pick. Editing model differs (selection->action) so only nav layer transfers.

## Zed vim mode (assets/keymaps/vim.json) -- KEY DATA POINT
Ships BOTH conventions simultaneously:
- Helix/classic style: gd definition, gD declaration, gy type def, gI implementation, gh hover, gs/gO outline, gS project symbols, g. code actions, gA references
- nvim 0.11 style: grn rename, grr references, gri implementation, gra code action
- Brackets: ]d/[d diagnostics, ]c/[c git hunks, [<space>/]<space> blank lines
- <C-]> goto definition; K hover; <C-w>d / <C-w>] goto-def in split
=> A modern editor independently chose the UNION of nvim-core + Helix conventions.

## Distro / dotfile observations (my own reads)
- kickstart.nvim: follows nvim 0.11 core (grn/gra/grr/gri/gO/gW, grd/grD added via telescope), <leader>s* search namespace, <leader>h git hunk, <leader>t toggle, <leader>f format, <leader><leader> buffers, <C-hjkl> window focus
- NvChad: OUTLIER. classic gd/gD (pre-0.11), <leader>f* find namespace, flat non-namespaced leader, <leader>/ comment, <C-n> filetree, <tab>/<S-tab> buffers
- ThePrimeagen: HIGHLY personal, NOT a standard. <leader>pv netrw, <leader>vrn rename, <leader>vca code action, <leader>pf/<C-p> files, <leader>ps grep,
  J/K visual line move, <leader>y "+y clipboard, <leader>p "_dP, <C-d>zz/<C-u>zz, nzzzv, Q disabled, <leader>f format, <C-f> tmux-sessionizer.
  NOTE: his [d/]d are INVERTED (]d goes prev) - a bug, evidence that personal configs != standards.
- folke (LazyVim author) personal dotfiles: almost NO custom keymaps -> he lives on LazyVim defaults. Strong signal LazyVim ~= de-facto standard.
- blink.cmp 'default' preset deliberately mirrors vim's ins-completion: <C-n>/<C-p> select, <C-y> accept, <C-e> abort, <C-space> menu/docs. Max-standard choice.

## Cross-editor consensus (agent-verified)
Tier 1 universal: F12 definition, Shift+F12 references, F2 rename, F5/F9/F10/F11 debug, Ctrl+Space complete, Ctrl+Shift+F find-in-files, Ctrl+/ comment
Tier 2 (one defector): Ctrl+. code action (JetBrains: Alt+Enter), Ctrl+P file finder, Ctrl+Shift+P palette, F8/Shift+F8 next/prev error, Ctrl+D add cursor
Tier 3 no consensus: declaration, TYPE DEFINITION (VS Code ships NO default!), peek, hover, format, splits, terminal, git hunks
- F-keys are the ONLY layer that survives the macOS Cmd vs Windows Ctrl split unchanged => most portable
- JetBrains is the systematic outlier (F2=next error not rename, F7/F8 step, Cmd+B definition, Alt+Enter action)
- VSCodeVim binds almost no LSP keys -> users fall back to host F-keys

## LazyVim 16 vs AstroNvim 6 (agent-verified, spot-checked by me)
### The g* navigation layer is where they AGREE (and it matches Helix + Zed):
gd definition | gD declaration | gy type def | gI implementation | gK signature help
(LazyVim adds gr=references; AstroNvim puts references on <leader>lR)
Also agree: <C-hjkl> windows, ]b/[b buffers, gco/gcO, ]e/[e errors, ]w/[w warnings,
<leader>xq/xl quickfix/loclist, <leader>uf/uF/uh/ud/ub/uw/us toggles, <leader>gg lazygit,
<leader>db/dc/di/du DAP, j/k -> gj/gk when count==0

### Where they DISAGREE: the leader namespace (almost entirely)
LazyVim: c=code(LSP actions) f=find g=git s=search u=ui/toggle x=diag/qf w=window b=buffer d=debug t=test q=quit
AstroNvim: l=language(LSP actions) f=find g=git u=ui/toggle x=lists t=terminal b=buffer d=debug S=session p=packages
  + single-key: w=save q=quit c=close-buffer n=new e=explorer /=comment R=rename-file
=> LSP *navigation* (g*) is standardized; LSP *actions* (rename/code-action/format) are NOT.
=> <leader>u toggle namespace: both use `u` but nearly every letter differs. Only uf/uF/uh/ud/ub/uw/us agree.

### CRITICAL: LazyVim kills nvim's gr* namespace  [VERIFIED by me at lsp/init.lua:81]
  { "gr", vim.lsp.buf.references, desc = "References", nowait = true }
nowait=true => gr fires immediately => grn/gra/gri/grt become UNTYPEABLE.
Neither distro ever explicitly binds grn/gra/grr/gri/grt/gO (grepped: zero hits).
AstroNvim is the more conservative: leaves ]d/[d, ]q/[q, K, s, and gr*/gO genuinely reachable.
LazyVim overrides more: ]d/[d, ]q/[q, K, s, <C-s>, ]t/[t, and shadows gr*.

### Both repurpose ]t/[t away from the built-in tag motion (LazyVim=TODO, AstroNvim=tab). They disagree on replacement.
### AstroNvim binds F5/F6/F9/F10/F11 for DAP (VS Code style). LazyVim binds NO function keys.

## CORRECTIONS to common folklore (agent-verified against nvim PRs; I re-verified on this machine)
1. **`g` does NOT mean "goto".** gpanders (nvim maintainer), PR #28650:
   "The g prefix does not mean goto. gs, gp, ga, g8, g?, gJ, gu, gU, gv, gq, gw, and g~ are all counter examples."
   Best characterization: `g` = "extra/extended namespace". (index.txt:389 "extended commands")
2. **`gr` does NOT mean "refactor".** "Refactor" was the mnemonic for the ABANDONED `cr*` prefix (PR #28500,
   reverted #28649 because c-prefixed normal maps delay operator-pending by timeoutlen, breaking ModeChanged plugins).
   `gl*` was proposed next (#28650), dropped because `gl` was wanted for a future "align".
   **`gr` won by ELIMINATION**: justinmk: "there is no alternative, planned use-case for 'gr'." Builtin gr (virtual
   replace) deemed "rarely useful". => The gr* namespace has NO mnemonic. This is a real argument against relying on it for memory.
3. **Why gr is a PREFIX not just references** (gpanders): "If we make gr map to references, we cannot use gr as a prefix
   for anything else... Finding unused default mappings is extremely difficult. The goal is a better out-of-the-box
   experience for NEW users... power users are free to ignore the defaults." => Defaults are aimed at beginners, explicitly.
4. **No `grd`.** justinmk: "because gd and ctrl-] literally already exist for that purpose."
   Issue #28476 "map gd to CTRL-]" was CLOSED/REJECTED (2024-05-25).
   => nvim's official position: **go-to-definition is `<C-]>`/`gd`, served via 'tagfunc'.**
5. **Timeline correction**: gr* shipped in **0.11.0**, NOT 0.10. `grt` (type def) landed only in **0.11.3**.
   [VERIFIED on this machine: nvim 0.11.1 has grn/gra/grr/gri/gO but NO grt]
   `grx` (codelens) is 0.12/nightly only.
6. gr* maps are set UNCONDITIONALLY at startup (not on LspAttach) - deliberate, so behavior doesn't vary by attach state.
7. Official escape hatch (`:h gr-default`): `nnoremap <nowait> gr gr` restores builtin virtual-replace.
8. **`[`/`]` has NO documented prose semantic** - index.txt 2.3 is a bare table. The prev/next pattern holds
   for all builtin *pairs*, but the include-search family ([d/[i/[D/[I) differs on a start-of-file vs from-cursor axis.
   Exceptions: [p/]p (indent-adjusted put, not directional), [f/]f (both = gf).
9. **`z` prefix**: no documented meaning either. Clusters: folds / scrolling+positioning / spelling(zg zw z=) / block-paste.
10. `Q` in nvim = repeat last recorded register (vim's Ex mode moved to gQ).
11. `:h map-which-keys` is inherited VERBATIM from vim, never updated for nvim defaults - it doesn't know about gr* or brackets.
    No nvim guidance exists for plugin authors on keyspace reservation.
12. Space-as-leader appears NOWHERE in nvim docs. Pure community convention. Default leader is `\`.

## Environment facts (this machine)
- nvim 0.11.1 installed; brew stable is 0.12.5 -> upgrade recommended (gains grt type-def from 0.11.3, grx codelens in 0.12)
- Config: single 38KB init.lua, kickstart.nvim-derived, mapleader=" "
- Plugins: telescope(+fzf,ui-select), blink.cmp, LuaSnip, mason*, nvim-lspconfig, treesitter(+textobjects),
  gitsigns, which-key, mini.nvim, todo-comments, lazydev, vimwiki, save.nvim, render-markdown, fidget, guess-indent
- Current leader groups: b=Buffer s=Search t=Toggle h=Git Hunk w=vimWiki
- Follows nvim 0.11 core: grn/gra/grr/gri/grD/grd/grt(via telescope)/gO/gW  <-- already modern
- <C-hjkl> window focus; <Esc> clears hlsearch; <leader>q diagnostic loclist; <leader>f format
- blink preset="default" => mirrors vim ins-completion (<C-n>/<C-p>/<C-y>/<C-e>/<C-space>) = maximally standard

## COLLISION FOUND in user's current config [verified]
init.lua:554 maps ]c/[c to treesitter @class.outer.
But ]c/[c is vim's BUILT-IN "cursor N times forward/backward to start of change" (diff.txt:236, index.txt),
and gitsigns uses ]c/[c for hunks by default (a hunk IS a change - semantic fit).
=> User's class mapping shadows both. LazyVim resolves by putting hunks on ]h/[h and class on ]c;
   Helix puts hunks on ]g and class on ]t. Either is fine, but the current setup silently loses diff/hunk nav.
Also: user's ]f/[f for function shadows unimpaired's [f/]f (= gf, next/prev file in dir) - low cost, widely done
   (Helix and LazyVim both use ]f for function).

## User's WIDER environment (constrains the design)
- ~/.shell-config is a chezmoi-style dotfile repo: vimrc, tmux.conf, gitconfig, psqlrc, pryrc + dot_config/nvim
- **plain vimrc ALSO uses `let mapleader = " "`** and `nmap \ <leader>` (keeps backslash as alias). Consistent already.
  vimrc has <leader>, edit vimrc, <leader>r reload, <leader>sudo
- **tmux prefix = M-a**, and tmux owns a LOT of Meta: M-hjkl panes, M-arrows panes, M-1..9 windows,
  M-PageUp/Down windows, S-M-* move.
  => **Meta/Alt is NOT available for nvim mappings** despite `:h map-which-keys` suggesting it. Important constraint.
- tmux splits: `|` and `\` horizontal, `_` and `-` vertical  => same mnemonic as LazyVim <leader>| / <leader>-
  and AstroNvim bare | / \. CONSISTENT: | = vertical divider, - = horizontal divider.
- tmux mode-keys vi, status-keys vi => vi motions in copy mode
- nvim uses <C-hjkl> for windows, tmux uses M-hjkl for panes => clean 2-level hierarchy already. Keep it.
- User is a Ruby dev (pryrc, RubyMine mentioned) => IdeaVim is a first-class target for transfer.

## Spacemacs = the origin of the leader-namespace idea [verified from repo docs]
DOCUMENTATION.org:250: "Key bindings are organized using mnemonic prefixes like ~b~ for buffer,
  ~p~ for project, ~s~ for search, ~h~ for help, etc..."
DOCUMENTATION.org:276: "*Lower the risk of RSI* by heavily using the space bar instead of modifiers."
  => the ACTUAL documented reason for space-as-leader: ergonomics/RSI + thumb use, not "space is unused".
CONVENTIONS.org formalizes things nvim never did:
  - SPC o and SPC m o are RESERVED FOR THE USER (no layer may use them)  <-- great idea, steal this
  - SPC m = current major mode (filetype-local) == nvim's <LocalLeader> concept
  - SPC t / SPC T / SPC C-t = global toggles; SPC m T = major-mode toggles
  - "." suffix = transient/hydra state (e.g. SPC w . = window transient state)
  - SPC m g = "go to" sub-prefix (mga alternate file, mgb back, mgu usage, mgi imports, mgt test)
  - C-j / C-k for vertical movement inside insert-state pickers  <-- matches AstroNvim's blink C-j/C-k
  - "Similar functionalities have the same key binding everywhere, thanks to a clearly defined set of conventions"
=> Spacemacs is the only ecosystem with a WRITTEN keybinding constitution. nvim distros inherited the
   letters but not the discipline (hence LazyVim vs AstroNvim divergence).

## tmux.conf detail (user is an avid tmux user - compatibility is a stated goal)
- copy-mode-vi is faithfully vim: v begin-selection, V select-line, C-v rectangle-toggle,
  y copy-selection-and-cancel, Y copy-end-of-line, Escape cancel
  => user ALREADY applies the transferability principle to tmux. Good precedent to extend.
- NO vim-tmux-navigator: nvim <C-hjkl> and tmux M-hjkl are deliberately SEPARATE modifiers.
  This is a defensible explicit-level-switch design (vs seamless). Keep unless user wants seamless.
- Splits |/\ = vertical, _/- = horizontal. Mirrors LazyVim <leader>| / <leader>- and AstroNvim | / \.
  => RECOMMEND: use <leader>| and <leader>- in nvim to match tmux muscle memory exactly.
- tmux `bind s choose-tree` (session picker), `bind S new-session`, `bind m` mark pane
- M-0 / bind 0 = move-window -r (renumber)
=> Meta belongs to tmux. nvim should stay on <leader>, g, [, ], z, <C-w>, and F-keys.

## MNEMONICS - the verified ones (this is the transferable memory layer)
[VERIFIED verbatim in tpope_vim-unimpaired/doc/unimpaired.txt]
- L95: "The mnemonic for y is that if you tilt it a bit it looks like a switch."  (NOT "yo, toggle this" - folk etymology)
- "Mnemonic: encoding always comes before decoding; '[' always comes before ']'."  <-- THE generative rule
- "x as in crosshairs" for yox (cursorline+cursorcolumn)
- YOPO "You Only Paste Once" - no paste toggle provided because a toggle for single-action state is wrong
- vim-surround: "It's a stretch, but a good mnemonic for ys is 'you surround'"
- fugitive [m/]m: "'/' appears in filenames, 'm' appears in 'filenames'" <- even tpope hits namespace exhaustion
=> tpope's y = "meta-operator" letter (yo toggle, ys surround), NOT yank.

[VERIFIED from nvim PRs]
- `g` does NOT mean goto (gpanders, counter-examples gs gp ga g8 g? gJ gu gU gv gq gw g~)
- `gr` has NO mnemonic - won by elimination. justinmk: "there is no alternative, planned use-case for 'gr'"
- grr's doubled r follows vim's operator-doubling pattern (dd, yy, gcc, gUU) = "apply to default/current object"
- gpanders: owning a namespace costs one redundant-looking key (grr) but buys 3 (grn/gra/gri)

[VERIFIED from Spacemacs source]
- SPC chosen for RSI/thumb/no-modifier reasons (DOCUMENTATION.org), origin commit 9d115ec 2013-01-24
  (agent corrected my 2014 -> Spacemacs repo 2012, SPC-leader Jan 2013)
- <Space> is a duplicate of l and <Right> in vim (motion.txt) - 3 bindings for 1 motion => free to claim

## nvim core's PHILOSOPHY (matters for how much to lean on defaults)
justinmk #33740: "I'm really not interested in catering to people that like some of the defaults, but not others."
justinmk: "distros like lazyvim, astrovim, nvchad ... provide inner-platforms to 'disable mappings' in a
  different way, are totally confusing people."
gpanders: "The goal is to provide a better out of the box experience for NEW and less experienced users...
  Experienced and power users are free to ignore the defaults."
=> Core defaults are BEGINNER-oriented and deliberately unconfigurable-by-family. Escape hatch is :mapclear
   or per-key vim.keymap.del. There will be NO standard. Design accordingly.
Rejected alternatives for LSP prefix: <F2>/<F3>/<F4> ("absolutely out of the question" - VonHeikemen),
  gl (owned by vim-lion), cr (c is an operator -> breaks operator-pending timing), gd (tagfunc already does it better)

## Two competing NAMESPACE PHILOSOPHIES (important design fork for the user)
(a) DOMAIN-keyed (Spacemacs, LazyVim, AstroNvim): <leader>b = buffers regardless of which plugin provides them.
    Survives plugin churn. Requires discipline.
(b) PLUGIN-keyed (most personal configs, e.g. <leader>h = harpoon): easy to write, leaks implementation
    into interface. Swap the plugin and muscle memory breaks.
=> RECOMMEND (a) for the stated goal (transferable memory).

## unimpaired vs LazyVim toggle split - a real tradeoff, not arbitrary
unimpaired `yo<x>`: optimizes TYPING SPEED once learned; invisible to which-key discovery
LazyVim `<leader>u<x>`: optimizes DISCOVERY before learning; slower to type
(no sourced rationale from folke for the switch; this is the structural explanation)

## which-key takes NO position on namespaces (README examples are illustrative, not prescriptive)
mini.clue explicitly refuses to prescribe; ships gen_clues only for BUILT-IN namespaces (g, z, <C-w>, marks, registers)
=> which-key made deep namespaces VIABLE, which removed the pressure to standardize them. Explains
   top-level convergence + sub-level divergence.
