// Someone's DOS screen, watched (the pilot, 2026-10-18: "the list marks who
// shares - select one and watch their screen"). Each is a window of its
// own, black as a game's DOS window is, the picture as big as it fits with
// square pixels. The picture comes from the server (OWLOS-LAN, Site.cs:
// /site/watch/<animal>) in the console core's codec (../console/cast.js),
// and lies under the page's canvas, seen through a hole in the window's
// inside - so a menu or a dialog over it hides only the cells it covers.
// The same way OWLOS LAN's watchers.js lays its broadcasts.

import { Style } from '../owlosui/owlosui.js';
import { Decoder, WAITING } from '../console/cast.js';

export class Screens {
  /** url(name): the watch address; closeCmd: the windows' close box; changed(): one opened or closed. */
  constructor(owl, { url, closeCmd, changed = () => {}, log = null }) {
    Object.assign(this, { owl, url, closeCmd, changed, log });
    this.views = new Map();      // name -> { win, el, canvas, ctx, ws, dec, picture, hole }
    owl.afterPaint?.add(() => this.layout());
  }

  get watching() { return [...this.views.keys()]; }
  owns(id) { return id !== 0 && [...this.views.values()].some(v => v.win === id); }

  /** A window on `name`'s screen - the one there is, if it is open already. */
  open(name) {
    const owl = this.owl, sc = owl.screen;
    const there = this.views.get(name);
    if (there && owl.place(there.win)) { owl.activate(there.win); owl.refresh?.(); return; }
    // Its inside 4:3 in pixels, as a DOS screen is; the golden section across.
    const w = Math.min(owl.width, Math.max(42, Math.round(owl.width * 0.5)));
    const h = Math.min(owl.height - 2, Math.round(((w - 2) * (sc?.cellW ?? 10) * 0.75) / (sc?.cellH ?? 22)) + 2);
    const x = Math.floor((owl.width - w) / 2) + 2 * this.views.size, y = 1 + Math.round((owl.height - 2 - h) * 0.382) + this.views.size;
    const win = owl.window(`Watching ${name}`, w, h, { x, y, style: Style.Terminal, closeCmd: this.closeCmd });
    owl.staticText(win, 1, Math.max(0, Math.floor((h - 2) / 2) - 1), `Waiting for ${name}'s DOS PC to start...`, w - 4, 2);
    const el = document.createElement('div');
    el.style.cssText = 'position:fixed;visibility:hidden;background:#000;display:flex;align-items:center;justify-content:center;pointer-events:none;z-index:0';
    const canvas = document.createElement('canvas');
    canvas.width = 320; canvas.height = 200;
    canvas.style.cssText = 'image-rendering:pixelated;image-rendering:crisp-edges';
    el.append(canvas);
    document.body.append(el);
    const v = { name, win, el, canvas, ctx: canvas.getContext('2d'), dec: null, ws: null, chain: Promise.resolve(), picture: false, hole: 0 };
    this.connect(v);
    this.views.set(name, v);
    this.log?.info('watch', `watching ${name}`);
    this.layout();
    this.changed();
    owl.refresh?.();
  }

  /** The picture's line, to /site/watch/<name>: a whole frame first, then what changes. */
  connect(v) {
    const owl = this.owl, { name, win, canvas } = v;
    v.dec = new Decoder();
    v.ws = new WebSocket(this.url(name));
    v.ws.binaryType = 'arraybuffer';
    v.ws.onmessage = e => {
      const msg = new Uint8Array(e.data);
      v.chain = v.chain.then(async () => {
        const img = await v.dec.decode(msg);
        if (img === WAITING) { if (v.picture) this.pictured(v, false); return; }
        if (!img) return;
        if (canvas.width !== img.width || canvas.height !== img.height) { canvas.width = img.width; canvas.height = img.height; this.fit(v); }
        v.ctx.putImageData(img, 0, 0);
        if (!v.picture) this.pictured(v, true);
      }).catch(err => this.log?.warn('watch', `${name}: ${err?.message ?? err}`));
    };
    // Their screen went off the air (they stopped, or left): the window says so and stays until closed.
    v.ws.onclose = () => {
      if (!this.views.has(name)) return;
      if (v.picture) this.pictured(v, false);
      if (owl.place(win)) { owl.setText(win, `${name} - not sharing now`); owl.refresh?.(); }
    };
    if (owl.place(win)) owl.setText(win, `Watching ${name}`);
  }

  /** Who shares now (the list): a window whose screen went off the air takes it again when it comes back. */
  revive(sharing) {
    for (const v of this.views.values()) {
      if (v.ws.readyState === WebSocket.CLOSED && sharing.includes(v.name)) this.connect(v);
    }
  }

  /** A picture came, or went: the window's inside becomes a hole the picture shows through - or its own cells again. */
  pictured(v, on) {
    v.picture = on;
    if (on && !v.hole) v.hole = this.owl.hole(v.win);
    if (!on && v.hole) { try { this.owl.close(v.hole); } catch { /* gone with its window */ } v.hole = 0; }
    this.layout();
    this.owl.refresh?.();
  }

  /** The close box, or Alt+F3: that one stops. */
  closeWindow(id) {
    for (const [name, v] of this.views) if (v.win === id) this.close(name);
  }

  close(name) {
    const v = this.views.get(name);
    if (!v) return;
    this.views.delete(name);
    v.ws.onmessage = null;
    v.ws.onclose = null;
    v.ws.close();
    v.el.remove();
    if (v.hole) { try { this.owl.close(v.hole); } catch { /* gone with its window */ } }
    if (this.owl.place(v.win)) this.owl.close(v.win);
    this.log?.info('watch', `stopped watching ${name}`);
    this.changed();
    this.owl.refresh?.();
  }

  /** Every picture under its window's inside, after every paint; a window closed some other way takes its picture with it. */
  layout() {
    const { cellW, cellH, canvas } = this.owl.screen ?? {};
    if (!canvas) return;
    const box = canvas.getBoundingClientRect();
    for (const [name, v] of this.views) {
      const p = this.owl.place(v.win);
      if (!p) { setTimeout(() => this.close(name)); continue; }
      v.area = { w: p.w * cellW, h: p.h * cellH };
      Object.assign(v.el.style, {
        left: `${box.left + p.x * cellW}px`, top: `${box.top + p.y * cellH}px`,
        width: `${v.area.w}px`, height: `${v.area.h}px`, visibility: v.picture ? 'visible' : 'hidden',
      });
      this.fit(v);
    }
  }

  /** The picture as big as fits, square pixels, its own proportions. */
  fit(v) {
    if (!v.area) return;
    const f = Math.min(v.area.w / v.canvas.width, v.area.h / v.canvas.height);
    v.canvas.style.width = `${Math.floor(v.canvas.width * f)}px`;
    v.canvas.style.height = `${Math.floor(v.canvas.height * f)}px`;
  }
}
