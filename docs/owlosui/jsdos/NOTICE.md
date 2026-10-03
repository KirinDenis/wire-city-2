# The files in this folder are not this project's

They are **js-dos 8.3.20**: DOSBox compiled to WebAssembly, and the
JavaScript that runs it in a page. The demo's DOS PC
([../dosbox/dosbox.js](../dosbox/dosbox.js)) loads them; nothing else does.

| File | What it is | Licence |
|---|---|---|
| `js-dos.js`, `js-dos.css` | js-dos 8.3.20 | GPL-2.0 |
| `emulators/emulators.js` | js-dos's emulator loader | GPL-2.0 |
| `emulators/wdosbox.js`, `emulators/wdosbox.wasm` | **DOSBox**, compiled to WebAssembly | **GPL-2.0** |
| `emulators/wlibzip.js`, `emulators/wlibzip.wasm` | libzip, compiled to WebAssembly | BSD-3-Clause |

**Used as published.** Nothing here is patched or rebuilt. The corresponding
source is js-dos 8.3.20 at <https://github.com/caiiiycuk/js-dos>, and the
DOSBox forks it is built from are at <https://github.com/js-dos>. The full
text of the GPL is in [COPYING-GPL-2.0.txt](COPYING-GPL-2.0.txt).

**The GPL covers these files only.** The rest of this repository is MIT
([../../../LICENSE](../../../LICENSE)): the toolkit talks to the emulator
from outside, through its published interface, and the DOS programs that run
inside it are separate works - as a DOS program has never taken on the
licence of the machine it runs on.

See [THIRD-PARTY.md](../../../THIRD-PARTY.md) for everything in this
repository that is not its own.
