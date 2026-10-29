// OWLOSUI under a finger: a phone's or a tablet's touch screen.
//
// A finger is not a mouse. It has no wheel and no second button, it covers
// several cells at once, and a drag that selects with a mouse should
// scroll under a finger, as every phone has taught the hand. So a touch is
// read as a gesture first, and only then handed to the core:
//
//   tap                        a click; two quick taps, a double click
//   drag on a window's title   the window moves
//   drag near its corner       the window is resized (the core says where)
//   drag on a text or a list   it scrolls, a row at a time, following
//   drag anywhere else         the mouse's drag - a menu, a scroll bar
//   hold                       the right button: the context menu
//   hold, then drag            a selection; on lifting, the context menu
//                              with Copy on it
//   two fingers                the browser's own: pinch to zoom
//
// The desktop's mouse is not touched: these listen to touch events only,
// and a touch ends with preventDefault, so the browser does not send the
// mouse events it would make up for it and every tap twice.
//
// A phone has no keys either. Keyboard puts a hidden textarea on the page
// and focuses it when a tap lands where the core shows a caret, which is
// what opens the phone's keyboard; what is typed there goes to the core.
// KeyBar is the row of keys a DOS program needs and a phone's keyboard
// has not got: Esc, Tab, Ctrl, Alt, the arrows, F1 to F10.

/** How long a finger stays still before it is a hold, in milliseconds. */
export const HOLD_MS = 450;
/** How far a finger may wander and still be tapping, in CSS pixels. */
export const SLOP_PX = 8;
/** Two taps this close in time, on the same cell, are a double tap. */
export const DOUBLE_MS = 400;

/** True on a screen whose main pointer is a finger: a phone, a tablet. */
export function touchFirst() {
  return typeof matchMedia === 'function' && matchMedia('(pointer: coarse)').matches;
}

/**
 * One finger's gesture, read and handed to the core. No DOM in here - a
 * test drives it with points and its own clock:
 *
 *   const f = new Finger(owl, { cell, cellH, after });
 *   f.down({ x, y, t }); f.move(...); f.up(t);   // and f.hold() when due
 *
 * cell(p) turns a point in CSS pixels into the cell under it; after() is
 * the page's own after-input (deliver, clipboard, paint). setTimer and
 * clearTimer default to the page's; a test passes its own and calls
 * hold() itself.
 */
export class Finger {
  constructor(owl, { cell, cellH, after, zoomed = () => false, setTimer = (f, ms) => setTimeout(f, ms), clearTimer = id => clearTimeout(id) }) {
    this.owl = owl;
    // The page pinched bigger: a drag then moves the view over it, as on
    // any page - except on a window's title or corner, which still move
    // and size the window.
    this.zoomed = zoomed;
    this.cell = cell;
    this.cellH = cellH;
    this.after = after;
    this.setTimer = setTimer;
    this.clearTimer = clearTimer;
    this.mode = null;
    this.lastTap = { t: -1e9, x: -1, y: -1 };
  }

  /** A finger put down. */
  down(p) {
    this.cancel();
    this.start = p;
    this.at = this.cell(p);
    this.last = this.at;
    this.mode = 'still';
    this.timer = this.setTimer(() => this.hold(), HOLD_MS);
    // Decided now, while the browser still waits to hear whether it may
    // move the view: the first move is the one that can say no.
    this.pans = false;
    if (this.zoomed()) {
      const what = this.owl.touchAt(this.at.x, this.at.y).what;
      this.pans = what !== 1 && what !== 2;
    }
  }

  /** The finger has stayed still long enough: it is a hold. */
  hold() {
    this.timer = null;
    if (this.mode !== 'still') return;
    this.mode = 'held';
    globalThis.navigator?.vibrate?.(15);
  }

  /** The finger moved. True if this gesture is the core's - not the page's to scroll. */
  move(p) {
    if (!this.mode) return false;
    const far = Math.hypot(p.x - this.start.x, p.y - this.start.y) > SLOP_PX;
    // Zoomed in and not on a title: the browser's, to move the view. A
    // finger that wandered off is not tapping or holding any more.
    if (this.pans && this.mode === 'still') {
      if (far) {
        this.stopTimer();
        this.mode = 'page';
      }
      return false;
    }
    if (this.mode === 'page') return false;
    if (this.mode === 'still') {
      if (!far) return true;
      this.stopTimer();
      const hit = this.owl.touchAt(this.at.x, this.at.y);
      if (hit.what === 3) {
        this.mode = 'scroll';
        this.scrollY = this.start.y;
      } else {
        // The core is pressed where it said - the corner itself, for a
        // finger that took the window a little way off it - and the drag
        // keeps that distance from the finger.
        this.mode = 'drag';
        this.offset = { x: hit.x - this.at.x, y: hit.y - this.at.y };
        this.owl.mouse(0, hit.x, hit.y, 0);
        this.after();
      }
    } else if (this.mode === 'held') {
      if (!far) return true;
      // A hold, then a drag: the mouse's left button, selecting.
      this.mode = 'select';
      this.offset = { x: 0, y: 0 };
      this.owl.mouse(0, this.at.x, this.at.y, 0);
      this.after();
    }
    if (this.mode === 'scroll') {
      // The finger goes up, the text goes up with it: what is below comes
      // into sight, as the wheel turned down would bring it.
      const rows = Math.trunc((this.scrollY - p.y) / this.cellH);
      if (rows) {
        this.scrollY -= rows * this.cellH;
        this.owl.scroll(this.at.x, this.at.y, rows);
        this.after();
      }
      return true;
    }
    const c = this.cell(p);
    const to = { x: c.x + this.offset.x, y: c.y + this.offset.y };
    if (to.x !== this.last.x || to.y !== this.last.y) {
      this.last = to;
      this.owl.mouse(2, to.x, to.y, 0);
      this.after();
    }
    return true;
  }

  /** The finger lifted, at time t. What it was is done now. */
  up(t) {
    const mode = this.mode;
    this.stopTimer();
    this.mode = null;
    const { x, y } = this.at ?? { x: 0, y: 0 };
    if (mode === 'still') {
      const twice = t - this.lastTap.t < DOUBLE_MS && x === this.lastTap.x && y === this.lastTap.y;
      this.lastTap = twice ? { t: -1e9, x: -1, y: -1 } : { t, x, y };
      this.owl.mouse(twice ? 6 : 0, x, y, 0);
      this.owl.mouse(1, x, y, 0);
      this.after();
      return 'tap';
    }
    if (mode === 'held') {
      this.rightClick(x, y);
      return 'menu';
    }
    if (mode === 'drag' || mode === 'select') {
      this.owl.mouse(1, this.last.x, this.last.y, 0);
      this.after();
      // A selection made by hand is made to be copied: the menu comes up
      // with Copy on it - opened on the selection's first cell, the one
      // the finger came from or went to, whichever is first in reading
      // order; its last cell is past the selection, and a menu opened
      // there would put the caret there and let the selection go.
      if (mode === 'select') {
        const a = this.at, b = this.last;
        const first = a.y < b.y || (a.y === b.y && a.x <= b.x) ? a : b;
        this.rightClick(first.x, first.y);
      }
      return mode;
    }
    return mode ?? 'none';
  }

  /** The gesture is off - a second finger came, or the browser took it. */
  cancel() {
    this.stopTimer();
    if (this.mode === 'drag' || this.mode === 'select') {
      this.owl.mouse(1, this.last.x, this.last.y, 0);
      this.after();
    }
    this.mode = null;
  }

  rightClick(x, y) {
    this.owl.mouse(0, x, y, 1);
    this.owl.mouse(1, x, y, 1);
    this.after();
  }

  stopTimer() {
    if (this.timer != null) this.clearTimer(this.timer);
    this.timer = null;
  }
}

/**
 * What changed between what the textarea held and what it holds now, as
 * keys: so many Backspaces, then the characters typed. A phone's keyboard
 * does not say which key was pressed - Android's says 229 for all of them -
 * and it may take back half a word and put a corrected one in its place,
 * so the text itself is the only honest account.
 */
export function typedBetween(before, now) {
  let same = 0;
  while (same < before.length && same < now.length && before[same] === now[same]) same++;
  return { back: [...before.slice(same)].length, text: now.slice(same) };
}

/**
 * The hidden textarea that brings up a phone's keyboard and hears it. It
 * always holds two spaces in front of what is being typed, so that a
 * Backspace with nothing typed still has something to delete - a keyboard
 * sends no event at all for deleting nothing.
 */
export class Keyboard {
  static SENTINEL = '  ';

  constructor(owl, { after, mods }) {
    this.owl = owl;
    this.after = after;
    this.mods = mods; // () => { ctrl, alt } held on the key bar, taken once
    this.composing = false;
    const ta = (this.area = document.createElement('textarea'));
    for (const [k, v] of Object.entries({ autocapitalize: 'off', autocomplete: 'off', autocorrect: 'off', spellcheck: 'false', 'aria-label': 'Keyboard' })) ta.setAttribute(k, v);
    ta.dataset.owlKeyboard = '';
    // On the page, where nothing can see it: 16px so iOS does not zoom
    // in to it, at the top so iOS has no reason to scroll to it.
    Object.assign(ta.style, {
      position: 'fixed', left: '0', top: '0', width: '1px', height: '1px', opacity: '0', border: '0', padding: '0',
      margin: '0', resize: 'none', fontSize: '16px', caretColor: 'transparent', zIndex: '-1', pointerEvents: 'none',
    });
    document.body.appendChild(ta);
    this.reset();
    ta.addEventListener('compositionstart', () => { this.composing = true; });
    ta.addEventListener('compositionend', () => { this.composing = false; this.heard(); });
    ta.addEventListener('input', () => this.heard());
    // Keys that come as keys - a hardware keyboard, iOS's own - the page's
    // keydown has already given the core and kept out of the textarea; a
    // caret moved inside it is put back at the end.
    ta.addEventListener('select', () => this.toEnd());
    this.auto = false;
  }

  get open() { return document.activeElement === this.area; }

  /** The phone's keyboard up. auto: because a caret was tapped, not asked for. */
  show(auto) {
    if (!this.open) this.area.focus({ preventScroll: true });
    this.auto = auto;
  }

  hide() {
    if (this.open) this.area.blur();
  }

  reset() {
    this.area.value = Keyboard.SENTINEL;
    this.base = Keyboard.SENTINEL;
    this.toEnd();
  }

  toEnd() {
    const n = this.area.value.length;
    if (this.area.selectionStart !== n || this.area.selectionEnd !== n) this.area.setSelectionRange(n, n);
  }

  heard() {
    const now = this.area.value;
    const { back, text } = typedBetween(this.base, now);
    this.base = now;
    if (!back && !text) return;
    for (let i = 0; i < back; i++) this.owl.press('Backspace');
    for (const ch of text) {
      const m = this.mods();
      if (ch === '\n') this.owl.press('Enter', m);
      else this.owl.press(ch, m);
    }
    // While a word is being composed the keyboard owns the text; after,
    // it is cleared to the two spaces again, so it never grows.
    if (!this.composing && (now !== Keyboard.SENTINEL)) this.reset();
    this.after();
  }
}

/**
 * The keys a DOS program wants and a phone's keyboard has not got, in a
 * row along the bottom of the screen. Ctrl and Alt stay down for the next
 * key - a letter typed, or one of these - and let go after it. Fn turns
 * the row over: F1 to F10, Home, End, PgUp, PgDn.
 */
export class KeyBar {
  static HEIGHT = 40;

  constructor(owl, { after, keyboard }) {
    this.owl = owl;
    this.after = after;
    this.keyboard = keyboard;
    this.held = { ctrl: false, alt: false };
    this.page = 0;
    const bar = (this.el = document.createElement('div'));
    bar.dataset.owlKeyBar = '';
    Object.assign(bar.style, {
      position: 'fixed', left: '0', right: '0', bottom: '0', height: KeyBar.HEIGHT + 'px', display: 'flex',
      background: '#000', borderTop: '1px solid #555', zIndex: '10', touchAction: 'manipulation', userSelect: 'none',
      webkitUserSelect: 'none',
    });
    document.body.appendChild(bar);
    this.draw();
  }

  static PAGES = [
    ['Esc', 'Tab', 'Ctrl', 'Alt', '←', '↑', '↓', '→', 'Fn', '⌨'],
    ['F1', 'F2', 'F3', 'F4', 'F5', 'F6', 'F7', 'F8', 'F9', 'F10', 'Home', 'End', 'PgUp', 'PgDn', 'Fn'],
  ];

  static NAME = { '←': 'ArrowLeft', '↑': 'ArrowUp', '↓': 'ArrowDown', '→': 'ArrowRight', PgUp: 'PageUp', PgDn: 'PageDown', Esc: 'Escape' };

  draw() {
    this.el.replaceChildren();
    for (const label of KeyBar.PAGES[this.page]) {
      const b = document.createElement('button');
      b.textContent = label;
      b.type = 'button';
      const on = (label === 'Ctrl' && this.held.ctrl) || (label === 'Alt' && this.held.alt) || (label === 'Fn' && this.page === 1);
      Object.assign(b.style, {
        flex: '1 1 0', minWidth: '0', padding: '0', border: '0', borderRight: '1px solid #333', font: '13px monospace',
        color: on ? '#000' : '#aaa', background: on ? '#aaa' : '#000', touchAction: 'manipulation',
      });
      // Down, not click: the textarea keeps the focus - and the phone its
      // keyboard - and a held arrow repeats.
      b.addEventListener('pointerdown', e => {
        e.preventDefault();
        this.press(label);
        if (['←', '↑', '↓', '→', 'PgUp', 'PgDn'].includes(label)) {
          const stop = () => { clearTimeout(this.repeat); clearInterval(this.repeat); };
          stop();
          this.repeat = setTimeout(() => { this.repeat = setInterval(() => this.press(label), 60); }, 400);
          for (const ev of ['pointerup', 'pointercancel', 'pointerleave']) b.addEventListener(ev, stop, { once: true });
        }
      });
      this.el.appendChild(b);
    }
  }

  /** The keys held on the bar for the next key, which lets go of them. */
  take() {
    const m = { ...this.held };
    if (m.ctrl || m.alt) {
      this.held = { ctrl: false, alt: false };
      this.draw();
    }
    return m;
  }

  press(label) {
    if (label === 'Ctrl' || label === 'Alt') {
      const k = label.toLowerCase();
      this.held[k] = !this.held[k];
      return this.draw();
    }
    if (label === 'Fn') {
      this.page = 1 - this.page;
      return this.draw();
    }
    if (label === '⌨') {
      if (this.keyboard.open) this.keyboard.hide();
      else this.keyboard.show(false);
      return;
    }
    this.owl.press(KeyBar.NAME[label] ?? label, this.take());
    this.after();
  }
}

/**
 * Everything above on a page that run() made: the finger on the canvas,
 * the textarea, and - on a touch-first screen - the key bar. Returns what
 * run() asks about later: how tall the bar is, whether the keyboard is up,
 * and pan(), which keeps the caret above the phone's keyboard.
 */
export function attachTouch({ owl, screen, canvas, after, ended, frame, withBar, refit = () => {} }) {
  // What covers the bottom of the page, in CSS pixels: the key bar, or
  // something taller a page puts there - a DOS keyboard (setInset).
  let inset = 0;
  const bottom = () => Math.max(withBar ? KeyBar.HEIGHT : 0, inset);
  const vv = globalThis.visualViewport;
  const zoomed = () => !!vv && vv.scale > 1.02;
  const finger = new Finger(owl, { cell: p => screen.cellAt({ clientX: p.x, clientY: p.y }), cellH: screen.cellH, after, zoomed });
  let bar = null;
  const keyboard = new Keyboard(owl, { after, mods: () => bar?.take() ?? { ctrl: false, alt: false } });
  if (withBar) bar = new KeyBar(owl, { after, keyboard });
  // One finger is the core's; two are the browser's, to zoom. Zoomed in,
  // one finger may move the view as well - the Finger says when not.
  const touchAction = () => {
    const want = zoomed() ? 'pan-x pan-y pinch-zoom' : 'pinch-zoom';
    if (canvas.style.touchAction !== want) canvas.style.touchAction = want;
  };
  touchAction();
  vv?.addEventListener('resize', touchAction);

  const point = t => ({ x: t.clientX, y: t.clientY });
  // A touch that begins on a hole - an emulator's picture under a window -
  // is the hole's, all of it, when the page has said who hears it
  // (owl.holeTouch, given every touch event): DOS's touchpad.
  let hole = null;
  const onHole = t => {
    const f = frame(), c = screen.cellAt(t);
    return f && c.x >= 0 && c.y >= 0 && c.x < f.w && c.y < f.h && f.isHole(c.x, c.y);
  };
  canvas.addEventListener('touchstart', e => {
    if (ended()) return;
    if (!hole && owl.holeTouch && e.touches.length === 1 && onHole(e.touches[0])) {
      finger.cancel();
      hole = owl.holeTouch;
    }
    if (hole) return hole.touch(e);
    if (e.touches.length > 1) return finger.cancel();
    finger.down(point(e.touches[0]));
  }, { passive: true });
  canvas.addEventListener('touchmove', e => {
    if (ended()) return;
    if (hole) {
      e.preventDefault();
      return hole.touch(e);
    }
    if (e.touches.length > 1) return;
    if (finger.move(point(e.touches[0]))) e.preventDefault();
  }, { passive: false });
  canvas.addEventListener('touchend', e => {
    if (ended()) return;
    e.preventDefault(); // no made-up mouse events after it, no click
    if (hole) {
      hole.touch(e);
      if (!e.touches.length) hole = null;
      return;
    }
    if (e.touches.length) return;
    const what = finger.up(e.timeStamp);
    if (what !== 'tap') return;
    // A tap where the core now shows a caret is a tap into something to
    // type in: the phone's keyboard comes up. A tap anywhere else puts
    // away a keyboard that came up that way - not one asked for with ⌨.
    const f = frame();
    if (f && f.cursorX >= 0) keyboard.show(true);
    else if (keyboard.auto) keyboard.hide();
  }, { passive: false });
  canvas.addEventListener('touchcancel', e => {
    if (hole) {
      hole.touch(e);
      if (!e.touches.length) hole = null;
      return;
    }
    finger.cancel();
  });

  // The phone's keyboard covers the bottom of the page. The desktop keeps
  // its size - windows do not jump every time it comes up - and the
  // canvas slides up as far as the caret needs, the key bar riding on top
  // of the keyboard. Not while the page is pinched bigger: that view is
  // the person's.
  let shift = 0;
  // Elements along the bottom that ride on the phone's keyboard too.
  const riders = new Set();
  function pan() {
    if (!vv) return;
    const barH = bottom();
    const zoomed = Math.abs(vv.scale - 1) > 0.01;
    const seen = vv.offsetTop + vv.height; // the bottom of what is in sight
    if (bar) bar.el.style.transform = zoomed ? '' : `translateY(${-(window.innerHeight - seen)}px)`;
    for (const el of riders) el.style.transform = zoomed ? '' : `translateY(${-(window.innerHeight - seen)}px)`;
    let want = 0;
    const f = frame();
    if (!zoomed && keyboard.open && f && f.cursorY >= 0) {
      const top = canvas.getBoundingClientRect().top + shift;
      const caretBottom = top + (f.cursorY + 1) * screen.cellH;
      want = Math.max(0, caretBottom - (seen - barH) + 4);
    }
    if (want !== shift) {
      shift = want;
      canvas.style.transform = shift ? `translateY(${-shift}px)` : '';
    }
  }
  vv?.addEventListener('resize', pan);
  vv?.addEventListener('scroll', pan);
  keyboard.area.addEventListener('blur', () => pan());
  keyboard.area.addEventListener('focus', () => pan());

  return {
    /** How much of the bottom of the page is covered: the screen is fitted above it. */
    bottom,
    /** An element of the page's along the bottom, kept above the phone's keyboard. */
    ride(el) { riders.add(el); pan(); },
    /**
     * Something of the page's own along the bottom, px tall - a DOS keyboard -
     * and whether the key bar shows meanwhile; the screen is fitted above it.
     */
    setInset(px, keyBar = px === 0) {
      if (bar) bar.el.style.display = keyBar ? 'flex' : 'none';
      if (px === inset) return;
      inset = px;
      // Not inside the paint that may have asked: after it.
      queueMicrotask(refit);
    },
    keyboardOpen: () => keyboard.open,
    pan,
    finger,
    keyboard,
    bar,
  };
}
