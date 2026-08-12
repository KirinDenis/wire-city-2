# WIRE CITY, taken apart

The game's engine is being split into small modules (`ENGINE/*.INC`), and each
example here is a tiny standalone `.COM` (a couple of KB) that demonstrates ONE
technique on the REAL engine code — the same include files the game itself
builds from. No duplication: fix the engine, and both the game and the
examples get the fix.

Each module states its **contract** at the top: the symbols (variables,
buffers) the including program must define. That is how modularity works
without a linker — no libraries, no calling conventions, just documented
agreements about globals and registers.

> **The engine is mid-migration.** These examples build with FASM and include
> `ENGINE/E_*F.INC`, the translated modules. `ENGINE/E_*.INC` are still the
> Turbo Assembler originals, because four games and the lab have not moved yet
> and build from them. When the last one does, the `F` disappears and the
> originals join the rest in `TASM/`. Until then the two sit side by side, and
> that is the honest state of the folder rather than a tidy fiction.

## The examples

| # | File | What it shows | Engine modules |
|---|---|---|---|
| 01 | `TERRA.ASM` | The island factory: Diamond-Square on a 64×64 torus, integer only, seeded from the BIOS clock. Any key mints a fresh island, colour-banded exactly like the game's zoning. | `E_MATH`, `E_TERR` |
| 02 | `RING.ASM` | The one-channel mixer: a looping ring on auto-init DMA, effects added *ahead* of the playback beam, a heal pass erasing them *behind* it. Keys 1–4 fire a cannon pop, a missile hiss, an explosion and a beep — press several at once, they mix. | `E_MATH`, `E_SND` |
| 03 | `JET.ASM` | The hangar: ALL FIVE aircraft of the game (Up/Down to cycle — fighter, four-engine bomber, rotodome radar picket, transport, tanker) spinning through the REAL pipeline — quarter-table sine rotation, face depths, a far-to-near bubble sort (nearly O(n): the order barely changes between frames), near-clip → project → scanline-fill. Painter's algorithm, no z-buffer. Arrows steer the spin; the nozzle burns by DAC cycling. | `E_MATH`, `E_M3D`, `E_RAST` |
| 04 | `AVIO.ASM` | The avionics: a flying instrument panel with no world — artificial horizon (roll-rotated, pitch-shifted), speed/altitude tapes with the red stall line, a compass strip, the blinking STALL lamp, all driven by a toy flight model (bank → the heading walks; climb → the speed bleeds). Arrows = stick, +/− = throttle. | `E_M3D`, `E_RAST` |
| 05 | `SPOOL.ASM` | The spool-up: the 2.5 seconds *before* the takeoff roll, a line on the spectrogram climbing from ~1.5 to ~3 kHz while nothing on screen moves yet. Played on the game's own sound rig. | `E_MATH`, `E_SND` |
| 06 | `SMOKE.ASM` | The fire-and-smoke laboratory: FIRE particles age into SMOKE puffs — many-sided random polygons that spin, swell and rise on buoyancy, drag, a gentle vortex and random-walk turbulence. | `E_MATH`, `E_M3D` |
| 07 | `TKOFF.ASM` | The measured takeoff: a keyframe replay of a cockpit tape, no controls and no simulation. If the replay looks and sounds like the tape, the renderer and the pacing are right — and the physics has a target to reproduce. | `E_MATH`, `E_SND` |
| 08 | `FLIGHT.ASM` | The airshow: TKOFF's sequel. The same takeoff, then level-off, a full aileron roll and a hard pull into pure sky. The manoeuvre program is a little table of (ticks, roll rate, pitch rate) at the bottom of the file. | `E_MATH`, `E_SND` |
| 09 | `LAND.ASM` | The measured landing: short final, the worked throttle of a real approach, the flare, the ~15 second float in ground effect, the kiss, derotation, and the seam thumps fading as it slows. | `E_MATH`, `E_SND` |
| 10 | `TKPHYS.ASM` | The takeoff **by forces**: TKOFF's twin with the script torn out. Thrust, drag, rolling friction — the speed comes from Newton, and the number to beat is the tape's. | `E_MATH`, `E_SND` |
| 11 | `LNDPHYS.ASM` | The landing **by forces**: LAND's twin, likewise. Nothing follows a timeline; the whole approach emerges from lift, drag, mass and gravity. | `E_MATH`, `E_SND` |
| 12 | `SOLO.ASM` | The first solo: the whole flight school in one machine and nobody in the back seat. Parked on the slab — throttle, roll, rotate when the wing is ready (the lift decides, not a script), fly the flat world, judge the descent, gear, flaps, and put it on the next runway. | `E_MATH`, `E_SND` |
| 13 | `BBS.ASM` | The chat terminal: multi-user IPX broadcast written against the real IPX API — INT 7Ah, ECBs, broadcast packets. In desktop DOSBox it talks over `ipxnet`; in the browser the emulator tunnels the same packets through WebSocket. | — |

The pairs are the point of the set. `TKOFF`/`TKPHYS` and `LAND`/`LNDPHYS` are
the same manoeuvre twice: once as a recording played back, once as forces
integrated. Put them side by side and the physics has something to be wrong
against.

## Building

Everything you need is in this repository. Nothing has to be bought,
downloaded or installed — the assembler is here, and it is free to use and to
pass on. Mount the repository in DOSBox (or run it on real DOS), then:

```
cd EXAMPLES
MAKE            assemble all thirteen
MAKE JET        just that one
RUN JET         run it
```

The assembler is [flat assembler](https://flatassembler.net/), in
`TOOLS/FASM`. There is no linker step — FASM writes the `.COM` directly. It
loads a small DPMI host from `TOOLS/CWSDPMI` first, because the assembler is a
32-bit program and DOS is not; `MAKE` does that for you.

From Windows, `MAKEWIN` and `RUNWIN JET` do the same without your opening
DOSBox by hand. They do not reimplement the build — they drive `MAKE.BAT`
through DOSBox, so there is only ever one way these are assembled.

### The Turbo Assembler versions

These were written for Borland's Turbo Assembler, and those originals are kept
unchanged in [`TASM/EXAMPLES`](../TASM/EXAMPLES) along with the binaries they
produced. You do not need them, and unless you own TASM you cannot build them,
which is exactly why the FASM translation exists.

The two sets of binaries are **not** meant to match, and the difference is
checked rather than assumed:

```bash
EXAMPLES\MAKEWIN.BAT CHECK
```

That runs [`TOOLS/BinAccount`](../TOOLS/BinAccount) over all thirteen. It
decodes both builds instruction by instruction and has to be able to name
every byte of the difference — padding TASM could not take back, a jump one of
them encoded shorter, an address that moved. It prints in hex and stops at
anything it cannot name. All thirteen are fully accounted for.

That accounting is what caught the one real bug in this migration. TASM's
`.8086` restricts the instruction set and **FASM has no equivalent**, so
dropping it in translation quietly let FASM encode out-of-range conditional
jumps in the 386 long form. [`ENGINE/E_8086.INC`](../ENGINE/E_8086.INC) puts
the restriction back, and every one of these includes it.

## Reading order for the curious

1. `TERRA.ASM` — the simplest complete program: mode 13h, a palette, a loop.
2. `ENGINE\E_TERRF.INC` — DSGEN: the diamond step, the square step, why the
   torus (`AND 63`) removes all edge special-casing, and why a histogram
   stretch follows.
3. `RING.ASM` — the DSP/DMA bring-up sequence, then the mixer idea.
4. `ENGINE\E_SNDF.INC` — the three primitives everything sonic is built from.
5. `TKOFF.ASM` then `TKPHYS.ASM` — the same takeoff played back, then
   derived. The second file is where the aeroplane stops being a cartoon.
6. `SOLO.ASM` — all of it at once, and the nearest thing here to a game.
7. `GAMES\OWLFLY2\SRC\` — the whole simulator, built from the same parts.
