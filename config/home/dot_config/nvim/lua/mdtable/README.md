# mdtable

Readable markdown tables without touching the file.

A markdown table is only aligned if somebody padded it. Most are not, and a
ragged one is hard to read:

```markdown
| Name | Description | Status |
|---|:---:|---:|
| foo | a thing | ok |
| a much longer name | short | pending |
```

With mdtable, that file renders as:

```
| Name               |  Description   |  Status |
|--------------------|:--------------:|--------:|
| foo                |    a thing     |      ok |
| a much longer name |     short      | pending |
```

The file on disk is unchanged. Only the spaces the columns need are added: no
borders, no icons, no concealed syntax, nothing a correctly padded file would
not already contain.

Pure Lua, no dependencies, no treesitter. Neovim 0.10 or later (inline virtual
text).

## Two halves

| | | |
|---|---|---|
| **render** | automatic | Pads the columns on screen with inline virtual text; the buffer is untouched. On by default for `markdown`. |
| **align** | on demand | Pads the table under the cursor **in the buffer**, as one undo step. |

Both measure with the same code, so **the pipes land in the same columns either
way**. They differ in what they may do to get there: render may only *add*, so a
cell written `|   3 |` keeps those three spaces and gets the rest around them,
while align *rewrites* each cell from its trimmed text, putting it where the
alignment says.

So `,t` on a table that already looks aligned can still shift text, to its
canonical position. The columns do not move; what sits inside them does.

Padding is not drawn in the buffer you are typing in — it would shift the cursor
away from the character under it — and returns however you leave insert mode.

## Install

A single module with no plugin/ directory, so it loads the same way everywhere:
`require("mdtable")`. `setup()` is optional.

**Inside a config** (how it is used here): keep `lua/mdtable/` in the config and
require it from `init.lua`.

```lua
require("mdtable").setup({ filetypes = { "markdown" } })
```

**As a standalone plugin**, with `lua/mdtable/init.lua` at the repo root:

```lua
-- vim.pack (Neovim 0.12+)
vim.pack.add({ "https://github.com/<you>/mdtable.nvim" })
require("mdtable").setup()

-- lazy.nvim
{ "<you>/mdtable.nvim", ft = "markdown", opts = {} }
```

Lazy-loading on `ft = "markdown"` works: `setup()` enables buffers that are
already open, so the one that triggered the load is not missed.

## Configuration

```lua
require("mdtable").setup({
  -- Filetypes rendered automatically. Default: { "markdown" }.
  filetypes = { "markdown", "rmd" },
})
```

The default is only `markdown`. A filetype that *contains* markdown — vimwiki —
is not the same thing: notes are written more than read, and inline padding
moves the columns under the cursor. Such filetypes opt in deliberately.

## Commands and functions

mdtable creates no keymaps. Bind what you use:

| Command | Function | Does |
|---|---|---|
| `:MdTableToggle` | `require("mdtable").toggle(buf?)` | Turn padding on or off for a buffer |
| `:MdTableAlign` | `require("mdtable").align()` | Pad the table under the cursor in the buffer |
| | `require("mdtable").enable(buf?)` | Turn padding on |
| | `require("mdtable").disable(buf?)` | Turn padding off |

`buf` defaults to the current buffer. `align()` does nothing outside a table,
not even a warning, so it is safe to bind globally.

A choice sticks: re-reading the file, or anything else that re-runs filetype
detection, leaves it alone. A buffer you have not chosen for follows its
filetype both ways, so `:set ft=text` stops the padding and `ft=markdown` starts it.

```lua
vim.keymap.set("n", "<leader>um", function() require("mdtable").toggle() end, { desc = "Markdown table alignment" })
vim.keymap.set("n", "<LocalLeader>t", function() require("mdtable").align() end, { desc = "Align markdown table" })
```

Rendering state is the buffer variable `b:mdtable_on`, should a statusline
want it.

## Behaviour

**Column width.** As wide as the widest cell's content, and never narrower than
what a cell already occupies: virtual text can only add, so a column sized by
content alone would ask an over-padded cell to shrink. Minimum three, so the
separator always has room for a rule.

**Alignment markers** in the separator (`:---`, `:---:`, `---:`) are honoured
when padding cells. `align()` rebuilds the separator from them, so a ragged
`|:-|--:|` comes out even and a left `:--` keeps its colon.

**Existing whitespace** counts towards the padding on the side it is on. When it
fights the alignment — trailing blanks in a right-aligned cell — the text cannot
reach its edge, but the pipes still meet.

**Width is display width.** CJK, emoji and combining marks measure as the cells
they occupy. Tabs measure where they sit, reaching the next multiple of
`'tabstop'`; `align()` turns them into spaces, so what it writes survives being
read back under any `'tabstop'`.

It is the width of the *text*, not of the text in your window: a cell wider than
the window still measures what it is. (`'vartabstop'` is not honoured.)

**Escapes.** `\|` inside a cell is not a delimiter. `\\|` is an escaped
backslash followed by a delimiter that still splits.

**Fenced code blocks** (`` ``` `` and `~~~`, with the longer-fence-closes rule)
are skipped whole. A table shown as source in a code block is not aligned.

**Rows with more or fewer cells than the header** render on their own terms, so
their trailing pipes will not meet. `align()` normalises them: short rows gain
empty cells, long rows add a column, nothing is dropped.

**Indented and blockquoted tables** align in place; `align()` keeps the indent
and the `>` markers, so a table inside a list item or quote stays there.

**Nothing runs when nothing changed.** Padding is placed for the whole buffer
and replaced when the text or `'tabstop'` changes; a re-render that would change
nothing is effectively free. Prose costs almost nothing either — the work scales
with table cells, not with lines.

The dashes added to the separator use `@punctuation.special.markdown`, which is
what treesitter gives the real ones, so the rule is one colour with treesitter
and plain without.

## Limits

Tables are found by scanning lines, not parsing: a parser would add only
code-block awareness, which fence tracking covers, and a scan works where
treesitter cannot. What follows:

- **A table indented four or more spaces is aligned.** At top level that is an
  indented code block, but the same indent inside a list item is a continuation
  holding a real table. Indistinguishable without block context, and the second
  is far commoner.
- **A pipe inside any inline construct still separates cells** — `` `a|b` ``,
  `[[Page|Alias]]`, `<kbd>|</kbd>`. GFM specifies this: only a backslash escapes
  a delimiter, which is why Obsidian and others require `\|` in cells too.
- **Every row needs a leading pipe.** GFM also accepts `a | b` over `--|--`;
  mdtable does not, because "any line containing a pipe" as the definition of a
  row would turn prose into tables.
- **The separator must be the second row**, as the spec requires. A second
  `|---|---|` further down is an ordinary row whose cells contain `---`, which
  is how GitHub shows it too. Grid borders (`+---+---+`) are not markdown.
- **Two tables written with no blank line between them** are one run of rows.
- **Concealed text is measured at full width.** With `conceallevel` above zero
  and treesitter hiding `**` or link targets, such a cell renders short and its
  pipe lands early. No cheap way to know a concealed width.
- **One inline-padding layer at a time.** Another plugin that pads tables with
  virtual text (render-markdown.nvim) will double it.

## Why not a markdown rendering plugin

The problem is narrow: unaligned tables are unreadable, and conceal cannot fix
it — conceal removes characters, alignment needs them added. Rendering plugins
do this as one feature among many, at a size and churn out of proportion to the
need; generic aligners edit the buffer, which is wrong for a file you are only
reading.

## Tests

```
nvim -l lua/mdtable/test.lua
```

No framework; exit code is 0 when all pass. Detection goes through the scanner,
`align()` through the buffer it rewrites, and the padding by reading back the
extmarks it places and applying them to the buffer's own text.

`nvim -l` attaches no UI and runs no main loop, so nothing is painted and insert
mode cannot be entered. Both are checked one layer down: the marks themselves,
and the gate that decides whether to place them.

`torture.md` is the manual half — numbered cases to open and read down, covering
what the checks measure but cannot see: wide characters, tabs, a cell wider than
the window, and the cases that must *not* be padded. Both bugs found since the
suite went green came from reading it.

## Design notes

`DESIGN.md` is why it is built this way: what it was measured against, the
detection and width decisions, and the bugs that shaped the current wiring.
