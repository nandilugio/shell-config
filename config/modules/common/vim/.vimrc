" ~/.vimrc: plain Vim, for a box that has only Vim. One file to curl, nothing
" to install, no network at startup.
"
" The keys are the Neovim config's (config/modules/common/nvim, see its
" cheatsheet), on the subset Vim has without plugins: leader and the find,
" git, toggle, lists and own namespaces, windows, folds, completion. No LSP,
" so gd, gr* and the F-keys stay as Vim ships them; no gitsigns, so <leader>g
" is empty. Kept in sync BY HAND: when a key moves in nvim's lua/keymaps.lua,
" move it here too. Everything version-dependent is behind a guard, so this
" also loads on an old Vim, minus that feature.

set nocompatible
set encoding=utf-8
scriptencoding utf-8
filetype plugin indent on
syntax on

" Vim captures the leader at definition time: before any mapping.
let mapleader = " "
let maplocalleader = ","

" ── Options, as nvim's options.lua ──────────────────────────────────────────

set updatetime=250
set timeoutlen=300 ttimeoutlen=10

set ignorecase smartcase
set incsearch hlsearch
silent! set inccommand=split

set hidden
set confirm
set virtualedit=block
set expandtab shiftwidth=2 softtabstop=2 tabstop=2
silent! set nofixendofline
set backspace=indent,eol,start
if has('clipboard') | set clipboard^=unnamedplus | endif
set mouse=a

set number
set scrolloff=10
silent! set signcolumn=yes
set cursorline
silent! set breakindent
set list listchars=tab:»\ ,trail:·,nbsp:␣
set splitright splitbelow
set laststatus=2 ruler

" Folds: no parse tree here, so by indent; all open on entry.
set foldmethod=indent foldlevel=99

" Completion is asked for, never volunteered: <C-n>/<C-p>, <C-x><C-o>.
set completeopt=menu,menuone,noselect
silent! set completeopt+=popup
silent! set completeopt+=fuzzy

" The command line, on <Tab>; a popup where Vim can draw one.
set wildmenu wildmode=full
silent! set wildoptions=pum,fuzzy

" :find through the tree, and :grep with rg where it is.
set path+=**
if executable('rg')
  set grepprg=rg\ --vimgrep\ --smart-case
  set grepformat=%f:%l:%c:%m
endif

" netrw is the browser here. Its history file was a code-execution path
" (GHSA-crm5-rh6j-2c7c, fixed in 9.2.0495): a directory name with a quote in
" it, written unescaped into .netrwhist and sourced at startup. No history.
let g:netrw_dirhistmax = 0

" Vim 9.1 ships gc/gcc as an optional package, the keys Neovim has built in.
silent! packadd comment

" ── Keys ────────────────────────────────────────────────────────────────────
" Normal mode, noremap, unless said otherwise.

" Find: <leader>f. The built-ins nvim falls back to where fzf is absent.
nnoremap <leader><leader> :buffer<Space>
nnoremap <leader>ff :find<Space>
nnoremap <leader>fg :grep<Space>
nnoremap <leader>/ :grep<Space>
nnoremap <leader>fw :grep <C-r><C-w><CR>
nnoremap <leader>fr :browse oldfiles<CR>
nnoremap <leader>fh :help<Space>
nnoremap <leader>fk :map<CR>

" Files
nnoremap <leader>e :Explore<CR>

" Windows and buffers. <C-hjkl> here, M-hjkl for tmux's panes.
nnoremap <C-h> <C-w><C-h>
nnoremap <C-j> <C-w><C-j>
nnoremap <C-k> <C-w><C-k>
nnoremap <C-l> <C-w><C-l>
nnoremap <leader>- :split<CR>
nnoremap <leader>\| :vsplit<CR>
nnoremap <leader>bd :bdelete<CR>

" Lists: [ back, ] forward, capital = first or last. Neovim has these
" built in; Vim does not.
nnoremap ]b :bnext<CR>
nnoremap [b :bprevious<CR>
nnoremap ]q :cnext<CR>
nnoremap [q :cprevious<CR>
nnoremap ]Q :clast<CR>
nnoremap [Q :cfirst<CR>
nnoremap ]l :lnext<CR>
nnoremap [l :lprevious<CR>
nnoremap <leader>xq :copen<CR>
nnoremap <leader>xl :lopen<CR>

" Toggles: <leader>u
nnoremap <leader>uw :set wrap!<CR>
nnoremap <leader>us :set spell!<CR>
nnoremap <leader>ul :set number!<CR>
nnoremap <leader>ur :set relativenumber!<CR>
nnoremap <leader>ub :let &background = &background ==# 'dark' ? 'light' : 'dark'<CR>
nnoremap <leader>uz :let &foldcolumn = &foldcolumn ? 0 : 1<CR>

" Own: <leader>o
nnoremap <leader>ox :%s/\s\+$//e<CR>:nohlsearch<CR>:echo "Cleared trailing whitespace"<CR>

" Neovim's own defaults that Vim lacks. Not <Esc> for :nohlsearch, as in
" nvim: terminal Vim receives escape sequences at startup (the terminal's
" replies to its queries), and a normal-mode <Esc> mapping fires on them.
nnoremap Y y$
if has('terminal')
  tnoremap <Esc><Esc> <C-\><C-n>
endif

" Completion. Enter accepts only once something is selected, so it still
" gives a newline until you pick. <C-Space> arrives as <Nul> in a terminal.
if exists('*complete_info')
  inoremap <expr> <CR> pumvisible() && complete_info(['selected']).selected != -1 ? "\<C-y>" : "\<CR>"
endif
inoremap <Nul> <C-n>
