# The course page

`docs/course/` — every lesson of *Writing a DOS game from scratch* in one page:
its **source** in an editor that colours assembler, a **DOS PC** in the page
that assembles it with FASM and runs it, and its **video**. A prototype,
started 2026-10-02, live at `https://kirindenis.github.io/wire-city-2/course/`.

```
+-- PIXEL.ASM (editor) ------------+-- DOS: BUILD.BAT --------------+
|                                  |  the lesson, built and running |
|                                  +-- L03 - lecture 3 -------------+
|                                  |  its YouTube video             |
+-- Build -------------------------+                                |
|  FASM's words, what to press     |                                |
+----------------------------------+--------------------------------+
F1 Lessons  F2 Save  F9 Build+run  Ctrl-F9 Run  ...  Right Ctrl: keys back
```

## Addresses — the videos link here, do not break them

| Address | Opens |
|---|---|
| `course/` | the list of lessons |
| `course/?l=7`, `?l=07`, `?l=L07` | lesson in folder `LESSONS\L07` — the FOLDER number, never the lecture's (lectures go hex at 0D) |
| `course/?l=5b` | lecture 5B: the second program in L05 (PIVOT.ASM) and its own video |
| `wbtest.html?l=N` | redirects to `course/?l=N` — **this is the link under lectures 1–17 on YouTube**. Its `?e=` / `?g=` still open the old workbench |
| `l02.html` `l03.html` `l05.html` `l21.html` `l22.html` `l23.html` | redirect to `course/?l=NN` (the old one-lesson pages; their text is in git history) |

The page writes the open lesson back into the address, so a reload or a
copied link lands on the same lesson. Lectures 18–23 have no link in their
YouTube descriptions yet; theirs would be `course/?l=18` … `?l=23`.

## Files

| File | What |
|---|---|
| `index.html`, `course.css` | the page: a canvas, and the module that runs `CourseApp` |
| `course.js` | the course: lessons list, layout of the four windows, open / build / run, the video window, menus and keys |
| `dos.js` | the DOS PC: `CourseDos`, on OWLOSUI's `DosBox` + `DriveGates` — its dosbox.conf, a run as a fresh boot, the floppy poll, the key gate, crash recovery |
| `log.js` | the page's diary (`log.lines`), also to the browser console (F12) |
| `course.json` | **generated** by `../pack-course.ps1`: every lesson, title, notes, main source, files, video |
| `files/` | **generated** by `../pack-course.ps1`: lesson sources, `ENGINE\*.INC`, FASM, CWSDPMI — what the page fetches |
| `../owlosui/` | **a copy** of OWLOSUI's web library (windows, editor, js-dos host), by `../pull-owlosui.ps1`; never edited here — see its README |

Nothing outside `docs/` is used: GitHub Pages serves `docs/` alone, and the
page was checked to fetch nothing from elsewhere in the repository.

## Run it

`.claude/launch.json` has `course`: a plain static server on `docs/`, port
8770, the same shape as Pages — open `http://localhost:8770/course/`
(or `http://localhost:8770/wbtest.html?l=10` to test a video link). Any
static server on `docs/` works; the page needs no special headers.

After changing a lesson's source, a `.INF`, or the YouTube playlist table:

```
powershell -ExecutionPolicy Bypass -File docs\pack-course.ps1
```

To take a newer OWLOSUI (after it is built and, ideally, committed there):

```
powershell -ExecutionPolicy Bypass -File docs\pull-owlosui.ps1
```

## How a lesson runs

Opening a lesson writes its files into this browser's storage, folder
`DOS A Drive` — which IS floppy A: of the DOS PC (`DriveGates`): what the
page writes DOS sees, what DOS writes comes back in about 1.5 s.

```
A:\LESSONS\Lnn\   the source and its includes, BUILD.BAT, GO.BAT, BUILD.TXT
A:\ENGINE\        the engine files (sources say ..\..\ENGINE\)
B:\               FASM.EXE, CWSDPMI.EXE
```

Files already on A: are kept — they may be the student's edits — until
Lessons > Reset. F9 saves the editor, boots the PC fresh with `call
BUILD.BAT`: `CWSDPMI`, `FASM -m 4096 X.ASM X.COM > BUILD.TXT`, then `call
GO.BAT`, which sets `cpu cycles=fixed 30000` and runs `X.COM`. The page
polls `BUILD.TXT` and shows FASM's last lines in the Build strip.

## What was measured, and why the code is the way it is

- **`core=normal`** (dos.js): on `auto` this DOSBox takes the dynamic core in
  protected mode and FASM dies on its first macro (`RuntimeError:
  unreachable`). Every course source is macros (E_8086.INC).
- **`FASM -m 4096`**: without `-m` FASM grabs CWSDPMI's virtual memory and
  js-dos dies; `-m 16384` dies; HOUSES.ASM died at 8192.
- **Build at `auto`, run at 30000.** `auto` runs FASM (protected mode) at full
  speed: HOUSES.ASM, 188 KB, in under a second. At fixed 30000 it did not
  finish in 40 s; `max` starves js-dos (FASM silent for 30 s). But real-mode
  programs on `auto` get DOSBox's slow default, and SQUARE (lesson 10), which
  wipes and redraws in one buffer, showed only its bottom rows. So GO.BAT
  switches to 30000 — the machine the lessons were made on — with DOSBox's
  own `config -set`, which works from a batch file.
- **Not cross-origin isolated, on purpose.** js-dos builds and runs without
  SharedArrayBuffer; and only a page that is not isolated can frame YouTube
  in Firefox and Safari (`<iframe credentialless>` is Chromium-only).
  **Beware `../coi-serviceworker.js`**: other pages of the site register it,
  its scope is the whole site, and it isolated this page too (live, Firefox,
  2026-10-03: no video, a popup blocked). It now passes `/course/`
  navigations through; `leaveIsolation()` in course.js updates an old copy
  of the worker and reloads once; and if the page is still isolated, the
  video window holds a link instead of a frame - never `window.open`.
- **The video is a window**: a YouTube iframe laid over an OWLOSUI window
  (`Style.Terminal`, black) after every paint, hidden while covered. While a
  mouse button is down outside it, the iframe lets the mouse through, or a
  window dragged across it would stick.
- **The key gate** (dos.js): js-dos 8 listens for keys on the whole `window`,
  so every key typed in the editor also went to DOS. Keys are stopped at
  `document` unless DOS has the focus. OWLOSUI's own DosBox still has this
  leak; the fix belongs there.
- **F9 is the page's even inside DOS** (capture listener, like Right Ctrl).
- **js-dos sometimes crashes** (`RuntimeError: unreachable`, right after
  FASM's banner, about 1 build in 10 at worst; cause not found). A dead js-dos
  never answers again, so everything that asks the old machine has a time
  limit; a crash is shown in the Build strip, and F9 drops the dead machine
  and boots a fresh one.
- **A file of any size opens in the editor** (OWLOSUI sends text in parts):
  HOUSES.ASM, 188 KB, opens, edits at its last line and saves byte-exact.

## Testing it as an agent

- **A hidden browser pane freezes js-dos** (and throttles the page's
  timers): a build "hangs" at FASM's banner. Nothing measured with the pane
  hidden means anything about timing; check `document.hidden`.
- `window.course` is the app: `course.openLesson(course.course.lessons.find(l
  => l.id === 'L10'))`, `course.onCommand(601)` (F9), `course.dos.box.ci` is
  js-dos's command interface (`ci.screenshot()` gives the frame as pixels —
  bounding boxes of lit pixels found the SQUARE fault).
- `import('/course/log.js')` then `log.lines` is the diary, DOSBox's own
  `[LOG_EXEC]` lines included.
- Wrap `course.dos.box.ci.sendKeyEvent` to count what reaches DOS.

## Open

- Why js-dos crashes now and then.
- YouTube links for lectures 18–23.
- Go to a FASM error's line in the editor.
- The page has no commander or console window of its own yet (OWLOSUI's demo
  has both; they are examples there, not library).
