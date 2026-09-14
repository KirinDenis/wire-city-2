# Notice for the files in this folder

These files are **not** part of the MIT-licensed source in this repository.
They are third-party software, published here so the games run in a browser.

| File | What it is | Licence |
|---|---|---|
| `js-dos.js`, `js-dos.css` | js-dos 8.3.20 | GPL-2.0 |
| `emulators/emulators.js` | js-dos emulator loader | GPL-2.0 |
| `emulators/wdosbox.js`, `emulators/wdosbox.wasm` | **DOSBox**, compiled to WebAssembly | **GPL-2.0** |
| `emulators/wlibzip.js`, `emulators/wlibzip.wasm` | libzip, compiled to WebAssembly | BSD-3-Clause |
| `src/` | js-dos 8.3.20's own TypeScript source, for reading | GPL-2.0 |

**Source.** All of it is used exactly as upstream published it; nothing here is
patched or rebuilt. The corresponding source is js-dos 8.3.20 at
<https://github.com/caiiiycuk/js-dos>, and the DOSBox forks it is built from at
<https://github.com/js-dos>.

**Why `src/` is here.** `js-dos.js` is minified, and several of its options are
documented nowhere but in the code — the shape of `softKeyboardLayout`, which
the OWL FLY pages depend on, is one of them. So the 80 files of js-dos's own
`src/` are unpacked here from the source map upstream publishes beside the
bundle (`js-dos.js.map`, from `cdn.jsdelivr.net/npm/js-dos@8.3.20`). It is the
real TypeScript, names and comments intact — not a beautified bundle.

Nothing loads these files: no page references them, and the browser never
fetches them. They are here to be read, and they double as the corresponding
source the GPL asks us to offer beside the binary. The bundled third-party
libraries that the same source map carries — preact, redux, immer — are
deliberately left out; only `src/` is unpacked.

The full GPL-2.0 text is in `COPYING-GPL-2.0.txt`, beside this file.

The GPL covers these files only. The DOS programs that run on the emulator —
the games and the lessons in this repository — are separate works under the
MIT licence in the repository root, in the same way that a DOS program has
never inherited the licence of the machine it runs on.

See [THIRD-PARTY.md](../../THIRD-PARTY.md) in the repository root for the full
inventory, including what is deliberately absent.
