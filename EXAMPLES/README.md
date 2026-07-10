# WIRE CITY, taken apart

The game's engine is being split into small modules (`ENGINE/*.INC`), and each
example here is a tiny standalone `.COM` (a couple of KB) that demonstrates ONE
technique on the REAL engine code — the same include files the game itself
builds from. No duplication: fix the engine, and both the game and the
examples get the fix.

Each module states its **contract** at the top: the symbols (variables,
buffers) the including program must define. That is how 1986-style modularity
works — no linker-level libraries, no calling conventions, just documented
agreements about globals and registers.

## The examples

| # | File | What it shows | Engine modules |
|---|---|---|---|
| 01 | `TERRA.ASM` | The island factory: Diamond-Square on a 64×64 torus, integer only, seeded from the BIOS clock. Any key mints a fresh island, colour-banded exactly like the game's zoning. | `E_MATH`, `E_TERR` |
| 02 | `RING.ASM` | The one-channel mixer: a looping ring on auto-init DMA, effects added *ahead* of the playback beam, a heal pass erasing them *behind* it. Keys 1–4 fire a cannon pop, a missile hiss, an explosion and a beep — press several at once, they mix. | `E_MATH`, `E_SND` |

More are planned: the painter's-algorithm terrain mesh, the 13-vertex jet with
face sorting, the breakup physics. Ask for the one you want next.

## Building

From the repo root, `MAKE.BAT` builds the game **and** the examples (the
`.COM` files land right here). Inside DOSBox: `BUILD.BAT` does the same.
One example by hand, from `EXAMPLES\` in DOSBox with TASM on the path:

```
TASM /T TERRA.ASM
TLINK /t TERRA.OBJ
TERRA
```

## Reading order for the curious

1. `TERRA.ASM` — the simplest complete program: mode 13h, a palette, a loop.
2. `ENGINE\E_TERR.INC` — DSGEN: the diamond step, the square step, why the
   torus (`AND 63`) removes all edge special-casing, and why a histogram
   stretch follows.
3. `RING.ASM` — the DSP/DMA bring-up sequence, then the mixer idea.
4. `ENGINE\E_SND.INC` — the three primitives everything sonic is built from.
5. `SRC\` — the whole game, built from the same parts.
