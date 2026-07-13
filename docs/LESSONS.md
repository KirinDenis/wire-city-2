# What 40 kilobytes taught us

The transferable lessons of WIRE CITY 86 — each learned the hard way in
this repo, each applicable far beyond DOS. Companion to
[ARCHITECTURE.md](https://github.com/KirinDenis/wire-city-2/blob/main/GAMES/OWLFLY/ARCHITECTURE.md).

## 1. A visible budget makes architecture honest

Code, data and stack shared one 64 KB segment, and every feature was
costed in bytes BEFORE it was written; the failure symptom was an
instant grey screen. That sounds like hell; it is the best school there
is. When the resource is visible and finite, design decisions stop
being matters of taste. **Modern translation:** set bundle-size, memory
and latency budgets before the first line, and check them on every
merge — not when users complain.

## 2. Move work to build time

The world's draw order is sorted once, forever (offsets, not objects —
zero sorts per frame). The photo cockpit is compiled by a Python script
into a span table so the CPU never asks "is this pixel glass or
metal?". **Anything decidable at build time must not be decided at run
time** — true for asset pipelines, codegen, and precomputed indexes
alike.

## 3. "Bad" algorithms in the right place are great algorithms

The aircraft faces are bubble-sorted every frame — and it runs nearly
O(n), because between two frames the order barely changes. Knowing your
DATA beats knowing your textbook. Measure the actual workload before
reaching for the clever structure.

## 4. Debug the binary with the era's own tools

A hang was caught under Turbo Debugger (one screenshot: instruction +
address), and `TASM /l` turned the address into a source line in one
grep. The same two-step rescues any DOS-era binary — which is,
incidentally, [our day job](https://owlos.sk/).

## 5. Number theory is watching you

A mod-2^16 LCG's low bits cycle fast; one island cost exactly 4096
draws; 4096 mod 128 = 0 — every island was identical. The residual
8-island cycle was counted BY EYE: hold a key, watch the flip-book,
your visual cortex is a period detector. Fixes: use the high byte, and
make the stride coprime with the period. Full story in
[GRAPHICS-101](GRAPHICS-101.md) and the
[E_TERR source](https://github.com/KirinDenis/wire-city-2/blob/main/ENGINE/E_TERR.INC).

## 6. INT 0 is not just divide-by-zero

On the 8086 it also fires on QUOTIENT OVERFLOW. Half the "mysterious"
crashes in old binaries live here. Guard every division whose operands
you don't fully control — or better, bound them mathematically (our
clipper clamps t into [0..1], after which overflow is impossible).

## 7. Contracts beat frameworks at small scale

The engine modules declare, in a comment, which symbols the including
program must define — and the one-pass assembler ENFORCES the contract
by listing undefined symbols. Documentation the compiler checks is the
only documentation that stays true.

## 8. Stop on purpose

The project wrapped when the architecture said so: the segment was
spoken for, 16-bit coordinates wrapped at the new scale. We reverted
the last unstable feature, documented everything, and tagged v1.0.
Knowing where a system ends is a feature of the system.

---
[Play the game](https://kirindenis.github.io/wire-city-2/) ·
[README](https://github.com/KirinDenis/wire-city-2#readme) ·
[3D for beginners](GRAPHICS-101.md) ·
[Avionics](AVIONICS-101.md) ·
[Community](https://www.facebook.com/groups/OWLOS) ·
[Owlos](https://owlos.sk/)
