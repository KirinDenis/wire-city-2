# OWLOSUI, a copy

This folder is a copy of the web library of **OWLOSUI** — a text-mode UI
toolkit with one Rust core, for DOS and the browser alike. OWLOSUI is its own
project: **https://github.com/KirinDenis/OWLOSUI** (MIT, `LICENSE.txt`).

The course page, [`../course/`](../course/), is built on it: the editor
with assembler colouring, the windows, and the DOS PC in the page (js-dos,
GPL-2.0 — see `jsdos/NOTICE.md`).

Only OWLOSUI's library is here - `lib/js` with its `apps/` (commander,
documents, DOS PC, console, log), and in `dos/` the three `lib/dos` files the
DOS PC's drive C: needs - never its examples, and it is not followed
live: it is copied when we choose to, by [`../pull-owlosui.ps1`](../pull-owlosui.ps1),
and [`VERSION.txt`](VERSION.txt) says which commit the copy came from. So
this repository keeps working whatever OWLOSUI is doing, and GitHub Pages,
which serves `docs/` alone, has everything the course page needs.

**Do not edit these files here.** A fix belongs in OWLOSUI; then pull again:

```
powershell -ExecutionPolicy Bypass -File docs\pull-owlosui.ps1
```
