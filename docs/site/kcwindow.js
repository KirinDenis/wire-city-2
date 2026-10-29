// Kirin Commander for Web: the commander in a window of the site.
//
// Kirin Commander is its own project (github.com/KirinDenis/Kirin_Commander):
// docs/kc/ is its browser build as docs/pull-kc.ps1 copied it - kc.wasm, the
// commander in Rust, and kc.js, which gives it a page's drives and draws its
// frames on a canvas of its own. Never edited here.
//
// That canvas lies UNDER the site's, exactly where the window's inside is,
// the way the DOS PC's picture does (owlosui/dosbox/dosbox.js): the inside
// is a hole, so whatever the site draws over the window - a menu, a dialog,
// a shadow - covers just the cells it covers, and the mouse over the hole
// is the commander's. The window is an ordinary window of the site: it
// moves, it is resized and zoomed, and the commander takes the new size.
//
// The keys are the commander's while its window is the one in front and
// nothing is drawn over it - F1 to F10 and Alt+F1 are its own then, as in
// any commander; another window brought to the front, or a menu opened
// over it, gives them back to the site. Right Ctrl gives them back too.
//
// Its drives are the site's drive table, the same array: a drive Map
// Drives adds is in its Alt+F1 at once. Its command line is the site's
// console: a line typed there is sent on the bus as if typed into the
// terminal (`ls`, `build`, `play`...), and what it printed is the terminal
// behind the panels (Ctrl+O). Enter on a program sends `run` with its
// path, so it starts on the DOS PC; Enter on an .ASM - the extension table
// below - `build`, which assembles it there and runs it.

import { Commander } from '../kc/kc.js';
import { Screen } from '../kc/owlosui/owlosui.js';
import { log } from '../owlosui/apps/log.js';

// The commander's own files - its setup (Shift+F9), KC.MNU, KC.EXT - are
// keys of this browser's localStorage under this name (kc.js, KC:\).
const SETUP_KEY = 'wirecity.kc.ini';
// What Enter does on a file that is not a program, the first time the
// commander is opened here - KC.EXT, which Commands > Extension file edit
// changes: an assembly source is built on the DOS PC, as the course's
// commander always did.
const DEFAULT_EXT = '; Enter on a file with this extension runs the command; !\\!.! is the file.\r\nasm: build !\\!.!\r\n';

export class KcWindow {
  constructor(app, { closeCmd = 0 } = {}) {
    this.app = app;
    this.owl = app.owl;
    this.closeCmd = closeCmd;
    this.win = 0;
    this.hole = 0;
    this.el = null;
    this.canvas = null;
    this.kc = null;
    this.front = false;
    this.place = () => this.layout();
    this.owl.afterPaint?.add(this.place);
    if (typeof window === 'undefined') return;
    // Right Ctrl: the keys back to the site, as from the DOS PC.
    window.addEventListener('keydown', e => {
      if (e.code === 'ControlRight' && this.hasKeys()) {
        e.preventDefault();
        e.stopImmediatePropagation();
        this.canvas.blur();
      }
    }, true);
  }

  owns(id) { return id !== 0 && id === this.win; }
  get isOpen() { return this.win !== 0; }
  hasKeys() { return !!this.canvas && document.activeElement === this.canvas; }

  /**
   * The commander, its panels on these folders: drive objects of the
   * table and their paths (`/LESSONS/`). Already open: brought to the
   * front and put there.
   */
  async show({ left, right = left, leftDir = '/', rightDir = '/' }) {
    const l = dosPath(left, leftDir), r = dosPath(right, rightDir);
    if (this.win) {
      this.owl.activate(this.win);
      this.owl.refresh?.();
      await this.kc?.go(l, r);
      this.canvas?.focus();
      return this.kc;
    }
    seedExtensions();
    const W = this.owl.width, H = this.owl.height;
    const w = Math.min(W, 82), h = Math.max(12, Math.min(H - 2, 27));
    this.win = this.owl.window('Kirin Commander', w, h, { x: Math.max(0, Math.floor((W - w) / 2)), y: 1, closeCmd: this.closeCmd });
    this.hole = this.owl.hole(this.win);
    const el = document.createElement('div');
    el.dataset.owlOwnKeys = '';
    el.style.cssText = 'position:fixed;z-index:0;background:#000;visibility:hidden;overflow:hidden';
    const canvas = document.createElement('canvas');
    canvas.tabIndex = 0;
    canvas.style.cssText = 'display:block;outline:none';
    // A click on it is a click on its window: the window comes to the front.
    canvas.addEventListener('mousedown', () => { if (this.owl.active() !== this.win) { this.owl.activate(this.win); this.owl.refresh?.(); } canvas.focus(); });
    el.append(canvas);
    document.body.append(el);
    this.el = el;
    this.canvas = canvas;
    this.layout();
    this.owl.refresh?.();
    const sc = this.owl.screen;
    try {
      this.kc = await Commander.start(canvas, {
        drives: this.app.drives, current: l, box: el, setupKey: SETUP_KEY,
        screen: new Screen(canvas, { font: sc?.font, cellHeight: sc?.cellH }),
        run: (dir, line) => this.run(dir, line),
        onQuit: () => this.closeWindow(this.win),
      });
    } catch (e) {
      log.error('kc', `Kirin Commander did not start: ${e?.message ?? e}`);
      this.closeWindow(this.win);
      throw e;
    }
    await this.kc.go(l, r);
    canvas.focus();
    this.front = true;
    log.info('kc', `Kirin Commander: ${l} and ${r}`);
    return this.kc;
  }

  /**
   * A command line from the commander, in the site's console. A program's
   * name alone - Enter on it, or typed - is `run` with its whole path; the
   * rest goes as it was typed.
   */
  async run(dir, line) {
    const typed = line.trim();
    const prog = /^"?([^"\s\\]+\.(com|exe|bat))"?$/i.exec(typed);
    const cmd = prog ? `run ${dir.replace(/\\$/, '')}\\${prog[1].toUpperCase()}` : typed;
    const a = await this.app.terminal.bus.send(cmd, { from: 'Kirin Commander' });
    this.app.owl.refresh?.();
    return [`${dir}>${line}`, ...(a.lines ?? []).map(x => x.text), ...(a.errors ?? [])].join('\n');
  }

  /** The drives changed under it - DOS wrote a floppy, a command made a file. */
  reread() { this.kc?.reread(); }

  closeWindow(id = this.win) {
    if (!id || id !== this.win) return;
    this.kc?.stop();
    this.kc = null;
    this.el?.remove();
    this.el = null;
    this.canvas = null;
    const win = this.win;
    this.win = 0;
    this.hole = 0;
    try { this.owl.close(win); } catch { /* gone already */ }
    this.owl.refresh?.();
  }

  /** Under the window's inside, after every paint; the keys while it is in front. */
  layout() {
    if (!this.el) return;
    const p = this.win ? this.owl.place(this.win) : null;
    const { cellW, cellH, canvas } = this.owl.screen ?? {};
    if (!p || !canvas) {
      this.el.style.visibility = 'hidden';
      return;
    }
    const box = canvas.getBoundingClientRect();
    Object.assign(this.el.style, {
      left: `${box.left + p.x * cellW}px`, top: `${box.top + p.y * cellH}px`,
      width: `${p.w * cellW}px`, height: `${p.h * cellH}px`, visibility: 'visible',
    });
    // In front and uncovered: its keys - once, when it comes to the front,
    // so Right Ctrl and a click elsewhere keep the keys where they went.
    const front = !p.covered && this.owl.active() === this.win;
    if (front && !this.front) this.canvas.focus();
    if (!front && this.hasKeys()) this.canvas.blur();
    this.front = front;
  }
}

/** A drive of the table and its path, as DOS spells it: `A:\LESSONS`. */
function dosPath(drive, dir = '/') {
  const rest = String(dir).replace(/^\/+|\/+$/g, '').replace(/\//g, '\\');
  return `${drive.letter}:\\${rest}`;
}

/** KC.EXT the first time: the site's associations, which the person may change. */
function seedExtensions() {
  try {
    const key = `${SETUP_KEY}:KC.EXT`;
    if (localStorage.getItem(key) === null) localStorage.setItem(key, DEFAULT_EXT);
  } catch { /* no storage: Enter on an .ASM opens it in the viewer */ }
}
