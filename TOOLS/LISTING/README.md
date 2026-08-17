# LISTING - what did my line turn into

FASM has no disassembler - the word does not occur once in its documentation.
For a student the listing is the better tool anyway: it answers the question
they actually have (*what did my line turn into*) rather than the one they do
not have yet (*what are these bytes*).

    FASM    TURN.ASM TURN.COM -s TURN.FAS
    LISTING TURN.FAS TURN.LST

`TURN.LST` is every source line with the address it landed at and the bytes
it became.

## Where the source is

Not here. `LISTING.ASM` is flat assembler's own tool, vendored unchanged at
`../FASM/TOOLS/DOS/LISTING.ASM` with the rest of the FASM package, under
FASM's licence (`../FASM/LICENSE.TXT`). This folder holds only the build of
it - the vendored tree stays exactly as shipped.

Build it from inside DOS with this folder's `MAKE.BAT`, or from Windows with
`MAKEWIN.BAT` (which drives the same `MAKE.BAT` through DOSBox).

## The two cautions, from the tool's own documentation

- **Generate the listing immediately after the build, from the same
  directory, with nothing moved or edited in between.** The `.FAS` file is a
  symbol dump that refers back to the source files by name; a stale pair
  prints garbage.
- **Pass `-a` for executable formats** (EXE) to get run-time addresses. A
  plain `.COM` needs nothing.

## Runtime

Like FASM itself, `LISTING.EXE` is a 32-bit DPMI program: running it needs a
DPMI host (`../CWSDPMI/CWSDPMI.EXE`). On the workbench disk the host is
loaded persistently by `autoexec`, so `LISTING` works as a bare command
there.
