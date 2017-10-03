let mapleader = " "

" Edit & reload .vimrc
nnoremap <leader>. :e $MYVIMRC<cr>
nnoremap <leader>r. :w<cr>:source $MYVIMRC<cr>

" Buffers
set hidden " Hide buffers when not displayed. This allow to switch between buffers without saving
nnoremap <c-s-right> :bn<cr>
nnoremap <c-k> :bn<cr>
nnoremap <c-l> :bn<cr>
nnoremap <c-s-left> :bp<cr>
nnoremap <c-j> :bp<cr>
nnoremap <c-h> :bp<cr>
nnoremap <leader>t :enew<cr>
nnoremap <leader>q :bd<cr>
nnoremap <leader>sudo :w !sudo tee %<cr>

" Clear search
nnoremap <leader>/ :let @/ = "" <cr> 

" Text indentation
filetype indent plugin on
set expandtab
set autoindent
set shiftwidth=2
"set tabstop=2
"set softtabstop=2
"set smartindent

" Swap and backups
set noswapfile
set nobackup
set nowritebackup

" Misc
set textwidth=0
set nowrap
"set relativenumber 
set number
set history=1000 
set nocompatible
set backspace=indent,eol,start
set autoread
set hlsearch
set incsearch
set ignorecase
set sessionoptions=blank,buffers,curdir,folds,help,resize,tabpages,winsize

" CtrlP (http://ctrlpvim.github.io/ctrlp.vim)
" set runtimepath^=~/.vim/bundle/ctrlp.vim
" let g:ctrlp_working_path_mode = 'ra'

" FZF (https://github.com/junegunn/fzf.vim)
nnoremap <leader><leader> :FZF<cr>
nnoremap <leader>p :FZF<cr>

" Nerdtree (https://github.com/scrooloose/nerdtree)
nnoremap <C-n> :NERDTreeToggle<cr>
autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif " Close vim if the only window left open is a NERDTree

" Vim Airline (https://github.com/vim-airline/vim-airline)
set laststatus=2
let g:airline#extensions#tabline#enabled = 1

" VimPlug (https://github.com/junegunn/vim-plug)
" Reload .vimrc and :PlugInstall to install plugins.
call plug#begin('~/.vim/plugged')
Plug 'scrooloose/nerdtree'
Plug 'Xuyuanp/nerdtree-git-plugin'
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
Plug 'vim-airline/vim-airline'
Plug 'ervandew/supertab'
Plug 'elixir-lang/vim-elixir'
Plug 'kchmck/vim-coffee-script'
call plug#end()

