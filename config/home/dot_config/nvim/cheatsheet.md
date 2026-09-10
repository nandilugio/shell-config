# Cheatsheet

<leader> is Space, <localleader> is comma. Press <leader> and wait to see what
follows; <leader>fk searches every mapping; :checkhealth config lists gaps.

g jumps · gr acts on symbols · <leader> opens tools · [ ] iterate
<C-w> windows · F-keys bridge other editors


## Getting out

<Esc>           close a float or picker, else clear the search highlight
<Esc><Esc>      leave terminal mode
q               close the file browser, the cheatsheet, a hover you entered
<C-o>           jump back to where you came from


## File browser — <leader>e

A normal buffer: edit a line to rename, delete a line to delete, = to apply.
Deletes go to a trash directory, so a mistaken = is recoverable.

l / L           enter, or open the file and stay / and close the browser
h / H           parent directory / parent, closing this column
=               apply pending changes           g?  help
m / '           set a mark / jump to it         @   reveal the working dir


## Pickers — <leader>f

The input line is a text field, so move with Ctrl, not h j k l.

<C-j>,<C-k>     next, previous                  Enter  open
<C-x>,<C-v>     open in a split, a vsplit       <C-t>  in a tab
<S-Up>,<S-Down> scroll the preview
<C-u>           clear the query                 <C-a>,<C-e>  start, end
Tab             tick several                    <C-q>  send all to quickfix

<leader><leader>  buffers                       <leader>ff  files
<leader>fg or /   grep the project              <leader>fw  word under cursor
<leader>fr        recent files                  <leader>fh  help
<leader>fk        keymaps                       <leader>fd  diagnostics
<leader>fs,fS     symbols: file, workspace      <leader>fR  references (usages)


## Code

gd,gD           definition, declaration         gy,gI  type def, implementation
<C-]> / <C-t>   definition via tags / back      <C-o>,<C-i>  back, forward
K               hover — K again enters it, <Esc> or q closes
<C-s>           signature help, while typing arguments
gO              symbols in this file

grn             rename                          gra  code action
grr             references, into quickfix       grx  run codelens
gq {motion}     format                          <leader>=  the whole buffer
gcc, gc         comment line, selection

grr finds what the server can resolve. For a metaprogrammed name or a word in
a comment, grep instead: <leader>fw or <leader>fg.


## Between things — [ back, ] forward, capital = first or last

]d,[d  ]D,[D    diagnostic; last, first         ]e,[e  ]w,[w  error, warning
]c,[c           changed hunk                    ]q,[q  ]Q,[Q  quickfix
]b,[b           buffer                          ]<Space>,[<Space>  blank line


## Git — <leader>g

Hunks live here; commits and history live in lazygit.

<leader>gs      stage hunk (or selection)       <leader>gr  reset hunk
<leader>gp      preview hunk                    <leader>gb  blame line
<leader>gd      diff this file                  <leader>gg  lazygit
ih              the hunk as a text object: dih, yih


## Windows and buffers

<C-h,j,k,l>     move between windows            tmux uses M-h,j,k,l for panes
<leader>-  |    split below, right              as in tmux
<C-w>           c close · o only · = equalise · _ | maximise
<S-h>,<S-l>     previous, next buffer           <leader>bd  close buffer


## Toggles — <leader>u

uw wrap · us spell · ul line numbers · ur relative numbers · ub light/dark
uh inlay hints       ud diagnostics: all → warnings+errors → errors → off


## Own — <leader>o

Reserved: nothing else will ever claim these.

oh  this cheatsheet    oa  autosave on/off    ox  strip trailing whitespace
ow  wiki index         od  diary today        oD  diary index


## Function keys — same in VS Code, Zed and Visual Studio

<F2> rename          <F12> definition          <S-F12> references


## Completion

Neovim's own. The menu appears when you pause, with nothing selected, so
typing straight past it and pressing Enter still gives a newline.

<C-n>,<C-p>     next, previous — <C-n> also opens the menu at once
<C-y>           accept; also expands the snippet and adds the import
Enter           accept, but only once something is selected
<C-e>           dismiss, keeping what you typed
<C-x><C-o>      language server only            <C-x><C-f>  file paths
<Tab>,<S-Tab>   next, previous snippet placeholder


## Command line — the same keys as completion

<C-n>,<C-p>     next, previous match (Tab too)  <C-y> accept    <C-e> dismiss
<Up>,<Down>     history, not the menu
<C-r><C-w>      insert the word under the cursor   <C-r>{reg}  a register
<C-f>           edit the command line as a buffer  q:  history as a buffer


## Quickfix — Vim's list of places

Filled by :make (rubocop, for ruby), :grep, <C-q> in a picker, <leader>xd.

]q,[q           next, previous                  <leader>xq  open    :cclose
<CR>            jump to the entry under the cursor
The location list is the same, per window: ]l,[l and <leader>xl.


## Vim itself

Motions take a count and work in visual mode. Operators take a motion, and
doubled apply to the line: dd yy cc >> ==.

w,e,b  W,E,B    word, end, back                 0,^,$  start, first char, end
f,t {c}  ;  ,   find, till a char; repeat       {,}  paragraph   %  bracket
gg,G  {n}G      file start, end, line n         H,M,L  screen top, mid, bottom
*,#  n,N        search the word under cursor; next, previous match
<C-d>,<C-u>     half page      <C-f>,<C-b>  full page      zz,zt,zb  cursor to

d c y  > < =    delete, change, yank; indent, dedent, reindent
gu gU g~        lower, upper, swap case         gq  format
x s  p P        delete, substitute a char; put after, before
v V <C-v>       visual char, line, block        gv  reselect

Text objects, after an operator: diw ca( yip
iw,aw  i(,a(    word; brackets — also { [ < " ' `      ip,ap  paragraph
it,at           html tag                               in,an  syntax node

:%s/old/new/gc  whole file, confirming each     :'<,'>s/...  the selection
:%s//new/g      an empty pattern reuses the last search
