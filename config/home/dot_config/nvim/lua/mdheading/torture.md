# mdheading torture test

`<Space>uH` toggles the heading colours. `<Space>um` and `,t` still drive mdtable.

How to use this file: read down it once and check every section does what its
title says. Sections 1-11 should be tinted. Sections 12-16 are the ones that
must NOT be tinted — those are where a line scanner earns its keep, and where
a bug would hide.

There are 16 sections and about 100 heading-shaped lines, of which 64 should
actually be coloured — 57 above the "must NOT" divider, plus the seven section
titles below it. Anything else tinted after that divider, or left plain before
it, is a bug worth telling me about.

---

# 1. The six levels, in order

The point of the whole plugin. These should fade evenly, strongest to faintest,
with no two adjacent levels hard to tell apart.

# Level 1
## Level 2
### Level 3
#### Level 4
##### Level 5
###### Level 6

## 2. The same six, spread out

Depth has to read on its own, without a neighbour to compare against. Scroll so
only one of these is on screen and see whether you can still name its level.

# One again

Some prose between them, so the levels are not adjacent. This is the realistic
case: you land somewhere in a long document and want to know how deep you are
without counting hashes.

### Three again

More prose. The tint is doing the work here.

###### Six again

If this one reads as "no tint at all" rather than "the faintest tint", the
range wants narrowing. That is the main thing this file is asking you.

## 3. Boundaries of the syntax

A bare `#` with nothing after it is a valid empty heading, so the next line
should be tinted:

#

And a bare `######`, also valid, also tinted:

######

A heading whose text is only whitespace — tinted, same as above:

##   

## 4. Whitespace after the hashes

All four should be tinted, at the level their hash count says.

# One space
##  Two spaces
###   Three spaces
####	A tab after the hashes

## 5. Trailing hashes (ATX closing sequence)

CommonMark allows a closing run of hashes. These are levels 1, 2 and 3 — the
trailing hashes are decoration, not depth:

# Closed heading #
## Closed heading ##
### Closed heading ###########

## 6. Indented headings

Up to three spaces is unambiguous. Four or more is an indented code block at
the top level, but a list continuation inside a list — indistinguishable
without block context, so all of these are tinted. Same call mdtable makes.

 # One space indent
  ## Two space indent
   ### Three space indent
    #### Four space indent (tinted, though strictly a code block here)

## 7. Inside a list

The realistic version of the case above. Both should be tinted, and the tint
reaches the window edge, so it covers the list marker too.

- A list item:

  ### Heading inside a list item

  Text under it.

1. A numbered item:

   #### Heading inside a numbered item

## 8. Blockquoted

`> ## x` is a heading inside a quote and GitHub renders it as one. The tint
covers the `>` markers, because the colour runs to the window edge.

> # Quoted level 1
>
> Some quoted prose.
>
> ### Quoted level 3

Nested:

> > ## Two levels deep
> >
> > > ##### Three levels deep

Blockquote with no space after the marker:

>## No space after the marker

## 9. Right after other block constructs

A heading immediately after a table, with no blank line:

| a | b |
|---|---|
| 1 | 2 |
### Heading straight after a table

A heading immediately after a fence closes:

```
code
```
### Heading straight after a fence

A heading immediately after a list:

- item
### Heading straight after a list

## 10. Adjacent headings, no blank lines

Six in a row with nothing between them — the easiest place to see the ramp,
and a place an off-by-one in the scan would show up:

# A
## B
### C
#### D
##### E
###### F
# G

## 11. Long and wide

The tint fills the line to the window edge, not to the end of the text, so this
next one should be a solid band across the whole window even though the text
stops partway:

# Short text, long band

### A heading long enough that it runs past the right edge of a normal terminal window and has to wrap, which is worth checking because the highlight applies to the whole buffer line rather than to each screen row

A heading with wide characters, to check nothing assumes one byte is one cell:

## 日本語の見出し — CJK

### 🎉 An emoji heading

#### Ünïcödé àccénts

---

# These must NOT be tinted

If anything below this line gets a background colour, that is a bug.

## 12. Inside fenced code blocks

This is the case a naive line scanner gets wrong, and the reason fence tracking
was copied from mdtable rather than rewritten.

A plain backtick fence:

```
# not a heading
## also not
###### definitely not
```

A tilde fence:

~~~
# not a heading
### also not
~~~

A fence with an info string. CommonMark 4.5 says a closing fence carries only
its marker, so ```` ```lua ```` opens a block but never closes one — the
"heading" below is still inside it:

````
```lua
# not a heading
```
````

A longer fence closing a shorter one, with a heading-shaped line in between:

```
# not a heading
````
Now outside. (This line is prose, not a heading.)

A tilde does not close a backtick fence, so both of these are still inside:

`````
# not a heading
~~~
# still not a heading
`````

An indented fence:

  ```
  # not a heading
  ```

A fence inside a blockquote:

> ```
> # not a heading
> ```

## 13. Not headings by syntax

Seven hashes is past the maximum of six, so this is not a heading:

####### seven hashes

No whitespace after the hashes — this is a tag or a fragment link, not a
heading:

#nospace
#hashtag
#1234
##nospace-either
######nope

A hash that is not at the start of the line:

Some prose with a # in the middle.
   Indented prose with a # in it.
A trailing hash #

A hash escaped with a backslash is not a heading in CommonMark. mdheading does
tint this one — a documented limit rather than a surprise, since the scanner
does not track inline escapes:

\# escaped hash

## 14. Setext headings are not supported

The two-line underline forms are real markdown, but they need lookahead and the
`---` form collides with a table separator and a thematic break. Both of these
should be plain — no tint on the text, none on the underline:

Setext level 1
==============

Setext level 2
--------------

## 15. Things that only look like fences or headings

A horizontal rule is not a heading:

---

***

___

A line of hashes with no space, which is decoration rather than a heading:

##########

A line that starts with a hash inside inline code:

`# not a heading` is inline code.

## 16. Empty and awkward

An empty line, a line of only spaces, and a line of only a tab follow. None of
them are headings and none should be tinted:

   
	

---

# What to tell me

1. **Level 6** — visible enough, or should the range narrow? This is the main
   question.
2. **Level 1** — too strong, or about right?
3. **Adjacent levels** — can you tell 3 from 4 in section 1? In section 10?
4. **Other themes** — `:colorscheme retrobox`, `catppuccin`, `sorbet`,
   `habamax`. The ramp recomputes per theme; does it work on the ones you would
   actually use?
5. **Anything tinted in sections 12-16**, or plain in 1-11.
6. **Typing** — enter insert mode and the colours should vanish, then come back
   when you leave, including with `<C-c>`.
