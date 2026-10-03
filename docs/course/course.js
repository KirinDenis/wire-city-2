// The 8086 course, in OWLOSUI. PROTOTYPE, 2026-10-02.
//
// A lesson opens whole: its source in an editor that colours assembler, its
// video, and a DOS PC that assembles the source with FASM and runs it.
//
//   Lessons   every lesson, its video and a few words on it; Open puts its
//             files on drive A: of the DOS PC, the source in the editor, and
//             builds and runs it
//   F9        save, build with FASM on the DOS PC, run - FASM's words in the
//             Build strip; Ctrl+F9 runs again without building
//   Watch     the lesson's video, in a window of its own
//
// Built on OWLOSUI's library alone - ../owlosui/, a copy of OWLOSUI's lib/js
// taken by ../pull-owlosui.ps1 (https://github.com/KirinDenis/OWLOSUI) -
// and nothing of its examples: the DOS PC is ./dos.js, the diary ./log.js.
//
// WHERE THE FILES GO. A:\LESSONS\Lnn\ the lesson's own files, A:\ENGINE\
// the five engine files (the sources say ..\..\ENGINE\, which from
// A:\LESSONS\Lnn\ is exactly there), B:\ FASM and CWSDPMI. Files already
// on A: are left alone - they may be yours - until Lessons > Reset.
//
// TWO THINGS FASM NEEDS IN THIS PC, both found by testing (wire-city-2/
// .claude/skills/owlosui-lessons/references/gaps.md, item 7): core=normal
// (dos.js), because a FASM macro kills js-dos's dynamic core, and
// FASM -m 4096, because FASM grabbing CWSDPMI's virtual memory kills it too.

import { sub, line, Style, Offer } from '../owlosui/owlosui.js';
import { BrowserStorage } from '../owlosui/files/browser.js';
import { CourseDos } from './dos.js';
import { log } from './log.js';

const Cm = {
  Exit: 2, Save: 3, About: 4, Dismiss: 5,
  Next: 30, Zoom: 31, Close: 32, Cascade: 33, Tile: 34, Previous: 35, List: 36, SizeMove: 37, Minimize: 38,
  Lessons: 600, Build: 601, Run: 602, Watch: 603, Reset: 604, Keys: 605, DosOff: 606,
  Open: 610, ListWatch: 611, ListClose: 612, BuildClose: 613, VideoClose: 614, DosClose: 615,
};
// What the page fetches for a lesson, copied into docs by ../pack-course.ps1:
// GitHub Pages serves docs/ alone.
const SITE = new URL('files/', import.meta.url);
const A = '/DOS A Drive/', B = '/DOS B Drive/';
// FASM's memory in KB; ?m=N on the page tries another (testing the crash).
const FASM_KB = Number(new URLSearchParams(globalThis.location?.search ?? '').get('m')) || 4096;
const TOOLS = [['FASM.EXE', 'TOOLS/FASM/FASM.EXE'], ['CWSDPMI.EXE', 'TOOLS/CWSDPMI/CWSDPMI.EXE']];
const ENGINE = ['E_8086.INC', 'E_MATH.INC', 'E_TERR.INC', 'E_M3D.INC', 'E_RAST.INC'];

/**
 * The speed every lesson runs at, set by GO.BAT with DOSBox's own
 * `config -set` after FASM has built at full speed: the machine the lessons
 * were made and measured on. On `auto`, real mode gets DOSBox's slow
 * default, and a lesson that wipes and redraws in one buffer (SQUARE,
 * lesson 10) is shown half-drawn - only its bottom rows ever appear
 * (measured 2026-10-02; whole at 30000).
 */
const LESSON_CYCLES = 30000;

/** What the Build strip says when js-dos dies under a lesson (dos.js). */
const CRASHED = 'The DOS PC crashed (js-dos: RuntimeError: unreachable) - it happens now and then, cause not found yet.\n' +
  'F9 builds again on a fresh machine.';

async function bytes(path) {
  const r = await fetch(new URL(path, SITE));
  if (!r.ok) throw new Error(`${path}: ${r.status}`);
  return new Uint8Array(await r.arrayBuffer());
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

export class CourseApp {
  constructor(owl) {
    this.owl = owl;
    this.browser = new BrowserStorage();
    this.dos = new CourseDos(owl, this.browser, { closeCmd: Cm.DosClose });
    this.dos.onCrash = () => this.showBuild(CRASHED);
    this.docs = new Map();            // editor window -> { text, source, path, name, crlf }
    this.box = 0;                     // the message box, while one is up
    this.course = null;
    this.lesson = null;
    this.list = new LessonsWindow(this);
    this.buildWin = 0;
    this.video = null;
    log.info('page', `the core is running: ${owl.width}x${owl.height} cells`);

    owl.menuBar(
      sub('~F~ile',
        { label: '~S~ave', cmd: Cm.Save, shortcut: 'F2', hint: 'The source in front, onto drive A:' },
        line(),
        { label: 'E~x~it', cmd: Cm.Exit, shortcut: 'Alt+X', hint: 'Leave the course' }),
      sub('~L~essons',
        { label: '~L~essons...', cmd: Cm.Lessons, shortcut: 'F1', hint: 'Every lesson of the course, its video and its source' },
        line(),
        { label: '~B~uild and run', cmd: Cm.Build, shortcut: 'F9', hint: 'Save, assemble with FASM on the DOS PC, and run what it made' },
        { label: '~R~un', cmd: Cm.Run, shortcut: 'Ctrl+F9', hint: 'Run the lesson as it was last built' },
        { label: '~W~atch the video', cmd: Cm.Watch, hint: 'The lesson on YouTube, in a window of its own' },
        line(),
        { label: 'Re~s~et this lesson', cmd: Cm.Reset, hint: "The lesson's files as the course ships them - your changes go" }),
      sub('~D~OS',
        { label: '~K~eyboard to DOS', cmd: Cm.Keys, hint: 'Or click the DOS picture; Right Ctrl gives it back' },
        { label: 'Switch ~o~ff', cmd: Cm.DosOff, hint: 'The DOS PC off and its window closed; F9 switches it on again' }),
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
      { label: '~F2~ Save', cmd: Cm.Save, key: 'F2' },
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
    const cw = this.owl.screen?.cellW ?? 10, ch = this.owl.screen?.cellH ?? 22;
    const R = Math.max(40, Math.min(W - 40, Math.floor(W * 0.45)));
    const D = H - 2;                                 // the desktop's rows
    let ih = Math.round(((R - 2) * cw * 3) / 4 / ch);
    ih = Math.min(ih, Math.floor(D * 0.55) - 2);     // the video keeps the rest, near half
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
    const p = this.dos.win ? this.owl.place(this.dos.win) : null;
    if (!p || p.x !== r.x + 1 || p.y !== r.y + 1 || p.w !== r.w - 2 || p.h !== r.h - 2) this.dos.openWindow(r);
  }

  /** An editor in the left column, coloured as its name says; `source` and `path` say where Save puts it. */
  addDoc(name, text, source, path, { readOnly = false } = {}) {
    const r = this.layout().editor;
    const w = this.owl.window(`${name} - ${source?.title ?? 'new'}`, r.w, r.h, { x: r.x, y: r.y, closeCmd: Cm.Close });
    // A DOS file ends its lines with CR LF; the editor wants LF alone, and
    // the CRs go back on when it is saved.
    const crlf = text.includes('\r\n');
    const t = this.owl.text(w, crlf ? text.replace(/\r\n/g, '\n') : text);
    this.owl.editor(t, Offer.All, { readOnly });
    this.owl.syntax(t, name);
    this.docs.set(w, { text: t, source, path, name, crlf });
    return w;
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
    const asked = lessonFromAddress(this.course.lessons);
    // Not at once: the first frames come before the canvas has its size,
    // and a window opened then is cut to the size it had. Nor from poll(),
    // which runs only when something happens - the list waited for a click.
    await new Promise(resolve => {
      const t = setInterval(() => { if (this.owl.width >= 80) { clearInterval(t); resolve(); } }, 50);
    });
    if (asked) { log.info('course', `the address asks for ${asked.id}`); await this.track(this.openLesson(asked)); }
    else this.list.show();
    this.owl.refresh?.();
  }

  poll() {
    this.list.poll();
  }

  // ------------------------------------------------------------ the lesson

  dir(lesson) { return `${A}LESSONS/${lesson.folder}/`; }

  /** The lesson's files onto the floppies; what is there already stays, unless `fresh`. */
  async install(lesson, fresh = false) {
    const S = this.browser;
    const put = async (to, from) => {
      if (!fresh) { try { await S.readBytes(to); return; } catch { /* not there: copy it */ } }
      await S.write(to, await bytes(from));
    };
    for (const [name, from] of TOOLS) await put(`${B}${name}`, from);
    if (lesson.engine) for (const e of ENGINE) await put(`${A}ENGINE/${e}`, `ENGINE/${e}`);
    for (const f of lesson.files) await put(`${this.dir(lesson)}${f}`, `LESSONS/${lesson.folder}/${f}`);
    const com = lesson.main.replace(/\.ASM$/i, '.COM');
    // The build and the run, as batch files on A: - so they are also there
    // to type. The PC switches on at full speed, for FASM; GO.BAT slows it
    // to the machine the lessons were made on before the program starts.
    await S.write(`${this.dir(lesson)}BUILD.BAT`, [
      '@echo off',
      `if exist ${com} del ${com}`,
      'B:\\CWSDPMI.EXE',
      `B:\\FASM.EXE -m ${FASM_KB} ${lesson.main} ${com} > BUILD.TXT`,
      `if not exist ${com} goto end`,
      'call GO.BAT',
      ':end', ''].join('\r\n'));
    await S.write(`${this.dir(lesson)}GO.BAT`, [
      '@echo off',
      `config -set "cpu cycles=fixed ${LESSON_CYCLES}"`,
      com, ''].join('\r\n'));
  }

  /**
   * A lesson opens whole, as the pilot drew it: its source on the left, its
   * video on the right waiting for a click, and the DOS PC above the video
   * building the source and running it - what the lesson makes is on the
   * screen before a key is pressed.
   */
  async openLesson(lesson) {
    this.lesson = lesson;
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
    else this.addDoc(lesson.main, await this.browser.read(path), this.browser, path);
    await this.build();
  }

  /** The lesson's source back onto A:, without a box saying so. */
  async saveQuietly() {
    const lesson = this.lesson;
    if (!lesson) return;
    const path = `${this.dir(lesson)}${lesson.main}`;
    for (const [, d] of this.docs) {
      if (d.path !== path) continue;
      const typed = this.owl.getText(d.text);
      await this.browser.write(path, d.crlf ? typed.replace(/\r?\n/g, '\r\n') : typed);
    }
  }

  async build() {
    const lesson = this.lesson;
    if (!lesson?.buildable) { this.list.show(); return; }
    await this.saveQuietly();
    await this.install(lesson);
    const out = `${this.dir(lesson)}BUILD.TXT`;
    await this.browser.remove(out).catch(() => {});
    // A newer F9 takes over: the older build stops waiting for its answer.
    const mine = this.builds = (this.builds ?? 0) + 1;
    this.showBuild(`Assembling ${lesson.main} on the DOS PC...`);
    log.info('build', `${lesson.id}: FASM -m ${FASM_KB} ${lesson.main}`);
    this.placeDos();
    await this.dos.run(this.dir(lesson), 'BUILD.BAT');
    // DOS writes BUILD.TXT on A:, and the floppy's folder gets it back
    // within a second or two. FASM's last line says how it went.
    for (let i = 0; i < 120; i++) {
      await new Promise(r => setTimeout(r, 1000));
      if (mine !== this.builds) return;
      if (this.dos.crashed) { this.showBuild(CRASHED); return; }
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

  runOnly() {
    const lesson = this.lesson;
    if (!lesson?.buildable) { this.list.show(); return; }
    this.placeDos();
    return this.dos.run(this.dir(lesson), 'GO.BAT');
  }

  showBuild(text) {
    const owl = this.owl;
    if (!this.buildWin) {
      const r = this.layout().build;
      this.buildWin = owl.window('Build', r.w, r.h, { x: r.x, y: r.y, style: Style.Dialog, closeCmd: Cm.BuildClose });
      this.buildText = owl.staticText(this.buildWin, 1, 1, '', r.w - 4, r.h - 3);
    }
    owl.setText(this.buildText, text);
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
      case Cm.Save:
        this.track(this.saveQuietly().then(() => { if (this.lesson) this.showBuild(`${this.lesson.main} saved on A:. F9 builds and runs it.`); }));
        return true;
      case Cm.Lessons: this.list.show(); return true;
      case Cm.Keys: this.dos.box.grab(); return true;
      case Cm.DosOff:
      case Cm.DosClose: this.track(this.dos.close()); return true;
      case Cm.Next: owl.nextWindow(); return true;
      case Cm.Previous: owl.previousWindow(); return true;
      case Cm.Zoom: { const a = owl.active(); if (a) owl.zoom(a); return true; }
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
      default:
        // The Lessons window's own buttons.
        if (this.list.handles(cmd)) this.list.onCommand(cmd);
        return true;
    }
  }

  /** The front window is being closed: whoever owns it forgets it. */
  closeActive() {
    const a = this.owl.active();
    if (!a) return;
    if (this.list.owns(a)) { this.list.close(); return; }
    if (this.dos.owns(a)) { this.track(this.dos.close()); return; }
    if (a === this.buildWin) { this.owl.close(a); this.buildWin = 0; return; }
    if (a === this.video?.win) { this.closeVideo(); return; }
    if (a === this.box) { this.closeBox(); return; }
    this.owl.close(a);
    this.docs.delete(a);
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
