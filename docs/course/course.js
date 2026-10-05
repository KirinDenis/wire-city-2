// The 8086 course, in OWLOSUI. PROTOTYPE, 2026-10-02.
//
// A lesson opens whole: its source in an editor that colours assembler, its
// video, and a DOS PC that assembles the source with FASM and runs it. And
// the student works with files as on a real PC: New, Open, Save, Save as;
// a two-panel commander over this browser's storage; a full DOS PC with its
// own commander, settings and network - and the three OWL FLY games.
//
//   Lessons   every lesson, its video and a few words on it; Open puts its
//             files on drive A: of the DOS PC, the source in the editor, and
//             builds and runs it
//   F9        save, build the .ASM in front with FASM on the DOS PC, run it -
//             FASM's words in the Build strip; Ctrl+F9 runs again
//   Commander Enter on an .ASM builds and runs it, on a .COM or .EXE runs it
//
// Built on OWLOSUI's library alone - ../owlosui/, a copy of OWLOSUI's lib/js
// (and the four lib/dos files its DOS PC needs) taken by ../pull-owlosui.ps1
// (https://github.com/KirinDenis/OWLOSUI). Its apps/ are the commander, the
// documents, the DOS PC, the console and the log; this file adds the course.
//
// WHERE THE FILES GO. A:\LESSONS\Lnn\ the lesson's own files, A:\ENGINE\
// the five engine files (the sources say ..\..\ENGINE\, which from
// A:\LESSONS\Lnn\ is exactly there), B:\ FASM and CWSDPMI. Files already
// on A: are left alone - they may be yours - until Lessons > Reset.
//
// TWO THINGS FASM NEEDS IN THIS PC, both found by testing (wire-city-2/
// .claude/skills/owlosui-lessons/references/gaps.md, item 7): core=normal
// (the DOS PC's default now), because a FASM macro kills js-dos's dynamic
// core, and FASM -m 4096, because FASM grabbing CWSDPMI's virtual memory
// kills it too.

import { sub, line, Style } from '../owlosui/owlosui.js';
import { BrowserStorage } from '../owlosui/files/browser.js';
import { CommanderTool, ASSOCIATIONS } from '../owlosui/apps/commander.js';
import { Documents, DocCm } from '../owlosui/apps/documents.js';
import { DosTool, DosCm } from '../owlosui/apps/dos.js';
import { DosBox } from '../owlosui/dosbox/dosbox.js';
import { unzip } from '../owlosui/dosbox/unzip.js';
import { ConsoleWindow } from '../owlosui/apps/console.js';
import { log, watchWindows } from '../owlosui/apps/log.js';

const Cm = {
  Exit: 2, About: 4, Dismiss: 5, Commander: 6, Console: 7,
  Next: 30, Zoom: 31, Close: 32, Cascade: 33, Tile: 34, Previous: 35, List: 36, SizeMove: 37, Minimize: 38,
  Lessons: 600, Build: 601, Run: 602, Watch: 603, Reset: 604,
  Open: 610, ListWatch: 611, ListClose: 612, BuildClose: 613, VideoClose: 614,
};
// Drive A: of the DOS PC: this folder of the browser's storage. The course
// disk (disk.zip, made by ../pack-course.ps1) is unpacked into it once.
const A = '/DOS A Drive/';
const DISK_VERSION = `${A}COURSE.VER`;
// FASM's memory in KB; ?m=N on the page tries another (testing the crash).
const FASM_KB = Number(new URLSearchParams(globalThis.location?.search ?? '').get('m')) || 4096;

/**
 * The speed every lesson runs at, set by GO.BAT with DOSBox's own
 * `config -set` after FASM has built at full speed: the machine the lessons
 * were made and measured on. On `auto`, real mode gets DOSBox's slow
 * default, and a lesson that wipes and redraws in one buffer (SQUARE,
 * lesson 10) is shown half-drawn - only its bottom rows ever appear
 * (measured 2026-10-02; whole at 30000).
 */
const LESSON_CYCLES = 30000;

/**
 * The games the course builds towards, on the DOS menu - each unpacked onto
 * C:\GAMES from the same bundle its own page plays. `page` is that page:
 * the bundle's name is read from it, because docs/pack.ps1 gives every
 * release a new name (owlfly3_v17.jsdos...) and retires the old one. The
 * networked ones join the same sky as their own page: `room`.
 */
const GAMES = [
  { key: 'owlfly', label: 'OWL ~F~LY', name: 'OWL FLY', page: 'owlfly.html', bundle: /owlfly_v\d+\.jsdos/,
    dir: 'OWLFLY', exe: 'FLYOWL.COM', hint: 'The first one: a city at night, in 64K, one segment' },
  { key: 'owlfly2', label: 'OWL FLY ~I~I', name: 'OWL FLY II', page: 'owlfly2.html', bundle: /owlfly2_v\d+\.jsdos/,
    dir: 'OWLFLY2', exe: 'FLYOWL2.EXE', room: 'owlfly2', hint: 'Multiplayer over the network - the same sky as its own page' },
  { key: 'owlfly3', label: 'OWL FLY II~I~', name: 'OWL FLY III', page: 'owlfly3.html', bundle: /owlfly3_v\d+\.jsdos/,
    dir: 'OWLFLY3', exe: 'OWLFLY3.EXE', room: 'owlfly3', hint: 'Every video card back to Hercules; multiplayer, the same sky as its own page' },
];
const RELAY = ['localhost', '127.0.0.1'].includes(globalThis.location?.hostname) ? 'ws://localhost:1900' : 'wss://view.owlos.sk';

/**
 * The DOS PC's settings are kept per page. A first visit to the course gets
 * the picture 'sharp' - whole multiples of DOS's pixels - in a window made to
 * fit 640x400 exactly (layout()): the DOS commander's text was hard to read
 * stretched by 'fill' to a fraction (the pilot, 2026-10-04), and 320x200
 * graphics come out at x2. And the network only for what asks for it, not
 * for every lesson build. A new key, so a visitor who got 'fill' gets this.
 */
const SETTINGS_KEY = 'course.dosbox.2';
function courseSettings() {
  try {
    if (!localStorage.getItem(SETTINGS_KEY)) localStorage.setItem(SETTINGS_KEY, JSON.stringify({ picture: 'sharp', always: false }));
  } catch { /* storage refused: the library's defaults */ }
}

/**
 * The DOS commander, started with the toolkit behind it (C:\OWL.BAT, the
 * library's): the course disk A:\ on the left, C:\ on the right. /STEP: to
 * run a program it steps out of memory, leaving the program's lines in
 * RUNPROG.BAT in the folder it was started in - C:\, here, so nothing is
 * written to the student's disk - and is started again afterwards. A program
 * then has all of DOS's memory, as from the prompt; OWL FLY III needs it.
 */
const COMMANDR_BAT = `@echo off
C:
cd \\
:again
call C:\\OWL.BAT A:\\TOOLS\\COMMANDR\\COMMANDR.EXE /STEP A:\\ C:\\
if not exist C:\\RUNPROG.BAT goto done
call C:\\RUNPROG.BAT
del C:\\RUNPROG.BAT
goto again
:done
`;

/** What the Build strip says when js-dos dies under a lesson. */
const CRASHED = 'The DOS PC crashed (js-dos: RuntimeError: unreachable) - it happens now and then, cause not found yet.\n' +
  'F9 builds again on a fresh machine.';

/** The course disk, fetched and unpacked once a visit: [{ path, contents }]. */
let diskFiles = null;
async function courseDisk(url) {
  if (!diskFiles) {
    const r = await fetch(new URL(url, import.meta.url));
    if (!r.ok) throw new Error(`the course disk (${url}): ${r.status}`);
    diskFiles = (await unzip(new Uint8Array(await r.arrayBuffer()))).filter(f => !f.path.endsWith('/'));
  }
  return diskFiles;
}

/**
 * The lesson an address names. ?l=7 is LESSONS\L07, as wbtest.html read it:
 * the folder's number, not the lecture's (lectures go hex at 0D, folders
 * never do). ?l=5b is the second lecture on L05 - its own entry, L05B, with
 * its own program and video. ?l=L23 works too. Anything else: none.
 */
function lessonFromAddress(lessons) {
  const v = new URLSearchParams(globalThis.location?.search ?? '').get('l');
  const m = /^L?0*(\d{1,2})([a-z]?)$/i.exec(v?.trim() ?? '');
  if (!m) return null;
  const id = `L${m[1].padStart(2, '0')}${m[2].toUpperCase()}`;
  return lessons.find(l => l.id === id) ?? lessons.find(l => l.id === id.slice(0, 3)) ?? null;
}

/**
 * This page must not be cross-origin isolated: an isolated page in Firefox
 * cannot frame YouTube. But the site's other pages register
 * ../coi-serviceworker.js, whose scope is the whole site, and a visitor who
 * has been to one of them gets this page through it, isolated (seen
 * 2026-10-03: Firefox, the video window empty, a popup blocked). The worker
 * now lets /course/ through; a visitor still holding the old one has it
 * updated here, and the page reloads once. True: a reload is on its way.
 */
async function leaveIsolation() {
  if (!globalThis.crossOriginIsolated || !navigator.serviceWorker?.controller) return false;
  try {
    if (sessionStorage.getItem('course.unisolate')) return false;   // tried once this tab: go on as we are
    sessionStorage.setItem('course.unisolate', '1');
    const reg = await navigator.serviceWorker.getRegistration();
    if (!reg) return false;
    await reg.update();
    const next = reg.installing ?? reg.waiting;
    if (next) {
      await new Promise(resolve => {
        next.addEventListener('statechange', () => { if (next.state === 'activated') resolve(); });
        setTimeout(resolve, 3000);
      });
    }
    log.info('page', 'served isolated by an old service worker: updated it, reloading once');
    location.reload();
    return true;
  } catch {
    return false;
  }
}

/**
 * NOTHING ON DRIVE A: IS DELETED BECAUSE DOS SEEMS TO HAVE LOST IT.
 *
 * OWLOSUI's DriveGates keeps the floppy folders and DOS in step both ways,
 * and a file it knew of that DOS no longer shows it takes for deleted by DOS,
 * and removes from this browser's storage. On 2026-10-04 that removed 328 of
 * the course disk's 334 files - everything but the lesson the page had just
 * written - after the page wrote to A: while OWL FLY III had been running a
 * long while: DOS was shown a folder it did not have whole, and the storage
 * followed it. A: holds the student's work. So a removal that comes from
 * that mirroring (storage.hush) is refused under A: and said in the log; the
 * page's own removals (a stale BUILD.TXT) still happen. The price: a file
 * DEL'd inside DOS comes back at the next switch-on. The fix belongs in
 * OWLOSUI's DriveGates; this guard stays until it is there.
 */
/**
 * DOS's picture STRETCHED in a big window. The course keeps OWLOSUI's 'sharp'
 * picture - whole multiples of DOS's pixels, so text stays exact - and sizes
 * the DOS window to a whole multiple too. But zoomed to the whole screen, a
 * lesson's notebook (640 by 480) fits once: a postcard in a black field (the
 * pilot, 2026-10-05). So when the whole multiple would leave more than half
 * the window black, the picture fills it instead, at the frame's own shape.
 * The library's box is left as it is; only this instance's sum is wrapped.
 */
function stretchWhenBig(box, big = () => false) {
  const sharp = box.pictureRect.bind(box);
  box.pictureRect = area => {
    const s = sharp(area);
    if (box.picture !== 'sharp') return s;
    if (!big() && s.w * s.h >= area.w * area.h / 2) return s;
    const { w: fw, h: fh } = box.frameSize;
    const f = Math.min(area.w / fw, area.h / fh);
    return { x: area.x + (area.w - fw * f) / 2, y: area.y + (area.h - fh * f) / 2, w: fw * f, h: fh * f };
  };
}

function guardTheDisk(storage) {
  const remove = storage.remove.bind(storage);
  storage.remove = path => {
    if (storage.quiet > 0 && path.startsWith(A)) {
      log.warn('files', `kept ${path}: the DOS PC no longer shows it, but nothing on A: is deleted that way`);
      return Promise.resolve();
    }
    return remove(path);
  };
}

export class CourseApp {
  constructor(owl) {
    this.owl = owl;
    watchWindows(owl);
    courseSettings();
    this.browser = new BrowserStorage();
    guardTheDisk(this.browser);
    // Files in editors: New, Open, Save, Save as - placed where the layout
    // puts the source.
    this.documents = new Documents(owl, {
      places: [{
        label: "~T~his browser's storage...", source: this.browser,
        hint: 'Files this browser keeps for this page; its folder DOS A Drive is drive A: of the DOS PC',
        saveHint: 'Under a name and in a folder you choose - a copy on A: builds with F9 under its own name',
      }],
      defaultSource: this.browser, closeCmd: Cm.Close,
      place: () => this.layout().editor,
    });
    // Two panels over this browser's storage. Enter on an .ASM assembles it
    // and runs it; on a .COM or .EXE runs it, at the lessons' speed.
    this.commander = new CommanderTool(owl, {
      sources: [this.browser], closeCmd: Cm.Close,
      open: (name, text, source, path, options) => this.documents.add(name, text, source, path, options),
      quietKeys: [{ cmd: Cm.Lessons, key: 'F1' }, { cmd: Cm.Close, key: 'F3', alt: true }, { cmd: Cm.Exit, key: 'x', alt: true }],
      run: (source, dir, name) => this.runFile(source, dir, name),
      associations: { ...ASSOCIATIONS, asm: ({ source, dir, name }) => this.buildFile(source, dir, name) },
    });
    // The DOS PC (OWLOSUI's DosTool - a DOS PC and nothing more): C: with the
    // toolkit, A: and B: the browser's floppy folders, and the games -
    // unpacked onto C:\GAMES once their bundles' names are read (start()).
    // It starts into OUR DOS commander, A:\TOOLS\COMMANDR on the course disk
    // (a copy of an OWLOSUI example - see its README), and a lesson's
    // program, run from the page, gives way to it when it ends.
    this.dos = new DosTool(owl, {
      storage: this.browser, commander: this.commander,
      open: (name, text, source, path, options) => this.documents.add(name, text, source, path, options),
      dosFiles: new URL('../owlosui/dos/', import.meta.url),
      settingsKey: SETTINGS_KEY, network: { relay: RELAY, room: 'owlfly3' },
      starts: {
        commander: { name: 'the commander', label: '~C~ommander on DOS', reread: true, line: 'call C:\\COMMANDR.BAT',
          hint: 'The DOS file manager: the course disk A: on the left, C: on the right. Enter runs a program, F4 edits' },
        ...Object.fromEntries(GAMES.map(g => [g.key, {
          name: g.name, label: g.label, hint: g.hint, network: !!g.room,
          line: `call C:\\${g.dir}.BAT\ncall C:\\COMMANDR.BAT`,
        }])),
      },
      start: 'commander', returnTo: 'commander',
      written: {
        'C/COMMANDR.BAT': COMMANDR_BAT,
        ...Object.fromEntries(GAMES.map(g => [`C/${g.dir}.BAT`, `@echo off\ncd \\GAMES\\${g.dir}\n${g.exe}\ncd \\\n`])),
      },
    });
    this.dos.box.on(what => { if (what === 'crashed') this.showBuild(CRASHED); });
    stretchWhenBig(this.dos.box, () => this.dosBig);
    this.console = new ConsoleWindow(owl, { state: async () => this.state() });
    this.course = null;
    this.lesson = null;
    this.list = new LessonsWindow(this);
    this.buildWin = 0;
    this.video = null;
    this.box = 0;
    log.info('page', `the core is running: ${owl.width}x${owl.height} cells`);

    owl.menuBar(
      sub('~F~ile',
        ...this.documents.fileMenu(),
        line(),
        { label: 'E~x~it', cmd: Cm.Exit, shortcut: 'Alt+X', hint: 'Leave the course' }),
      sub('~L~essons',
        { label: '~L~essons...', cmd: Cm.Lessons, shortcut: 'F1', hint: 'Every lesson of the course, its video and its source' },
        line(),
        { label: '~B~uild and run', cmd: Cm.Build, shortcut: 'F9', hint: 'Save, assemble the .ASM in front with FASM on the DOS PC, and run what it made' },
        { label: '~R~un', cmd: Cm.Run, shortcut: 'Ctrl+F9', hint: 'Run it again as it was last built' },
        { label: '~W~atch the video', cmd: Cm.Watch, hint: 'The lesson on YouTube, in a window of its own' },
        line(),
        { label: 'Re~s~et this lesson', cmd: Cm.Reset, hint: "The lesson's files as the course ships them - your changes go" }),
      sub('~T~ools',
        { label: 'Co~m~mander', cmd: Cm.Commander, hint: "Two panels over this browser's storage - DOS A Drive is A:. Enter on an .ASM builds and runs it" },
        { label: 'C~o~nsole', cmd: Cm.Console, hint: 'Everything the page and the DOS PC did since it opened - for a bug report' }),
      sub('~D~OS', ...this.dos.menu()),
      sub('~W~indow',
        { label: '~S~ize/Move', cmd: Cm.SizeMove, shortcut: 'Ctrl+F5' },
        { label: '~Z~oom', cmd: Cm.Zoom, shortcut: 'F5' },
        { label: 'Mi~n~imize', cmd: Cm.Minimize },
        { label: '~N~ext', cmd: Cm.Next, shortcut: 'F6' },
        { label: '~P~revious', cmd: Cm.Previous, shortcut: 'Shift+F6' },
        { label: '~C~lose', cmd: Cm.Close, shortcut: 'Alt+F3' },
        { label: '~L~ist...', cmd: Cm.List, shortcut: 'Alt+0' },
        line(),
        { label: 'C~a~scade', cmd: Cm.Cascade },
        { label: '~T~ile', cmd: Cm.Tile }),
      sub('~H~elp', { label: '~A~bout', cmd: Cm.About, hint: 'What this page is' }),
    );
    owl.statusLine(
      { label: '~F1~ Lessons', cmd: Cm.Lessons, key: 'F1' },
      { label: '~F2~ Save', cmd: DocCm.Save, key: 'F2' },
      { label: '~F9~ Build+run', cmd: Cm.Build, key: 'F9' },
      { label: '~Ctrl-F9~ Run', cmd: Cm.Run, key: 'F9', ctrl: true },
      { label: '~F5~ Zoom', cmd: Cm.Zoom, key: 'F5' },
      { label: '~Alt-F3~ Close', cmd: Cm.Close, key: 'F3', alt: true },
      { label: '~Alt-X~ Exit', cmd: Cm.Exit, key: 'x', alt: true },
    );

    // F9 and Ctrl+F9 belong to the course even while DOS has the keyboard:
    // caught on the way down, before the emulator's element, the way the
    // DOS PC catches Right Ctrl. While the page has the keys, the status
    // line answers them as usual. A lesson program never sees F9 - every
    // build switches the PC off and on anyway.
    if (typeof window !== 'undefined') {
      window.addEventListener('keydown', e => {
        if (e.key !== 'F9' || !this.dos.box.hasKeys()) return;
        e.preventDefault();
        e.stopImmediatePropagation();
        this.dos.box.release();
        this.onCommand(e.ctrlKey ? Cm.Run : Cm.Build);
      }, true);
    }
  }

  /** The editors, by window: { text, source, path, name, crlf, binary }. */
  get docs() { return this.documents.docs; }

  /** Console > F4: what the course is doing now, a line each. */
  state() {
    const d = this.dos;
    return [
      `course: lesson ${this.lesson?.id ?? 'none'}, builds ${this.lastTarget ? `${this.lastTarget.dir}${this.lastTarget.asm}` : 'its own program'}`,
      `dos: ${d.box.running ? `on, running ${d.program?.name ?? d.started}` : 'off'}${d.box.crashed ? ', CRASHED' : ''}, picture ${d.settings.picture}, cycles ${d.settings.cycles}`,
      `editors: ${[...this.docs.values()].map(x => x.path ?? x.name).join(', ') || 'none'}`,
    ];
  }

  // ------------------------------------------------------------ the desktop

  /**
   * Where the four windows of a lesson go, in cells. The left column: the
   * DOS PC on top, its inside as near 4:3 in pixels as the cells allow, and
   * the lesson's video under it. The right column: the source, and under it
   * a strip with FASM's words. Nothing overlaps; why this way round, below.
   */
  layout() {
    const W = this.owl.width, H = this.owl.height;
    // A screen too small for four windows side by side - a phone, or a
    // hidden pane whose canvas shrank - gets them one over another, each
    // as big as the screen.
    if (W < 80 || H < 20) {
      const all = { x: 0, y: 1, w: Math.max(W, 12), h: Math.max(H - 2, 4) };
      return { editor: all, dos: all, build: all, video: all };
    }
    const D = H - 2;                                 // the desktop's rows
    // The DOS PC's inside, made to hold DOS's 640x400 at a whole scale -
    // DosBox.insideFor, as OWLOSUI's own DOS window sizes itself: text and
    // pixels exact, 320x200 graphics at x2. Forty columns are kept for the
    // editor, and eight rows under it for the video.
    const fit = DosBox.insideFor(this.owl, W - 40 - 2, D - 2 - 8);
    const R = Math.max(30, fit.w + 2);
    const ih = fit.h;
    const B = 6;                                     // FASM says two lines; room for an error's three
    // Every window has its shadow, two columns to the right and a row below.
    // So the DOS PC and the video are on the LEFT and the source on the
    // RIGHT (the pilot's idea, 2026-10-03): the editor's shadow falls off
    // the screen, never on the video - a shadow over the video counts as
    // covering it, and the video was hidden while the editor was in front -
    // and the left column's shadows fall on the editor, which does not mind.
    // DOS's shadow may fall on the video's title - it does not hide the
    // video, and the pilot likes the look (2026-10-03). One row is left under
    // the editor, so its shadow keeps off the Build strip's title.
    return {
      dos: { x: 0, y: 1, w: R, h: ih + 2 },
      video: { x: 0, y: 1 + ih + 2, w: R, h: D - (ih + 2) },
      editor: { x: R, y: 1, w: W - R, h: D - B - 1 },
      build: { x: R, y: 1 + D - B, w: W - R, h: B },
    };
  }

  /** The DOS PC's window where the layout puts it; moved only by opening it again, so only when it is elsewhere. */
  placeDos() {
    const r = this.layout().dos;
    this.dosBig = false;
    const p = this.dos.win ? this.owl.place(this.dos.win) : null;
    if (!p || p.x !== r.x + 1 || p.y !== r.y + 1 || p.w !== r.w - 2 || p.h !== r.h - 2) this.dos.openWindow(r);
  }

  /**
   * F5 on the DOS PC: as big as the screen allows AT THE PICTURE'S OWN
   * SHAPE, centred, and the picture stretched to fill it - and F5 again puts
   * it back in the layout. A plain zoom made the window the whole desktop,
   * two and a fifth to one, and a 320 by 200 game or a 640 by 480 notebook
   * sat in it between two black fields (the pilot chose this, 2026-10-05).
   * The shape is the frame's when F5 is pressed: a mode change later keeps
   * the window and fits the new frame into it.
   */
  zoomDos() {
    const owl = this.owl, box = this.dos.box;
    if (this.dosBig) {
      this.placeDos();
    } else {
      const W = owl.width, H = owl.height;
      const { cellW = 10, cellH = 22 } = owl.screen ?? {};
      const { w: fw, h: fh } = box.frameSize;
      let ih = H - 2 - 2;                                // the desktop's rows, less the frame
      let iw = Math.round((ih * cellH * fw) / fh / cellW);
      if (iw > W - 2) {                                  // a tall, narrow screen: fit the width instead
        iw = W - 2;
        ih = Math.round((iw * cellW * fh) / fw / cellH);
      }
      this.dos.openWindow({ x: Math.floor((W - iw - 2) / 2), y: 1, w: iw + 2, h: ih + 2 });
      this.dosBig = true;
    }
    box.win = this.dos.win;                              // the picture follows the window it now lies over
    this.dos.retitle?.();                                // ...and its title says what runs, again
    box.layout();
  }


  tell(title, text) {
    this.closeBox();
    this.box = this.owl.messageBox(title, text, ['~O~K', Cm.Dismiss]);
  }

  closeBox() {
    if (this.box) this.owl.close(this.box);
    this.box = 0;
  }

  /** Work that finishes later: what goes wrong is said in a box, and a test can wait for it. */
  track(promise) {
    this.pending = promise.catch(e => { log.error('page', e.message); this.tell('Course', e.message); }).finally(() => this.owl.refresh?.());
    return this.pending;
  }

  /**
   * The page opens on the lesson its address names - ?l=7, the link under
   * every video since lecture 1 (it used to go to wbtest.html, which now
   * sends it here) - or, with none, on the list of lessons.
   */
  async start() {
    if (await leaveIsolation()) return;
    this.course = await (await fetch(new URL('course.json', import.meta.url))).json();
    log.info('course', `${this.course.lessons.length} lessons`);
    await this.findGames();
    await this.waitForScreen();
    await this.track(this.installDisk());
    const asked = lessonFromAddress(this.course.lessons);
    if (asked) { log.info('course', `the address asks for ${asked.id}`); await this.track(this.openLesson(asked)); }
    else this.list.show();
    this.owl.refresh?.();
    // ?tour=NAME: the page plays a script of its own features (tour.js), for
    // the video that presents it. Loaded only then.
    const tour = new URLSearchParams(globalThis.location?.search ?? '').get('tour');
    if (tour && /^[\w-]+$/.test(tour)) {
      const { Tour } = await import('./tour.js');
      this.tour = new Tour(this, tour);
      await this.track(this.tour.start());
    }
  }

  /**
   * Until the canvas has its size: a window opened in the first frames is
   * cut to the size the screen had then. Not from poll(), which runs only
   * when something happens - the list waited for a click.
   */
  waitForScreen() {
    return new Promise(resolve => {
      const t = setInterval(() => { if (this.owl.width >= 80) { clearInterval(t); resolve(); } }, 50);
    });
  }

  /** What is not a command: each tool looks at its own windows. */
  poll() {
    for (const t of this.tools()) t.poll?.();
  }

  /** Every tool, in the order a command is offered to them. */
  tools() { return [this.list, this.documents, this.commander, this.console, this.dos]; }

  // ------------------------------------------------------------ the lesson

  dir(lesson) { return `${A}LESSONS/${lesson.folder}/`; }

  /**
   * The course disk onto A:, once - the course as the repository holds it:
   * TOOLS, ENGINE, every lesson, the examples and the games, each with its
   * own MAKE.BAT. A file already on A: is left alone: it may be the
   * student's. A newer disk (its version in course.json) adds what is new.
   */
  async installDisk() {
    const disk = this.course?.disk;
    if (!disk) return;
    const S = this.browser;
    const had = await S.read(DISK_VERSION).catch(() => '');
    if (had.trim() === disk.version) return;
    this.showBuild(`Putting the course disk on drive A: - ${disk.files} files, the lessons, the examples and the games...`);
    const files = await courseDisk(disk.url);
    let added = 0;
    await S.hush(async () => {
      for (const f of files) {
        const to = `${A}${f.path}`;
        const there = await S.readBytes(to).then(() => true, () => false);
        if (!there) { await S.write(to, f.contents); added++; }
      }
    });
    await S.write(DISK_VERSION, `${disk.version}\r\n`);
    log.info('course', `course disk ${disk.version}: ${added} of ${files.length} files put on A:`);
    this.showBuild(`Drive A: holds the course: LESSONS, EXAMPLES, GAMES, ENGINE and TOOLS - ${added} files new. ` +
      'Tools > Commander shows them; MAKE.BAT in any folder builds what is there.');
  }

  /** A lesson's own files as the course ships them - Lessons > Reset - over what is on A:. */
  async install(lesson, fresh = false) {
    if (fresh) {
      const prefix = `LESSONS/${lesson.folder}/`;
      for (const f of (await courseDisk(this.course.disk.url)).filter(f => f.path.startsWith(prefix))) {
        await this.browser.write(`${A}${f.path}`, f.contents);
      }
    }
    await this.batches({ dir: this.dir(lesson), asm: lesson.main });
  }

  /**
   * The build and the run of one source, as batch files beside it on A: -
   * so they are also there to type. The PC switches on at full speed, for
   * FASM; GO.BAT slows it to the machine the lessons were made on before
   * the program starts, and waits for a key after it: a program that
   * prints and ends (lesson 2's HELLO) would otherwise be gone at once,
   * the DOS commander drawn over its words.
   */
  async batches({ dir, asm }) {
    const com = asm.replace(/\.ASM$/i, '.COM');
    await this.browser.write(`${dir}BUILD.BAT`, [
      '@echo off',
      `if exist ${com} del ${com}`,
      'A:\\TOOLS\\CWSDPMI\\CWSDPMI.EXE',
      `A:\\TOOLS\\FASM\\FASM.EXE -m ${FASM_KB} ${asm} ${com} > BUILD.TXT`,
      `if not exist ${com} goto end`,
      'call GO.BAT',
      ':end', ''].join('\r\n'));
    await this.browser.write(`${dir}GO.BAT`, [
      '@echo off',
      `config -set "cpu cycles=fixed ${LESSON_CYCLES}"`,
      com,
      'pause', ''].join('\r\n'));
  }

  /**
   * What F9 builds: the .ASM in the editor in front, under its own name and
   * in its own folder - so a copy saved as MY.ASM builds as MY.COM. With no
   * .ASM in front (an .INC, the video), what was built last; failing that,
   * the lesson's own program. Only a file on a floppy can be built: DOS
   * sees nothing else.
   */
  target() {
    const doc = this.docs.get(this.owl.active());
    if (doc?.path?.startsWith(A) && /\.ASM$/i.test(doc.name)) {
      return { dir: doc.path.slice(0, doc.path.lastIndexOf('/') + 1), asm: doc.name.toUpperCase() };
    }
    if (this.lastTarget) return this.lastTarget;
    return this.lesson?.buildable ? { dir: this.dir(this.lesson), asm: this.lesson.main } : null;
  }

  /**
   * A lesson opens whole, as the pilot drew it: its source on the left, its
   * video on the right waiting for a click, and the DOS PC above the video
   * building the source and running it - what the lesson makes is on the
   * screen before a key is pressed.
   */
  async openLesson(lesson) {
    this.lesson = lesson;
    this.lastTarget = null;      // a new lesson builds its own program until told otherwise
    // The address follows: a reload, or a link copied from the bar, lands here.
    try { history.replaceState(null, '', `?l=${lesson.id.slice(1).replace(/^0/, '').toLowerCase()}`); } catch { /* not a page */ }
    // The video first: every lesson has one, a program or not. It waits
    // for a click - the program beside it may have a voice of its own.
    if (lesson.video && this.video?.lesson !== lesson.id) this.watch(lesson, 0, { autoplay: false });
    if (!lesson.buildable) {
      this.tell(`Lesson ${lesson.id}`, `${lesson.title}. This lesson has no 8086 source to build here` +
        (lesson.id === 'L01' ? ' - it is written in C.' : '.') + ' Its video is on the right.');
      return;
    }
    await this.install(lesson);
    const path = `${this.dir(lesson)}${lesson.main}`;
    // One editor per lesson: a second Open brings the first one to the front.
    // Any size: the client sends a text over 64 KB in parts and reads it
    // back the same way (TEXT_APPEND, GET_TEXT_PART), so HOUSES.ASM's
    // 188 KB opens and saves whole.
    const open = [...this.docs].find(([, d]) => d.path === path);
    if (open) this.owl.activate(open[0]);
    else this.documents.add(lesson.main, await this.browser.read(path), this.browser, path);
    await this.build();
  }

  /**
   * Every open file back where it came from in this browser, without a box
   * saying so: what F9 builds may include what another window holds.
   */
  async saveQuietly() {
    for (const [, d] of this.docs) {
      if (d.source !== this.browser || !d.path) continue;
      await this.browser.write(d.path, this.documents.contentOf(d));
    }
  }

  /**
   * Enter on an .ASM in the commander: assembled and run, like F9 on it.
   * Only a file on a floppy can be: DOS sees nothing else.
   */
  buildFile(source, dir, name) {
    if (source !== this.browser || !dir.startsWith(A)) {
      this.tell('Build', `${name} is not on drive A:, so the DOS PC cannot see it. Copy it into DOS A Drive (F5) and press Enter on it there.`);
      return null;
    }
    return this.build({ dir, asm: name.toUpperCase() });
  }

  /**
   * The DOS PC switched on into `name` in `dir` - after the floppy has
   * caught up. A file the page has just written reaches a running DOS a
   * moment later (DriveGates, in OWLOSUI's library), and switching on first
   * collects what DOS holds and forgets what it lacks: a BUILD.BAT written
   * the instant before was taken for deleted, and DOS said "Illegal command:
   * BUILD.BAT" (seen 2026-10-04). So: a breath first, while DOS still runs.
   */
  async runDos(source, dir, name) {
    if (this.dos.box.running) await new Promise(r => setTimeout(r, 800));
    return this.dos.runProgram(source, dir, name);
  }

  /**
   * A game is built the way it is built: by its own MAKE.BAT, from its own
   * folder - several assemblies, data files and an .EXE, not one source.
   * The game folder of `dir` (A:\GAMES\OWLFLY3\SRC\ -> A:\GAMES\OWLFLY3\),
   * or null outside GAMES.
   */
  gameOf(dir) {
    const m = /^\/DOS A Drive\/GAMES\/[^/]+\//i.exec(dir);
    return m ? m[0] : null;
  }

  /**
   * Enter on a .COM, .EXE or .BAT in the commander. A lesson's or an
   * example's program runs at the lessons' speed, through a GO.BAT beside
   * it, as Ctrl+F9 runs one; a game, and anything else, as the DOS PC runs
   * any program - at full speed, as on its own page.
   */
  async runFile(source, dir, name) {
    this.builds = (this.builds ?? 0) + 1;      // a build waiting for FASM stops waiting
    this.placeDos();
    if (source === this.browser && /^\/DOS A Drive\/(LESSONS|EXAMPLES)\//i.test(dir) && /\.(COM|EXE)$/i.test(name)) {
      await this.browser.write(`${dir}GO.BAT`, ['@echo off', `config -set "cpu cycles=fixed ${LESSON_CYCLES}"`, name.toUpperCase(), 'pause', ''].join('\r\n'));
      return this.runDos(this.browser, dir, 'GO.BAT');
    }
    return this.runDos(source, dir, name);
  }

  async build(t = this.target()) {
    if (!t) { this.list.show(); return; }
    const game = this.gameOf(t.dir);
    if (game) {
      // A game's source: its own MAKE.BAT builds it (into INSTALL\), as in
      // the repository; RUN.BAT beside it flies what was built.
      await this.saveQuietly();
      this.builds = (this.builds ?? 0) + 1;
      this.showBuild(`Building ${game.slice(A.length, -1).replace(/\//g, '\\')} with its own MAKE.BAT - its words are on the DOS screen; ` +
        'RUN.BAT in the same folder flies it.');
      this.placeDos();
      // Through a BUILD.BAT that waits for a key after MAKE.BAT: otherwise
      // DOS goes straight back to its commander, and MAKE's last words -
      // "Built INSTALL\OWLFLY3.EXE" - are gone before they can be read.
      await this.browser.write(`${game}BUILD.BAT`, ['@echo off', 'call MAKE.BAT', 'pause', ''].join('\r\n'));
      return this.runDos(this.browser, game, 'BUILD.BAT');
    }
    await this.saveQuietly();
    if (this.lesson?.buildable) await this.install(this.lesson);
    await this.batches(t);
    this.lastTarget = t;
    const out = `${t.dir}BUILD.TXT`;
    await this.browser.remove(out).catch(() => {});
    // A newer F9 takes over: the older build stops waiting for its answer.
    const mine = this.builds = (this.builds ?? 0) + 1;
    this.showBuild(`Assembling ${t.asm} on the DOS PC...`);
    log.info('build', `${t.dir}${t.asm}: FASM -m ${FASM_KB}`);
    this.placeDos();
    // The PC switches on into BUILD.BAT; when the program ends, DOS goes on
    // into its commander - the student is at a real DOS, not a prompt.
    await this.runDos(this.browser, t.dir, 'BUILD.BAT');
    // DOS writes BUILD.TXT on A:, and the floppy's folder gets it back
    // within a second or two. FASM's last line says how it went.
    for (let i = 0; i < 120; i++) {
      await new Promise(r => setTimeout(r, 1000));
      if (mine !== this.builds) return;
      if (this.dos.box.crashed) { this.showBuild(CRASHED); return; }
      const text = await this.browser.read(out).catch(() => '');
      if (/bytes\.|error/i.test(text)) {
        const lines = text.trim().split(/\r?\n/);
        for (const l of lines) log.info('build', l);
        // What to press next.
        lines.push('F9 saves, builds and runs again; Ctrl+F9 only runs; Right Ctrl takes the keys back from DOS.');
        this.showBuild(lines.join('\n'));
        return;
      }
    }
    this.showBuild("No word from FASM in two minutes. The browser's console (F12) says what the DOS PC did.");
  }

  /**
   * The games' bundles onto C:\GAMES - each named by its own page, which
   * pack.ps1 keeps current. Before the PC's first switch-on: C: is put
   * together once and kept. A game whose page cannot be read is left out.
   */
  async findGames() {
    const bundles = [];
    for (const g of GAMES) {
      try {
        const name = g.bundle.exec(await (await fetch(new URL(`../${g.page}`, import.meta.url))).text())?.[0];
        if (name) bundles.push({ url: new URL(`../${name}`, import.meta.url).href, to: `GAMES/${g.dir}` });
        else log.warn('course', `${g.page} names no bundle: ${g.name} is not on C:`);
      } catch (e) {
        log.warn('course', `${g.page} did not load: ${g.name} is not on C:`);
      }
    }
    this.dos.bundles = bundles;
  }

  async runOnly() {
    const t = this.target();
    if (!t) { this.list.show(); return; }
    await this.batches(t);
    this.placeDos();
    return this.runDos(this.browser, t.dir, 'GO.BAT');
  }

  showBuild(text) {
    const owl = this.owl;
    if (!this.buildWin) {
      const r = this.layout().build;
      this.buildWin = owl.window('Build', r.w, r.h, { x: r.x, y: r.y, style: Style.Dialog, closeCmd: Cm.BuildClose });
      this.buildText = owl.staticText(this.buildWin, 1, 1, '', r.w - 4, r.h - 3);
    }
    owl.setText(this.buildText, text);
    // For the tour (tour.js, waitbuild): builds started, and the last one answered.
    this.lastBuildShown = text;
    if (/^Assembling/.test(text)) this.buildsStarted = (this.buildsStarted ?? 0) + 1;
    else if (/bytes\.|error|crashed/i.test(text)) this.buildsAnswered = this.buildsStarted ?? 0;
    owl.refresh?.();
  }

  // ------------------------------------------------------------ the video

  /**
   * The lesson's video in a window of our own, as the DOS PC's picture is:
   * a YouTube frame laid over the window's inside after every paint, so it
   * goes where the window goes - dragged by its title, Ctrl+F5, F5 - and
   * hidden while a menu or another window is over it.
   */
  watch(lesson = this.lesson, at = 0, { autoplay = true } = {}) {
    if (!lesson?.video) { this.list.show(); return; }
    // A plain frame, in every browser - because this page is NOT
    // cross-origin isolated. An isolated one (what OWLOSUI's demo makes
    // with its service worker) frames YouTube only with `credentialless`,
    // which Firefox and Safari do not have. js-dos does not need the
    // isolation: without SharedArrayBuffer it built HOUSES.ASM and ran it.
    // If the page is isolated all the same (leaveIsolation could not undo an
    // old service worker), the attribute keeps Chromium working; elsewhere
    // the window holds a LINK to the video - a click the reader makes, which
    // no browser blocks, where window.open from here was blocked as a popup.
    const framed = !crossOriginIsolated || 'credentialless' in HTMLIFrameElement.prototype;
    this.closeVideo();
    const owl = this.owl;
    // Under the DOS PC; YouTube letterboxes itself into whatever shape it gets.
    const r = this.layout().video;
    const title = `${lesson.id}${lesson.lecture ? ` - lecture ${lesson.lecture}` : ''}`;
    // Black, frame and all (Style.Terminal): the video is black round its
    // picture, and a blue frame round black looked like a hole.
    const win = owl.window(title, r.w, r.h, { x: r.x, y: r.y, style: Style.Terminal, closeCmd: Cm.VideoClose });
    let f;
    if (framed) {
      f = document.createElement('iframe');
      if (crossOriginIsolated) f.setAttribute('credentialless', '');
      f.allow = 'autoplay; encrypted-media; fullscreen';
      f.allowFullscreen = true;
      f.src = `https://www.youtube.com/embed/${lesson.video}?start=${at}&autoplay=${autoplay ? 1 : 0}`;
    } else {
      f = document.createElement('a');
      f.href = `https://www.youtube.com/watch?v=${lesson.video}&t=${at}s`;
      f.target = '_blank';
      f.rel = 'noopener';
      f.textContent = `▶  ${lesson.title}${lesson.lecture ? ` - lecture ${lesson.lecture}` : ''} - on YouTube`;
      f.style.cssText = 'display:flex;align-items:center;justify-content:center;text-align:center;padding:1em;box-sizing:border-box;' +
        'color:#fff;font:16px monospace;text-decoration:none';
    }
    f.style.cssText += ';position:fixed;z-index:5;border:0;background:#000;visibility:hidden';
    document.body.append(f);
    // A frame keeps every mouse event that lands on it, and the page never
    // hears the button come up: a window dragged across the video would
    // stick to the mouse. While a button is down outside the frame, the
    // frame lets the mouse through.
    const down = e => { if (e.target !== f) f.style.pointerEvents = 'none'; };
    const up = () => { f.style.pointerEvents = ''; };
    window.addEventListener('pointerdown', down, true);
    window.addEventListener('pointerup', up, true);
    const lay = () => this.layVideo();
    owl.afterPaint?.add(lay);
    this.video = { win, frame: f, lay, down, up, lesson: lesson.id };
    this.layVideo();
    owl.refresh?.();
  }

  /** Over the video window's inside while nothing covers it; gone with the window. */
  layVideo() {
    const v = this.video;
    if (!v) return;
    const p = this.owl.place(v.win);
    const { cellW, cellH, canvas } = this.owl.screen ?? {};
    if (!p) { this.closeVideo(); return; }        // the window went some other way
    if (!canvas) return;
    const box = canvas.getBoundingClientRect();
    Object.assign(v.frame.style, {
      left: `${box.left + p.x * cellW}px`, top: `${box.top + p.y * cellH}px`,
      width: `${p.w * cellW}px`, height: `${p.h * cellH}px`,
      visibility: p.covered ? 'hidden' : 'visible',
    });
  }

  closeVideo() {
    const v = this.video;
    if (!v) return;
    this.video = null;
    this.owl.afterPaint?.delete(v.lay);
    window.removeEventListener('pointerdown', v.down, true);
    window.removeEventListener('pointerup', v.up, true);
    v.frame.remove();
    if (this.owl.place(v.win)) this.owl.close(v.win);
  }

  // ------------------------------------------------------------ commands

  /** Every command of the page; false ends it (Alt+X). */
  onCommand(cmd) {
    const owl = this.owl;
    switch (cmd) {
      case Cm.Exit: return false;
      case Cm.Dismiss: this.closeBox(); return true;
      case Cm.Lessons: this.list.show(); return true;
      case Cm.Commander: {
        // The lesson's folder on the left, the whole of A: on the right.
        const left = this.lesson ? this.dir(this.lesson) : A;
        this.commander.show({ left: this.browser, right: this.browser, leftDir: left, rightDir: A });
        return true;
      }
      case Cm.Console: this.console.show(); return true;
      case Cm.Next: owl.nextWindow(); return true;
      case Cm.Previous: owl.previousWindow(); return true;
      case Cm.Zoom: {
        const a = owl.active();
        if (a && a === this.dos.win && this.dos.box.running) this.zoomDos();
        else if (a) owl.zoom(a);
        return true;
      }
      case Cm.Minimize: { const a = owl.active(); if (a) owl.minimize(a); return true; }
      case Cm.Close: this.closeActive(); return true;
      case Cm.Cascade: owl.cascade(); return true;
      case Cm.Tile: owl.tile(); return true;
      case Cm.List: owl.windowList(); return true;
      case Cm.SizeMove: owl.sizeMove(); return true;
      case Cm.Build: this.track(this.build()); return true;
      case Cm.Run: this.track(Promise.resolve(this.runOnly())); return true;
      case Cm.Watch: this.watch(); return true;
      case Cm.VideoClose: this.closeVideo(); return true;
      case Cm.Reset:
        if (this.lesson?.buildable) {
          this.track(this.install(this.lesson, true).then(() =>
            this.tell('Reset', `${this.lesson.id} is on drive A: as the course ships it. Close its editor and open it again.`)));
        }
        return true;
      case Cm.BuildClose:
        if (this.buildWin) this.owl.close(this.buildWin);
        this.buildWin = 0;
        return true;
      case Cm.About:
        this.tell('The 8086 course', 'Every lesson of "Writing a DOS game from scratch": its video, its source in an editor that ' +
          'colours assembler, and a DOS PC in the page that assembles it with FASM and runs it. The page is OWLOSUI - a Rust core ' +
          'in WebAssembly - and the DOS PC is DOSBox, also in WebAssembly.');
        return true;
      default: {
        // A game on the DOS menu: its own sky. The DOS PC has one room for
        // its network card; a game's room goes in before it switches on, so
        // OWL FLY II meets the players on its own page, not III's.
        const game = this.dos.pageStarts?.[cmd - DosCm.Start] && GAMES.find(g => g.key === this.dos.pageStarts[cmd - DosCm.Start]);
        if (game) {
          if (game.room) this.dos.settings = { ...this.dos.settings, room: game.room };
          this.builds = (this.builds ?? 0) + 1;     // a build waiting for FASM stops waiting
          this.placeDos();
        }
        // Whoever owns the command: the Lessons window, the editors, the
        // commander, the console, the DOS PC.
        for (const t of this.tools()) if (t.handles(cmd)) { this.track(Promise.resolve(t.onCommand(cmd))); break; }
        return true;
      }
    }
  }

  /** The front window is being closed: whoever owns it forgets it. */
  closeActive() {
    const a = this.owl.active();
    if (!a) return;
    if (this.list.owns(a)) { this.list.close(); return; }
    if (a === this.buildWin) { this.owl.close(a); this.buildWin = 0; return; }
    if (a === this.video?.win) { this.closeVideo(); return; }
    if (a === this.box) { this.closeBox(); return; }
    for (const t of [this.documents, this.commander, this.console, this.dos]) {
      if (t.owns(a)) { this.track(Promise.resolve(t.closeWindow(a))); return; }
    }
    this.owl.close(a);
  }
}

// ------------------------------------------------------------------ Lessons

class LessonsWindow {
  constructor(app) {
    this.app = app;
    this.owl = app.owl;
    this.win = 0;
    this.shown = -1;
  }

  handles(cmd) { return cmd >= Cm.Open && cmd <= Cm.ListClose; }
  owns(id) { return id !== 0 && id === this.win; }

  label(l) {
    // The folder, not the lecture: the first lectures are numbered in
    // decimal and the later in hex, so "lecture 10" is two of them.
    return `${l.id}  ${l.title}`.slice(0, 44);
  }

  show() {
    const owl = this.owl, lessons = this.app.course?.lessons ?? [];
    if (this.win) { owl.activate(this.win); return; }
    const w = Math.min(78, owl.width), h = Math.min(22, owl.height - 2);
    this.win = owl.window('Lessons', w, h, { style: Style.Dialog, closeCmd: Cm.ListClose });
    this.list = owl.list(this.win, 2, 1, 46, h - 6, lessons.map(l => this.label(l)));
    this.about = owl.staticText(this.win, 50, 1, '', w - 54, h - 6);
    owl.buttons(this.win, { label: '~O~pen', cmd: Cm.Open, default: true }, { label: '~W~atch', cmd: Cm.ListWatch },
      { label: 'Close', cmd: Cm.ListClose, cancel: true });
    this.shown = -1;
    this.poll();
  }

  current() { return this.app.course?.lessons[this.owl.current(this.list)]; }

  poll() {
    if (!this.win) return;
    const i = this.owl.current(this.list);
    if (i === this.shown) return;
    this.shown = i;
    const l = this.app.course?.lessons[i];
    if (!l) return;
    const parts = [l.title + (l.lecture ? ` (lecture ${l.lecture})` : ''), '', l.about || '(no notes for this one)', ''];
    if (l.video) parts.push(`Video: ${l.length}.`);
    parts.push(l.buildable ? `Source: ${l.main}, ${Math.round(l.size / 1024)} KB.`
      : 'No 8086 source to build here.');
    this.owl.setText(this.about, parts.join('\n'));
  }

  onCommand(cmd) {
    const l = this.current();
    if (cmd === Cm.ListClose) return this.close();
    if (cmd === Cm.Open && l) { this.close(); return this.app.track(this.app.openLesson(l)); }
    if (cmd === Cm.ListWatch && l) { this.close(); return this.app.watch(l); }
    return null;
  }

  close() {
    if (this.win) this.owl.close(this.win);
    this.win = 0;
  }

}
