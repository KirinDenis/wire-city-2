# THE FLIGHT SCHOOL

A take-off and landing trainer, grown out of engine example 07 into its
own game. An airfield laid out to the real rules — the numbered runway
with threshold stripes and touchdown bars, a taxiway with the yellow
centreline, enterable hangars, a spinning radar dish — and a flight
model that knows VR, the stall, the crosswind and the difference
between a grease, a bounce and a crash.

**The aircraft is data, not code.** The model travels the honest way:

    Blender (res/Plane1.obj, PALnn materials) ->
    \TOOLS\OBJ2DAT.COM (pure 8086) -> PLANE1.DAT -> loaded at start-up

## Layout

| file | what |
|---|---|
| `SRC/FIELD.ASM`   | the frame loop, keys, state |
| `SRC/F_PHYS.INC`  | flight model, ground handling, warnings |
| `SRC/F_WORLD.INC` | runway, taxiway, hangars, the radar |
| `SRC/F_PLANE.INC` | the DAT model loader and aircraft renderer |
| `SRC/F_HUD.INC`   | readouts, warnings, the text kit, palette |
| `res/Plane1.obj`  | the aircraft, edited in Blender |

## Build

Mount the repository in DOSBox and, in this folder:

```
MAKE            pack the models, then assemble  ->  FIELD.COM
RUN             fly it
```

`MAKE` runs `TOOLS\OBJ2DAT.COM` over the six Wavefront models in `res/`
first — the game cannot read text at runtime — then assembles `SRC/FIELD.ASM`
with [flat assembler](https://flatassembler.net/) from `TOOLS/FASM`. Both are
in this repository; nothing has to be bought or installed. Build `OBJ2DAT`
first if it is not there: `cd TOOLS`, `MAKE`.

From Windows, `MAKEWIN` and `RUNWIN` do the same without your opening DOSBox
by hand, and `MAKEWIN CHECK` accounts for every byte of the difference against
the Turbo Assembler build frozen in [`TASM/TRAINER`](../../TASM/TRAINER).

## Keys

arrows = stick / nose-wheel steering · `+` `-` throttle · `F` flaps ·
`G` gear · `B` brakes · `Z`/`C` rudder · `V` view · `R` reset · ESC quit
