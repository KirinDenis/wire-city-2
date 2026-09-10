# The story engine

`STORY.COM` plays a story: the scenes of `STORY\<NAME>`, section by
section, the way the desk laid them out. It is the game, without the
game around it yet.

```
STORY                       plays ..\STORY\NIGHT
STORY ..\STORY\OTHER        plays that one
STORY ..\STORY\NIGHT /AUTO  plays itself and writes SHOTnn.OWV of the screen
```

| in a clip | ESC or Space skips it, Q quits |
|---|---|
| in a pickup | click a thing to take it, or move the cursor with the arrow keys and press Enter or Space; ESC skips, Q quits |
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
- `MUSIC` - the scene's track, `MUSIC.PCM`, an OWA1 file of sixteen-bit
  mono samples opened when the scene starts and closed when it ends, and
  looped. Under the room and under a quiz the card is started for it and
  the loop keeps the queue fed; under a clip the decoder hands every audio
  chunk through `OWV_MIX` and the music is added in at half level,
  saturated - so a clip carries only its own sounds and the scene's mood
  goes on underneath. A silent clip plays silent: the mixing rides on the
  clip's own audio chunks.
- `[PICKUP]` - `BG.OWV`, one frame, through that same decoder; then every
  `.SPR` named in the section drawn on top at the position in its header,
  index 255 skipped. `PANEL = 64` says the bottom 64 rows are not the room:
  the converter laid the panel's backing there, and each thing's `.SLT` -
  the thing at slot size, placed in its slot by the converter - is drawn
  on it as an **outline** in the palette's grey (every opaque pixel with a
  transparent neighbour) while the thing is in the room, and as itself
  once taken. A `TEXT` line for the thing is drawn in a black band at the
  foot of the room for a second and a half at the taking, and the section
  waits that long for the last one. The mouse (`INT 33h`, ranges set to 640x400) with a
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
- **Transitions.** Every section comes up out of black and goes down into
  it: the DAC is written with the palette scaled to a level of eight, a
  clip over its first and last eight frames from the decoder's frame hook,
  a still (the room, a question, a message) a level a tick with the music
  kept fed. Nothing in the frame is touched, so `/AUTO` shots are
  unaffected. A cross-dissolve is not on: two pictures with two palettes
  have no colours in common to blend through.
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
4000  SECTTAB   the scene's sections, parsed     4E00  ITEMTAB  the things on screen
4C00  ORDERTAB  the scene ids from STORY.INI     5000  CURSAVE  under the cursor
5100  HDRBUF    the clip's header                5500  MODEBUF  what VESA said
5600  INIBUF    the INI being read, 4 KB         6600  QUEUE    audio, 32 KB
E600  IOBUF     DOS reads land here, 4 KB        F600  the stack
```

and above 1 MB, taken outright as the player does: the clip buffers of
`OWV.INC`, the things of a pickup at `400000h`, 64 KB a slot, and their
slot pictures at `500000h`, 16 KB a slot. Not safe with a memory manager
loaded; the batch files start DOSBox without one.

## What is not here yet

Inventory - a thing taken goes into its slot and no further; nothing
persists into the next scene. Flags, and a quiz answer that depends on
them. A click on a slot does nothing. Music under a clip that has no sound
of its own. A title screen. Each of those is a section kind or a key, and
the desk and this program grow together.

## Seen once, not yet understood

Twice in this lab a `/AUTO` run of the whole story ended early - DOSBox
closed in the middle of a clip (once at the start of S02's, once fifteen
seconds into S03's), with nothing in the log and no message - and the
same build then played the story to THE END twice over. It did not happen
in a run of S02 alone. The log stops without `reached: the end of the
stream`, so the program did not finish the clip by itself; nothing in the
room or the panel code is running at those moments. If it shows again,
the thing to catch is DOSBox's own console (`RUNWIN` without the batch's
`exit`, or `-noconsole` so `stdout.txt` keeps it), not the engine's log.
