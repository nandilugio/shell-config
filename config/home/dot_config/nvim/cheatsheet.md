# Cheatsheet

<leader> is Space. <localleader> is comma.
Press <leader> and wait to see what follows. <leader>fk searches every mapping.
:checkhealth config reports anything missing on this machine.

g jumps · gr acts on symbols · <leader> opens tools · [ ] iterate
<C-w> windows · F-keys bridge other editors


## Getting out

q               close the file browser
<Esc>           close a picker, clear search highlight
<C-c>           close a picker, when <Esc> is taken
<Esc><Esc>      leave terminal mode
<C-o>           jump back where you came from


## File browser — <leader>e

A normal buffer: j,k to move, edit a line to rename, delete a line to delete,
then = to apply. Deletes go to a trash dir, so a mistaken = is recoverable.

l               enter directory, or open file AND STAY here
L               enter directory, or open file AND CLOSE the browser
h               go to parent directory
H               go to parent, closing the current column
q               close
=               apply pending renames, deletes and creations
g?              help, inside the browser

m and '         set a mark, jump to it
@               reveal the working directory


## Pickers — <leader>f...

The input line is a text field, so h,j,k,l become query text. Move with Ctrl —
no need to clear what you typed first.

<C-j>,<C-k>     next, previous result   (also <C-n>,<C-p> or the arrows)
Enter           open it
<C-x>,<C-v>     open in a split, a vsplit
<C-t>           open in a new tab
<S-up>,<S-down> scroll the preview

<C-u>           clear the query         (as in a shell, not a half-page scroll)
<C-a>,<C-e>     start, end of the query
<BS>,<C-w>      delete a char, a word

Tab             tick several, then Enter sends them to the quickfix list
<C-q>           send every result to the quickfix list

<leader><leader>  switch buffer
<leader>ff        files
<leader>fg or /   grep the project
<leader>fw        grep the word under the cursor
<leader>fr        recent files
<leader>fh        help
<leader>fk        keymaps
<leader>fd        diagnostics
<leader>fs,fS     symbols in this file, in the workspace
<leader>fR        references (usages), with a preview   note: fr is recent files


## Code

Jumps live on g, actions on gr.

gd,gD           definition, declaration
gy,gI           type definition, implementation
<C-]> / <C-t>   definition via tags / back
<C-o>,<C-i>     back, forward through jumps
K               hover documentation
gO              symbols in this file

grn             rename
gra             code action
grr             references — every usage, into the quickfix list
<leader>fR      the same, in a picker with previews
grx             run codelens

gq {motion}     format          <leader>= whole buffer
gcc, gc         comment line, comment selection

g]              ruby only: list every matching definition, not just the first

grr finds what the language server can resolve. For anything it cannot — a
method reached through metaprogramming, a name in a comment — grep instead
with <leader>fw (word under the cursor) or <leader>fg.


## Between things

[ goes back, ] goes forward. Uppercase jumps to the first or last.

]d,[d           diagnostic              ]D,[D  last, first
]e,[e           error only
]w,[w           warning only
]c,[c           changed hunk
]f,[f           function
]t,[t           type or class
]q,[q           quickfix entry          ]Q,[Q  last, first
]b,[b           buffer
]<Space>        blank line below        [<Space> above


## Git — <leader>g

Hunks live here; commits and history live in lazygit.

]c,[c           next, previous hunk
<leader>gs      stage hunk              (works on a selection)
<leader>gr      reset hunk
<leader>gp      preview hunk
<leader>gb      blame line
<leader>gd      diff this file
<leader>gg      lazygit


## Windows and buffers

<C-h,j,k,l>     move between windows    (tmux uses M-h,j,k,l for panes)
<leader>-       split below             as in tmux
<leader>|       split right             as in tmux
<C-w>           everything else: c close, o only, = equalise, _ | maximise

<S-h>,<S-l>     previous, next buffer
<leader>bd      close buffer


## Toggles — <leader>u

uw  wrap            us  spell           ul  line numbers
ur  relative nums   ud  diagnostics     uh  inlay hints
ub  light/dark


## Own — <leader>o

Reserved: nothing else will ever claim these.

<leader>oh      this cheatsheet
<leader>oa      autosave on/off         (writes when you leave insert)
<leader>ox      strip trailing whitespace
<leader>ow      wiki index              od diary today, oD diary index


## Function keys

Same in VS Code, Zed and Visual Studio.

<F2>            rename
<F12>           definition
<S-F12>         references


## Completion

Neovim's own, no plugin. The menu appears after a short pause; <C-n> summons it
at once. Sources are the buffer, other buffers, and the language server.

<C-n>,<C-p>     next, previous candidate — <C-n> also opens the menu
<C-y>           accept — also expands snippets and adds imports
Enter           accept, but only once you have selected something
<C-e>           dismiss, keeping what you typed
<C-x><C-o>      ask the language server only
<C-x><C-f>      file paths

The menu opens with nothing selected, so typing straight past it and pressing
Enter still gives a newline. Press <C-n> first and Enter accepts — by then you
are choosing from the list, not writing. <C-y> accepts either way.


## Command line

Same keys as insert-mode completion: the menu shows itself as you type, and
<C-y> and <C-e> mean what they mean above.

<C-n>,<C-p>     next, previous match       Tab,<S-Tab> also work
<C-y>           accept the match
<C-e>           dismiss the menu
Enter           run the command
<Up>,<Down>     command history, not the menu
<C-u>,<C-w>     clear the line, clear a word
<C-r> {reg}     insert a register — <C-r><C-w> is the word under the cursor
<C-f>           edit the command line as a buffer
q:              command history as a buffer


## Scrolling

<C-u>,<C-d>     half page up, down      in buffers, which-key, hover floats
<C-b>,<C-f>     full page up, down
zz,zt,zb        cursor to centre, top, bottom
<C-e>,<C-y>     one line down, up


## Motions

{count}{motion}, and they work in visual mode too.

w,e,b           word, end, back         W,E,B  same but WORDS
f,F {char}      find next, prev in line
t,T {char}      same, stopping before it
; and ,         repeat that find forward, backward

0,$             start, end of line
^ or _          first non-blank
{,}             previous, next paragraph
%               matching bracket
H,M,L           screen high, middle, low
gg,G            file start, end         {n}G  line n
*,#             search word under cursor, forward and back
/,? {pat}       search forward, back    n,N  next, previous match


## Operators

{operator}{count}{motion}, doubled to apply to the line.

d,dd,D          delete motion, line, to end of line
c,cc,C          change
y,yy,Y          yank
>,<,=           indent, dedent, reindent
gu,gU,g~        lower, upper, swap case
gq              format

x,s             delete, substitute char
v,V,<C-v>       visual char, line, block        gv  reselect
p,P             put after, before


## Text objects

Use with an operator: diw, ca(, yif.

iw,aw           word, word plus space
i(,a(  i[,a[    inside, around brackets — also i{ i< i" i' i`
ip,ap           paragraph
it,at           xml/html tag
if,af           function
ic,ac           class
ih              git hunk


## Substitute

:%s/old/new/gc  whole file — g every match on the line, c confirm each
:'<,'>s/old/new/  the visual selection
:%s//new/g      an empty pattern reuses the last search
