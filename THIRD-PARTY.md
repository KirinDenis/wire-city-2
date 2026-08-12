# Third-party software in this repository

Everything in this repository is the authors' own work under the [MIT
licence](LICENSE), **except** the files listed here. This page exists because
some of them carry obligations that MIT does not, and because the browser
build publishes them to anyone who opens the page.

## What ships

| Component | Path | Version | Licence | Upstream |
|---|---|---|---|---|
| js-dos | `docs/jsdos/js-dos.js`, `js-dos.css` | 8.3.20 | GPL-2.0 | [caiiiycuk/js-dos](https://github.com/caiiiycuk/js-dos) |
| js-dos emulators loader | `docs/jsdos/emulators/emulators.js` | 8.3.20 | GPL-2.0 | [caiiiycuk/js-dos](https://github.com/caiiiycuk/js-dos) |
| DOSBox, compiled to WebAssembly | `docs/jsdos/emulators/wdosbox.js`, `wdosbox.wasm` | js-dos 8.3.20 build | **GPL-2.0** | [DOSBox](https://www.dosbox.com/), via [js-dos](https://github.com/js-dos) |
| libzip, compiled to WebAssembly | `docs/jsdos/emulators/wlibzip.js`, `wlibzip.wasm` | js-dos 8.3.20 build | BSD-3-Clause | [libzip](https://libzip.org/) |
| coi-serviceworker | `docs/coi-serviceworker.js` | 0.1.7 | MIT | [gzuidhof/coi-serviceworker](https://github.com/gzuidhof/coi-serviceworker) |
| flat assembler (fasm) | `TOOLS/FASM/` | 1.73.35 | BSD-style | [flatassembler.net](https://flatassembler.net/) |
| CWSDPMI | `TOOLS/CWSDPMI/` | r7 | GPL-2.0, or binary-only with its notice | [DJGPP archive](http://www.delorie.com/pub/djgpp/current/v2misc/) |

`coi-serviceworker.js` carries its own attribution in the first line of the
file. The others carried nothing, which is what this page fixes.

## flat assembler, and why it is in here at all

`TOOLS/FASM/` is the official DOS package of flat assembler 1.73.35, unpacked
exactly as downloaded from [flatassembler.net](https://flatassembler.net/) —
binaries, documentation, licence and the assembler's own source, which is
written in itself.

Copyright (c) 1999-2026 Tomasz Grysztar. Its licence is BSD-style: free for
commercial and non-commercial use, redistribution permitted in source and
binary form provided the copyright notice, the conditions and the disclaimer
travel with it. They do — see `TOOLS/FASM/LICENSE.TXT`, which is the file the
licence asks to be included, and which is why the package is vendored whole
rather than trimmed to the one executable we use.

It is here because **the toolchain has to be one a viewer may also have.**
This repository is built with tools bought in the nineties; nobody watching a
lesson can be asked to buy them. FASM can simply be handed over, and it
assembles the same bytes.

## CWSDPMI, and why an assembler needs it

`TOOLS/CWSDPMI/` is CWSDPMI r7, the DPMI host from the DJGPP archive.

> CWSDPMI V0.90+ (r7) Copyright (C) 2010 CW Sandmann  ABSOLUTELY NO WARRANTY

That notice is the licence's own condition for shipping the binary without
source; the alternative is the GPL with source, and either is allowed. Its
documentation travels with it in `cwsdpmi.doc`.

It is here because **the DOS build of FASM cannot run in DOSBox without it.**
`FASM.EXE` is a DPMI client and DOSBox is not a DPMI host; `FASMLITE.EXE`
avoids DPMI by entering 32-bit real mode instead, which DOSBox refuses at
every core and CPU setting — and so does DOSBox-X, which was tried next.
CWSDPMI supplies the missing service in twenty-one kilobytes, and `MAKE WCDOS`
then assembles inside DOS exactly as a viewer's browser will.

That target exists for one purpose: to prove the DOS assembler and the Windows
one emit the same bytes. **They do** — WIRECITY comes out of both as the same
5230 bytes, hash for hash. Which is what makes `MAKE WCFASM`, the fast Windows
path, legitimate rather than merely convenient.

## The GPL part, and what it means here

`wdosbox.wasm` is DOSBox, compiled. It is **GPL-2.0**, and publishing the page
distributes it. That brings two obligations, and neither is onerous:

**The terms must travel with it.** The GPL-2.0 text belongs beside the
binaries, as `docs/jsdos/COPYING-GPL-2.0.txt`.

**The corresponding source must be available.** It is, upstream and unmodified:
js-dos 8.3.20 at [github.com/caiiiycuk/js-dos](https://github.com/caiiiycuk/js-dos)
and the DOSBox forks under [github.com/js-dos](https://github.com/js-dos). These
files are used exactly as published — nothing in this repository patches or
rebuilds them.

The GPL applies to those files. It does not reach the game, the engine, the
tools or the lessons: they are separate programs that happen to run *on* the
emulator, the same way a DOS program does not inherit DOSBox's licence.

## What is deliberately NOT here, and must never be

This matters more than it looks, because the obvious next step — "let people
try it in the browser" — walks straight into it.

| Software | Why it is not here |
|---|---|
| Borland Pascal 7 / Turbo Pascal 7 | Commercial, never released for redistribution. Used locally to build; not shipped. |
| Turbo Assembler (TASM), TLINK, Turbo Debugger | Same. TASM was never part of Borland's free "antique software" releases. |
| Turbo Pascal 5.5 | It *is* free to download — and its terms say, in as many words, that the files **"may not be made available via the Internet"**. Free to use, not free to host. |
| Volkov Commander | Shareware. Used locally in a lesson; not shipped. |

The build expects these on the machine that runs it, named in `LOCAL.BAT`,
which is gitignored for exactly this reason.

If a browser sandbox is ever wanted, the toolchain has to be one that may be
redistributed — a free assembler such as FASM or JWasm, or simply shipping the
already-compiled program so a visitor can *run* the result without a compiler
being handed out at all.

---

*This is an inventory, not legal advice. Where a term matters to you, read it
at the source — every one is linked above.*
