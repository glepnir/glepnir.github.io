---
title: "You Don't Need Nerdfont Patch"
date: 2023-12-06T20:09:53+08:00
draft: false
description: "You Don't Need Nerdfont Patch"
tags: [terminal, neovim]
categories: [terminal, neovim]
---

## You Don't Need NerdFont Symbol Patch

In fact you don't need a font which build with nerd font symbol patch. Nerd font has provide 
[Nerd Fonts Symbols Only](https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/NerdFontsSymbolsOnly.zip) font
you can only install it. then just use this font for symbols, Use your favorite font for code.

## Terminal Config

It's easy to config in iterm2,kitty etc modern terminal. Eg i use kitty in arch or mac. In kitty
config file you need config symbol map. When symbol unicode match in symbol map kitty will use this
font to render symbol. like in my config `~/.config/kitty.conf` i have these lines:

```text
# "Nerd Fonts - Pomicons"
symbol_map  U+E000-U+E00D Symbols Nerd Font Mono

# "Nerd Fonts - Powerline"
symbol_map U+e0a0-U+e0a2,U+e0b0-U+e0b3 Symbols Nerd Font Mono

# "Nerd Fonts - Powerline Extra"
symbol_map U+e0a3-U+e0a3,U+e0b4-U+e0c8,U+e0cc-U+e0d2,U+e0d4-U+e0d4 Symbols Nerd Font Mono

# "Nerd Fonts - Symbols original"
symbol_map U+e5fa-U+e62b Symbols Nerd Font Mono

# "Nerd Fonts - Devicons"
symbol_map U+e700-U+e7c5 Symbols Nerd Font Mono
```

you con config a range of symbol unicode. now you will have a correct symbol render and you can use
any code font which you favorite.

Enjoy :)
