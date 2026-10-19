# TOOLS - building and testing: FASM, batch files, the site's build, rigs

How a DOS program gets assembled, built by a batch file, run on the site or
a desktop DOSBox, and tested without a person watching. Plus the converters
the games' tables and artwork come from. Working batch files:
A:\GAMES\OWLFLY3\MAKE.BAT (several assemblies, an EXE), A:\GAMES\WIRECITY\
MAKE.BAT and RUN.BAT (one .COM, commented line by line).

## Rules you must not break

- FASM.EXE is a 32-bit DOS program: load CWSDPMI.EXE right before EVERY
  FASM run. With no arguments it stays resident for one program and unloads
  (`-p` keeps it). DOSBox has no DPMI host; DOSBox-X's does not satisfy FASM.
- In js-dos run FASM with `-m 4096` on `core=normal`. Without -m it takes
  CWSDPMI's virtual memory (~146 MB) and the emulator dies; -m 16384 died
  before the banner; -m 8192 died on a 188 KB source. On `core=auto` the
  dynamic core dies on FASM's first macro: "RuntimeError: unreachable".
  The site's `build` does both for you.
- Delete the old output first, then check three things: errorlevel (FASM ran
  and failed), existence (DOS's "Illegal command" sets no errorlevel) and
  SIZE: a zero-byte file passes both. A killed DOSBox's file lock, or a host
  scanner grabbing a fresh .EXE, made FASM leave exactly that.
- DOS text files are CR LF: .ASM .INC .BAT .TXT .CFG .INF. Most DOS editors
  show a bare-LF file as one endless line. Convert by extension, never over a
  folder glob: that turned every 0Ah inside an EXE into 0Dh 0Ah (26368 ->
  26528 bytes) and the program hung silently.
- Include A:\ENGINE\E_8086.INC after `org 100h` (see FASM): FASM silently
  emits 386 jumps an 8086 cannot run.

## FASM on the command line

- `FASM SRC.ASM OUT.COM` - the format comes from the source (`format binary
  as 'com'` + `org 100h`, or `format MZ`). Options: `-m KB` memory (the DOS
  version: extended memory only), `-p N` most passes (default 100), `-d
  NAME=VALUE` a symbol, `-s FILE.FAS` symbols for LISTING. A: carries FASM
  1.73.35 (A:\TOOLS\FASM\FASM.EXE) and A:\TOOLS\CWSDPMI\CWSDPMI.EXE.
- Success: "N passes, T seconds, B bytes." An error: "FILE [line]:", the
  line, "error: ..." (inside a macro, the macro's line too) and a non-zero
  errorlevel.
- What did my line become: `FASM X.ASM X.COM -s X.FAS`, then at once, same
  folder, nothing edited between, `LISTING X.FAS X.LST` (`-a` for an EXE) -
  a stale pair prints garbage. LISTING is in the repository's TOOLS\LISTING,
  not on A:.
- Byte identity is the regression test: A:\LESSONS\L05\TURN.ASM is 771 bytes on
  every machine. After an engine edit rebuild every program that includes it
  and compare; a comment-only pass must leave the binary identical.
- The Windows FASM prints the same diagnosis instantly: when a DOSBox build
  fails silently, look there. Ship its output only while `fc /b` says the
  bytes equal the DOS build's.

## A BUILD.BAT, a MAKE.BAT

- One folder per program, 8.3 names, every path relative to it: from
  A:\MY\HELI\ the tools are `..\..\TOOLS\`, the engine `..\..\ENGINE\`. A
  drive-root path works only where the tree is mounted AS the root, and DOS
  clamps `..` at the root. Nothing may lean on a variable set earlier: a
  file manager runs each command in a fresh environment.
- COMMAND.COM is not cmd.exe: no `CALL :label`, no cmd-style FOR; to repeat
  per name the batch CALLs itself with an argument. DOS `if` has no /i.

      @echo off
      if exist HELI.COM del HELI.COM
      ..\..\TOOLS\CWSDPMI\CWSDPMI.EXE
      ..\..\TOOLS\FASM\FASM.EXE -m 4096 HELI.ASM HELI.COM > BUILD.TXT
      if errorlevel 1 goto bad
      if not exist HELI.COM goto bad
      HELI.COM
      goto end
      :bad
      type BUILD.TXT
      :end

- Several assemblies (data blobs, then the EXE): CWSDPMI before each FASM,
  the EXE written as .NEW and renamed once it provably exists, the old one
  deleted only then (A:\GAMES\OWLFLY3\MAKE.BAT).
- `MAKE EXIT` ends with `exit`: a batch started from a DOSBox `-c` line
  swallows every `-c` after it, so only the batch can close DOSBox.

## The site's console: build and run

- `build A:\MY\HELI\HELI.ASM` writes BUILD.BAT and GO.BAT beside the source
  and starts the DOS PC in BUILD.BAT: del HELI.COM, CWSDPMI, `FASM -m 4096
  HELI.ASM HELI.COM > BUILD.TXT`, and if HELI.COM exists GO.BAT: `config
  -set "cpu cycles=fixed 30000"`, HELI.COM, `pause`. FASM's words come back
  from BUILD.TXT, errors with line numbers.
- It makes NAME.COM from one NAME.ASM. A source under A:\GAMES\DIR\ is built
  by that folder's MAKE.BAT. An .EXE or several assemblies: write your own
  MAKE.BAT and `run` it. `run PATH` starts any .COM/.EXE/.BAT where it is.
- A program from `build` runs at fixed 30000 cycles/ms (the site's own
  default is max), and GO.BAT then waits at `pause`: a key back to DOS. A new
  build or run replaces what runs. `zip A:\MY\HELI` hands the folder over.
- Builds work on A: only: it is a floppy mount, re-read on every look, so
  what the page writes reaches a running DOS. What DOS writes comes back
  every 1.5 s when its size changed; a same-size rewrite only every ~7.5 s
  and under 256 KB. A log your program writes: give it a second or two.
- About one build in ten at worst, js-dos dies right after FASM's banner;
  a dead machine never answers. Build again: it starts a fresh one.

## Running on a desktop DOSBox

- Start DOSBox from a .BAT with `-noautoexec` (else its autoexec runs first
  and buries the `-c` lines), the `-c` strings inside the .BAT.
- A `-c` string must not end in a backslash: it escapes the closing quote
  and DOSBox eats the next `-c`. Put environment lines in a .BAT.
- From Windows (the repository's GAMES\OWLFLY3\MAKEWIN.BAT): `-c` lines ending
  `-c exit` (a batch that EXITed from inside left zero-byte EXEs four times
  in a row), each FASM's output redirected to BUILD.LOG (three assemblers
  writing to the console: the third failed silently 3 runs in 4), the
  result measured (>= 100000 bytes for OWL FLY III), three attempts.
- A program that prints and ends vanishes when a file manager redraws: end
  its batch with `pause`.

## The converters (what exists)

C# console programs in the repository's TOOLS\ (`dotnet run --project
TOOLS\X`), run on Windows by each game's CONVERT.BAT. Their output is
committed, so a DOS build never needs them; they write CR LF and a "generated
by ... do not edit" header. None is on A:.
- SinTab: the lessons' 256-byte sine table. RecipTab OUT.INC [d] [near]: the
  8.8 reciprocal table for perspective without IDIV.
- Obj2Inc: an .OBJ model to a FASM include (`-s` scale, `-n` name, `-fasm`:
  without it, TASM spelling FASM rejects).
- Panel2Inc: cockpit PNGs to an include and palette, front and sides
  quantised together into the 63 DAC slots lent to art. Cab2Dat (after it):
  a PNG to a span-stream overlay, white = transparent, per-card variants.
- VidRig: CGA, EGA and Hercules lookup tables and baked panels, rendered to
  PNG first so the picture is judged before the assembly exists.
- Snd2Dat: WAVs to SFX.DAT (signed 8-bit at 11025 Hz, trimmed at -42 dB, a
  6 ms fade, shorter than the 32K ring). Tasm2Fasm and BinAccount: porting
  TASM code and accounting for every differing byte.
- On A:, in 8086 assembly: A:\TOOLS\OBJ2DAT.COM - `OBJ2DAT IN.OBJ OUT.DAT
  [units per metre]`, a binary model ('MD', counts, x y z words, faces of 4
  corners + colour; at most 255 vertices, 300 faces; material PALnn = that
  palette index). A:\GAMES\TRAINER\MAKE.BAT uses it.
- A table FASM can compute needs no tool: `repeat 256` / `db expr` / `end
  repeat`.

## Testing without a person

- Silent: a test conf with `[mixer] nosound=true`, `[speaker]
  pcspeaker=false` (DOSBox-X takes them as `-set "mixer nosound=true"`), on
  the site sbtype=none, plus the game's own NO SOUND - so give the game one.
- Measure from inside, never with a stopwatch: a DOSBox that swallowed
  `-c exit` idles after the program. Sum BIOS ticks (0040:006C, 18.2 Hz) per
  phase and write them to a log; a frame count published every 18 ticks is
  fps. OWL FLY III BOND's Ctrl+D profiler sums ticks per stage over 16
  frames (x 3.4 = ms a frame); its first mark after switching on must restart
  the clock, or that slot is charged the whole off time. Measure without the
  retrace wait (it measures the beam), same seed, same spot.
- An agent, not a person, presses the keys. A game reading key state once a
  frame needs holds: 300 ms for held controls at low fps, but a short tap
  (~150 ms) for toggles - typematic repeat re-arms a latch, and a long hold
  toggles twice. On the site a key alone is held 120 ms; `Up*800` holds 800.
- Let the program test itself: a switch (OWL NIGHT's /AUTO) that plays
  through the same code a click takes and writes a screenshot and a log line
  per step. Put the step number on screen; allow start-at-step-N.
- Freeze instruments, gated by Ctrl+D: a 10x10 square written straight to
  A000h in the colour of the stage the frame is in, a bar of blocks counting
  stages done. A frozen frame names its stage; count blocks, not hues.
- Calibrate a probe: draw a known value (0A5h) beside the unknowns; reading
  back 5Ah exposed an inverted probe (in OWL FLY's palette 8 is white).
- Do it twice and overlay: the trusted version in grey, the fast one in
  white, a red dot wherever they differ by more than a pixel.
- Risky integer maths: re-run the exact steps in a C# model, exhaustively
  (230680 fireball discs, zero writes outside the buffer).
- Desktop: stop only the DOSBox whose PID you started (a window titled
  "DOSBox" can be someone's file manager); DOSBox-X follows the host's
  keyboard layout (`-set "dos keyboardlayout=us"`) and sometimes faults at
  exit, so never judge by exit code. A program reading INT 16h can be fed
  keys written into the BIOS buffer (tail word 0040:001C) before it starts;
  one with its own INT 9 cannot.
- Start each scripted run on a clean folder: a leftover file raised an
  "overwrite?" dialog that ate the next keys.
- A page that fetches a .jsdos bundle for a test uses `cache: "no-store"`,
  or it tests an old build.
