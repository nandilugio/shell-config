" This mappings fix some weird keyboard behaviors.
" To test mappings: Insert mode, <C-v>, type whatever is wrongly being
" interpreted. Literal escape sequence will be typed. A leading ^[ means
" <ESC>.
"
" "Note that although escape sequences vary between terminals, conflicts (i.e.
" an escape sequence that corresponds to different keys in different
" terminals) are rare, so there's no particular need to try to apply the
" mappings only on a particular terminal type."
"
" See: https://unix.stackexchange.com/questions/1709/how-to-fix-ctrl-arrows-in-vim
"
" Fixes for Linux + Gnome terminal
map <ESC>[1;5D <C-Left>
map <ESC>[1;5C <C-Right>
map! <ESC>[1;5D <C-Left>
map! <ESC>[1;5C <C-Right>
map <ESC>[5;5~ <C-PageUp>
map <ESC>[6;5~ <C-PageDown>
map! <ESC>[5;5~ <C-PageUp>
map! <ESC>[6;5~ <C-PageDown>

" Basics
let mapleader = " "
nmap \ <leader>

" Edit & reload .vimrc
nnoremap <leader>, :e $MYVIMRC<cr>
nnoremap <leader>r, :source $MYVIMRC<cr>

" Buffers
set hidden " Hide buffers when not displayed. This allow to switch between buffers without saving
nmap <leader>sudo :w !sudo tee %<cr>

nmap <leader><Left> :bp<cr>
nmap <leader><Right> :bn<cr>
nmap <leader><PageUp> :bp<cr>
nmap <leader><PageDown> :bn<cr>
nmap <leader>t :enew<cr>
nmap <leader>w :bd<cr>
nmap <leader>s :w<CR>

nmap <C-Left> :bp<cr>
nmap <C-Right> :bn<cr>
nmap <C-PageUp> :bp<cr>
nmap <C-PageDown> :bn<cr>
nmap <C-t> :enew<cr>
nmap <C-w> :bd<cr>
" nmap <C-s> :w<CR>
" <C-s> is trapped by the OS's terminal driver (use <C-s> to 'unfreeze' the terminal ;p).
" See: https://unix.stackexchange.com/questions/12107/how-to-unfreeze-after-accidentally-pressing-ctrl-s-in-a-terminal

" Clipboard
set clipboard=unnamed " Global clipboard

" Swap and backups
set noswapfile
set nobackup
set nowritebackup

" Search
set hlsearch
set incsearch
nnoremap <leader>/ :let @/ = "" <cr> 

" Display
colorscheme desert
set number
"set relativenumber 
"set nowrap
set wrap linebreak nolist
"set cursorline

" Mouse
set mouse=a

" Text indentation
filetype indent plugin on
set expandtab
set autoindent
set shiftwidth=2
set tabstop=2
set softtabstop=2

" Text editing
set backspace=indent,eol,start
inoremap <C-d> <Del>

" Remove trailing space
nnoremap <silent> <leader>dt :let _s=@/ <Bar> :%s/\s\+$//e <Bar> :let @/=_s <Bar> :nohl <Bar> :unlet _s <CR>

" Misc
set enc=utf-8
set autoread
set pastetoggle=<F1>
"set textwidth=0
"set history=1000 
"set backspace=indent,eol,start
"set sessionoptions=blank,buffers,curdir,folds,help,resize,tabpages,winsize

" Finding files
set wildmode=list:longest

" FZF (https://github.com/junegunn/fzf.vim)
nnoremap <leader><leader> :FZF<cr>
nnoremap <leader>p :FZF<cr>

" CtrlP (http://ctrlpvim.github.io/ctrlp.vim)
" set runtimepath^=~/.vim/bundle/ctrlp.vim
" let g:ctrlp_working_path_mode = 'ra'

" Nerdtree (https://github.com/scrooloose/nerdtree)
" nnoremap <C-n> :NERDTreeToggle<cr>
" autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif " Close vim if the only window left open is a NERDTree

" Vim Airline (https://github.com/vim-airline/vim-airline)
set laststatus=2
let g:airline#extensions#tabline#enabled = 1

" VimPlug (https://github.com/junegunn/vim-plug)
" Reload .vimrc and :PlugInstall to install plugins.
if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif
call plug#begin('~/.vim/plugged')
"Plug 'scrooloose/nerdtree'
"Plug 'Xuyuanp/nerdtree-git-plugin'
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
Plug 'vim-airline/vim-airline'
Plug 'vim-ruby/vim-ruby'
"Plug 'ervandew/supertab'
Plug 'elixir-lang/vim-elixir'
"Plug 'kchmck/vim-coffee-script'
call plug#end()

