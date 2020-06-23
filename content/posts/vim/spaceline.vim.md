+++
author = "raphael"
title = "Spaceline vim"
date = "2020-06-05"
description = "Vim statusline like emacs spaceline"
tags = ["vim"]
categories = ["vim"]
+++

## Spaceline

一直很喜欢 spacemacs 的 spaceline。也曾经尝试使用 emacs 例如 spacemacs 和 doom
奈何 emacs 给我的体验真的是非常糟糕。放弃了 emacs。还是 vim 香。所以我就在
vim 中实现了一个类似的不过照着我的喜欢进行了修改和添加。

## 安装

使用 vim 插件管理器

```vim
Plug 'hardcoreplayers/spaceline.vim'
```

## 必要插件

coc.nvim 插件里的 git 的分支和 git 的 diff 都是使用了 coc 的扩展 coc-git 所以需要安装 coc.

## TODO

- 支持 nvim-lsp (已经支持了在 0.4.2)

- 移除 coc-git 的依赖(git 的分支已经支持了，git 的 diff 还在进行中)
