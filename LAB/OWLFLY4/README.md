# The OWL FLY 4 workbenches

OWL FLY 4 stands on a different machine from II and III: 32-bit code in a
flat address space, VESA 640x400, streamed sound and full-motion video.

None of that can be tried inside an existing game. The games are 16-bit real
mode, their main segment is full, and every one of these pieces is the kind
that either works alone or does not work at all. So each is proved here
first, by itself, and only then becomes engine.

| | |
|---|---|
| [`VIDEO/`](VIDEO) | the full-motion video format — a converter that packs it, and a DOS player that reads it back |

Planned and not started: a protected-mode and VESA smoke test, the software
mixer that feeds the Sound Blaster, and the pseudo-3D road for the driving
sections.

## What is already decided

**640x400, VESA mode 100h.** Exactly twice 320x200 in both directions, so
artwork and projection share one grid and a resolution switch is a
multiplier rather than a second branch through the whole renderer. 640x480
is 4:3 and would letterbox 16:10 material for nothing.

**Twelve frames a second.** Source footage is 24, and twelve is a clean
halving — every frame is held for exactly the same time. Fifteen out of
twenty-four is a ratio of 8:5, which judders, and it judders worst on slow
pans, which is most of what this game's scenes are.

**These programs are not 8086.** They are meant to use 386 instructions, so
they must **not** include `ENGINE/E_8086.INC` — the macro file the 16-bit
programs need because FASM, unlike TASM, has no `.8086` directive to stop it
quietly reaching for a 386 long jump. Here the long jump is welcome.

**A resolution switch, not a resolution.** The mode is chosen at startup the
way the games of this idiom did it, so the engine renders into a buffer of
W by H and only the blit and the projection scale know the difference.
