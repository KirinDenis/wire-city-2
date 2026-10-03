// What a DOS machine says on the network, counted and read.
//
// DOSBox has an IPX network card. In a browser there are no IPX cables and
// no UDP, so js-dos carries each IPX packet in one WebSocket message to a
// relay server, which passes it to the other machines in the same room -
// the DOS program does not know. Every byte of it goes through a WebSocket
// that the page itself opens, so the page can count it: the tap replaces
// window.WebSocket with one that tells it what went through.
//
// An IPX packet starts with a 30-byte header, big-endian: checksum, length,
// transport control, type, then the destination's network, node and socket
// and the source's. The node is the machine's six-byte address, which the
// relay gives out. That is what the sniffer shows.

const KEEP = 200;

export class NetTap {
  static instance = null;

  /** Once per page: every WebSocket made after this is counted. */
  static install() {
    if (NetTap.instance) return NetTap.instance;
    const tap = new NetTap();
    NetTap.instance = tap;
    if (typeof window === 'undefined' || !window.WebSocket) return tap; // not a browser: nothing to tap
    const Real = window.WebSocket;
    class Tapped extends Real {
      constructor(url, protocols) {
        super(url, protocols);
        const link = tap.opened(String(url));
        this.owlLink = link;
        this.addEventListener('message', e => tap.seen(link, 'in', e.data));
        this.addEventListener('open', () => { link.state = 'open'; tap.emit(); });
        this.addEventListener('close', () => { link.state = 'closed'; tap.emit(); });
        this.addEventListener('error', () => { link.state = 'error'; tap.emit(); });
      }
      send(data) {
        tap.seen(this.owlLink, 'out', data);
        return super.send(data);
      }
    }
    window.WebSocket = Tapped;
    return tap;
  }

  constructor() {
    this.links = [];      // every connection: { url, state, sent, received, packetsOut, packetsIn }
    this.packets = [];    // the last KEEP packets, newest last
    this.history = [];    // bytes per second, for a graph: { t, out, in }
    this.listeners = new Set();
    this.bucket = { t: Math.floor(Date.now() / 1000), out: 0, in: 0 };
  }

  on(f) { this.listeners.add(f); return () => this.listeners.delete(f); }
  emit() { for (const f of this.listeners) f(this); }

  opened(url) {
    const link = { url, state: 'connecting', sent: 0, received: 0, packetsOut: 0, packetsIn: 0, opened: Date.now() };
    this.links.push(link);
    this.emit();
    return link;
  }

  seen(link, dir, data) {
    const bytes = data instanceof ArrayBuffer ? new Uint8Array(data)
      : ArrayBuffer.isView(data) ? new Uint8Array(data.buffer, data.byteOffset, data.byteLength)
        : new TextEncoder().encode(String(data));
    if (link) {
      if (dir === 'out') { link.sent += bytes.length; link.packetsOut++; } else { link.received += bytes.length; link.packetsIn++; }
    }
    this.tick();
    this.bucket[dir] += bytes.length;
    this.packets.push({ at: Date.now(), dir, size: bytes.length, ...ipx(bytes) });
    if (this.packets.length > KEEP) this.packets.splice(0, this.packets.length - KEEP);
    this.emit();
  }

  /** Close the second that has passed into the history; the graph reads it. */
  tick() {
    const now = Math.floor(Date.now() / 1000);
    while (this.bucket.t < now) {
      this.history.push(this.bucket);
      if (this.history.length > 600) this.history.shift();
      this.bucket = { t: this.bucket.t + 1, out: 0, in: 0 };
      if (now - this.bucket.t > 600) this.bucket.t = now;
    }
  }

  totals() {
    const t = { sent: 0, received: 0, packetsOut: 0, packetsIn: 0 };
    for (const l of this.links) { t.sent += l.sent; t.received += l.received; t.packetsOut += l.packetsOut; t.packetsIn += l.packetsIn; }
    return t;
  }
}

/** An IPX header read, or { ipx: false } for something that is not one. */
export function ipx(b) {
  if (b.length < 30) return { ipx: false };
  const u16 = at => (b[at] << 8) | b[at + 1];
  const node = at => Array.from(b.subarray(at, at + 6), x => x.toString(16).padStart(2, '0')).join(':');
  return {
    ipx: true,
    length: u16(2),
    type: b[5],
    to: node(10), toSocket: u16(16),
    from: node(22), fromSocket: u16(28),
    payload: b.length - 30,
  };
}
