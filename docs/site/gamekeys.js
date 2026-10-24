// A game's own pad under DOS on a phone.
//
// OWLOSUI puts a whole PC keyboard under DOS on a touch screen (its
// dosbox/doskeys.js) - right for a prompt or a menu, wrong for a flight:
// a pilot needs a stick under the left thumb and big buttons under the
// right, held together. This is that pad, one layout a game, made from
// what each game's code reads (the scan-code survey, 2026-10-24).
//
// It takes DosKeys' place in the library's DosBox (box.keys, which the box
// makes only if there is none: `this.keys ??= new DosKeys(this)`), and keeps
// a DosKeys inside it: in a TEXT mode - a menu, the commander, a name to
// type - that whole keyboard shows; in a picture mode the game's pad does.
// ⌨ on the pad swaps them by hand. Keys go down when the finger does and
// up when it lifts, straight into the emulator; any number of fingers.
// Same height as DosKeys, so the library's inset for it stays right.

import { DosKeys, GLFW } from '../owlosui/dosbox/doskeys.js';

const H = DosKeys.HEIGHT;            // 204 px: what the library keeps free under DOS

// ---- the layouts ----------------------------------------------------------
// A button: [label, keys, wide?]  keys = 'space' or 'alt+q' (held together)
// A page: { stick: 'arrows' | 'wasd' | null, pad: true (taps, not a stick),
//           right: [buttons], top: [buttons], go: { label: page } }
// A button whose keys start with '>' switches the pad to that page; '>x:tab'
// switches AND presses F8 (OWL FLY III's seat change; F8 because a browser may eat Tab).
const FLY_TOP1 = [['MFD', 'm'], ['F2', 'f2'], ['F3', 'f3'], ['F4', 'f4'], ['F5', 'f5'], ['Night', 'n'], ['Snd', 'v']];
const OWL2_RIGHT = [['FIRE', 'space', 2], ['MSL', 'backspace'], ['LOCK', 'enter'],
  ['THR+', 'w'], ['THR-', 's'], ['A/B', 'a'], ['FLAP', 'f'],
  ['◄RUD', '1'], ['RUD►', '3'], ['GEAR', 'l'], ['BRK', 'b']];
const OWL2_TOP = [['MFD', 'm'], ['Z', 'z'], ['X', 'x'], ['F3', 'f3'], ['F4', 'f4'], ['Quit', 'alt+q'], ['More', '>panel']];
const OWL_PANEL = { stick: 'arrows', right: [['G', 'g'], ['U', 'u'], ['I', 'i'], ['T', 't'], ['O', 'o'], ['P', 'p'],
  ['R', 'r'], ['J', 'j'], ['Y', 'y'], ['FIRE', 'space', 2], ['Fly', '>fly']],
  top: [['F2', 'f2'], ['F5', 'f5'], ['F6', 'f6'], ['F7', 'f7'], ['Night', 'n'], ['Snd', 'v'], ['Fly', '>fly']] };

export const LAYOUTS = {
  owlfly: { fly: { stick: 'arrows',
    right: [['FIRE', 'space', 2], ['MSL', 'backspace'], ['LOCK', 'enter'], ['THR+', 'w'], ['THR-', 's'], ['A/B', 'a'],
      ['◄RUD', 'q'], ['RUD►', 'e']],
    top: [...FLY_TOP1, ['Esc', 'esc']] } },
  owlfly2: { fly: { stick: 'arrows', right: OWL2_RIGHT, top: OWL2_TOP }, panel: OWL_PANEL },
  owlfly3: {
    fly: { stick: 'arrows', right: OWL2_RIGHT, top: [['Pause', 'esc'], ['Seat', '>shilka:f8'], ...OWL2_TOP.filter(b => b[0] !== 'Z' && b[0] !== 'X')] },
    shilka: { stick: 'arrows', stick2: 'wasd', names: ['HULL', 'TURRET'],
      right: [['FIRE', 'space', 2], ['F3', 'f3'], ['Z', 'z'], ['Q', 'q'], ['E', 'e'], ['X', 'x']],
      top: [['Pause', 'esc'], ['Seat', '>fly:f8'], ['Quit', 'alt+q']] },
    panel: OWL_PANEL,
  },
  trainer: { fly: { stick: 'arrows',
    right: [['THR+', 'w', 2], ['THR-', 's'], ['◄RUD', 'z'], ['RUD►', 'c'], ['FLAP', 'f'], ['GEAR', 'g'], ['BRK', 'b'],
      ['LOOK', 'shift'], ['VIEW', 'v']],
    top: [['Again', 'r'], ['Canopy', 'o'], ['Esc', 'esc']] } },
  wirecity: { fly: { stick: 'arrows', right: [['AGAIN', 'space', 2]], top: [['Esc', 'esc']] } },
  multsoko: { walk: { stick: 'arrows', pad: true,
    right: [['MINE', 'space', 2], ['⟲', 'q'], ['⟳', 'e'], ['ISO', 'v'], ['ZOOM', 'z']],
    top: [['Again R', 'r'], ['Next N', 'n'], ['Prev P', 'p'], ['Esc', 'esc']] } },
  // EGA 640x200 reaches the page as 640x400, the size of a text mode: here it is the game.
  multsoko2: { tall: true, walk: { stick: 'arrows', pad: true,
    right: [['UNDO', 'u', 2], ['MINE', 'space'], ['⟲', 'q'], ['⟳', 'e'], ['ISO', 'v'], ['ZOOM', 'z'], ['ENTER', 'enter']],
    top: [['1', '1'], ['2', '2'], ['3', '3'], ['4', '4'], ['5', '5'], ['R', 'r'], ['N', 'n'], ['P', 'p'], ['Esc', 'esc']] } },
  owlnight: { room: { stick: 'arrows', pad: true,
    right: [['CLICK', 'enter', 2], ['SKIP', 'esc'], ['QUIT', 'q']],
    top: [['1', '1'], ['2', '2'], ['3', '3'], ['4', '4'], ['5', '5'], ['6', '6'], ['7', '7'], ['8', '8'], ['9', '9']] } },
  // Any other program in a picture mode: a lesson, an example, a model's game.
  any: { play: { stick: 'arrows', right: [['SPACE', 'space', 2], ['ENTER', 'enter'], ['ESC', 'esc']], top: [] } },
};

const STICKS = { arrows: ['up', 'down', 'left', 'right'], wasd: ['w', 's', 'a', 'd'] };

/** The pad, in DosKeys' place: box.keys = new GameKeys(box). */
export class GameKeys {
  constructor(box) {
    this.box = box;
    this.full = new DosKeys(box);    // the whole keyboard, for text modes and ⌨
    this.held = new Map();           // a key's code -> how many fingers hold it
    this.fingers = new Map();        // pointerId -> the codes that finger holds
    this.on = false;                 // the library wants a keyboard shown
    this.forced = false;             // ⌨: the whole keyboard by hand
    this.setGame(null);
    const el = (this.el = document.createElement('div'));
    el.dataset.owlOwnKeys = '';
    el.dataset.owlDosKeys = '';
    Object.assign(el.style, {
      position: 'fixed', left: '0', right: '0', bottom: '0', height: H + 'px', display: 'none',
      flexDirection: 'column', background: '#0c0c10', zIndex: '11', touchAction: 'none', userSelect: 'none',
      webkitUserSelect: 'none', borderTop: '1px solid #444', font: '12px monospace', color: '#ddd',
    });
    document.body.appendChild(el);
    box.owl.touch?.ride(el);
    // The picture's mode decides between the pad and the whole keyboard.
    box.on(what => { if (what === 'frame' || what === 'started') this.apply(); if (what === 'stopped') this.letGo(); });
    addEventListener('resize', () => { this.h = 0; this.apply(); });
    this.render();
  }

  /** The game the machine runs now (a GAMES key), or null for anything else. */
  setGame(key) {
    this.game = key && LAYOUTS[key] ? key : null;
    const l = LAYOUTS[this.game ?? 'any'];
    this.tall = !!l.tall;
    this.pages = Object.fromEntries(Object.entries(l).filter(([k]) => k !== 'tall'));
    this.page = Object.keys(this.pages)[0];
    this.forced = false;
    if (this.el) { this.letGo(); this.render(); this.apply(); }
  }

  get shown() { return this.el.style.display !== 'none' || this.full.shown; }

  /** The library: show a keyboard, or none (another window over DOS). */
  show(on) { this.on = on; this.apply(); }

  /** A text mode - a menu, the commander, a name - wants the whole keyboard. */
  textMode() {
    const f = this.box.frameSize;
    if (!f) return true;
    return f.h >= 400 && f.w >= 640 && !this.tall;
  }

  /** The pad's height: the room left under DOS's window (a phone held upright has plenty), 204..360 px. */
  fit() {
    const r = this.box.el?.getBoundingClientRect();
    const h = Math.max(H, Math.min(360, Math.floor(innerHeight - (r?.bottom ?? innerHeight) - 22)));
    if (h === this.h) return;
    this.h = h;
    this.el.style.height = h + 'px';
    this.render();
  }

  apply() {
    const pad = this.on && !this.forced && !this.textMode();
    const full = this.on && !pad;
    if (!pad && this.el.style.display !== 'none') this.letGo();
    this.el.style.display = pad ? 'flex' : 'none';
    if (pad) this.fit();
    this.full.show(full);
    this.full.el.querySelector('[data-key="gamepad"]')?.remove();
    if (full && this.game !== null || full && this.forced) this.addBackKey();
  }

  /** On the whole keyboard, a key back to the game's pad. */
  addBackKey() {
    const row = this.full.el.firstElementChild;
    if (!row || row.querySelector('[data-key="gamepad"]')) return;
    const b = document.createElement('button');
    b.type = 'button';
    b.textContent = '🎮';
    b.dataset.key = 'gamepad';
    Object.assign(b.style, { flex: '1.2 1 0', minWidth: '0', margin: '1px', border: '1px solid #555', borderRadius: '3px',
      background: '#335', color: '#fff', font: '12px monospace', touchAction: 'none' });
    b.addEventListener('pointerdown', e => { e.preventDefault(); this.forced = false; this.apply(); });
    row.prepend(b);
  }

  // ---- keys into the emulator, counted so two fingers on one key are fine
  press(code) {
    const n = this.held.get(code) ?? 0;
    this.held.set(code, n + 1);
    if (!n) this.box.ci?.sendKeyEvent(code, true);
  }
  release(code) {
    const n = this.held.get(code) ?? 0;
    if (n <= 1) { this.held.delete(code); if (n) this.box.ci?.sendKeyEvent(code, false); }
    else this.held.set(code, n - 1);
  }
  /** This finger now holds exactly these codes (a stick slid to a new place). */
  hold(finger, codes) {
    const was = this.fingers.get(finger) ?? [];
    for (const c of was) if (!codes.includes(c)) this.release(c);
    for (const c of codes) if (!was.includes(c)) this.press(c);
    if (codes.length) this.fingers.set(finger, codes); else this.fingers.delete(finger);
    this.light();
  }
  letGo() {
    for (const [code] of this.held) this.box.ci?.sendKeyEvent(code, false);
    this.held.clear();
    this.fingers.clear();
    this.light?.();
  }

  codes(keys) { return keys.split('+').map(k => GLFW[k]).filter(c => c !== undefined); }

  // ---- drawing --------------------------------------------------------------
  render() {
    const el = this.el;
    if (!el) return;
    el.replaceChildren();
    const p = this.pages[this.page];
    const top = document.createElement('div');
    Object.assign(top.style, { display: 'flex', height: '30px', flex: '0 0 30px' });
    for (const b of p.top) top.appendChild(this.button(b, true));
    top.appendChild(this.button(['⌨', '#keyboard'], true));
    el.appendChild(top);
    const body = document.createElement('div');
    Object.assign(body.style, { display: 'flex', flex: '1 1 0', minHeight: '0' });
    // Two sticks (the Shilka: hull and turret) share the width with a narrow
    // column of buttons between them; one stick leaves four columns.
    const tall = (this.h || H) - 36;
    const two = !!p.stick2, side = two ? Math.min(tall, Math.floor((innerWidth - 104) / 2)) : Math.min(tall, Math.floor(innerWidth * 0.48));
    if (p.stick) body.appendChild(this.stick(STICKS[p.stick], p.pad, side, p.names?.[0]));
    const right = document.createElement('div');
    Object.assign(right.style, { flex: '1 1 0', display: 'grid', gridTemplateColumns: `repeat(${two ? 2 : 4}, 1fr)`, gridAutoRows: '1fr', gap: '3px', padding: '3px' });
    for (const b of p.right) right.appendChild(this.button(b));
    body.appendChild(right);
    if (p.stick2) body.appendChild(this.stick(STICKS[p.stick2], false, side, p.names?.[1]));
    el.appendChild(body);
    this.light();
  }

  /** A stick: a 3x3 field; where the finger is says which keys are down, as it slides. */
  stick([up, down, left, right], pad, side = H - 36, name = '') {
    const s = document.createElement('div');
    Object.assign(s.style, { flex: `0 0 ${side}px`, height: side + 'px', margin: '3px', alignSelf: 'center', position: 'relative', borderRadius: pad ? '8px' : '50%',
      background: 'radial-gradient(circle, #2a2a38 0%, #15151c 70%)', border: '1px solid #445', touchAction: 'none' });
    for (const [t, x, y] of [['▲', 50, 12], ['▼', 50, 88], ['◄', 12, 50], ['►', 88, 50], [name, 50, 50]]) {
      const m = document.createElement('div');
      m.textContent = t;
      Object.assign(m.style, { position: 'absolute', left: x + '%', top: y + '%', transform: 'translate(-50%,-50%)', color: '#889', fontSize: '18px', pointerEvents: 'none' });
      s.appendChild(m);
    }
    const where = e => {
      const r = s.getBoundingClientRect();
      const fx = (e.clientX - r.left) / r.width, fy = (e.clientY - r.top) / r.height;
      // A pad (the Soko games, a cursor) takes ONE direction - the nearer
      // axis; a stick takes diagonals too (pitch and roll at once).
      const dx = fx - 0.5, dy = fy - 0.5, dead = 0.14;
      const k = [];
      if (pad) {
        if (Math.hypot(dx, dy) < dead) return k;
        if (Math.abs(dx) > Math.abs(dy)) k.push(dx < 0 ? left : right); else k.push(dy < 0 ? up : down);
        return k;
      }
      if (dy < -dead) k.push(up); else if (dy > dead) k.push(down);
      if (dx < -dead) k.push(left); else if (dx > dead) k.push(right);
      return k;
    };
    s.addEventListener('pointerdown', e => {
      e.preventDefault();
      try { s.setPointerCapture(e.pointerId); } catch { /* a made-up pointer */ }
      this.hold(e.pointerId, where(e).map(n => GLFW[n]));
      navigator.vibrate?.(8);
    });
    s.addEventListener('pointermove', e => {
      if (!this.fingers.has(e.pointerId) && !(e.buttons || e.pressure)) return;
      if (pad) return;                // a pad steps once per touch: no slide
      this.hold(e.pointerId, where(e).map(n => GLFW[n]));
    });
    const lift = e => this.hold(e.pointerId, []);
    s.addEventListener('pointerup', lift);
    s.addEventListener('pointercancel', lift);
    return s;
  }

  button([label, keys, wide = 1], small = false) {
    const b = document.createElement('button');
    b.type = 'button';
    b.textContent = label;
    b.dataset.keys = keys;
    Object.assign(b.style, {
      minWidth: '0', margin: small ? '2px' : '0', padding: '0', border: '1px solid #3a3a48', borderRadius: small ? '4px' : '10px',
      font: small ? '11px monospace' : 'bold 14px monospace', color: '#e8e8f0', touchAction: 'none',
      background: keys === 'space' || label === 'FIRE' ? '#5a1f1f' : small ? '#1c1c24' : '#262634',
      ...(small ? { flex: '1 1 0' } : { gridColumn: `span ${wide}` }),
    });
    b.addEventListener('pointerdown', e => {
      e.preventDefault();
      if (keys === '#keyboard') { this.letGo(); this.forced = true; this.apply(); return; }
      if (keys.startsWith('>')) {
        const [page, also] = keys.slice(1).split(':');
        if (also) { const c = this.codes(also); c.forEach(x => this.box.ci?.sendKeyEvent(x, true)); setTimeout(() => c.forEach(x => this.box.ci?.sendKeyEvent(x, false)), 60); }
        this.letGo();
        if (this.pages[page]) { this.page = page; this.render(); }
        return;
      }
      try { b.setPointerCapture(e.pointerId); } catch { /* a made-up pointer */ }
      this.hold(e.pointerId, this.codes(keys));
      navigator.vibrate?.(8);
    });
    const up = e => { if (this.fingers.has(e.pointerId)) this.hold(e.pointerId, []); };
    b.addEventListener('pointerup', up);
    b.addEventListener('pointercancel', up);
    return b;
  }

  /** Buttons whose keys are down, lit. */
  light() {
    if (!this.el) return;
    for (const b of this.el.querySelectorAll('button[data-keys]')) {
      const k = b.dataset.keys;
      if (k.startsWith('>') || k.startsWith('#')) continue;
      const down = this.codes(k).every(c => this.held.has(c));
      b.style.outline = down ? '2px solid #ffd860' : 'none';
    }
  }
}
