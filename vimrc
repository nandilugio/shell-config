" Basics
let mapleader = " "
nmap \ <leader>

" Edit & reload .vimrc
nnoremap <leader>, :e $MYVIMRC<cr>
nnoremap <leader>r, :source $MYVIMRC<cr>

" Buffers
set hidden " Hide buffers when not displayed. This allow to switch between buffers without saving
nnoremap <leader><pagedown> :bn<cr>
nnoremap <leader><pageup> :bp<cr>
nnoremap <leader>t :enew<cr>
nnoremap <leader>s :w<CR>
nnoremap <leader>w :bd<cr>
nnoremap <leader>sudo :w !sudo tee %<cr>

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

" Text indentation
filetype indent plugin on
set expandtab
set autoindent
set shiftwidth=2
set tabstop=2
set softtabstop=2
"set smartindent

" Text editing
set backspace=indent,eol,start

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

