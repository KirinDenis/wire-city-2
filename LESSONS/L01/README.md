# Lesson 1 — The Screen Is Memory

The source typed in the video: [MEMORY.PAS](MEMORY.PAS). Turbo Pascal 7, real
mode, DOS. It runs on its own — nothing else in this repository is needed.

There is no graphics library in it, no BGI driver and no output function.
There are two addresses:

| | | |
|---|---|---|
| `$B800` | the text screen | 80 × 25 cells, **two** bytes per cell: the character, then its colour |
| `$A000` | mode 13h | 320 × 200, **one** byte per pixel, and that byte *is* the colour |

Everything the program draws — a word of text, a dot, two lines and a square —
is the same two-line idea at those two addresses:

```pascal
o := y * 320 + x;
Mem[$A000:o] := c;
```

## Running it

Any DOS with Turbo Pascal 7 will do, DOSBox included. Open `MEMORY.PAS` in the
IDE and press **Ctrl-F9**, or compile it with `TPC MEMORY.PAS`. It waits for a
key between stages, so press one to move along.

Two things worth knowing if you type it in yourself rather than opening the
file: the IDE's **auto-indent** adds the previous line's indentation on top of
whatever you type (`Ctrl-O I` turns it off), and `ReadLn` is the wrong way to
pause in mode 13h — it echoes, and the echo scrolls the picture. That is why
the pause here goes through interrupt 16h instead.

## On the date

The Pascal here is version 7, from 1992, but nothing in this file needs it.
VGA and mode 13h arrived in **1987**, the text screen at `$B800` goes back to
1981, and Turbo Pascal 4.0 from 1987 compiles every line of this identically.
By the late eighties all of it — the hardware and the tool — was ordinary.

## Why Pascal and not assembly

Assembly comes later in the series, and it changes none of this. It only makes
it fast enough to do sixty thousand times a second. The point of starting here
is that in DOS you can reach the hardware directly *from a high level
language* — no driver, no permission, nothing in the way.

---

Made by [Owlos](https://owlos.sk). We modernise legacy software for the people
who still depend on it, and knowing how it was written the first time is the
whole reason we can.
