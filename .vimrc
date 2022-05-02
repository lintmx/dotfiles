" Use Vim settings
set nocompatible
filetype off

" Vundle
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

" Plugin
Plugin 'VundleVim/Vundle.vim'
Plugin 'Lokaltog/vim-powerline'
Plugin 'nathanaelkane/vim-indent-guides'
Plugin 'scrooloose/nerdcommenter'
Plugin 'scrooloose/nerdtree'
Plugin 'altercation/vim-colors-solarized'

call vundle#end()
filetype plugin indent on

" Base settings
set number
set ruler
set showcmd
set nowrap
set nobackup
set nowritebackup
set noswapfile
set autochdir
set incsearch
set ignorecase
set laststatus=2
set cursorline
set foldmethod=syntax
set nofoldenable
set showmatch

" Theme
syntax on
syntax enable
set background=dark
let g:solarized_termtrans = 256
" set termguicolors
colorscheme solarized

" Tab settings
set tabstop=4
set shiftwidth=4
set shiftround
set expandtab
" set list listchars=tab:»·,trail:·

" sudo save
command W w !sudo tee % > /dev/null

" Hot key settings
nnoremap <F2> :set nonumber!<CR>:set foldcolumn=0<CR>
nnoremap <F4> :set invpaste paste?<CR>
set pastetoggle=<F4>
set showmode

" vim-powerline
let g:Powerline_colorscheme='solarized256'

" vim-indent-guides
let g:indent_guides_enable_on_vim_startup=1
let g:indent_guides_start_level=2
let g:indent_guides_guide_size=1

" nerdtree
nnoremap <F3> :NERDTreeToggle<CR>
let NERDTreeWinSize=32
let NERDTreeWinPos="right"
let NERDTreeShowHidden=1
let NERDTreeMinimalUI=1
let NERDTreeAutoDeleteBuffer=1

