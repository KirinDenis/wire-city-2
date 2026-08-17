# The workbench — the brief

Somebody who has never seen DOS opens a page on our site, presses one button,
and is inside a machine where they can learn assembly from nothing. Everything
they need is already on that machine: a catalogue of what there is, an editor,
the assembler, a reference, a way to look at bytes.

That is the whole goal. This file is the brief for it.

---

## What was measured before writing this

Three things were found by opening the files, and each one changes the plan.
They are stated first because the rest of the document follows from them.

### 1. The student's editor already exists, and it is already shipped

`TOOLS/FASM/FASMD.EXE` — 136,087 bytes — is flat assembler's own DOS IDE, and
**it is already inside every lesson bundle.** It has, today, without us writing
a line:

| | |
|---|---|
| syntax highlighting | by the assembler's own tokeniser, so it cannot disagree with it |
| `F9` / `Ctrl+F9` | compile and run / compile only |
| `Ctrl+F8` | compile **and dump the symbol table** |
| `F7` `Ctrl+F7` `F5` | find, replace, go to position |
| `Ctrl+Z` / `Ctrl+Shift+Z` | undo and redo |
| blocks | including **column blocks**, `Alt+Ins` |
| many files at once | `Ctrl+Tab`, `Alt+1..9` |
| `Ctrl+B`, `Ctrl+F6` | ASCII table, calculator |
| an INI | colours, and an `[Environment]` section that sets variables for the assembler alone |

That is more than the C prototype in `TOOLS/ED/`, and its source ships with it
(`TOOLS/FASM/SOURCE/IDE/` — EDIT, BLOCKS, UNDO, SEARCH, NAVIGATE).

**So the environment does not have to wait for us to write an editor.** What ED
is still for is in `TOOLS/ED/BRIEF.md`, and it is a narrower thing than it was.

### 2. Eleven bundles carry eleven copies of the assembler

| bundle | size |
|---|---|
| `l02_v3.jsdos` | 164,255 |
| `l03_v3.jsdos` | 164,308 |
| `l05_v2.jsdos` | 169,475 |

Nearly all of that is FASM (108,923) + FASMD (136,087) + CWSDPMI (21,325). The
lesson itself — `TURN.ASM`, `SINT.INC`, `MKSIN.C` and four batch files — is
about 27 KB before compression.

A person taking the course downloads the assembler again for every lesson.
Six lessons is about 985 KB of which roughly 930 KB is the same three files
six times. **One disk carrying all six would be near 210 KB** — less than two
of today's bundles, for the whole course. Add the games and their data and it
is still under half.

These are estimates from the file sizes above, not a measured build. The
direction is not in doubt; the exact number should be checked once the disk is
assembled.

### 3. FASM cannot disassemble — and something better is already in the box

The word "disassemble" does not occur once in FASM's 278 KB of documentation.
It is a one-way assembler and always was.

But `TOOLS/FASM/TOOLS/` holds three tools that read the symbol dump FASM can
produce, and one of them is the thing actually wanted:

    fasm    TURN.ASM TURN.COM -s TURN.FAS
    listing TURN.FAS TURN.LST

`TURN.LST` is every source line with the address it landed at and the bytes it
became. For a student that is **a better answer than a disassembler**, because
it answers the question they have — *what did my line turn into* — rather than
the question they do not have yet, *what are these bytes*.

`LISTING.ASM` is 3,842 bytes of FASM source in `TOOLS/FASM/TOOLS/DOS/`. We
assemble it with the assembler we already ship. `SYMBOLS.ASM` next to it dumps
the symbol table, which is what `Ctrl+F8` in FASMD produces.

Two cautions, both from that directory's own README: the listing must be
generated **immediately after** the build, from the same directory, with
nothing moved or edited in between, or it prints garbage; and `-a` should be
passed for executable formats to get run-time addresses.

A real disassembler is still worth having later, for one specific reason of
our own — see *Bytes* below.

---

## The shape: one disk

Stop shipping a machine per lesson. Ship **one machine** whose disk is the
course.

    C:\
      MENU.COM          the catalogue - what autoexec runs
      WORK\             the student's own files. Nothing else writes here.
      TOOLS\            FASM.EXE  FASMD.EXE  CWSDPMI.EXE  LISTING.EXE  HEX.COM
      LESSONS\L01..L06\ one idea built from nothing
      EXAMPLES\         the same idea, standalone and running
      GAMES\            the same idea in production, at scale
      HELP\             one file per instruction

The three directories are not a filing decision. **They are the curriculum**,
and the repository has been arranged that way for months without ever saying
so out loud. `DIR` at the root now teaches the course's own structure, which
is exactly the kind of thing that should be visible rather than explained.

`WORK\` matters more than it looks. A beginner will break something. Their own
files must not be where the originals are, so that "start again" is always
available and never destroys anything. The lesson scripts already clear `WORK`
between takes.

---

## The catalogue

`MENU.COM` is what `autoexec` runs instead of leaving a prompt. It lists the
three tiers, and inside each, the entries. Choosing one offers exactly three
things — **open it, build it, run it** — and nothing else.

**Every choice prints the command it is about to run, then runs it.** This is
already the rule in the bundles' `MAKE.BAT`, and it is the whole pedagogy of
the menu: the menu is training wheels that show you the pedals. By lesson
three a student types `MAKE` instead of arrowing to it, and that is a success,
not a bypass.

`ESC` at the menu leaves a plain `C:\>` prompt with a one-line reminder of how
to get back. Never trap anyone inside the menu.

### One manifest per entry, and only one

Each lesson, example and game carries a small file describing itself:

    .title    Sixty-five numbers, and what they are for
    .what     A sine table, and a dozen instructions that unfold it
    .tier     LESSON
    .main     TURN.ASM
    .build    FASM TURN.ASM TURN.COM
    .run      TURN.COM
    .needs    SINT.INC
    .reads    MKSIN.C
    .uses     AND SHR NEG MUL SHL SAR IMUL LOOP
    .engine   ENGINE\E_MATH.INC
    .video    https://youtu.be/...

`MENU.COM` reads these to build its list. **So does the course page on the
web.** One description, two readers — a lesson list that can disagree with the
disk is worse than no lesson list, and there is no way to keep two hand-written
lists in step.

`.uses` is what threads the monolith together: the reference knows which
lessons use an instruction because the lessons say so, and nobody maintains a
cross-reference by hand.

Do not guess these fields from file names. `EXAMPLES/RING.ASM` is **not** a
circle — it is a sound ring buffer, the DMA loop that mixes an engine note
with guns and explosions through one Sound Blaster channel. It went into an
earlier draft of this brief as "the same thing as lesson 5's ring" on the
strength of its name alone, and that was wrong. Open the file.

---

## The editor: a decision, with the costs attached

There are two editors and two different users, and conflating them is what
made the earlier brief bigger than it needed to be.

**The student is a person looking at a screen.** Dialogs help them. FASMD is
already better than anything we would write this year, costs nothing, and is
already in the bundle.

**The rig is a machine that cannot see the screen.** It sends keystrokes down
a wire and trusts the editor to be where it left it. Dialogs are invisible
state, and five takes of one lesson died on exactly that. FASMD has a load
dialog. It can never be the rig's editor.

So:

| | student | rig |
|---|---|---|
| editor | **FASMD**, today | **ED**, to be written |
| dialogs | yes, they help | none, ever |
| extendable by us | only by forking its assembly source | it is ours |

They must agree on one thing: **the bytes on disk.** CRLF, no trailing spaces,
same file. A lesson recorded with ED and then opened by a student in FASMD
must be the same file, or the video and the disk diverge.

Note FASMD's *Optimal fill on saving* option, which packs blanks into tabs to
make the file smaller. **Turn it off in the shipped INI.** A lesson's source is
compared byte for byte against the repository, and tabs where the video showed
spaces would fail that comparison for no reason.

**Recommendation: do not block the environment on ED.** Ship the disk with
FASMD. Build ED for the rig, on its own schedule. If ED grows up it can
replace FASMD for students too, and if it does not, nothing was lost.

---

## The reference, and why it cannot live in the editor

One file per instruction, and **the file name is the instruction**: `SAR.TXT`,
`IMUL.TXT`, `LOOP.TXT`. No index, no database, no search — take the word under
the cursor, uppercase it, open `HELP\<word>.TXT`. DOS 8.3 names and 8086
mnemonics fit each other exactly; the longest is six characters.

    .name   SAR
    .what   Shift right ARITHMETIC. The top bit is copied into itself
            instead of a zero coming in, so the sign survives.
    .flags  CF gets the last bit shifted out. OF cleared.
    .eats   the destination. Count is 1 or CL - the 8086 has no immediate.
    .cost   2 clocks, +1 a bit
    .form   SAR r/m, 1
    .form   SAR r/m, CL
    .trap   SHR is not the same instruction. -8 SAR 1 is -4; -8 SHR 1 is
            +124. Half our sines are negative.
    .trap   SAR rounds DOWN, towards minus infinity, not towards zero.
    .see    SHR SHL IMUL
    .used   LESSONS/L05/TURN.ASM  ENGINE/E_MATH.INC

**Nine of these are already written**, inside `LESSONS/L05/TURN.ASM` as comment
boxes — AND, SHR, NEG, MUL, SHL, SAR, IMUL, LOOP and Px's MUL. Lift them out;
do not write them again. The editor shows the file and the lesson pastes it in
as a comment, so a reference that contradicts a lesson becomes impossible
rather than merely unlikely.

**It has to be a TSR — a resident popup on a hotkey.** Since we are not writing
the student's editor, a reference built into an editor would only work in an
editor we do not ship. Resident, it works inside FASMD, inside the assembler's
error output, at the `C:\>` prompt, and inside a running game.

That is also what makes it possible at all: **the popup reads the word under
the cursor straight out of video memory at `B800`.** It does not need to
understand the editor, or parse the file, or be told anything. It reads the
screen, the same as the person looking at it.

`.form` is what a beginner needs most and no tool gives them. There is no
`SAR BX, 6` on an 8086 — the count is `1` or `CL` and nothing else — and FASM
will not say so. It will quietly assemble the 186 instruction, the build will
succeed, and the program will not run on the machine the course is about.

### What the popup can check, and where to stop

Reading the screen bounds this precisely, and the boundary is worth stating
because it is easy to walk past:

1. **Show the forms** for the instruction under the cursor. Pure display, no
   analysis. Nearly free, and most of the value is here.
2. **Count the operands** on that line — commas outside quotes. Catches
   `MUL AX, BX` and a bare `SAR AX`. Twenty lines of code.
3. **Classify each operand** — register, memory, immediate — against `.form`.
   This catches `SHR BX, 6`, which is the one that matters. A register table
   and a rough classifier: real work, but bounded.
4. **Sizes, segment overrides, the whole type system.** *Do not.* That is the
   assembler's job, `Ctrl+F9` is exact, and it is two keystrokes away. A tool
   that is almost right about types is worse than one that says nothing,
   because people start arguing with it.

**Checking that a label exists is not on that list, and cannot be.** It needs
the whole file, and the screen only holds 25 lines of it. It is possible only
in an editor we own — so it belongs to ED, and it is one of the few real
arguments for ED ever serving students. If it is built there, two things
decide whether it is usable:

- **FASM's local labels.** A label starting with a dot belongs to the last
  global label above it, so `.done` may appear in five routines, all five legal
  and different. `TURN.ASM` has `.out:` at line 147 inside `Px` and again at
  217 inside `PxS`. A checker that does not understand scoping cries
  "duplicate" on every one of them, and the first thing anyone does with a tool
  that cries wolf is switch it off.
- **When to rescan.** Not per keystroke. Five hundred lines is twenty kilobytes
  to walk, and on a 4.77 MHz machine that is felt. Rescan when the cursor
  leaves a line — that is when a definition can have changed, and it is
  invisible to the typist.

Highlighting needs no work at all: FASMD already colours by the assembler's own
tokeniser.

---

## Bytes

`LESSONS/L02/HEX.COM` — 832 bytes — is a byte viewer and patcher, and it was
**written by the student in lesson 2.** Put it in `TOOLS\` and offer it from
the menu. Do not write another one. A course whose own tools are its own
lesson output is making an argument that no amount of prose would make as well.

The same argument decides the disassembler. FASM has none, DOSBox's shell
provides no `DEBUG`, and nothing in our bundles ships one — so a disassembler
would have to be brought in or written. **Written, as a lesson**, it is the
natural sequel to `HEX.COM`: the hex viewer shows the bytes, the disassembler
says what they are, and by then the student has met most of the encoding.

It would also pay a debt this project already has. `TOOLS/ED/BRIEF.md` warns
that FASM silently emits `0F 80..8F` — a long conditional jump, which an 8086
does not have — whenever a conditional jump has to reach further than 127
bytes, and that this has happened in five lessons. That check runs on Windows
today. A disassembler on the DOS side would let the machine the course is about
check its own output.

Until then, `LISTING.EXE` covers the teaching case, and it costs one build.

---

## The INI

One file beside the tools. Paths and nothing clever:

    [tools]
    fasm    = C:\TOOLS\FASM.EXE
    fasmd   = C:\TOOLS\FASMD.EXE
    dpmi    = C:\TOOLS\CWSDPMI.EXE
    listing = C:\TOOLS\LISTING.EXE
    hex     = C:\TOOLS\HEX.COM

    [paths]
    lessons  = C:\LESSONS
    examples = C:\EXAMPLES
    games    = C:\GAMES
    engine   = C:\ENGINE
    help     = C:\HELP
    work     = C:\WORK

Inside the bundle these values never change. In the repository they are all
different, and on a contributor's machine different again. **Nobody's disk
looks like anyone else's**, which is the rule this repository already lives
by: machine paths go in a file that is not committed.

FASMD keeps its own INI, named after the executable. Ship one, with *optimal
fill* off, and the colours settled — a student should not have to configure an
editor before writing their first line.

---

## What ships first

Each step is worth having on its own. None of them waits on ED.

1. **One disk, one bundle.** LESSONS + EXAMPLES + GAMES + TOOLS, `autoexec`
   into a prompt with a `MENU` hint. This alone makes the course a course
   instead of eleven downloads, and makes it smaller.
2. **`MENU.COM` and the manifests.** The catalogue, and the same manifests
   feeding the web page.
3. **`LISTING.EXE`.** One build of a file already in the tree. Add `LIST` next
   to `MAKE` and `RUN`.
4. **`HELP\` and the TSR.** Nine entries lifted from `TURN.ASM` first, the
   popup reading `B800` second, `.form` checking third.
5. **`HEX.COM` into `TOOLS\`.** Ten minutes, and it closes the loop on
   lesson 2.

Cross-cutting, and to be settled once rather than per step: the `.uses` and
`.engine` fields are the monolith the whole thing has been heading towards.
Lessons point at engine modules, engine modules are what the games are built
from, the reference points back at the lessons that use each instruction — and
none of it is a hand-maintained list.

---

## The rules that do not change

**CRLF, always.** A lone LF shows a whole program as one endless line in every
DOS editor there is.

**The bundle ships source and the assembler, never the built program.** Already
the rule, and `RUN.BAT` says so out loud when there is nothing to run. The
student builds it, and the first thing they own is a binary they made.

**The commands are identical on every machine.** The bundle's `MAKE.BAT` says
it best: whichever machine you type `MAKE` on, the same assembler produces the
same 771 bytes. The menu must not invent verbs that only exist inside it.

**Never hide DOS.** The audience does not know `DIR`, and the answer is to
show them, not to build a shell that means they never need to. Everything the
menu does, it prints first.

**No commercial software on the disk.** TASM, TLINK, Turbo Debugger, BP7 and
Volkov may be used locally and are never committed and never shipped. FASM,
CWSDPMI and everything in `TOOLS\` are redistributable — check the licence
before adding a twelfth thing.

**Scan for 386 instructions before believing a build.** `0F 80..8F` is a long
conditional jump and an 8086 has none. FASM emits them silently. It has caught
five lessons.
