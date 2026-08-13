# Lesson 1 — The Screen Is Memory

The source typed in the video: [MEMORY.C](MEMORY.C). C, 16-bit real mode, DOS.
It runs on its own — nothing else in this repository is needed.

There is no graphics library in it, no driver and no output function. There
are two addresses:

| | | |
|---|---|---|
| `0xB800` | the text screen | 80 × 25 cells, **two** bytes per cell: the character, then its colour |
| `0xA000` | mode 13h | 320 × 200, **one** byte per pixel, and that byte *is* the colour |

Everything the program draws — a word of text, a dot, two lines and a square —
is the same two-line idea at those two addresses:

```c
vga[y * 320 + x] = c;
```

## The word that makes it possible

```c
unsigned char far *vga = (unsigned char far *) 0xA0000000L;
```

`far` is C admitting something about this machine that later machines let you
forget: **an address here is two numbers, not one.** A segment, and an offset
inside it. A near pointer can only reach inside whatever segment you happen to
be in; a far pointer carries both halves, and that is why the screen can be
named at all.

You will meet that fact again in every lesson after this one. It is the reason
the games in this repository are built the way they are, and eventually the
reason one of them had to become an EXE.

## Running it

You need a C compiler that targets 16-bit DOS. **[Open Watcom](https://open-watcom.github.io/)**
is free and open source, and it is the one this lesson is written for. It is
*not* vendored in this repository — it is a compiler for one lesson, and
everything else here needs only the assembler that already ships.

With `wcl` on the path, in DOS or on Windows:

```
wcl -0 -ml -bcl=dos MEMORY.C
```

- `-0` — write 8086 instructions and nothing newer
- `-ml` — the large memory model, so `far` pointers are the ordinary kind
- `-bcl=dos` — build a plain DOS executable

Run `MEMORY.EXE` in DOSBox. It waits for a key between stages, so press one to
move along.

## What it does, and why it looks like magic

The program never clears the screen and never prints anything. It writes
`HELLO` into the text screen at `0xB800` and the word is simply *there* — the
video card had been showing those bytes all along, before, during and after
the write. There is no "draw" step because there is nothing between the memory
and the glass.

Then it asks the BIOS for mode 13h and does the same thing at `0xA000`: one
pixel, a line, a line in another colour, and a square built out of four lines.
Same idea, different address, one byte instead of two.

Two things are worth knowing if you type it in rather than opening the file:

- **Always hand the text screen back.** The program ends with `SetMode(3)`. A
  DOS program owns the whole machine, including the video card, and nothing
  will put it right for you.
- **Do not use `scanf` or `getchar` to pause in mode 13h.** They echo, and the
  echo scrolls the picture. The pause here goes through interrupt 16h instead,
  which reads a key and says nothing.

## Why the corner is the top left one

Every graph you have ever drawn puts nought, nought at the **bottom** left. A
screen puts it at the **top** left, and it is worth knowing why, because it is
not a convention somebody picked.

Offset zero is the first byte of the segment, and the first byte is the one
drawn first. What decided *where* it gets drawn was the glass: the electron
beam swept from left to right, dropped a line, and swept again, working down
the screen. The bytes are simply laid out in the order the beam needed to read
them.

So the memory is not really a grid at all — it is one long row, and the grid
only exists because the machine takes that row a line at a time. Which is why
the arithmetic comes out the way it does:

```
x = 5, y = 0     ->  offset = 5             five along the first row
x = 0, y = 1     ->  offset = 320           one row down is one whole width
x = 5, y = 2     ->  offset = 2 * 320 + 5 = 645
```

Every canvas since has counted from that corner, and the reason is a beam that
stopped existing decades ago.

## Why a high-level language and not assembly

Assembly comes next in the series, and it changes none of this. It only makes
it fast enough to do sixty thousand times a second.

The point of starting here is that in DOS you reach the hardware directly
**from an ordinary language** — no driver, no system call, no permission, and
nothing in the way. That is not a trick of C. It is what the machine is: one
program, one address space, and the peripherals sitting in it where you can
touch them.

## On the versions

Nothing in this file needs a modern compiler or a new machine. Mode 13h and
the VGA card arrived in 1987; the text screen at `0xB800` is older still. Any
C compiler that can produce a 16-bit real-mode DOS program builds this
identically — Open Watcom is simply the one that is free, maintained and easy
to get today.

## The pictures at the start

**[INTRO.C](INTRO.C)** is the slide deck the narration talks over before any
code is typed — what we are going to draw, what stands between a modern
program and its pixels, what DOS takes away, and then six frames on the
question above: which byte, exactly, and why that corner.

It is built the same way and with the same tools:

```
wcl -0 -ml -bcl=dos INTRO.C
```

And it uses nothing this lesson does not teach: the same `far` pointer, the
same `y * 320 + x`, the same video BIOS for text. Everything in the opening
was drawn by the program you are about to write.

It times nothing. Every slide waits on interrupt 16h, exactly the way
`MEMORY.C` waits between its stages, so the pictures follow the narration
however long it happens to be.

## The Pascal twin

There is also **[MEMORY.PAS](MEMORY.PAS)** here: the same program in Turbo
Pascal, from the first recording of this lesson. Turbo Pascal is commercial
software and cannot be shipped with this repository, which is exactly why the
C version exists. If you happen to own it, the Pascal is a line-for-line twin
and worth reading beside the C — `Mem[$A000:o]` hides inside it the same
segment that `far` states out loud.

---

Made by [Owlos](https://owlos.sk). We modernise legacy software for the people
who still depend on it, and knowing how it was written the first time is the
whole reason we can.
