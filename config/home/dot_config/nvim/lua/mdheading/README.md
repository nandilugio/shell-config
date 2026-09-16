# mdheading

Markdown heading depth you can see.

Markdown encodes depth in character count, so `######` looks heavier than `#`
while meaning less. The visual weight runs backwards from the semantic weight,
and in a long or messy file headings are hard to pick out at all.

mdheading puts a background colour on each heading line — strongest at level 1,
fading to level 6:

```markdown
# Chapter          ← strongest tint
## Section
### Subsection
#### Detail        ← faintest
```

Depth reads at a glance, and headings become landmarks while scrolling. The
file on disk is unchanged: this is a display layer, one extmark per heading
line.

Pure Lua, no dependencies, no treesitter. Needs `termguicolors` for the
colours (`:set termguicolors?` to check — Neovim 0.12 turns it on when the
terminal supports it).

## The colour is derived, not configured

There is nothing to pick. mdheading takes one colour from your colourscheme and
blends it toward your `Normal` background in six steps, so the headings belong
to whatever theme you are using:

| scheme | level 1 → level 6 |
|---|---|
| `default` | teal, `#426c6f` → `#24252a` |
| `catppuccin` | blue, `#47577c` → `#2a2a38` |
| `retrobox` | olive, `#575820` → `#272727` |
| `sorbet` | green, `#416139` → `#22242d` |

The ramp is recomputed on `ColorScheme`, so switching theme switches the
headings with it.

**Why a ramp rather than the existing groups.** The six `@markup.heading.N`
groups are identical in most schemes — in Neovim's default they share one
foreground and `bold` — so there is no ordered scale to read. One has to be
computed.

**Why not blend the heading colour itself.** In the default scheme that colour
*is* `Normal`'s foreground, so blending it gives six greys and depth reads as
nothing. mdheading prefers the first source that is genuinely coloured,
trying `@markup.heading.1`, `@markup.heading`, `Directory`, `Function`,
`Special` and `Title` in turn. A monochrome scheme such as `quiet` correctly
gets greys, because that is what it has.

**The ramp moves along two axes**, because one is not enough to tell six levels
apart. Each level is both darker *and* less saturated than the one above, so
level 1 is vividly coloured and level 6 is nearly neutral grey — depth reads as
colour draining away, not as six samples of one colour.

The second axis is there because the first is capped. **How bright level 1 gets
is not a taste call:** a heading line still has text on it, so the tint may not
get bright enough to swallow it. Level 1 sits at the brightest blend that keeps
heading text at WCAG AA (4.5:1) in the default scheme, and past that it
degrades fast — one step further drops it to 3.6:1, and a little beyond that to
2.7:1, which is genuinely hard to read. With brightness pinned at both ends,
saturation is what buys the remaining separation, and it is free: desaturating
preserves luminance, so it costs no contrast at all.

Verified on every bundled scheme: the worst level anywhere is 3.4:1
(`catppuccin`), still above the 3:1 threshold for bold text, which headings
are. There is a regression test for it, so widening the range later fails the
suite rather than quietly making headings unreadable.

For scale, in the default scheme `CursorLine` sits 24 units from the background
and `Visual` 60: level 1 lands past `Visual`, level 4 near it, and level 6
below `CursorLine` but still present.

To override a level, set the group after your colourscheme loads. They are
defined with `default = true`, so yours wins:

```lua
vim.api.nvim_set_hl(0, "MdHeading1", { bg = "#3a5f62", bold = true })
```

## Install

A single module with no `plugin/` directory, so it loads the same way
everywhere: `require("mdheading")`. Calling `setup()` is optional.

**Inside a Neovim config** (how it is used here): keep `lua/mdheading/` in the
config and require it from `init.lua`.

```lua
require("mdheading").setup({ filetypes = { "markdown" } })
```

**As a standalone plugin**, once it lives in its own repository:

```lua
-- vim.pack (Neovim 0.12+)
vim.pack.add({ "https://github.com/<you>/mdheading.nvim" })
require("mdheading").setup()

-- lazy.nvim
{ "<you>/mdheading.nvim", ft = "markdown", opts = {} }
```

## Configuration

```lua
require("mdheading").setup({
  -- Filetypes coloured automatically. Default: { "markdown" }.
  filetypes = { "markdown", "rmd" },
})
```

The default is deliberately only `markdown`, matching mdtable: a filetype that
*contains* markdown — vimwiki, for instance — is not the same thing, and is
opted in here on purpose rather than assumed.

## Commands and functions

mdheading creates no keymaps. Bind what you use:

| Command | Function | Does |
|---|---|---|
| `:MdHeadingToggle` | `require("mdheading").toggle(buf?)` | Turn the colours on or off for a buffer |
| | `require("mdheading").enable(buf?)` | Turn them on |
| | `require("mdheading").disable(buf?)` | Turn them off |

`buf` defaults to the current buffer.

Turning it on or off for a buffer sticks: re-reading the file, or anything else
that re-runs filetype detection, leaves your choice alone. A buffer you have
not chosen for follows its filetype in both directions, so `:set ft=text` stops
the colouring and `:set ft=markdown` starts it.

```lua
vim.keymap.set("n", "<leader>uH", function() require("mdheading").toggle() end, { desc = "Markdown heading colours" })
```

State is the buffer variable `b:mdheading_on`, should a statusline want it.

## Behaviour

**A heading** is one to six `#` at the start of a line, followed by whitespace
or nothing, optionally after indentation or blockquote markers — so `> ## x` is
a heading inside a quote. `#nospace` is not a heading, and neither is
`#######` (seven), both per CommonMark 4.2.

**Fenced code blocks are skipped whole.** A README quoting markdown is full of
`#` lines that are not headings. Both ``` ``` ``` and `~~~` are tracked,
including the two CommonMark 4.5 rules: a closing fence carries nothing but its
marker (so ```` ```lua ```` opens a block but never closes one), and a backtick
fence's info string may not contain a backtick.

**The colours go away while typing** and come back when you leave insert mode.
Nothing forces this — a background colour, unlike mdtable's padding, shifts
nothing under the cursor — but one rule across both plugins is easier to hold
than two, and the buffer you are editing shows you what is actually in the file.

**Nothing runs when nothing changed.** Marks are placed for the whole buffer
and replaced when the text changes; a re-render that would change nothing costs
about 1 µs. A full render of 10,000 lines with 500 headings is 1.2 ms, and the
cost is in the scan, not the marks.

## Limits

mdheading finds headings by scanning lines, not by parsing markdown. What
follows from that:

- **Setext headings are not supported** — the `===` and `---` underline forms.
  They need lookahead, and the `---` form is ambiguous with a table separator
  and a thematic break. Use `#` and `##`.
- **A heading indented four or more spaces is still coloured.** At the top
  level of a document that is an indented code block and should be left alone,
  but the same indent inside a list item is a continuation. The two are
  indistinguishable without block context, and the second is commoner. Same
  call as mdtable.
- **The colour reaches the window edge,** not the end of the text, because that
  is what `line_hl_group` does. On a heading in a list or a blockquote the tint
  covers the markers too.
- **`termguicolors` is required.** Without it the groups are defined but the
  terminal shows no background. There is no `ctermbg` fallback: 256-colour
  approximations of six close shades are not six distinguishable colours.

## Why a second plugin rather than one markdown plugin

mdtable and mdheading share about forty lines of wiring — the enable/disable
scheme, the autocommand list, the fence tracking — and copying it was
deliberate. Two users is where a shared layer is premature: the interface would
be designed from one and a half examples. If a third arrives, extract it then.

`render-markdown.nvim` does headings and tables and callouts and lists
together. If heading depth turns out to be the last gap, two focused modules
win on size and churn; if three more wants appear, that is the moment to
reconsider rather than growing these one feature at a time.

## Tests

```
nvim -l lua/mdheading/test.lua
```

No framework. Exit code is 0 when all pass. 47 checks. Detection goes through
`heading_at()` and `scan()`; the drawing is checked by reading back the
extmarks actually placed, not by recomputing what they should be — mdtable's
suite once passed 109 green while the feature drew nothing, because it checked
its own arithmetic instead.

Two things `nvim -l` cannot reach, so the tests stop one step short: no UI is
attached, so nothing is painted, and insert mode cannot be entered without a
main loop. Both are checked at the layer below — the marks themselves, and the
gate that decides whether to place them.
