# The story engine

`STORY.COM` plays a story: the scenes of `STORY\<NAME>`, section by
section, the way the desk laid them out. It is the game, without the
game around it yet.

```
STORY                       plays ..\STORY\NIGHT
STORY ..\STORY\OTHER        plays that one
STORY ..\STORY\NIGHT /AUTO  plays itself and writes SHOTnn.OWV of the screen
```

| in a clip | ESC skips it, Q quits |
|---|---|
| in a pickup | click a thing to take it, or move the cursor with the arrow keys and press Enter; ESC skips, Q quits |
| in a quiz | 1..9 answers; ESC takes the first |

Build with `MAKE` from inside DOS (or `MAKEWIN` from Windows), run with
`RUN` (or `RUNWIN`). Every run writes `STORY.LOG`: which scene, which
section, what was taken, which code, where it went - and the player's own
five lines for every clip.

## What it reads

[`STORY.INI` and `SCENE.INI`](../STORY/README.md): the first scene, then
each scene's sections in play order.

- `[VIDEO]` - the clip, through the same decoder as the workbench player:
  `..\VIDEO\OWV.INC` and `..\VIDEO\SB.INC` are included, not copied. Sound
  is the clock, sixteen bits on a Sound Blaster 16.
- `[PICKUP]` - `BG.OWV`, one frame, through that same decoder; then every
  `.SPR` named in the section drawn on top at the position in its header,
  index 255 skipped. The mouse (`INT 33h`, ranges set to 640x400) with a
  cursor drawn by hand, because the driver draws none in a VESA mode; and
  the arrow keys move that same cursor, Enter clicks, so a mouse an
  emulator has not captured yet is not a wall. A click takes a thing in
  two passes: first the thing whose own opaque pixel is under the cursor,
  so where two overlap the right one wins; then, if none was, the thing
  whose rectangle holds the point - the middle of a glass ashtray is
  see-through, and a player who clicks on the ashtray has clicked on the
  ashtray. Taking it: the room is copied back over
  its rectangle from the frame the decoder left above 1 MB, and the
  others are drawn again. When every thing in NEED is taken - all of
  them, if NEED is empty - the section is over.
- `[QUIZ]` - the question and its numbered answers in a box at the bottom,
  over whatever the last frame was, in the ROM's 8x8 font doubled and in
  the brightest and darkest entries of the current palette. The number
  pressed is the code the scene ends with.

A scene ends with a number: the quiz answer, else its `CODE` line. The
next scene is the first in `ORDER` whose `SCENE.INI` has that number in
`ENTERS` - the engine reads each candidate's file and looks. `ENDING = yes`
ends the story.

A file that is not there is a box at the top of the screen with the
path, and a key moves on. The story can be played at every stage of
production, with the holes visible where they are.

## /AUTO, which is how it was tested

Nobody can screenshot DOSBox from a script and nobody should be made to
click through forty scenes to check a build. With `/AUTO` the engine takes
every thing in a pickup half a second apart, answers 1 to every quiz, holds
every message for a second, and at each of those moments writes the whole
screen to `SHOTnn.OWV` - a one-frame OWV of what was on it, palette and
all. The desk renders those with `SceneDesk --dump SHOT01.OWV 1 out.png`,
and the run can be looked at afterwards, frame by frame.

Four bugs were found that way and would not have been found by reading:
the parser kept its cursor in SI and every handler that used SI for its
own string ended the parse after exactly one `ITEM`; the sprites came
out as black rectangles because `COPYB` hands back ECX as zero, so "end
minus length" was end minus nothing; every click took thing number 0
because hiding the cursor ran a loop on CX, the register the hit test had
just answered in; and the centre of the ashtray was a hole. The /AUTO run
goes through the same hit test a click does, for exactly that reason.

## Memory

```
0100  code and the small data
4000  SECTTAB   the scene's sections, parsed     4A00  ITEMTAB  the things on screen
4800  ORDERTAB  the scene ids from STORY.INI     4B00  CURSAVE  under the cursor
4C00  HDRBUF    the clip's header                5000  MODEBUF  what VESA said
5400  INIBUF    the INI being read, 4 KB         6400  QUEUE    audio, 32 KB
E400  IOBUF     DOS reads land here, 4 KB        F400  the stack
```

and above 1 MB, taken outright as the player does: the clip buffers of
`OWV.INC`, and the things of a pickup at `400000h`, 64 KB a slot. Not safe
with a memory manager loaded; the batch files start DOSBox without one.

## What is not here yet

Inventory - a thing taken goes nowhere. Flags, and a quiz answer that
depends on them. Sound in a pickup. Text of the pickup's own (a line under
the room). A title screen. Each of those is a section kind or a key, and
the desk and this program grow together.
