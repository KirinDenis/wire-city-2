// The live map (the pilot, 2026-10-18: "who flies where, whether their
// camera is shared, a click opens the screen - the browser has resources to
// spare, draw the houses too, and zoom"). One room's sky as the server hosts
// it (OWLOS-LAN Sky.cs): the ground built from the room's seed exactly as
// the game builds it (world.js), the city blocks the game builds houses on,
// the aerodromes, the radar stations - and every jet in the sky where its
// last position put it, five times a second from the server, moved smoothly
// between. The world is a torus, as the game's is: the map wraps.
//
// It is drawn on a canvas of its own under the page's, seen through a hole
// in the window's inside, as the watched screens are (screens.js) - in real
// pixels, not in cells. The mouse is heard on the page's canvas, over the
// window's inside: the wheel zooms at the pointer, a drag moves the map, a
// click on a jet whose screen is shared watches it.

import { Style } from '../owlosui/owlosui.js';

const WORLD = 65536, NODE = 1024, BIAS = 8192;
const wrap = v => ((v % WORLD) + WORLD) % WORLD;
/** The shortest way from a to b on the torus, in world units. */
const toward = (a, b) => { const d = wrap(b - a); return d > WORLD / 2 ? d - WORLD : d; };

/** The ground's colour for a height 0..255, by the game's bands: sea below 88, the city's 120..167. */
function ground(h) {
  if (h < 70) return [18, 40, 92];
  if (h < 88) return [32, 70, 130];
  if (h < 94) return [176, 160, 112];
  if (h < 120) return [62, 118, 52];
  if (h < 168) return [96, 130, 64];
  if (h < 205) return [120, 100, 70];
  return [190, 190, 196];
}

export class SkyMap {
  /** owl; onPick(pilot): a jet clicked; loadWorld(seed) -> a world (world.js) or null; closeCmd: its close box. */
  constructor(owl, { closeCmd, onPick, loadWorld, closed = () => {}, games = [], log = null }) {
    Object.assign(this, { owl, closeCmd, onPick, loadWorld, closed, games, log });
    this.win = 0;
    this.room = '';
    this.state = null;          // the server's last: { seed, gid, rubble, next, pilots }
    this.jets = new Map();      // pid -> { from, to, at } for the smooth move between two updates
    this.me = null;             // this page's own pid, if it flies there
    this.view = { cx: 24576, cz: 24576, scale: 1 };   // the map's middle (the front line's), and pixels per node
    this.texture = null;        // the ground, for the seed it was made for
    owl.afterPaint?.add(() => this.layout());
  }

  get isOpen() { return !!this.win && !!this.owl.place(this.win); }
  owns(id) { return id !== 0 && id === this.win; }

  show(room) {
    const owl = this.owl, sc = owl.screen;
    this.room = room;
    if (this.isOpen) { owl.setText(this.win, this.title()); owl.activate(this.win); owl.refresh?.(); return; }
    const w = Math.min(owl.width, Math.max(50, Math.round(owl.width * 0.618)));
    const h = Math.min(owl.height - 2, Math.round(((w - 2) * (sc?.cellW ?? 10)) / (sc?.cellH ?? 22)) + 2);
    this.win = owl.window(this.title(), w, h, {
      x: Math.floor((owl.width - w) / 2), y: 1 + Math.round((owl.height - 2 - h) * 0.382), style: Style.Terminal, closeCmd: this.closeCmd,
    });
    owl.staticText(this.win, 1, 1, 'Waiting for the server...', w - 4, 1);
    owl.windowStatus(this.win, { label: '~+~ ~-~ ~Wheel~ Zoom', cmd: 0 }, { label: '~Home~ All', cmd: 0 }, { label: '~Space~ Me', cmd: 0 },
      { label: '~Drag~ Move', cmd: 0 }, { label: '~Click~ a shared screen', cmd: 0 });
    this.el = document.createElement('div');
    this.el.style.cssText = 'position:fixed;visibility:hidden;background:#000;z-index:0;touch-action:none';
    this.canvas = document.createElement('canvas');
    this.el.append(this.canvas);
    document.body.append(this.el);
    this.ctx = this.canvas.getContext('2d');
    this.hole = owl.hole(this.win);
    this.listen();
    this.view.scale = 0;        // fitted to the window at the first draw
    this.layout();
    this.frame = requestAnimationFrame(() => this.draw());
    owl.refresh?.();
  }

  title() { return `Live map - ${this.games.find(g => g.room === this.room)?.name ?? this.room}`; }

  close() {
    if (!this.win) return;
    cancelAnimationFrame(this.frame);
    this.unlisten?.();
    this.el?.remove();
    if (this.hole) { try { this.owl.close(this.hole); } catch { /* gone with its window */ } }
    if (this.owl.place(this.win)) this.owl.close(this.win);
    this.win = 0;
    this.hole = 0;
    this.closed();
    this.owl.refresh?.();
  }

  /** The server's five-a-second: the map and the jets - each jet moves from where it is drawn now to where it is said to be. */
  async update(m) {
    if (m.room !== this.room) return;
    const now = performance.now();
    if (this.state?.seed !== m.seed) await this.ground(m.seed);
    for (const p of m.pilots) {
      const was = this.jets.get(p.pid);
      const from = was ? this.where(was, now) : p;
      this.jets.set(p.pid, { from, to: p, at: now, p });
    }
    for (const pid of [...this.jets.keys()]) if (!m.pilots.some(p => p.pid === pid)) this.jets.delete(pid);
    // The shared war (OWL FLY III WAR.INC), as its host's last packets had it: bots
    // [slot, x, y, z, heading, down], moved smoothly like the jets; Shilkas
    // [n, x, z, hull, turret, burning], which crawl and need no smoothing.
    const bots = new Map();
    for (const [slot, x, y, z, heading, down] of m.war?.bots ?? []) {
      const to = { x: wrap(x), y, z: wrap(z), heading }, was = this.bots?.get(slot);
      const from = was && !was.down && !down && Math.abs(toward(was.to.x, to.x)) + Math.abs(toward(was.to.z, to.z)) < 4000 ? this.where(was, now) : to;
      bots.set(slot, { from, to, at: now, down: !!down });
    }
    this.bots = bots;
    this.state = m;
  }

  /** Where a jet is drawn now: between its last two positions, the short way round the torus. */
  where(j, now) {
    const t = Math.min(1, (now - j.at) / 200);
    return {
      x: wrap(j.from.x + toward(j.from.x, j.to.x) * t), z: wrap(j.from.z + toward(j.from.z, j.to.z) * t),
      y: j.from.y + (j.to.y - j.from.y) * t, heading: j.to.heading,
    };
  }

  /** The ground for a seed: the world as the game builds it, painted once - smooth heights and a light from the north-west. */
  async ground(seed) {
    let world = null;
    try { world = await this.loadWorld?.(seed); } catch (e) { this.log?.warn('map', `the world of seed ${seed}: ${e?.message ?? e}`); }
    this.world = world;
    const N = 512, img = new ImageData(N, N), hm = world?.hmap;
    const H = (x, z) => (hm ? hm[((x & 63) << 6) | (z & 63)] : 128);
    const at = (u, v) => {          // bilinear, in nodes, wrapping
      const x0 = Math.floor(u), z0 = Math.floor(v), fx = u - x0, fz = v - z0;
      const a = H(x0, z0) + (H(x0 + 1, z0) - H(x0, z0)) * fx, b = H(x0, z0 + 1) + (H(x0 + 1, z0 + 1) - H(x0, z0 + 1)) * fx;
      return a + (b - a) * fz;
    };
    for (let py = 0; py < N; py++) {
      for (let px = 0; px < N; px++) {
        // Texture pixel (px, py): x east, z north (py 0 the north edge).
        const u = (px / N) * 64, v = ((N - 1 - py) / N) * 64;
        const h = at(u, v), shade = (at(u - 0.5, v + 0.5) - at(u + 0.5, v - 0.5)) * 0.9;
        const c = ground(h), k = h < 88 ? 1 : Math.max(0.55, Math.min(1.35, 1 + shade / 40));
        const o = (py * N + px) * 4;
        img.data[o] = Math.min(255, c[0] * k); img.data[o + 1] = Math.min(255, c[1] * k); img.data[o + 2] = Math.min(255, c[2] * k); img.data[o + 3] = 255;
      }
    }
    const t = document.createElement('canvas');
    t.width = N; t.height = N;
    t.getContext('2d').putImageData(img, 0, 0);
    this.texture = t;
  }

  /** The canvas under the window's inside, after every paint; the window gone some other way takes it along. */
  layout() {
    if (!this.win) return;
    const { cellW, cellH, canvas } = this.owl.screen ?? {};
    const p = this.owl.place(this.win);
    if (!p) { setTimeout(() => this.close()); return; }
    const box = canvas.getBoundingClientRect(), dpr = devicePixelRatio || 1;
    this.area = { left: box.left + p.x * cellW, top: box.top + p.y * cellH, w: p.w * cellW, h: p.h * cellH };
    Object.assign(this.el.style, { left: `${this.area.left}px`, top: `${this.area.top}px`, width: `${this.area.w}px`, height: `${this.area.h}px`, visibility: 'visible' });
    const W = Math.round(this.area.w * dpr), Hh = Math.round(this.area.h * dpr);
    if (this.canvas.width !== W || this.canvas.height !== Hh) { this.canvas.width = W; this.canvas.height = Hh; }
    this.canvas.style.width = `${this.area.w}px`;
    this.canvas.style.height = `${this.area.h}px`;
  }

  /** World (x, z) to canvas pixels, and back - north up, east right. */
  toScreen(x, z) {
    const s = this.view.scale / NODE;
    return { sx: this.canvas.width / 2 + toward(this.view.cx, x) * s, sy: this.canvas.height / 2 - toward(this.view.cz, z) * s };
  }
  toWorld(sx, sy) {
    const s = this.view.scale / NODE;
    return { x: wrap(this.view.cx + (sx - this.canvas.width / 2) / s), z: wrap(this.view.cz - (sy - this.canvas.height / 2) / s) };
  }

  draw() {
    if (!this.win) return;
    this.frame = requestAnimationFrame(() => this.draw());
    const c = this.ctx, W = this.canvas.width, H = this.canvas.height, dpr = devicePixelRatio || 1;
    if (!W || !H) return;
    if (!this.view.scale) this.view.scale = Math.min(W, H) / 64;      // the whole world across the shorter side
    c.fillStyle = '#000';
    c.fillRect(0, 0, W, H);
    const s = this.view.scale;                 // pixels per node
    if (this.texture) {
      // The ground, tiled round the torus as far as the window reaches. Node 0
      // starts BIAS before world 0 (nx = (x + BIAS) >> 10): the texture's west
      // edge is world x -BIAS, its north edge world z 64 nodes - BIAS.
      c.imageSmoothingEnabled = true;
      const side = 64 * s;
      let x0 = this.toScreen(-BIAS, 0).sx, y0 = this.toScreen(0, WORLD - BIAS).sy;
      x0 -= Math.ceil(x0 / side) * side;
      y0 -= Math.ceil(y0 / side) * side;
      // Whole pixels and one over: two tiles never leave a hairline of black between them.
      for (let x = x0; x < W; x += side) for (let y = y0; y < H; y += side) c.drawImage(this.texture, Math.floor(x), Math.floor(y), Math.ceil(side) + 1, Math.ceil(side) + 1);
    }
    this.drawTown(c, s);
    this.drawFields(c, s, dpr);
    this.drawRadars(c, s, dpr);
    this.drawWar(c, s, dpr);
    this.drawJets(c, s, dpr);
    this.drawControls(c, dpr);
    if (!this.state) { c.fillStyle = '#ccc'; c.font = `${14 * dpr}px monospace`; c.fillText('waiting for the server...', 12 * dpr, 24 * dpr); }
  }

  /**
   * The city as the game builds it (world.js): a block it paves (built -
   * BLKCTY) gets its avenues, cells 0 and 1 of the block each way; a house
   * stands on every plot HBLD says yes to - two cells square, at cells 2, 4
   * and 6 of a block - roofed in its district's colour. The front line over
   * it all, as the game's own map draws it: a red step a band of 4 nodes.
   */
  drawTown(c, s) {
    const w = this.world;
    if (!w?.blocks) return;
    const W = this.canvas.width, H = this.canvas.height, blockPx = 2 * s, cellPx = s / 4;   // a block is 2x2 nodes, a cell a quarter node
    if (s >= 3) {
      for (let i = 0; i < 32; i++) {
        for (let j = 0; j < 32; j++) {
          // Block (i, j): cells 8i.. east, 8j.. north; its north-west corner on the screen.
          const { sx, sy } = this.toScreen(i * 2 * NODE - BIAS, (j * 2 + 2) * NODE - BIAS);
          if (sx < -blockPx || sy < -blockPx || sx > W || sy > H) continue;
          const district = (w.blocks[i * 32 + j] >> 4) & 3;
          if (w.built?.(w, i, j)) {
            // The avenues: the block's first two cells along its west and south sides.
            c.fillStyle = 'rgba(60,60,64,0.85)';
            c.fillRect(sx, sy, 2 * cellPx, blockPx);
            c.fillRect(sx, sy + blockPx - 2 * cellPx, blockPx, 2 * cellPx);
          }
          if (!w.building || cellPx < 1.5) continue;
          for (const a of [2, 4, 6]) {
            for (const b of [2, 4, 6]) {
              if (!w.building(w, i * 8 + a, j * 8 + b)) continue;
              // The house: cells a..a+1 east, b..b+1 north of the block's south-west corner.
              const x = sx + a * cellPx, y = sy + blockPx - (b + 2) * cellPx, pad = cellPx * 0.2;
              c.fillStyle = district === 1 ? '#c8c8d4' : district === 2 ? '#b09070' : '#dcc8a8';
              c.fillRect(x + pad, y + pad, 2 * cellPx - 2 * pad, 2 * cellPx - 2 * pad);
              c.strokeStyle = 'rgba(0,0,0,0.5)';
              c.lineWidth = 1;
              c.strokeRect(x + pad, y + pad, 2 * cellPx - 2 * pad, 2 * cellPx - 2 * pad);
            }
          }
        }
      }
    }
    if (w.border) {
      const dpr = devicePixelRatio || 1;
      c.strokeStyle = 'rgba(255,40,40,0.8)';
      c.lineWidth = 2 * dpr;
      c.setLineDash([6 * dpr, 4 * dpr]);
      c.beginPath();
      for (let b = 0; b < 16; b++) {
        const z = 24576 + w.border[b], a = this.toScreen(b * 4 * NODE - BIAS, z), e = this.toScreen((b + 1) * 4 * NODE - BIAS, z);
        if (Math.abs(e.sx - a.sx) > 4 * s + 1) continue;      // a band split by the torus's seam on the screen
        c.moveTo(a.sx, a.sy);
        c.lineTo(e.sx, e.sy);
      }
      c.stroke();
      c.setLineDash([]);
    }
  }

  /** The aerodromes: their runways to scale - 3000 by 300, along north - and their numbers. */
  drawFields(c, s, dpr) {
    for (const [n, f] of (this.world?.fields ?? []).entries()) {
      const { sx, sy } = this.toScreen(f.x, f.z);
      const len = Math.max(10 * dpr, (2 * (f.halfLength ?? 1500) / NODE) * s), wid = Math.max(3 * dpr, (2 * (f.halfWidth ?? 150) / NODE) * s);
      c.save();
      c.translate(sx, sy);
      c.fillStyle = '#3a3a3a';
      c.fillRect(-wid / 2, -len / 2, wid, len);
      c.fillStyle = '#ddd';
      for (let k = -len / 2 + wid; k < len / 2 - wid; k += wid * 2) c.fillRect(-wid / 10, k, wid / 5, wid);
      c.restore();
      c.fillStyle = '#eee';
      c.font = `${11 * dpr}px monospace`;
      c.fillText(`AF${n + 1}`, sx + wid + 3 * dpr, sy + 4 * dpr);
    }
  }

  drawRadars(c, s, dpr) {
    for (const [n, r] of (this.world?.radars ?? []).entries()) {
      const { sx, sy } = this.toScreen(r.x, r.z), down = (this.state?.rubble ?? 0) & (1 << n), R = 6 * dpr;
      c.strokeStyle = down ? '#ff4040' : '#60ff60';
      c.lineWidth = 2 * dpr;
      c.beginPath();
      if (down) { c.moveTo(sx - R, sy - R); c.lineTo(sx + R, sy + R); c.moveTo(sx + R, sy - R); c.lineTo(sx - R, sy + R); }
      else {
        c.arc(sx, sy, R, 0, Math.PI * 2);
        const a = (performance.now() / 1000) * Math.PI;          // the dish turning
        c.moveTo(sx, sy); c.lineTo(sx + Math.cos(a) * R * 1.6, sy + Math.sin(a) * R * 1.6);
      }
      c.stroke();
    }
  }

  /**
   * The war under the jets: the bots small, the two sides in the game's own
   * parity (an even slot flies with the pilots' green side, an odd one is
   * red), one shot down a grey cross where it fell; the Shilkas a hull and a
   * gun along the turret's bearing, one burning flickering where it stands.
   * And a line of what is left, top left.
   */
  drawWar(c, s, dpr) {
    const war = this.state?.war;
    if (!war) return;
    const now = performance.now(), side = n => (n % 2 ? '#ff5a4a' : '#52d852');
    for (const [n, x, z, hull, turret, burning] of war.shilkas ?? []) {
      const { sx, sy } = this.toScreen(wrap(x), wrap(z)), R = 4 * dpr;
      c.save();
      c.translate(sx, sy);
      c.rotate((hull / 256) * Math.PI * 2);
      c.fillStyle = burning ? (Math.floor(now / 120 + n) % 2 ? '#ff8000' : '#602000') : side(n);
      c.strokeStyle = '#000';
      c.lineWidth = 1 * dpr;
      c.fillRect(-R * 0.7, -R, R * 1.4, R * 2);
      c.strokeRect(-R * 0.7, -R, R * 1.4, R * 2);
      c.restore();
      if (burning) continue;
      const a = (turret / 256) * Math.PI * 2;
      c.strokeStyle = '#000';
      c.lineWidth = 1.5 * dpr;
      c.beginPath();
      c.moveTo(sx, sy);
      c.lineTo(sx + Math.sin(a) * R * 2.2, sy - Math.cos(a) * R * 2.2);
      c.stroke();
    }
    for (const [slot, b] of this.bots ?? []) {
      const at = this.where(b, now), { sx, sy } = this.toScreen(at.x, at.z), size = 5 * dpr;
      if (b.down) {
        c.strokeStyle = 'rgba(160,160,160,0.8)';
        c.lineWidth = 1.5 * dpr;
        c.beginPath();
        c.moveTo(sx - size * 0.6, sy - size * 0.6); c.lineTo(sx + size * 0.6, sy + size * 0.6);
        c.moveTo(sx + size * 0.6, sy - size * 0.6); c.lineTo(sx - size * 0.6, sy + size * 0.6);
        c.stroke();
        continue;
      }
      c.save();
      c.translate(sx, sy);
      c.rotate((at.heading / 256) * Math.PI * 2);
      c.fillStyle = side(slot);
      c.strokeStyle = '#000';
      c.lineWidth = 1 * dpr;
      c.beginPath();
      c.moveTo(0, -size); c.lineTo(size * 0.7, size * 0.8); c.lineTo(0, size * 0.4); c.lineTo(-size * 0.7, size * 0.8); c.closePath();
      c.fill(); c.stroke();
      c.restore();
    }
    const bots = war.bots ?? [], shk = war.shilkas ?? [];
    const up = bots.filter(b => !b[5]), burning = shk.filter(k => k[5]).length;
    const line = `war: green ${up.filter(b => b[0] % 2 === 0).length} · red ${up.filter(b => b[0] % 2).length} bots up, ${bots.length - up.length} down`
      + (shk.length ? ` · Shilkas ${shk.length - burning} up, ${burning} burning` : '');
    c.font = `${12 * dpr}px monospace`;
    c.lineWidth = 3 * dpr;
    c.strokeStyle = 'rgba(0,0,0,0.8)';
    c.strokeText(line, 8 * dpr, 18 * dpr);
    c.fillStyle = '#fff';
    c.fillText(line, 8 * dpr, 18 * dpr);
  }

  /** Every jet: an arrow along its heading, its pilot's animal or callsign, its height - and a screen mark if it is shared. */
  drawJets(c, s, dpr) {
    const now = performance.now();
    this.hits = [];
    // Labels already put: a jet beside another (two on one runway) puts its own lower, not on top.
    const taken = [], free = (x, y, w, h) => {
      for (let k = 0; k < 6 && taken.some(t => x < t.x + t.w && t.x < x + w && y < t.y + t.h && t.y < y + h); k++) y += h;
      taken.push({ x, y, w, h });
      return y;
    };
    for (const [pid, j] of this.jets) {
      const at = this.where(j, now), p = j.p, mine = pid === this.me;
      const { sx, sy } = this.toScreen(at.x, at.z), size = 9 * dpr;
      const a = (at.heading / 256) * Math.PI * 2;      // 0 north, 64 east: clockwise
      c.save();
      c.translate(sx, sy);
      c.rotate(a);
      c.fillStyle = p.dying ? (Math.floor(now / 150) % 2 ? '#ff3030' : '#ffb000') : mine ? '#ffff40' : p.name ? '#ffffff' : '#a0c8ff';
      c.strokeStyle = '#000';
      c.lineWidth = 1.5 * dpr;
      c.beginPath();
      c.moveTo(0, -size); c.lineTo(size * 0.7, size * 0.8); c.lineTo(0, size * 0.4); c.lineTo(-size * 0.7, size * 0.8); c.closePath();
      c.fill(); c.stroke();
      c.restore();
      // The height as the cockpit's altimeter shows it: world units (HUD.INC prints camy as it is).
      const label = `${p.name ?? `jet ${String.fromCharCode(65 + (pid % 26))}`}${mine ? ' (you)' : ''}  ALT ${Math.round(at.y)}`;
      c.font = `${12 * dpr}px monospace`;
      // To the right of the jet - or, near the window's right edge, to its left.
      const lw = c.measureText(label).width, right = sx + size + 3 * dpr + lw + 50 * dpr < this.canvas.width;
      const lx = right ? sx + size + 3 * dpr : sx - size - 3 * dpr - lw;
      const ly = free(lx, sy - 14 * dpr, lw + 50 * dpr, (p.sharing ? 34 : 16) * dpr) + 12 * dpr;
      c.lineWidth = 3 * dpr;
      c.strokeStyle = 'rgba(0,0,0,0.8)';
      c.strokeText(label, lx, ly);
      c.fillStyle = mine ? '#ffff80' : '#fff';
      c.fillText(label, lx, ly);
      if (p.sharing) {
        // A shared screen: a small red "on air" sign under the name - click it, or the jet.
        const bx = lx, by = ly + 6 * dpr, bw = 46 * dpr, bh = 14 * dpr;
        c.fillStyle = '#c00000';
        c.fillRect(bx, by, bw, bh);
        c.fillStyle = '#fff';
        c.font = `${10 * dpr}px monospace`;
        c.fillText('► watch', bx + 3 * dpr, by + 10 * dpr);
        this.hits.push({ p, x0: bx, y0: by, x1: bx + bw, y1: by + bh });
      }
      this.hits.push({ p, x0: sx - size * 1.5, y0: sy - size * 1.5, x1: sx + size * 1.5, y1: sy + size * 1.5 });
    }
  }

  /**
   * The mouse over the window's inside. Over a hole OWLOSUI lets the mouse
   * through its canvas (pointer-events none there, once the pointer has
   * moved), as it does to the DOS PC's picture - so the canvas, where this
   * used to listen, never heard a press or a wheel over the map: drag,
   * click and wheel did nothing while the status line offered them (the
   * pilot, 2026-10-19). Now it listens on the window and asks two things:
   * is the cell under the pointer a hole (nothing drawn over the map there)
   * - and of the pictures under the canvas, is ours the one in front there
   * (site.js stackPictures orders them).
   */
  listen() {
    const target = window;
    const inArea = e => this.area && this.owl.place(this.win) && e.clientX >= this.area.left && e.clientX < this.area.left + this.area.w &&
      e.clientY >= this.area.top && e.clientY < this.area.top + this.area.h;
    const inside = e => {
      if (!inArea(e)) return false;
      // In a slot of an HTML page of one's own (htmlpage.js): no hole there - the map is on top where its slot is.
      if (this.slotted?.()) {
        const top = document.elementFromPoint(e.clientX, e.clientY);
        return !!top && (top === this.el || this.el.contains(top));
      }
      const { cellW, cellH, canvas } = this.owl.screen ?? {};
      if (!canvas) return false;
      const box = canvas.getBoundingClientRect();
      const x = Math.floor((e.clientX - box.left) / cellW), y = Math.floor((e.clientY - box.top) / cellH);
      if (!this.owl.holes().some(h => h.y === y && x >= h.x && x < h.x + h.w)) return false;
      const top = document.elementsFromPoint(e.clientX, e.clientY).find(el => el !== canvas);
      return !!top && (top === this.el || this.el.contains(top));
    };
    const local = e => { const dpr = devicePixelRatio || 1; return { sx: (e.clientX - this.area.left) * dpr, sy: (e.clientY - this.area.top) * dpr }; };
    let drag = null;
    const down = e => { if (!inside(e)) return; drag = { ...local(e), cx: this.view.cx, cz: this.view.cz, moved: false }; };
    const move = e => {
      if (!drag) return;
      const { sx, sy } = local(e), s = this.view.scale / NODE;
      if (Math.abs(sx - drag.sx) + Math.abs(sy - drag.sy) > 4) drag.moved = true;
      this.view.cx = wrap(drag.cx - (sx - drag.sx) / s);
      this.view.cz = wrap(drag.cz + (sy - drag.sy) / s);
    };
    const up = e => {
      const d = drag;
      drag = null;
      if (!d || d.moved || !inside(e)) return;
      const { sx, sy } = local(e);
      // The map's own buttons first, then the jets.
      const button = (this.buttons ?? []).find(h => sx >= h.x0 && sx <= h.x1 && sy >= h.y0 && sy <= h.y1);
      if (button) { button.act(); return; }
      const hit = (this.hits ?? []).find(h => sx >= h.x0 && sx <= h.x1 && sy >= h.y0 && sy <= h.y1);
      if (hit) this.onPick?.(hit.p);
    };
    const wheel = e => {
      if (!inside(e)) return;
      e.preventDefault();
      const { sx, sy } = local(e);
      this.zoom(e.deltaY < 0 ? 1.25 : 0.8, sx, sy);
    };
    // The keys, while the map is the window in front: + and - zoom, Home the whole world, Space your jet.
    const key = e => {
      if (!this.win || this.owl.active() !== this.win || e.ctrlKey || e.altKey) return;
      const act = { '+': () => this.zoom(1.5), '=': () => this.zoom(1.5), '-': () => this.zoom(1 / 1.5), _: () => this.zoom(1 / 1.5),
        Home: () => this.whole(), ' ': () => this.onMe() }[e.key];
      if (!act) return;
      e.preventDefault();
      e.stopImmediatePropagation();
      act();
    };
    target.addEventListener('pointerdown', down, true);
    window.addEventListener('pointermove', move, true);
    window.addEventListener('pointerup', up, true);
    target.addEventListener('wheel', wheel, { passive: false, capture: true });
    window.addEventListener('keydown', key, true);
    this.unlisten = () => {
      target.removeEventListener('pointerdown', down, true);
      window.removeEventListener('pointermove', move, true);
      window.removeEventListener('pointerup', up, true);
      target.removeEventListener('wheel', wheel, { capture: true });
      window.removeEventListener('keydown', key, true);
    };
  }

  /** Closer (factor > 1) or farther, at a point of the canvas - the middle, unless the pointer's: the point under it stays under it. */
  zoom(factor, sx = this.canvas.width / 2, sy = this.canvas.height / 2) {
    const before = this.toWorld(sx, sy), min = Math.min(this.canvas.width, this.canvas.height) / 64;
    this.view.scale = Math.max(min, Math.min(min * 48, this.view.scale * factor));
    const after = this.toWorld(sx, sy);
    this.view.cx = wrap(this.view.cx + toward(after.x, before.x));
    this.view.cz = wrap(this.view.cz + toward(after.z, before.z));
  }

  /** The whole world in the window, its middle the front line's. */
  whole() {
    this.view.scale = Math.min(this.canvas.width, this.canvas.height) / 64;
    this.view.cx = 24576;
    this.view.cz = 24576;
  }

  /** Your own jet in the middle, close enough to see the town round it. */
  onMe() {
    const j = this.me != null ? this.jets.get(this.me) : null;
    if (!j) return;
    const at = this.where(j, performance.now());
    this.view.cx = at.x;
    this.view.cz = at.z;
    this.view.scale = Math.max(this.view.scale, (Math.min(this.canvas.width, this.canvas.height) / 64) * 8);
  }

  /**
   * The map's own controls, drawn on it: + and - zoom, ALL the whole world,
   * ME your jet (while you fly) - top right; a scale bar bottom left, in the
   * game's own measure (DATA.INC: a world unit is half a metre - the F-15 is
   * 26 units across against 13 metres of span).
   */
  drawControls(c, dpr) {
    const W = this.canvas.width, H = this.canvas.height, B = 26 * dpr, gap = 6 * dpr;
    this.buttons = [];
    const list = [['+', () => this.zoom(1.5)], ['−', () => this.zoom(1 / 1.5)], ['ALL', () => this.whole()]];
    if (this.me != null && this.jets.has(this.me)) list.push(['ME', () => this.onMe()]);
    let y = gap;
    c.font = `bold ${12 * dpr}px monospace`;
    c.textAlign = 'center';
    c.textBaseline = 'middle';
    for (const [label, act] of list) {
      const x = W - gap - B;
      c.fillStyle = 'rgba(0,0,0,0.65)';
      c.fillRect(x, y, B, B);
      c.strokeStyle = 'rgba(255,255,255,0.8)';
      c.lineWidth = 1 * dpr;
      c.strokeRect(x + 0.5, y + 0.5, B - 1, B - 1);
      c.fillStyle = '#fff';
      c.fillText(label, x + B / 2, y + B / 2 + 1 * dpr);
      this.buttons.push({ x0: x, y0: y, x1: x + B, y1: y + B, act });
      y += B + gap / 2;
    }
    c.textAlign = 'start';
    c.textBaseline = 'alphabetic';
    // The scale: the roundest length between 60 and 160 pixels.
    const pxPerMetre = (this.view.scale / NODE) * 2;
    const metres = [50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000].find(m => m * pxPerMetre >= 60 * dpr) ?? 20000;
    const len = metres * pxPerMetre, x0 = 12 * dpr, y0 = H - 14 * dpr;
    c.fillStyle = 'rgba(0,0,0,0.6)';
    c.fillRect(x0 - 6 * dpr, y0 - 20 * dpr, len + 12 * dpr, 28 * dpr);
    c.strokeStyle = '#fff';
    c.lineWidth = 2 * dpr;
    c.beginPath();
    c.moveTo(x0, y0 - 5 * dpr); c.lineTo(x0, y0); c.lineTo(x0 + len, y0); c.lineTo(x0 + len, y0 - 5 * dpr);
    c.stroke();
    c.fillStyle = '#fff';
    c.font = `${11 * dpr}px monospace`;
    c.fillText(metres >= 1000 ? `${metres / 1000} km` : `${metres} m`, x0, y0 - 8 * dpr);
  }
}
