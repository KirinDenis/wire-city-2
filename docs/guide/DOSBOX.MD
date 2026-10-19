# DOSBOX - the machine: js-dos on the site, plain DOSBox, real iron

The site's DOS PC is DOSBox compiled to WebAssembly (js-dos 8.3.20, as
published). What it gives a program, what stops it, and where it differs
from desktop DOSBox and a real 8086. Cards: VIDEO; the wire: NET.

## Rules you must not break

- Never tie speed to the CPU. One program meets several speeds here:
  `build` runs it at fixed 30000 cycles/ms, a game on C: at `max`
  (host-dependent), the course page at `auto` (3000/ms in real mode), and a
  visitor may set anything. Pace by the BIOS tick at 0040:006C or the
  retrace (TIME).
- Never let a divide fault: DOSBox, like every CPU after the 8086, pushes
  the address of the DIV itself, so a returning INT 0 handler (the default
  one here) re-runs it for ever. Guard divides, or install an INT 0 that
  never returns (A:\LESSONS\L15\PERSP.ASM Trap, A:\EXAMPLES\RELIEF.ASM
  TRAP0).
- Never use memory DOS did not give you without checking (Memory below).
- Save by writing, never by deleting: the site refuses DOS's deletions,
  and the file is back at the next switch-on. Truncate or overwrite.
- Never wait silently for a key: a visitor whose keys are elsewhere sees a
  hang. Say on screen what you wait for.

## The site's machine

- Each run is a fresh switch-on: the page writes a dosbox.conf and hands
  js-dos every file of every drive (`initFs`); nothing survives in memory.
  The boot lines remount C:, D: and added drives as floppies (`mount c C -t
  floppy`), `cls`, then run the program's own lines.
- Defaults: machine=svga_s3 memsize=16 core=normal cputype=auto cycles=max
  sbtype=sb16 rate=44100 gus=false pcspeaker=true xms=true (forced)
  ems=true umb=true ipx=true, "awake" on. The visitor changes them in
  Settings or with the console's `dosbox NAME=VALUE` (`dosbox cycles=fixed
  fixed=30000`), kept in that browser; a model asks first. For one run
  prefer `config -set "cpu cycles=fixed N"` in your own batch.
- `build A:\MY\X\X.ASM` writes BUILD.BAT beside it (CWSDPMI, `FASM -m 4096
  X.ASM X.COM > BUILD.TXT`, then GO.BAT if X.COM exists) and GO.BAT
  (`config -set "cpu cycles=fixed 30000"`, `X.COM`, `pause`), runs them
  with nothing resident (CWSDPMI unloads after FASM), then the DOS file
  manager, which would wipe a program's last words but for that `pause`.
  A game on C: runs `cd \GAMES\<DIR>`, `call RUN.BAT`.

## Speed: cycles and cores

- `auto`: real mode gets 3000 cycles/ms, protected mode runs flat out - FASM
  (DPMI) builds fast while a real-mode game crawls (OWL FLY III: a frame a
  second). `max`: 113.5 million cycles/s measured, the page still quick;
  a frame counter then measures the visitor's laptop, so pin `fixed` where
  a number must mean something (lessons: 30000).
- At low cycles a program that wipes and redraws one buffer is only ever
  seen half drawn: draw into a back buffer.
- The DOS window's frame shows the real speed (`[30001 cyc]`).
- core=normal for protected mode: on core=auto this build sends it to the
  dynamic core and FASM dies on its first macro (`RuntimeError:
  unreachable`). Real-mode games run on either. FASM here also needs
  `-m 4096`: with none, or 8192 and up, js-dos died.
- ~300 cycles/ms is a 4.77 MHz XT, ~900 an 8 MHz 8086, 30000 roughly a
  486. For an 8088 target measure in PCjs's IBM 5160.

## Memory

- 640K conventional; memsize 16/32/63 MB; XMS (DOSBox's own) always on, EMS
  and UMB on. With XMS off or under 16 MB, CWSDPMI and DPMI programs fail
  with DOS error 8, DOS/16M programs lack extended memory.
- The site starts programs with nothing resident; a shell elsewhere will
  not. A program that hangs buffers off CS without asking DOS (OWL FLY III:
  (CS+5FFFh) AND F000h) lands in A000h when loaded high: a striped band
  crawls down the screen, then js-dos dies. Allocate (INT 21h AH=4Ah/48h)
  or check and refuse:

```
        mov  ax,cs
        add  ax,NEEDP           ; AX = paragraph past what we use
        jc   .nomem             ; wrapped past 1 MB
        cmp  ax,[2]             ; PSP:2 (DS = PSP in a .COM): our block's end
        ja   .nomem             ; DOS gave less: say so, quit
```

- 0040:0013 = conventional memory in KB (`shl 6` = paragraphs).
- 386 code: unreal mode and VESA 100h with a linear frame buffer work in
  js-dos and DOSBox 0.74. Make only FS flat: a flat ES tripped BIOS
  interrupts and DOSBox logged ~12 s a frame.

## Drives and files

- A: course disk (A:\LESSONS, A:\EXAMPLES, A:\ENGINE, A:\TOOLS\FASM,
  A:\GAMES), B: spare, C: the games (C:\GAMES\<DIR>), D: the visitor's
  files, E: on: Map Drives. All are browser-storage folders mounted as
  FLOPPIES; builds work on A: only.
- Why: DOSBox re-reads a floppy whenever DOS looks but holds a hard disk
  as it was at boot; a file the page writes mid-run reaches DOS only there.
- DOS to page: polled every 1.5 s from the emulator's file list (names and
  sizes, no times). A size change is copied at once; a same-size rewrite
  only every fifth round (~7.5 s) and only under 256 KB; switch-off pulls
  once more, 3 s limit. A save that keeps its size can be lost: change its
  size, or keep it small and give it time.
- Free space reads as a floppy's, ~1.4 MB a drive: write little; an
  installer that checks space may refuse. 8.3 names (a longer one shows
  cut short, PROGRA~1.TXT). Every file is copied in at switch-on: big
  drives boot slowly.
- Browser storage is no vault: a site-data clean-up takes it all, and
  files have vanished with their folders left. The site restores its own
  files on A: and C:, never yours: `zip A:\MY\X` what must survive.
- A page that writes a file and switches on in the same instant loses it:
  wait ~800 ms while DOS still runs.

## What pauses, freezes or kills it

- A hidden tab: js-dos paces DOSBox on requestAnimationFrame, which a
  hidden tab never gets. The site races each rAF against a 250 ms timer and
  calls `ci.resume()` on visibilitychange while "awake" is on: a hidden
  machine ticks about once a second.
- Focus: DOS has the keys only after a click on its picture; Right Ctrl, a
  click elsewhere, or a menu over the window takes them back.
- No click: booted without a user gesture, the audio stays suspended and
  the machine stops dead at its first sound.
- A loop that never yields: A:\EXAMPLES\BBS.ASM calls INT 2Fh AX=1680h
  (release time slice) and IPX BX=0Ah every pass; without 1680h its sends
  never drained in the browser.
- `RuntimeError: unreachable`: the emulator is dead for good; the site
  shows CRASHED and the next run boots fresh. Seen: a wild write or jump
  (desktop DOSBox: a black screen, still running), buffers in A000h from a
  program loaded high, FASM on core=auto - and about one build in ten right
  after FASM's banner, cause unknown: build again.

## The picture

- Default "sharp": a whole multiple in device pixels, pixels SQUARE -
  320x200 shows as 640x400 (16:10). "fill" and "monitor" show 4:3, as a CRT
  did, where a 13h pixel is 1.2 times taller: a circle corrected by SQUASH
  (A:\LESSONS\L06\CLOCK.ASM) is round there and a little flat in sharp.
- 320x200 comes out at x2 in the 640x400 window. Grab frames with
  `ci.screenshot()`: the WebGL canvas reads back black.

## Keys sent by a page or an agent

- Right Ctrl never reaches DOS (host key); F9 belongs to the course page.
- `ci.sendKeyEvent(code, down)`, GLFW codes (Esc 256, Enter 257, Tab 258,
  letters upper-case ASCII). An INT 9 table read once a frame misses a
  short tap at low fps: hold level keys 300 ms+, tap toggles ~150 ms
  (typematic re-fires a long hold). Synthetic Tab, Esc and F8 once never
  arrived while digits did: give vital actions a digit too (INPUT).

## Sound

- sb16 by default, but sbpro2, sb2, none and the speaker off are choices:
  probe the DSP (reset at 226h, 0AAh at 22Ah) and fall back to the speaker
  or silence. Port, IRQ and DMA are DOSBox's defaults, announced in BLASTER
  (A220 I7 D1 H5 T6): read it. Mixer 44100 Hz (SOUND).
- Test rigs run silent: sbtype=none, pcspeaker=false, for the test only.

## The IPX card in the browser

- ipx=true makes INT 2Fh AX=7A00h answer at boot; the card is cabled only
  when the page calls `ci.networkConnect(0, "<relay>/ipx/<room>")`. The
  site does so for its own networked games; a program you build gets an
  answering, uncabled card unless the visitor sets `dosbox always=yes
  room=NAME` (a-z 0-9, up to 16). Use your own room AND socket: the room is
  otherwise the last game's (owlfly3 at first), and the server sends OWL
  FLY's sky advert on socket 5757h into every site room once a second.
- The address arrives late: until networkConnect lands, BX=9 gives a
  network number and six ZERO node bytes. Re-ask every tick until the node
  is non-zero (OWL FLY III waits up to 270 ticks, 15 s), showing a live
  wait; real cards answer at once. Uncabled, sends complete with a non-zero
  code: probe once and say "wire dark".
- `sti` after every INT 7Ah (IF may come back off, the tick stops); never
  mask IRQ 11 - DOSBox signals through INT 73h.
- A hidden, not awake tab freezes and the others time it out. `ci.pause()`
  pauses networkConnect too: deadlock.
- Desktop: `ipxnet startserver 213` / `ipxnet connect <host> 213` (a UDP
  port, not a socket). Protocol, ECBs: NET.

## Cross-origin isolation

- Not needed: js-dos runs here with no COOP/COEP and no SharedArrayBuffer,
  FASM included. /site/ and /course/ are served NOT isolated (isolated, a
  page cannot frame YouTube in Firefox). Older game pages still register
  coi-serviceworker.js for the whole site; it passes /site/ and /course/.

## Plain DOSBox (desktop)

- Start it from a .BAT with `-noautoexec` and the `-c "..."` lines in it
  (PowerShell splits the quoted strings).
- A batch started from `-c` swallows every later `-c`, `-c exit` too: it
  must close DOSBox itself (`MAKE EXIT`), or DOSBox idles and a stopwatch
  times nothing - time from inside, by the BIOS tick. A `-c` string ending
  in a backslash escapes its quote and eats the next `-c`.
- Cards: `-machine cga|ega|hercules`. Test a retro mode on the real card
  AND on svga_s3 playing it (most players' road). The site switches for
  one run: `play owlfly3 --machine hercules`.
- A host change to a mounted folder is unseen until `RESCAN`. Silent
  tests: `-set "mixer nosound=true" -set "speaker pcspeaker=false"`.
- FASM needs CWSDPMI first (no DPMI host in DOSBox). Check a build's size,
  not only that it exists: after a killed DOSBox FASM wrote zero bytes.

## Real iron is not the emulator

- Speed hides faults: on a 486 DX2 full detail was choppy and quick taps
  were lost, invisible at DOSBox's 30+ fps. Latch presses in INT 9 (INPUT).
- FASM's silent 386 jumps (`0F 8x`) run on every emulator and kill an 8086:
  include A:\ENGINE\E_8086.INC (FASM).
- INT 0: an 8086 pushes the address AFTER the DIV, DOSBox the DIV itself.
- Self-modifying code: an 8086 has fetched 6 bytes ahead (8088: 4); patch,
  then JMP (A:\ENGINE\E_RAST.INC LINE). DOSBox does not model the queue: a
  missing jump shows only on real iron.
- Under DOS 2.x INT 2Fh does not exist and calling it jumps into garbage:
  check the DOS version before probing IPX. A real PC may have 256K or
  512K: check PSP:2 and 0040:0013.

## Pages that boot js-dos

- Pin `backend: 'dosbox'` (js-dos remembers a choice); boot from a click.
- js-dos caches an extracted bundle in IndexedDB by path: a new file name
  per release, or fetch it `cache: 'no-store'` and pass a blob URL.
- A .jsdos is a zip with forward-slash names (PowerShell 5.1's
  Compress-Archive writes backslashes), one dosbox.conf at both
  `.jsdos/dosbox.conf` and the root, no `.jsdos/jsdos.json`.
- Network: `noNetworking: false`, networkConnect on "ci-ready" (js-dos's
  ipx/room options killed the keyboard); a failed connect rejects with
  `undefined`.
- js-dos owns short globals (`$`, `el`, `k`, `T`): wrap page code in a
  function. It hears keys on the whole window: stop them at `document`
  unless DOS has focus. Files for a hard-disk mount: `initFs`, before boot.
