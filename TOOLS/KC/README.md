# KC - Kirin Commander for DOS

The DOS commander of the course page and the site: two panels in the line
of Norton Commander, Volkov Commander and Far Manager. F1 shows its keys;
F9 its menu.

**It is its own project.** Kirin Commander lives in its own repository and
is built there - one program for DOS, a desktop and a browser, on
[OWLOSUI](https://github.com/KirinDenis/OWLOSUI). This folder holds the
built DOS commander as `docs\pull-kc.ps1` copied it; `VERSION.TXT` says
from which commit. Do not edit these files here: change the commander,
build it, and pull again.

- `KC.COM` - the loader: it puts `KC.BIN` in extended memory under DPMI
  (CWSDPMI must be loaded first) and jumps into it.
- `KC.BIN` - the commander, a flat 32-bit binary built from Rust.

## How the course uses it

`docs\pack-course.ps1` puts this folder on the course disk as
`A:\TOOLS\KC`. The page's DOS PC starts into it through `C:\COMMANDR.BAT` -
the course disk `A:\` on the left, `C:\` on the right - with `/STEP`: to
run a program the commander writes its lines into `C:\RUNPROG.BAT` and
where it was into `C:\KC.SAV`, and leaves memory; the batch file runs the
program and starts the commander again, in the same folders, with the same
history. A program has all of DOS's memory, as from the prompt - OWL FLY
III needs it.

```text
:again
C:\OWLOS\CWSDPMI.EXE
A:\TOOLS\KC\KC.COM /STEP A:\ C:\
if not exist C:\RUNPROG.BAT goto done
call C:\RUNPROG.BAT
del C:\RUNPROG.BAT
goto again
:done
```

Its setup (Shift+F9), its user menu (`KC.MNU`), its extension table
(`KC.EXT`) and its language files (`KC*.LNG`) live beside `KC.COM`.

`TOOLS\COMMANDR`, the Pascal commander the course started with, is still
in the repository and on the disk; the DOS PC no longer starts into it.
