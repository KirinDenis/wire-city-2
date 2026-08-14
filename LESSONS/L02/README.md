# Lesson 2 — The File Is The Program

### ▶ Do it yourself, in your browser: https://kirindenis.github.io/wire-city-2/l02.html

[HELLO.ASM](HELLO.ASM) becomes an eighteen-byte `.COM`,
[HELLO2.ASM](HELLO2.ASM) becomes an eighty-one-byte `.EXE`, and they print
almost the same thing. The difference between them is the lesson.

The third source, [HEX.ASM](HEX.ASM), is the tool the lesson needs to look at
those bytes and change them — see [below](#the-byte-viewer-is-part-of-the-lesson).

## Building them

The assembler is [flat assembler](https://flatassembler.net/), and it is in
this repository — `TOOLS/FASM`, free to use and to pass on. There is no linker
step at all: FASM writes the finished file.

```
cd LESSONS\L02
MAKE
```

That is three calls to one program, and nothing else:

```
FASM HELLO.ASM  HELLO.COM
FASM HELLO2.ASM HELLO2.EXE
FASM HEX.ASM    HEX.COM
```

**One line in the source decides which kind of file comes out.** In `HELLO.ASM`
it is

```asm
format binary as 'com'
```

and in `HELLO2.ASM` it is

```asm
format MZ
```

That is the whole fork in the road, and it is worth noticing that it lives in
the *source* — the program itself says what it is, rather than a flag on a
command line saying it for them.

## The eighteen bytes

```
BA 0C 01  B4 09  CD 21  B8 00 4C  CD 21  48 45 4C 4C 4F 24
```

That is the entire file. Read it against the source and every byte is
accounted for:

| bytes | | |
|---|---|---|
| `BA 0C 01` | `mov dx, msg` | the address `010C`, low byte first |
| `B4 09` | `mov ah, 9` | DOS function 9: print until `$` |
| `CD 21` | `int 21h` | ask DOS to do it |
| `B8 00 4C` | `mov ax, 4C00h` | function 4Ch: exit, code 0 |
| `CD 21` | `int 21h` | |
| `48 45 4C 4C 4F 24` | `msg db 'HELLO$'` | H E L L O `$` |

Change the five bytes at offset 12 and run it again:

```
HEX HELLO.COM 12 WORLD
HELLO
```

It prints `WORLD`. Nothing was recompiled. The source still says `HELLO`.

That works because **a COM file has no header at all**. DOS finds a free
segment, copies the file into it starting at offset `100h`, and jumps to the
first byte. That is the whole loader — and it is why the source begins with
`org 100h`, and why file offset 12 is memory address `010C`.

## Why the EXE is four times bigger

An EXE can be larger than one segment, so the loader has to be told where each
segment goes and then walk back through the program fixing every reference to
them. That list lives in a header, and here the header is 32 bytes of an
81-byte file — most of what the EXE costs is bookkeeping about where things
are.

`HEX HELLO2.EXE` shows all of it:

```
0000: 4D 5A 51 00 01 00 01 00 02 00 10 00 FF FF 04 00  MZ..............
0010: 00 01 00 00 00 00 02 00 1C 00 00 00 21 00 00 00  ............!...
0020: 48 45 4C 4C 4F 20 46 52 4F 4D 20 41 4E 20 45 58  HELLO FROM AN EX
0030: 45 24 00 00 00 00 00 00 00 00 00 00 00 00 00 00  E$..............
0040: B8 00 00 8E D8 BA 00 00 B4 09 CD 21 B8 00 4C CD  ...........!..L.
0050: 21                                               !
```

`4D 5A` is `MZ` — Mark Zbikowski, who wrote this loader, signing his format in
the first two bytes of every DOS executable there has ever been. Then:

| offset | | |
|---|---|---|
| `08` | `02 00` | the header is **2 paragraphs**, so the program starts at file offset `20h` |
| `0E`, `10` | `FF FF`, `00 01` | the stack: segment and `SP = 100h`, the `stack 100h` from the source |
| `06` | `01 00` | **one relocation** to fix up |
| `18` | `1C 00` | and its list starts at `1Ch`, which is the `00 00 02 00` right after |

That single relocation is the whole point of the header. At `0040` the code
begins `B8 00 00` — `mov ax, 0`. Zero is not the answer; it is a **blank the
loader fills in**, and the relocation entry is what tells it which blank. DOS
adds the segment it actually loaded you at, and only then does `8E D8`
(`mov ds, ax`) point DS at the text.

The COM file needed none of this, and that is why it has no header: everything
it refers to is inside the one segment it was copied into.

You can see the same fact in the source. `HELLO2.ASM` has two instructions the
COM never needed:

```asm
start:  mov  ax, VARS
        mov  ds, ax
```

The text lives in a segment of its own now, and only the loader knows where it
put it, so DS has to be pointed at it before anything can be read. A COM file
cannot need this, because everything in it is inside one segment — which is
exactly why it can simply be copied into memory.

It also declares two things a COM has no way to say:

```asm
entry CODE:start        ; an EXE names its starting point
stack 100h              ; and gets a stack segment of its own
```

A COM starts at `100h` because there is nowhere else to start, and its stack
is whatever is left at the top of its one segment.

> One small thing you will meet at once: the data segment here is called
> `VARS`, not `DATA`, because `data` is a word FASM keeps for itself. Segment
> names are yours to choose — just not that one.

## The byte viewer is part of the lesson

A lesson about bytes needs something that shows them and lets you change them.
The recorded video uses Volkov Commander, which is fine on your own machine and
could not come with you: it is shareware — free to use, not free to hand out —
and the [browser edition](https://kirindenis.github.io/wire-city-2/l02.html) is
meant for somebody who agreed to nothing and downloaded nothing.

So [HEX.ASM](HEX.ASM) is ours, written in the language this lesson is about and
built by the assembler this lesson uses:

```
HEX HELLO.COM              show every byte
HEX HELLO.COM 12 WORLD     write WORLD at offset 12
```

It is a hundred and fifty lines and worth reading after the other two, because
it is the first program here that does something real: it takes a command tail
apart, opens a file for reading *and* writing, seeks, and prints a number in
hex. It also carries the trap this whole repository has a file to deal with —

```asm
        jnc  .named        ; NOT `jc usage`
        jmp  usage
.named:
```

An 8086 conditional jump reaches 127 bytes and `usage` is further away. FASM
has no `.8086` directive, so it would have taken the 386 long form without a
word, and the program would have run perfectly in every emulator and died on
the machine it is written for. Jumping over an unconditional jump is what
[`ENGINE/E_8086.INC`](../../ENGINE/E_8086.INC) does automatically for the
games; here it is done by hand, once, where you can see it.

## Tools

DOSBox and `TOOLS/FASM` from this repository. Nothing else, and nothing to buy
— which is the reason the whole repository moved off Turbo Assembler.

---

Made by [Owlos](https://owlos.sk). We modernise legacy software for the people
who still depend on it, and knowing how it was written the first time is the
whole reason we can.
