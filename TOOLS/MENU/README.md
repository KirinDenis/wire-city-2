# MENU - the catalogue

`MENU.COM` is what the workbench disk's autoexec runs instead of leaving a
bare prompt. It scans the `.INF` manifest beside every lesson, example and
game - the same file `TOOLS/packwb.ps1` and the course page read - and lists
the three tiers plus `WORK`, the student's own directory.

Choosing an entry offers three things and nothing else: **open** (the main
file, in FASMD), **build** (the entry's `MAKE.BAT`), **run** (its
`RUN.BAT`). Every choice prints the command as the student would type it,
then runs it through COMMAND.COM in the entry's own directory. The menu is
training wheels that show you the pedals; a student who types `MAKE`
instead of arrowing to it is a success, not a bypass.

In `WORK` there is one extra key: **N** asks for a name, copies
`NEW.ASM` (the template in this folder) to `WORK\NAME.ASM` - create-new,
so an existing file is opened rather than wiped - and drops into the
editor. An entry with no `.build` in its manifest (lesson 1, the Watcom
one) honestly offers only *open*.

`ESC` from the top screen leaves a plain `C:\>` with a one-line reminder
of how to get back. Never trap anybody inside the menu.

## Build

    cd TOOLS\MENU
    MAKE

or `MAKEWIN` from Windows (`MAKEWIN CHECK` cross-checks against the
Windows FASM). 8086 only: `..\..\ENGINE\E_8086.INC` turns the conditional
jumps into reach-checked macros, because FASM otherwise emits a 386 long
jump silently.

## What ships where

`MENU.COM` goes to the disk **root** (it is furniture, like FASM itself -
the student builds the lessons, not the menu). `NEW.ASM` and `FASMD.INI`
(with *Optimal fill on saving* OFF - it retabs saved files and would break
the byte-for-byte match with the repository) go to the disk's `TOOLS\`.
All three are placed by `TOOLS/packwb.ps1`.

## Known faults, for part two

Caught by the pilot running MENU.COM from inside Volkov on a machine that
carries no course (2026-08-17). The garbage they exposed is real and
scripted around in episode one; it gets fixed on camera in episode two:

1. **An empty section still draws one entry.** `draw_entries` is a
   do-while - it paints row 0 before comparing against a count of zero -
   and the title it paints is whatever the uninitialised entry buffer
   holds (a COM's `rb` memory is not zeroed). Same root as the `.what`
   line reading garbage. Guard `curcnt=0` at the screen, not per loop.
2. **The section bar prints name and description glued together** -
   "LESSONSone idea, built from nothing". The top screen pads the name to
   16 columns; the section screen forgot to.
3. ENTER on a section showing (0) should not enter at all.

## The workbench palette

One look for both editors - `FASMD.INI` carries it for the student, ED
hard-codes the same numbers for the camera. Turbo Vision by eye: blue
desktop, and the rank of a thing is its brightness. **White is what
matters** (the code itself - FASMD's tokeniser cannot split mnemonics from
operands, so the code is one class and it is the important one). **Yellow
is second rank** (punctuation and numeric constants). **Green appears
exactly twice**, where Turbo Vision used it: string literals - rare in
assembly, so they flash - and the focused control of a dialog.
**Comments are quiet gray.**

| what | colour on blue (1) |
|---|---|
| code (Text) | white 15 |
| symbols, numbers | yellow 14 |
| strings | light green 10 |
| comments | light gray 7 |
| selection | blue 1 on gray 7 |
| frame, title | white 15 on blue 1 |
| menu/status bar, dialogs | black 0 on gray 7 |
| focused control | white 15 on green 2 |
| errors | white 15 on red 4 |

This program is the workbench series' on-camera piece: its source is the
one that gets retyped through ED by the director once the draft is
approved. See `Skill/DISKTASK.md`, "How the work is done".
