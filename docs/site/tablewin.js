// A window round a CellTable, laid out as Map Drives was worked out with
// the pilot (2026-10-16) - so that every table window of the site is the
// same: Map Drives, the Games catalog.
//
//   ┌──────────────────────── Title ────────────────────────┐
//   │  ┌──────┬─────────────┬────────┐                       │
//   │  │ ...  │ ...         │    ... │  the table, the width  │
//   │  └──────┴─────────────┴────────┘                       │
//   │  [ Open ]  [ Add ]  [ Edit ]       the row's own buttons│
//   │                                                         │
//   │  The words: what the window does, or what the row in    │
//   │  the bar is - as many lines as the widest need.         │
//   │                                                         │
//   │                                            [ Close ]    │
//   └─────────────────────────────────────────────────────────┘
//
//  - its size by the golden section: 0.618 of the screen's width, the
//    height by the golden ratio in the screen's own cells - or, `tall`,
//    what its rows and words need - set 0.382 of the way down;
//  - grey as a dialog, but its size the person's: the corner to drag, the
//    zoom box; laid out again WHILE its size changes, and let go smaller
//    than `min` it goes back to `min`, where it stood;
//  - a narrower table leaves columns out, the least needed first (CellTable);
//  - the row's own buttons in a row a line under the table, each always in
//    its place - one that does not apply to the row is not there, and leaves
//    its place empty; Close alone at the bottom right, a free line above it:
//    working on the rows is one thing, leaving the window another.

import { Style } from '../owlosui/owlosui.js';
import { CellTable } from './table.js';

/** How many lines a static folds `text` into at `width`: a word that does not fit goes to the next line. */
export function wrappedLines(text, width) {
  let lines = 1, used = 0;
  for (const word of text.split(/\s+/)) {
    const need = (used ? 1 : 0) + word.length;
    if (used + need > width) { lines++; used = word.length; } else used += need;
  }
  return lines;
}

export class TableWindow {
  /**
   * base: the first of seven command numbers of its own - the bar's keys
   * and Close. rows(): the rows, a text a column. buttons(i): the row's
   * own, [{ key, label, cmd, default, shown }], in their order. keys(i): its
   * status line for that row. words(i): the paragraphs under the buttons.
   * open(i): Enter's and a double click's. closed(): after it is gone.
   */
  constructor(app, { title, base, columns, rows, buttons = () => [], keys = () => [], words = () => [],
    open = null, closed = null, min = { w: 56, h: 20 }, tall = false }) {
    Object.assign(this, { app, owl: app.owl, title, columns, rows, buttons, keys, words, opener: open, closed, min, tall });
    this.cmd = { up: base, down: base + 1, pageUp: base + 2, pageDown: base + 3, home: base + 4, end: base + 5, close: base + 6 };
    this.win = 0;
    this.table = null;
    this.labels = {};             // each button's words now, by its key
    this.widest = {};             // and the longest they have been: its place
    this.owl.afterPaint.add(() => this.watchSize());
    window.addEventListener('pointerdown', () => { this.mouseDown = true; }, true);
    window.addEventListener('pointerup', () => { this.mouseDown = false; }, true);
  }

  get isOpen() { return !!this.win && !!this.owl.place(this.win); }
  get current() { return this.table?.current ?? 0; }

  /** rect: where the window goes, if not where the golden section puts it. */
  show(rect = null) {
    const owl = this.owl, sc = owl.screen;
    if (this.isOpen) owl.close(this.win);
    const W = owl.width, H = owl.height;
    let { x, y, w, h } = rect ?? {};
    if (!rect) {
      w = Math.min(W, Math.max(this.min.w, Math.max(100, Math.round(W * 0.618))));
      h = this.tall ? this.rows().length + 4 + 10 + this.wordLines(w) : Math.round((w * (sc?.cellW ?? 10)) / ((sc?.cellH ?? 22) * 1.618));
    }
    w = Math.min(W, Math.max(this.min.w, w));
    h = Math.min(H - 2, Math.max(this.min.h, h));
    if (!rect) { x = Math.floor((W - w) / 2); y = 1 + Math.round((H - 2 - h) * 0.382); }
    // The core's FIXED bit (0x02) and NO_ZOOM bit (0x04) taken off a dialog's style.
    this.win = owl.window(this.title, w, h, { x, y, style: Style.Dialog & ~0x06, closeCmd: this.cmd.close });
    this.rect = { x, y, w, h };
    this.views = [];
    this.said = [];
    this.slots = { y: 0, at: {} };
    this.layout();
  }

  /** Shown again where and as big as it was - its rows changed in number. */
  again() { if (this.isOpen) this.show(this.rect); }

  close() {
    if (this.isOpen) this.owl.close(this.win);
    this.win = 0;
    this.table = null;
    this.rect = null;
    this.closed?.();
  }

  /** The rows again, the bar where it was: what they say changed, not how many. */
  refreshRows() { if (this.isOpen && this.table) this.table.setRows(this.rows()); }

  select(i) { this.table?.select(i); }

  /** The words' lines at a window's width: the most any row needs, so nothing moves as the bar does. */
  wordLines(w) {
    let most = 0;
    for (let i = 0; i < Math.max(1, this.rows().length); i++) {
      const ps = this.words(i);
      most = Math.max(most, ps.reduce((n, p) => n + wrappedLines(p, w - 7), 0) + Math.max(0, ps.length - 1));
    }
    return most;
  }

  /**
   * What is inside, for the size it has now - made again whenever that
   * changes, in the same window, so a drag of its corner goes on. A margin
   * of two columns and a row; the table; a line under it, the buttons;
   * the words; a free line; Close. Below `min` the views keep min's size,
   * and the window cuts them until it is let go.
   */
  layout() {
    const owl = this.owl, win = this.win, p = win && owl.place(win);
    if (!p) return;
    const keep = this.table?.current ?? 0;
    for (const id of [...this.views, ...this.said, ...Object.values(this.slots.at)]) owl.close(id);
    this.views = [];
    this.said = [];
    this.saidOf = null;
    this.slots.at = {};
    const w = Math.max(this.min.w, p.w + 2), h = Math.max(this.min.h, p.h + 2);
    this.size = { w: p.w + 2, h: p.h + 2 };
    // A static folds a column short of its width: counted at w - 7, it came out right at 56 and at 106.
    this.wordsAt = { w, lines: this.wordLines(w) };
    // A free line between the words and Close: the table gives it up (the pilot - Close stays where it is).
    const th = Math.max(6, h - 10 - this.wordsAt.lines);
    this.table = new CellTable(owl, win, {
      x: 2, y: 1, w: w - 2 - 4, h: th, columns: this.columns, rows: this.rows(),
      onOpen: i => this.opener?.(i),
      onSelect: () => this.place(),
    });
    this.views.push(this.table.canvas);
    this.slots.y = 1 + th + 1;
    this.wordsY = 1 + th + 4;
    // By hand, not owl.buttons: a dialog's own row makes its first button the
    // default, and Enter must be the row's, not close the window. Esc closes.
    this.views.push(owl.buttonRow(win, w - 2 - 2 - 10, h - 2 - 2, [{ label: 'Close', cmd: this.cmd.close, cancel: true }]));
    this.table.select(keep);              // and with it the row's buttons, words and keys
  }

  /** The row in the bar: its buttons shown or taken away, its words, its keys on the status line. */
  place() {
    const owl = this.owl, win = this.win, i = this.current;
    if (!this.isOpen || !this.table) return;
    // Each button where it always is, with the same gap after each: its words, the padding and shadow, two cells.
    // A button whose words change (Share my screen, Stop sharing) is made again; its place is its longest words'.
    let x = 2;
    for (const b of this.buttons(i)) {
      const at = this.slots.at[b.key];
      if (at && (!b.shown || this.labels[b.key] !== b.label)) { owl.close(at); delete this.slots.at[b.key]; }
      if (b.shown && !this.slots.at[b.key]) {
        this.slots.at[b.key] = owl.buttonRow(win, x, this.slots.y, [{ label: b.label, cmd: b.cmd, default: !!b.default }]);
        this.labels[b.key] = b.label;
      }
      this.widest[b.key] = Math.max(this.widest[b.key] ?? 0, b.label.replace(/~/g, '').length);
      x += this.widest[b.key] + 4 + 1 + 2;
    }
    const ps = this.words(i), of = ps.join('\n');
    if (of !== this.saidOf) {
      for (const id of this.said) owl.close(id);
      this.said = [];
      let y = this.wordsY;
      for (const p of ps) {
        const n = wrappedLines(p, this.wordsAt.w - 7);
        this.said.push(owl.staticText(win, 2, y, p, this.wordsAt.w - 6, n));
        y += n + 1;
      }
      this.saidOf = of;
    }
    const c = this.cmd;
    owl.windowStatus(win, ...this.keys(i),
      { label: '', cmd: c.up, key: 'ArrowUp' }, { label: '', cmd: c.down, key: 'ArrowDown' },
      { label: '', cmd: c.pageUp, key: 'PageUp' }, { label: '', cmd: c.pageDown, key: 'PageDown' },
      { label: '', cmd: c.home, key: 'Home' }, { label: '', cmd: c.end, key: 'End' });
    owl.refresh?.();
  }

  /**
   * After every paint: whether the window changed its size - its corner, its
   * zoom box, Ctrl+F5. Laid out again at once, not after the paint it was
   * heard in. Let go smaller than `min` - the core lets a window go down to
   * 6 by 3 - it is made again at `min`, where it stood.
   */
  watchSize() {
    const owl = this.owl, win = this.win;
    const p = win && owl.place(win);
    if (!p || !this.size) return;
    const now = { x: p.x - 1, y: p.y - 1, w: p.w + 2, h: p.h + 2 };
    this.rect = now;
    if (now.w !== this.size.w || now.h !== this.size.h) {
      this.size = { w: now.w, h: now.h };
      setTimeout(() => { if (this.win === win) { this.layout(); owl.refresh?.(); } });
    }
    if (now.w >= this.min.w && now.h >= this.min.h) return;
    clearTimeout(this.resizing);
    this.resizing = setTimeout(() => {
      const q = this.win === win && owl.place(win);
      if (!q) return;
      if (this.mouseDown) { this.watchSize(); return; }
      if (q.w + 2 < this.min.w || q.h + 2 < this.min.h) this.show({ x: q.x - 1, y: q.y - 1, w: q.w + 2, h: q.h + 2 });
    }, 250);
  }

  /** A click on the table. */
  poll() { if (this.isOpen && this.table) this.table.poll(); }

  handles(cmd) { return Object.values(this.cmd).includes(cmd); }

  onCommand(cmd) {
    const t = this.table, c = this.cmd;
    switch (cmd) {
      case c.close: this.close(); break;
      case c.up: t?.move(-1); break;
      case c.down: t?.move(1); break;
      case c.pageUp: t?.move(-(t?.room ?? 1)); break;
      case c.pageDown: t?.move(t?.room ?? 1); break;
      case c.home: t?.home(); break;
      case c.end: t?.end(); break;
    }
  }
}
