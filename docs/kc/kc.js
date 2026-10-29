// Kirin Commander in a browser page: kc.wasm (web/src/lib.rs) on a
// canvas, its file system the page's drives.
//
//   const kc = await Commander.start(canvas, { drives, run });
//
// drives: the drive table - objects as WIRE CITY's Drive is (site/drives.js):
//   { letter, title, kind, readOnly, list(dir), readBytes(path),
//     write(path, bytes), remove(path), mkdir(path), rename(from, to) }
//   paths /folder/file, folders ending in /; a list entry is
//   { name, dir, size, date }. The same array the page keeps: a drive
//   added there is in Alt+F1 the next time it opens.
// run(dir, line): a command line, in the console the page has (WIRE
//   CITY's); resolves to what it printed. Without one the commander runs
//   the line itself: DIR, TYPE, COPY, DEL, REN, MD, RD on these drives
//   (kc/src/shell.rs).
//
// The screen is OWLOSUI's own canvas Screen, so a frame looks exactly as
// every OWLOSUI window does; the frame comes in OWLOSUI's FRAME layout and
// is read with its Frame.

import { Frame, Screen } from './owlosui/owlosui.js';

const FIELD = '\x1F', RECORD = '\x1E';
const utf8 = new TextEncoder(), text = new TextDecoder();

// The kinds of error, in the order of ErrorKind (kc/src/fs.rs).
const KIND = { NotFound: 0, Exists: 1, Denied: 2, ReadOnly: 3, NotEmpty: 4, DiskFull: 5, NotReady: 6, WriteProtected: 7,
  InUse: 8, BadName: 9, CrossDevice: 10, IntoItself: 11, Unsupported: 12, Io: 13 };

class FsFailure extends Error {
  constructor(kind, words = '') { super(words || kind); this.kind = kind; }
}

/** A browser's error as one of the commander's kinds (docs/06-file-systems.md, 6.4). */
export function kindOf(e) {
  if (e instanceof FsFailure) return e.kind;
  const m = String(e?.message ?? e);
  switch (e?.name) {
    case 'NotFoundError': return 'NotFound';
    case 'TypeMismatchError': return 'NotFound';
    case 'QuotaExceededError': return 'DiskFull';
    case 'InvalidModificationError': return 'NotEmpty';
    case 'NoModificationAllowedError': return 'InUse';
    case 'NotAllowedError': case 'SecurityError': return 'Denied';
    case 'AbortError': return 'Io';
    case 'TypeError': return /name/i.test(m) ? 'BadName' : 'Io';
  }
  if (/read-only|readonly/i.test(m)) return 'WriteProtected';
  if (/cannot rename/i.test(m)) return 'Unsupported';
  if (/not running|no dos/i.test(m)) return 'NotReady';
  return 'Io';
}

const ok = (payload = new Uint8Array(0)) => {
  const p = typeof payload === 'string' ? utf8.encode(payload) : payload;
  const out = new Uint8Array(p.length + 1);
  out.set(p, 1);
  return out;
};
const failed = e => {
  const words = utf8.encode(String(e?.message ?? e).slice(0, 200));
  const out = new Uint8Array(words.length + 2);
  out[0] = 1;
  out[1] = KIND[kindOf(e)] ?? KIND.Io;
  out.set(words, 2);
  return out;
};

const two = n => String(n);
function stampOf(date) {
  if (!(date instanceof Date) || isNaN(date)) return '';
  return [date.getFullYear(), date.getMonth() + 1, date.getDate(), date.getHours(), date.getMinutes(), date.getSeconds()].map(two).join(',');
}
const entryText = e => [e.name, e.dir ? '1' : '0', e.dir ? 0 : (e.size ?? 0), stampOf(e.date), e.attrs ?? 0].join(FIELD);

/**
 * The page's drives as the commander's `Fs`: one call a number, as
 * web/src/lib.rs makes them. What can answer at once - a read from a file
 * already in memory, the clock - answers at once; the rest is a promise.
 *
 * A file is read whole when it is opened and written whole when it is
 * closed: the drives of a page have no file opened in parts (6.5).
 */
export class WebFs {
  constructor(drives, { current = null, setupKey = 'kc.ini' } = {}) {
    this.drives = drives;
    this.current = current;
    this.setupKey = setupKey;
    this.open = new Map();
    this.next = 1;
  }

  /** `D:\GAMES\X` as its drive and the drive's own path, /GAMES/X. */
  where(path) {
    const m = /^([A-Za-z]):\\?(.*)$/.exec(path);
    if (!m) throw new FsFailure('NotFound', `no drive in ${path}`);
    const drive = this.drives.find(d => d.letter.toUpperCase() === m[1].toUpperCase());
    if (!drive) throw new FsFailure('NotReady', `no drive ${m[1]}:`);
    const parts = m[2].split('\\').filter(Boolean);
    return { drive, parts, path: '/' + parts.join('/') };
  }

  /**
   * A path as the storage spells it: DOS names are case-blind, the
   * storage is not (6.2) - each folder of the path found as it is
   * written, else by its name in any case.
   */
  async spelled(drive, parts) {
    let dir = '/';
    const out = [];
    for (let i = 0; i < parts.length; i++) {
      const want = parts[i];
      const list = await drive.list(dir);
      const hit = list.find(e => e.name === want) ?? list.find(e => e.name.toUpperCase() === want.toUpperCase());
      if (!hit) return { found: false, path: dir + parts.slice(i).join('/'), dir, rest: parts.slice(i) };
      out.push(hit.name);
      dir = '/' + out.join('/') + (hit.dir ? '/' : '');
      if (!hit.dir && i < parts.length - 1) throw new FsFailure('NotFound', `${hit.name} is a file`);
      if (i === parts.length - 1) return { found: true, path: '/' + out.join('/'), entry: hit, dir: dir };
    }
    return { found: true, path: '/', entry: { name: '', dir: true, size: 0 }, dir: '/' };
  }

  async entry(path) {
    const { drive, parts } = this.where(path);
    const s = await this.spelled(drive, parts);
    if (!s.found) throw new FsFailure('NotFound', path);
    return { drive, ...s };
  }

  isSetup(path) { return path.toUpperCase().startsWith('KC:'); }

  /**
   * KC: is the commander's own folder: the setup file and what lives
   * beside it - the user menu, the extension table, the language files -
   * each a key of the page's localStorage: KC.INI the setup's own key,
   * any other name `<setup key>:<NAME>`.
   */
  kcName(path) { return path.slice(3).replace(/^\\+/, '').toUpperCase(); }
  kcKey(path) {
    const name = this.kcName(path);
    return name === 'KC.INI' ? this.setupKey : `${this.setupKey}:${name}`;
  }
  kcGet(path) {
    try { return localStorage.getItem(this.kcKey(path)); } catch { return null; }
  }
  kcNames() {
    const names = [];
    try {
      if (localStorage.getItem(this.setupKey) !== null) names.push('KC.INI');
      for (let i = 0; i < localStorage.length; i++) {
        const k = localStorage.key(i);
        if (k?.startsWith(this.setupKey + ':')) names.push(k.slice(this.setupKey.length + 1));
      }
    } catch { /* no storage: an empty folder */ }
    return names;
  }
  kcEntry(name) {
    return { name, dir: false, size: utf8.encode(this.kcGet('KC:\\' + name) ?? '').length };
  }

  /** The call `op`, its arguments as web/src/lib.rs sends them: a reply, or a promise of one. */
  call(op, args) {
    try {
      switch (op) {
        case 1: return ok(this.drives.map(d => [d.letter, d.kind ?? d.title ?? ''].join(FIELD)).join(RECORD));
        case 2: return ok(this.current ?? `${this.drives[0]?.letter ?? 'A'}:\\`);
        case 13: return this.read(args);
        case 14: return this.write(args);
        case 15: return this.close(args);
        case 17: { const d = new Date(); return ok(`${d.getHours()},${d.getMinutes()}`); }
      }
      const a = text.decode(args).split('\0');
      return this.slow(op, a).then(ok, failed);
    } catch (e) {
      return failed(e);
    }
  }

  async slow(op, a) {
    switch (op) {
      case 3: {
        if (this.isSetup(a[0])) return this.kcNames().map(n => entryText(this.kcEntry(n))).join(RECORD);
        const { drive, path } = await this.entry(a[0]).then(r => r, e => { throw e; });
        const dir = path.endsWith('/') ? path : path + '/';
        return (await drive.list(dir)).map(entryText).join(RECORD);
      }
      case 4: {
        if (this.isSetup(a[0])) {
          const name = this.kcName(a[0]);
          if (!name) return entryText({ name: 'KC:', dir: true, size: 0 });
          if (this.kcGet(a[0]) === null) throw new FsFailure('NotFound');
          return entryText(this.kcEntry(name));
        }
        const r = await this.entry(a[0]);
        return entryText(r.entry.name ? r.entry : { ...r.entry, name: r.drive.letter + ':' });
      }
      case 5: { const s = await this.space(); return s ? String(s[1]) : ''; }
      case 16: { const s = await this.space(); return s ? `${s[0]},${s[1]}` : ''; }
      case 6: {
        const { drive, parts } = this.where(a[0]);
        this.writable(drive);
        const s = await this.spelled(drive, parts);
        if (s.found) throw new FsFailure('Exists');
        await drive.mkdir(this.joined(s));
        return '';
      }
      case 7: {
        if (this.isSetup(a[0])) {
          if (this.kcGet(a[0]) === null) throw new FsFailure('NotFound');
          try { localStorage.removeItem(this.kcKey(a[0])); } catch { /* nothing was kept */ }
          return '';
        }
        const r = await this.entry(a[0]);
        this.writable(r.drive);
        if (r.entry.dir) throw new FsFailure('NotFound', `${a[0]} is a folder`);
        await r.drive.remove(r.path);
        return '';
      }
      case 8: {
        const r = await this.entry(a[0]);
        this.writable(r.drive);
        if (!r.entry.dir) throw new FsFailure('NotFound', `${a[0]} is a file`);
        // The storage would take a full folder with everything in it;
        // the commander takes only an empty one (6.5).
        if ((await r.drive.list(r.path + '/')).length) throw new FsFailure('NotEmpty');
        await r.drive.remove(r.path + '/');
        return '';
      }
      case 9: {
        const from = await this.entry(a[0]);
        const to = this.where(a[1]);
        if (to.drive !== from.drive) throw new FsFailure('CrossDevice');
        this.writable(from.drive);
        const t = await this.spelled(to.drive, to.parts);
        // A new spelling of the same name is a rename, not a clash.
        if (t.found && t.path.toUpperCase() !== from.path.toUpperCase()) throw new FsFailure('Exists');
        await from.drive.rename(from.path + (from.entry.dir ? '/' : ''), this.joined(t, true) + (from.entry.dir ? '/' : ''));
        return '';
      }
      case 10: throw new FsFailure('Unsupported', 'a browser keeps no attributes');
      case 18: return '';             // no dates to set in a browser's storage: the copy is dated now
      case 11: {
        if (this.isSetup(a[0])) {
          const s = this.kcGet(a[0]);
          if (s === null) throw new FsFailure('NotFound');
          return this.handle({ data: utf8.encode(s), pos: 0 });
        }
        const r = await this.entry(a[0]);
        if (r.entry.dir) throw new FsFailure('NotFound', `${a[0]} is a folder`);
        return this.handle({ data: await r.drive.readBytes(r.path), pos: 0 });
      }
      case 12: {
        if (this.isSetup(a[0])) return this.handle({ kc: this.kcKey(a[0]), parts: [] });
        const { drive, parts } = this.where(a[0]);
        this.writable(drive);
        const s = await this.spelled(drive, parts);
        if (s.found && s.entry.dir) throw new FsFailure('Exists', `${a[0]} is a folder`);
        if (!s.found && s.rest.length > 1) throw new FsFailure('NotFound', `no folder ${s.rest[0]}`);
        return this.handle({ drive, path: s.found ? s.path : this.joined(s, true), parts: [] });
      }
    }
    throw new FsFailure('Unsupported', `call ${op}`);
  }

  /** Where a path not yet there goes: the part found as spelled, the rest as typed. */
  joined(s, file = false) {
    const p = s.dir.replace(/\/$/, '') + '/' + (s.rest ?? []).join('/');
    return file ? p : p + '/';
  }

  writable(drive) {
    if (drive.readOnly) throw new FsFailure('WriteProtected', `${drive.letter}: is read-only`);
  }

  async space() {
    const e = await navigator.storage?.estimate?.();
    if (!e?.quota) return null;
    return [e.quota, Math.max(0, e.quota - (e.usage ?? 0))];
  }

  handle(h) {
    const n = this.next++;
    this.open.set(n, h);
    return String(n);
  }

  read(args) {
    const v = new DataView(args.buffer, args.byteOffset, args.byteLength);
    const h = this.open.get(v.getUint32(0, true));
    if (!h?.data) return failed(new FsFailure('Io', 'not open'));
    const n = Math.min(v.getUint32(4, true), h.data.length - h.pos);
    const out = ok(h.data.subarray(h.pos, h.pos + n));
    h.pos += n;
    return out;
  }

  write(args) {
    const v = new DataView(args.buffer, args.byteOffset, args.byteLength);
    const h = this.open.get(v.getUint32(0, true));
    if (!h?.parts) return failed(new FsFailure('Io', 'not open'));
    h.parts.push(args.slice(4));
    return ok();
  }

  close(args) {
    const v = new DataView(args.buffer, args.byteOffset, args.byteLength);
    const n = v.getUint32(0, true);
    const h = this.open.get(n);
    this.open.delete(n);
    if (!h) return failed(new FsFailure('Io', 'not open'));
    if (!h.parts) return ok();
    const size = h.parts.reduce((s, p) => s + p.length, 0);
    const all = new Uint8Array(size);
    let at = 0;
    for (const p of h.parts) { all.set(p, at); at += p.length; }
    if (h.kc) {
      try { localStorage.setItem(h.kc, text.decode(all)); return ok(); } catch (e) { return failed(new FsFailure('DiskFull', String(e))); }
    }
    return h.drive.write(h.path, all).then(() => ok(), failed);
  }
}

// ------------------------------------------------------------- the keys

const NAMED = { Enter: 2, Escape: 3, Tab: 4, Backspace: 6, Delete: 7, Insert: 8, Home: 9, End: 10, PageUp: 11, PageDown: 12,
  ArrowUp: 13, ArrowDown: 14, ArrowLeft: 15, ArrowRight: 16 };

/** A keydown as kc_key's three numbers, or null for a key the commander has no use for. */
export function keyOf(e) {
  const mods = (e.ctrlKey ? 1 : 0) | (e.altKey ? 2 : 0) | (e.shiftKey ? 4 : 0);
  if (e.key === 'Tab' && e.shiftKey) return [5, 0, mods];
  if (NAMED[e.key]) return [NAMED[e.key], 0, mods];
  const f = /^F(\d{1,2})$/.exec(e.key);
  if (f) return [1, Number(f[1]), mods];
  // With Ctrl or Alt the key as its place on the keyboard says: Alt+F
  // is F whatever the layout makes of it.
  if (e.ctrlKey || e.altKey) {
    const c = /^Key([A-Z])$/.exec(e.code)?.[1] ?? /^Digit(\d)$/.exec(e.code)?.[1];
    if (c) return [0, c.toLowerCase().codePointAt(0), mods];
  }
  if ([...e.key].length === 1) return [0, e.key.codePointAt(0), mods];
  return null;
}

// ------------------------------------------------------------- the page

export class Commander {
  /**
   * The commander on `canvas`, as big as `box` (the canvas's parent) has
   * room for. Resolves when the first frame is on it. setupKey: the
   * localStorage key of its setup, and the start of its other files' keys
   * (KC:\KC.MNU is `${setupKey}:KC.MNU`) - a page of its own keeps its own.
   */
  static async start(canvas, { drives, run = null, current = null, wasm = new URL('./kc.wasm', import.meta.url), box = canvas.parentElement,
    onQuit = null, screen = null, setupKey = 'kc.ini' } = {}) {
    const kc = new Commander(canvas, { drives, run, current, box, onQuit, screen, setupKey });
    await kc.load(wasm);
    return kc;
  }

  constructor(canvas, { drives, run, current, box, onQuit, screen, setupKey = 'kc.ini' }) {
    this.canvas = canvas;
    this.box = box;
    this.fs = new WebFs(drives, { current, setupKey });
    this.runLine = run;
    this.onQuit = onQuit;
    this.screen = screen ?? new Screen(canvas);
    this.glyphs = [];
    this.queue = Promise.resolve();
    this.pending = null;
    this.reply = null;
    this.taken = null;
    this.frame = null;
    this.ended = false;
  }

  async load(url) {
    const bytes = await (await fetch(url)).arrayBuffer();
    const { instance } = await WebAssembly.instantiate(bytes, {
      kc: { host: (op, ptr, len) => this.host(op, ptr, len), host_take: ptr => this.mem(ptr, this.taken.length).set(this.taken),
        panicked: (ptr, len) => console.error('kc panicked:', text.decode(this.mem(ptr, len)))  },
    });
    this.x = instance.exports;
    // asyncify's saved stack: a header of two pointers, then the room.
    const room = 1 << 16;
    this.data = this.x.kc_alloc(room + 8);
    this.dataEnd = this.data + 8 + room;
    const { cols, rows } = this.fit();
    await this.later('kc_start', cols, rows, this.runLine ? 0 : 1);
    this.listen();
  }

  mem(ptr, len) { return new Uint8Array(this.x.memory.buffer, ptr, len); }

  /**
   * One `Fs` call from inside the module. An answer at hand goes back at
   * once; a promise puts the module to sleep (asyncify's unwind), and
   * enter() wakes it with the answer when the promise is kept.
   */
  host(op, ptr, len) {
    if (this.x.asyncify_get_state() === 2) {
      this.x.asyncify_stop_rewind();
      this.taken = this.reply;
      this.reply = null;
      return this.taken.length;
    }
    const r = this.fs.call(op, this.mem(ptr, len).slice());
    if (!(r instanceof Promise)) {
      this.taken = r;
      return r.length;
    }
    this.pending = r;
    const v = new DataView(this.x.memory.buffer);
    v.setInt32(this.data, this.data + 8, true);
    v.setInt32(this.data + 4, this.dataEnd, true);
    this.x.asyncify_start_unwind(this.data);
    return 0;
  }

  /** An exported function, run to its end through every sleep in it. */
  async enter(name, ...args) {
    let r = this.x[name](...args);
    while (this.x.asyncify_get_state() === 1) {
      this.x.asyncify_stop_unwind();
      this.reply = await this.pending;
      this.pending = null;
      this.x.asyncify_start_rewind(this.data);
      r = this.x[name](...args);
    }
    return r;
  }

  /** In the module one call at a time, in the order they came; then the screen. */
  later(name, ...args) {
    if (this.ended) return this.queue;
    this.queue = this.queue.then(() => this.enter(name, ...args)).then(() => this.paint()).catch(e => console.error('kc', e));
    return this.queue;
  }

  fit() {
    const r = this.box?.getBoundingClientRect() ?? { width: innerWidth, height: innerHeight };
    return this.screen.fit(r.width, r.height);
  }

  async paint() {
    if (this.ended) return;
    const len = await this.enter('kc_frame');
    const all = this.mem(this.x.kc_out(), len).slice();
    const v = new DataView(all.buffer);
    const w = v.getInt16(0, true), h = v.getInt16(2, true), font = v.getUint16(9, true);
    if (font > this.glyphs.length) {
      const n = this.x.kc_glyphs(this.glyphs.length);
      this.glyphs.push(...text.decode(this.mem(this.x.kc_room_ptr(), n)));
    }
    const cells = 11 + w * h * 3;
    this.frame = new Frame(all.subarray(0, cells), this.glyphs);
    this.screen.draw(this.frame);
    const requests = text.decode(all.subarray(cells)).split('\n').filter(Boolean);
    for (const r of requests) this.request(r.split(FIELD));
    if (!this.ticking) this.tickSoon();
  }

  /** What the commander asks the page to do. */
  request([what, dir, line]) {
    if (what === 'quit') {
      this.ended = true;
      this.unlisten?.();
      this.onQuit?.();
    } else if (what === 'run') {
      this.queue = this.queue.then(async () => {
        let out;
        try {
          out = this.runLine ? await this.runLine(dir, line) : `${dir}>${line}\nThis page has no shell: in WIRE CITY the line runs in the site's console.`;
        } catch (e) {
          out = `${dir}>${line}\n${e?.message ?? e}`;
        }
        const b = utf8.encode(String(out ?? ''));
        this.mem(this.x.kc_room(b.length), b.length).set(b);
        await this.enter('kc_ran', b.length);
      }).then(() => this.paint());
    }
  }

  /** The clock once a second; a job a step at a time, the screen between. */
  tickSoon() {
    this.ticking = true;
    setTimeout(() => {
      this.ticking = false;
      if (this.ended) return;
      this.queue = this.queue.then(async () => {
        const busy = await this.enter('kc_tick');
        await this.paint();
        if (busy) this.tickSoon();
      }).catch(e => console.error('kc', e));
    }, 0);
    // A job asks again at once; the clock waits.
  }

  listen() {
    const held = e => this.later('kc_held', (e.ctrlKey ? 1 : 0) | (e.altKey ? 2 : 0) | (e.shiftKey ? 4 : 0));
    const down = e => {
      if (['Control', 'Alt', 'Shift'].includes(e.key)) { held(e); e.preventDefault(); return; }
      const k = keyOf(e);
      if (!k) return;
      e.preventDefault();
      this.later('kc_key', ...k);
    };
    const up = e => { if (['Control', 'Alt', 'Shift'].includes(e.key)) { held(e); e.preventDefault(); } };
    let last = null;
    const mouse = kind => e => {
      const { x, y } = this.screen.cellAt(e);
      if (kind === 0) {
        const now = performance.now();
        const twice = last && now - last.t < 400 && last.x === x && last.y === y;
        last = { t: now, x, y };
        this.later('kc_mouse', x, y, twice ? 2 : 0, e.button === 2 ? 1 : e.button === 1 ? 2 : 0);
      } else if (kind === 3 && !e.buttons) return;
      else this.later('kc_mouse', x, y, kind, e.button === 2 ? 1 : 0);
      e.preventDefault();
    };
    const wheel = e => { const { x, y } = this.screen.cellAt(e); this.later('kc_mouse', x, y, e.deltaY < 0 ? 5 : 6, 0); e.preventDefault(); };
    const menu = e => e.preventDefault();
    const target = this.canvas.tabIndex >= 0 ? this.canvas : window;
    const md = mouse(0), mu = mouse(1), mm = mouse(3);
    target.addEventListener('keydown', down);
    target.addEventListener('keyup', up);
    this.canvas.addEventListener('mousedown', md);
    this.canvas.addEventListener('mouseup', mu);
    this.canvas.addEventListener('mousemove', mm);
    this.canvas.addEventListener('wheel', wheel, { passive: false });
    this.canvas.addEventListener('contextmenu', menu);
    const clock = setInterval(() => this.later('kc_tick'), 1000);
    const resize = new ResizeObserver(() => { const { cols, rows } = this.fit(); this.later('kc_resize', cols, rows); });
    if (this.box) resize.observe(this.box);
    this.unlisten = () => {
      target.removeEventListener('keydown', down);
      target.removeEventListener('keyup', up);
      this.canvas.removeEventListener('mousedown', md);
      this.canvas.removeEventListener('mouseup', mu);
      this.canvas.removeEventListener('mousemove', mm);
      this.canvas.removeEventListener('wheel', wheel);
      this.canvas.removeEventListener('contextmenu', menu);
      clearInterval(clock);
      resize.disconnect();
    };
  }

  /** The screen as text, a line a row: for a test to read. */
  text() { return this.frame?.toString() ?? ''; }

  /** The panels on these folders - `A:\LESSONS`, `D:\` - where the page wants them. */
  go(left, right = left) {
    const b = utf8.encode(`${left}${FIELD}${right}`);
    if (this.ended) return this.queue;
    this.queue = this.queue.then(async () => {
      this.mem(this.x.kc_room(b.length), b.length).set(b);
      await this.enter('kc_go', b.length);
    }).then(() => this.paint()).catch(e => console.error('kc', e));
    return this.queue;
  }

  /** Both panels read again: something else changed the drives under them. */
  reread() { return this.later('kc_reread'); }

  /** Ended by the page - its window closed: no more keys, mouse or clock. */
  stop() {
    this.ended = true;
    this.unlisten?.();
  }

  /** Keys by name, for a test: `await kc.keys('Down F4 "text" Ctrl+R')`. */
  async keys(script) {
    for (const k of script.match(/"[^"]*"|\S+/g) ?? []) {
      if (k.startsWith('"')) {
        for (const c of k.slice(1, -1)) await this.later('kc_key', 0, c.codePointAt(0), 0);
        continue;
      }
      let rest = k, mods = 0;
      for (;;) {
        const m = /^(Ctrl|Alt|Shift)\+(.+)$/.exec(rest);
        if (!m) break;
        mods |= m[1] === 'Ctrl' ? 1 : m[1] === 'Alt' ? 2 : 4;
        rest = m[2];
      }
      const named = { Enter: 2, Esc: 3, Tab: 4, Bksp: 6, Del: 7, Ins: 8, Home: 9, End: 10, PgUp: 11, PgDn: 12, Up: 13, Down: 14, Left: 15, Right: 16, Space: -1 };
      if (rest === 'Space') await this.later('kc_key', 0, 32, mods);
      else if (named[rest]) await this.later('kc_key', named[rest], 0, mods);
      else if (/^F\d+$/.test(rest)) await this.later('kc_key', 1, Number(rest.slice(1)), mods);
      else await this.later('kc_key', 0, rest.toLowerCase().codePointAt(0), mods);
    }
    // A job a keystroke started: to its end, or to its question.
    this.queue = this.queue.then(async () => {
      while (await this.enter('kc_tick')) { /* the next steps */ }
      await this.paint();
    });
    await this.queue;
    return this.text();
  }
}
