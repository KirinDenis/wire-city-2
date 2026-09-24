# REFGEN — the reference factory

One command produces a set of Turbo Vision screens as raw video memory, and
decodes each one into a picture plus a list of every colour in it, by name.

```
TOOLS\REFGEN\MAKEWIN
```

DOSBox opens, Borland Pascal compiles `REFGEN.PAS`, it runs, and DOSBox
closes. Nobody presses anything. What comes out is `REF00.TXT` and up.

## Why this and not a screenshot

We spent an afternoon arguing about a colour from a JPEG and got it backwards:
the desktop is blue dots on light grey, not light grey dots on blue, and at
25% coverage those are completely different pictures. Every such question has
an exact answer sitting in video memory, two bytes per cell, and no amount of
looking at an enlarged screenshot produces it.

`REFGEN.PAS` builds each scene with the real Turbo Vision units, lets them
draw, and copies `B800` straight to a file. There is no interpretation
anywhere in the path.

## What it settled, first run

```
0x71  blue on lightgray    the desktop, with ░
0x1F  white on blue        an active window's frame
0x1A  ltgreen on blue      the close box, the zoom box, the resize corner
0x08  darkgray on black    the shadow
0x31  blue on cyan         the entire scrollbar - track, thumb and arrows
0x70  black on lightgray   menu bar and status line
0x74  red on lightgray     their hotkey letters  (red, not bright red)
0x78  darkgray on lightgray  a disabled item
```

Two of those we had wrong and could not have seen: the status keys were bright
red, and the scrollbar was three palette entries where Turbo Vision uses one
attribute and three different glyphs.

Two we had right and had been arguing about anyway: the resize corner is two
cells and it is green, and the scrollbar marker is `■` and not a full block.

## The scenes

| | |
|---|---|
| `REF00` | desktop, menu bar, status line |
| `REF01` | one active window |
| `REF02` | two windows — front active, back inactive, shadow between |
| `REF03` | a window with both scrollbars |
| `REF04` | a dialog — input line, label, checkboxes, radio buttons, buttons |

Add a scene by writing another `SceneXxx` procedure and calling it; the file
numbering and the index take care of themselves.

## What this cannot reach

Anything that only exists while Turbo Vision is running its event loop — an
open menu, a highlighted item, a dialog in the middle of being dragged. Those
need the screen taken off a live program, which is what `TOOLS\SCRGRAB` is
for.

The IDE's own editor window is also worth capturing that way: plain Turbo
Vision runs its horizontal scrollbar nearly the whole width of the bottom
edge, while the IDE shortens it to make room for the line:column indicator.
Both are real; ours follows the IDE.

## Not committed

Borland Pascal is commercial software and is not in this repository — it comes
from `TASMDIR` in `LOCAL.BAT`. Neither `REFGEN.EXE` nor the dumps are
committed either: the source is ours, what it links against and what it draws
are not.
