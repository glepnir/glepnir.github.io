+++
date = '2026-02-21T20:45:11+08:00'
title = 'A Better Indent Line Implementation'
toc = true
+++

# I Built Another Indent Guide

![indent.png](/images/indent.png)

So I made [indentmini.nvim](https://github.com/nvimdev/indentmini.nvim) a while
back. Minimal indent guide plugin, pretty fast, people seem to like it. It works
by using `nvim_set_decoration_provider` to draw virtual text on every visible
line during each redraw cycle. I spent a ton of time optimizing it — bit-packing
line data into integers, calling Neovim's C functions through FFI, all that fun
stuff.

But the whole time there was this thing nagging me. Neovim already has
`leadmultispace` in `listchars`. You set it to something like `┆···` (guide char
+ spaces) and Neovim renders indent guides on every line that has leading
whitespace. For free. At the C level. No plugin needed.

The only thing it can't do is blank lines. Blank lines have no text, so there's
no leading whitespace to replace. And that's literally the only gap.

So I thought — what if the plugin just... handled blank lines? And nothing else?

## How It Works

**Non-blank lines:** One autocmd sets `leadmultispace` when a buffer is opened
or shiftwidth changes. Done. The plugin never touches these lines again.

```lua
local function guides(bufnr)
  if vim.list_contains(opt.exclude_filetype, vim.bo.filetype) then
    return
  end
  local sw = get_step(bufnr)
  local indent_char = opt.char .. (' '):rep(sw - 1)
  vim.opt_local.listchars:append({ leadmultispace = indent_char })
end
```

**Blank lines:** A decoration provider runs `on_win` to figure out what indent
each blank line should have, then `on_line` draws the guides with ephemeral
extmarks.

That's the whole plugin. Non-blank lines are Neovim's problem. Blank lines are mine.

## Figuring Out Blank Line Indents

This is the only interesting part. A blank line has no text, so you have to
figure out its indent from surrounding context. Two approaches depending on
what's available.

**If TreeSitter is active**, just ask the syntax tree. Get the node at the blank
line, walk up to its parent, grab the parent's indent and add one level:

```lua
local node = ts.get_node({ bufnr = bufnr, pos = { row, 0 } })
local parent = node:parent()
local p_srow = parent:range()
indent = buf_get_indent(bufnr, p_srow + 1) + step
```

**If there's no TreeSitter**, search up and down for the nearest non-blank lines
and take the max:

```lua
local up = search_nearest(c, row - 1, UP, bufnr)
local down = search_nearest(c, row + 1, DOWN, bufnr)
indent = math.max(up, down)
```

Why max? Picture this:

```c
if (true) {     // indent 4
                // blank — up=4, down=8
    foo();      // indent 8
}
```

The blank line is inside the block, so it should show guides up to the deeper
level. Max gets that right.

The search function handles both directions with a single implementation — just
pass -1 or 1. And there's a `nonblank` cache so every line's indent gets
computed at most once. First pass through the viewport caches all non-blank line
indents. When searching for blank line context, the lookup hits the cache and
returns immediately. Even lines outside the viewport get cached on first access
so adjacent blank lines don't repeat the work.

```lua
local function search_nearest(c, row, direction, bufnr)
  local r = row
  while r >= 0 and r < c.count do
    if c.nonblank[r] then
      return c.nonblank[r]
    end
    local text = buf_get_line(bufnr, r)
    if not is_blank(text) then
      local indent = buf_get_indent(bufnr, r + 1)
      c.nonblank[r] = indent
      return indent
    end
    r = r + direction
  end
  return 0
end
```

## Rendering Blank Lines

The `on_line` callback is short. Non-blank line? Return immediately. Blank line?
Read the precomputed indent, loop through levels, place extmarks:

```lua
on_line = function(_, winid, bufnr, row)
  local c = ctx[winid]
  if not c or not c.blank[row] then
    return
  end
  local indent = c.indent[row]
  if not indent or indent <= 0 then
    return
  end
  for level = opt.minlevel, math.floor(indent / step) do
    local col = (level - 1) * step
    api.nvim_buf_set_extmark(bufnr, ns, row, 0, {
      virt_text = { { opt.char, opt.hl } },
      virt_text_pos = 'overlay',
      ephemeral = true,
      virt_text_win_col = col - c.leftcol,
    })
  end
end
```

Since blank lines have zero length, you can't use column offsets —
`virt_text_win_col` positions the guide visually. Subtracting `leftcol` handles
horizontal scrolling.

## FFI

I use LuaJIT FFI to call Neovim internals directly — `ml_get_buf` for line text,
`get_sw_value` for shiftwidth. Way faster than the Lua API for hot paths.
Used `get_indent_buf` for computing indentation to support multiple windows.

## indentmini vs This

indentmini renders every line — it uses a snapshot system with bit-packed data,
handles all the edge cases around mixed tabs/spaces, supports `only_current`
mode for highlighting just the current block, all that. It's a proper plugin.

This new thing is more of an experiment. Push as much as possible onto Neovim's
native rendering and only fill in the gap. Less code, less work per redraw, but
also fewer features. Different tradeoffs.

The code is up on [GitHub](https://github.com/glepnir/nvim/blob/main/lua/private/indent.lua) if you want to poke at it.
