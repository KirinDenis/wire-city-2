# ED — the brief

Build a text editor for DOS, in 8086 assembly, that a machine can drive
blind. It is the editor the lessons are **recorded** in.

**It is not the editor the students use.** That is `FASMD.EXE`, flat
assembler's own DOS IDE — it already ships inside every lesson bundle, it
already does more than the C prototype here, and it costs nothing. See
[`../WORKBENCH.md`](../WORKBENCH.md), which is the brief for the environment
as a whole; this file is one part of it.

That division is the whole point:

| | student | rig |
|---|---|---|
| looks at the screen | yes | **no** |
| dialogs | help them | are invisible state, and kill takes |
| editor | FASMD, today | ED, this brief |

The two must agree on exactly one thing — **the bytes on disk**. A lesson
typed by the rig and then opened by a student must be the same file.

This file is the whole brief for ED. A session that starts from it needs
nothing else to begin.

---

## Why it exists

**Five takes of one lesson were lost to somebody else's editor.** The lessons
are typed by a rig that cannot see the screen — it sends keystrokes down a
serial line and trusts the editor to be where it left it. Volkov Commander is
a good editor for a person and an impossible one for a machine, because its
state is invisible:

| what happened | what it cost |
|---|---|
| `F4` opens whatever the panel cursor is on; with panels hidden, nothing | a take of lesson 3 |
| one Enter to re-open, two to create — and the file was not there | a take of 5B |
| `PGDN 10` reaches the end only of a file shorter than ten screens | frame 4 typed in ahead of frame 1 |
| `END` + `BACKSPACE` on an empty dialog field cancels the dialog | two takes of 5B |
| `CTRL-O` hides the panels, and `SHIFT-F4` then does nothing | the last take of 5B |

The last one is the argument in miniature: the take log shows two file-opens
with **byte-identical keystrokes**, one working and one not. The difference
was a toggle whose position nothing could observe.

**And the audience needs it too.** The course teaches DOS assembly to people
who have never seen DOS. `DIR` alone stops them. They need a way in that does
not hide DOS — it shows the commands it runs — but does not drop them at a
bare `C:\>` either.

---

## What already exists

- **`TOOLS/ED/ED.C`** — a working prototype in Open Watcom C, 29,662 bytes.
  Frame, title bar with the file name, menu strip, F-key bar, all the editing
  keys, F9 build, F10 run, and the assembler's error line taking the cursor
  to it. **Use it as the behaviour reference, then supersede it.** Its two
  faults are why it is only a prototype: 29 KB, and `system()` keeps it
  resident while FASM runs.
- **`LESSONS/L02/HEX.COM`** — 832 bytes, a byte viewer and patcher written in
  lesson 2. The catalogue should offer it; do not write another.
- **`ENGINE/E_*.INC`** — the shared engine, already split: `E_8086` (integer
  arithmetic), `E_MATH` (the sine table), `E_RAST` (pixels and spans),
  `E_M3D`, `E_TERR`, `E_SND`.
- **The instruction boxes in `LESSONS/L05/TURN.ASM`** — nine of them so far
  (AND, SHR, NEG, MUL, Px's MUL, SHL, SAR, IMUL, LOOP), each with what the
  instruction does, which flags it sets, what it destroys, its cost in
  clocks, and the instruction it is confused with. **This is TeachHelp's
  content, already written.** It is not part of this brief, but do not design
  the editor so that it cannot be added later.

---

## What to build

### 1. The editor

80×25 text, written straight to `B800`. An array of lines, one byte per
character, ANSI — none of what makes a modern editor hard is present here.

Turbo Vision by eye: a double-line frame, **the file name in the top bar**, a
menu strip along the top, the function keys along the bottom, line and column
in the corner.

### 2. FASM, wired in

- **F9 assembles** and prints the real command line on the screen before it
  runs — `FASM TURN.ASM TURN.COM`, not a progress bar. The viewer is meant to
  learn that the key is a shortcut for something they could type.
- **The error takes the cursor to the line.** FASM says `FILE.ASM [123]:`;
  parse it and go there. This single behaviour is worth more to a beginner
  than any other feature in the editor.
- **F10 runs** what was built.

### 3. The configuration

An INI beside the executable — where the assembler is, and where it is safe
to write. Nothing else:

    [tools]
    fasm = C:\TOOLS\FASM.EXE
    dpmi = C:\TOOLS\CWSDPMI.EXE

    [paths]
    work = C:\WORK

Nobody's disk looks like anyone else's, and the browser bundle's disk looks
like neither. The rule this repository already lives by: machine paths go in
a file that is not committed.

The full disk layout — the three tiers, the catalogue, the reference — is
`WORKBENCH.md`'s, not ED's. ED opens the file it was handed.

### 4. What moved out, and the one thing that stayed

The catalogue, the per-instruction reference and the operand hints are now in
[`../WORKBENCH.md`](../WORKBENCH.md). They serve a person choosing what to
learn, and they turned out to belong to a **resident popup** rather than to an
editor — because the student's editor is FASMD, so anything built into an
editor of ours would only work where the student is not.

The popup reads the word under the cursor straight out of video memory at
`B800`, which is why it needs no editor's cooperation at all. It will work
inside ED too, for free.

One piece could not move, because it is the only thing on that list that
**needs the whole file** and the screen holds only 25 lines of it:

### 5. Labels and names, on the fly

Scan the buffer for what it defines — `name:` at the left margin, and
`name dw`/`db`/`equ` — and keep the set. Then a name used and never defined
gets marked, a name defined twice gets marked, and the same set gives
completion for free.

This is the one feature that could earn ED a place in front of students, and
two things decide whether it is usable.

**FASM's local labels.** A label starting with a dot belongs to the last
global label above it, so `.done` may appear in five routines and all five
are legal and different. Our own `TURN.ASM` has `.out:` at line 147 inside
`Px` and again at 217 inside `PxS`, and `.back`, `.have`, `.done` inside
`SINQ`. A checker that does not understand scoping will cry "duplicate" on
every one of them, and the first thing anybody does with a tool that cries
wolf is switch it off.

**When to rescan.** Not on every keystroke. Five hundred lines is twenty
kilobytes to walk, and on a 4.77 MHz machine that is felt. Rescan when the
cursor leaves a line — that is when a definition can have changed, and it is
invisible to the typist.

**Mark it, never refuse it.** A name can be defined in an include ED has not
read, and a half-typed line is not an error. The exact check is the
assembler's, and it is one keystroke away.

<details>
<summary>Superseded: the catalogue as ED was going to carry it</summary>

Kept only because the lesson-to-engine links below were verified by reading
the module headers, and `WORKBENCH.md` should inherit them rather than have
somebody derive them a second time.

A list of what there is to open, built from those paths, in three tiers —
because the repository is **already** arranged in three tiers and nothing has
ever said so out loud:

    LESSONS/    builds one idea from nothing
    EXAMPLES/   the same idea, standalone and running
    GAMES/      the same idea in production, at scale

The engine modules are the seam, and they say so themselves: *"the game's own
code, split out so that small standalone examples can share them. Each module
states its CONTRACT."* So the links are already true, and only need writing
down:

| lesson | engine module | example |
|---|---|---|
| 3 — the screen, one byte at a time | `E_RAST` — PUTPIXEL, LINE, the scanline filler | |
| 4 — arithmetic without MUL or DIV | `E_8086` — and it exists to keep FASM inside the 8086 set | |
| 5 — the sine table | `E_MATH` — integer maths primitives | `RING.ASM` includes it |
| 6 — a line at any angle | `E_RAST` — Cohen–Sutherland clipping, the stroker | |

Do not guess these from file names. `EXAMPLES/RING.ASM` is **not** a circle —
it is a sound ring buffer, the DMA loop that mixes an engine note with guns
and explosions through one Sound Blaster channel. It was written into this
brief as "the same thing as lesson 5's ring" on the strength of its name
alone, and that was wrong. Open the file.

For each entry: open it, build it, run it. That is all.
</details>

---

<details>
<summary>Superseded: the reference, as an editor feature</summary>

### The reference, and what the editor does with it

**One file per instruction, and the file name IS the instruction.** `SAR.TXT`,
`IMUL.TXT`, `LOOP.TXT`. No index, no database, no search: the editor takes
the word under the cursor, uppercases it, and opens `HELP\<word>.TXT`. DOS
8.3 names and 8086 mnemonics fit each other exactly — the longest are six
characters — so the lookup is `open` and nothing else.

Each file is marked up plainly, because it is read by two things: the editor
shows it, and a lesson pastes it into the source as a comment box.

    .name   SAR
    .what   Shift right ARITHMETIC. The top bit is copied into itself
            instead of a zero coming in, so the sign survives.
    .flags  CF gets the last bit shifted out. OF cleared.
    .eats   the destination. Count is 1 or CL - the 8086 has no immediate.
    .cost   2 clocks, +1 a bit
    .trap   SHR is not the same instruction. -8 SAR 1 is -4; -8 SHR 1 is
            +124. Half our sines are negative.
    .trap   SAR rounds DOWN, towards minus infinity, not towards zero.
    .see    SHR SHL IMUL
    .used   LESSONS/L05/TURN.ASM  ENGINE/E_MATH.INC

**Nine of these are already written**, inside `LESSONS/L05/TURN.ASM` as
comment boxes. Lift them out; do not write them again.

The point of one source for both is that they cannot drift. A reference that
says something the lesson does not is worse than no reference, because
somebody will believe it instead of the processor.

**Highlighting** falls out of the same files for free: the set of file names
in `HELP\` *is* the set of known mnemonics. Anything in that set is an
instruction and can be coloured; anything else is a label, a number or a
comment. No parser, no table to maintain, and it stays correct as the
reference grows.

The operand forms (`.form`) and the four-step limit on how far to check them
are in `WORKBENCH.md` now, with the popup that shows them.
</details>

---

## The constraints that are not obvious

These are not preferences. Each was paid for.

**No dialogs. None.** Not on save, not on quit, not on "the file has
changed", not on "overwrite?". A dialog is a state the rig cannot see, and
every lost take above is one. The file comes from the command line:
`ED TURN.ASM`.

**`HOME` goes to column zero**, not to the first non-blank. Volkov's goes to
the first non-blank, which is why every lesson script says `END` then `ENTER`
instead: landing in front of a line and typing drags that line along at the
end of everything typed.

**A command to find the insertion point, not count to it.** "Go to the line
that starts with `Bye:`." Today the scripts navigate by pages and counted
arrow presses, and that is what put frame 4 ahead of frame 1 the moment the
file grew past ten screens. An insertion point must not depend on how long
the file has become.

**CRLF on save, always.** A lone LF makes a DOS editor show the whole program
as one endless line.

**Small, and gone during the build.** The C prototype is 29 KB and stays in
memory while FASM runs — with CWSDPMI and FASM in the same 640 KB that is
luck, not headroom. Assembly should bring it to a few KB; better still, leave
as little as possible resident across the build.

**Deterministic.** The same keystrokes must produce the same file, every
time. That is what makes the next constraint possible.

---

## Done means this

`Director.exe --check <lesson>` already replays a lesson script into a file
and compares it with the program in this repository. Today it **models** what
Volkov would do, and that model was wrong four times.

With this editor the model goes away: drive the real editor with the real
script, take the file it produces, and assemble it. Byte for byte, or the
lesson is not ready.

**The editor is finished when a lesson can be recorded without a human
watching for a dialog.**

---

## Decisions still open

- **One program or a family?** A shell, an editor and a resident help are
  three things. The help has to be resident and separate — otherwise it only
  works inside our own editor, and the course spends half its time at the DOS
  prompt and inside FASM. The rig also needs to invoke the editor directly,
  `ED file`, with no shell around it.
- **How the catalogue describes an entry.** One small file per lesson, game
  and example — title, what it builds, what it needs — would also feed the
  course page on the web and the lesson list in the shell. That is the same
  question as the "one monolith" one, and it should be answered once.
- **TeachHelp.** A resident reference on a hotkey, with the content that is
  already written. Not in this brief, but do not make it impossible.

---

## Notes for whoever picks this up

Build with FASM, from the folder's own `MAKE.BAT`, and scan the binary for
386 instructions before believing it — `0F 80..8F` is a long conditional
jump, which an 8086 does not have, and FASM emits them silently when a
conditional jump has to reach further than 127 bytes. It has happened in five
lessons.

The `.claude/skills/lesson-factory` skill in the `lecture-rig` repository
holds the rest of the production rules, and `FACTORY.md` there holds the
plan this work belongs to.

Open Watcom and the C prototype stay where they are for now: the lessons have
to keep being recorded while this is written, and `ED.EXE` is what they will
be recorded with until this replaces it.
