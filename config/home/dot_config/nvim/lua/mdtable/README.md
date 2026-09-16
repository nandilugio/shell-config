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

Reading and writing are different problems, so there are two operations:

| | | |
|---|---|---|
| **render** | automatic | Pads the columns on screen with inline virtual text. The buffer is untouched, so it is safe on anything you are only reading. On by default for `markdown`. |
| **align** | on demand | Pads the table under the cursor **in the buffer** — a real, undoable edit, for files you own. One undo step. |

Both measure with the same code, so **the pipes land in the same columns
either way**. They differ in what they are allowed to do to get there:

- **render may only add.** Whatever you wrote stays where it is, so a cell
  written `|   3 |` keeps those three spaces and gets the rest of its padding
  around them. That is what makes it safe on a file it must not touch.
- **align rewrites.** Each cell is rebuilt from its trimmed text, so the text
  lands where the alignment says rather than wherever stray whitespace left it.

So pressing `,t` on a table that already looks aligned can still shift text —
to its canonical position. The columns do not move; what sits inside them does.
That is `,t` doing its job: it is a formatter, and the display is not.

Padding is not drawn in the buffer you are typing in: it shifts the real
columns, so the cursor would sit at a different screen column than the
character under it. It comes back however you leave insert mode.

## Install

mdtable is a single module with no plugin/ directory, so it loads the same way
everywhere: `require("mdtable")`. Calling `setup()` is optional.

**Inside a Neovim config** (how it is used here): keep `lua/mdtable/` in the
config and require it from `init.lua`.

```lua
require("mdtable").setup({ filetypes = { "markdown" } })
```

**As a standalone plugin**, once it lives in its own repository with
`lua/mdtable/init.lua` at the root:

```lua
-- vim.pack (Neovim 0.12+)
vim.pack.add({ "https://github.com/<you>/mdtable.nvim" })
require("mdtable").setup()

-- lazy.nvim
{ "<you>/mdtable.nvim", ft = "markdown", opts = {} }
```

Lazy-loading on `ft = "markdown"` works: the padding is drawn on the next
redraw, so the buffer that triggered the load gets it with no catching up.

## Configuration

```lua
require("mdtable").setup({
  -- Filetypes rendered automatically. Default: { "markdown" }.
  filetypes = { "markdown", "rmd" },
})
```

The default is deliberately only `markdown`. A filetype that *contains*
markdown — vimwiki, for instance — is not the same thing: notes are written
more than read, and inline padding moves the columns under the cursor. Such
filetypes are opted in here, on purpose, rather than assumed.

## Commands and functions

mdtable creates no keymaps. Bind what you use:

| Command | Function | Does |
|---|---|---|
| `:MdTableToggle` | `require("mdtable").toggle(buf?)` | Turn padding on or off for a buffer |
| `:MdTableAlign` | `require("mdtable").align()` | Pad the table under the cursor in the buffer |
| | `require("mdtable").enable(buf?)` | Turn padding on |
| | `require("mdtable").disable(buf?)` | Turn padding off |

`buf` defaults to the current buffer. `align()` does nothing outside a table —
not even a warning — so it is safe to bind globally.

Turning it on or off for a buffer sticks: re-reading the file, or anything else
that re-runs filetype detection, leaves your choice alone. A buffer you have
not chosen for follows its filetype in both directions, so `:set ft=text` stops
the padding and `:set ft=markdown` starts it.

```lua
vim.keymap.set("n", "<leader>um", function() require("mdtable").toggle() end, { desc = "Markdown table alignment" })
vim.keymap.set("n", "<LocalLeader>t", function() require("mdtable").align() end, { desc = "Align markdown table" })
```

Rendering state is the buffer variable `b:mdtable_on`, should a statusline
want it.

## Behaviour

**Column width.** A column is as wide as its widest cell's content — but never
narrower than what any cell in it already occupies on screen. Virtual text can
only add columns, so a column sized by content alone would ask an over-padded
cell to shrink, which it cannot do. Every column is at least three wide, so the
separator always has room for a rule.

**Alignment markers** in the separator (`:---`, `:---:`, `---:`) are honoured
when padding cells. `align()` rebuilds the separator from them, so a ragged
`|:-|--:|` comes out even and a left `:--` keeps its colon.

**Whitespace an author already wrote** counts towards the padding on the side
it is on. `|   1 |` is text pushed right, so what it still needs goes on the
right. When that whitespace fights the alignment — trailing blanks in a
right-aligned cell — the text cannot reach its edge, but the pipes still meet.

**Width is display width.** CJK, emoji, combining marks and joined emoji are
measured as the cells they occupy. Tabs are measured where they sit, since a
tab reaches the next multiple of the buffer's `'tabstop'` from its own
position. `align()` turns tabs into spaces, so the alignment it writes survives
being read back under any `'tabstop'`.

Width is the width of the *text*, not of the text in your window: a cell wider
than the window still measures what it is. (`'vartabstop'` is not honoured —
tabs are measured against `'tabstop'` alone.)

**Escapes.** `\|` inside a cell is not a delimiter. `\\|` is an escaped
backslash followed by a delimiter that still splits.

**Fenced code blocks** (`` ``` `` and `~~~`, with the longer-fence-closes rule)
are skipped whole. A table shown as source in a code block is not aligned.

**Rows with more or fewer cells than the header** are rendered each on their
own terms; their trailing pipes will not meet, because they genuinely have
different numbers of cells. `align()` normalises them: short rows gain empty
cells, long rows add a column, nothing is dropped.

**Indented and blockquoted tables** are aligned in place, and `align()` keeps
the indent or the `>` markers, so a table inside a list item or a quote stays
inside it.

**Nothing runs when nothing changed.** Padding is placed for the whole buffer
and replaced when the text or `'tabstop'` changes; a re-render that would change
nothing costs about 3 µs. A full render of a 2000-row table is about 8 ms, and
prose is nearly free — the cost is in table cells, not lines.

**Redraws are coalesced.** A render walks the whole buffer (~10 ms on a
2000-row table), so normal-mode edits restart a 150 ms timer and only the last
one renders. Leaving insert mode renders immediately.

The dashes render adds to the separator use the `@punctuation.special.markdown`
highlight group, which is what treesitter gives the real ones — so the rule is
one colour with treesitter on, and plain without it.

## Limits

mdtable finds tables by scanning lines, not by parsing markdown. Its syntax is
regular enough that a parser would add only code-block awareness, which the
fence tracking covers, and a line scan works where treesitter cannot: on a
machine with no compiler. What follows from that:

- **A table indented four or more spaces is aligned.** At the top level of a
  document that is an indented code block and should be left alone, but the
  same indent inside a list item is a continuation holding a real table. The
  two are indistinguishable without block context, and the second is far
  commoner.
- **A pipe inside any inline construct still separates cells** — `` `a|b` ``,
  `[[Page|Alias]]`, `<kbd>|</kbd>`. This is what GFM specifies: only a
  backslash escapes a delimiter, and tools that render such files (Obsidian
  included) require `\|` in table cells for the same reason.
- **Every row needs a leading pipe.** GFM also accepts `a | b` over `--|--`
  with no outer pipes; mdtable does not, because "any line containing a pipe"
  as the definition of a row would turn prose into tables. Add the pipes.
- **The separator must be the second row**, as the spec requires. A run of
  pipe-lines with its separator elsewhere is not a table, and a second
  `|---|---|` further down is an ordinary row whose cells contain `---` —
  which is also how GitHub shows it. Grid borders (`+---+---+`) are not
  markdown and are left as written.
- **Two tables written with no blank line between them** are one run of rows.
- **Concealed text is measured at its full width.** With `conceallevel` above
  zero and treesitter hiding `**` markers or link targets, a cell containing
  them renders shorter than mdtable measured, and its pipe lands early. There is
  no cheap way to know a cell's concealed width. Keep `conceallevel=0` for
  files where this matters, or accept it on cells with markup.
- **One inline-padding layer at a time.** A plugin that also pads tables with
  virtual text (render-markdown.nvim, for one) will double the padding. Use one
  or the other.
- **Inline padding shifts the cursor's screen column.** It is not drawn in the
  buffer you are typing in for that reason. If it gets in the way in normal
  mode, `:MdTableToggle` turns it off for the buffer.

## Why not a markdown rendering plugin

The problem this solves is narrow: unaligned tables are unreadable, and conceal
cannot fix that because it only removes characters, while alignment needs
characters added. Full rendering plugins do this as one feature among many, at
a size and rate of change out of proportion to the need, and generic aligners
edit the buffer, which is the wrong tool for a file you are only reading.

## Tests

```
nvim -l lua/mdtable/test.lua
```

No framework. Exit code is 0 when all pass. Detection is tested through the
scanner, `align()` through the buffer it rewrites, and the padding by reading
back the extmarks it places and applying them to the buffer's own text.

Two things `nvim -l` cannot reach, so the tests stop one step short of them:
`screenstring()` sees bare text, because marks are only drawn when a UI is
attached, and insert mode cannot be entered without a main loop. Both are
checked at the layer below — the marks themselves, and the gate that decides
whether to place them.

Which leaves `torture.md`, the manual half: twenty numbered cases to open in a
real editor and read down, covering what the automated checks measure but
cannot see — wide characters, tabs, a cell wider than the window, and the
things at the end that must *not* be padded. Both bugs found since the suite
went green came from reading it.

## Design notes

`DESIGN.md`, next to this file, is why it is built this way: the plugins it was
measured against, the detection and width decisions, the performance numbers,
and the bugs that shaped the current wiring.
