# WIRE CITY 3D, explained to a high-schooler

The same machine as [GRAPHICS.md](GRAPHICS.md), but told simply — with
the real assembly pasted in and links to small runnable programs. You
can read this with zero 3D background and leave understanding how a
40 KB DOS game draws a world.

## 0. What happens every frame

Imagine a painter redrawing the whole picture 30 times a second: sky
first, then far mountains, then the city, then the aircraft, then the
cockpit on top. He paints on a scratch canvas in memory, and only when
the picture is DONE it goes to the screen in one move (`rep movsw`,
64000 bytes). That's why you never see a half-drawn frame.

## 1. Fractions without fractions

A 1986 CPU has **no fractional numbers** — integers only. But sines and
cosines are all fractions (0.7071...). The trick: store everything
**multiplied by 256**. sin 45° = 0.7071 → store 181. To rotate a point,
multiply by 181 and divide by 256 — the two 256s cancel. This exact
idiom appears hundreds of times in the code:

```asm
        imul word ptr [hcos]    ; DX:AX = x * cos*256
        mov  bx,256
        idiv bx                 ; /256 - the scale cancels out
```

Second trick: **a full circle is 256 "degrees", not 360**. Why? Because
0..255 fits a byte, and wrapping past a full turn becomes automatic:

```asm
SINQ:   and  ax,255             ; wrap to one circle - THAT'S IT.
                                ; no "if angle >= 360 subtract 360"
```

The whole sine machinery is a 65-entry quarter table plus symmetry —
see [`SINQ` in ENGINE/E_M3D.INC](https://github.com/KirinDenis/wire-city-2/blob/v1.0/ENGINE/E_M3D.INC).

## 2. Perspective, and its bodyguard

Projecting 3D onto the screen is one textbook line — the farther away
(bigger `rz`), the closer to the centre:

```asm
        mov  bx,FOCAL
        imul bx                 ; DX:AX = rx * FOCAL
        idiv cx                 ; AX = rx*FOCAL/rz  -> screen offset
```

Now the part textbooks skip. If a point is almost AT the camera (tiny
`rz`) but far to the side (huge `rx`), the quotient doesn't fit 16 bits
— and on the 8086 **that kills the machine**: `idiv` raises INT 0 not
only on division by zero but on quotient overflow too. So the real code
posts a bodyguard before the divide:

```asm
        cmp  cx,256             ; rz >= 256: even the worst rx is safe
        jge  @@sxok
        mov  ax,cx
        mov  dx,32767/FOCAL     ; the safe |rx|/rz ratio for this lens
        mul  dx
        cmp  bx,ax              ; |rx| <= rz*(32767/FOCAL) ?
        jbe  @@sxok             ; yes: divide away
        mov  bx,4000            ; no: clamp far off-screen, keep the sign
```

Full routine: [`PROJPT` in ENGINE/E_M3D.INC](https://github.com/KirinDenis/wire-city-2/blob/v1.0/ENGINE/E_M3D.INC).
We caught a real crash from an unguarded divide **under Turbo Debugger**
during development — the story is in section 5.

## 3. The big trick: a painter instead of a z-buffer

Any 3D renderer must make the near building hide the far one. The
"proper" solution is a z-buffer: remember the depth of **every screen
pixel**. At 320×200 that's 64 KB — **more than this entire game**.

The painter's solution: **draw far things first, near things last** —
near paint covers far paint, like brush strokes. All you need is the
right order. And here is the project's crown jewel:

**The world was sorted once, before the game even runs.** Not the
buildings — the **offsets relative to the camera**: "5 cells right and
3 ahead", "1 left and 1 ahead"... Wherever the camera flies, the cell
"5 right, 3 ahead" is always farther than "1 left, 1 ahead" — **moving
the camera never changes the relative order**. So one pre-sorted table
is correct from every position, forever. The renderer just walks it:

```asm
@@tl:   mov  al,[TORD+si]       ; di (signed cell offset, pre-sorted
        cbw                     ;     far -> near at assembly time)
        add  ax,[tnx]           ; + camera cell = the cell to draw NOW
```

Sorts per frame: **zero**. Tables: [`TORD`/`BORD` in SRC/DATA.INC](https://github.com/KirinDenis/wire-city-2/blob/v1.0/SRC/DATA.INC).
Watch it work: run [`EXAMPLES/TERRA.COM`](https://github.com/KirinDenis/wire-city-2/blob/v1.0/EXAMPLES/TERRA.ASM)
— the island generator this world is built on (any key = a new island).

## 4. Aircraft: the bubble sort that earns respect

Aircraft rotate freely, so their 8..12 faces DO need sorting every
frame. We use **bubble sort** — the algorithm your CS teacher mocks.
The secret: bubble sort is only slow on SHUFFLED data. Between two
frames (1/30 s) a jet turns a hair's width — the face order is almost
unchanged, and on almost-sorted data a bubble flies through in one
pass. A "bad" algorithm in the right place is a great algorithm:

```asm
@@bi:   mov  bx,si
        add  bx,bx
        mov  ax,[FCD+bx]        ; two neighbouring face depths...
        cmp  ax,[FCD+bx+2]
        jge  @@nsw              ; ...already in order? next
        xchg ax,[FCD+bx+2]      ; swap depths
        mov  [FCD+bx],ax
        mov  al,[FCO+si]        ; and swap the draw order with them
        xchg al,[FCO+si+1]
        mov  [FCO+si],al
@@nsw:  inc  si
```

See it live: [`EXAMPLES/JET.COM`](https://github.com/KirinDenis/wire-city-2/blob/v1.0/EXAMPLES/JET.ASM)
— the hangar. Up/Down cycles all five aircraft, arrows spin them (watch
the faces overlap correctly at every angle — that's the bubble working),
Space blows one apart and the SAME sort keeps ordering the flying
debris. ~5 KB, and it uses the very engine files the game flies.

## 5. The scissors

What if a wall is half BEHIND the camera? Drawing it would hit the
overflow from section 2. So every face is first cut by invisible
scissors at the near plane: vertices behind are dropped, and new points
are computed where edges cross the plane. The interpolation there
carries a battle scar — a garbage face once drove the divide into
overflow, the game froze, the user caught it under **Turbo Debugger**,
we mapped the address to a source line with a TASM listing, and the fix
clamps the parameter so overflow became mathematically impossible:

```asm
@@tok:  mov  ax,[tnum]          ; clamp t into [0..1]: with 0<=t<=1 the
        or   ax,ax              ; quotient can never exceed |x1-x0|,
        jns  @@tn1              ; so INT 0 simply cannot fire
        mov  word ptr [tnum],0
```

Full pipeline (clip → project → scanline fill):
[`ENGINE/E_RAST.INC`](https://github.com/KirinDenis/wire-city-2/blob/v1.0/ENGINE/E_RAST.INC),
search `APPENDISECT`.

## 6. What we deliberately DON'T do

- No z-buffer (64 KB — bigger than the game).
- No per-pixel visibility — decisions are per-face and per-cell.
- One honest hole: aircraft draw after the world, assuming sky behind
  them. A jet directly behind a tower shows through it. Fixable with
  one cheap depth test per jet — left as the first exercise for a fork.

## The whole thing in one paragraph

Three ideas carry all of it: **multiply fractions by 256** (now there
are no fractions), **paint far-to-near** (now there is no z-buffer),
and **sort offsets, not objects** (now sorting is free) — plus paranoia
before every `idiv`. That's enough for a flying war in 40 kilobytes,
and every line of it is open:
[the game](https://github.com/KirinDenis/wire-city-2/tree/v1.0/SRC) ·
[the engine](https://github.com/KirinDenis/wire-city-2/tree/v1.0/ENGINE) ·
[the examples](https://github.com/KirinDenis/wire-city-2/tree/v1.0/EXAMPLES) ·
[play it in the browser](https://kirindenis.github.io/wire-city-2/).

---
[README](https://github.com/KirinDenis/wire-city-2#readme) ·
[The engineer's version](GRAPHICS.md) ·
[Avionics](AVIONICS-101.md) ·
[Community](https://www.facebook.com/groups/OWLOS)
