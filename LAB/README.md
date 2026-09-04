# LAB

Workbenches. Nothing in here ships.

Each folder is a program built to answer one question that a game is a bad
place to ask. A simulator never holds still — you cannot judge how a wall
looks from a cockpit doing 900 km/h — and a full 64 KB segment has no room
for the scaffolding an experiment needs. So the experiment gets its own
program, and pays for itself on the second iteration.

One folder per workbench, and each one builds itself:

| | |
|---|---|
| [`HOUSE/`](HOUSE) | one city block, standing still, and a camera to walk round it — the game's own cells and rasteriser, with nothing flying. Where windows, textures and explosions get their look. |
| [`OWLFLY4/`](OWLFLY4) | the experiments behind OWL FLY 4 — 32-bit code, VESA, full-motion video |

## Building any of them

Mount **the repository** in DOSBox — not the workbench folder — then `cd`
into the one you want and type `MAKE`, and `RUN` to see it.

Every path inside these folders is relative to the folder itself
(`..\..\TOOLS\FASM\FASM.EXE`, never `\TOOLS\...`). That is what lets you
mount the repository anywhere. It is also why mounting a subfolder breaks
the build: the tools are above it, and there is no longer an above.

From Windows, `MAKEWIN` and `RUNWIN` do the same without your opening DOSBox
by hand. They do not reimplement the build — they start DOSBox and run the
folder's own `MAKE.BAT`. There is one build, and it is the DOS one, because
that is the one a stranger will actually run.
