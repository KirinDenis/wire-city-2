// DOS under a finger: a PC keyboard drawn along the bottom of a phone's
// screen, and the DOS picture used as a touchpad.
//
// A DOS program wants keys a phone's keyboard has not got - Esc, the
// function keys, Ctrl, the arrows - and it wants them held: a game reads
// an arrow for as long as it is down. So these keys go down when the
// finger does and up when it lifts, straight into the emulator, and
// several fingers can hold several at once. Shift, Ctrl and Alt are
// tapped before the key they go with - once for the next key, twice to
// stay down until tapped again - or held while it is tapped.
//
// ⌨ brings up the phone's own keyboard for typing words: what it types
// goes to DOS as the keys a US keyboard would press for it.
//
// The mouse: a DOS mouse moves by how far it is pushed, not to where it is
// pointed, so the picture is a touchpad, as on a laptop. A finger slid
// over it moves the pointer; a tap is a click; a tap with two fingers is
// the right button; held still and then slid, it drags with the button down.

import { typedBetween, HOLD_MS, SLOP_PX } from '../touch.js';

/** js-dos's key numbers, which are GLFW's. */
export const GLFW = {
  space: 32, "'": 39, ',': 44, '-': 45, '.': 46, '/': 47, ';': 59, '=': 61, '[': 91, '\\': 92, ']': 93, '`': 96,
  esc: 256, enter: 257, tab: 258, backspace: 259, insert: 260, delete: 261, right: 262, left: 263, down: 264, up: 265,
  pgup: 266, pgdn: 267, home: 268, end: 269, shift: 340, ctrl: 341, alt: 342,
};
for (let i = 0; i < 26; i++) GLFW[String.fromCharCode(97 + i)] = 65 + i;
for (let i = 0; i < 10; i++) GLFW[String(i)] = 48 + i;
for (let i = 1; i <= 12; i++) GLFW['f' + i] = 289 + i;

/** What Shift makes of a key on a US keyboard: '!' is Shift and 1. */
const SHIFTED = { '!': '1', '@': '2', '#': '3', $: '4', '%': '5', '^': '6', '&': '7', '*': '8', '(': '9', ')': '0',
  _: '-', '+': '=', '{': '[', '}': ']', '|': '\\', ':': ';', '"': "'", '<': ',', '>': '.', '?': '/', '~': '`' };

/**
 * A character typed into the keys that type it: { code, shift }, or null
 * for one a PC keyboard has no key for.
 */
export function keyFor(ch) {
  if (ch === '\n') return { code: GLFW.enter, shift: false };
  if (ch === ' ') return { code: GLFW.space, shift: false };
  if (ch === '\t') return { code: GLFW.tab, shift: false };
  if (/^[a-z0-9]$/.test(ch) || ch in GLFW && ch.length === 1) return { code: GLFW[ch], shift: false };
  if (/^[A-Z]$/.test(ch)) return { code: GLFW[ch.toLowerCase()], shift: true };
  if (ch in SHIFTED) return { code: GLFW[SHIFTED[ch]], shift: true };
  return null;
}

/** The rows, as on a PC; a key is its label, or [label, name, width]. */
const ROWS = [
  ['Esc', 'F1', 'F2', 'F3', 'F4', 'F5', 'F6', 'F7', 'F8', 'F9', 'F10', 'F11', 'F12'],
  ['`', '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', ['⌫', 'backspace', 1.4]],
  [['Tab', 'tab', 1.3], 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', '\\'],
  [['Ctrl', 'ctrl', 1.5], 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', "'", ['Enter', 'enter', 1.8]],
  [['Shift', 'shift', 1.8], 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', ['↑', 'up'], ['Del', 'delete']],
  [['Alt', 'alt', 1.3], ['⌨', 'phone'], ['', 'space', 3.5], ['Ins', 'insert'], ['Home', 'home', 1.2], ['End', 'end'],
    ['PgUp', 'pgup', 1.2], ['PgDn', 'pgdn', 1.2], ['←', 'left'], ['↓', 'down'], ['→', 'right']],
];

const MODS = ['shift', 'ctrl', 'alt'];

/** The keyboard: an element along the bottom, sending to a DosBox's machine. */
export class DosKeys {
  static HEIGHT = 6 * 34;

  constructor(box) {
    this.box = box;
    // 0 up, 1 down for the next key, 2 down until tapped again; and which
    // of them a finger is holding down right now.
    this.mods = { shift: 0, ctrl: 0, alt: 0 };
    this.fingers = new Map();
    const el = (this.el = document.createElement('div'));
    // Its keys are DOS's: the page's own keydown leaves them alone.
    el.dataset.owlOwnKeys = '';
    el.dataset.owlDosKeys = '';
    Object.assign(el.style, {
      position: 'fixed', left: '0', right: '0', bottom: '0', height: DosKeys.HEIGHT + 'px', display: 'none',
      flexDirection: 'column', background: '#111', zIndex: '11', touchAction: 'none', userSelect: 'none',
      webkitUserSelect: 'none', borderTop: '1px solid #555',
    });
    for (const row of ROWS) {
      const r = document.createElement('div');
      Object.assign(r.style, { display: 'flex', flex: '1 1 0', minHeight: '0' });
      for (const k of row) r.appendChild(this.key(...(Array.isArray(k) ? k : [k, k.toLowerCase()])));
      el.appendChild(r);
    }
    // The phone's own keyboard, for words: a textarea nobody sees.
    const ta = (this.area = document.createElement('textarea'));
    for (const [k, v] of Object.entries({ autocapitalize: 'off', autocomplete: 'off', autocorrect: 'off', spellcheck: 'false', 'aria-label': 'Keyboard for DOS' })) ta.setAttribute(k, v);
    ta.dataset.owlOwnKeys = '';
    Object.assign(ta.style, { position: 'fixed', left: '0', top: '0', width: '1px', height: '1px', opacity: '0', border: '0',
      padding: '0', fontSize: '16px', zIndex: '-1', pointerEvents: 'none' });
    this.base = '  ';
    ta.value = this.base;
    ta.addEventListener('input', () => this.typed());
    el.appendChild(ta);
    document.body.appendChild(el);
    // Above the phone's keyboard when ⌨ brings it up, as the key bar is.
    box.owl.touch?.ride(el);
    ta.addEventListener('focus', () => box.owl.touch?.pan());
    ta.addEventListener('blur', () => box.owl.touch?.pan());
  }

  key(label, name, width = 1) {
    const b = document.createElement('button');
    b.type = 'button';
    b.textContent = label;
    b.dataset.key = name;
    Object.assign(b.style, {
      flex: `${width} 1 0`, minWidth: '0', margin: '1px', padding: '0', border: '1px solid #333', borderRadius: '3px',
      font: '12px monospace', color: '#ccc', background: '#222', touchAction: 'none',
    });
    b.addEventListener('pointerdown', e => {
      e.preventDefault();
      // Its release comes here even if the finger slid off the key.
      try { b.setPointerCapture(e.pointerId); } catch { /* a pointer the page made up */ }
      this.down(name, e.pointerId);
    });
    const up = e => this.up(name, e.pointerId);
    b.addEventListener('pointerup', up);
    b.addEventListener('pointercancel', up);
    return b;
  }

  get shown() { return this.el.style.display !== 'none'; }

  show(on) {
    const want = on ? 'flex' : 'none';
    if (this.el.style.display === want) return;
    this.el.style.display = want;
    if (!on) {
      this.letGo();
      if (document.activeElement === this.area) this.area.blur();
    }
  }

  send(code, down) { this.box.ci?.sendKeyEvent(code, down); }

  down(name, finger) {
    if (name === 'phone') {
      if (document.activeElement === this.area) this.area.blur();
      else this.area.focus({ preventScroll: true });
      return;
    }
    if (MODS.includes(name)) {
      // Held: down now, for the keys tapped while it is. Tapped: see up().
      this.fingers.set(finger, { name, at: performance.now(), mod: true, used: false });
      this.send(GLFW[name], true);
      return;
    }
    // The modifiers waiting for this key go down first.
    for (const m of MODS) if (this.mods[m] && !this.heldByFinger(m)) this.send(GLFW[m], true);
    for (const f of this.fingers.values()) if (f.mod) f.used = true;
    this.fingers.set(finger, { name });
    this.send(GLFW[name], true);
  }

  up(name, finger) {
    const f = this.fingers.get(finger);
    if (!f) return;
    this.fingers.delete(finger);
    if (f.mod) {
      this.send(GLFW[name], false);
      // Held while another key was tapped: done. Tapped by itself: the
      // next key gets it; tapped again, it stays; a third time, off.
      if (!f.used) this.mods[name] = (this.mods[name] + 1) % 3;
      return this.paint();
    }
    this.send(GLFW[name], false);
    for (const m of MODS) {
      if (!this.mods[m] || this.heldByFinger(m)) continue;
      this.send(GLFW[m], false);
      if (this.mods[m] === 1) this.mods[m] = 0;
    }
    this.paint();
  }

  heldByFinger(m) {
    for (const f of this.fingers.values()) if (f.mod && f.name === m) return true;
    return false;
  }

  /** Everything held let go: the keyboard is put away, or DOS stopped. */
  letGo() {
    for (const [, f] of this.fingers) this.send(GLFW[f.name], false);
    this.fingers.clear();
    for (const m of MODS) this.mods[m] = 0;
    this.paint();
  }

  paint() {
    const shift = !!this.mods.shift;
    for (const b of this.el.querySelectorAll('button')) {
      const name = b.dataset.key;
      const lit = MODS.includes(name) && this.mods[name];
      b.style.background = lit === 2 ? '#aaa' : lit ? '#555' : '#222';
      b.style.color = lit === 2 ? '#000' : '#ccc';
      if (name.length === 1 && /[a-z]/.test(name)) b.textContent = shift ? name.toUpperCase() : name;
    }
  }

  /** What the phone's keyboard typed, pressed as keys. */
  async typed() {
    const now = this.area.value;
    const { back, text } = typedBetween(this.base, now);
    this.base = now;
    const tap = async (code, shift) => {
      if (shift) this.send(GLFW.shift, true);
      this.send(code, true);
      await new Promise(r => setTimeout(r, 20));
      this.send(code, false);
      if (shift) this.send(GLFW.shift, false);
    };
    for (let i = 0; i < back; i++) await tap(GLFW.backspace, false);
    for (const ch of text) {
      const k = keyFor(ch);
      if (k) await tap(k.code, k.shift);
    }
    if (now !== '  ') {
      this.area.value = this.base = '  ';
    }
  }
}

/**
 * The DOS picture as a touchpad. touch(e) is given every touch event of a
 * gesture that began on the picture (see touch.js, owl.holeTouch).
 */
export class Trackpad {
  constructor(box, { speed = 1.5 } = {}) {
    this.box = box;
    this.speed = speed;
    this.reset();
  }

  reset() {
    this.start = null;
    this.last = null;
    this.most = 0;
    this.moved = false;
    this.dragging = false;
    clearTimeout(this.timer);
  }

  /** DOS pixels for a CSS pixel: the picture may be shown at any size. */
  scale() {
    const el = this.box.screenEl;
    const w = el?.getBoundingClientRect().width || 640;
    return (this.box.frameSize?.w ?? 640) / w * this.speed;
  }

  touch(e) {
    const ci = this.box.ci;
    if (!ci) return;
    const t = e.touches[0] ?? e.changedTouches[0];
    if (e.type === 'touchstart') {
      this.most = Math.max(this.most, e.touches.length);
      if (e.touches.length > 1) return;
      this.reset();
      this.most = 1;
      this.start = this.last = { x: t.clientX, y: t.clientY, t: performance.now() };
      // Held still: the button goes down, and the slide that follows drags.
      this.timer = setTimeout(() => {
        if (this.moved) return;
        this.dragging = true;
        ci.sendMouseButton(0, true);
        globalThis.navigator?.vibrate?.(15);
      }, HOLD_MS);
      return;
    }
    if (e.type === 'touchmove') {
      if (!this.last || e.touches.length > 1) return;
      const dx = t.clientX - this.last.x, dy = t.clientY - this.last.y;
      if (!this.moved && Math.hypot(t.clientX - this.start.x, t.clientY - this.start.y) > SLOP_PX) {
        this.moved = true;
        if (!this.dragging) clearTimeout(this.timer);
      }
      if (this.moved) {
        const k = this.scale();
        ci.sendMouseRelativeMotion(dx * k, dy * k);
      }
      this.last = { x: t.clientX, y: t.clientY };
      return;
    }
    // touchend, touchcancel: when the last finger is off.
    if (e.touches.length) return;
    clearTimeout(this.timer);
    if (this.dragging) ci.sendMouseButton(0, false);
    else if (this.start && !this.moved && e.type === 'touchend') {
      const button = this.most >= 2 ? 1 : 0;
      ci.sendMouseButton(button, true);
      setTimeout(() => ci.sendMouseButton(button, false), 40);
    }
    this.reset();
  }
}
