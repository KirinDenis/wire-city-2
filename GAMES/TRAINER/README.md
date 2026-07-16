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

Inside DOS (repo root mounted as C:): run `BUILD.BAT` in this folder.
From Windows: `MAKE.BAT` here, or `MAKE TRAINER` from the repo root —
it converts the model with OBJ2DAT and assembles with TASM in DOSBox.

## Keys

arrows = stick / nose-wheel steering · `+` `-` throttle · `F` flaps ·
`G` gear · `B` brakes · `Z`/`C` rudder · `V` view · `R` reset · ESC quit
