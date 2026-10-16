// A table drawn cell by cell on an OWLOSUI canvas - what a list cannot be:
// a colour a column, striped rows, single lines between the columns, the
// heads inside the same frame as the rows (the pilot, 2026-10-16: "these
// effects are cheap, and we will use them somewhere else too").
//
//   ┌──────┬──────────────┬───────┐
//   │ Drive│ Kind         │  Size │   the heads, on a band of their own
//   ├──────┼──────────────┼───────┤
//   │ A:   │ floppy       │ 9.1 MB│   a row, a stripe
//   │ B:   │ floppy       │  1 KB │   the next, a stripe of the other blue
//   └──────┴──────────────┴───────┘
//
// A column: { head, width, align: 'left' | 'right', colour, drop } - width
// counts its two spaces of padding, 0 for the one column that takes what
// the others leave; `drop`, a number, lets a narrow table leave the column
// out (the highest goes first). A row: an array of texts, a column each.
// The bar - the row in hand - is moved by the page's keys (move, home,
// end) and by a click; a second click on the same row within half a second
// is `onOpen`.

import { attr, Color } from '../owlosui/owlosui.js';

/** The table's colours: CGA's own, as the rest of the screen's. */
export const TableLook = {
  frame: Color.LightCyan,
  // The heads on the table's own blue, in yellow, as Norton's were: those
  // years did not set heads on a band of their own (the pilot, 2026-10-16).
  head: { fg: Color.Yellow, bg: Color.Blue },
  // Rows plain: stripes were tried, and were too bright and too new for the
  // look. Two the same - a page that wants stripes gives two colours.
  stripes: [Color.Blue, Color.Blue],
  empty: Color.Blue,
  // The bar - the row in hand - as OWLOSUI's own lists have it, black on
  // cyan: a light blue bar was tried and liked, but a cursor of one table's
  // own is not how those programs looked - styles come later, for the whole
  // site at once (the pilot, 2026-10-16). fg null would keep the columns'
  // colours on it.
  bar: { fg: Color.Black, bg: Color.Cyan },
};

export class CellTable {
  /** x, y, w, h: the canvas inside `win`. */
  /** onSelect(i): the bar moved - a page that shows the row's own buttons hears it. */
  constructor(owl, win, { x, y, w, h, columns, rows = [], onOpen = null, onSelect = null, look = TableLook }) {
    Object.assign(this, { owl, win, x, y, w, h, onOpen, onSelect, look });
    this.canvas = owl.canvas(win, x, y, w, h);
    this.all = columns;
    this.rows = rows;
    this.current = 0;
    this.top = 0;
    this.lastClick = null;
    this.fit();
  }

  /** The rows a screenful holds: the frame's two lines, the heads and their line. */
  get room() { return Math.max(1, this.h - 4); }

  /** The columns that fit, the flexible one given what is left. */
  fit() {
    let cols = [...this.all];
    const need = list => list.reduce((n, c) => n + (c.width || 16), 0) + list.length + 1;   // the flexible one wants 16 at least
    while (need(cols) > this.w && cols.some(c => c.drop)) {
      const worst = cols.reduce((a, c) => ((c.drop ?? 0) > (a.drop ?? 0) ? c : a));
      cols = cols.filter(c => c !== worst);
    }
    const fixed = cols.reduce((n, c) => n + c.width, 0) + cols.length + 1;
    // `at`: the column's place in a row - a row has a text for every column, shown or left out.
    this.columns = cols.map(c => ({ ...c, at: this.all.indexOf(c), width: c.width || Math.max(4, this.w - fixed) }));
  }

  setRows(rows) {
    this.rows = rows;
    this.current = Math.min(this.current, Math.max(0, rows.length - 1));
    this.draw();
  }

  move(by) { this.select(this.current + by); }
  home() { this.select(0); }
  end() { this.select(this.rows.length - 1); }
  select(i) {
    this.current = Math.max(0, Math.min(this.rows.length - 1, i));
    if (this.current < this.top) this.top = this.current;
    if (this.current >= this.top + this.room) this.top = this.current - this.room + 1;
    this.draw();
    this.onSelect?.(this.current);
  }

  /** A click on a row puts the bar there; a second one on it, quickly, opens it. */
  poll() {
    const c = this.owl.canvasClick(this.canvas);
    if (!c) return false;
    const i = this.top + c.y - 3;
    if (c.y < 3 || i < 0 || i >= this.rows.length) return false;
    const now = Date.now(), again = this.lastClick && this.lastClick.i === i && now - this.lastClick.at < 500;
    this.lastClick = { i, at: now };
    this.select(i);
    if (again) this.onOpen?.(i);
    return true;
  }

  /**
   * One line of the canvas: chars and attributes, w each. frameBg: the
   * colour under the frame's two outer lines - the bar lives inside the
   * frame and never paints them (the pilot); innerAttr: the lines between
   * the columns, when they are not the frame's colour (on the bar).
   */
  line(texts, colourOf, bg, joints, { frameBg = bg, innerAttr = null } = {}) {
    const L = this.look, chars = [], attrs = [];
    const put = (s, a) => { for (const ch of s) { chars.push(ch); attrs.push(a); } };
    put(joints[0], attr(L.frame, frameBg));
    this.columns.forEach((c, k) => {
      const room = c.width - 2;
      let t = String(texts[c.at ?? k] ?? '');
      t = t.length > room ? `${t.slice(0, room - 1)}…` : t;
      t = c.align === 'right' ? t.padStart(room) : t.padEnd(room);
      put(` ${t} `, attr(colourOf(c), bg));
      const last = k === this.columns.length - 1;
      put(last ? joints[2] : joints[1], last ? attr(L.frame, frameBg) : innerAttr ?? attr(L.frame, bg));
    });
    return { chars, attrs };
  }

  draw() {
    const owl = this.owl, L = this.look, W = this.columns.reduce((n, c) => n + c.width, 0) + this.columns.length + 1;
    const rule = (l, m, r, bg) => {
      let s = l;
      this.columns.forEach((c, k) => { s += '─'.repeat(c.width) + (k === this.columns.length - 1 ? r : m); });
      return { chars: [...s], attrs: new Array(s.length).fill(attr(L.frame, bg)) };
    };
    // The heads' band is the frame's top line, the heads and the line under them.
    const lines = [rule('┌', '┬', '┐', L.head.bg)];
    lines.push(this.line(this.all.map(c => c.head), () => L.head.fg, L.head.bg, '│││'));
    lines.push(rule('├', '┼', '┤', L.head.bg));
    for (let r = 0; r < this.room; r++) {
      const i = this.top + r, row = this.rows[i];
      const bar = i === this.current && row;
      const base = row ? L.stripes[i % 2] : L.empty;
      lines.push(this.line(row ?? [], c => (bar && L.bar.fg !== null ? L.bar.fg : c.colour ?? Color.White), bar ? L.bar.bg : base, '│││',
        bar ? { frameBg: base, innerAttr: attr(L.bar.fg ?? L.frame, L.bar.bg) } : {}));
    }
    lines.push(rule('└', '┴', '┘', L.empty));
    // The canvas is wider than the table if the columns came out short: blank the rest.
    lines.forEach((l, y) => {
      const pad = Math.max(0, this.w - W);
      owl.blit(this.canvas, 0, y, W + pad, 1, [...l.chars, ...' '.repeat(pad)], [...l.attrs, ...new Array(pad).fill(attr(Color.LightGray, Color.LightGray))]);
    });
    owl.refresh?.();
  }
}
