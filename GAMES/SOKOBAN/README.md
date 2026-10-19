# SOKOBAN

Crates onto the red marks, in an isometric brick warehouse on a **CGA**
screen: 320x200, four colours, **8086 assembly**, flat FASM, one `.COM`.
The 61 levels are the ones of
[Base-Z-47](https://github.com/KirinDenis/Base-Z-47-Rust-Game).

```
Arrows    walk the grid: UP goes up-right on the screen, RIGHT down-right,
          DOWN down-left, LEFT up-left
9 3 1 7   the keypad (PgUp PgDn End Home): the same four, named the way
          the screen shows them
Z         the whole level / close up
R R       the level anew (the first R only asks)
N N, P P  the next, the previous level
ESC       back to DOS
```

A crate onto a goal scores +10, off one -10; a solved level gives +50 to
every man in the warehouse. The list under the playfield shows the men and
their scores. Today there is one man; the warehouse is built for eight, and
the network game fills the other places.

## Build it, run it

In DOSBox, with the repository mounted:

```
cd GAMES\SOKOBAN
MAKE
RUN
```

From Windows: `MAKEWIN`, then `RUNWIN` (`RUNWIN CGA` plays it on DOSBox's
real CGA machine). On the WIRE CITY site, a copy in `A:\MY\SOKOBAN` builds
with `build A:\MY\SOKOBAN\SOKOBAN.ASM`.

## The files

| File | What it is |
|---|---|
| `SOKOBAN.ASM` | the game |
| `ART.INC` | the pictures as text, one character a pixel: `.` see-through, `0`-`3` the four colours, `S` and `P` the man's shirt and cap. Edit them by hand. |
| `LEVELS.INC` | the levels, made by `TOOLS\LevConv` from Base-Z-47's `level0.rs` ... `level60.rs` |

`TOOLS\ArtGen` draws the floor, walls and crates by rule, writes them out as
`ART.INC` text and renders a level the way the game does, as PNG, so the
pictures can be tried before DOS sees them.

## How the picture is made

- **Isometric.** Grid cell (c, r) has its tile at `x = ox + (c-r)*hx`,
  `y = oy + (c+r)*hy`. Everything is drawn back to front into a back buffer:
  every floor first, then row by row the walls, crates and men. A tile lower
  on the screen is always nearer, so it is drawn later.
- **Two sizes.** Tiles of 24x12 by default, with the camera following your
  man; `Z` switches to 16x8, where most levels fit on the screen whole. Both
  are 2:1 diamonds with rows 2, 6, 10 ... pixels wide, so neighbours meet
  without a gap.
- **Low walls.** A wall is a block only 6 pixels high. At 8 the walls in
  front hid the crates in Sokoban's one-tile corridors. The tops are a dark
  red checker and the faces red bricks in black mortar, so the light floor,
  the yellow crates and the men stand out.
- **CGA in a byte.** Four pixels a byte, two bits each. A picture is
  compiled at start into a mask and an ink byte per four pixels, and drawn as
  `screen = (screen AND mask) OR ink`. The back buffer is linear; the copy
  out splits it into the CGA's two banks, the even rows at `B800:0000`, the
  odd ones at `B800:2000`.
- **One palette, three ways.** Green, red and yellow on black: the BIOS call,
  port `3D9h` for a real CGA, and the attribute registers for a VGA, which
  ignores the other two in mode 4.
- **Text** is the BIOS's own 8x8 font, from `F000:FA6E` on a CGA or wherever
  an EGA or VGA BIOS says (`INT 10h AX=1130h`).
