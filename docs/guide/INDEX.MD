# INDEX - the WIRE CITY guide to making DOS games

What the work on the WIRE CITY games found out - the flight sims OWL FLY
I, II and III, the course's lessons, the demos - put down for whoever
makes the next DOS game here: a model working in a visitor's page, or a
person. 8086 assembly, flat FASM, DOSBox in a browser.

Read this page, then TRAPS, then only the topics your game needs - every
topic is a few KB, and a model's reading is paid for by the person.
With the tools: guide("TRAPS"), guide("VIDEO")... In DOS: A:\ is the
course disk; the code the topics point to is there (A:\ENGINE\*.INC,
A:\LESSONS\Lnn\, A:\GAMES\..\SRC\, A:\EXAMPLES\).

## The ten rules

1. 8086 real mode, flat FASM, a .COM: `org 100h`, then
   `include '..\..\ENGINE\E_8086.INC'` - FASM silently emits 386 long
   jumps (0F 8x) that an 8086 cannot run; the include rewrites them.
2. Never divide by what can be 0, or by what makes the quotient too big:
   under DOSBox a divide fault returns to the DIV and loops for ever.
   Shift, use a reciprocal table, clamp before the divide.
3. MUL, IMUL, DIV and IDIV write DX:AX - keep nothing in DX across them;
   byte IMUL/IDIV operands are signed (135 is -121).
4. Time by the BIOS tick at 0040:006Ch (18.2 a second), never by CPU
   speed: the site runs DOSBox at full speed. One physics step per tick
   passed, at most 6 a frame.
5. VGA mode 13h (320x200, 256 colours) unless asked otherwise: draw into
   a back buffer, wait for the vertical retrace, then copy it to A000h.
6. Keys in a game: an INT 9 handler, a table of held keys and a latch for
   taps between frames; EOI every interrupt; give every vector back on
   every way out. Esc quits and restores text mode 3.
7. Memory beyond your program is not yours until DOS says so: read the
   top at PSP:[2], or ask with INT 21h AH=4Ah/48h. A back buffer is a
   64000-byte segment you asked for.
8. On the site the DOS PC builds on A: (`build A:\MY\GAME\GAME.ASM`), in
   DOS 8.3 names, text in CR LF. A file DOS deletes there comes back;
   overwrite state files instead.
9. A small version that builds and runs first; then grow it a step at a
   time, testing with the screen and the keys. Fix a line, not the file.
10. A comment beside every arithmetic instruction; no dates or years
    invented in any text; the game tells its keys on its first screen.

## The topics

- TRAPS - what cost hours, as symptom -> cause -> fix. Read it first.
- FASM - the syntax, the 8086 set, what each instruction clobbers, the
  error messages and what they mean, building.
- MEMORY - .COM and .EXE, segments, far calls, buffers, the stack, DOS
  memory, what moves when a segment grows.
- VIDEO - mode 13h, the palette, the back buffer and the retrace; CGA,
  EGA, MCGA, Hercules and text mode; detecting the card.
- RENDER - fixed-point maths, sine and reciprocal tables, rotation,
  perspective and the camera, clipping, polygons and lines, terrain,
  sprites.
- TIME - the BIOS tick, the PIT, the retrace, frame pacing, a fixed
  physics step with catch-up, measuring inside a program.
- INPUT - INT 16h for menus, INT 9 for games, scan codes, latches and
  typematic repeats, the mouse, keys the browser keeps.
- SOUND - the PC speaker and the PIT, the Sound Blaster and DMA, music
  and effects.
- PHYSICS - motion in fixed point: forces, the flight model, the ground,
  collisions, landing, scale and overflow.
- GAMEPLAY - the design rules the games play by: consequences, controls
  that matter, AI, damage, the HUD, rounds and teams.
- MULTI - a multiplayer game on the site, step by step: `build --net`,
  A:\ENGINE\E_NET.INC, the packet, testing with two windows, a shared
  world.
- NET - IPX: INT 7Ah, ECBs, listen buffers, packets, who hosts, the
  WIRE CITY relay and its rooms.
- DOSBOX - the machine it runs on: DOSBox and js-dos in the browser,
  speed, drives and files, what pauses it, real-hardware differences.
- TOOLS - building and testing: FASM's command line, BUILD.BAT, the
  site's `build`, converters, testing without a person.
- COMMANDS - the site's console as an API: each command's effect and
  data (`help --json`), which lines ask the person first, and why.
- STYLE - the house style of code and text, a program's skeleton, what a
  game looks like when it is handed over.
