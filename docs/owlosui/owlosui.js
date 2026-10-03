// OWLOSUI for JavaScript: the client of the wire, and a screen to draw on.
//
// The same thing Owlosui.cs is for C#, with one difference: there is no
// pipe. The core - the wire server, lib/serve - is compiled into a
// WebAssembly module (owlosui-wire.wasm, beside this file), and a request
// goes into the module's memory instead of down a pipe. The bytes are the
// same, byte for byte: lib/PROTOCOL.md.
//
// Three parts:
//
//   Wire      loads the module and makes calls: op and payload in, reply out.
//   Owlosui   the API - window, buttons, input, menuBar... - one method a
//             request, named as in the C# client (camelCase). A program is
//             written against this.
//   Screen    draws a frame on a canvas and turns the browser's keys and
//             mouse into requests. `run` puts the three together.
//
// Nothing here knows what a window is. The core decides every cell; this
// file copies cells onto a canvas, as a console copies them onto a screen.
//
// In Node (for tests) there is no canvas: load a Wire from the file's
// bytes, make an Owlosui, and read frames as text with frame().row(y).

// ------------------------------------------------------------------ wire

export class OwlosuiError extends Error {}

const utf8 = new TextEncoder();
const fromUtf8 = new TextDecoder();

/** The core, in a WebAssembly module: one call is one request and one reply. */
export class Wire {
  constructor(instance) {
    this.m = instance.exports;
  }

  /** Load the module from a URL (browser) or from its bytes (Node). */
  static async load(source) {
    const imports = {};
    let result;
    if (source instanceof URL || typeof source === 'string') {
      const response = await fetch(source);
      if (!response.ok) throw new OwlosuiError(`could not load ${source}: ${response.status}`);
      result = await WebAssembly.instantiate(await response.arrayBuffer(), imports);
    } else {
      result = await WebAssembly.instantiate(source, imports);
    }
    return new Wire(result.instance);
  }

  /** One request. Returns the reply's body; an error reply throws with the server's words. */
  call(op, payload = new Uint8Array(0)) {
    if (payload.length > 0xFFFF) {
      throw new OwlosuiError(`op ${op.toString(16)}: ${payload.length} bytes is more than one request can carry (65535)`);
    }
    const at = this.m.owl_in(payload.length);
    new Uint8Array(this.m.memory.buffer, at, payload.length).set(payload);
    const n = this.m.owl_call(op);
    // Copied out at once: the next call may move the module's memory.
    const reply = new Uint8Array(this.m.memory.buffer, this.m.owl_out(), n).slice();
    const body = reply.subarray(3, 3 + (reply[1] | (reply[2] << 8)));
    if (reply[0] !== 0) throw new OwlosuiError(`op ${op.toString(16)}: ${readStr(body, 0).text}`);
    return body;
  }
}

// ---- bytes, the way the wire wants them: little-endian, strings UTF-8
// with a u16 length in front.

function bytes(...parts) {
  const n = parts.reduce((s, p) => s + p.length, 0);
  const out = new Uint8Array(n);
  let at = 0;
  for (const p of parts) {
    out.set(p, at);
    at += p.length;
  }
  return out;
}
const u8 = v => Uint8Array.of(v & 0xFF);
const u16 = v => Uint8Array.of(v & 0xFF, (v >> 8) & 0xFF);
const i16 = v => u16(v & 0xFFFF);
const u32 = v => Uint8Array.of(v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >>> 24) & 0xFF);
const rect = (x, y, w, h) => bytes(i16(x), i16(y), i16(w), i16(h));
function str(s) {
  const b = utf8.encode(s);
  if (b.length > 0xFFFF) throw new OwlosuiError('string too long for the wire');
  return bytes(u16(b.length), b);
}
/**
 * A text in pieces that each fit one request: 15000 UTF-16 units are at
 * most 60000 bytes of UTF-8. Never cut between the two halves of a
 * surrogate pair, or a character outside the BMP would arrive as two
 * replacement marks.
 */
function pieces(s, max = 15000) {
  if (s.length <= max) return [s];
  const out = [];
  for (let at = 0; at < s.length;) {
    let end = Math.min(at + max, s.length);
    const c = s.charCodeAt(end - 1);
    if (end < s.length && c >= 0xD800 && c <= 0xDBFF) end--;
    out.push(s.slice(at, end));
    at = end;
  }
  return out;
}
const readU16 = (b, at) => b[at] | (b[at + 1] << 8);
const readU32 = (b, at) => (b[at] | (b[at + 1] << 8) | (b[at + 2] << 16) | (b[at + 3] << 24)) >>> 0;
const readI16 = (b, at) => (readU16(b, at) << 16) >> 16;
function readStr(b, at) {
  const n = readU16(b, at);
  return { text: fromUtf8.decode(b.subarray(at + 2, at + 2 + n)), next: at + 2 + n };
}

const Op = {
  Quit: 0x00, Init: 0x01, Resize: 0x02,
  Window: 0x10, Text: 0x11, Static: 0x12, Input: 0x13, Buttons: 0x14, MessageBox: 0x15,
  Status: 0x16, Label: 0x17, Progress: 0x18, List: 0x19, Canvas: 0x1B, MenuBar: 0x1C,
  Cluster: 0x1D, ButtonRow: 0x1E, Hex: 0x1F,
  Close: 0x20, GetText: 0x21, SetProgress: 0x22, GetMarked: 0x23, GetCurrent: 0x24,
  Activate: 0x27, Active: 0x2A, SetText: 0x2B, Blit: 0x2C, MenuCheck: 0x2D, GetCluster: 0x2E, GetClick: 0x2F,
  Key: 0x30, Mouse: 0x31, Tick: 0x32,
  Frame: 0x40, Take: 0x41, GetGlyphs: 0x42, Cycle: 0x43, Zoom: 0x44, SetButton: 0x45, Focus: 0x46,
  Cascade: 0x47, Tile: 0x48, SetReadOnly: 0x49, WindowStatus: 0x4A, WindowMenu: 0x4B, WindowList: 0x4C,
  CycleBack: 0x4D, SizeMove: 0x4E, SetHistory: 0x4F, GetHistory: 0x50, Palette: 0x51, SetColor: 0x52,
  Find: 0x57, Replace: 0x58, ReplaceAll: 0x59, Editor: 0x5D, GetEditor: 0x5E, Syntax: 0x5F, SyntaxDefine: 0x60,
  Files: 0x1A, SetFiles: 0x25, TakeFiles: 0x26, MarkedNames: 0x28, SetFilesError: 0x29, AddFiles: 0x5A, Unmark: 0x61,
  Place: 0x62, SetTag: 0x65, SetIndicator: 0x66, Console: 0x67, ConsoleWrite: 0x68,
  Clipboard: 0x69, ClipboardGet: 0x6A, ClipboardPaste: 0x6B, Minimize: 0x6C, TextAppend: 0x6D, GetTextPart: 0x6E,
  Tree: 0x53, TreeChildren: 0x54, TreeExpand: 0x55, TreePath: 0x56,
};

// ------------------------------------------------------------------ keys

/** The keys that have names on the wire, by the names a KeyboardEvent gives them. */
const NAMED = {
  Enter: 0, Escape: 1, Tab: 2, BackTab: 3, Backspace: 4, Delete: 5, Insert: 6, Home: 7, End: 8,
  PageUp: 9, PageDown: 10, ArrowUp: 11, ArrowDown: 12, ArrowLeft: 13, ArrowRight: 14,
};

/**
 * A key as the wire wants it: [kind, value, mods]. `key` is a KeyboardEvent
 * name - 'Enter', 'F1', 'ArrowUp' - or one character. Mods: shift 1, ctrl
 * 2, alt 4. With Ctrl or Alt a letter is sent as itself, lower case: Alt+X
 * is 'x' with alt, as it is on the wire. Null for a key the wire has no
 * name for.
 */
export function encodeKey(key, { shift = false, ctrl = false, alt = false } = {}) {
  let mods = (shift ? 1 : 0) | (ctrl ? 2 : 0) | (alt ? 4 : 0);
  if (key === 'Tab' && shift) return [2, 3, mods];
  if (key in NAMED) return [2, NAMED[key], mods];
  const f = /^F(\d{1,2})$/.exec(key);
  if (f) return [1, parseInt(f[1], 10), mods];
  if ([...key].length !== 1) return null;
  if (mods & 6) return [0, key.toLowerCase().codePointAt(0), mods];
  // Shift is already in the character's case.
  return [0, key.codePointAt(0), 0];
}

// ---------------------------------------------------------------- colours

/** The sixteen colours by name, numbered as the IBM PC numbered them. */
export const Color = {
  Black: 0, Blue: 1, Green: 2, Cyan: 3, Red: 4, Magenta: 5, Brown: 6, LightGray: 7,
  DarkGray: 8, LightBlue: 9, LightGreen: 10, LightCyan: 11, LightRed: 12, LightMagenta: 13, Yellow: 14, White: 15,
};

/** An attribute byte: foreground in the low four bits, background in the high four. */
export const attr = (fg, bg) => ((bg & 15) << 4) | (fg & 15);

/** On a canvas: a cell left clear shows whatever is behind it. */
export const CLEAR_ATTR = 0xFF;

// --------------------------------------------------------------- the API

/**
 * What an editor offers, for `editor()`: each one a whole feature the core
 * then runs by itself while the editor's window is active - its items in
 * the Edit menu, its keys, and for Find and Replace the dialogs.
 */
export const Offer = {
  Edit: 1,       // Undo, Redo, Cut, Copy, Paste, Select all
  Find: 2,       // Find... (Ctrl+F) and Find next (Ctrl+L)
  Replace: 4,    // Replace... (Ctrl+H)
  Wrap: 8,       // Word wrap, ticked while on
  ReadOnly: 16,  // Read only, ticked while on
  Hex: 32,       // the same text as bytes
  Keys: 64,      // Classic keys: the WordStar arrangement
  Syntax: 128,   // Syntax: the language the text is coloured as
  All: 255,
};

/** Window styles: a document is blue and resizable, a dialog grey and fixed. */
export const Style = {
  Document: 0x00, Help: 0x10, Dialog: 0x20 | 0x02 | 0x04, ModalDialog: 0x20 | 0x02 | 0x04 | 0x01,
  // Black, frame and all: a console's window, the colour of what is in it.
  Terminal: 0x30,
};

const STYLES = { normal: 0, accent: 1, danger: 2 };

/**
 * A button: `['~O~K', cmd]`, or `{ label, cmd, default, cancel, style,
 * enabled }` where style is 'normal', 'accent' or 'danger'. The label has
 * its hotkey between tildes.
 */
function buttonsBytes(buttons, implyDefault) {
  if (buttons.length === 0) throw new OwlosuiError('a button row needs at least one button');
  const list = buttons.map(b => (Array.isArray(b) ? { label: b[0], cmd: b[1] } : b));
  let dflt = list.findIndex(b => b.default);
  if (dflt < 0 && implyDefault) dflt = 0;
  const parts = [u8(list.length)];
  list.forEach((b, i) => {
    if (!b.cmd) throw new OwlosuiError(`button '${b.label}' has command 0, which means none`);
    const flags = (i === dflt ? 1 : 0) | ((STYLES[b.style ?? 'normal'] ?? 0) << 1) | (b.enabled === false ? 8 : 0) | (b.cancel ? 16 : 0);
    parts.push(u16(b.cmd), u8(flags), str(b.label));
  });
  return bytes(...parts);
}

/**
 * A menu item: `{ label, cmd, shortcut, hint, checked, enabled, items }`.
 * `sub(label, ...items)` makes a submenu and `line()` a separator.
 */
export const sub = (label, ...items) => ({ label, cmd: 0, items });
export const line = () => ({ label: '', cmd: 0, separator: true });

/**
 * Tree nodes: `n:u8` then `n ×` (`flags:u8 text:str` then the node's own
 * children the same way). Flags: bit 0 open, bit 1 lazy.
 */
function nodeBytes(nodes = []) {
  const list = nodes.slice(0, 255);
  return bytes(u8(list.length), ...list.flatMap(n => [
    u8((n.open ? 1 : 0) | (n.lazy ? 2 : 0)), str(n.text ?? ''), nodeBytes(n.children ?? []),
  ]));
}

function menuBytes(items) {
  const parts = [u8(items.length)];
  for (const it of items) {
    const flags = (it.separator ? 1 : 0) | (it.enabled === false ? 2 : 0) | (it.checked ? 4 : 0);
    parts.push(u8(flags), u16(it.cmd ?? 0), str(it.label ?? ''), str(it.shortcut ?? ''), str(it.hint ?? ''), menuBytes(it.items ?? []));
  }
  return bytes(...parts);
}

/**
 * A status line item: `{ label, cmd, key, shift, ctrl, alt }`. The label
 * has the key's name between tildes, `~F1~ Help`; `key` is the key that
 * sends `cmd` ('F1', 'x' with alt...), or none for an item only a click
 * reaches.
 */
function statusBytes(items) {
  const parts = [u8(items.length)];
  for (const it of items) {
    parts.push(u16(it.cmd));
    const k = it.key ? encodeKey(it.key, it) : null;
    parts.push(k ? bytes(u8(k[0]), u16(k[1]), u8(k[2])) : bytes(u8(0xFF), u16(0), u8(0)));
    parts.push(str(it.label ?? ''));
  }
  return bytes(...parts);
}

/**
 * A folder's entries for the file panel: `{ name, size, date, dir,
 * readOnly }`, `date` a Date or null for none. The server reads no folders - a program
 * reads its own, wherever they are, and hands them over - so a listing
 * bigger than one request (64K) goes in parts: the first with FILES or
 * SET_FILES, the rest with ADD_FILES.
 */
function entryParts(entries) {
  const one = e => {
    const attrs = (e.dir ? 0x10 : 0) | (e.readOnly ? 0x01 : 0);
    // No date, or one that is not a date: the year 0, which the panel
    // shows as an empty column rather than as a day nobody chose.
    const d = e.date instanceof Date && !isNaN(e.date) && e.date.getTime() !== 0 ? e.date : null;
    const when = d ? bytes(u16(d.getFullYear()), u8(d.getMonth() + 1), u8(d.getDate()), u8(d.getHours()), u8(d.getMinutes()))
      : bytes(u16(0), u8(0), u8(0), u8(0), u8(0));
    return bytes(str(e.name), u32(e.size ?? 0), when, u8(attrs));
  };
  const parts = [];
  let chunk = [], size = 0;
  for (const e of entries) {
    const b = one(e);
    if (size + b.length > 60000) { parts.push(chunk); chunk = []; size = 0; }
    chunk.push(b);
    size += b.length;
  }
  parts.push(chunk);
  return parts.map(c => bytes(u16(c.length), ...c));
}

/** A frame: w by h cells of glyph and attribute, the caret, and whether to hold it. */
export class Frame {
  constructor(body, glyphs) {
    this.w = readI16(body, 0);
    this.h = readI16(body, 2);
    this.cursorX = readI16(body, 4);
    this.cursorY = readI16(body, 6);
    this.hold = body[8] !== 0;
    // How long to show it: a chosen item long enough to be seen, a step of
    // a window falling into its bar only as long as a frame of film.
    this.holdMs = body[8] === 2 ? 35 : 90;
    this.cells = body.subarray(11);
    this.glyphs = glyphs;
  }
  glyph(x, y) { return readU16(this.cells, (y * this.w + x) * 3); }
  attr(x, y) { return this.cells[(y * this.w + x) * 3 + 2]; }
  char(x, y) { const g = this.glyph(x, y); return g < this.glyphs.length ? this.glyphs[g] : '?'; }
  row(y) { let s = ''; for (let x = 0; x < this.w; x++) s += this.char(x, y); return s; }
  /** Where a piece of text first is on the screen, or null. */
  find(text) {
    for (let y = 0; y < this.h; y++) {
      const x = this.row(y).indexOf(text);
      if (x >= 0) return { x, y };
    }
    return null;
  }
  toString() { const rows = []; for (let y = 0; y < this.h; y++) rows.push(this.row(y)); return rows.join('\n'); }
}

/**
 * The toolkit, one method a request. Every view is a number (its id), and
 * nothing calls back: what the person did comes out of take() - a button
 * pressed, a menu item chosen - and the program decides what it means.
 */
export class Owlosui {
  constructor(wire, width = 80, height = 25, codePage = 437) {
    this.wire = wire;
    this.width = Math.max(width, 20);
    this.height = Math.max(height, 5);
    this.call(Op.Init, i16(this.width), i16(this.height), u16(codePage));
    this.glyphs = this.fetchGlyphs();
  }

  call(op, ...parts) { return this.wire.call(op, bytes(...parts)); }

  /** Glyph index to character: the font the session draws with. It grows as new characters arrive. */
  fetchGlyphs() {
    const r = this.call(Op.GetGlyphs);
    const n = readU16(r, 1);
    const out = new Array(n);
    for (let i = 0; i < n; i++) out[i] = String.fromCharCode(readU16(r, 3 + i * 2));
    return out;
  }

  resize(width, height) {
    this.width = Math.max(width, 20);
    this.height = Math.max(height, 5);
    this.call(Op.Resize, i16(this.width), i16(this.height));
  }

  // ---- windows

  /**
   * A framed window. x or y of -1 (the default) centres it. Options:
   * style (Style.Document...), parent, closeCmd (what the close box sends
   * instead of closing), shadow, minimize (false: no [↓] box - a modal
   * window or one without a shadow has none anyway).
   */
  window(title, w, h, { x = -1, y = -1, style = Style.Document, parent = 0, closeCmd = 0, shadow = true, minimize = true } = {}) {
    const flags = style | (shadow ? 0 : 0x40) | (minimize ? 0 : 0x80);
    return readU16(this.call(Op.Window, u16(parent), rect(x, y, w, h), u8(flags), str(title), u16(closeCmd)), 0);
  }
  close(id) { this.call(Op.Close, u16(id)); }
  /**
   * Where a window's inside is, in cells, and whether anything is drawn
   * over it - for laying something of the page's own over a window, such
   * as an emulator's picture: show it while `covered` is false.
   * { x, y, w, h, covered }, or null for a window that is gone.
   */
  place(id) {
    try {
      const r = this.call(Op.Place, u16(id));
      return { x: readI16(r, 0), y: readI16(r, 2), w: readI16(r, 4), h: readI16(r, 6), covered: r[8] !== 0 };
    } catch {
      return null;
    }
  }
  activate(id) { this.call(Op.Activate, u16(id)); }
  active() { return readU16(this.call(Op.Active), 0); }
  zoom(id) { this.call(Op.Zoom, u16(id)); }
  /** Put a window away into its bar in the bottom right corner; activate(id) brings it back. */
  minimize(id) { this.call(Op.Minimize, u16(id)); }
  nextWindow() { this.call(Op.Cycle); }
  previousWindow() { this.call(Op.CycleBack); }
  windowList() { this.call(Op.WindowList); }
  sizeMove() { this.call(Op.SizeMove); }
  cascade() { this.call(Op.Cascade); }
  tile() { this.call(Op.Tile); }
  focus(id) { this.call(Op.Focus, u16(id)); }

  // ---- what goes in a window

  /** An editor filling its window; readOnly makes it a viewer. */
  text(parent, text = '', { readOnly = false } = {}) {
    const [first, ...rest] = pieces(text);
    const id = readU16(this.call(Op.Text, u16(parent), rect(0, 0, 0, 0), u8(0), u8(readOnly ? 1 : 0), str(first)), 0);
    this.appendText(id, rest);
    return id;
  }
  /** A boxed editor at a place of its own. */
  memo(parent, x, y, w, h, text = '', { readOnly = false } = {}) {
    const [first, ...rest] = pieces(text);
    const id = readU16(this.call(Op.Text, u16(parent), rect(x, y, w, h), u8(1), u8((readOnly ? 1 : 0) | 2), str(first)), 0);
    this.appendText(id, rest);
    return id;
  }
  /** The rest of a text bigger than one request, after its first piece: a file of any size. */
  appendText(id, rest) {
    for (const p of rest) this.call(Op.TextAppend, u16(id), str(p));
  }
  setReadOnly(id, on) { this.call(Op.SetReadOnly, u16(id), u8(on ? 1 : 0)); }
  /**
   * What a text offers (`Offer` bits) and how it starts: folded, read only,
   * with classic keys, as hex. The person can change each from the Edit
   * menu; `editorState` reads them back.
   */
  editor(id, offers, { wrap = false, readOnly = false, classic = false, hex = false } = {}) {
    const state = (wrap ? 1 : 0) | (readOnly ? 2 : 0) | (classic ? 4 : 0) | (hex ? 8 : 0);
    this.call(Op.Editor, u16(id), u8(offers), u8(state));
  }
  /** { offers, wrap, readOnly, classic, hex, syntax, line, col } - line and column from 0. */
  editorState(id) {
    const r = this.call(Op.GetEditor, u16(id));
    const s = r[1];
    return {
      offers: r[0], wrap: !!(s & 1), readOnly: !!(s & 2), classic: !!(s & 4), hex: !!(s & 8), syntax: !!(s & 16),
      line: readU16(r, 2), col: readU16(r, 4),
    };
  }
  /**
   * Colour a text as a language: its name ('Pascal'), an extension ('PAS')
   * or a file name ('DEMO.PAS'). The language's name, or null when there
   * is none - and then the text is plain.
   */
  syntax(id, language) {
    const r = this.call(Op.Syntax, u16(id), str(language));
    return r[0] ? readStr(r, 1).text : null;
  }
  /** Languages of the program's own, in the format of lib/core/src/syntax.ini; how many. */
  defineSyntax(text) { return this.call(Op.SyntaxDefine, str(text))[0]; }
  /** Words, wrapped to w; one line if h is 1. */
  staticText(parent, x, y, text, w = 0, h = 1) {
    return readU16(this.call(Op.Static, u16(parent), rect(x, y, w > 0 ? w : [...text].length, h), str(text)), 0);
  }
  /** A one-line field with its label in front. */
  input(parent, x, y, w, label, text = '', max = 0) {
    return readU16(this.call(Op.Input, u16(parent), rect(x, y, w, 1), u16(max), str(label), str(text)), 0);
  }
  /**
   * The whole text of an editor, an input or a console, however long: read
   * a part at a time, each cut where a character ends, and decoded once.
   */
  getText(id) {
    const parts = [];
    let from = 0, total = 0;
    do {
      const r = this.call(Op.GetTextPart, u16(id), u32(from));
      total = readU32(r, 0);
      const n = readU16(r, 4);
      if (n === 0 && from < total) throw new OwlosuiError(`the text of view ${id} stopped at byte ${from} of ${total}`);
      parts.push(r.subarray(6, 6 + n));
      from += n;
    } while (from < total);
    return new TextDecoder().decode(parts.length === 1 ? parts[0] : bytes(...parts));
  }
  /** New words for a static, an input, a window's title - or a whole new text for an editor, of any length. */
  setText(id, text) {
    const [first, ...rest] = pieces(text);
    this.call(Op.SetText, u16(id), str(first));
    this.appendText(id, rest);
  }
  /** A word in brackets after a window's title, as [modal] is: what it is doing that its name does not say. '' takes it away. */
  windowTag(id, tag) { this.call(Op.SetTag, u16(id), str(tag)); }
  /** Words at the right end of the status line while the window is in front; a part between tildes is lit, green. '' for none. */
  windowIndicator(id, text) { this.call(Op.SetIndicator, u16(id), str(text)); }
  setHistory(id, ...items) { this.call(Op.SetHistory, u16(id), u8(items.length), ...items.map(str)); }
  getHistory(id) {
    const r = this.call(Op.GetHistory, u16(id));
    const out = [];
    let at = 1;
    for (let i = 0; i < r[0]; i++) { const s = readStr(r, at); out.push(s.text); at = s.next; }
    return out;
  }
  find(id, pattern, { caseSensitive = false, wholeWord = false } = {}) {
    return this.call(Op.Find, u16(id), u8((caseSensitive ? 1 : 0) | (wholeWord ? 2 : 0)), str(pattern))[0] !== 0;
  }
  /** Replace the selected match and find the next: { replaced, found }. */
  replace(id, pattern, withText, { caseSensitive = false, wholeWord = false } = {}) {
    const r = this.call(Op.Replace, u16(id), u8((caseSensitive ? 1 : 0) | (wholeWord ? 2 : 0)), str(pattern), str(withText));
    return { replaced: r[0] !== 0, found: r[1] !== 0 };
  }
  replaceAll(id, pattern, withText, { caseSensitive = false, wholeWord = false } = {}) {
    return readU16(this.call(Op.ReplaceAll, u16(id), u8((caseSensitive ? 1 : 0) | (wholeWord ? 2 : 0)), str(pattern), str(withText)), 0);
  }

  /** The window's buttons, bottom right. Enter presses the default, Escape the cancel (or the last). */
  buttons(parent, ...buttons) { return readU16(this.call(Op.Buttons, u16(parent), buttonsBytes(buttons, true)), 0); }
  /** A row of buttons placed by hand - one row of a keypad. selectable: whether Tab stops there. */
  buttonRow(parent, x, y, buttons, { selectable = true } = {}) {
    return readU16(this.call(Op.ButtonRow, u16(parent), rect(x, y, 0, 2), u8(selectable ? 0 : 1), buttonsBytes(buttons, false)), 0);
  }
  enableButton(row, index, on) { this.call(Op.SetButton, u16(row), u8(index), u8(on ? 1 : 0)); }
  /** A modal box sized to its words. Its buttons' commands come out of take(). */
  messageBox(title, text, ...buttons) { return readU16(this.call(Op.MessageBox, str(title), str(text), buttonsBytes(buttons, true)), 0); }
  label(parent, x, y, text, target = 0) {
    return readU16(this.call(Op.Label, u16(parent), rect(x, y, text.replace(/~/g, '').length, 1), u16(target), str(text)), 0);
  }
  progress(parent, x, y, w, max = 100, percent = true) {
    return readU16(this.call(Op.Progress, u16(parent), rect(x, y, w, 1), u32(max), u8(percent ? 1 : 0)), 0);
  }
  setProgress(id, value) { this.call(Op.SetProgress, u16(id), u32(value)); }
  list(parent, x, y, w, h, items, { multi = false } = {}) {
    return readU16(this.call(Op.List, u16(parent), rect(x, y, w, h), u8(multi ? 1 : 0), u16(items.length), ...items.map(str)), 0);
  }
  current(id) { return readU16(this.call(Op.GetCurrent, u16(id)), 0); }
  /** The marked items of a list made with multi: true, by index - Insert or Space marks one. */
  marked(id) {
    const r = this.call(Op.GetMarked, u16(id));
    return Array.from({ length: readU16(r, 0) }, (_, i) => readU16(r, 2 + i * 2));
  }

  // ---- a tree: nodes that open and close, filled as they are opened

  /**
   * A tree filling its window. A node is { text, children, open, lazy };
   * lazy says it has children that are given only when it is opened -
   * treeExpand() then names it and treeChildren() fills it, so a disk is
   * not read whole.
   */
  tree(parent, nodes) { return readU16(this.call(Op.Tree, u16(parent), rect(0, 0, 0, 0), nodeBytes(nodes)), 0); }
  /** The children of the node at path (indices from the root); the node opens. */
  treeChildren(id, path, nodes) {
    this.call(Op.TreeChildren, u16(id), u8(path.length), ...path.map(u16), nodeBytes(nodes));
  }
  /** The lazy node somebody opened, once: { path, texts } from the root down, or null. Answer with treeChildren. */
  treeExpand(id) {
    const r = this.call(Op.TreeExpand, u16(id));
    if (r[0] === 0) return null;
    const path = [], texts = [];
    let at = 1;
    for (let i = 0; i < r[0]; i++) {
      path.push(readU16(r, at));
      const s = readStr(r, at + 2);
      texts.push(s.text);
      at = s.next;
    }
    return { path, texts };
  }
  /** The texts from the root down to the tree's current row. */
  treePath(id) {
    const r = this.call(Op.TreePath, u16(id));
    const texts = [];
    let at = 1;
    for (let i = 0; i < r[0]; i++) {
      const s = readStr(r, at);
      texts.push(s.text);
      at = s.next;
    }
    return texts;
  }
  /** Check boxes (any number on), or radio buttons with single: true. */
  /** on: which are ticked to begin with - an array of booleans, or for radio buttons the index of the chosen one. */
  cluster(parent, x, y, w, labels, { single = false, on = null } = {}) {
    const states = on === null ? [] : labels.map((_, i) => u8((typeof on === 'number' ? i === on : !!on[i]) ? 1 : 0));
    return readU16(this.call(Op.Cluster, u16(parent), rect(x, y, w, labels.length), u8(single ? 1 : 0), u8(labels.length), ...labels.map(str), ...states), 0);
  }
  /** { on: [bool], current } - which boxes are ticked, which one the cursor is on. */
  clusterState(id) {
    const r = this.call(Op.GetCluster, u16(id));
    const n = r[0];
    return { on: Array.from(r.subarray(1, 1 + n), b => b !== 0), current: r[1 + n] };
  }

  // ---- a console: text that keeps arriving, coloured by its ANSI sequences

  /**
   * A console filling its window. It keeps `scrollback` lines (0, a
   * thousand), folds long ones to its width, and follows the newest line
   * until it is scrolled back; End follows again.
   */
  console(parent, { scrollback = 0 } = {}) {
    return readU16(this.call(Op.Console, u16(parent), rect(0, 0, 0, 0), u16(scrollback)), 0);
  }
  /**
   * Text at the end of a console. ANSI sequences in it are obeyed - SGR
   * colours, CR, tab, backspace, erase-line, clear - and never shown; a
   * sequence cut in two between writes is still one. getText(id) gives the
   * whole record back without its colours.
   */
  consoleWrite(id, text) {
    // A request carries 64K; a character is at most four bytes of UTF-8.
    for (let i = 0; i < text.length; i += 16000) this.call(Op.ConsoleWrite, u16(id), str(text.slice(i, i + 16000)));
  }

  // ---- the clipboard the page shares with the core

  /**
   * The page shares its clipboard (host true): how many times the core has
   * copied - Copy, Cut, a console's Ctrl+C - and whether a Paste was
   * chosen that waits for the page's clipboard. run() asks after every
   * input; a program that runs its own loop does the same.
   */
  clipboard(host = true) {
    const r = this.call(Op.Clipboard, u8(host ? 1 : 0));
    return { copied: readU32(r, 0), paste: r[4] !== 0 };
  }
  /** What the core's clipboard holds, as text. */
  clipboardText() { return readStr(this.call(Op.ClipboardGet), 0).text; }
  /**
   * The page's clipboard in, and the paste waiting for it done. now: paste
   * into whatever has the focus even if nothing was waiting (the page's own
   * Ctrl+V). keep: the page could not read its clipboard; paste what the
   * core has. True if something was pasted.
   */
  clipboardPaste(text, { now = false, keep = false } = {}) {
    return this.call(Op.ClipboardPaste, u8((now ? 1 : 0) | (keep ? 2 : 0)), str(text ?? ''))[0] !== 0;
  }

  // ---- a canvas: cells the program draws itself

  canvas(parent, x, y, w, h) { return readU16(this.call(Op.Canvas, u16(parent), rect(x, y, w, h)), 0); }
  /**
   * A block of cells onto a canvas: chars is a string (or an array of
   * characters) and attrs an array of attribute bytes, w*h of each.
   */
  blit(id, x, y, w, h, chars, attrs) {
    const cs = typeof chars === 'string' ? [...chars] : chars;
    if (cs.length < w * h || attrs.length < w * h) throw new OwlosuiError(`a ${w}x${h} block needs ${w * h} cells`);
    const cells = new Uint8Array(w * h * 3);
    for (let i = 0; i < w * h; i++) {
      const c = cs[i] === '\0' ? 0 : cs[i].charCodeAt(0);
      cells[i * 3] = c & 0xFF;
      cells[i * 3 + 1] = c >> 8;
      cells[i * 3 + 2] = attrs[i];
    }
    this.call(Op.Blit, u16(id), i16(x), i16(y), i16(w), i16(h), cells);
  }
  /** One line of text in one colour. */
  blitText(id, x, y, text, attribute) {
    const cs = [...text];
    this.blit(id, x, y, cs.length, 1, cs, new Array(cs.length).fill(attribute));
  }
  /** Where the last click on a canvas landed, in its cells, once; or null. */
  canvasClick(id) {
    const r = this.call(Op.GetClick, u16(id));
    return r[0] !== 0 ? { x: readI16(r, 1), y: readI16(r, 3) } : null;
  }

  // ---- the file panel

  /**
   * The file panel, filling its window with `top` rows left free above
   * it: the path line, the names in columns, a line of details. `path` is
   * what the path line says; the entries are the program's own reading of
   * the folder (see entryParts). What the person does comes back through
   * takeFiles.
   */
  files(parent, path, entries, { mask = '*.*', top = 0, multi = false, pathLine = true, detailsOnly = false } = {}) {
    // pathLine false: no path line above the names, a file manager's panel.
    // detailsOnly: a one-row foot of what the cursor is on - size, date,
    // attributes - with no path and no name; the window's title says where.
    const flags = (multi ? 1 : 0) | (pathLine ? 0 : 4) | (detailsOnly ? 8 : 0);
    const [first, ...rest] = entryParts(entries);
    const id = readU16(this.call(Op.Files, u16(parent), rect(0, top, 0, 0), u8(flags), str(mask), str(path), first), 0);
    for (const more of rest) this.call(Op.AddFiles, u16(id), more);
    return id;
  }
  /** Another folder in the panel: the person went somewhere else. */
  setFiles(id, path, entries, mask = '*.*') {
    const [first, ...rest] = entryParts(entries);
    this.call(Op.SetFiles, u16(id), str(path), str(mask), first);
    for (const more of rest) this.call(Op.AddFiles, u16(id), more);
  }
  /** A line in the panel saying what went wrong. */
  filesError(id, text) { this.call(Op.SetFilesError, u16(id), str(text)); }
  /**
   * A hex dump of bytes, filling its window: offsets, sixteen bytes a row,
   * the same bytes as characters. At most what one request carries, 64K.
   */
  hex(parent, data) {
    const b = data instanceof Uint8Array ? data : new Uint8Array(data);
    return readU16(this.call(Op.Hex, u16(parent), rect(0, 0, 0, 0), b.subarray(0, 65000)), 0);
  }
  /** What happened in a panel since last asked: kind 1 a name entered, 2 a path typed, 0 nothing. */
  takeFiles(id) {
    const r = this.call(Op.TakeFiles, u16(id));
    return { kind: r[0], text: readStr(r, 1).text };
  }
  /** Every mark off a panel: the marked files were copied, moved or deleted. */
  unmark(id) { this.call(Op.Unmark, u16(id)); }
  /** The marked names, or the one under the cursor when none are. */
  markedNames(id) {
    const r = this.call(Op.MarkedNames, u16(id));
    const out = [];
    let at = 2;
    for (let i = 0; i < readU16(r, 0); i++) {
      const s = readStr(r, at);
      out.push(s.text);
      at = s.next;
    }
    return out;
  }

  // ---- the bars

  menuBar(...menus) { return readU16(this.call(Op.MenuBar, menuBytes(menus)), 0); }
  menuCheck(cmd, on) { this.call(Op.MenuCheck, u16(cmd), u8(on ? 1 : 0)); }
  statusLine(...items) { return readU16(this.call(Op.Status, statusBytes(items)), 0); }
  /** Keys a window carries: on the status line and bound only while it is the active one. */
  windowStatus(window, ...items) { this.call(Op.WindowStatus, u16(window), statusBytes(items)); }
  /** Menus a window carries, merged into the bar while it is active. */
  windowMenu(window, ...menus) { this.call(Op.WindowMenu, u16(window), menuBytes(menus)); }

  // ---- the palette

  /** Every colour the toolkit draws with: [{ group, name, attr }], in the order setColor indexes. */
  palette() {
    const r = this.call(Op.Palette);
    const out = [];
    let at = 1;
    for (let i = 0; i < r[0]; i++) {
      const g = readStr(r, at);
      const n = readStr(r, g.next);
      out.push({ group: g.text, name: n.text, attr: r[n.next] });
      at = n.next + 1;
    }
    return out;
  }
  setColor(index, attribute) { this.call(Op.SetColor, u8(index), u8(attribute)); }

  // ---- events in, results out

  /** A key: [kind, value, mods] as encodeKey makes them. */
  key(kind, value, mods = 0) { this.call(Op.Key, u8(kind), u16(value), u8(mods)); }
  /** A key by name: press('Enter'), press('x', { alt: true }), press('F4'). */
  press(key, mods = {}) { const k = encodeKey(key, mods); if (k) this.key(...k); }
  /** Characters, typed. */
  type(text) { for (const ch of text) this.press(ch); }
  /** kind: 0 down, 1 up, 2 drag, 3 move, 4 wheel up, 5 wheel down, 6 double. button: 0 left, 1 right, 2 middle. */
  mouse(kind, x, y, button = 0) { this.call(Op.Mouse, u8(kind), u8(button), i16(x), i16(y)); }
  click(x, y) { this.mouse(0, x, y); this.mouse(1, x, y); }
  /** The ninety milliseconds a pressed button is shown down are over: it may happen now. */
  tick() { this.call(Op.Tick); }
  /** What has happened: a button pressed and a command chosen (menu, status line), each 0 for none. */
  take() {
    const r = this.call(Op.Take);
    return { pressed: readU16(r, 0), command: readU16(r, 2) };
  }
  /** The screen as it is now. */
  frame() {
    const r = this.call(Op.Frame);
    if (readU16(r, 9) > this.glyphs.length) this.glyphs = this.fetchGlyphs();
    return new Frame(r, this.glyphs);
  }
}

// ---------------------------------------------------------------- screen

// The box-drawing characters as arms - left, right, up, down; 0 none, 1
// single, 2 double - drawn as bars from the cell's edges, so the lines
// meet whatever the font. A font's ═ is narrower than its cell.
const ARMS = {
  0x2500: [1, 1, 0, 0], 0x2502: [0, 0, 1, 1], 0x250C: [0, 1, 0, 1], 0x2510: [1, 0, 0, 1], 0x2514: [0, 1, 1, 0], 0x2518: [1, 0, 1, 0],
  0x251C: [0, 1, 1, 1], 0x2524: [1, 0, 1, 1], 0x252C: [1, 1, 0, 1], 0x2534: [1, 1, 1, 0], 0x253C: [1, 1, 1, 1],
  0x2550: [2, 2, 0, 0], 0x2551: [0, 0, 2, 2], 0x2552: [0, 2, 0, 1], 0x2553: [0, 1, 0, 2], 0x2554: [0, 2, 0, 2],
  0x2555: [2, 0, 0, 1], 0x2556: [1, 0, 0, 2], 0x2557: [2, 0, 0, 2], 0x2558: [0, 2, 1, 0], 0x2559: [0, 1, 2, 0], 0x255A: [0, 2, 2, 0],
  0x255B: [2, 0, 1, 0], 0x255C: [1, 0, 2, 0], 0x255D: [2, 0, 2, 0], 0x255E: [0, 2, 1, 1], 0x255F: [0, 1, 2, 2], 0x2560: [0, 2, 2, 2],
  0x2561: [2, 0, 1, 1], 0x2562: [1, 0, 2, 2], 0x2563: [2, 0, 2, 2], 0x2564: [2, 2, 0, 1], 0x2565: [1, 1, 0, 2], 0x2566: [2, 2, 0, 2],
  0x2567: [2, 2, 1, 0], 0x2568: [1, 1, 2, 0], 0x2569: [2, 2, 2, 0], 0x256A: [2, 2, 1, 1], 0x256B: [1, 1, 2, 2], 0x256C: [2, 2, 2, 2],
};

// Every arm a bar from the edge; how far past the centre it reaches makes
// the join. A double arm is two bars d apart: each stops d short of the
// centre if a double crosses on its side, at the centre if a single does,
// d past it if nothing does. A single arm reaches d past the centre when
// a double crosses it, bridging the double's two lines.
function drawBox(ctx, x0, y0, w, h, a) {
  const t = Math.max(1, Math.floor(h / 14));
  const d = Math.max(2, Math.floor(h / 8));
  const cx = x0 + Math.floor(w / 2), cy = y0 + Math.floor(h / 2);
  const [l, r, u, dn] = a;
  const bar = (xa, ya, xb, yb) => ctx.fillRect(Math.min(xa, xb), Math.min(ya, yb), Math.abs(xb - xa), Math.abs(yb - ya));
  const reach = (same, other) => (same === 2 ? -d : same === 1 ? 0 : other === 1 ? 0 : d);
  const singleReach = (p, q) => (p === 2 || q === 2 ? d : 0);
  for (const [arm, dir] of [[l, -1], [r, 1]]) {
    if (!arm) continue;
    const edge = dir < 0 ? x0 : x0 + w;
    if (arm === 1) {
      bar(edge, cy, cx - dir * singleReach(u, dn) + (dir < 0 ? t : 0), cy + t);
    } else {
      for (const s of [-1, 1]) {
        const y = cy + s * d;
        const [same, other] = s < 0 ? [u, dn] : [dn, u];
        bar(edge, y, cx - dir * reach(same, other) + (dir < 0 ? t : 0), y + t);
      }
    }
  }
  for (const [arm, dir] of [[u, -1], [dn, 1]]) {
    if (!arm) continue;
    const edge = dir < 0 ? y0 : y0 + h;
    if (arm === 1) {
      bar(cx, edge, cx + t, cy - dir * singleReach(l, r) + (dir < 0 ? t : 0));
    } else {
      for (const s of [-1, 1]) {
        const x = cx + s * d;
        const [same, other] = s < 0 ? [l, r] : [r, l];
        bar(x, edge, x + t, cy - dir * reach(same, other) + (dir < 0 ? t : 0));
      }
    }
  }
}

/** The sixteen colours of the IBM CGA, as every emulator shows them. */
const PALETTE = [
  '#000000', '#0000aa', '#00aa00', '#00aaaa', '#aa0000', '#aa00aa', '#aa5500', '#aaaaaa',
  '#555555', '#5555ff', '#55ff55', '#55ffff', '#ff5555', '#ff55ff', '#ffff55', '#ffffff',
];

/** A canvas that shows frames and reports keys and the mouse, in cells. */
export class Screen {
  constructor(canvas, { font = '18px "Cascadia Mono", "Consolas", "DejaVu Sans Mono", monospace', cellHeight = 22 } = {}) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d', { alpha: false });
    this.font = font;
    this.ctx.font = font;
    this.cellW = Math.ceil(this.ctx.measureText('M').width);
    this.cellH = cellHeight;
    this.patterns = new Map();
    this.blink = true;
  }

  /** As many whole cells as the canvas's box holds: { cols, rows }. */
  fit(width = window.innerWidth, height = window.innerHeight) {
    const cols = Math.max(20, Math.floor(width / this.cellW));
    const rows = Math.max(8, Math.floor(height / this.cellH));
    const dpr = window.devicePixelRatio || 1;
    this.canvas.width = cols * this.cellW * dpr;
    this.canvas.height = rows * this.cellH * dpr;
    this.canvas.style.width = cols * this.cellW + 'px';
    this.canvas.style.height = rows * this.cellH + 'px';
    this.ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    this.ctx.font = this.font;
    this.ctx.textBaseline = 'middle';
    return { cols, rows };
  }

  /** A cell under a mouse event. */
  cellAt(e) {
    const r = this.canvas.getBoundingClientRect();
    return { x: Math.floor((e.clientX - r.left) / this.cellW), y: Math.floor((e.clientY - r.top) / this.cellH) };
  }

  shade(which, fg, bg) {
    const key = which + fg + bg;
    let p = this.patterns.get(key);
    if (p) return p;
    // The dots a DOS card drew for ░ ▒ ▓, one 8x8 tile per colour pair.
    const rows = [[0x22, 0x88], [0xAA, 0x55], [0xDD, 0x77]][which];
    const c = document.createElement('canvas');
    c.width = 8;
    c.height = 8;
    const g = c.getContext('2d');
    g.fillStyle = bg;
    g.fillRect(0, 0, 8, 8);
    g.fillStyle = fg;
    for (let y = 0; y < 8; y++) for (let x = 0; x < 8; x++) if (rows[y & 1] & (0x80 >> x)) g.fillRect(x, y, 1, 1);
    p = this.ctx.createPattern(c, 'repeat');
    this.patterns.set(key, p);
    return p;
  }

  /** Every cell of a frame onto the canvas, and the caret. */
  draw(frame) {
    const { ctx, cellW: cw, cellH: ch } = this;
    for (let y = 0; y < frame.h; y++) {
      for (let x = 0; x < frame.w; x++) {
        const a = frame.attr(x, y);
        const fg = PALETTE[a & 15], bg = PALETTE[a >> 4];
        const px = x * cw, py = y * ch;
        const c = frame.char(x, y);
        const code = c.charCodeAt(0);
        ctx.fillStyle = bg;
        ctx.fillRect(px, py, cw, ch);
        if (code === 0 || c === ' ') continue;
        ctx.fillStyle = fg;
        if (code === 0x2588) ctx.fillRect(px, py, cw, ch);
        else if (code === 0x2580) ctx.fillRect(px, py, cw, ch / 2);
        else if (code === 0x2584) ctx.fillRect(px, py + ch / 2, cw, ch / 2);
        else if (code === 0x258C) ctx.fillRect(px, py, cw / 2, ch);
        else if (code === 0x2590) ctx.fillRect(px + cw / 2, py, cw / 2, ch);
        else if (code >= 0x2591 && code <= 0x2593) {
          ctx.fillStyle = this.shade(code - 0x2591, fg, bg);
          ctx.fillRect(px, py, cw, ch);
        } else if (ARMS[code]) drawBox(ctx, px, py, cw, ch, ARMS[code]);
        else ctx.fillText(c, px, py + ch / 2);
      }
    }
    if (this.blink && frame.cursorX >= 0 && frame.cursorY >= 0 && frame.cursorX < frame.w && frame.cursorY < frame.h) {
      ctx.fillStyle = PALETTE[frame.attr(frame.cursorX, frame.cursorY) & 15];
      ctx.fillRect(frame.cursorX * cw, (frame.cursorY + 1) * ch - 3, cw, 2);
    }
  }
}

// ------------------------------------------------------------------- run

/**
 * The whole browser program: load the core, size the desktop to the
 * window, make the application, and pass it what the person does.
 *
 *   run(canvas, owl => new App(owl))
 *
 * The application is any object with `onCommand(cmd)` - called for every
 * button pressed and command chosen; return false to end - and, if it
 * wants, `poll()`, called after every input for what is not a command
 * (a canvas click, a cluster ticked). Returns the Owlosui, for a page's
 * own scripts.
 */
export async function run(canvas, makeApp, { wasm = new URL('./owlosui-wire.wasm', import.meta.url), codePage = 437 } = {}) {
  const wire = await Wire.load(wasm);
  const screen = new Screen(canvas);
  let { cols, rows } = screen.fit();
  const owl = new Owlosui(wire, cols, rows, codePage);
  // For work that finishes later - a file read over the network: the
  // program calls this when it has changed the screen, and it is painted.
  owl.refresh = () => paint();
  // The cells' size and the canvas, for a page that lays something of its
  // own over a window (see place); and what it wants done after every
  // frame - put that something where the window now is.
  owl.screen = screen;
  owl.afterPaint = new Set();
  const app = makeApp(owl);
  let ended = false, holding = false;

  function end() {
    ended = true;
    const ctx = screen.ctx;
    ctx.fillStyle = '#000';
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.fillStyle = '#aaa';
    ctx.fillText('The program has ended. Reload the page to start it again.', 8, screen.cellH);
  }

  function deliver() {
    const { pressed, command } = owl.take();
    if (pressed && app.onCommand(pressed) === false) return end();
    if (command && app.onCommand(command) === false) return end();
  }

  function paint() {
    if (ended) return;
    const f = owl.frame();
    screen.draw(f);
    for (const after of owl.afterPaint) after();
    // A button pressed by a key is on the screen, down: leave it there
    // long enough to be seen, then let it happen.
    // One wait at a time: the cursor's blink paints too, and a second
    // timer would tick a falling window two steps at once.
    if (f.hold && !holding) {
      holding = true;
      setTimeout(() => { holding = false; if (ended) return; owl.tick(); deliver(); shareClipboard(); app.poll?.(); paint(); }, f.holdMs);
    }
  }

  // The page's clipboard is the core's: what the core copies - Copy, Cut,
  // a console's Ctrl+C, a context menu - goes to the computer's clipboard,
  // and a Paste the core was asked for waits for the computer's clipboard
  // to come in first. Asked after every input; the browser allows both
  // because a key or a click has just happened.
  let copied = owl.clipboard(true).copied, reading = false;
  function shareClipboard() {
    const s = owl.clipboard(true);
    if (s.copied !== copied) {
      copied = s.copied;
      navigator.clipboard?.writeText(owl.clipboardText()).catch(() => { /* refused: the core still has it */ });
    }
    if (s.paste && !reading) {
      reading = true;
      const read = navigator.clipboard?.readText ? navigator.clipboard.readText() : Promise.reject(new Error('no clipboard'));
      read.then(t => owl.clipboardPaste(t), () => owl.clipboardPaste('', { keep: true }))
        .finally(() => { reading = false; after(); });
    }
  }

  function after() {
    if (ended) return;
    deliver();
    shareClipboard();
    if (!ended) app.poll?.();
    paint();
  }

  // Ctrl+V and Shift+Insert are left to the browser, which answers with a
  // paste event carrying its clipboard - no permission to ask for. If none
  // comes, the key goes to the core after all.
  let pasteKey = 0;
  document.addEventListener('paste', e => {
    if (ended) return;
    if (e.target instanceof Element && e.target.closest('[data-owl-own-keys]')) return;
    clearTimeout(pasteKey);
    pasteKey = 0;
    e.preventDefault();
    owl.clipboardPaste(e.clipboardData?.getData('text/plain') ?? '', { now: true });
    after();
  });

  setInterval(() => { screen.blink = !screen.blink; paint(); }, 500);
  window.addEventListener('resize', () => {
    ({ cols, rows } = screen.fit());
    owl.resize(cols, rows);
    after();
  });
  document.addEventListener('keydown', e => {
    if (ended) return;
    // An element laid over the screen that takes the keyboard while it has
    // the focus - an emulator - marks itself so; its keys are its own.
    if (e.target instanceof Element && e.target.closest('[data-owl-own-keys]')) return;
    const k = encodeKey(e.key, { shift: e.shiftKey, ctrl: e.ctrlKey, alt: e.altKey });
    if (!k) return;
    if ((e.ctrlKey && !e.altKey && e.key.toLowerCase() === 'v') || (e.shiftKey && e.key === 'Insert')) {
      clearTimeout(pasteKey);
      pasteKey = setTimeout(() => { pasteKey = 0; owl.key(...k); after(); }, 80);
      return;
    }
    e.preventDefault();
    owl.key(...k);
    after();
  });
  let held = 0, lastDown = 0, lastAt = '';
  const button = e => (e.button === 2 ? 1 : e.button === 1 ? 2 : 0);
  canvas.addEventListener('contextmenu', e => e.preventDefault());
  canvas.addEventListener('mousedown', e => {
    if (ended) return;
    // A click on the screen takes the keyboard back from whatever had it.
    if (document.activeElement instanceof HTMLElement && document.activeElement !== document.body) document.activeElement.blur();
    const { x, y } = screen.cellAt(e);
    const b = button(e);
    held |= 1 << b;
    // A second press on the same cell within half a second is a double.
    const now = performance.now(), at = `${x},${y},${b}`;
    const twice = now - lastDown < 500 && at === lastAt;
    lastDown = twice ? 0 : now;
    lastAt = at;
    lastCell = { x, y };
    owl.mouse(twice ? 6 : 0, x, y, b);
    after();
    e.preventDefault();
  });
  // While a button is down - a window dragged by its title, resized by its
  // corner - the release and the moves are heard on the whole page, in the
  // capture phase, ahead of anything on it. An element laid over the screen
  // - an emulator's picture - would otherwise take the release for itself,
  // and the window would go on following a mouse whose button is long up.
  // The browser itself goes on sending a drag that began on the page, even
  // out past its edge. No pointer capture: it was tried, and quick clicks
  // went missing in the pilot's browser and in no other.
  const cell = e => {
    const { x, y } = screen.cellAt(e);
    return { x: Math.max(0, Math.min(cols - 1, x)), y: Math.max(0, Math.min(rows - 1, y)) };
  };
  let lastCell = { x: 0, y: 0 };
  window.addEventListener('mouseup', e => {
    if (ended || !(held & (1 << button(e)))) return;
    const { x, y } = (lastCell = cell(e));
    held &= ~(1 << button(e));
    owl.mouse(1, x, y, button(e));
    after();
  }, true);
  window.addEventListener('mousemove', e => {
    if (ended || !held) return;
    const { x, y } = (lastCell = cell(e));
    owl.mouse(2, x, y);
    after();
  }, true);
  // The page losing the focus while a button is down - Alt+Tab mid-drag -
  // is a release where the mouse last was: its mouseup goes to another window.
  window.addEventListener('blur', () => {
    if (ended || !held) return;
    for (let b = 0; b < 3; b++) if (held & (1 << b)) owl.mouse(1, lastCell.x, lastCell.y, b);
    held = 0;
    after();
  });
  canvas.addEventListener('wheel', e => {
    if (ended) return;
    const { x, y } = screen.cellAt(e);
    owl.mouse(e.deltaY < 0 ? 4 : 5, x, y);
    after();
    e.preventDefault();
  }, { passive: false });

  paint();
  return owl;
}
