# Lesson 2 — The File Is The Program

Two sources: [HELLO.ASM](HELLO.ASM) becomes an eighteen-byte `.COM`,
[HELLO2.ASM](HELLO2.ASM) becomes an eighty-one-byte `.EXE`, and they print
almost the same thing. The difference between them is the lesson.

## Building them

The assembler is [flat assembler](https://flatassembler.net/), and it is in
this repository — `TOOLS/FASM`, free to use and to pass on. There is no linker
step at all: FASM writes the finished file.

```
FASM HELLO.ASM  HELLO.COM
FASM HELLO2.ASM HELLO2.EXE
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

Open it in any hex editor, change the five bytes at offset 12 to
`57 4F 52 4C 44`, and run it again — it prints `WORLD`. Nothing was
recompiled. The source still says `HELLO`.

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

## Tools

DOSBox, `TOOLS/FASM` from this repository, and any hex editor. In the video it
is Volkov Commander, because this machine has no `DEBUG.EXE` and VC is the one
tool in DOS that both shows the bytes and lets you change them.

---

Made by [Owlos](https://owlos.sk). We modernise legacy software for the people
who still depend on it, and knowing how it was written the first time is the
whole reason we can.
