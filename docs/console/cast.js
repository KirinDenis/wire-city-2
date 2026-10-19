// Screen broadcast - THE SHARED CORE (2026-10-18; it was web/cast.js, which
// now only passes this on): the codec and the sender, every UI's - OWLOS
// LAN's cafe and the WIRE CITY site. A PROTOTYPE of the codec and of both ends.
//
// A DOS picture is small (320x200 is 64,000 pixels) and most of it stays
// still from one frame to the next. So: the frame is cut into 16x16 blocks,
// only the blocks that changed are sent, and the message is deflated. Every
// KEY_EVERY ms a whole frame goes, so a viewer who joins late, or lost a
// message, has a full picture again soon. The picture is exact - no video
// codec smearing pixel art - and the viewer scales it up with square pixels.
//
// Message kind 3 is the one byte alone: on air, but the DOS PC is not on yet
// (sent every KEY_EVERY ms while so; a viewer shows "waiting for DOS").
// Message: 1 byte kind (1 whole frame, 2 changed blocks), then deflate-raw of:
//   u16 width, u16 height, u16 blocks, and per block: u16 bx, u16 by (block
//   numbers), then its pixels as RGB, row by row (edge blocks are cut short).
// Later: palette indices instead of RGB, text mode as characters - see the
// owlos-lan skill, "Voice and broadcast".

export const BLOCK = 16;
const KEY = 1, DELTA = 2;
export const WAITING = 3;
const KEY_EVERY = 2000, EVERY = 100;   // ms: a whole frame, any frame

async function deflate(bytes) {
  return new Uint8Array(await new Response(new Blob([bytes]).stream().pipeThrough(new CompressionStream('deflate-raw'))).arrayBuffer());
}
async function inflate(bytes) {
  return new Uint8Array(await new Response(new Blob([bytes]).stream().pipeThrough(new DecompressionStream('deflate-raw'))).arrayBuffer());
}

/** Encodes RGBA frames (ImageData) into messages, remembering the last one. */
export class Encoder {
  constructor() { this.last = null; this.lastKey = 0; }

  async encode(img, now = performance.now()) {
    const { width: w, height: h, data } = img;
    const key = !this.last || this.last.length !== data.length || now - this.lastKey >= KEY_EVERY;
    const bw = Math.ceil(w / BLOCK), bh = Math.ceil(h / BLOCK);
    const blocks = [];
    for (let by = 0; by < bh; by++) {
      for (let bx = 0; bx < bw; bx++) {
        if (!key && !this.changed(data, w, h, bx, by)) continue;
        blocks.push([bx, by]);
      }
    }
    this.last = data.slice();
    if (key) this.lastKey = now;
    if (!key && blocks.length === 0) return null;
    // Size: header + per block 4 bytes + its pixels.
    let size = 6;
    for (const [bx, by] of blocks) size += 4 + Math.min(BLOCK, w - bx * BLOCK) * Math.min(BLOCK, h - by * BLOCK) * 3;
    const out = new Uint8Array(size), v = new DataView(out.buffer);
    v.setUint16(0, w, true); v.setUint16(2, h, true); v.setUint16(4, blocks.length, true);
    let at = 6;
    for (const [bx, by] of blocks) {
      v.setUint16(at, bx, true); v.setUint16(at + 2, by, true); at += 4;
      const x0 = bx * BLOCK, y0 = by * BLOCK, x1 = Math.min(w, x0 + BLOCK), y1 = Math.min(h, y0 + BLOCK);
      for (let y = y0; y < y1; y++) {
        for (let x = x0, p = (y * w + x0) * 4; x < x1; x++, p += 4) { out[at++] = data[p]; out[at++] = data[p + 1]; out[at++] = data[p + 2]; }
      }
    }
    const packed = await deflate(out);
    const msg = new Uint8Array(1 + packed.length);
    msg[0] = key ? KEY : DELTA;
    msg.set(packed, 1);
    return msg;
  }

  changed(data, w, h, bx, by) {
    const last = this.last;
    const x0 = bx * BLOCK, y0 = by * BLOCK, x1 = Math.min(w, x0 + BLOCK), y1 = Math.min(h, y0 + BLOCK);
    for (let y = y0; y < y1; y++) {
      for (let p = (y * w + x0) * 4, end = (y * w + x1) * 4; p < end; p += 4) {
        if (data[p] !== last[p] || data[p + 1] !== last[p + 1] || data[p + 2] !== last[p + 2]) return true;
      }
    }
    return false;
  }
}

/** Applies messages to an RGBA picture; whole frames reset it. */
export class Decoder {
  constructor() { this.img = null; }

  /** Returns the picture (ImageData) after the message, or null before the first whole frame. */
  async decode(msg) {
    const kind = msg[0];
    if (kind === WAITING) { this.img = null; return WAITING; }
    const body = await inflate(msg.subarray(1));
    const v = new DataView(body.buffer, body.byteOffset, body.byteLength);
    const w = v.getUint16(0, true), h = v.getUint16(2, true), n = v.getUint16(4, true);
    if (kind === KEY || !this.img || this.img.width !== w || this.img.height !== h) {
      if (kind !== KEY) return null;   // a change to a picture we do not have
      this.img = new ImageData(w, h);
    }
    const data = this.img.data;
    let at = 6;
    for (let i = 0; i < n; i++) {
      const bx = v.getUint16(at, true), by = v.getUint16(at + 2, true); at += 4;
      const x0 = bx * BLOCK, y0 = by * BLOCK, x1 = Math.min(w, x0 + BLOCK), y1 = Math.min(h, y0 + BLOCK);
      for (let y = y0; y < y1; y++) {
        for (let x = x0, p = (y * w + x0) * 4; x < x1; x++, p += 4) { data[p] = body[at++]; data[p + 1] = body[at++]; data[p + 2] = body[at++]; data[p + 3] = 255; }
      }
    }
    return this.img;
  }
}

/**
 * The sender: the DOS PC's picture (box.screenshot(), the frame as js-dos
 * has it) every EVERY ms, to /cast/<name> on our server. One frame in flight
 * at a time; a slow moment skips frames rather than piling them up.
 */
export class Caster {
  constructor(box, log) {
    this.box = box; this.log = log; this.ws = null; this.timer = 0; this.name = ''; this.sent = 0; this.bytes = 0;
    // For telemetry.js: time spent taking and encoding frames, and frames
    // skipped because the previous one was still being made or the line was behind.
    this.encMs = 0; this.encoded = 0; this.skipped = 0;
  }

  get onAir() { return !!this.ws; }

  /** url: where it goes - this page's own server's /cast/<name> unless a UI says another (the site: /site/cast?token=). */
  start(name, url = `${location.protocol === 'https:' ? 'wss' : 'ws'}://${location.host}/cast/${encodeURIComponent(name)}`) {
    if (this.ws) return;
    this.name = name;
    this.enc = new Encoder();
    this.ws = new WebSocket(url);
    this.ws.binaryType = 'arraybuffer';
    this.ws.onclose = () => { this.log?.info('cast', `${name}: off air, ${this.sent} messages, ${this.bytes} bytes`); this.stop(); };
    let busy = false, waitSent = -Infinity;
    this.timer = setInterval(async () => {
      if (this.ws?.readyState !== WebSocket.OPEN) return;
      if (busy || this.ws.bufferedAmount > 256 * 1024) { this.skipped++; return; }   // behind: skip, do not pile up
      busy = true;
      const t0 = performance.now();
      try {
        const img = this.box.running ? await this.box.screenshot() : null;
        if (!img) {
          // On air without a picture: say so, now and then; the next picture is a whole frame.
          this.enc = new Encoder();
          const now = performance.now();
          if (now - waitSent >= KEY_EVERY) { this.ws.send(new Uint8Array([WAITING])); waitSent = now; }
          return;
        }
        waitSent = -Infinity;
        const msg = await this.enc.encode(img);
        this.encMs += performance.now() - t0;
        this.encoded++;
        if (msg) { this.ws.send(msg); this.sent++; this.bytes += msg.length; }
      } catch (e) {
        this.log?.warn('cast', String(e?.message ?? e));
      } finally { busy = false; }
    }, EVERY);
    this.log?.info('cast', `${name}: on air`);
  }

  stop() {
    clearInterval(this.timer);
    this.timer = 0;
    const ws = this.ws;
    this.ws = null;
    if (ws && ws.readyState <= WebSocket.OPEN) ws.close();
  }
}
