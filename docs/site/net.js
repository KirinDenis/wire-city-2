// The site on the network (the pilot, 2026-10-18): anonymous - nobody signs
// in. The server (OWLOS-LAN, Site.cs) names this page's connection an
// animal, and the list of who is here is simply the connections there are:
// a reload is a new animal, and nothing of a visitor is kept once they go.
// What the others see of this page is its status, a code - playing a game,
// in a lesson, building, in the terminal, away - never a file's name, never
// what was typed.

/**
 * Where the server is: this computer's while the site is served from it,
 * else the public one. ?server=ws://... in the address, or localStorage
 * `site.server`, says another.
 */
export function serverUrl() {
  let asked = null;
  try {
    // Kept for the tab: a lesson opened writes its own address (?l=7), and a reload would lose ?server= with it.
    const given = new URLSearchParams(location.search).get('server');
    if (given) sessionStorage.setItem('site.server', given);
    asked = sessionStorage.getItem('site.server') ?? localStorage.getItem('site.server');
  } catch { /* storage refused */ }
  if (asked) return asked.replace(/\/$/, '');
  return ['localhost', '127.0.0.1'].includes(location.hostname) ? 'ws://localhost:8790' : 'wss://lan.owlos.sk';
}

/** What a status says, in words: { doing, what } from the server's list. */
export function doingText({ doing, what }, games = []) {
  switch (doing) {
    case 'play': return `plays ${games.find(g => g.key === what)?.name ?? what}`;
    case 'lesson': return `in lesson ${what.toUpperCase()}`;
    case 'build': return 'builds a program';
    case 'edit': return 'edits a file';
    case 'files': return 'goes through files';
    case 'terminal': return 'in the terminal';
    case 'watch': return 'watches a screen';
    case 'away': return 'away';
    default: return 'here';
  }
}

export class Presence {
  /**
   * onChange(): the list, the name or the line's state changed. onSoon(room,
   * seconds): a room's map changes in that long; onMap(m): it changed - the
   * server's clock, every half hour (OWLOS-LAN Sky.cs).
   */
  constructor({ url = serverUrl(), log = null, onChange = () => {}, onMap = null, onSoon = null, onPilots = null } = {}) {
    Object.assign(this, { url, log, onChange, onMap, onSoon, onPilots });
    this.following = '';        // the room whose live map this page watches
    this.asked = new Map();     // room -> the answer awaited for it
    this.ws = null;
    this.state = 'off';         // off, connecting, on
    this.me = null;             // this connection's animal, from the server's hello
    this.token = null;
    this.people = [];           // [{ name, doing, what, sharing, since }]
    this.here = 0;
    this.want = { doing: 'here', what: '' };
    this.sent = null;
    this.wait = 2000;
  }

  start() { if (this.state === 'off' && !this.timer) this.connect(); }

  connect() {
    this.timer = null;
    this.state = 'connecting';
    let ws;
    try { ws = new WebSocket(`${this.url}/site/live`); } catch (e) { this.lost(String(e?.message ?? e)); return; }
    this.ws = ws;
    ws.onopen = () => { this.state = 'on'; this.wait = 2000; this.log?.info('net', `connected to ${this.url}`); };
    ws.onmessage = e => {
      let m;
      try { m = JSON.parse(e.data); } catch { return; }
      if (m.type === 'hello') {
        this.me = m.you;
        this.token = m.token;
        this.sent = null;
        this.sentFollow = null;      // a new connection follows again what the old one did
        this.flush();
      } else if (m.type === 'people') {
        this.people = m.people ?? [];
        this.here = m.here ?? this.people.length;
      } else if (m.type === 'map' && m.sky) {
        // A room's sky: the answer to `map`, or - changed: true - the server's new map, on its clock.
        if (m.changed) { this.onMap?.(m); return; }
        const waiting = this.asked.get(m.sky.room);
        if (waiting) { this.asked.delete(m.sky.room); waiting(m); }
        return;
      } else if (m.type === 'sky') {
        this.onSoon?.(m.room, m.seconds);      // a minute before a room's new map
        return;
      } else if (m.type === 'pilots') {
        this.onPilots?.(m);                    // the live map of the room this page follows
        return;
      } else return;
      this.onChange();
    };
    ws.onclose = () => this.lost('the line closed');
  }

  /** The line gone: no name, no list - and again, a little later each time. */
  lost(why) {
    const was = this.state;
    this.ws = null;
    this.state = 'off';
    this.me = null;
    this.token = null;
    this.people = [];
    this.here = 0;
    if (was === 'on') this.log?.warn('net', `${this.url}: ${why} - trying again`);
    this.onChange();
    this.timer = setTimeout(() => this.connect(), this.wait);
    this.wait = Math.min(60000, this.wait * 2);
  }

  /** A game room's sky from the server: { sky: { room, seed, gid, rubble, next, every, pilots } }. */
  map(room) {
    if (this.state !== 'on' || !this.me) return Promise.reject(new Error(`not connected to the server (${this.url})`));
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => { this.asked.delete(room); reject(new Error('the server did not answer')); }, 5000);
      this.asked.set(room, m => { clearTimeout(timer); resolve(m); });
      this.ws.send(JSON.stringify({ type: 'map', room }));
    });
  }

  /**
   * This page's status: sent when it changes, and again on every new
   * connection. jet: { room, pid } while its DOS PC flies in a room of the
   * server's - the server checks it against the relay, then the live map
   * says which jet is this animal's.
   */
  status(doing, what = '', jet = null) {
    this.want = { doing, what: String(what).toLowerCase().replace(/[^a-z0-9]/g, '').slice(0, 16), ...(jet ? { room: jet.room, pid: jet.pid } : {}) };
    this.flush();
  }

  /** The live map of a room, from the server five times a second (onPilots) - or, '', no more. */
  follow(room) {
    this.following = room;
    this.sentFollow = null;
    this.flush();
  }

  flush() {
    if (this.state !== 'on' || !this.me) return;
    const s = JSON.stringify({ type: 'status', ...this.want });
    if (s !== this.sent) { this.sent = s; this.ws.send(s); }
    if (this.following !== this.sentFollow) { this.sentFollow = this.following; this.ws.send(JSON.stringify({ type: 'follow', room: this.following })); }
  }
}
