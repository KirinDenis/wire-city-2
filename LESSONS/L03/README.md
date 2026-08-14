# Lesson 3 — The Screen, One Byte At A Time

### ▶ Run it and rebuild it in your browser: https://kirindenis.github.io/wire-city-2/l03.html

Lesson 1 put a pixel on the screen in C. Lesson 2 showed that a program is
only bytes in a file. This one puts the two together: **the screen is bytes as
well**, and from here on we write them ourselves.

[PIXEL.ASM](PIXEL.ASM) is 237 bytes and draws seven frames. A key moves on,
Esc leaves early.

```
cd LESSONS\L03
MAKE
RUN
```

| | frame | what it is actually for |
|---|---|---|
| 1 | one dot | one byte, at one address. That is the whole of it. |
| 2 | every colour there is | 64000 bytes, each one greater than the last |
| 3 | black | and nothing else, because we asked for it |
| 4 | two lines | why one of them is a single instruction and the other cannot be |
| 5 | an empty square | drawn straight on top — **nothing was cleared** |
| 6 | a filled square | the same line as frame 4, done forty-eight times |
| 7 | two hundred of them | random colours, random places, one routine |

> **Why the file is in the order it is.** Everything a frame needs — the way
> out, and the wait for a key — is declared at the top and jumped over, so
> everything below `Boot` is the frames, in the order they run. That is not
> tidiness: it is how the lesson is recorded. Each step adds a few lines to
> the **end** of the file and assembles again, so the program on screen only
> ever grows downwards and nobody has to steer a cursor into the middle of
> something that already works.

## The whole of the arithmetic

```
offset = y * 320 + x
```

That is the same line lesson 1 wrote in C, and it is still the only arithmetic
in the file. The screen is not a grid. It is **one long row of 64000 bytes**,
and it only looks like a grid because the card reads 320 of them, drops a line,
and reads 320 more.

Two lines set it all up:

```asm
        mov  ax, 0013h          ; mode 13h - 320 x 200, 256 colours
        int  10h
        mov  ax, 0A000h
        mov  es, ax             ; from here on ES *is* the screen
```

After that, a pixel is a `mov`.

## Frame 2 is the one that proves it

The second frame writes 64000 bytes, and each is the number after the one
before it:

```asm
        xor  di, di
        xor  al, al
        mov  cx, W*H            ; 64000 - every byte there is
.pal:   stosb                   ; ES:DI <- AL, then DI steps on by one
        inc  al
        loop .pal
```

Nothing in there says *where* a colour goes. The colours are simply laid down
the memory in order — and what comes out is a set of **diagonal stripes**.

That slant is the proof. A row is 320 bytes wide and there are only 256
colours, so every row starts 64 colours further along than the row above it.
The picture is slanted because 320 does not divide by 256. If the screen were
really a grid of rows, it could not do that.

> It is also the cheapest test in the repository: check the pixel at `(0, y)`
> against the one at `(64, y-1)`. Their offsets differ by exactly 256, so they
> must be the same colour, on all 199 pairs. They are.

## Frame 4: what a line costs

```asm
        mov  di, 100*W + 60     ; across
        mov  cx, 200
        rep  stosb              ; ...and that is the whole line

        mov  di, 40*W + 160     ; down
        mov  cx, 120
.down:  mov  byte [es:di], 14
        add  di, W              ; the pixel below is 320 bytes further on
        loop .down
```

Same line on the glass. Completely different price: across, the pixels are
next to each other in memory, so one instruction draws all two hundred. Down,
they are 320 bytes apart, so it has to be a loop.

**That difference is why everything in these games is drawn in horizontal
spans** — the terrain, the aircraft, the cockpit. It is not a style. It is
what the memory layout charges you.

### STOS is not MOVS

Clearing the screen uses `rep stosw`, and the two string instructions are easy
to confuse:

- **`STOS`** *stores* AL or AX into `ES:DI`. It fills, and it needs no source.
- **`MOVS`** *copies* from `DS:SI` to `ES:DI`. It needs something to copy from.

There is no page of zeroes lying around to copy, so filling is the right
instruction here. `MOVS` is what the next lesson is about: pouring a second
screen, drawn where nobody can see it, onto this one.

## Frame 5: nothing is ever cleared

The empty square is drawn without clearing first, and the lines are still
underneath it. There is no scene here, no display list, and nobody tidying up
behind you. **The screen holds whatever was last written into it** — which is why frame 3
has to exist at all. The screen going black is something we had to ask for,
and a game that forgets to ask is a game covered in the last frame's wreckage.

## Frames 6 and 7: nothing new was invented

A filled rectangle is the horizontal line from frame 4, done once per row:

```asm
;   DI = top-left offset    AL = colour    BX = width    DX = height
Rect:   push di
        mov  cx, bx
        rep  stosb              ; one row - the same single instruction
        pop  di
        add  di, W              ; down to the next row
        dec  dx
        jnz  Rect
        ret
```

And two hundred of them in random places is that routine, called two hundred
times, with a five-line random number generator feeding it. It is not random at all,
and you can prove that without reading a line of it: **run the program twice**
and frame 7 comes out identical, square for square. Nothing asked the clock
what time it was.

That is the trick, not the shortcoming — two bytes of seed instead of a stored
picture. It is how a city gets built later in this series, and how two machines
on a network end up in the same world without sending it to each other.

## Tools

DOSBox and `TOOLS/FASM` from this repository. Nothing else, and nothing to buy.

---

Made by [Owlos](https://owlos.sk). We modernise legacy software for the people
who still depend on it, and knowing how it was written the first time is the
whole reason we can.
