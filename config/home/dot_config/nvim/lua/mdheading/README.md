# mdheading

Markdown heading depth you can see.

Markdown encodes depth in character count, so `######` looks heavier than `#`
while meaning less: the visual weight runs backwards from the semantic one, and
in a long file headings are hard to pick out at all.

mdheading puts a background colour on each heading line, strongest at level 1
and fading to level 4, which `#####` and `######` share:

```markdown
# Chapter          ← strongest tint
## Section
### Subsection
#### Detail        ← faintest
```

The file on disk is unchanged: a display layer, one extmark per heading line.

Pure Lua, no dependencies, no treesitter. Needs `termguicolors`, which Neovim
0.12 turns on when the terminal supports it.

## The colour is derived, not configured

Nothing to pick: one colour from your colourscheme, blended toward your
`Normal` background, so the headings belong to whatever theme you use.

The hue comes from the scheme, so `default` gives teal, `catppuccin` blue,
`retrobox` olive and `sorbet` green, each fading toward that scheme's own
background. A monochrome scheme such as `quiet` gets greys, correctly.

The ramp is recomputed on `ColorScheme`, so switching theme switches the
headings with it.

**A ramp has to be computed**, because the six `@markup.heading.N` groups are
identical in most schemes — in Neovim's default they share one foreground and
`bold` — so there is no ordered scale to read. The source is the first genuinely
coloured group of `@markup.heading.1`, `@markup.heading`, `Directory`,
`Function`, `Special`, `Title`; blending the heading colour itself would give
six greys, since in the default scheme it *is* `Normal`'s foreground.

**Each level is both darker and less saturated** than the one above, so depth
reads as colour draining away rather than as samples of one colour. Brightness
alone is capped at both ends — the background below, and above it the fact that
a heading line still has text on it — so saturation carries the rest, which it
does for free: desaturating preserves luminance and costs no contrast.

**The deepest levels share one shade**, which is what makes the rest legible:
the same range over fewer steps puts more distance between them, and six was too
close to tell at a glance. `####` is common enough to miss, so this is a real
cost, taken because a distinction too fine to see is not one. `DISTINCT_LEVELS`
in `init.lua` trades it back.

**A couple of bundled schemes fall under the contrast floor** at this
brightness, their accent being lighter against their background. They are named
in the test with the ratio measured, rather than quietly excused, so the check
still fails for any other scheme. Raising `BLEND_FIRST` clears them, at some
cost in separation.

`DESIGN.md` has the measurements and the levers tried and rejected.

To override a level, set the group after your colourscheme loads. They are
defined with `default = true`, so yours wins:

```lua
vim.api.nvim_set_hl(0, "MdHeading1", { bg = "#3a5f62", bold = true })
```

## Install

A single module with no `plugin/` directory, so it loads the same way
everywhere: `require("mdheading")`. Calling `setup()` is optional.

**Inside a config** (how it is used here): keep `lua/mdheading/` in the config
and require it from `init.lua`.

```lua
require("mdheading").setup({ filetypes = { "markdown" } })
```

**As a standalone plugin**, with `lua/mdheading/init.lua` at the repo root:

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

The default is only `markdown`, matching mdtable: a filetype that *contains*
markdown — vimwiki — is not the same thing, and opts in deliberately.

## Commands and functions

mdheading creates no keymaps. Bind what you use:

| Command | Function | Does |
|---|---|---|
| `:MdHeadingToggle` | `require("mdheading").toggle(buf?)` | Turn the colours on or off for a buffer |
| | `require("mdheading").enable(buf?)` | Turn them on |
| | `require("mdheading").disable(buf?)` | Turn them off |

`buf` defaults to the current buffer.

A choice sticks: re-reading the file, or anything else that re-runs filetype
detection, leaves it alone. A buffer you have not chosen for follows its
filetype both ways, so `:set ft=text` stops the colouring and `ft=markdown`
starts it.

```lua
vim.keymap.set("n", "<leader>uH", function() require("mdheading").toggle() end, { desc = "Markdown heading colours" })
```

State is the buffer variable `b:mdheading_on`, should a statusline want it.

## Behaviour

**A heading** is one to six `#` at the start of a line followed by whitespace or
nothing, optionally after indentation or blockquote markers, so `> ## x` counts.
Per CommonMark 4.2, `#nospace` and `#######` do not.

**Fenced code blocks are skipped whole** — a README quoting markdown is full of
`#` lines that are not headings. Both ``` ``` ``` and `~~~` are tracked, with the
two CommonMark 4.5 rules: a closing fence carries only its marker (so
```` ```lua ```` opens a block but never closes one), and a backtick fence's
info string may not contain a backtick.

**The colours go away while typing** and come back on leaving insert mode.
Nothing forces this — unlike mdtable's padding, a background colour shifts
nothing — but one rule across both plugins is easier to hold than two.

**Nothing runs when nothing changed.** Marks are placed for the whole buffer and
replaced when the text changes; a re-render that would change nothing is
effectively free. Even a large file full of headings renders in a couple of
milliseconds, and the cost is in the scan, not the marks.

## Limits

Headings are found by scanning lines, not parsing. What follows:

- **Setext headings are not supported** — the `===` and `---` underline forms.
  They need lookahead, and `---` is ambiguous with a table separator and a
  thematic break.
- **A heading indented four or more spaces is still coloured.** At top level
  that is an indented code block, but the same indent inside a list item is a
  continuation. Indistinguishable without block context; same call as mdtable.
- **The colour reaches the window edge,** not the end of the text, because that
  is what `line_hl_group` does.
- **`termguicolors` is required.** Without it the groups are defined but the
  terminal shows no background. No `ctermbg` fallback: 256-colour approximations
  of shades this close are not distinguishable.

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

No framework; exit code is 0 when all pass. Detection goes through
`heading_at()` and `scan()`; the drawing by reading back the extmarks actually
placed, never by recomputing what they should be — mdtable's suite once passed
109 green while the feature drew nothing.

`nvim -l` attaches no UI and runs no main loop, so nothing is painted and insert
mode cannot be entered. Both are checked one layer down: the marks themselves,
and the gate that decides whether to place them.

`torture.md` is the manual half. It exists because the question this plugin has
to answer, whether the levels read apart at a glance, is one no assertion can
settle: the ramp was narrowed to fewer distinct shades by looking at that file,
not at a number.

## Design notes

`DESIGN.md` is why it is built this way: how the ramp was derived and measured,
why it ends at four levels, and the levers rejected on the way there.
