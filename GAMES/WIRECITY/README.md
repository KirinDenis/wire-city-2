# WIRE CITY 86

### ▶ Play online: https://kirindenis.github.io/wire-city-86/

A wireframe night-flight over a procedural megacity, written in **8086
assembly** for **VGA mode 13h**, in one source file, into a `.COM` of five
kilobytes. Integer maths only — no floating point anywhere — hidden lines
removed with a painter's algorithm, near-plane clipping, free yaw steering
with aeroplane-style banking.

Fly forward, bank left and right through the streets, climb over the towers —
or fly into one.

```
Controls:  ← / →  turn (with bank)
           ↑ / ↓  climb / descend
           ESC    quit
           SPACE  restart after a crash
```

## Build it yourself

Everything you need is in this repository. Nothing has to be bought,
downloaded or installed — the assembler is here, and it is free to use and to
pass on.

Mount the repository in DOSBox (or run it on real DOS), then:

```
GO                      read this once - it says what to type
cd GAMES\WIRECITY
MAKE
RUN
```

`MAKE` should answer **`3 passes, 5230 bytes`**. That is the whole game.

The assembler is [flat assembler](https://flatassembler.net/), in
`TOOLS/FASM`. There is no linker step — FASM writes the `.COM` directly. It
loads a small DPMI host from `TOOLS/CWSDPMI` first, because the assembler is a
32-bit program and DOS is not; `MAKE` does that for you and the host unloads
itself again afterwards.

Open `CITY.ASM`, change something, `MAKE` again. That is the entire loop.

If it runs sluggishly, raise the emulator speed — `cycles=max` in
`dosbox.conf`, or Ctrl+F12 while it runs.

### …or from Windows, without opening DOSBox yourself

`MAKEWIN.BAT` and `RUNWIN.BAT`, in this folder, do the same thing from a
Windows prompt: they start DOSBox, run `MAKE` or the game, and close it again.
`MAKEWIN` is not a second build — it drives the `MAKE.BAT` above, so there is
only ever one way the game is assembled.

```
MAKEWIN                 assemble it (in DOS, via DOSBox)
MAKEWIN CHECK           assemble again with the Windows FASM and compare
RUNWIN                  play it
RUNWIN TASM             play the Turbo Assembler build instead
```

`MAKEWIN CHECK` exists to keep one claim honest: the Windows assembler is much
faster, and leaning on it is only legitimate while it emits the same bytes as
the DOS one. It writes `CITYW.COM`, never `CITY.COM`, and compares. They have
matched every time.

Both read `DOSBOX=` from `LOCAL.BAT` in the repository root if it is there, and
fall back to `dosbox.exe` on the `PATH`. Neither is needed to build the game —
they are a convenience for working on Windows, and the DOS route above stays
the one that has to work.

## The Turbo Assembler version

This source is a translation. The game was first written for Borland's **Turbo
Assembler**, and that version is kept unchanged in **[`TASM/WIRECITY`](../../TASM/WIRECITY)** —
you do not need it, and unless you already own TASM you cannot build it, which
is precisely why the FASM translation exists.

The two builds differ by **312 bytes and not one instruction**, and every one
of the 312 is a `NOP`. TASM is a one-pass assembler: its `JUMPS` directive
reserves room for a near jump, and when a short one turns out to be enough it
pads the leftovers, because the addresses after it are already placed and
cannot move. FASM makes three passes and needs no padding.

That is checked rather than asserted. [`TOOLS/BinAccount`](../../TOOLS/BinAccount)
decodes both builds and walks them instruction by instruction; it has to be
able to name every byte of the difference, and it prints in hex and stops at
anything it cannot. That accounting, not a matching checksum, is what makes
the translation provable — the two binaries are not supposed to match.

```bash
dotnet run --project TOOLS\BinAccount -c Release -- TASM\WIRECITY\CITY.COM GAMES\WIRECITY\CITY.COM
```

### The 386 jumps that were nearly shipped

The first FASM build of this game was wrong, and looked finished. TASM's
`.8086` directive restricts the instruction set; **FASM has no equivalent**,
so the restriction was simply lost in translation. FASM then did the sensible
thing for a modern assembler and encoded ten out-of-range conditional jumps
in the 386 long form `0F 8x` — inside a program whose first line says *8086
only*. It ran perfectly in every emulator and would have died on the machine
it was written for.

`BinAccount` found them by refusing to explain a five-byte TASM sequence
against a four-byte FASM one. The fix is
[`ENGINE/E_8086.INC`](../../ENGINE/E_8086.INC), included right after
`org 100h`: it redefines the sixteen conditional jumps as macros that measure
the distance themselves and fall back to the 8086's own jump-over-a-jump.

Translating it also turned up a bug nobody had noticed: a variable called
`di`, shadowed by the register of the same name, so every `[di]` in the file
refers to the register instead. The variable is never read. TASM's own
listing says so plainly — `[di]` assembles as `C7 05`, register-indirect,
while its neighbour `[dj]` assembles as `C7 06` with an address.

## Play in the browser

The browser build runs the same `CITY.COM` inside DOSBox compiled to
WebAssembly via [js-dos](https://js-dos.com).

1. Build `CITY.COM` as above.
2. Make the js-dos bundle `docs/city.jsdos`. Two ways:
   - **Easiest:** open the js-dos studio at <https://js-dos.com>, drop in
     `CITY.COM`, set the run command to `CITY.COM`, export the `.jsdos`
     bundle, save it as `docs/city.jsdos`.
   - **Scripted (Windows):** run `docs/pack.ps1` from the repository root. It
     zips `CITY.COM` + `docs/dosbox.conf` into `docs/city.jsdos`. Check the
     bundle layout against current js-dos docs — the config path occasionally
     changes between releases.
3. Test locally (`file://` will not work — it needs http):
   ```
   python -m http.server -d docs 8080
   ```
   then open <http://localhost:8080>.

### SharedArrayBuffer note (GitHub Pages)

Threaded js-dos wants `SharedArrayBuffer`, which needs COOP/COEP headers that
GitHub Pages cannot set. If the page shows a `SharedArrayBuffer` error, use
the `coi-serviceworker.js` already in `docs/` — uncomment its `<script>` line
in `index.html` — or use a single-threaded js-dos build.

## Deploy to GitHub Pages

1. Push the repository to GitHub.
2. Settings → Pages → **Deploy from a branch** → branch `main`, folder
   `/docs`.
3. The game appears at `https://<user>.github.io/wire-city-86/`.

## Licence

The game and the build scripts are **MIT** — see `LICENSE`.

The assembler and the DPMI host that ship with this repository are other
people's work under their own terms, and the browser build embeds DOSBox and
js-dos, which are **GPL**. All of it is listed, with its terms and its
sources, in [`THIRD-PARTY.md`](../../THIRD-PARTY.md) at the repository root.
