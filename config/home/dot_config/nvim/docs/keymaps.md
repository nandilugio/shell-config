# Neovim keybinding map — design + rationale
nvim 0.12.5 · leader = `<Space>` · localleader = `,`
Status: the design as agreed, frozen at that point. What shipped is `lua/keymaps.lua`;
where it differs (no `gW` or `<leader>uf`; `]t`/`[t` left as Vim's tag motion; a `<leader>x`
lists namespace; treesitter text objects gone with the plugin) see `decisions.md`.
Companion research: `research-keybindings.md`.

## The rule
> `g` jumps · `gr` acts on symbols · `<leader>` opens tools · `[`/`]` iterate lists
> · `<C-w>` windows · F-keys bridge editors

Legend: ⬛ core (nvim default, never break) · 🟦 portable (≥3 other envs) · 🟨 mnemonic · ⚠️ shadows a builtin

## Design decisions (the "why" behind the why)
1. **Prefer the layer with most independent adopters, not the most authoritative one.**
   Core's `gr*` is authoritative but nvim-only and mnemonic-free. `gd`/`gy`/`gI` is
   Helix + LazyVim + AstroNvim + Zed + IdeaVim. Use both, for different jobs.
2. **Domain-keyed namespaces, never plugin-keyed.** `<leader>g` = git regardless of
   whether gitsigns or fugitive provides it. Plugin-keyed (`<leader>h`=harpoon) breaks
   when you swap plugins.
3. **No duplicate paths to the same action.** Earlier draft had `<leader>c*` aliasing
   `gr*`; dropped. Learning two bindings for one action is strictly worse, and the
   `<leader>c*` set has NO cross-distro consensus anyway (LazyVim `cr`, AstroNvim `lr`,
   NvChad `ra`, Helix `<spc>r`).
   EXCEPTION: `<C-]>`+`gd` both kept — they use *different back-buttons*
   (tag stack vs jumplist) and `<C-]>` works in help/man where `gd` doesn't.
4. **`g` is NOT an LSP namespace.** It's vim's "extended commands" junk drawer
   (`gg` `gU` `gJ` `gq` `gv` `gc` `gf` `gi` `g;` ...). The goto cluster are tenants.
   Corollary: DON'T add your own `g<letter>` maps — extend under `<leader>`.
   `gr*` IS 100% LSP — the one carve-out.
5. **Meta/Alt is unavailable** — tmux owns it (prefix M-a, M-hjkl panes, M-1..9 windows).
   So despite `:h map-which-keys` recommending Meta, the available space is
   `<leader>`, `g`, `[`/`]`, `z`, `<C-w>`, F-keys.

---

## 1 · Jump — `g` + letter
| Key | Action | Why |
|---|---|---|
| `gd` | Definition | 🟦 Universal: Helix, LazyVim, AstroNvim, Zed, **IdeaVim native**. Vim's own `gd`="Goto local Declaration" → LSP *upgrades* existing semantics |
| `gD` | Declaration | 🟦 Vim's `gD`=global declaration. Capital = wider scope |
| `gy` | T**y**pe definition | 🟦 Helix+LazyVim+AstroNvim+Zed. `t` taken by tags → `y` from "t**y**pe". Key is free |
| `gI` | **I**mplementation | 🟦 LazyVim+AstroNvim+Zed. ⚠️ shadows `gI` (insert col 1); capital chosen so lowercase `gi` (insert at last edit) survives |
| `gO` | **O**utline / doc symbols | ⬛ Core. Works in help/checkhealth/markdown too |
| `gW` | **W**orkspace symbols | 🟨 Capital = wider scope, parallel to `gO`. Free |
| `<C-]>` | Definition (tag stack) | 🟦 **Most portable key in existence**: vi→vim→nvim→Helix→Zed→IdeaVim→man. Free via `tagfunc` |
| `<C-t>` | Back (tag stack) | 🟦 Pairs with `<C-]>` |
| `<C-o>`/`<C-i>` | Back/fwd (jumplist) | ⬛ The `gd` back-button — distinct mechanism from `<C-t>` |
| `K` | Hover | ⬛ Core; universal across every vim emulation |

## 2 · Act on symbol — `gr` + letter  (100% LSP)
`gr` itself is arbitrary — it won **by elimination** (justinmk: "there is no alternative,
planned use-case for 'gr'"). No mnemonic exists. But every *suffix* is transparent, so you
memorize one prefix and get six. `cr` was tried first (mnemonic "refactor") and reverted:
`c` is an operator, so a `cr` prefix delays operator-pending mode by `timeoutlen`.

| Key | Action | Why |
|---|---|---|
| `grn` | Re**n**ame | ⬛ Core; also native in Zed vim mode |
| `gra` | Code **a**ction | ⬛ Core; normal + visual |
| `grr` | **R**eferences | ⬛ Core. Doubling = "current object" (cf. `dd`, `yy`, `gcc`) |
| `grx` | E**x**ecute codelens | ⬛ Core, new in 0.12 |
| `<C-s>` (insert) | Signature help | ⬛ Core |
| ~~`gri`~~ ~~`grt`~~ | — | Redundant with `gI`/`gy`; left as core defaults, not in active vocabulary |

Cost accepted: `gr` was virtual-replace (unused). Restore: `nnoremap <nowait> gr gr`

## 3 · Iterate — `[` / `]`
tpope's generative rule, verbatim from unimpaired.txt:
> "encoding always comes before decoding; `[` always comes before `]`"
Lowercase = step, **capital = first/last**. nvim 0.12 absorbed this into core and
credits tpope in the source.

| Key | Action | Why |
|---|---|---|
| `]d`/`[d` | **D**iagnostic | ⬛ Core + Helix + Zed |
| `]D`/`[D` | Last/first diagnostic | ⬛ Core; capital = extremum |
| `]e`/`[e` | **E**rror | 🟦 LazyVim + AstroNvim identical |
| `]w`/`[w` | **W**arning | 🟦 identical |
| `]c`/`[c` | **C**hange / git hunk | 🟦 **BUG FIX** — vim's builtin "change" motion + gitsigns default. A hunk IS a change |
| `]f`/`[f` | **F**unction | 🟦 Helix + LazyVim |
| `]t`/`[t` | **T**ype / class | 🟨 frees `]c` for hunks; Helix uses `]t` for this. ⚠️ shadows core tag-nav (rare) |
| `]q`/`[q`/`]Q`/`[Q` | **Q**uickfix | ⬛ Core (from unimpaired) |
| `]l`/`[l` | **L**oclist | ⬛ Core |
| `]b`/`[b` | **B**uffer | ⬛ Core |
| `]<Space>`/`[<Space>` | Blank line | ⬛ Core |
| `]n`/`[n`/`an`/`in` | Treesitter node | ⬛ New in 0.12 |

## 4 · Find — `<leader>f`
| Key | Action | Why |
|---|---|---|
| `<leader><leader>` | Buffers | 🟨 fastest key ↔ most frequent action |
| `<leader>ff` | **F**iles | 🟦 Spacemacs→LazyVim→AstroNvim→NvChad. Strongest leader convention that exists |
| `<leader>fr` | **R**ecent | 🟦 |
| `<leader>fg` | **G**rep | 🟦 |
| `<leader>fw` | **W**ord under cursor | 🟦 |
| `<leader>fh` | **H**elp | 🟦 |
| `<leader>fk` | **K**eymaps | 🟨 discovery hatch |
| `<leader>fd` | **D**iagnostics | 🟨 |
| `<leader>fs` | **S**ymbols | 🟨 |
| `<leader>/` | Grep project | 🟦 LazyVim; matches `/`=search intuition |

## 5 · Git — `<leader>g`
| Key | Action | Why |
|---|---|---|
| `<leader>gg` | Status / lazygit | 🟦 LazyVim + AstroNvim identical |
| `<leader>gs` | **S**tage hunk | 🟨 |
| `<leader>gr` | **R**eset hunk | 🟨 |
| `<leader>gp` | **P**review hunk | 🟨 |
| `<leader>gb` | **B**lame line | 🟨 |
| `<leader>gd` | **D**iff | 🟨 |
| `]c`/`[c` | Navigate hunks | 🟦 see §3 |

## 6 · Toggle — `<leader>u`
Spacemacs used `SPC t`; LazyVim moved to `u` (**u**i) to free `t` for test.
All letters below are LazyVim/AstroNvim-identical (the only 7 they agree on).

| Key | Action |
|---|---|
| `<leader>uw` | **W**rap |
| `<leader>us` | **S**pell |
| `<leader>ud` | **D**iagnostics |
| `<leader>uh` | Inlay **h**ints |
| `<leader>uf` | Auto**f**ormat |
| `<leader>ub` | **B**ackground |
| `<leader>ul` | **L**ine numbers |

Optional companion: tpope's `yo<x>` — 2 keystrokes, free namespace.
Mnemonic (verbatim): "The mnemonic for y is that if you tilt it a bit it looks like a switch."
Tradeoff: faster to type, invisible to which-key. `<leader>u` optimizes discovery, `yo` optimizes speed.

## 7 · Windows / buffers / splits
| Key | Action | Why |
|---|---|---|
| `<C-h/j/k/l>` | Focus window | 🟦 all four distros. **Pairs with tmux `M-hjkl` panes** = clean 2-level hierarchy |
| `<leader>-` | Split horizontal | 🟨 **matches tmux `bind -`**; `-` = horizontal divider |
| `<leader>|` | Split vertical | 🟨 **matches tmux `bind |`**; `|` = vertical divider |
| `<C-w>…` | Window namespace | ⬛ untouched — Helix copies it verbatim from vim |
| `<S-h>`/`<S-l>` | Prev/next buffer | 🟦 LazyVim (`]b`/`[b` also core) |
| `<leader>bd` | **B**uffer **d**elete | 🟦 LazyVim |

## 8 · Edit & format
| Key | Action | Why |
|---|---|---|
| `gq`/`gw` | Format motion | ⬛ core, LSP-backed via `formatexpr`. **Native in IdeaVim** |
| `=` | Indent motion | ⬛ core; works in vscode-neovim, VSCodeVim, Zed |
| `<leader>=` | Format buffer | 🟨 `=` is vim's own format operator |
| `gc`/`gcc` | Comment | ⬛ core. IdeaVim via `set commentary`; VS Code native |
| `<C-w>d` | Line diagnostic float | ⬛ core |

## 9 · F-key bridge
nvim binds ONLY `<F1>` — F2–F12 verified free on 0.12.5. `:h map-which-keys` recommends
them first. **The only layer surviving the macOS-Cmd / Windows-Ctrl split unchanged.**

| Key | Action | Why |
|---|---|---|
| `<F2>` | Rename | 🟦 VS Code + Zed + Visual Studio |
| `<F12>` | Definition | 🟦 VS Code + VS + Zed + Sublime — strongest single binding in the industry |
| `<S-F12>` | References | 🟦 VS Code + Visual Studio |
| `<F5>`/`<F9>`/`<F10>`/`<F11>` | debug/breakpoint/step over/step into | 🟦 VS Code + VS + Zed; AstroNvim does this |

Caveat: JetBrains is the systematic outlier (`F2`=next error, `F7`/`F8`=step).

## 10 · Reserved & structural
| Key | Purpose | Why |
|---|---|---|
| `<leader>o` | **Yours alone** | 🟨 Spacemacs' best convention: guaranteed never to collide |
| `<LocalLeader>`=`,` | Filetype-specific | 🟨 Spacemacs `SPC m`. Home for Ruby/markdown/vimwiki keys |
| `-` | **leave free** | 🟨 nvim 0.13's builtin explorer claims it (guards politely) |
| `g`+new letters | **don't extend** | ⚠️ crowded with real vim commands |

---

## Migration from current config
| | Now | New | Reason |
|---|---|---|---|
| Find | `<leader>s*` | `<leader>f*` | `f`=find strongest cross-distro convention |
| Git | `<leader>h*` | `<leader>g*` | `g`=git universal; `h` collides w/ help/harpoon |
| Toggle | `<leader>t*` | `<leader>u*` | frees `t` for test |
| Format | `<leader>f` | `<leader>=` | `<leader>f` needed for find |
| Class nav | `]c`/`[c` | `]t`/`[t` | **bug fix** — `]c` is change motion + gitsigns hunks |
| Jumps | `grd`/`grD` via telescope | `gd`/`gD`/`gy`/`gI` | portability |
| F-keys | unused | F2/F12/S-F12/F5/F9-F11 | free; only cross-editor-portable layer |
| Diag list | `<leader>q` | `<leader>fd` | folds into find namespace |

**Unchanged (already correct):** `<C-hjkl>` · blink `preset="default"` (mirrors vim
`ins-completion`) · `<Esc>` clears hlsearch · `grn`/`gra`/`grr`/`gO` · `]f`/`[f` ·
`af`/`if`/`ac`/`ic` textobjects · `;`/`,` repeat

## Decided
1. `<leader>s` -> `<leader>f` — cut clean, no transition alias.
2. vimwiki moved to `<leader>ow`, and its own `<leader>w*` mappings are
   suppressed via `vim.g.vimwiki_key_mappings = { global = 0 }`, which is what
   was quietly claiming the window namespace.
