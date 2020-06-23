+++
author = "raphael"
title = "Dashboard vim plugin"
date = "2020-06-10"
description = "dashboard-nvim a startup screen of vim/neovim"
tags = ["vim"]
categories = ["vim"]
+++

## Dashboard

Dashboard-nvim 是一个 vim/neovim 的首屏启动插件。灵感来源于 doom emacs。
功能也很丰富。

<!--more-->

## 与 startify 的区别

- startify 是个很棒的插件，提供的功能都是采取文件列表的形式，但是我们也只是打开一个文件获取跳到一个 mark 或者恢复一个 session，一大堆的列表并没有什么用还占据了很多空间。所以 dashboard 使用 fuzzy search 插件来弹出菜单，提供了更多的功能，而且更美观，灵感来源于 doom emacs 的 dashboard 。

## 安装

推荐使用插件管理器来安装，例如 vim-plug 或者 dein。

- vim-plug

```vim
Plug 'hardcoreplayers/dashboard-nvim'
```

- dein

```vim
call dein#add('hardcoreplayers/dashboard-nvim')
```

## 最小 Vimrc

- dashboard-nvim with vim-clap

```viml
Plug 'hardcoreplayers/dashboard-nvim'
Plug 'liuchengxu/vim-clap'

let g:mapleader="\<Space>"
nmap <Leader>ss :<C-u>SessionSave<CR>
nmap <Leader>sl :<C-u>SessionLoad<CR>
nnoremap <silent> <Leader>fh :<C-u>Clap history<CR>
nnoremap <silent> <Leader>ff :<C-u>Clap files ++finder=rg --ignore --hidden --files<cr>
nnoremap <silent> <Leader>tc :<C-u>Clap colors<CR>
nnoremap <silent> <Leader>fa :<C-u>Clap grep2<CR>
nnoremap <silent> <Leader>fb :<C-u>Clap marks<CR>

let g:dashboard_custom_shortcut={
  \ 'last_session' : 'SPC s l',
  \ 'find_history' : 'SPC f h',
  \ 'find_file' : 'SPC f f',
  \ 'change_colorscheme' : 'SPC t c',
  \ 'find_word' : 'SPC f a',
  \ 'book_marks' : 'SPC f b',
  \ }

```

- dashboard-nvim with fzf.vim

```viml
Plug 'hardcoreplayers/dashboard-nvim'
Plug 'junegunn/fzf.vim'

let g:mapleader="\<Space>"
nmap <Leader>ss :<C-u>SessionSave<CR>
nmap <Leader>sl :<C-u>SessionLoad<CR>
nnoremap <silent> <Leader>fh :History<CR>
nnoremap <silent> <Leader>ff :Files<CR>
nnoremap <silent> <Leader>tc :Colors<CR>
nnoremap <silent> <Leader>fa :Rg<CR>
nnoremap <silent> <Leader>fb :Marks<CR>

let g:dashboard_custom_shortcut={
  \ 'last_session'       : 'SPC s l',
  \ 'find_history'       : 'SPC f h',
  \ 'find_file'          : 'SPC f f',
  \ 'change_colorscheme' : 'SPC t c',
  \ 'find_word'          : 'SPC f a',
  \ 'book_marks'         : 'SPC f b',
  \ }
```

## 选项

更多的选项可以参考 README.
[dashboard-nvim](https://github.com/hardhardcoreplayers/dashboard-nvim)
