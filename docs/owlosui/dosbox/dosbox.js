// DOSBox in an OWLOSUI window: a real DOS machine, compiled to WebAssembly
// (js-dos, ../jsdos/), laid over a window's inside.
//
// The core draws every cell of the screen; the emulator's picture is not a
// cell, so it is an element of the page put exactly over the window - and
// moved with it, and hidden while a menu or another window is drawn over
// it (owl.place says where the window is and whether it is covered). The
// machine keeps running while it is hidden.
//
// The keyboard belongs to whoever has the focus. Click the DOS picture and
// keys go to DOS; click anywhere on the OWLOSUI screen, or press Right Ctrl
// - the "host key" virtual machines have always used - and they come back.
//
// A machine starts from either a .jsdos bundle (a zip with a dosbox.conf
// inside: url) or from a dosbox.conf and the files of its disks, put
// together in the page (conf, files). Once it runs, `ci` is js-dos's
// command interface: its files, its keys, its statistics.

import { NetTap } from './nettap.js';

const JSDOS = new URL('../jsdos/', import.meta.url);

let loading = null;

/**
 * js-dos is a classic script that defines window.Dos; it is loaded once, on
 * the first machine, not with the page.
 *
 * Before it, a heartbeat for requestAnimationFrame: js-dos paces the
 * emulator on frames, and a covered or background tab gets none, so a
 * networked game would vanish from everybody else's sky. Raced against a
 * plain timer, a visible page is unchanged and a hidden one still ticks.
 */
function loadJsDos() {
  if (loading) return loading;
  const raf = window.requestAnimationFrame.bind(window);
  const caf = window.cancelAnimationFrame.bind(window);
  let seq = 1;
  const live = new Map();
  window.requestAnimationFrame = cb => {
    const key = seq++;
    const fire = ts => {
      const e = live.get(key);
      if (!e) return;
      live.delete(key);
      caf(e.r);
      clearTimeout(e.t);
      cb(ts);
    };
    live.set(key, { r: raf(fire), t: setTimeout(() => fire(performance.now()), 250) });
    return -key; // negative: never one of the browser's own ids
  };
  window.cancelAnimationFrame = id => {
    if (id >= 0) return caf(id);
    const e = live.get(-id);
    if (e) { live.delete(-id); caf(e.r); clearTimeout(e.t); }
  };
  const css = document.createElement('link');
  css.rel = 'stylesheet';
  css.href = new URL('js-dos.css', JSDOS).href;
  document.head.append(css);
  // No focus ring on the picture: the browser draws one round whatever
  // has the keyboard, two colours wide, and here it lands on the window's
  // frame and doubles its lines. The window's title says who has the keys.
  const ring = document.createElement('style');
  ring.textContent = '[data-owl-own-keys], [data-owl-own-keys] * { outline: none !important; }';
  document.head.append(ring);
  loading = new Promise((resolve, reject) => {
    const s = document.createElement('script');
    s.src = new URL('js-dos.js', JSDOS).href;
    s.onload = () => resolve(window.Dos);
    s.onerror = () => reject(new Error('js-dos did not load from ' + s.src));
    document.head.append(s);
  });
  return loading;
}

export class DosBox {
  /** One DOS machine at a time, over one window; owl from run(). */
  constructor(owl) {
    this.owl = owl;
    this.win = 0;
    this.dos = null;
    this.ci = null;
    this.el = null;
    this.what = '';
    this.net = NetTap.install();
    this.listeners = new Set();
    this.place = () => this.layout();
    owl.afterPaint?.add(this.place);
    if (typeof window === 'undefined') return; // a test in Node: no page to lay anything on
    // Right Ctrl: the keyboard back to OWLOSUI. Caught on the way down,
    // before the emulator's element - which keeps every key it sees.
    window.addEventListener('keydown', e => {
      if (e.code === 'ControlRight' && this.hasKeys()) {
        e.preventDefault();
        e.stopImmediatePropagation();
        this.release();
      }
    }, true);
    // js-dos pauses a machine whenever the page is hidden. A networked one
    // must keep going, or its player drops off the wire.
    document.addEventListener('visibilitychange', () => {
      if (this.ci && this.keepRunning) setTimeout(() => this.ci?.resume(), 50);
    });
    // js-dos 8 listens for keys on the whole WINDOW, not on its picture, so
    // every key typed in an editor on the page went to DOS as well (three
    // Downs in the editor, three Downs in DOS). OWLOSUI hears keys on
    // `document`, a step before the window: there a key is stopped from
    // going on unless DOS has the focus. A key that went down while DOS
    // had it is still let up, so nothing stays held in DOS.
    const held = new Set();
    const gate = e => {
      if (this.hasKeys()) {
        if (e.type === 'keydown') held.add(e.code); else held.delete(e.code);
        return;
      }
      if (e.type === 'keyup' && held.delete(e.code)) return;
      e.stopPropagation();
    };
    document.addEventListener('keydown', gate);
    document.addEventListener('keyup', gate);
    // js-dos sometimes dies - `RuntimeError: unreachable`, seen right
    // after FASM's banner, cause not found - and a dead one never answers
    // again. It is noticed here and said ('crashed'); the next start makes
    // a fresh machine, and nothing waits on the dead one (stop's limit).
    this.crashed = false;
    window.addEventListener('error', e => {
      if (!this.running || this.crashed || !/unreachable/.test(String(e.message ?? e.error))) return;
      this.crashed = true;
      this.emit('crashed');
    });
  }

  /**
   * Something to hear about: 'started', 'stopped', 'keys' (who has the
   * keyboard), 'frame' (a new picture size, in frameSize), 'crashed' (js-dos
   * died: `crashed` is true until the next start), and what the emulator
   * says - 'stdout' with its line, 'message' with { type, text }.
   */
  on(f) { this.listeners.add(f); return () => this.listeners.delete(f); }
  emit(what, detail) { for (const f of this.listeners) f(what, this, detail); }

  get running() { return this.ci !== null; }

  /**
   * A machine over the window `win`. One of:
   *   { url }            a .jsdos bundle
   *   { conf, files }    a dosbox.conf and [{ path, contents }] for its disks
   * what: a name for it, shown by the page. keepRunning: carry on in a
   * background tab - for a machine on the network. picture: 'sharp' -
   * whole multiples of DOS's pixels; 'fill' - as big as the window allows
   * at 4:3, the pixels still square blocks; 'monitor' - the same size,
   * smoothed as a CRT showed it.
   */
  async start(win, { url, conf, files = [], what = 'DOS', keepRunning = false, picture = 'sharp' }) {
    await this.stop();
    const Dos = await loadJsDos();
    this.crashed = false;
    this.win = win;
    this.what = what;
    this.keepRunning = keepRunning;
    this.picture = picture;
    this.frameSize = { w: 640, h: 400 };
    // A black backdrop over the window's inside, and js-dos's own element
    // in it, at the size the picture is shown at - see layout().
    const el = document.createElement('div');
    el.dataset.owlOwnKeys = '';
    el.style.cssText = 'position:fixed;z-index:5;background:#000;visibility:hidden';
    el.addEventListener('focusin', () => this.emit('keys'));
    el.addEventListener('focusout', () => this.emit('keys'));
    const screen = document.createElement('div');
    screen.style.cssText = 'position:absolute;background:#000';
    el.append(screen);
    document.body.append(el);
    this.el = el;
    this.screenEl = screen;
    this.layout();
    const ready = new Promise((resolve, reject) => {
      const options = {
        pathPrefix: new URL('emulators/', JSDOS).href,
        backend: 'dosbox',          // pinned: only DOSBox is vendored, and js-dos remembers a choice
        kiosk: true,                // no js-dos side bar: the window is the frame
        autoStart: true,
        noCloud: true,
        noNetworking: false,
        // Sharp: every DOS pixel a whole square of screen pixels, the frame
        // as it is. Fill: as big as the window at 4:3, the pixels blocks -
        // sharp in a window a few pixels short of 400 showed 320 by 200 at
        // one to one, a stamp in a black field. A monitor: the same size,
        // smoothed as a CRT showed it.
        imageRendering: picture === 'monitor' ? 'smooth' : 'pixelated',
        renderAspect: picture === 'sharp' ? 'AsIs' : '4/3',
        onEvent: (event, ci) => {
          if (event === 'ci-ready') {
            this.ci = ci;
            // A mode change - text, a game's 320 by 200 - is a new frame size,
            // and the whole-pixel scale is worked out again for it.
            ci.events().onFrameSize((w, h) => { this.frameSize = { w, h }; this.layout(); this.emit('frame'); });
            ci.events().onStdout?.(line => this.emit('stdout', String(line)));
            ci.events().onMessage?.((type, ...args) => this.emit('message', { type: String(type), text: args.map(String).join(' ') }));
            resolve(ci);
          }
          if (event === 'exit') this.emit('stopped');
        },
      };
      if (url) options.url = url;
      else { options.dosboxConf = conf; options.initFs = files; }
      try { this.dos = Dos(screen, options); } catch (e) { reject(e); }
    });
    const ci = await ready;
    this.emit('started');
    return ci;
  }

  /**
   * Switched off, its picture taken away. A machine that does not stop in
   * `ms` - a crashed js-dos never answers - is dropped: its picture taken
   * off the page all the same, and 'dropped' returned.
   */
  async stop(ms = 3000) {
    const dos = this.dos, el = this.el;
    this.dos = null;
    this.ci = null;
    this.el = null;
    let result = dos ? 'stopped' : 'off';
    if (dos) {
      const stopped = dos.stop().then(() => true, () => true);
      const late = new Promise(r => setTimeout(() => r(false), ms));
      if (!(await Promise.race([stopped, late]))) result = 'dropped';
    }
    el?.remove();
    if (dos) this.emit('stopped');
    return result;
  }

  /** Over the window's inside while nothing covers it; hidden, and the keyboard given back, while something does. */
  layout() {
    if (!this.el) return;
    const p = this.win ? this.owl.place(this.win) : null;
    const { cellW, cellH, canvas } = this.owl.screen ?? {};
    if (!p || !canvas) {
      this.el.style.visibility = 'hidden';
      return;
    }
    const box = canvas.getBoundingClientRect();
    const area = { x: box.left + p.x * cellW, y: box.top + p.y * cellH, w: p.w * cellW, h: p.h * cellH };
    Object.assign(this.el.style, {
      left: `${area.x}px`, top: `${area.y}px`, width: `${area.w}px`, height: `${area.h}px`,
      visibility: p.covered ? 'hidden' : 'visible',
    });
    const s = this.pictureRect(area);
    Object.assign(this.screenEl.style, {
      left: `${s.x - area.x}px`, top: `${s.y - area.y}px`, width: `${s.w}px`, height: `${s.h}px`,
    });
    if (p.covered && this.hasKeys()) this.release();
  }

  /**
   * Where the picture goes inside the window. Sharp: the largest whole
   * multiple of the DOS frame that fits, counted in the screen's own
   * pixels - a 125% Windows display has 1.25 of them to a CSS pixel - and
   * placed on a pixel, centred. Scaled by anything else, some columns of
   * a letter come out a pixel wider than the rest, and text is hard to
   * read. Fill and a monitor: the whole area; js-dos keeps 4:3 inside it.
   */
  pictureRect(area) {
    if (this.picture !== 'sharp') return area;
    const dpr = globalThis.devicePixelRatio || 1;
    const { w: fw, h: fh } = this.frameSize;
    const k = Math.floor(Math.min((area.w * dpr) / fw, (area.h * dpr) / fh));
    if (k < 1) {
      // A window smaller than the frame: fitted, as well as it can be.
      const f = Math.min(area.w / fw, area.h / fh);
      return { x: area.x + (area.w - fw * f) / 2, y: area.y + (area.h - fh * f) / 2, w: fw * f, h: fh * f };
    }
    const w = (fw * k) / dpr, h = (fh * k) / dpr;
    const snap = v => Math.round(v * dpr) / dpr;
    return { x: snap(area.x + (area.w - w) / 2), y: snap(area.y + (area.h - h) / 2), w, h };
  }

  /**
   * How big a window's inside should be, in cells, for a frame of fw by fh
   * shown sharp: the largest whole multiple of it, in the screen's own
   * pixels, that fits in `cols` by `rows` cells - then the window is the
   * picture, with no black round it. { w, h, scale }.
   */
  static insideFor(owl, cols, rows, fw = 640, fh = 400) {
    const cw = owl.screen?.cellW ?? 10, ch = owl.screen?.cellH ?? 22;
    const dpr = globalThis.devicePixelRatio || 1;
    const k = Math.max(1, Math.floor(Math.min((cols * cw * dpr) / fw, (rows * ch * dpr) / fh)));
    return {
      w: Math.min(cols, Math.ceil((fw * k) / dpr / cw)),
      h: Math.min(rows, Math.ceil((fh * k) / dpr / ch)),
      scale: k,
    };
  }

  /** Whether DOS has the keyboard now. */
  hasKeys() {
    return !!this.el && this.el.contains(document.activeElement);
  }

  /** The keyboard to DOS, as a click on its picture does. */
  grab() {
    const target = this.el?.querySelector('canvas') ?? this.el;
    if (target && !target.hasAttribute('tabindex')) target.tabIndex = -1;
    target?.focus();
  }

  /** The keyboard back to OWLOSUI. */
  release() {
    if (this.hasKeys()) document.activeElement.blur();
    this.emit('keys');
  }

  /** A key into DOS, pressed and let go: js-dos's key numbers (KEYS below). */
  async press(...codes) {
    if (!this.ci) return;
    for (const c of codes) this.ci.sendKeyEvent(c, true);
    await new Promise(r => setTimeout(r, 60));
    for (const c of codes.reverse()) this.ci.sendKeyEvent(c, false);
  }

  /** The emulator's own counters, and the network's: for a monitor. */
  async stats() {
    if (!this.ci) return null;
    return { ...(await this.ci.asyncifyStats()), net: this.net.totals() };
  }

  /** What DOS shows now, as an ImageData. */
  screenshot() { return this.ci?.screenshot(); }
}

/** js-dos's numbers for the keys a page presses for DOS. */
export const KEYS = { enter: 257, esc: 256, tab: 258, ctrl: 341, alt: 342, shift: 340, f10: 299, r: 82 };
