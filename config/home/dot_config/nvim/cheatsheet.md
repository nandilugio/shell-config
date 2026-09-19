# Cheatsheet

<leader> is Space, <localleader> is comma. Press <leader> and wait to see what
follows; :checkhealth config lists gaps.

Finding what you already have, before writing it yourself:

:SomePlugin <Tab>   the functions a plugin exposes — :FzfLua, :Gitsigns, ...
<leader>fh          search every plugin's help     <leader>fk  every mapping
:FzfLua commands    every Ex command, plugins included

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

The input line is a text field, so move with Ctrl, not h j k l. These are
fzf's own keys, so they are the same ones the shell's fzf uses.

<C-j>,<C-k>     next, previous                  Enter  open
<C-s>,<C-v>     open in a split, a vsplit       <C-t>  in a tab
<C-f>,<C-b>     half page down, up              <C-u>  clear the query
<S-Up>,<S-Down> scroll the preview              <C-a>,<C-e>  start, end of query
Tab             tick one, M-a ticks all         M-q    ticked to quickfix
F1 help · F4 hide the preview · M-i include ignored · M-f follow symlinks

Tab does nothing where a pick must be single: buffers and file history.
M-h (include hidden) is tmux's pane-left and never arrives; M-i is the one
you want anyway, since .gitignore hides more here than dotfiles do.

<leader><leader>  buffers                       <leader>ff  files
<leader>fg or /   grep the project              <leader>fw  word under cursor
<leader>fr        recent files                  <leader>fh  help
<leader>fk        keymaps                       <leader>fd  diagnostics
<leader>fs,fS     symbols: file, workspace      <leader>fR  references (usages)
<leader>f?        every picker fzf-lua has      <leader>f.  resume the last one


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

Hunks and history here; commits and rebases belong in a tmux pane.
Capital = the whole buffer, where the lowercase is one hunk.

<leader>gs,gS   stage hunk (or selection), buffer
<leader>gr,gR   reset hunk (or selection), buffer
<leader>gp      preview hunk                    <leader>gq  hunks to quickfix
<leader>gd      diff this file
ih              the hunk as a text object: dih, yih

gs on a hunk that is already staged unstages it — the signs dim when staged,
so you can see which is which.

<leader>gb      blame this line, in a float
<leader>gB      blame the file, in a scroll-bound side panel
<leader>gl      line history: every commit that touched it (visual: the range)
<leader>gt      function history: the whole function, as it moved and changed
<leader>gf      file history: every commit touching the file, as a picker

gt needs the repository to have enabled git's funcname pattern for the
language (`*.py diff=python` in .gitattributes); it says so when it has not.
On a definition line prefer gt: gl there shows the signature and hides the
body that changed with it.

Inside the blame panel: <CR> menu · s,S show commit in a split, a tab
r reblame at that commit · R at its parent · d,D diff it in a tab
r and R land you in a read-only revision of the file: the statusline then
reads name@sha in red. <C-o> comes back. They error across a rename.

Its toggles are under <leader>ug — see Toggles below.


## Windows and buffers

<C-h,j,k,l>     move between windows            tmux uses M-h,j,k,l for panes
<leader>-  |    split below, right              as in tmux
<C-w>           c close · o only · = equalise · _ | maximise
<S-h>,<S-l>     previous, next buffer           <leader>bd  close buffer


## Toggles — <leader>u

uw wrap · us spell · ul line numbers · ur relative numbers · ub light/dark
uh inlay hints       ud diagnostics: all → warnings+errors → errors → off
um markdown table alignment (on by default for markdown)
ug* git: ugd deleted lines · ugw word diff · ugb blame every line


## Filetype — <LocalLeader> = ,

,t  pad the markdown table under the cursor, for real (edits the buffer)


## Own — <leader>o

Reserved: nothing else will ever claim these.

oh  this cheatsheet    oa  autosave on/off    ox  strip trailing whitespace
ow  wiki index         od  diary today        oD  diary index


## Function keys — same in VS Code, Zed and Visual Studio

<F2> rename          <F12> definition          <S-F12> references


## Completion

Neovim's own, and it never appears on its own — you ask for it. Nothing is
selected when the menu opens, so Enter still gives a newline until you pick.

<C-n>,<C-p>     open the menu, then next, previous
<C-y>           accept; also expands the snippet and adds the import
Enter           accept, but only once something is selected
<C-e>, <Esc>    dismiss, keeping what you typed — Esc again leaves insert
<C-x><C-o>      language server only            <C-x><C-f>  file paths
<Tab>,<S-Tab>   next, previous snippet placeholder

<C-Space> is mapped too, as in VS Code and Zed, but many terminals swallow it.


## Command line — the same idea, on <Tab>

Tab             open the menu, then next match  <S-Tab>  previous
<C-n>,<C-p>     with the menu open, next and previous — as in insert mode;
                with it closed, newer and older commands from history
<C-y>           accept the match and keep editing — for building up arguments
Enter           accept and run
<C-e>           dismiss the menu
<Down>,<Up>     with the menu open, descend into and leave a directory;
                with it closed, command history — never the menu
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
                what you yank flashes, so you can see what it took
gu gU g~        lower, upper, swap case         gq  format
x s  p P        delete, substitute a char; put after, before
v V <C-v>       visual char, line, block        gv  reselect

Text objects, after an operator: diw ca( yip
iw,aw  i(,a(    word; brackets — also { [ < " ' `      ip,ap  paragraph
it,at           html tag                               in,an  syntax node

:%s/old/new/gc  whole file, confirming each     :'<,'>s/...  the selection
:%s//new/g      an empty pattern reuses the last search
