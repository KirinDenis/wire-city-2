# OWL FLY III

The third generation. Forked 2026-08-18 from [`GAMES\OWLFLY2`](../OWLFLY2) —
the finished, released game — the same way OWL FLY II itself was forked from
a proven core: start from what works, whole, and grow the next version there.
OWL FLY II stays as it shipped; nothing in its folder changes because of this
one.

At the fork the two games are the same program. The main source is
`SRC\OWLFLY3.ASM` (OWL FLY II called it `CITY.ASM`), it builds to
`INSTALL\OWLFLY3.EXE`, and the first build was verified byte-identical to
OWL FLY II's before anything was allowed to change. What this version is FOR
is decided in the task files, not here — this README grows as the game does.

## Playing it in DOSBox, or on a real machine

It is a **DOS** program - not specifically MS-DOS. It wants DOS and a VGA
card and does not care whose: DOSBox, FreeDOS, PC-DOS, MS-DOS, or a real
486 with the lid off. Nothing has to be built: the game and the files it
loads are committed, in [`INSTALL/`](INSTALL).

1. Download the repository as a ZIP and unpack it:
   <https://github.com/KirinDenis/wire-city-2/archive/refs/heads/main.zip>
2. Start DOSBox and point it at that one folder:

   ```
   mount c C:\path\to\wire-city-2\GAMES\OWLFLY3\INSTALL
   c:
   OWLFLY3
   ```
3. If it feels heavy, give it more machine: `Ctrl-F12` a few times, or put
   `cycles=30000` in your `dosbox.conf`.

On Windows, **`PLAY.BAT`** in this folder does all of that for you.

**The front step.** The game opens with SELECT VIDEO SYSTEM - seven
entries, each stating its resolution and colours, digits or arrows and
ENTER - and every one of them flies:

1. HERCULES 720x348 mono - the 6845 programmed by hand, dithered by
   density, drawn cockpit
2. CGA 320x200, the classic palette 1 (cyan/magenta/white)
3. EGA 320x200x16 - runs on ANY EGA, the 64K launch card included
4. EGA 640x350x16 - EGA's best (needs a 128K card and an EGA monitor)
5. MCGA 320x200x256 - the same mode 13h path as VGA
6. VGA 320x200x256 - the game as born
7. VGA 640x480x16 - the crispest geometry of all, VGA only

Pick what the machine actually has: the retro entries talk to their
cards the way 1988 did, and a mode the hardware lacks will not appear
by magic. The renderer itself never changes - every mode converts the
same finished 320x200x256 frame, and the cockpit on the retro cards is
its own drawn artwork, baked offline (TOOLS\VidRig), not a per-pixel
conversion. **PLAYHGC.BAT is the Hercules door** - DOSBox comes up as a
real mono machine, the only place that mode exists (plain PLAY.BAT's
VGA marks it "- NOT IN THIS MACHINE", as the metal would). TESTCGA.BAT
and TESTEGA.BAT open DOSBox as those machine types for checking modes
you would otherwise fly on the VGA host.

**A shared sky.** `NETHOST.BAT` starts one and prints nothing clever; whoever
is joining runs `NETJOIN.BAT <your-ip>`. Both are DOSBox's own `ipxnet`, which
is IPX over UDP.

**On real hardware**, copy the files out of `INSTALL/` and run `OWLFLY3`.
VGA is required; a Sound Blaster is not, but it is what the sound was
written for.

## Building

Everything you need is in this repository. Mount it in DOSBox and, in this
folder:

```
MAKE            assemble  ->  INSTALL\OWLFLY3.EXE and the two blobs
RUN             fly it
```

Three assemblies, and only the last is a program. `SRC/RESDAT.ASM` and
`SRC/SIDEDAT.ASM` are artwork, palettes and fonts laid out as bytes; they
become `CITY.DAT` and `CPSIDE.DAT`, which the game loads at startup (the
blob names are load-bearing — the game opens them by name — so they did not
change with the fork). There is no `ENGINE.RAW` source step - the turbine
is generated at startup by GENBED.

The assembler is [flat assembler](https://flatassembler.net/) in `TOOLS/FASM`,
free to use and to pass on, and it writes the executable itself: no linker.

**This is an EXE of five segments** sitting end to end - the main one at
64K, then SKYSEG, UISEG, SYMSEG and TOWNSEG - and the game works out where
its back buffer goes by counting paragraphs past all of them. That is why
each segment ends by claiming its whole window: change a size and everything
above it moves. `ARCHITECTURE.md` in this folder has the whole story.

From Windows, `MAKEWIN` and `RUNWIN` drive the same build through DOSBox.
There is no `MAKEWIN CHECK` here: OWL FLY II kept one because it had a
frozen Turbo Assembler build to account against, and this game never had
one - it was born on FASM, after that migration finished.

`CONVERT.BAT` rebakes the cockpit, the models and the sound bank. Its output
is committed, so the build above does not need it to have run.
