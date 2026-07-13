# WIRE CITY avionics, explained to a high-schooler

How the cockpit works: the tapes, the sight, the radar, the lamps —
told simply, with the real assembly and a runnable toy. Companion to
[GRAPHICS-101.md](GRAPHICS-101.md).

**Run it first:** [`EXAMPLES/AVIO.COM`](https://github.com/KirinDenis/wire-city-2/blob/main/EXAMPLES/AVIO.ASM)
is a flying instrument panel with no world attached — artificial
horizon, both tapes with the red stall line, a compass strip, a
blinking STALL lamp, and a toy flight model driving them (bank and the
heading starts walking; climb and the speed bleeds; stall and the nose
drops). Arrows are the stick, +/- the throttle. ~3 KB.

## 1. A tape is just ticks that scroll

A speed tape shows a window of values around the current speed. Don't
move the tape — move the MATH: for each round value near the current
one, compute its row and draw a tick. The value–row relation is one
subtraction and one shift:

```asm
        sub  ax,[spd]           ; how far is this tick from NOW
        sar  ax,1               ; 1 unit = half a pixel
        mov  bx,90
        sub  bx,ax              ; higher value = higher on the tape
```

The game draws two of these ([`HUDBARS` in SRC/HUD.INC](https://github.com/KirinDenis/wire-city-2/blob/v1.0/SRC/HUD.INC)),
and puts **red lines at the values that kill you**: on the speed tape
the stall speed, on the altitude tape — the height of the terrain
directly below, so the gap between the red line and the middle of the
tape IS your real clearance. Cheap to draw, priceless to read.

## 2. The gunsight stays level with the world

Roll the aircraft and the gunsight bar rotates the OPPOSITE way, so it
always lies parallel to the horizon — that's how the pilot keeps
spatial orientation in a turn. It is the same `*256` trig as
everything else, using the roll's sine and cosine to place the bar's
endpoints, plus a small tick that always points at the sky:

```asm
        mov  ax,[rcos]          ; bar direction = the horizon's
        mov  bx,14
        imul bx
        mov  bx,256
        idiv bx                 ; outer end, x component
```

Lose the horizon entirely (a loop, a vertical dive) and a standby
horizon appears right at the aiming ring. Source:
[`CROSS` in SRC/RASTER.INC](https://github.com/KirinDenis/wire-city-2/blob/v1.0/SRC/RASTER.INC).

## 3. The radar rotates the world, not itself

The radar is heading-up: your nose always points up the scope. No
special radar math exists — every blip is run through `ROTXZ`, the
same yaw rotation the 3D renderer uses, then scaled by a shift:

```asm
        call ROTXZ              ; world offset -> (right, ahead)
        mov  cl,9
        sar  ax,cl              ; 1 px = 512 world units
        sar  bx,cl
```

One instrument, zero new geometry code. Blips get IFF colours and
altitude ticks (a dot above = higher than you). Source: the radar
section of [`PANELBMP` in SRC/HUD.INC](https://github.com/KirinDenis/wire-city-2/blob/v1.0/SRC/HUD.INC).

## 4. Caution lamps are letters that blink

F for fuel, S for stall, T for terrain, L for lock. Each is one glyph
drawn over the cockpit artwork only when its condition holds, and only
on alternating ticks — blinking costs one `test`:

```asm
        mov  ax,[lasttk]
        test ax,2               ; dark phase: the artwork shows through
        jz   @@no
```

In the full game each lamp also *sings* its own note through the Sound
Blaster ring — you know which system complains without looking.

## 5. The photo cockpit: compiled at art time

The cockpit is a photograph (320×200) with a transparent windshield.
Blitting it per frame by testing every pixel would burn the frame
budget. Instead the art converter (`res/mkpanel.py`, Python) walks the
image ONCE at build time and emits a **span table**: runs of opaque
pixels as (offset, length) pairs. At runtime the blit is just:

```asm
@@sp:   lodsw                   ; offset (0FFFFh = done)
        cmp  ax,0FFFFh
        je   @@done
        mov  di,ax
        lodsw                   ; length
        mov  cx,ax
        rep  movsb              ; one opaque run, no per-pixel tests
```

The decision "is this pixel window or metal?" was made in 2026 by
Python so it never has to be made by the 8086. That's the whole
philosophy of this project in one instrument panel.

## Read next

[GRAPHICS-101.md](GRAPHICS-101.md) — the 3D under the panel ·
[ARCHITECTURE.md](https://github.com/KirinDenis/wire-city-2/blob/main/GAMES/OWLFLY/ARCHITECTURE.md) —
the whole machine · [play the game](https://kirindenis.github.io/wire-city-2/). ·
[README](https://github.com/KirinDenis/wire-city-2#readme) ·
[Community](https://www.facebook.com/groups/OWLOS)
