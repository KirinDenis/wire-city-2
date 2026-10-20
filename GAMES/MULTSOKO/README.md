# MULTIPLAY SOKO

Crates onto the red marks, in a brick warehouse seen from three quarters
above, on a **CGA** screen: 320x200, four colours, **8086 assembly**, flat
FASM, one `.COM`. The 61 levels are the ones of
[Base-Z-47](https://github.com/KirinDenis/Base-Z-47-Rust-Game).

```
Arrows    walk, and push the crate in front of you
W A S D   the same, for the left hand
Z         the whole level / close up
R R       the level anew (the first R only asks)
N N, P P  the next, the previous level
ESC       back to DOS
```

A crate onto a goal scores +10, off one -10; a solved level gives +50 to
every man in the warehouse. The list under the playfield shows the men,
their names and their scores; a star marks the host.

## On the network

Up to eight players work one warehouse. On the WIRE CITY site everyone who
plays MULTIPLAY SOKO is in the room `multsoko`; in desktop DOSBox, start the
DOSBoxes on one `ipxnet`. The title screen asks for a name (up to eight
letters and digits; none typed is PLAYER).

- **One machine keeps the warehouse.** The crates, the level, the men and
  the scores belong to the host - the lowest name on the wire. It sends the
  world whole (`'W'`) twice a second and after every change; the others send
  it their steps and orders (`'M'`) and their name (`'H'`, twice a second),
  and draw what it sends. A step therefore goes there and back before the
  man moves - a tenth of a second on the relay - and two men can never push
  one crate two ways.
- **A newcomer** listens two seconds for a world. Hearing one, it is a
  client; the host gives its man the free floor nearest the start. Hearing
  none, it opens a warehouse of its own at level 1 and hosts it. Two that
  started alone at once become one: the higher name yields when it hears the
  lower one's world.
- **Leaving.** A man not heard for 3 s is taken off the floor. A host not
  heard for 2 s is replaced by the lowest name still heard, which carries on
  from the world it last drew.
- **R R, N N, P P** go to the host, and change the level for everyone.
- **Everything off the wire is checked:** a level past the last drops the
  packet; a crate or a man off the floor is left out; a name is made
  printable.
- No IPX card, or no address within 15 s (Enter stops the wait): alone, the
  same game.

The network calls are `ENGINE\E_NET.INC`. It was tested with a fake player,
`tests\SokoPilot\sokopilot.mjs` in the OWLOS-LAN repository, against the
game in the site's page on a test server: as a client (its man in, its
steps applied, dropped 3 s after it went quiet) and as the host (the game
joined its warehouse, its steps went there and back, and it took the
warehouse over 1.7 s after the host went quiet).

## Build it, run it

In DOSBox, with the repository mounted:

```
cd GAMES\MULTSOKO
MAKE
RUN
```

From Windows: `MAKEWIN`, then `RUNWIN` (`RUNWIN CGA` plays it on DOSBox's
real CGA machine). On the WIRE CITY site, a copy in `A:\MY\MULTSOKO` builds
with `build A:\MY\MULTSOKO\MULTSOKO.ASM`.

## The files

| File | What it is |
|---|---|
| `MULTSOKO.ASM` | the game |
| `ART.INC` | the pictures as text, one character a pixel: `.` see-through, `0`-`3` the four colours, `S` and `P` the man's shirt and cap. Edit them by hand. |
| `LEVELS.INC` | the levels, made by `TOOLS\LevConv` from Base-Z-47's `level0.rs` ... `level60.rs` |
| `..\..\ENGINE\E_NET.INC` | the network: IPX, everyone in the room hears everyone |

`TOOLS\ArtGen` draws the floor, walls and crates by rule, writes them out as
`ART.INC` text and renders a level the way the game does, as PNG, so the
pictures can be tried before DOS sees them.

## How the picture is made

- **Three quarters from above.** Grid rows run across the screen; cell
  (c, r) has its corner at `x = ox + c*cw`, `y = oy + r*cd`. A wall or a
  crate shows its top face lifted and its front face under it. Everything is
  drawn back to front into a back buffer: every floor first, then row by row
  the walls, crates and men, so a nearer block covers the bottom of the cell
  behind it.
- **Why not isometric.** The first version was isometric, and prettier, but
  there every grid direction is a diagonal of the screen: each arrow had to
  be turned 45 degrees in the head. Here an arrow goes where it points.
- **Two sizes.** Cells of 16x12 by default, with the camera following your
  man; `Z` switches to 8x6, where every level fits on the screen whole.
- **Low walls.** A wall is half a cell high (6 pixels of 12). Taller, and a
  wall in front hides most of a corridor. The tops are a dark red checker and
  the faces red bricks in black mortar, so the light floor, the yellow crates
  and the men stand out.
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
