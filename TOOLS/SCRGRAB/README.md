# SCRGRAB — take text screens off a running DOS program

A resident that copies the 80×25 text screen out of video memory when you
press both Shift keys, and writes what it collected when you unload it.

## Why

Rebuilding a text-mode interface from screenshots is archaeology. You enlarge
a JPEG, argue about which blue that is, change a constant, look again. We
spent an afternoon on exactly this and got the desktop colour backwards —
light grey on blue instead of blue on light grey, which is a different picture
entirely.

The machine never had to guess. Every cell of an 80×25 screen is two bytes in
video memory: a glyph index and an attribute byte, four bits of foreground and
four of background. Read them and the question is answered, exactly, with
nothing left to interpret.

## Build

```
cd TOOLS\SCRGRAB
MAKE
```

or `MAKEWIN` from Windows, which drives the same `MAKE.BAT` through DOSBox.

`TESTWIN` runs a self-test: it cannot press the hotkey for you, but it proves
the resident installs once, notices a second copy, and comes back out. Those
are the failures that leave a machine needing a reboot, and none of them
announce themselves.

## The whole session, one command

```
TOOLS\SCRGRAB\GRABWIN
```

DOSBox comes up with the repository on `C:` and Borland on `D:`, SCRGRAB
already resident, and the IDE running. Arrange a screen, press **both Shift
keys**, repeat. `Alt+X` quits the IDE — and then the shots write themselves,
DOSBox closes, and every capture is decoded to `SHOTnn.TXT` beside it.

Nothing has to be remembered at the end of a session, which is the point: the
step everybody forgets is always the one that saves the work.

Borland comes from `TASMDIR` in `LOCAL.BAT`, which is not committed — and
neither is `SHOTS\`, because a dump of the IDE's screen is a picture of
commercial software even though the tool that took it is ours.

## Using it by hand

```
SCRGRAB              go resident
  ... run whatever you want to study, arrange the screen ...
  ... press BOTH SHIFT KEYS - a short beep means it took one ...
  ... up to eight screens ...
SCRGRAB /U           write SHOT00.BIN .. and unload
```

Then, from Windows:

```
TOOLS\ShotRead\ShotRead.exe SHOT00.BIN
TOOLS\ShotRead\ShotRead.exe SHOT00.BIN --grid
```

which prints the screen as text and — the part that matters — a legend of
every distinct attribute in it, by name, with a count and where it first
appears. `--grid` adds the attribute of every single cell.

## How it avoids the hard part of writing a resident

**It does not read the keyboard port.** A resident that watches for a letter
has to read port 60h itself, and then it owns the scancode: if it decides the
key was not for it, the handler it passes control to reads a port that has
already been drained. Every TSR that does this is relying on the hardware
being forgiving.

This one calls the BIOS handler *first* and only then reads the shift-state
byte the BIOS keeps at `0040:0017`. The keyboard behaves exactly as if we were
not installed. Both Shift keys together is a combination no program uses.

**It does not call DOS from the interrupt.** DOS is not reentrant — a resident
woken by an interrupt may already be standing inside a DOS call. The usual
cure is the InDOS flag and a wait for INT 28h. Here there is nothing to cure:
capturing is a `rep movsw` into memory we already own. The disk writing
happens in `/U`, which is an ordinary program in an ordinary context.

**It closes its inherited handles before going resident.** A resident keeps
its PSP for ever, and every handle open in it stays open too — including the
one behind a redirected `>` on the command line. The self-test found this the
first time it ran: the log came back with lines missing.

**It refuses to unload if something hooked the keyboard after it**, because
putting the old vector back would cut that program out of the chain while it
is still running.

## Limits

* 80×25 text only. A graphics mode is not at B800 and is not 4000 bytes.
* Eight screens, 32000 bytes of resident memory.
* It captures the *screen*, not the program: a dialog half-drawn is captured
  half-drawn.

## What is not in this repository

Borland Pascal, Turbo Debugger and Turbo Vision are commercial software. They
may be used locally; they are not committed here. SCRGRAB does not depend on
them — it will capture any DOS program's text screen — but the reason it
exists is to read theirs.
