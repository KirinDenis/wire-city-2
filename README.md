# WIRE CITY 86

### ▶ Play online: https://kirindenis.github.io/wire-city-2/

A wireframe night-flight over a procedural megacity, written in **8086 assembly**
for **VGA mode 13h** and built with **Turbo Assembler (TASM)** into a tiny
`.COM`. Integer math only, hidden-line removal via a painter's algorithm,
near-plane clipping, free yaw steering with airplane-style banking.

Runs in the browser via DOSBox compiled to WebAssembly ([js-dos](https://js-dos.com)).

Fly forward, bank left/right through the streets, climb over the towers — or
crash into one.

```
Controls:  ← / →  turn (with bank)
           ↑ / ↓  climb / descend
           ESC    quit
           SPACE  restart after a crash
```

## Repository layout

```
CITY.ASM        the whole game (8086 / TASM, single source file)
BUILD.BAT       assemble + link to CITY.COM (TASM/TLINK)
docs/           the browser version (GitHub Pages serves this folder)
  index.html      js-dos loader page
  dosbox.conf     config that goes inside the js-dos bundle
  pack.ps1        helper to build docs/city.jsdos from CITY.COM
LICENSE         MIT (game code). The emulator (DOSBox / js-dos) is GPL.
```

## Build the game (DOS / DOSBox)

Needs TASM + TLINK (e.g. from Borland/Turbo, here at `c:\bp\bin`). Inside DOSBox:

```
BUILD.BAT          rem  -> TASM CITY.ASM ; TLINK /t CITY.OBJ  -> CITY.COM
CITY.COM
```

`TLINK /t` (lowercase t) produces a **COM**, not an EXE.

If it runs sluggishly, raise the emulator speed (`cycles=max`, or
`core=dynamic` in `dosbox.conf` / via Ctrl+F12).

## Play in the browser

The browser build runs the same `CITY.COM` inside DOSBox compiled to
WebAssembly via [js-dos](https://js-dos.com).

1. Build `CITY.COM` (above).
2. Make the js-dos bundle `docs/city.jsdos`. Two ways:
   - **Easiest / most reliable:** open the js-dos online studio at
     <https://js-dos.com>, drop in `CITY.COM`, set the run command to
     `CITY.COM`, and export the `.jsdos` bundle. Save it as `docs/city.jsdos`.
   - **Scripted (Windows):** run `docs/pack.ps1` from the repo root. It zips
     `CITY.COM` + `docs/dosbox.conf` into `docs/city.jsdos`. Verify the bundle
     layout against current js-dos docs — the config path/format occasionally
     changes between js-dos releases.
3. Test locally (a plain file:// won't work — needs http):
   ```
   python -m http.server -d docs 8080
   ```
   then open <http://localhost:8080>.

### SharedArrayBuffer note (GitHub Pages)

Threaded js-dos wants `SharedArrayBuffer`, which needs COOP/COEP HTTP headers
that GitHub Pages can't set. If the page shows a `SharedArrayBuffer` error:

- grab `coi-serviceworker.js` (Guido Zuidhof's tiny header-injecting service
  worker) into `docs/`, and uncomment the `<script src="coi-serviceworker.js">`
  line in `index.html`; **or**
- use a single-threaded js-dos build.

## Deploy to GitHub Pages

1. Push the repo to GitHub.
2. Settings → Pages → **Deploy from a branch** → branch `main`, folder `/docs`.
3. The game appears at `https://<user>.github.io/wire-city-2/`.

## License

Game code (`CITY.ASM`, build/web scaffolding): **MIT** — see `LICENSE`.

The browser build embeds **DOSBox** and **js-dos**, which are **GPL**-licensed
and are fetched from the js-dos CDN (not vendored here). They are tools used to
run the game, not part of the game's own source.
