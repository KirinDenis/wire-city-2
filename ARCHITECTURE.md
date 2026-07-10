# WIRE CITY 86 — how it works

A combat flight simulator in one 41 KB `.COM` file: pure 8086 assembly,
VGA mode 13h, integer math only, no libraries. This document is the map
of the whole machine — written when the project reached the natural
limits of its architecture and stopped, on purpose, while everything
still works.

## The one-segment discipline

A `.COM` program owns exactly one 64 KB segment. Code, data, BSS and the
stack all share it:

```
0000  PSP
0100  code + initialized data     (~41 KB, the file)
....  BSS: heightmap, mesh caches, span table, wreck pool,
      black box, ruins bitmap     (~23 KB, zeroes never shipped)
FFFE  stack, growing down
```

**The budget rule that ruled the project:** `0x100 + file size + BSSEND`
must stay well under 65536, or the BSS silently eats the stack — the
symptom is an instant grey screen. Every feature was costed against this
number. When it ran out, data moved to *far segments*:

- `bufseg = CS + 0x1000` — the 320×200 back buffer
- `resseg = CS + 0x2000` — CITY.DAT: the photo cockpit and the font
- `sndseg = (CS+0x3FFF) & 0xF000` — the sound ring, 64K-ALIGNED so the
  32 KB DMA loop can never cross a page boundary *by construction*; its
  top half holds a pristine copy of the loop
- `scrseg = sndseg + 0x1000` — the baked minimap (4 KB)

Total working set ≈ 260 KB of conventional RAM. A 384K PC suffices.

## Rendering: the painter, three times over

No z-buffer anywhere. A 64 KB depth buffer would outweigh the program.

1. **Terrain and buildings** — not even sorted at runtime. `TORD`/`BORD`
   are tables of *camera-relative* cell offsets pre-sorted by squared
   distance, far to near. Translation doesn't change relative order, so
   one table serves every camera position: the world costs **zero sort
   per frame**. 1600 heightmap quads plus city blocks, on an 8086.
2. **Aircraft** — 13..25 vertices, 8..12 quad faces per type (variable
   geometry: `MVTAB/MVNTAB/MFTAB/NFCTAB`, the first 13/8 are always the
   core airframe). Faces bubble-sorted by average depth each frame —
   between two frames the order barely changes, so the bubble is nearly
   O(n), and n is at most 12.
3. **Face pipeline** — near-plane polygon clip (`CLIPNEAR`), perspective
   projection with overflow guards scaled to the lens (`PROJPT`), and a
   scanline filler (`SCANPOLY`). The clipper is hardened: on the 8086,
   INT 0 fires on divide-by-zero AND quotient overflow, so the edge
   interpolation clamps t into [0..1] — garbage clips ugly instead of
   crashing (a lesson delivered by Turbo Debugger).

Known honest limitation: aircraft draw after the world, assuming a sky
background — a jet directly behind a tower paints over it. The fix (one
depth test per jet against the occluding column) is left as the first
exercise for a fork.

## The world: shipped as a recipe

`DSGEN` builds a 64×64 heightmap by integer Diamond-Square **on a
torus** (`AND 63` wraps both axes — no edge special-casing anywhere),
then histogram-stretches it to 0..255 because plain midpoint averaging
flattens toward grey. The seed is the BIOS tick count at launch: nobody
has ever flown the same island twice. Zoning is pure height bands: sea,
plains, city lowlands, woods, rock, snow. The city plan, building
shapes and window glyphs all derive from cell hashes — the world ships
as ~150 instructions, not as data.

Two number-theory lessons live in this file, both caught by a human
holding down a key and watching the flip-book:

- A mod-2^16 LCG's low k bits cycle every 2^(k+1) draws. One DSGEN is
  exactly 4096 draws — 4096 ≡ 0 (mod 128), so islands repeated. **Use
  the high byte.**
- 65536/4096 = 16 phases, and the half-period symmetry
  x[n+32768] = x[n]+0x8000 pairs them: exactly 8 distinct islands,
  counted by eye. **One extra draw per island** makes the stride 4097,
  coprime with the period: the full orbit.

## Sound: the ring is the mixer

One Sound Blaster DMA channel, no mixer chip, four kinds of one-shot
effects over a looping engine:

- The engine is a real recording (32 KB, 11025 Hz, loop-smoothed by
  `res/mkengine.py`), spinning forever on auto-init DMA. The game
  touches ONE knob: the DSP time constant — throttle spools the pitch,
  the afterburner leans on it, manoeuvre loading bends and wavers it,
  a dying engine winds down to a groan.
- Effects (cannon pops, missile hiss, explosions by distance, caution
  beeps — each lamp its own note) are **added into the ring ~60 ms
  ahead of the DMA beam** (the 8237 tells us where the beam is), play
  once as the beam sweeps through, and a heal pass restores the ring
  behind the beam from the pristine copy. Overlapping effects sum with
  clamping — a real mixer, made of memory.

## Time: physics at 18.2 Hz, motion smoother

The PIT stays untouched (hooking it hangs this DOSBox); physics ticks
at the BIOS 18.2 Hz clock. Rendering interpolates the camera between
the last two ticks by frame counting — no sub-tick timer exists, and
none is needed.

## The war

Two 20-ship teams: 13 fighters, 3 four-engine bombers, 1 rotodome
radar picket, 2 transports, 1 tanker (variable geometry per type; the
wreck pool breaks the core airframe, so nacelles vanish unmourned). A
jagged red front line splits the island north/south on both map MFDs;
formations spawn facing each other across it. Everything collides,
attrition is permanent within a round, buildings are destructible and
stay ruins. The dead radar picket, the paradrops, the tanker hose —
designed, staged, and left on the drawing board: the 64K was spoken for.

## Build pipeline

`MAKE.BAT` (Windows) → converters (`mkpanel.py`, `mkengine.py`) →
headless DOSBox → TASM 3.2 one-pass + TLINK /t → `INSTALL\CITY.COM`.
The one-pass rules that shaped the code:

- constants used as immediates must be defined BEFORE the include
- symbols are case-insensitive (TRX vs trx: one namespace)
- `JUMPS`, `LOCALS`, `.8086` — or long conditional jumps won't assemble
- the assembler doubles as the module documenter: build, read the
  undefined symbols, and that's the module's contract

## ENGINE/ and EXAMPLES/

The engine is split 1986-style — not a library, but modules with
CONTRACTS: each `ENGINE/*.INC` states the symbols its includer must
define, and the game includes the same files the examples do. Each
example is a standalone `.COM` of a few KB: `TERRA` (the island
factory), `RING` (the one-channel mixer), `JET` (the hangar: all five
aircraft with ROM-font spec sheets, Space blows them apart). The
decomposition paid for itself on day one — TERRA exposed the LCG
resonance that the game had been masking for weeks.

## Where it stops, and why

The project ends by decision, not by accident. The 64K segment is
spoken for (the stack margin was fought back twice by exiling data to
far segments); 16-bit world coordinates wrap at the ×4 scale (the
hardened clipper turns those wraps from crashes into glitches, but the
wraps themselves are the architecture speaking); and every further
feature now costs a reclaim campaign first. The honest next step is not
another squeeze — it's an EXE with far segments, 32-bit coordinate
math, and that is a different program. This one is complete: it flies,
it fights, it sounds, it fits in the memory of a machine from 1986 —
and every byte of it can be read.
