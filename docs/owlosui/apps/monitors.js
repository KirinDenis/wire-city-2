// DOS > Network monitor and DOS > Machine monitor: what can be seen of the
// DOS PC from outside it, drawn into a canvas of cells once a second.
//
// The network monitor reads the tap on the machine's WebSocket
// (lib/js/dosbox/nettap.js): bytes and packets each way, a graph of the
// last minute, and the packets themselves with their IPX addresses - a
// sniffer. The machine monitor reads what js-dos counts in the emulator:
// how many instructions' worth of cycles it ran each second, how much of
// the time it slept, how many pictures and sound buffers it sent - and
// what is on its disks. DOSBox does not hand the page DOS's own memory or
// its list of programs, so neither is here.

import { Style } from '../owlosui.js';

export const MonCm = { NetClose: 390, MachineClose: 391 };

const WHITE = 0x1F, YELLOW = 0x1E, CYAN = 0x1B, GREEN = 0x1A, GREY = 0x17, RED = 0x1C;

const kb = n => (n < 1024 ? `${n} B` : n < 1048576 ? `${(n / 1024).toFixed(1)} KB` : `${(n / 1048576).toFixed(2)} MB`);
const grouped = n => String(n).replace(/\B(?=(\d{3})+(?!\d))/g, ',');
const clock = t => new Date(t).toTimeString().slice(0, 8);

/** Words into lines no wider than width: a sentence in a window narrower than it is not cut off. */
function wrap(text, width) {
  const lines = [];
  let line = '';
  for (const word of text.split(' ')) {
    if (line && line.length + 1 + word.length > width) { lines.push(line); line = word; } else line = line ? `${line} ${word}` : word;
  }
  if (line) lines.push(line);
  return lines;
}

/** A bar graph of values, `rows` high, in half-cell steps: rows of text. */
function bars(values, width, rows, max) {
  const top = Math.max(max, 1);
  const cols = values.slice(-width);
  while (cols.length < width) cols.unshift(0);
  const out = [];
  for (let r = rows - 1; r >= 0; r--) {
    let line = '';
    for (const v of cols) {
      const halves = Math.round((v / top) * rows * 2) - r * 2;
      line += halves >= 2 ? '█' : halves === 1 ? '▄' : ' ';
    }
    out.push(line);
  }
  return out;
}

export class Monitors {
  constructor(owl, dos) {
    this.owl = owl;
    this.dos = dos;
    this.net = null;      // { win, canvas, w, h }
    this.machine = null;
    this.last = null;     // the previous second's counters, for rates
    this.rates = [];      // cycles a second, for the graph
    this.disks = '';
    if (typeof setInterval !== 'undefined') setInterval(() => this.tick(), 1000);
  }

  owns(id) { return id !== 0 && (id === this.net?.win || id === this.machine?.win); }

  onCommand(cmd) {
    if (cmd === MonCm.NetClose) this.closeWindow(this.net?.win);
    if (cmd === MonCm.MachineClose) this.closeWindow(this.machine?.win);
  }

  closeWindow(id) {
    if (!id) return;
    this.owl.close(id);
    if (id === this.net?.win) this.net = null;
    if (id === this.machine?.win) this.machine = null;
  }

  open(title, w, h, closeCmd, x) {
    const W = Math.min(w, this.owl.width), H = Math.min(h, this.owl.height - 2);
    const win = this.owl.window(title, W, H, { style: Style.Document, closeCmd, x: x ?? -1 });
    const canvas = this.owl.canvas(win, 0, 0, W - 2, H - 2);
    return { win, canvas, w: W - 2, h: H - 2 };
  }

  showNet() {
    if (this.net) { this.owl.activate(this.net.win); return; }
    this.net = this.open('Network monitor', 78, 24, MonCm.NetClose);
    this.drawNet();
  }

  showMachine() {
    if (this.machine) { this.owl.activate(this.machine.win); return; }
    this.machine = this.open('Machine monitor', 62, 18, MonCm.MachineClose);
    this.drawMachine(null);
  }

  /** Every line of a canvas written, padded, so last second's text does not show through. */
  lines(m, rows) {
    for (let y = 0; y < m.h; y++) {
      const [text, attr] = rows[y] ?? ['', WHITE];
      this.owl.blitText(m.canvas, 0, y, (text + ' '.repeat(m.w)).slice(0, m.w), attr);
    }
  }

  async tick() {
    if (!this.net && !this.machine) return;
    const stats = this.dos.box.running ? await this.dos.box.stats().catch(() => null) : null;
    if (this.net) this.drawNet();
    if (this.machine) await this.drawMachine(stats);
    this.owl.refresh?.();
  }

  drawNet() {
    const m = this.net, tap = this.dos.box.net, n = this.dos.network;
    tap.tick();
    const t = tap.totals();
    const rows = [];
    rows.push([` Relay  ${n.url || '(none)'}`, WHITE]);
    rows.push([` State  ${n.state}`, n.state === 'connected' ? GREEN : n.state === 'off' ? GREY : YELLOW]);
    rows.push([` Sent   ${kb(t.sent).padEnd(10)} in ${grouped(t.packetsOut)} packets     Received ${kb(t.received).padEnd(10)} in ${grouped(t.packetsIn)} packets`, WHITE]);
    const now = tap.history.at(-1) ?? { out: 0, in: 0 };
    rows.push([` Last second: ${kb(now.out)} out, ${kb(now.in)} in.   The last ${Math.min(60, m.w - 10)} seconds:`, GREY]);
    const width = m.w - 10;
    const hist = tap.history.slice(-width);
    const max = Math.max(1, ...hist.map(h => Math.max(h.in, h.out)));
    bars(hist.map(h => h.in), width, 3, max).forEach((line, i) => rows.push([(i === 0 ? ' Received' : '').padEnd(10) + line, CYAN]));
    bars(hist.map(h => h.out), width, 3, max).forEach((line, i) => rows.push([(i === 0 ? ' Sent' : '').padEnd(10) + line, YELLOW]));
    rows.push([` ${'time'.padEnd(9)}${'way'.padEnd(5)}${'bytes'.padStart(6)}  ${'from (node:socket)'.padEnd(23)}  to (node:socket)`, GREY]);
    if (tap.packets.length === 0) {
      for (const line of wrap('Nothing has gone over the wire yet. DOS > Play OWL FLY III puts a machine on it: ' +
        'every IPX packet it sends is one WebSocket message to the relay, counted here.', m.w - 2)) rows.push([` ${line}`, WHITE]);
    }
    const room = m.h - rows.length;
    for (const p of tap.packets.slice(-room).reverse()) {
      const addr = (node, sock) => (node ? `${node.slice(-11)}:${sock.toString(16).padStart(4, '0')}` : '?');
      const to = p.ipx && p.to === 'ff:ff:ff:ff:ff:ff' ? `everyone:${p.toSocket.toString(16).padStart(4, '0')}` : addr(p.to, p.toSocket);
      const line = p.ipx
        ? ` ${clock(p.at).padEnd(9)}${(p.dir === 'out' ? 'out' : 'in').padEnd(5)}${String(p.size).padStart(6)}  ${addr(p.from, p.fromSocket).padEnd(23)}  ${to}`
        : ` ${clock(p.at).padEnd(9)}${p.dir.padEnd(5)}${String(p.size).padStart(6)}  (not an IPX packet)`;
      rows.push([line, p.dir === 'out' ? YELLOW : CYAN]);
    }
    this.lines(m, rows);
  }

  async drawMachine(stats) {
    const m = this.machine, box = this.dos.box;
    const rows = [];
    if (!box.running) {
      for (const line of wrap('The DOS PC is off. DOS > Switch on starts it.', m.w - 2)) rows.push([` ${line}`, WHITE]);
      this.last = null;
      this.lines(m, rows);
      return;
    }
    rows.push([` Running   ${box.what}`, WHITE]);
    if (stats && this.last) {
      const dt = (Date.now() - this.last.at) / 1000;
      // The counter is 32 bits and goes round; the difference is what ran.
      const cycles = ((stats.cycles - this.last.cycles) >>> 0) / dt;
      const busy = Math.max(0, Math.min(100, 100 - ((stats.sleepTime - this.last.sleepTime) / (dt * 1000)) * 100));
      const frames = (stats.messageFrame - this.last.messageFrame) / dt;
      const sound = (stats.messageSound - this.last.messageSound) / dt;
      this.rates.push(cycles);
      if (this.rates.length > 120) this.rates.shift();
      rows.push([` CPU       ${(cycles / 1e6).toFixed(1)} million cycles a second`, GREEN]);
      rows.push([` Busy      ${busy.toFixed(0)}% of the time; the rest the emulator slept`, WHITE]);
      rows.push([` Picture   ${frames.toFixed(0)} frames a second sent to the page`, WHITE]);
      rows.push([` Sound     ${sound.toFixed(0)} buffers a second`, WHITE]);
    } else {
      rows.push([' Measuring...', GREY]);
    }
    if (stats) this.last = { ...stats, at: Date.now() };
    const width = m.w - 2;
    rows.push([' Cycles a second, the last two minutes:', GREY]);
    bars(this.rates, width, 4, Math.max(...this.rates, 1)).forEach(line => rows.push([' ' + line, GREEN]));
    if (!this.disks || Date.now() - (this.disksAt ?? 0) > 3000) {
      this.disksAt = Date.now();
      try {
        const tree = await box.ci.fsTree();
        const count = n => (n.nodes ? n.nodes.reduce((a, c) => { const x = count(c); return { files: a.files + x.files, bytes: a.bytes + x.bytes }; }, { files: 0, bytes: 0 }) : { files: 1, bytes: n.size ?? 0 });
        const drive = name => { const n = (tree.nodes ?? []).find(x => x.name === name); return n ? count(n) : { files: 0, bytes: 0 }; };
        const c = drive('C'), a = drive('A');
        this.disks = ` Disks     C: ${c.files} files, ${kb(c.bytes)}    A: ${a.files} files, ${kb(a.bytes)}`;
      } catch { /* switching off */ }
    }
    rows.push([this.disks, WHITE]);
    const t = box.net.totals();
    rows.push([` Network   ${this.dos.network.state}; ${kb(t.sent)} out, ${kb(t.received)} in`, WHITE]);
    for (const line of wrap("DOSBox does not show the page DOS's memory or programs; what is here is what js-dos counts in the emulator.", m.w - 2)) {
      rows.push([` ${line}`, GREY]);
    }
    this.lines(m, rows);
  }
}
