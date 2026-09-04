+++
date = '2026-09-04T15:38:16+08:00'
draft = false
title = "Neovim's New Multicursor Support"
toc = true
+++

Multiple cursors landed in Neovim core on September 1. PR [#41587](https://github.com/neovim/neovim/pull/41587), It ships in 0.13, so today you need nightly.

`Q` drops a cursor. `1Q` drops one on every search match. `<C-l>` clears them. Everything you already know about Vim keeps working. That's most of it.

## How it works

This isn't keystroke replay. Each action you take gets captured as an **atom**: the resolved, post-mapping key sequence for one semantic thing, the same material dot-repeat runs on. `x` is captured as `dl`. `viweex` is captured as `viweed`. Then every extra cursor replays that atom in its own context, which is why a visual sequence gets per-cursor extents instead of a fixed-size reselect.

A few things follow from that:

- Cursors are extmarks in the `nvim.multicursor` namespace. That's the whole state. The primary cursor isn't one of them.
- Cursor sets are per-buffer, and a cascade only runs in the current buffer.
- Atoms replay at the completion of a toplevel normal command. A mapping still feeding keys pushes that back, so a mapping cascades as one unit.
- Insert mode previews at each cursor while you type instead of replaying at the end.
- Registers go per-cursor for the session, then join when it ends.
- One cascade is one undo state. Undo and redo never cascade.
- Cascade replays emit no `CmdAtom`. One action, one event, cursors or not.

## Keys

| Key | Effect |
| --- | --- |
| `Q` | Toggle a cursor here. Ends follow-mode. |
| `[count]Q` | Cursor at every match of the last search pattern |
| `{Visual}Q` | Cursor on every selected line, by screen column. Starts follow-mode. |
| `<C-LeftMouse>` | Toggle a cursor at the click. Keeps follow-mode. |
| `q=` | Toggle follow-mode. `1q=` on, `2q=` off. |
| `]C` / `[C` | Next / previous cursor, wraps, takes a count |
| `g<C-a>` | Ascending counter at each cursor |
| `<C-l>` | Clear cursors in the buffer |
| `gQ` | Restore the last cleared set |
| `<C-c>` | Interrupt a cascade |

Turn on `showcmd` and the count shows up there as `2×`, or `=2×` in follow-mode.

# Placing cursors

## Q

The cursor starts at line 1 column 1 unless the keys say otherwise.

```
QjQjx

aaa   │   aa
bbb   │   bb
ccc   │   cc
```

It's a toggle. Press it on a cursor and that cursor goes away; take out the last one and the session ends.

```
QjQk      2 cursors, primary back on line 1
Q         removes the cursor under the primary, 1 left
x

aaa   │   aa
bbb   │   bb
```

If a cursor is sitting on the primary, the edit happens once and the pair merges.

```
Qx

ab   │   b        one deletion, 0 cursors left
```

In operator-pending mode `Q` throws the operator away and places nothing.

```
dQ        the d is gone, no cursor
wx

one two   │   one wo
```

You can't use it inside a macro, recording or executing. It just beeps.

```
qq Q q    no cursor (the Q gets recorded)
@q        no cursor either
Q         works
```

And watch out for `qQ`, which is `q` starting a recording into register `Q`.

## [count]Q

A cursor at every match of the last search pattern, including the one under the primary. The primary doesn't move.

```
gg0*1Q cwXXX<Esc>

foo bar foo   │   XXX bar XXX
baz foo qux   │   baz XXX qux
foobar foo    │   foobar XXX
```

`*` is whole-word, so `foobar` misses. Four cursors before the edit, three after: the one on top of the primary merges away in the first cascade.

Any search works.

```
gg0/ab<CR>1Q x

ab ab ab   │   b b b
xx ab      │   xx b
```

Placement runs through the real search engine, so your case options behave exactly like they do for `n`.

```
:set smartcase                       :set ignorecase
gg0/Foo<CR>1Q x                      gg0/foo<CR>1Q gUiw

Foo foo Foo   │   oo foo oo          Foo foo FOO   │   FOO FOO FOO
```

No previous search, no cursors (E35).

The two placement styles mix.

```
gg0*1Q    2 cursors on the two "foo"
0fbQ      3 cursors, adding "bar"
$x        the primary edits a fourth position

foo bar foo   │   oo ar o
```

## {Visual}Q

Visual mode ends, the primary lands on the first selected line, and every selected line gets a cursor at the primary's screen column. Follow-mode comes on.

```
gg0ll V2j Q iX<Esc>

aaaa   │   aaXaa
bbbb   │   bbXbb
cc     │   ccX          short line: the cursor sits past EOL
dddd   │   dddd
```

Follow-mode is on, so the next motion takes everything with it.

```
jx

aaXaa   │   aaXaa
bbXbb   │   bbbb
ccX     │   cc
dddd    │   ddd
```

Screen column, not byte column. A multibyte character earlier on one line won't throw off the cursors on the others.

```
gg0ll vjQ x

é123     │   é13
abcdef   │   abdef
```

## Mouse

`<C-LeftMouse>` toggles a cursor where you click, without moving the primary or pulling you into another window. Ctrl-click an existing cursor to remove it. Unlike `Q` it leaves follow-mode alone, and it's a no-op in insert mode. Middle-click paste is still one paste at the click point.

## :g and :cdo

`Q` is a normal-mode command, so anything that runs normal-mode commands can place cursors.

```
:g/foo/normal! Q
A!<Esc>

foo a   │   foo a!
bar b   │   bar b
foo c   │   foo c!
baz d   │   baz d
foo e   │   foo e!
```

Put motions in front of the `Q` to pick the column.

```
:g/checkPassword/normal! 0fcQ
cwverifyPassword<Esc>
```

Quickfix works the same, except a range there addresses items, not lines.

```
qflist on lines 1, 2, 4
:cdo normal! Q      3 cursors
3G0                 move the primary off the last item
x

aaa   │   aa
bbb   │   bb
ccc   │   cc          the primary's own edit
ddd   │   dd

:2,3cdo normal! Q   2 cursors, items 2 and 3
```

## Lua

`nvim_mcursor(buf, {row, col})` takes a (1,0)-indexed position and hands back the number of extra cursors. Calling it on an existing cursor is a no-op, not a toggle. Hidden buffers are fine.

```lua
for _, m in ipairs(vim.fn.matchbufline('%', [[\<TODO\>]], 1, '$')) do
  vim.api.nvim_mcursor(0, { m.lnum, m.byteidx })
end
```

Bad input gets you `Invalid cursor line: out of range`, `Invalid 'pos': expected [row, col] array`, or `Invalid buffer`.

# Clearing them

`<C-l>` clears the buffer's cursors on top of its usual `nohlsearch` and `diffupdate`. It's a default mapping, so if you wrap it you need to remap, not feed it noremap.

Clearing takes a snapshot, and `gQ` brings it back, same idea as `gv`.

```
QjQ      cursors on lines 1 and 2
<C-l>    0 cursors
gQ       2 cursors
Gx

aaa   │   aa
bbb   │   bb
ccc   │   ccc
ddd   │   dd
```

The snapshot rides on extmarks, so edits in between shift it.

```
<C-l> ggO<Esc> gQ     the restored cursors moved down a line
```

`:edit!` takes out the cursors and the snapshot together. Clearing part of the namespace removes those cursors without ending the session, so the rest keep follow-mode and the registers don't join yet.

From Lua, clearing the namespace is the same operation, snapshot and all.

```lua
vim.api.nvim_buf_clear_namespace(0, vim.api.nvim_create_namespace('nvim.multicursor'), 0, -1)
```

`<C-c>` interrupts a cascade in flight. What got done is still one undo block and no line ends up half-edited. It doesn't clear anything.

# Normal mode

## Operators

```
QjQjdw

hello world   │   world
foo bar       │   bar
one two       │   two
```

```
QjQj2x

aaaa   │   aa
bbbb   │   bb
cccc   │   cc
```

```
Q2jQ2jdd

a1   │   a2
a2   │   b2
b1   │   c2
b2   │
c1   │
c2   │
```

```
gg0ll QjD              gg0ll QjCX<Esc>

one two      │   on    one two      │   onX
three four   │   th    three four   │   thX
```

```
Qj2clXY<Esc>           Qj~~

abcd   │   XYcd        abc   │   ABc
efgh   │   XYgh        def   │   DEf
```

Backwards:

```
gg$ Qj$cT_M<Esc>       gg$ Qj$d4h

x_abcY    │   x_MY     abcdef   │   af
w_defgZ   │   w_MZ     ghijkl   │   gl
```

Counted objects, and objects that seek forward:

```
Qjc2awX<Esc>                     gg0l Qjci(X<Esc>

one two three   │   Xthree       a()b   │   a(X)b
foo bar baz     │   Xbaz         c()d   │   c(X)d
```

```
Qjci"NEW<Esc>

x "aa" y    │   x "NEW" y
z "bbb" w   │   z "NEW" w
```

Operators that eat a payload character:

```
Qjdf,                  Qj2rZ                  QjgrZ

ab,cd   │   cd         abc   │   ZZc          abc   │   Zbc
wxy,z   │   z          def   │   ZZf          def   │   Zef
```

`r<CR>` terminates itself, no `<Esc>`:

```
gg0l Qjr<CR>

abcd   │   a
efgh   │   cd
       │   e
       │   gh
```

A search as the operator's motion travels with the atom, and each cursor finds its own match:

```
Qjd/find<CR>

aaa find end   │   find end
bbb find end   │   find end
```

Multibyte:

```
Qjx

éàü      │   àü
日本語   │   本語
```

Cursors end up wherever the operator left them, so the next key acts per region:

```
gg0l QjQjdiw           then x

foo bar   │    bar     │   bar
baz qux   │    qux     │   qux
aaa bbb   │    bbb     │   bbb
```

```
gg0l QjguiW            then x

FOO BAR   │   foo BAR  │   oo BAR
BAZ QUX   │   baz QUX  │   az QUX
```

Options apply per cursor:

```
:set autoindent                  :set shiftwidth=2
QjccX<Esc>                       Qj>>

␣␣aaa       │   ␣␣X             foo   │   ␣␣foo
␣␣␣␣␣␣bbb   │   ␣␣␣␣␣␣X         bar   │   ␣␣bar
```

`<C-a>` and `<C-x>` cascade like anything else:

```
Qj<C-x>            then <C-a>

x = 5   │   x = 4      │   x = 5
y = 5   │   y = 4      │   y = 5
```

## Chaining

Positions update after each cascade:

```
QjQ jx             then x

AAAA   │   AAA        │   AA
BBBB   │   BBB        │   BB
CCCC   │   CCC        │   CC
```

Anything that inserts lines shifts the cursors below it, primary included:

```
QjQj oX<Esc>

aaa   │   aaa
bbb   │   X
ccc   │   bbb
      │   X
      │   ccc
      │   X
```

Typeahead behind the cascading key survives:

```
Qj xyy      then p

abc   │   bc          │   bc
def   │   ef          │   bc
                      │   ef
                      │   ef
```

## Dot-repeat

```
QjQj x  .

aaa   │   aa   │   a
bbb   │   bb   │   b
ccc   │   cc   │   c
```

An edit you made *before* placing cursors is still what `.` repeats:

```
gg0x        aaa/bbb/ccc  ->  aa/bbb/ccc
QjQj
.

aa    │   a
bbb   │   bb
ccc   │   cc
```

Inserts and changes repeat too, including across a follow-mode move:

```
Qj iZ<Esc> .           Qj cwX<Esc> q= w q= .

aaa   │   ZZaaa        one two   │   X X
bbb   │   ZZbbb        one two   │   X X
```

# Follow mode

Off by default: only the primary moves.

```
Q j          no cascade, the cursor stays on line 1
q= ll x      now both move

abcd   │   abd
efgh   │   efh
```

`q=` toggles. A count forces instead, so `1q=` always turns it on and `2q=` always turns it off.

```
q= h x          off again: only the primary moves
1q= 1q= h x     forced on, both move
2q= 2q= h x     forced off
```

`$` sends each cursor to its own end of line:

```
Qj q= $ x

abc     │   ab
defgh   │   defg
```

Vertical, display and arrow motions all follow:

```
Q3j q= j x        then k x        then gj x        then gk x

a1   │   a1   │   1    │   1    │
a2   │   2    │   2    │        │
a3   │   a3   │   a3   │   a3   │   a3
b1   │   b1   │   1    │   1    │
b2   │   2    │   2    │        │
b3   │   b3   │   b3   │   b3   │   b3
```

Each cursor keeps its own curswant over short lines:

```
gg04l Q 3jhh      primary at (4,2), cursor at (1,4)
q= jj q= x

ABCDEF   │   ABCDEF
xy       │   xy
GHIJKL   │   GHIJL
MNOPQR   │   MNOPQR
zw       │   zw
STUVWX   │   STVWX
```

Mapped and `<expr>`-mapped motions follow:

```
:nnoremap j gj
Q2j q= j x

a1   │   a1
a2   │   2
b1   │   b1
b2   │   2
```

Jumps don't follow. `<C-o>` and `` ` `` move the primary alone. Scrolling never follows either way, so `<C-d>` is primary-only, and a later edit still cascades to the off-screen cursors while the viewport stays where it was.

Cursors that converge merge, and if they all merge the session ends and follow-mode resets:

```
QjQ q= G q= x

aaa   │   aaa
bbb   │   bbb
ccc   │   cc          one deletion, not three
```

`Q` ends follow-mode. `<C-LeftMouse>` doesn't. `]C` and `[C` don't drag the others.

`q=` while you're recording a macro won't toggle, because the `q` stops the recording first.

A mapping that edits cascades its motions too, even with follow-mode off:

```
:nnoremap gj i<C-j><Esc>k$
gg04l QjQj gj

aaa bbb   │   aaa␣
ccc ddd   │   bbb
eee fff   │   ccc␣
          │   ddd
          │   eee␣
          │   fff
```

# Insert mode

Text shows up at the other cursors as you type it, not at `<Esc>`.

```
QjQj I# <Esc>

puts "one"     │   # puts "one"
puts "two"     │   # puts "two"
puts "three"   │   # puts "three"
```

Cursor moves inside the session cascade live and resolve per cursor:

```
QjQj Aab<Left><Left>X       (still in insert mode)

alpha one     │   alpha oneXab
beta two      │   beta twoXab
gamma three   │   gamma threeXab

<Esc> AZ<Home>Y<Esc>        <Home> is each line's own start

              │   Yalpha oneXabZ
              │   Ybeta twoXabZ
              │   Ygamma threeXabZ

A<S-Left>W<Esc>             word-wise, per cursor

              │   Yalpha WoneXabZ
              │   Ybeta WtwoXabZ
              │   Ygamma WthreeXabZ
```

`<C-g>U` cascades and doesn't split undo:

```
Qj i12<C-g>U<Left>3<Esc>      then u

aa   │   132aa      │   aa
bb   │   132bb      │   bb
```

An absolute jump splits the session and re-anchors:

```
j0Q j0Q gg$ ix<C-Home>y<Esc>

alpha   │   yalphxa
beta    │   xybeta
gamma   │   xygamma
```

`<C-c>` ends the session like `<Esc>` does. The text and the cursors both survive.

Deleting:

```
Qj iXY<BS>Z<Esc>           gg0l Qji<BS>Z<Esc>

aaa   │   XZaaa            abc   │   Zbc
bbb   │   XZbbb            def   │   Zef
```

`<BS>` at column 0 joins with the line above:

```
ggj0 Q2ji<BS><Esc>

aa   │   aabb
bb   │   ccdd
cc   │
dd   │
```

`<CR>` splits:

```
gg02l QjiAB<CR>CD<Esc>

aaXbb   │   aaAB
ccXdd   │   CDXbb
        │   ccAB
        │   CDXdd
```

Entry commands:

```
Q2jOX<Esc>          QjaZ<Esc>          gg$ Qj$IX<Esc>

aaa   │   X         abc   │   aZbc     ␣␣aa     │   ␣␣Xaa
bbb   │   aaa       def   │   dZef     ␣␣␣␣bb   │   ␣␣␣␣Xbb
ccc   │   bbb
      │   X
      │   ccc
```

Insert-mode commands:

```
Qjifoo bar<C-w>X<Esc>       Qji<C-v>u00e9<Esc>      Qj3iZ<Esc>

zz   │   foo Xzz            aaa   │   éaaa          aaa   │   ZZZaaa
yy   │   foo Xyy            bbb   │   ébbb          bbb   │   ZZZbbb
```

Replace mode, including `<BS>` putting back what it overwrote:

```
QjRXY<Esc>                  QjRXY<BS><BS><Esc>

abcdef   │   XYcdef         abcdef   │   abcdef
ghijkl   │   XYijkl         ghijkl   │   ghijkl
```

Abbreviations and `autoindent`:

```
:iabbrev teh the            :set autoindent
Qjiteh <Esc>                QjoX<Esc>

aaa   │   the aaa           ␣␣aa       │   ␣␣aa
bbb   │   the bbb           ␣␣␣␣␣␣bb   │   ␣␣X
                                       │   ␣␣␣␣␣␣bb
                                       │   ␣␣␣␣␣␣X
```

A replayed `<C-u>` on a less-indented line has nothing to eat, and won't backspace through the line boundary:

```
:set autoindent
QjQj o<C-u><Tab>yay<Esc>

␣␣␣␣indented aa   │   ␣␣␣␣indented aa
flat bb           │   →yay
␣␣␣␣indented cc   │   flat bb
                  │   →yay
                  │   ␣␣␣␣indented cc
                  │   →yay
```

`ea` under follow-mode:

```
Qj q= ea!<Esc> q=

one two      │   one! two
three four   │   three! four
```

Completion works. The cascade pauses while a popup is up and the other cursors catch up when it closes, so accepting a candidate lands everywhere:

```
2gg Q j A<C-n><Esc>

wombat   │   wombat
wo       │   wombat
wo       │   wombat
```

Same for `autocomplete` and for a plugin driving `complete()` from an `InsertCharPre` handler.

Autocommand counts match what you'd get with one cursor. `InsertEnter` and `InsertLeave` fire once. `TextChangedI` fires once per typed character, not once per cursor. `TextChanged` fires once for the session. `InsertCharPre` fires once per character, and whatever it does to `v:char` lands at every cursor. `textwidth` wraps per cursor.

Insertion points past EOL get drawn as virtual cells, so `A` at three cursors shows you three carets.

# Visual mode

Each cursor shows its own selection, previewed live, with the display cursor at each selection end. `o` swaps it to the other end. Charwise, linewise and blockwise all render.

The whole keysequence replays, so the extents are per-cursor:

```
Qj viweex

one two three x   │   ␣x
aa bb cc d        │   ␣d
```

```
Qjviwr X                   Q4jVjd

one two   │   XXX two      a   │   c
ab cd     │   XX cd        b   │   d
                           c   │
                           d   │
                           e   │
                           f   │
```

Blockwise:

```
Q2j<C-v>jcX<Esc>     Q2j<C-v>jIX<Esc>     Q2j<C-v>jA!<Esc>

ab   │   Xb          ab   │   Xab         ab   │   a!b
cd   │   Xd          cd   │   Xcd         cd   │   c!d
ef   │   Xf          ef   │   Xef         ef   │   e!f
gh   │   Xh          gh   │   Xgh         gh   │   g!h
```

Payload motions inside the selection:

```
Qjvf,d                     Qjv/two<CR>d

abcd,ef   │   ef           one two   │   wo
wxyz,gh   │   gh           one two   │   wo
```

`<Esc>` puts every cursor on its own selection end, which is a handy way to reposition without turning on follow-mode:

```
gg04l QjQj viw<Esc>x       then 0viwe<Esc>x

aaa bbb ccc   │   aaa bb ccc   │   aaa bb cc
ddd eee fff   │   ddd ee fff   │   ddd ee ff
ggg hhh iii   │   ggg hh iii   │   ggg h iii
```

A selection changed by scrolling the viewport (`V<C-e>` at the window edge) isn't replayable, so it edits the primary only.

# Registers

Every cursor reads and writes its own.

```
Qj yy p

aaa   │   aaa
bbb   │   aaa
      │   bbb
      │   bbb
```

Swap two words everywhere:

```
Qj q= dW E p q=

one two      │   twoone␣
three four   │   fourthree␣
```

Paste each cursor's own yank over its own word:

```
Qj yiw q= w q= viwp

aaa X   │   aaa aaa
bbb Y   │   bbb bbb
```

Jagged line ends, each cursor on its own register:

```
gg$Q j$ x        then p

abc   │   ab     │   abc
de    │   d      │   de
```

Once the last cursor goes, the per-cursor values join in document order, linewise:

```
Qj0Q j0 yiw       buffer unchanged; " is "baz" during the session
<C-l>             " is now  foo\nbar\nbaz\n , type V

foo x
bar y
baz z
```

Named registers join the same way, and one nobody touched is left alone:

```
:let @z = 'PRESET'
Qj0 "ayiw <C-l>

@a  ->  foo\nbar\n
@z  ->  PRESET
```

Last write wins:

```
Qj0 yl x <C-l>

aa    →   @"  is  a\nb\n     the deletes, not the yanks
bb
```

A cursor whose replays never wrote a register contributes nothing, instead of folding in the stale pre-session value.

`TextYankPost` fires per cursor with that cursor's contents. The primary fires first and isn't a replay, which `nvim__mcursor_cascading()` will tell you. The primary's registers are the ones that stick.

Under `clipboard=unnamedplus` the provider syncs once for the primary's own edit and once for the whole cascade, not once per cursor, and what reaches the clipboard is the primary's.

# Undo

One `u` reverts a whole cascade. `<C-r>` puts the cursors back where the edit left them, rather than wherever splice adjustment would have drifted them:

```
QjQj$ IX <Esc>       cursors at column 1
u                    cursors back at column 0
<C-r>                cursors at column 1 again
x

aaa   │   X aaa   │   Xaaa
bbb   │   X bbb   │   Xbbb
ccc   │   X ccc   │   Xccc
```

Each cascade is a step, and a count counts cascades:

```
Q jx x          abc/def  ->  bc/ef  ->  c/f
u               bc/ef
u               abc/def
<C-r><C-r>      c/f
2u              abc/def
```

`Q` is placement, not an edit, so the tree runs straight through the point where you placed cursors:

```
gg0x   xxx/yyy  ->  xx/yyy
Q jx            ->  x/yy
u               ->  xx/yyy
u               ->  xxx/yyy
```

A cascaded macro is one block:

```
:let @q = "iX\<Esc>"
Qj @q        then u        then <C-r>

aaa   │   Xaaa   │   aaa   │   Xaaa
bbb   │   Xbbb   │   bbb   │   Xbbb
```

A mapped undo or redo doesn't cascade. Undo is buffer-global, so cascading it would undo once per cursor and blow straight past the start of the session:

```
:nnoremap <silent> u :<C-u>undo<CR>
QjQj x       aaa/bbb/ccc  ->  aa/bb/cc
u            aaa/bbb/ccc      one undo, not three
```

Undo restores text, never registers. The per-cursor values survive it, so exiting still joins them:

```
Qj0 diw      "foo x"/"bar y"  ->  " x"/" y"
u                              ->  "foo x"/"bar y"
             @"  is still  bar
<C-l>        @"  is  foo\nbar\n
```

`g-`, `g+` and `:earlier` drop every cursor and end the session:

```
Q jx         aaa/bbb  ->  aa/bb    1 cursor
g-           aaa/bbb                0 cursors
g+           aa/bb                  still 0
Q            new session
```

# Macros

`@` cascades:

```
gg0qqxq      record "x"; line 1 becomes "aa"
jQ j0 @q     then @@

aaa   │   aa   │   aa
bbb   │   bb   │   b
ccc   │   cc   │   c
```

So does a macro with an insert session in it:

```
gg0qwA!<Esc>q
jQ j0 @w

aaa   │   aaa!
bbb   │   bbb!
ccc   │   ccc!
```

A count applies at each cursor:

```
2@q      the "x" macro, twice per cursor

aaaa   │   aaaa
bbbb   │   bb
cccc   │   cc
```

A macro typed where there are no cursors cascades in whatever buffer it navigates into, same as a mapping.

# Numbering

```
Qj0Qj0 g<C-a>          Qj0 5g<C-a>

a   │   1a             a   │   5a
b   │   2b             b   │   6b
c   │   3c
```

The primary counts as a slot. If it's sitting on a cursor the pair shares one:

```
QjQj gg0 g<C-a>        2 cursors survive

x   │   1x
y   │   2y
z   │   z
```

The number goes in at the cursor's column, before whatever is there:

```
Qj g<C-a>

x = 5   │   x = 15
y = 5   │   y = 25
```

Through a mapping it applies once, not once per cursor:

```
:nnoremap ,n g<C-a>
QjQj ,n

a   │   1a
b   │   2b
c   │   3c
```

With no cursors it isn't a command and beeps. Plain `<C-a>` still increments.

Start, step and format live on the function behind it. Private module, so pin your version or wrap it in `pcall`:

```lua
require('vim._core.mcursor').number(10, 2, '%d) ')
```

```
Qj0Qj0 then the call above

x   │   10) x
x   │   12) x
x   │   14) x
```

# Jumping between cursors

`]C` and `[C` cycle in position order, wrapping, with a count. They'll scroll the viewport to reach an off-screen cursor, and they never drag the other cursors along, even in follow-mode. No cursors, no move, just a beep.

```
Q2jllQ gg0j       cursors at (1,0) and (3,2), primary on line 2
]C                (3,2)
]C                (1,0)   wrapped
2]C               (1,0)
[C                (3,2)
```

Pair that with the `Q` toggle and you get select-all-then-deselect:

```
1Q        every match
]C ]C     walk
Q         drop this one
ciw...    edit the rest
```

# Folds

The primary keeps normal fold behavior. Replays don't: they act on the per-cursor line inside the fold, and the fold stays closed.

Primary outside the fold:

```
3G0Q :2,4fold gg0 x       then dd

aaa   │   aa    │   bbb        primary deletes line 1
bbb   │   bbb   │   ddd        the cursor deletes only line 3, inside the fold
ccc   │   cc    │
ddd   │   ddd   │
```

Primary inside the fold:

```
4jQ gg :2,3fold 2G dd

aaa   │   aaa        primary is in the closed fold: its dd takes the whole fold
bbb   │   ddd
ccc   │   fff        the cursor on line 5 deletes only its own line
ddd   │
eee   │
fff   │
```

Follow-mode motions ignore closed folds too, so a replayed `j` steps into one. A mapping that turns fold semantics back on mid-cascade (`zN` then `dd`) doesn't change that.

Fold operators cascade; fold toggles don't:

```
4G0Q gg0 zfap      each cursor folds its own paragraph
za                 only the primary's fold toggles
```

# What doesn't cascade

Ex commands. The atom gets emitted with `type = "excmd"` and never replayed:

```
Qj :s/o/O/<CR>

foo   │   foo
foo   │   fOo
```

`:normal!`, and anything else programmatic:

```
Qj
:normal! x        primary only
x                 typed: cascades

aaa   │   aaa   │   aa
bbb   │   bb    │   b
```

API edits shift the cursors but are primary-only themselves:

```
QjQj
:lua vim.api.nvim_buf_set_lines(0, 0, 0, true, { 'zzz' })
x

aaa   │   zzz   │   zzz
bbb   │   aaa   │   aa
ccc   │   bbb   │   bb
      │   ccc   │   cc
```

Also undo and redo, fold toggles, an operator with no effect (an aborted `ysa[` won't drag every cursor onto the same bracket), and an atom captured in one buffer that resolves in another (a mapping ending in `:bnext` doesn't cascade into where it lands).

# Buffers

Cursor sets are per-buffer. A cascade pauses while you're elsewhere and picks up when you come back:

```
:set hidden
Qj                aaa/bbb, 1 cursor
:enew  gg0x       xxx  ->  xx , no cascade into the other buffer
:buffer #         1 cursor still there
2G0x              aa/bb
```

Edits cascade from any window showing the buffer, so `:split` and editing from the new window is fine. Cursors die with their buffer, and `nvim_mcursor()` will happily place them in a hidden one.

# Advanced

## Occurrence operator

This is the thing issue #21334 was asking for. An `operatorfunc` puts a cursor on every occurrence of the word under the cursor within a motion, then your next edit cascades to all of them. They survive because a `g@` with no effect doesn't cascade.

```lua
_G.occur_opfunc = function()
  local ms = vim.fn.matchbufline('%', _G.occur_pat, vim.fn.line("'["), vim.fn.line("']"))
  vim.api.nvim_win_set_cursor(0, { ms[1].lnum, ms[1].byteidx })
  for i = 2, #ms do
    vim.api.nvim_mcursor(0, { ms[i].lnum, ms[i].byteidx })
  end
end

vim.keymap.set('n', 'co', function()
  _G.occur_pat = ([[\<%s\>]]):format(vim.fn.expand('<cword>'))
  vim.o.operatorfunc = 'v:lua.occur_opfunc'
  return 'g@'
end, { expr = true })
```

```
cursor on the first "text"
coip ciwWORD<Esc>

text a text   │   WORD a WORD
b text c      │   b WORD c
```

`coi{`, `coap` and `co3j` all work the same way.

## Follow mode for exactly one motion

`CmdAtom` plus a one-shot autocommand. Returning `true` deletes the autocommand.

```lua
vim.keymap.set('n', 'q-', function()
  vim.cmd('normal! 1q=')
  vim.api.nvim_create_autocmd('CmdAtom', {
    callback = function(ev)
      if ev.data.lhs == 'q-' then
        return
      end
      vim.cmd('normal! 2q=')
      return true
    end,
  })
end)
```

```
QjQj q- ^      every cursor moves to its first non-blank
l              follow mode already ended: primary only

␣␣aaa
␣␣bbb
␣␣ccc
```

## Telling the primary apart in an autocommand

```lua
vim.api.nvim_create_autocmd('TextYankPost', {
  callback = function()
    if vim.api.nvim__mcursor_cascading() then
      return
    end
    -- primary only
  end,
})
```

Double underscore, so it can change under you.

## Cursors from a treesitter query

```lua
local function cursors_from_query(lang, query_str, capture)
  local parser = vim.treesitter.get_parser(0, lang)
  local root = parser:parse()[1]:root()
  local query = vim.treesitter.query.parse(lang, query_str)
  for id, node in query:iter_captures(root, 0, 0, -1) do
    if query.captures[id] == capture then
      local row, col = node:range()
      vim.api.nvim_mcursor(0, { row + 1, col })
    end
  end
end

cursors_from_query('lua', '(function_declaration name: (identifier) @name)', 'name')
```

A cursor on every function name, then `cw` to rename the lot.

## Pruning

Deleting an extmark deletes the cursor, so you can place broadly and filter after:

```lua
local ns = vim.api.nvim_create_namespace('nvim.multicursor')

local function keep_cursors(pred)
  for _, m in ipairs(vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {})) do
    local id, row, col = m[1], m[2], m[3]
    local line = vim.api.nvim_buf_get_lines(0, row, row + 1, true)[1]
    if not pred(line, row + 1, col) then
      vim.api.nvim_buf_del_extmark(0, ns, id)
    end
  end
end

keep_cursors(function(line) return not line:match('^%s*//') end)
```

## Aligning columns

Extmarks move with inserted text, so padding to a shared virtual column is short. Assumes one cursor per line, and skips the primary since it isn't an extmark.

```lua
local function align_cursors()
  local marks = vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {})
  local target = 0
  for _, m in ipairs(marks) do
    target = math.max(target, vim.fn.virtcol({ m[2] + 1, m[3] + 1 }))
  end
  for i = #marks, 1, -1 do
    local row, col = marks[i][2], marks[i][3]
    local pad = target - vim.fn.virtcol({ row + 1, col + 1 })
    if pad > 0 then
      vim.api.nvim_buf_set_text(0, row, col, row, col, { (' '):rep(pad) })
    end
  end
end
```

## Cursors from quickfix, across files

```lua
for _, item in ipairs(vim.fn.getqflist()) do
  if item.valid == 1 and item.bufnr ~= 0 then
    vim.api.nvim_mcursor(item.bufnr, { item.lnum, math.max(item.col - 1, 0) })
  end
end
```

Quickfix items are 1-indexed on both axes, hence `col - 1`. Diagnostics are 0-indexed on both, so those want `lnum + 1` and a bare `col`.

## CmdAtom

One event per action, and cascade replays emit nothing.

`type` is `motion`, `operator`, `insert`, `visual`, `mapping` or `excmd`. `lhs` is what you typed before resolution. `keys` is the resolved sequence in raw bytes: empty means it can't be replayed, nil means the capture was lossy and you should replay `lhs` with `feedkeys` mode `m` instead of `n`. `text` carries the payload, whether that's inserted text, a cmdline or a search. `changed` and `moved` tell you whether the action edited or moved. `atoms` holds ordered subatoms, and it's only non-empty for a composite action.

`nnoremap gj i<C-j><Esc>k$` emits one `mapping` atom whose `atoms` are two inserts plus the motions `k` and `$`. `q=` gets recorded too, so a follow-mode stretch shows up as `q=`, `l`, `l`, `q=`.

The event is deferred, so schedule anything that reacts to it. A custom `.`:

```lua
local last ---@type vim.event.cmdatom.data?
local mc = vim.api.nvim_create_namespace('nvim.multicursor')

vim.api.nvim_create_autocmd('CmdAtom', {
  callback = function(ev)
    if ev.data.changed and ev.data.lhs ~= '.' then
      last = ev.data
    end
  end,
})

vim.keymap.set('n', '.', function()
  if #vim.api.nvim_buf_get_extmarks(0, mc, 0, -1, { limit = 1 }) > 0 then
    vim.api.nvim_feedkeys('.', 'n', false) -- hand it back so it cascades
    return
  end
  vim.schedule(function()
    if last then
      vim.api.nvim_feedkeys(last.keys or last.lhs, last.keys and 'n' or 'm', false)
    end
  end)
end)
```

That multicursor check is the important bit: a replay through `feedkeys` is programmatic and won't cascade. The version in `:h CmdAtom` also filters undo and redo out by comparing `undoseq` against a buffer-local high-water mark. `:h cmdatom-macro` keeps a ring of the last N atoms and turns them into an editable macro in the cmdwin.

# Keymaps

`Q` used to replay the last recorded register, and `{Visual}Q` ran it per selected line. Both are gone. If you miss them:

```lua
vim.keymap.set({ 'n', 'x' }, '<leader>q', 'Q', { remap = false })

vim.keymap.set('n', 'Q', function()
  local reg = vim.fn.reg_recorded()
  if reg == '' then return '' end
  return '@' .. reg
end, { expr = true })
```

`remap = false` is what gets you the builtin `Q` instead of the mapping below it.

Cursor at every occurrence of the word under the cursor:

```lua
vim.keymap.set('n', '<leader>*', function()
  local word = vim.fn.expand('<cword>')
  if word == '' then return end
  vim.fn.setreg('/', [[\<]] .. vim.fn.escape(word, [[\/]]) .. [[\>]])
  vim.v.hlsearch = 1
  vim.cmd('normal! 1Q')
end)
```

`:Cursors {pattern}`, range-aware:

```lua
vim.api.nvim_create_user_command('Cursors', function(opts)
  local first = opts.range > 0 and opts.line1 or 1
  local last = opts.range > 0 and opts.line2 or vim.fn.line('$')
  for _, m in ipairs(vim.fn.matchbufline('%', opts.args, first, last)) do
    vim.api.nvim_mcursor(0, { m.lnum, m.byteidx })
  end
end, { nargs = 1, range = true })
```

`:Cursors \d\+` hits every number, `:'<,'>Cursors ,` every comma in the selection.

Cursor on every error:

```lua
vim.keymap.set('n', '<leader>me', function()
  for _, d in ipairs(vim.diagnostic.get(0, { severity = vim.diagnostic.severity.ERROR })) do
    vim.api.nvim_mcursor(0, { d.lnum + 1, d.col })
  end
end)
```

Escape clears cursors when there are any. Clear the namespace directly rather than feeding `<C-l>`, which is a mapping and would need `remap = true` to fire:

```lua
vim.keymap.set('n', '<Esc>', function()
  local n = #vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { limit = 1 })
  if n > 0 then
    vim.api.nvim_buf_clear_namespace(0, ns, 0, -1) -- snapshots for gQ, same as CTRL-L
  else
    vim.cmd('nohlsearch')
  end
end)
```

Colors:

```lua
vim.api.nvim_set_hl(0, 'MCursor', { reverse = true })
vim.api.nvim_set_hl(0, 'MCursorVisual', { link = 'Visual' })
```

`reverse` is the safe pick. Linking to `Cursor` sounds right until you remember how many colorschemes leave `Cursor` invisible in the terminal.

If you share a config with a machine still on 0.12:

```lua
if vim.api.nvim_mcursor then
  -- ...
end
```

# Things that will bite you

Two cursors on one line do edit at their own columns, for column-local operators:

```
Q4l x        then x

abcdef   │   bcdf   │   cd
```

But an edit that shifts columns shifts them relative to each other, and linewise operators aren't deduplicated for same-line cursors yet, so `dd` there runs once per cursor.

The rest of the list:

- `g-`, `g+` and `:earlier` end the session, and `gQ` can't bring the cursors back.
- `:e!` and `autoread` reloads clear the cursors and the `gQ` snapshot.
- Undo restores text, not registers.
- `g<C-a>` inserts before the character at the cursor's column, and `$` stops on the last character, so appending numbers to line ends needs `nvim_mcursor()` at an exact byte column.
- `Q` is quietly unavailable inside a macro, and `qQ` starts a recording.
- `iw` and `cw` are still word objects. They won't split `camelCase`. Use `:%s///g` for substrings.
- Ex commands don't cascade.

# Terminals

Nvim asks for the [Kitty multiple-cursors protocol](https://github.com/kovidgoyal/kitty/blob/master/docs/multiple-cursors-protocol.rst) at startup and only uses it if the reply advertises cursor shape 29. When it does, you get real terminal cursors instead of `MCursor` cell highlights, including in unfocused splits. To force the fallback:

```lua
require('vim._core.mcursor').tty_cursors(false)
```
