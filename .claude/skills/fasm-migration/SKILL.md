---
name: fasm-migration
description: Migrate a DOS assembly program in this repository from TASM to FASM, and lay out its folder so a stranger can build and run it with nothing but this repository. Use when moving any program under GAMES/, EXAMPLES/, LAB/, TOOLS/ or ENGINE/ off Turbo Assembler, when adding build/run batch files to a program folder, or when deciding where a batch file belongs.
---

# Migrating a program from TASM to FASM

The goal is not "it assembles". The goal is that someone who downloaded this
repository as a ZIP, mounted it in DOSBox and knows nothing about the project
can `cd` into a program's folder, type `MAKE`, and get a working binary —
without buying, installing or configuring anything.

WIRE CITY has been through this end to end. Follow the same road.

## The rules that are not negotiable

**Line endings are CRLF.** Every `.ASM`, `.INC`, `.BAT`, `.TXT`, `.CFG` in
this repository ends its lines with `0D 0A`. Most DOS editors show an LF file
as one endless line with `◙` in it. The Write tool emits LF, so **convert
after writing, every time**:

```bash
perl -pi -e 's/\r?\n/\r\n/' <files>
file -b <file>     # must say "with CRLF line terminators"
```

`grep -c $'\r'` is not a reliable check — use `file -b`. `.gitattributes`
pins these extensions so git does not undo it.

**Every path inside a program's batch files is relative to that folder.**
`..\..\TOOLS\FASM\FASM.EXE`, never `\TOOLS\FASM\FASM.EXE`. A drive-root path
only works if the repository happens to be mounted *as* a drive root; mount
the folder above it — an ordinary thing to do — and every tool path points at
nothing.

**Nothing may depend on a variable set earlier.** A file manager (Volkov, and
DOS shells generally) runs each command in its own environment, so anything
`GO.BAT` set is already gone by the time `MAKE` runs. Each `MAKE.BAT` loads
what it needs by itself.

**Only `GO.BAT` lives in the repository root.** Everything that serves one
program lives in that program's folder. A root full of per-game batch files
is exactly the mess this layout exists to avoid.

**Never write provenance you did not witness.** These games are new code in a
period idiom. No dates, no "the original", no archaeology. Describe what the
code does and what the constraints are.

## What a finished program folder looks like

```
GAMES/WIRECITY/
    CITY.ASM        the FASM source — hand-maintained once migration is done
    CITY.COM        the built binary, tracked
    MAKE.BAT        assemble, from inside DOS
    RUN.BAT         run it, from inside DOS
    MAKEWIN.BAT     assemble from Windows (drives MAKE.BAT through DOSBox)
    RUNWIN.BAT      run from Windows
    README.md       what it is, how to build it, what is interesting in it
    LICENSE
```

and the Turbo Assembler original, frozen, in `TASM/<PROGRAM>/`.

A folder holding a *collection* — `EXAMPLES/` — takes a name: `MAKE JET`,
`RUN JET`, and a bare `MAKE` for all of them.

**Write DOS batch, not Windows batch.** `MAKE.BAT` and `RUN.BAT` run under
COMMAND.COM, which has neither `CALL :label` nor `FOR` — both are cmd.exe
inventions and both fail silently or strangely. To run the same three lines
thirteen times, have the batch `CALL` *itself* with a name argument; one level
of that has worked since DOS 3.3. `MAKEWIN.BAT` and `RUNWIN.BAT` run under
cmd.exe and may use whatever they like.

Copy `GAMES/WIRECITY/MAKE.BAT`, `RUN.BAT`, `MAKEWIN.BAT` and `RUNWIN.BAT` as
the templates — or `EXAMPLES/` for the collection shape. Four things they get
right that are easy to get wrong:

1. `MAKE.BAT` loads a DPMI host before FASM (see below) and **deletes the
   output first**, so a failed build cannot leave yesterday's binary looking
   like today's.
2. `MAKE.BAT` checks that the output *file exists* rather than trusting
   `if errorlevel 1` — DOS's "Illegal command" does not set errorlevel, so
   the error check alone reports success on a build that never ran.
3. `MAKE.BAT` takes an optional `EXIT` argument that closes DOSBox. This is
   for `MAKEWIN.BAT`: a batch file started from a DOSBox `-c` line **swallows
   every `-c` line after it**, so the emulator has to close itself from
   inside or it hangs there forever. Typed by hand, `MAKE` leaves you at the
   prompt.
4. `MAKEWIN.BAT` does not reimplement the build. It starts DOSBox and runs
   the folder's own `MAKE.BAT EXIT`. There is one build, and it is the DOS
   one — the one a stranger will actually run.

## Why a DPMI host has to be loaded first

FASM is a 32-bit program; DOS is a 16-bit system; something has to own
protected mode on its behalf. That is what DPMI is — a *host* owns protected
mode and serves *clients*. It is unrelated to UMB/HMA/EMS/XMS, which all stay
in real mode. DOSBox provides no DPMI host, and DOSBox-X's does not satisfy
FASM either (four CPU configurations were tried; none worked). CWSDPMI, in
`TOOLS/CWSDPMI`, does.

```bat
..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
..\..\TOOLS\FASM\FASM.EXE SRC.ASM OUT.COM
```

With **no arguments** CWSDPMI stays resident for exactly one program and
unloads itself when that program exits. Use `-p` only when several tools run
in a row and you want it to persist.

## The translation

```bash
dotnet run --project TOOLS\Tasm2Fasm -c Release -- <file-or-dir>
```

It never touches the original: `CITY.ASM` becomes `CITYF.ASM`, `E_MATH.INC`
becomes `E_MATHF.INC` — still 8.3, and it recognises its own output so a
source that already ends in `F` (like `TKOFF.ASM`) is not skipped.

The rules it applies are in the header of `TOOLS/Tasm2Fasm/Program.cs`. The
part that needs a human is what it **refuses to guess**: FASM reserves the
register names of processors that did not exist when this idiom was current,
so a variable called `rcx` or `rdi` or `di` now collides. It reports these and
translates nothing.

**Before renaming a colliding symbol, find out whether it is alive.** In
WIRE CITY the variable `di` had never worked at all — the register name
shadowed it, so every `[di]` in the file assembles as `DS:[DI]`. TASM's `/L`
listing settles it in one line:

```
mov word ptr [di],-RAD   ->  C7 05 FFFB          register-indirect
mov word ptr [dj],-RAD   ->  C7 06 01A3 FFFB     absolute — a real variable
```

Record the judgement in `TOOLS/Tasm2Fasm/renames.txt` so the translation
stays reproducible:

```
*                          rcx=rc_x  rcz=rc_z
GAMES\WIRECITY\CITY.ASM    di@def=di_dead
EXAMPLES\SMOKE.ASM         rdi=rd_i
```

`old=new` renames every whole word; `old@def=new` renames only the column-0
label — which is what you want when the name is also a register, because then
every *other* occurrence in the file really is the register. `*` applies to
the whole repository, and that is not a convenience: `rcx` is **declared** in
five different programs and **used** only inside `ENGINE/E_M3D.INC`, which all
of them include. Rename it in the programs alone and the shared code stops
compiling; rename it in the shared code alone and so do the programs.

A dead slot is kept, not deleted: removing a variable moves every address
after it.

**The tool only warns about names it defines as reserved, and that list has
been wrong.** `spl` — a span length in `FLIGHT.ASM` — is the low byte of RSP
on x86-64, and nothing said a word until FASM refused the file. If FASM
rejects a symbol the tool passed, add it to `Reserved` in `Program.cs` as well
as fixing the file, or the next translation walks into it again.

## How you know the port is correct

**Not by a matching checksum.** TASM is one-pass, so `JUMPS` reserves room
for a near jump and pads the leftovers with NOPs it can no longer take back.
FASM makes three passes and needs none, so the FASM build is smaller — WIRE
CITY by 312 bytes, every one of them a NOP.

The standard is **complete accounting**: every byte of the difference
explained. Run it:

```bash
dotnet run --project TOOLS\BinAccount -c Release -- TASM\<PROG>\X.COM <folder>\X.COM
```

`BinAccount` decodes both binaries instruction by instruction and walks them
in step. It accepts NOP padding, a jump FASM encoded shorter, the two
assemblers' different-but-equal choices (direction bit, `imm16` vs
sign-extended `imm8`), operands that moved because the code ahead of them got
shorter, and stretches of data whose addresses moved — and nothing else.
Anything it cannot name, it prints in hex and stops. Read that spot in the
source before trusting either build.

Two things it will tell you that are worth understanding rather than working
around:

- **"data — N bytes on both sides"** means it crossed a table of addresses.
  A data run can excuse different *contents* and never a different *size*,
  because both cursors advance equally.
- **"instruction boundary re-found"** means it had been reading data as code
  and came out standing in the middle of an instruction. Harmless, and it
  says so, but if the count is large the program is more interleaved than you
  think.

If it reports **"LOST THE THREAD"**, the two walks stopped being on the same
instructions somewhere *earlier* than the message. Look backwards, not at the
offset printed.

It has already earned its keep twice: the 386 jumps described below, and a
one-byte error in the macro that fixed them.

Two further checks worth having:

- Run both binaries and compare behaviour. Accounting proves the assembler
  did what you asked; only running it proves you asked for the right thing.
- `MAKEWIN CHECK` assembles the same source with the Windows FASM into
  `CITYW.COM` and compares. The Windows assembler is much faster and leaning
  on it is only legitimate while it emits identical bytes. Keep the DOS build
  as the one that counts.

## `.8086` has no FASM equivalent — this is the trap

TASM's `.8086` restricts the instruction set. **FASM has no such directive at
all.** It assembles whatever encoding is shortest, and when a conditional
jump goes out of the 8086's ±127-byte range it silently reaches for the 386
long form, `0F 8x`.

So dropping `.8086` in translation — which is the obvious thing to do, since
FASM does not accept it — quietly puts 386 instructions into a program whose
own header says 8086. WIRE CITY shipped ten of them. They run on every
emulator and would die on the machine the code was written for.

Every ported program that was `.8086` must include the replacement, right
after `org 100h`:

```
        include '..\..\ENGINE\E_8086.INC'
```

It redefines the sixteen conditional jumps as macros that measure the
distance and emit the short form where it reaches, or the 8086's own
jump-over-a-jump where it does not — the same expansion TASM's `JUMPS` makes.
After including it the two builds differ by NOP padding alone.

Do not include it in anything meant to use 386 instructions.

## When it is done

Move the TASM original to `TASM/<PROGRAM>/`, unchanged, **and its built
`.COM` with it** — that binary is the oracle, and it is what `BinAccount`
actually compares. A source that can no longer be assembled is still a
perfectly good archive if the thing it produced travelled with it.

Then rename the `F` file to the plain name in the program's folder. From then
on the FASM source is the one that is edited, and the archived TASM source is
a frozen oracle, not a parallel branch. Say so in the program's README, and
note that the archived version cannot be rebuilt without owning TASM, which is
why the FASM one exists.

Then take the program out of the root `MAKEWIN.BAT`/`BUILDQ.BAT`
orchestrator: those exist only for what has not migrated yet.

**The shared engine moves last.** `ENGINE/E_*.INC` is included by the
examples, by `LAB/HOUSE`, and by four games, so it cannot be renamed until the
last of them has migrated. Until then `ENGINE/` holds both — `E_MATH.INC` for
whatever still assembles with TASM, `E_MATHF.INC` for what has moved — and the
migrated programs include the `F` names. It looks untidy and it is honest;
say so where a reader will meet it. When the last game moves, rename the `F`
files, create `TASM/ENGINE/`, and the archived programs one directory deep
(`TASM/EXAMPLES/`, `TASM/LAB/`) start resolving `..\ENGINE\` correctly again
without a single path being edited. **This has happened**: the engine is
collapsed and `TASM/` is closed.

## An EXE is a different animal

Everything here is a COM except OWL FLY II. If you ever port another
multi-segment program, four things have no COM equivalent:

- `format MZ`, `entry SEG:LABEL` (TASM puts it on the last line, `END X`),
  `stack SEG:0`, and one `segment` per `SEGMENT`. An `ORG X` inside a segment
  must become **`rb X - $`**: FASM's `org` moves the counter and emits
  nothing, so the segment stays as short as its last real byte and every
  segment above it slides down.
- **`PROC FAR` carries two meanings.** `RET` inside it is `RETF`, and a call
  to it is far. Write the call as `call SEGMENT:LABEL`. Do **not** write
  `call far ptr X` — FASM accepts that line and assembles an *indirect* far
  call through memory, which is a different instruction that looks right.
- **There is no `ASSUME`.** Inside a far segment, a reference to a symbol
  declared there needs an explicit `cs:`; a reference to another segment's
  symbol through this one's CS needs the gap between their bases added back:
  `[cs:SYM+(THERE-HERE)*16+bx]`. A difference of two segment names is a plain
  paragraph count to FASM, so that expression assembles to a constant.
- **FASM does not merge same-named segments.** A file written as a
  continuation of another's segment must have its `include` moved up to
  follow it, or its bytes land in the next window.
- **`entry SEG:LABEL` must come BEFORE `segment SEG`.** This one has no
  warning attached to it. Put the declaration after the segment it names and
  FASM stops on the **`segment` line** — not on the `entry` line — with
  `error: invalid argument`, and writes no EXE at all. Since TASM's `END
  start` lives on the *last* line of a file, translating it in place is the
  natural thing to do and it is exactly wrong. Verified four ways: entry
  first passes, entry last fails, and where `stack` goes makes no difference
  to either. It cost a take of lesson 2, whose script had the declarations at
  the bottom because they read better there.

Check an EXE with `BinAccount -exe old.exe new.exe`. It cannot be walked in
one pass — each segment is padded to a fixed window, so the two builds are the
same length there even where the code shrank — so it cuts at the segment
boundaries and accounts for each separately. The boundaries come from the
executable's own relocation table; do not try to find them by looking for runs
of padding, because the segments are full of tables that start out zero.

## What must never enter this repository

Turbo Assembler, TLINK, Turbo Debugger, Borland Pascal 7, Turbo Pascal 5.5
and Volkov Commander are commercial software. They may be used locally; they
may not be committed. `THIRD-PARTY.md` records this alongside the inventory
of what *is* vendored (FASM, CWSDPMI, js-dos, DOSBox wasm) and its licences.
That table is the reason the migration is happening at all.
