# Lesson 2 — The File Is The Program

Two sources, both typed in the video: [HELLO.ASM](HELLO.ASM) becomes an
eighteen-byte `.COM`, [HELLO2.ASM](HELLO2.ASM) becomes a five-hundred-odd-byte
`.EXE`, and they print almost the same thing. The difference between them is
the lesson.

## Building them

```
TASM /T /L HELLO.ASM
TLINK /t HELLO.OBJ
```

`/L` writes `HELLO.LST`, and that listing is the best thing in the toolchain
for seeing what an assembler actually does — address, machine bytes and your
own source line, side by side:

```
0100  BA 010Cr    start:  mov  dx, offset msg
0103  B4 09               mov  ah, 9
0105  CD 21               int  21h
0107  B8 4C00             mov  ax, 4C00h
010A  CD 21               int  21h
010C  48 45 4C 4C 4F 24   msg  db 'HELLO$'
```

`TLINK /t` makes a COM. Drop the `/t` and you get an EXE — that one letter is
the whole fork in the road.

## The eighteen bytes

```
BA 0C 01  B4 09  CD 21  B8 00 4C  CD 21  48 45 4C 4C 4F 24
```

That is the entire file, and every byte of it is in the listing above. Open it
in any hex editor, change the five bytes at offset 12 to `57 4F 52 4C 44`, and
run it again — it prints `WORLD`. Nothing was recompiled. The source still
says `HELLO`.

That works because **a COM file has no header at all**. DOS finds a free
segment, copies the file into it starting at offset `100h`, and jumps to the
first byte. That is the whole loader — and it is why the source begins with
`org 100h`, and why file offset 12 is memory address `010C`.

## Why the EXE is thirty times bigger

An EXE can be larger than one segment, so the loader has to be told where each
segment goes and then walk back through the program fixing every reference to
them. That list lives in the header, and the header is nearly all of those
five hundred bytes.

You can see the same fact in the source. `HELLO2.ASM` has two instructions
that the COM never needed:

```asm
start:  mov  ax, @data
        mov  ds, ax
```

The data is in a segment of its own now, and only the loader knows where it
put it. A COM file cannot need this, because everything in it is inside one
segment — which is exactly why it can simply be copied into memory.

## Tools

DOSBox, Turbo Assembler 3.2 with TLINK, and any hex editor. In the video it is
Volkov Commander, because this machine has no `DEBUG.EXE` and VC is the one
tool in DOS that both shows the bytes and lets you change them.

---

Made by [Owlos](https://owlos.sk). We modernise legacy software for the people
who still depend on it, and knowing how it was written the first time is the
whole reason we can.
