# OWL FLY III BOND

OWL FLY III cut down for the Bondwell Model 8 class of machine: an 8088 at
4.77 MHz, 512K of memory, a CGA or Hercules screen and a PC speaker.
Forked from `GAMES/OWLFLY3` on 2026-10-02. OWL FLY III itself is unchanged.

## What is cut

| v3 has | the BOND has |
|---|---|
| seven video systems | CGA and Hercules |
| FULL / MEDIUM / LOW detail | LOW only, with no menu screen |
| Sound Blaster, PC speaker, silence | PC speaker or silence |
| a photographed cockpit (64000-byte bitmap, two RLE side views, CGA/HGC bakes) | a cockpit DRAWN from stroke lists: lines, boxes and words (`VPDL`, `VPSL`, `VPSR` in `SRC/VID.INC`) |
| panel captions dithered to imitate VGA colours | panel colours forced SOLID in the lookups (`BONDLUT`) |
| far pages aligned to 64K for the Blaster's DMA, top near 640K | packed pages, the game ends at CS+3000h |

The network is v3's, byte for byte, so a BOND flies in the same sky as
OWL FLY III.

## Memory map

| paragraphs from CS | what |
|---|---|
| below CS | SKYSEG, UISEG, SYMSEG, TOWNSEG, VIDSEG, packed, each as long as its code |
| 0000h | CODE: code, data, then reserved space - the zero-start variables (`SRC/ZERO.INC`), the BSS, the converters' tables (`CVTAB`) and the stack |
| 1000h | back buffer |
| 2000h | scrseg: the minimap (0..1FFFh) and the radar phosphor (F000h) |
| 3000h | end (`BONDTOP`) |

The game checks PSP:2 against `BONDTOP` before anything else and refuses
with a message if DOS gave it less.

## Files

`INSTALL/` holds everything that ships: `OWLFLY3B.EXE`, 55K, and nothing
else. The game opens no files: the 4x6 font is built in (`VFONTF` in
`SRC/VID.INC`).

What keeps the EXE small (it was 128K at the fork):

- CODE is the LAST segment, so everything reserved at its end is not in
  the file - DOS hands it over at load and MAIN clears it. That is the
  BSS, the stack, and every variable whose start value is zero: declare
  those in `SRC/ZERO.INC` with `rb`/`rw`, not in `DATA.INC` with `dw 0`.
- The far segments come first and are not padded to fixed windows.
- v3's code the BOND never runs is deleted, not switched off: EGA and
  VGA, the Blaster, the Shilkas, traffic, clouds, relief, the photo
  cockpit and its loaders.
- `BORD` keeps only the nearest `BONDCELLS` of v3's city walk.

## Speed tricks

- **Pre-shifted conversion tables.** `CGTBUILD` (`SRC/VID.INC`) copies
  the bank in use into `CVTAB` four times, the ink already shifted to
  its place in the output byte, so the CGA and Hercules converters do
  `LODSW`, `XLAT`, `OR` - no shifts - and read the tables through `SS:`.
  They are rebuilt on every day/night or palette change.
- **Row addresses by addition.** Neither converter multiplies per row.
- **Lines with the distances in registers.** `linereg` switches
  `ENGINE/E_RAST.INC`'s self-modifying `LINE` to a loop that keeps both
  distances in SI and BP; the other programs that include the engine are
  unaffected, byte for byte.

## Build and run

    MAKE        inside DOS, from this folder
    RUN         inside DOS
    MAKEWIN     from Windows
    PLAY        from Windows, CGA on a colour DOSBox
    PLAYHGC     from Windows, a Hercules DOSBox
    NETHOST / NETJOIN   a shared sky over IPX
    DISK        from Windows: DISK\OWLFLY3B.IMG (720K) and DISK\OWL360.IMG (360K)

## Measured

PCjs IBM PC XT (8088 at 4.77 MHz, 512K, CGA, PC DOS 2.00 or MS-DOS 3.21),
`OWL360.IMG` in B:, parked on the strip.

2026-10-18, the speed tricks above, ticks over 16 frames (x 3.4 = ms a
frame): the conversion to CGA 60 -> 51..53, the ground lattice 24 ->
20..23 (a different world each run, so that one is noisy). PCjs charges
instructions by their execution time and hardly by their length; on a
real 8088, where every code byte costs four clocks to fetch, the shorter
converter loop (41 -> 32 bytes per four pixels) should gain more.

**Ctrl+D is a profiler in the BOND.** It shows two lines of numbers: BIOS
ticks spent in each stage of the frame, summed over 16 frames. Multiply by
3.4 to get ms per frame. The slots are listed in `PROFMK`, `SRC/SYM.INC`.

2026-10-03, after removing the Shilkas, drawing far jets as their IFF
marker alone (`BONDJLOD`), dropping the runway paint and stopping the lamps
blinking: **about 1300 ms a frame**. The conversion to CGA (390 ms) is now
the largest stage, ahead of the aerodromes (210 ms), the city (150 ms), the
radar stations (130 ms) and the panel (115 ms).

2026-10-02, after the first cuts, in ms per frame:

| stage | ms |
|---|---|
| conversion to CGA | 390 |
| the Shilkas | 350 |
| the aerodromes | 285 |
| drawing the AI jets | 280 |
| the AI jets' physics | 235 |
| the city | 145 |
| the radar stations | 130 |
| the panel (one frame in four) | 115 |
| the ground lattice | 95 |
| sky + ground | 65 |
| **frame** | **about 2300** (was 3700) |

One MODELDRAW, the call that puts a jet, a Shilka or a radar on screen,
costs about 60 ms on this machine.
