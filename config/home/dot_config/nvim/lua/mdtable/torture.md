# mdtable torture test

Keys: `,t` aligns the table under the cursor **in the buffer**.
`<Space>um` toggles the display padding off and on.

How to use this file: read down it once with padding on and check each table
looks right. Then put the cursor in each table and press `,t` — the text should
end up looking the way it already looked, because both halves measure the same
way. `u` undoes it. Anything where `,t` *moves* things is a bug worth telling
me about.

Tables 18-20 at the end should NOT be padded at all.

---

## 1. The basic case — ragged, no alignment markers

Every column is a different width and nothing lines up in the source.

| Name | Description | Status |
|---|---|---|
| foo | a thing | ok |
| a much longer name | short | pending |
| x | y | z |

## 2. Alignment markers — left, centre, right

Column 2 should centre, column 3 should hug the right edge. `,t` must keep the
`:` marks, including the left one on column 1.

| a | b | c |
|:--|:-:|--:|
| 1 | 2 | 3 |
| longer | longer | longer |
| x | y | z |

## 3. Already padded

Nothing should change on screen, and `,t` should leave it byte-identical.

| Name   | Value |
| ------ | ----- |
| first  | 1     |
| second | 22    |

## 4. Whitespace in every combination

Row by row: none, leading, trailing, both, and a lot of both. The padding has
to count what is already there, on the side it is on.

| alpha | beta |
|---|---|
|1|2|
|   3| 4 |
|5   | 6 |
|   7   |  8  |
|        9        |    10    |

## 5. Whitespace fighting the alignment

Right-aligned, but the cells have trailing spaces the padding cannot remove.
The pipes must still line up even though the text cannot reach the right edge.

| n |
|--:|
|1   |
|22  |
|333 |

## 6. CJK, emoji, accents, RTL

All of these are wider or narrower than their byte count suggests.

| text | note |
|---|---|
| 日本語テキスト | three wide chars |
| 🎉 party | emoji is two cells |
| 👨‍👩‍👧 family | joined emoji, still two |
| éé | combining accents |
| שלום | right-to-left |
| plain ascii | the control |

## 7. A cell wider than your window

This is the one that was broken: measuring it against the window made the
column too wide. Unless your terminal is very wide, this cell wraps — the other
rows must still reach the same pipe.

| kind | detail |
|---|---|
| long | Pads the columns on screen with inline virtual text. The buffer is untouched, so it is safe on anything you are only reading, which is most files most of the time. |
| short | tiny |

## 8. Tabs — the awkward one

There are real tabs in here. A tab reaches the next multiple of `tabstop`, so
its width depends on where it lands, and padding moves it. `,t` turns them into
spaces on purpose.

| alpha | beta |
|---|---|
|	leading tab | x |
| between	words | y |
|	both	sides	| z |

## 9. Tabs after a padded column

Column 1 gets padded, which pushes the tab in column 2 to a new screen column
and changes its width.

| aaaaaaaaaaaa | b |
|---|---|
| x |	y |
| z | w |

## 10. Tabs with right and centre alignment

Padding goes *before* the text here, which moves the tab inside it.

| aaaaaaaaaa | b |
|----------:|:-:|
| x	y | q	r |
| short | s |

## 11. Escaped pipes

`\|` is not a delimiter. `\\|` is an escaped backslash and then a real
delimiter — so row 3 has three cells, not two.

| a | b | c |
|---|---|---|
| x \| y | z | w |
| p \\| q | r | s |
| plain | cells | here |

## 12. Empty cells, and an empty header

The header row is all blanks. Columns still get a minimum width of three.

| | | |
|---|---|---|
| **render** | automatic | Pads the columns on screen. |
| **align** | on demand | Pads the table in the buffer. |

| a | b |
|---|---|
|  |  |
| x |  |
|  | y |

## 13. Ragged cell counts

Row 2 is short, row 3 is long. Their trailing pipes will NOT line up on screen —
that is correct, they genuinely have different numbers of cells. `,t` normalises
them: short rows gain empty cells, long rows add a column, nothing is dropped.

| a | b | c |
|---|---|---|
| 1 |
| 2 | 3 | 4 | 5 |
| 6 | 7 | 8 |

## 14. Missing outer pipes

The trailing pipe is optional.

| a | b
|---|---
| 1 | 2
| longer | x

## 15. Separators of odd sizes

A one-dash separator, and one much wider than its content. A rule longer than
the column cannot be shortened, so the columns widen to fit it.

| a | b |
|-|-|
| 1 | 2 |

| a | b |
|--------------|--------------|
| 1 | 2 |

## 16. Indented, and in a list

Both are aligned in place. `,t` keeps the indent, so the table stays inside
its list item.

  | a | b |
  |---|---|
  | 1 | longer |

- A list item:

  | key | value |
  |---|---|
  | one | first |
  | two | second |

## 17. In a blockquote

Blockquotes are container blocks, so a table inside one is still a table. `,t`
must keep the `>` markers.

> | a | b |
> |---|---|
> | 1 | longer |
> | 2 | x |

> Nested:
>
> > | a | b |
> > |---|---|
> > | 1 | longer |

---

# These must NOT be padded

## 18. Inside a fenced code block

Nothing in here is a table. This is the case a line scanner would get wrong.

```
| a | b |
|---|---|
| 1 | 2 |
```

~~~
| a | b |
|---|---|
| 1 | 2 |
~~~

A fence with an info string opens a block but never closes one, so the table
below is still inside it:

````
```lua
| a | b |
|---|---|
| 1 | 2 |
```
````

## 19. Things that look like tables but are not

No separator row, so not a table:

| no | separator |
| so | not a table |

Separator in the wrong place — it must be the second row:

| a | b |
| c | d |
|---|---|

Column counts disagree between header and separator:

| a | b | c |
|---|---|
| 1 | 2 | 3 |

A separator cell with no dash:

| a | b |
|:|---|
| 1 | 2 |

Prose that merely contains a pipe should be untouched: use `a | b` for either,
and `c | d` for both.

## 20. Not GFM

Grid borders are Pandoc, not markdown. The pipe rows between them ARE a table
and will be padded; the `+---+` lines will not, and will not line up. That is
correct — they are not part of the table.

+---+---+
| a | b |
|---|---|
| 1 | 2 |
+---+---+

Pipeless tables are valid GFM but not supported, by choice — "any line with a
pipe" as the definition of a row would turn prose into tables. Nothing here
should be padded:

a | b
--|--
1 | 2
