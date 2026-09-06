+++
date = '2026-09-04T15:38:16+08:00'
draft = false
title = "Neovim's New Multicursor Support"
toc = true
+++

Multiple cursors landed in Neovim core on September 1. PR
[#41587](https://github.com/neovim/neovim/pull/41587), titled "MC HAMMER". It
ships in 0.13, so today you need nightly.

`Q` drops a cursor. `1Q` drops one on every search match. `<C-l>` clears them.
Everything you already know about Vim keeps working. That's most of it.

## Reading the examples

Every block below is the screen. Steps are separated by a line starting with `-`
and the keys that got you there.

`│` is a cursor, sitting just left of the character it's on, so `│abc` means the
cursor is on the `a`. Past EOL it sits after the last character. Every cursor
looks the same, including the one you're actually driving — Neovim calls that
one the primary, and where the difference matters the note says so. Two cursors
in the same cell draw one bar, same as the real thing.

`[...]` is a visual selection and `␣` is a space worth pointing at. Where a
step's cursor positions don't matter, the screen just shows text.

## How it works

This isn't keystroke replay. Each action you take gets captured as an **atom**:
the resolved, post-mapping key sequence for one semantic thing, the same
material dot-repeat runs on. `x` is captured as `dl`. `viweex` is captured as
`viweed`. Then every extra cursor replays that atom in its own context, which is
why a visual sequence gets per-cursor extents instead of a fixed-size reselect.

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
│aaa
 bbb
 ccc

- Q          nothing moves: the new cursor is exactly where you already are

│aaa
 bbb
 ccc

- j          you move down, it doesn't

│aaa
│bbb
 ccc

- Q          again, no visible change until you move

│aaa
│bbb
 ccc

- j

│aaa
│bbb
│ccc

- x          your own edit runs first, then each cursor replays "dl"

│aa
│bb
│cc
```

It's a toggle. Press it on a cursor and that cursor goes away. Neither the drop
nor the removal shows up on screen when you're standing on the spot, which is
what the `2×` in `showcmd` is for.

```
│aaa
 bbb

- Q          a cursor, right under you

│aaa
 bbb

- Q          and gone again

│aaa
 bbb

- QjQk       one on each line, then back up to line 1

│aaa
│bbb

- Q          takes out the cursor under you. Still two bars: one of them is you.

│aaa
│bbb

- x

│aa
│bb
```

Take out the last one and the session ends. Same thing happens implicitly when a
cursor is sitting where you are: the edit runs once and the pair merges.

```
│ab

- Q          a cursor, right under you

│ab

- x          one deletion, not two, and no cursors left

│b
```

In operator-pending mode `Q` throws the operator away and places nothing.

```
│one two

- dQ         the d is gone, and no cursor either

│one two

- w          so this is just a motion

 one │two

- x

 one │wo
```

You can't use it inside a macro, recording or executing. It just beeps.

```
qq Q q       nothing placed (the Q still gets recorded)
@q           nothing placed
Q            works
```

And watch out for `qQ`, which is `q` starting a recording into register `Q`.

## [count]Q

A cursor at every match of the last search pattern, including the one under the
primary. The primary doesn't move.

```
│foo bar foo
 baz foo qux
 foobar foo

- *          whole-word search, primary jumps to the next match

 foo bar │foo
 baz foo qux
 foobar foo

- 1Q         a cursor at every match. "foobar" isn't a whole word, so it misses.

│foo bar │foo
 baz │foo qux
 foobar │foo

- cwXXX<Esc>   the one you're standing on merges away, so nothing gets edited twice

XX│X bar XX│X
 baz XX│X qux
 foobar XX│X
```

Any search works, and several matches on one line are fine.

```
│ab ab ab
 xx ab

- /ab<CR>

 ab │ab ab
 xx ab

- 1Q

│ab │ab │ab
 xx │ab

- x

│b │b │b
 xx │b
```

Placement runs through the real search engine, so your case options behave
exactly like they do for `n`.

```
:set ignorecase

│Foo foo FOO

- /foo<CR>

 Foo │foo FOO

- 1Q         all three

│Foo │foo │FOO

- gUiw

 FOO FOO FOO
```

```
:set smartcase

│Foo foo Foo

- /Foo<CR>   the capital F forces case-sensitivity

 Foo foo │Foo

- 1Q         only the two "Foo"s

│Foo foo │Foo

- x

│oo foo │oo
```

No previous search, no cursors (E35).

The two placement styles mix.

```
│foo bar foo

- *

 foo bar │foo

- 1Q

│foo bar │foo

- 0fb        over to "bar"

│foo │bar │foo

- Q          now "bar" is a cursor too, not just where you happen to be

│foo │bar │foo

- $          and you go edit a fourth position

│foo │bar │fo│o

- x

│oo │ar │o
```

## {Visual}Q

Visual mode ends, the primary lands on the first selected line, and every
selected line gets a cursor at the primary's screen column. Follow-mode comes
on.

```
│aaaa
 bbbb
 cc
 dddd

- gg0ll

 aa│aa
 bbbb
 cc
 dddd

- V2j

[aaaa]
[bbbb]
[cc]
 dddd

- Q          you land on the first selected line, one cursor per line

 aa│aa
 bb│bb
 cc│         short line: the cursor sits past EOL
 dddd

- iX<Esc>

 aa│Xaa
 bb│Xbb
 cc│X
 dddd
```

Follow-mode is on, so the next motion takes everything with it.

```
- j

 aaXaa
 bb│Xbb
 cc│X
 dd│dd

- x

 aaXaa
 bb│bb
 c│c
 dd│d
```

Screen column, not byte column. A multibyte character earlier on one line won't
throw off the cursors on the others.

```
│é123
 abcdef

- gg0ll      two screen columns right, onto "2"

 é1│23
 abcdef

- vjQ

 é1│23
 ab│cdef     same screen column, different byte column

- x

 é1│3
 ab│def
```

## Mouse

`<C-LeftMouse>` toggles a cursor where you click, without moving the primary or pulling you into another window.

```
│aaa
 bbb
 ccc

- <C-LeftMouse> on line 3

│aaa
 bbb
│ccc

- x

│aa
 bbb
│cc

- <C-LeftMouse> on line 3 again

│aa
 bbb
 cc
```

Unlike `Q` it leaves follow-mode alone, and it's a no-op in insert mode.
Middle-click paste is still one paste at the click point.

## :g and :cdo

`Q` is a normal-mode command, so anything that runs normal-mode commands can place cursors.

```
│foo a
 bar b
 foo c
 baz d
 foo e

- :g/foo/normal! Q      a cursor per match, and :g leaves you on the last one

│foo a
 bar b
│foo c
 baz d
│foo e

- A!<Esc>

 foo a│!
 bar b
 foo c│!
 baz d
 foo e│!
```

Put motions in front of the `Q` to pick the column.

```
:g/checkPassword/normal! 0fcQ
cwverifyPassword<Esc>
```

Quickfix works the same, except a range there addresses items, not lines.

```
qflist on lines 1, 2, 4

│aaa
 bbb
 ccc
 ddd

- :cdo normal! Q

│aaa
│bbb
 ccc
│ddd

- 3G0        step off the last item, or it gets edited twice

│aaa
│bbb
│ccc
│ddd

- x

│aa
│bb
│cc
│dd
```

`:2,3cdo normal! Q` gives you 2 cursors, on items 2 and 3.

## Lua

`nvim_mcursor(buf, {row, col})` takes a (1,0)-indexed position and hands back
the number of extra cursors. Calling it on an existing cursor is a no-op, not a
toggle. Hidden buffers are fine.

```lua
for _, m in ipairs(vim.fn.matchbufline('%', [[\<TODO\>]], 1, '$')) do
  vim.api.nvim_mcursor(0, { m.lnum, m.byteidx })
end
```

Bad input gets you `Invalid cursor line: out of range`, `Invalid 'pos': expected [row, col] array`, or `Invalid buffer`.

# Clearing them

`<C-l>` clears the buffer's cursors on top of its usual `nohlsearch` and
`diffupdate`. It's a default mapping, so if you wrap it you need to remap, not
feed it noremap.

Clearing takes a snapshot, and `gQ` brings it back, same idea as `gv`.

```
│aaa
 bbb
 ccc
 ddd

- QjQ

│aaa
│bbb
 ccc
 ddd

- <C-l>

 aaa
│bbb
 ccc
 ddd

- gQ

│aaa
│bbb
 ccc
 ddd

- G

│aaa
│bbb
 ccc
│ddd

- x

│aa
│bb
 ccc
│dd
```

The snapshot rides on extmarks, so edits in between shift it.

```
│aa
│bb
 ccc
│dd

- <C-l>

 aa
 bb
 ccc
│dd

- ggO<Esc>   a new line on top

│
 aa
 bb
 ccc
 dd

- gQ         the restored cursors moved down with the text

│
│aa
│bb
 ccc
 dd
```

`:edit!` takes out the cursors and the snapshot together. Clearing part of the
namespace removes those cursors without ending the session, so the rest keep
follow-mode and the registers don't join yet.

From Lua, clearing the namespace is the same operation, snapshot and all.

```lua
vim.api.nvim_buf_clear_namespace(0, vim.api.nvim_create_namespace('nvim.multicursor'), 0, -1)
```

`<C-c>` interrupts a cascade in flight. What got done is still one undo block
and no line ends up half-edited. It doesn't clear anything.

# Normal mode

## Operators

```
QjQj

│hello world
│foo bar
│one two

- dw

│world
│bar
│two
```

```
QjQj

│aaaa
│bbbb
│cccc

- 2x

│aa
│bb
│cc
```

```
Q2jQ2j

│a1
 a2
│b1
 b2
│c1
 c2

- dd

│a2
│b2
│c2
```

`D` and `C`, from column 2:

```
gg0ll Qj

 on│e two
 th│ree four

- D

 o│n
 t│h
```

```
gg0ll Qj

 on│e two
 th│ree four

- CX<Esc>

 on│X
 th│X
```

```
Qj

│abcd
│efgh

- 2clXY<Esc>

X│Ycd
X│Ygh
```

```
Qj

│abc
│def

- ~~         toggle case, twice, advancing each time

AB│c
DE│f
```

Backwards:

```
gg$ Qj$

 x_abc│Y
 w_defg│Z

- cT_M<Esc>

 x_│MY
 w_│MZ
```

```
gg$ Qj$

 abcde│f
 ghijk│l

- d4h

 a│f
 g│l
```

Counted objects:

```
Qj

│one two three
│foo bar baz

- c2awX<Esc>

│Xthree
│Xbaz
```

Objects that seek forward find their own target per cursor:

```
gg0l Qj

 a│()b
 c│()d

- ci(X<Esc>

 a(│X)b
 c(│X)d
```

```
Qj

│x "aa" y
│z "bbb" w

- ci"NEW<Esc>

 x "NE│W" y
 z "NE│W" w
```

Operators that eat a payload character carry it along:

```
Qj

│ab,cd
│wxy,z

- df,

│cd
│z
```

```
Qj

│abc
│def

- 2rZ

Z│Zc
Z│Zf
```

```
Qj

│abc
│def

- grZ

│Zbc
│Zef
```

`r<CR>` terminates itself, no `<Esc>`:

```
gg0l Qj

 a│bcd
 e│fgh

- r<CR>

 a
│cd
 e
│gh
```

A search as the operator's motion travels with the atom, and each cursor finds its own match:

```
Qj

│aaa find end
│bbb find end

- d/find<CR>

│find end
│find end
```

Multibyte:

```
Qj

│éàü
│日本語

- x

│àü
│本語
```

Cursors end up wherever the operator left them, so the next key acts per region:

```
gg0l QjQj

 f│oo bar
 b│az qux
 a│aa bbb

- diw        each cursor is left where its word was

│␣bar
│␣qux
│␣bbb

- x

│bar
│qux
│bbb
```

```
gg0l Qj

 F│OO BAR
 B│AZ QUX

- guiW       cursor lands at the region start

│foo BAR
│baz QUX

- x

│oo BAR
│az QUX
```

Options apply per cursor:

```
:set autoindent
Qj

␣␣│aaa
␣␣␣␣␣␣│bbb

- ccX<Esc>   each line keeps its own indent

␣␣│X
␣␣␣␣␣␣│X
```

```
:set shiftwidth=2
Qj

│foo
│bar

- >>

␣␣│foo
␣␣│bar
```

`<C-a>` and `<C-x>` cascade like anything else:

```
Qj

│x = 5
│y = 5

- <C-x>

 x = │4
 y = │4

- <C-a>

 x = │5
 y = │5
```

## Chaining

Positions update after each cascade, so you can just keep going.

```
QjQ

│AAAA
│BBBB
 CCCC

- j

│AAAA
│BBBB
│CCCC

- x

│AAA
│BBB
│CCC

- x

│AA
│BB
│CC
```

Anything that inserts lines shifts the cursors below it, primary included:

```
QjQj

│aaa
│bbb
│ccc

- oX<Esc>

 aaa
│X
 bbb
│X
 ccc
│X
```

Typeahead behind the cascading key survives:

```
Qj

│abc
│def

- xyy        "x" cascades, the queued "yy" survives and cascades too

│bc
│ef

- p          each cursor pastes what it yanked

 bc
│bc
 ef
│ef
```

## Dot-repeat

```
QjQj

│aaa
│bbb
│ccc

- x

│aa
│bb
│cc

- .

│a
│b
│c
```

An edit you made *before* placing cursors is still what `.` repeats:

```
│aaa
 bbb
 ccc

- x

│aa
 bbb
 ccc

- QjQj

│aa
│bbb
│ccc

- .

│a
│bb
│cc
```

Inserts and changes repeat too:

```
Qj

│aaa
│bbb

- iZ<Esc>

│Zaaa
│Zbbb

- .

│ZZaaa
│ZZbbb
```

Including across a follow-mode move:

```
Qj

│one two
│one two

- cwX<Esc>

│X two
│X two

- q= w q=    every cursor onto its own second word

 X │two
 X │two

- .

 X │X
 X │X
```

# Follow mode

Off by default: only the primary moves.

```
│abcd
 efgh

- Q

│abcd
 efgh

- j          no cascade: you move, the cursor doesn't

│abcd
│efgh

- q= ll      now both move

 ab│cd
 ef│gh

- x

 ab│d
 ef│h
```

`q=` toggles it, and a count forces instead: `1q=` always on, `2q=` always off. Picking up where that left off:

```
 ab│d
 ef│h

- q= h       off again, so only you move

 ab│d
 e│fh

- x

 a│b
 e│h

- 1q= 1q= h  forced on, both move

│ab
│eh

- x

│b
│h

- 2q= 2q=    forced off
- A!<Esc>    edits cascade either way

 b│!
 h│!

- h

 b│!
│h!

- x

│b
│!
```

`$` sends each cursor to its own end of line:

```
Qj q=

│abc
│defgh

- $

 ab│c
 defg│h

- x

 a│b
 def│g
```

Vertical, display and arrow motions all follow:

```
Q 3j q=

│a1
 a2
 a3
│b1
 b2
 b3

- j x

 a1
│2
 a3
 b1
│2
 b3

- k x

│1
 2
 a3
│1
 2
 b3

- gj x

 1
│
 a3
 1
│
 b3

- gk x       both lines are empty now

│

 a3
│

 b3
```

Each cursor keeps its own curswant over short lines:

```
gg04l Q 3jhh

 ABCD│EF
 xy
 GHIJKL
 MN│OPQR
 zw
 STUVWX

- q= jj q=   the short lines don't reset anybody's column

 ABCDEF
 xy
 GHIJ│KL
 MNOPQR
 zw
 ST│UVWX

- x

 ABCDEF
 xy
 GHIJ│L
 MNOPQR
 zw
 ST│VWX
```

Mapped and `<expr>`-mapped motions follow:

```
:nnoremap j gj
Q2j q=

│a1
 a2
│b1
 b2

- j

 a1
│a2
 b1
│b2

- x

 a1
│2
 b1
│2
```

A mapping that moves the cursor without pressing a motion key follows too,
whether it gets there through the API, a nested `:normal!` inside `<Cmd>`, or a
plain `:call`. Which means matchit's `%` works:

```
:packadd matchit
QjQj q=

│(aa)
│(bb)
│(cc)

- %          every cursor jumps to its own ")"

 (aa│)
 (bb│)
 (cc│)

- x

 (a│a
 (b│b
 (c│c
```

Jumps don't follow. `<C-o>` and `` ` `` move the primary alone. Scrolling never
follows either way, so `<C-d>` is primary-only, and a later edit still cascades
to the off-screen cursors while the viewport stays where it was.

Cursors that converge merge, and if they all merge the session ends and follow-mode resets:

```
QjQ q=

│aaa
│bbb
 ccc

- G          everybody lands on line 3

 aaa
 bbb
│ccc

- x          one deletion, not three

 aaa
 bbb
│cc
```

`Q` ends follow-mode. `<C-LeftMouse>` doesn't. `]C` and `[C` don't drag the others.

`q=` while you're recording a macro won't toggle, because the `q` stops the recording first.

A mapping that edits cascades its motions too, even with follow-mode off:

```
:nnoremap gj i<C-j><Esc>k$
gg04l QjQj

 aaa │bbb
 ccc │ddd
 eee │fff

- gj         split at the cursor, then k$ back to the end of the first half

 aaa│␣
 bbb
 ccc│␣
 ddd
 eee│␣
 fff

- x          the k$ moved every cursor, so the trailing spaces go

 aa│a
 bbb
 cc│c
 ddd
 ee│e
 fff
```

Same thing for a mapping that moves before it inserts:

```
:nnoremap i ^i
gg0ll QjQj

 aa│aa
 bb│bb
 cc│cc

- iX         the ^ takes each cursor to its own first non-blank

X│aaaa
X│bbbb
X│cccc

- <Esc>

│Xaaaa
│Xbbbb
│Xcccc
```

# Insert mode

Text shows up at the other cursors as you type it, not at `<Esc>`.

```
QjQj

│puts "one"
│puts "two"
│puts "three"

- I#         already there, still in insert mode

#│puts "one"
#│puts "two"
#│puts "three"

- ␣<Esc>

# puts "one"
# puts "two"
# puts "three"
```

Cursor moves inside the session cascade live and resolve per cursor:

```
QjQj

│alpha one
│beta two
│gamma three

- Aab        still in insert mode

 alpha oneab│
 beta twoab│
 gamma threeab│

- <Left><Left>X

 alpha oneX│ab
 beta twoX│ab
 gamma threeX│ab

- <Esc> AZ<Home>Y<Esc>     <Home> is each line's own start

 Yalpha oneXabZ
 Ybeta twoXabZ
 Ygamma threeXabZ

- A<S-Left>W<Esc>          word-wise, per cursor

 Yalpha WoneXabZ
 Ybeta WtwoXabZ
 Ygamma WthreeXabZ
```

`<C-g>U` cascades and doesn't split undo:

```
Qj

│aa
│bb

- i12<C-g>U<Left>3<Esc>

1│32aa
1│32bb

- u          one block, not two

│aa
│bb
```

An absolute jump splits the session and re-anchors:

```
 alpha
 beta
 gamma

- j0Q j0Q gg$

 alph│a
│beta
│gamma

- ix

 alphx│a
 x│beta
 x│gamma

- <C-Home>y  the jump re-anchors, the previews stay

 y│alphxa
 xy│beta
 xy│gamma
```

`<C-c>` ends the session like `<Esc>` does. The text and the cursors both survive.

Deleting:

```
Qj

│aaa
│bbb

- iXY<BS>Z<Esc>

X│Zaaa
X│Zbbb
```

```
gg0l Qj

 a│bc
 d│ef

- i<BS>Z<Esc>    <BS> eats past where the insert started

│Zbc
│Zef
```

`<BS>` at column 0 joins with the line above:

```
ggj0 Q2j

 aa
│bb
 cc
│dd

- i<BS><Esc>

 a│abb
 c│cdd
```

`<CR>` splits:

```
gg02l Qj

 aa│Xbb
 cc│Xdd

- iAB<CR>CD<Esc>

 aaAB
 C│DXbb
 ccAB
 C│DXdd
```

Entry commands:

```
Q2j

│aaa
 bbb
│ccc

- OX<Esc>

│X
 aaa
 bbb
│X
 ccc
```

```
Qj

│abc
│def

- aZ<Esc>

a│Zbc
d│Zef
```

```
gg$ Qj$

 ␣␣a│a
 ␣␣␣␣b│b

- IX<Esc>    each line's own first non-blank

 ␣␣│Xaa
 ␣␣␣␣│Xbb
```

Insert-mode commands:

```
Qj

│zz
│yy

- ifoo bar<C-w>X<Esc>

 foo │Xzz
 foo │Xyy
```

```
Qj

│aaa
│bbb

- i<C-v>u00e9<Esc>

│éaaa
│ébbb
```

```
Qj

│aaa
│bbb

- 3iZ<Esc>

ZZ│Zaaa
ZZ│Zbbb
```

Replace mode, including `<BS>` putting back what it overwrote:

```
Qj

│abcdef
│ghijkl

- RXY<Esc>

X│Ycdef
X│Yijkl
```

```
Qj

│abcdef
│ghijkl

- RXY<BS><BS><Esc>   the <BS>s put the overwritten chars back

│abcdef
│ghijkl
```

Abbreviations and `autoindent`:

```
:iabbrev teh the
Qj

│aaa
│bbb

- iteh <Esc>

 the│ aaa
 the│ bbb
```

```
:set autoindent
Qj

␣␣│aa
␣␣␣␣␣␣│bb

- oX<Esc>

 ␣␣aa
 ␣␣│X
 ␣␣␣␣␣␣bb
 ␣␣␣␣␣␣│X
```

A replayed `<C-u>` on a less-indented line has nothing to eat, and won't
backspace through the line boundary:

```
:set autoindent
QjQj

│␣␣␣␣indented aa
│flat bb
│␣␣␣␣indented cc

- o<C-u><Tab>yay<Esc>

 ␣␣␣␣indented aa
 →ya│y
 flat bb
 →ya│y
 ␣␣␣␣indented cc
 →ya│y
```

`ea` under follow-mode:

```
Qj q=

│one two
│three four

- ea!<Esc>

 one│! two
 three│! four
```

Completion works. The cascade pauses while a popup is up and the other cursors
catch up when it closes, so accepting a candidate lands everywhere:

```
│wombat
 wo
 wo

- 2gg Q j    a cursor on line 2, you on line 3

 wombat
│wo
│wo

- A<C-n><Esc>    the cursor catches up when the popup closes

 wombat
 womba│t
 womba│t
```

Same for `autocomplete` and for a plugin driving `complete()` from an `InsertCharPre` handler.

Autocommand counts match what you'd get with one cursor. `InsertEnter` and
`InsertLeave` fire once. `TextChangedI` fires once per typed character, not once
per cursor. `TextChanged` fires once for the session. `InsertCharPre` fires once
per character, and whatever it does to `v:char` lands at every cursor.
`textwidth` wraps per cursor.

Insertion points past EOL get drawn as virtual cells, so `A` at three cursors
shows you three carets.

# Visual mode

Each cursor shows its own selection, previewed live, with the display cursor at
each selection end. `o` swaps it to the other end. Charwise, linewise and
blockwise all render.

The whole keysequence replays, so the extents are per-cursor:

```
Qj

│one two three x
│aa bb cc d

- viw

[one] two three x
[aa] bb cc d

- ee         two more words, each cursor stretching over its own text

[one two three] x
[aa bb cc] d

- x

│␣x
│␣d
```

```
Qj

│one two
│ab cd

- viw

[one] two
[ab] cd

- rX

│XXX two
│XX cd
```

```
Q4j

│a
 b
 c
 d
│e
 f

- Vj

[a]
[b]
 c
 d
[e]
[f]

- d

│c
│d
```

Blockwise:

```
Q2j

│ab
 cd
│ef
 gh

- <C-v>j

[a]b
[c]d
[e]f
[g]h

- cX<Esc>

│Xb
 Xd
│Xf
 Xh
```

Same block, `I` inserts before it and `A` appends after it:

```
[a]b                   [a]b
[c]d                   [c]d
[e]f                   [e]f
[g]h                   [g]h

- IX<Esc>              - A!<Esc>

│Xab                  │a!b
 Xcd                   c!d
│Xef                  │e!f
 Xgh                   g!h
```

Payload motions inside the selection:

```
Qj

│abcd,ef
│wxyz,gh

- vf,

[abcd,]ef
[wxyz,]gh

- d

│ef
│gh
```

```
Qj

│one two
│one two

- v/two<CR>

[one t]wo
[one t]wo

- d

│wo
│wo
```

`<Esc>` puts every cursor on its own selection end, which is a handy way to
reposition without turning on follow-mode:

```
gg04l QjQj

 aaa │bbb ccc
 ddd │eee fff
 ggg │hhh iii

- viw

 aaa [bbb] ccc
 ddd [eee] fff
 ggg [hhh] iii

- <Esc>      every cursor lands on its own selection end

 aaa bb│b ccc
 ddd ee│e fff
 ggg hh│h iii

- x          the column doesn't move, so every cursor is now on a space

 aaa bb│␣ccc
 ddd ee│␣fff
 ggg hh│␣iii
```

Again from column 0, this time stretching one word further. The `0` is
primary-only, the `viwe` replays everywhere:

```
- 0

 aaa bb│␣ccc
 ddd ee│␣fff
│ggg hh iii

- viwe       "iw" on a space is the space, then "e" takes the next word

 aaa bb[␣ccc]
 ddd ee[␣fff]
[ggg hh] iii

- <Esc>x

 aaa bb c│c
 ddd ee f│f
 ggg h│␣iii
```

A selection changed by scrolling the viewport (`V<C-e>` at the window edge)
isn't replayable, so it edits the primary only.

# Registers

Every cursor reads and writes its own.

```
Qj

│aaa
│bbb

- yy         buffer unchanged, two yanks into two registers

- p

 aaa
│aaa
 bbb
│bbb
```

Swap two words everywhere:

```
Qj q=

│one two
│three four

- dW         each cursor's first word into its own register

│two
│four

- E          to the end of what's left

 tw│o
 fou│r

- p          charwise paste leaves each cursor on the last pasted char

 twoone│␣
 fourthree│␣
```

Paste each cursor's own yank over its own word:

```
Qj

│aaa X
│bbb Y

- yiw

- q= w q=

 aaa │X
 bbb │Y

- viwp

 aaa aa│a
 bbb bb│b
```

Jagged line ends, each cursor on its own register:

```
gg$Q j$

 ab│c
 d│e

- x

 a│b
 │d

- p

 ab│c
 d│e
```

Once the last cursor goes, the per-cursor values join in document order, linewise:

```
Qj0Q j0

│foo x
│bar y
│baz z

- yiw        buffer unchanged; " is "baz" while the session is alive

- <C-l>      " is now  foo\nbar\nbaz\n , type V
```

Named registers join the same way, and one nobody touched is left alone:

```
:let @z = 'PRESET'
Qj0

│foo
│bar

- "ayiw  then  <C-l>

@a  ->  foo\nbar\n
@z  ->  PRESET
```

Last write wins:

```
Qj0

│aa
│bb

- yl  then  x  then  <C-l>

@"  is  a\nb\n      the deletes, not the yanks
```

A cursor whose replays never wrote a register contributes nothing, instead of
folding in the stale pre-session value.

`TextYankPost` fires per cursor with that cursor's contents. The primary fires
first and isn't a replay, which `nvim__mcursor_cascading()` will tell you. The
primary's registers are the ones that stick.

Under `clipboard=unnamedplus` the provider syncs once for the primary's own edit
and once for the whole cascade, not once per cursor, and what reaches the
clipboard is the primary's.

# Undo

One `u` reverts a whole cascade. Undo and redo don't land in the same place
though: undo sends you back to where the change started, redo puts every cursor
back where the edit left it, rather than wherever splice adjustment would have
drifted it.

```
QjQj$

│aaa
│bbb
 cc│c

- IX <Esc>   cursors at column 1, on the space

 X│ aaa
 X│ bbb
 X│ ccc

- u          text back. The cursors go to column 0, you go back to where
             you were standing when you started the change.

│aaa
│bbb
 cc│c

- <C-r>      now everybody's at column 1, not column 2

 X│ aaa
 X│ bbb
 X│ ccc

- x

 X│aaa
 X│bbb
 X│ccc
```

Each cascade is a step, and a count counts cascades:

```
Q

│abc
 def

- jx

│bc
│ef

- x

│c
│f

- u

│bc
│ef

- u

│abc
│def

- <C-r><C-r>

│c
│f

- 2u

│abc
│def
```

`Q` is placement, not an edit, so the tree runs straight through the point where you placed cursors:

```
│xxx
 yyy

- x

│xx
 yyy

- Q j x

│x
│yy

- u

│xx
│yyy

- u          the restored "x" is inserted in front of the cursor, pushing it

│x│xx
 yyy
```

A cascaded macro is one block:

```
:let @q = "iX\<Esc>"
Qj

│aaa
│bbb

- @q

│Xaaa
│Xbbb

- u

│aaa
│bbb

- <C-r>

│Xaaa
│Xbbb
```

A mapped undo or redo doesn't cascade. Undo is buffer-global, so cascading it
would undo once per cursor and blow straight past the start of the session:

```
:nnoremap <silent> u :<C-u>undo<CR>
QjQj

│aaa
│bbb
│ccc

- x

│aa
│bb
│cc

- u          one undo, not three

│aaa
│bbb
│ccc
```

Undo restores text, never registers. The per-cursor values survive it, so exiting still joins them:

```
Qj0

│foo x
│bar y

- diw

│␣x
│␣y

- u          text back, registers untouched: @" is still "bar"

│foo x
│bar y

- <C-l>      @"  is  foo\nbar\n
```

`g-`, `g+` and `:earlier` drop every cursor and end the session:

```
Q

│aaa
 bbb

- jx

│aa
│bb

- g-         every cursor is dropped; the bar left is just you

 aaa
│bbb

- g+         still none

 aa
│bb

- Q          new session, cursor where you are

 aa
│bb
```

# Macros

`@` cascades:

```
gg0qqxq      record "x" into q; line 1 becomes "aa"

│aa
 bbb
 ccc

- jQ j0

 aa
│bbb
│ccc

- @q

 aa
│bb
│cc

- @@

 aa
│b
│c
```

So does a macro with an insert session in it:

```
gg0qwA!<Esc>q

 aaa│!
 bbb
 ccc

- jQ j0

 aaa!
│bbb
│ccc

- @w

 aaa!
│bbb!
│ccc!
```

A count applies at each cursor:

```
 aaaa
│bbbb
│cccc

- 2@q        the "x" macro, twice per cursor

 aaaa
│bb
│cc
```

A macro typed where there are no cursors cascades in whatever buffer it navigates into, same as a mapping.

# Numbering

```
Qj0Qj0

│a
│b
│c

- g<C-a>

 1│a
 2│b
 3│c
```

```
Qj0

│a
│b

- 5g<C-a>

 5│a
 6│b
```

One bar, one number. Two cursors stacked in the same cell still only get one:

```
QjQj gg0     back to line 1, where a cursor already is

│x
│y
 z

- g<C-a>     two bars on screen, two numbers

 1│x
 2│y
 z
```

The number goes in at the cursor's column, before whatever is there:

```
Qj

 x = │5
 y = │5

- g<C-a>

 x = 1│5
 y = 2│5
```

Through a mapping it applies once, not once per cursor:

```
:nnoremap ,n g<C-a>
QjQj

│a
│b
│c

- ,n

 1│a
 2│b
 3│c
```

With no cursors it isn't a command and beeps. Plain `<C-a>` still increments.

Start, step and format live on the function behind it. Private module, so pin
your version or wrap it in `pcall`:

```lua
require('vim._core.mcursor').number(10, 2, '%d) ')
```

```
Qj0Qj0

│x
│x
│x

- the call above

 10) │x
 12) │x
 14) │x
```

# Jumping between cursors

`]C` and `[C` cycle in position order, wrapping, with a count. They'll scroll
the viewport to reach an off-screen cursor, and they never drag the other
cursors along, even in follow-mode. The jump leaves a cursor at the position you
left, so walking the ring doesn't change the set of positions. No cursors, no
move, just a beep.

```
Q2jllQ gg0j

│aaa
│bbb         you're here
 cc│c
 ddd

- ]C    ->   line 3, column 2. A cursor stays behind on line 2, so
             the screen doesn't change.

│aaa
│bbb
 cc│c
 ddd

- ]C    ->   line 1, column 0, wrapped
- 2]C   ->   line 3, column 2
- [C    ->   line 2, column 0
- [C    ->   line 1, column 0

- x          three positions, three edits

│aa
│bb
 c│c
 ddd
```

Pair that with the `Q` toggle and you get select-all-then-deselect:

```
1Q        every match
]C ]C     walk
Q         drop this one
ciw...    edit the rest
```

# Folds

The primary keeps normal fold behavior. Replays don't: they act on the
per-cursor line inside the fold, and the fold stays closed.

Primary outside the fold:

```
3G0Q  then  :2,4fold  then  gg0

│aaa
+--  3 lines: bbb·············      lines 2-4, the cursor is on line 3

- x

│aa
+--  3 lines: bbb·············

- dd         primary deletes line 1; the cursor deletes only line 3

+--  2 lines: bbb·············      what's left is bbb and ddd
```

Primary inside the fold:

```
4jQ  then  gg  then  :2,3fold  then  2G

 aaa
+--  2 lines: bbb·············      you're in here
 ddd
│eee
 fff

- dd         you take the whole fold, the cursor takes only its own line

 aaa
│ddd
│fff
```

Follow-mode motions ignore closed folds too, so a replayed `j` steps into one. A
mapping that turns fold semantics back on mid-cascade (`zN` then `dd`) doesn't
change that.

Fold operators cascade; fold toggles don't:

```
4G0Q gg0 zfap      each cursor folds its own paragraph
za                 only the primary's fold toggles
```

# What doesn't cascade

Ex commands. The atom gets emitted with `type = "excmd"` and never replayed:

```
Qj

│foo
│foo

- :s/o/O/<CR>    only your line

 foo
│fOo
```

`:normal!`, and anything else programmatic:

```
Qj

│aaa
│bbb

- :normal! x     primary only

│aaa
│bb

- x              typed, so it cascades

│aa
│b
```

API edits shift the cursors but are primary-only themselves:

```
QjQj

│aaa
│bbb
│ccc

- :lua vim.api.nvim_buf_set_lines(0, 0, 0, true, { 'zzz' })

 zzz
│aaa
│bbb
│ccc

- x

 zzz
│aa
│bb
│cc
```

Also undo and redo, fold toggles, an operator with no effect (an aborted `ysa[`
won't drag every cursor onto the same bracket), and an atom captured in one
buffer that resolves in another (a mapping ending in `:bnext` doesn't cascade
into where it lands).

# Buffers

Cursor sets are per-buffer. A cascade pauses while you're elsewhere and picks up
when you come back:

```
:set hidden
Qj

│aaa
│bbb

- :enew  gg0x    a different buffer, no cascade into the old one

│xx

- :buffer #      the cursor was an extmark, it survived

│aaa
│bbb

- 2G0x

│aa
│bb
```

Edits cascade from any window showing the buffer, so `:split` and editing from
the new window is fine. Cursors die with their buffer, and `nvim_mcursor()` will
happily place them in a hidden one.

# Advanced

## Occurrence operator

This is the thing issue #21334 was asking for. An `operatorfunc` puts a cursor
on every occurrence of the word under the cursor within a motion, then your next
edit cascades to all of them. They survive because a `g@` with no effect doesn't
cascade.

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
│text a text
 b text c

- coip       a cursor on every "text" in the paragraph

│text a │text
 b │text c

- ciwWORD<Esc>

 WOR│D a WOR│D
 b WOR│D c
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
QjQj

│␣␣aaa
│␣␣bbb
│␣␣ccc

- q- ^       every cursor to its first non-blank

 ␣␣│aaa
 ␣␣│bbb
 ␣␣│ccc

- l          follow mode already ended, so only you move

 ␣␣│aaa
 ␣␣│bbb
 ␣␣c│cc
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

Extmarks move with inserted text, so padding to a shared virtual column is
short. Assumes one cursor per line, and skips the primary since it isn't an
extmark.

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

Quickfix items are 1-indexed on both axes, hence `col - 1`. Diagnostics are
0-indexed on both, so those want `lnum + 1` and a bare `col`.

## CmdAtom

One event per action, and cascade replays emit nothing.

`type` is `motion`, `operator`, `insert`, `visual`, `mapping` or `excmd`. `lhs`
is what you typed before resolution. `keys` is the resolved sequence in raw
bytes: empty means it can't be replayed, nil means the capture was lossy and you
should replay `lhs` with `feedkeys` mode `m` instead of `n`. `text` carries the
payload, whether that's inserted text, a cmdline or a search. `changed` and
`moved` tell you whether the action edited or moved. `atoms` holds ordered
subatoms, and it's only non-empty for a composite action.

`nnoremap gj i<C-j><Esc>k$` emits one `mapping` atom whose `atoms` are two
inserts plus the motions `k` and `$`. `q=` gets recorded too, so a follow-mode
stretch shows up as `q=`, `l`, `l`, `q=`.

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

That multicursor check is the important bit: a replay through `feedkeys` is
programmatic and won't cascade. The version in `:h CmdAtom` also filters undo
and redo out by comparing `undoseq` against a buffer-local high-water mark. `:h
cmdatom-macro` keeps a ring of the last N atoms and turns them into an editable
macro in the cmdwin.

# Keymaps

`Q` used to replay the last recorded register, and `{Visual}Q` ran it per
selected line. Both are gone. If you miss them:

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

Escape clears cursors when there are any. Clear the namespace directly rather
than feeding `<C-l>`, which is a mapping and would need `remap = true` to fire:

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

`reverse` is the safe pick. Linking to `Cursor` sounds right until you remember
how many colorschemes leave `Cursor` invisible in the terminal.

If you share a config with a machine still on 0.12:

```lua
if vim.api.nvim_mcursor then
  -- ...
end
```

# Things that will bite you

Two cursors on one line do edit at their own columns, for column-local operators:

```
Q4l

│abcd│ef

- x          you delete the "e", then the cursor deletes the "a"

│bcd│f

- x

│c│d
```

But an edit that shifts columns shifts them relative to each other, and linewise
operators aren't deduplicated for same-line cursors yet, so `dd` there runs once
per cursor.

The rest of the list:

- `g-`, `g+` and `:earlier` end the session, and `gQ` can't bring the cursors back.
- `:e!` and `autoread` reloads clear the cursors and the `gQ` snapshot.
- Undo restores text, not registers.
- `g<C-a>` inserts before the character at the cursor's column, and `$` stops on
  the last character, so appending numbers to line ends needs `nvim_mcursor()`
  at an exact byte column.
- `Q` is quietly unavailable inside a macro, and `qQ` starts a recording.
- `iw` and `cw` are still word objects. They won't split `camelCase`. Use `:%s///g` for substrings.
- Ex commands don't cascade.

# Terminals

Nvim asks for the [Kitty multiple-cursors protocol](https://github.com/kovidgoyal/kitty/blob/master/docs/multiple-cursors-protocol.rst)
at startup and only uses it if the reply advertises cursor shape 29. When it
does, you get real terminal cursors instead of `MCursor` cell highlights,
including in unfocused splits. To force the fallback:

```lua
require('vim._core.mcursor').tty_cursors(false)
```
