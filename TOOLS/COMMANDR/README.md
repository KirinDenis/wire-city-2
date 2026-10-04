# COMMANDR - the DOS commander of the course page

A two-panel file manager for DOS, in Pascal, with Volkov Commander's keys:
Tab the other side, Enter into a folder or runs a program, F3 View, F4 Edit,
F5 Copy, F6 Move, F7 MkDir, F8 Del, Alt+F1/Alt+F2 a drive, Ctrl+R reads
again, F10 quits.

**It is ours: a copy of an example from OWLOSUI.** OWLOSUI
([github.com/KirinDenis/OWLOSUI](https://github.com/KirinDenis/OWLOSUI), MIT)
keeps it in `Examples/DOS/Commandr` - an example of its toolkit for DOS, not
part of the library. It was copied here on 2026-10-04 from OWLOSUI commit
`8e9bb2c`, as it is: `COMMANDR.EXE` and its source, `COMMANDR.PAS`. OWLOSUI
is never changed for the course; a newer commander is copied again.

## How the course uses it

The course page (`docs/course/`) puts it on its DOS PC's disk A: with the
rest of the course (`docs/pack-course.ps1`), as `A:\TOOLS\COMMANDR`. The
DOS PC starts into it - left side `A:\`, the course; right side `C:\`, the
games' players and the toolkit - and comes back to it when a lesson's
program ends. Enter on a program in it runs that program.

It draws with **OWLOSRES**, the OWLOSUI toolkit resident for DOS - the same
Rust core as the page's windows, behind INT 60h. That IS library: the page's
DOS PC (OWLOSUI's `DosTool`) puts it on `C:\OWLOS` and `C:\OWL.BAT` runs a
program with it behind. The page's own `C:\COMMANDR.BAT` starts the commander
that way, with `/STEP`: to run a program the commander steps out of memory
(the program's lines in `RUNPROG.BAT`) and is started again after it, so a
program has all of DOS's memory, as from the prompt.

## Building it

With Borland Pascal 7's command-line compiler, for real mode, against the
toolkit's Pascal unit (`lib/dos/pascal/OWLOSUI.PAS` in OWLOSUI) - see
OWLOSUI's `Examples/DOS/Commandr/MAKE.BAT`. Borland Pascal is commercial and
is in neither repository, so the course carries the built `COMMANDR.EXE`,
and `COMMANDR.PAS` to read.
