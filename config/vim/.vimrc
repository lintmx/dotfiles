" Vim 基础设置
set nocompatible
filetype plugin off

" vim-plug 插件管理
call plug#begin('~/.vim/plugged')

Plug 'nathanaelkane/vim-indent-guides'
Plug 'preservim/nerdcommenter'
Plug 'preservim/nerdtree'
Plug 'tpope/vim-surround'

call plug#end()
filetype plugin indent on

" 基础编辑设置
set number
set ruler
set showcmd
set nowrap
set nobackup
set nowritebackup
set incsearch
set hlsearch
set ignorecase
set smartcase
set laststatus=2
set cursorline
set foldmethod=indent
set nofoldenable
set showmatch
set wildmenu
set wildmode=longest:full,full
set completeopt=menuone,noinsert,noselect
set hidden
set autoread
set splitbelow
set splitright
set scrolloff=5
set sidescrolloff=5
" set mouse=a
set updatetime=300
set undofile
set undodir=~/.vim/undo//

" 主题设置
syntax on

" 缩进与 Tab 设置
set tabstop=4
set shiftwidth=4
set softtabstop=4
set shiftround
set expandtab
set smartindent
" set list listchars=tab:»·,trail:·

" 以 sudo 权限写回当前文件
command W w !sudo tee % > /dev/null

" 快捷键设置
let mapleader=" "
nnoremap <F2> :set nonumber!<CR>:set foldcolumn=0<CR>
nnoremap <F4> :set invpaste paste?<CR>
nnoremap <silent> <leader><space> :nohlsearch<CR>
nnoremap <silent> <leader>ig :IndentGuidesToggle<CR>
set pastetoggle=<F4>

if has('clipboard')
  set clipboard=unnamed
endif

" vim-indent-guides 相关设置
let g:indent_guides_start_level=2
let g:indent_guides_guide_size=1

" nerdtree 相关设置
nnoremap <F3> :NERDTreeToggle<CR>
let NERDTreeWinSize=32
let NERDTreeWinPos="right"
let NERDTreeShowHidden=1
let NERDTreeMinimalUI=1
let NERDTreeAutoDeleteBuffer=1
