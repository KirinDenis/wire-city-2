// The bus - THE SHARED CORE (2026-10-18), every UI's: the one channel of
// truth (references/console.md). A window does not call the code behind
// it: it sends a command, the command runs in the shell - the same one the
// terminal types into - and shows in the terminal's record, marked with the
// window it came from; its answer comes back to that window, as data.
//
//   send(line, { from, secret,     a command; resolves to its answer:
//         ...given })              { id, line, from, code, lines: [{ text,
//                                  tone }], data: [...], errors: [...] };
//                                  what else is given goes to the command
//                                  in ctx, as it is (a cafe, a table)
//   on(type, fn)                   events: 'command', 'answer', and whatever
//                                  a UI emits; '*' for all. Returns the way
//                                  to stop.
//   emit(type, data)               an event onto the bus
//
// A secret (a password from a form) goes to its command beside the line,
// never in it: the record shows `login petya`, nothing more. OWLOS LAN's
// bus (../bus.js) adds the server's live stream; the WIRE CITY site uses
// this one as it is.

const KEPT = 300;     // the last events, for the rigs and for `history` of the bus

export class Bus {
  constructor({ shell }) {
    this.shell = shell;
    this.handlers = new Map();     // type -> Set of fn(data, type)
    this.events = [];              // the last KEPT: { n, type, at, data }
    this.seq = 0;
  }

  on(type, fn) {
    if (!this.handlers.has(type)) this.handlers.set(type, new Set());
    this.handlers.get(type).add(fn);
    return () => this.handlers.get(type)?.delete(fn);
  }

  emit(type, data = {}) {
    this.events.push({ n: this.events.length ? this.events.at(-1).n + 1 : 1, type, at: Date.now(), data });
    if (this.events.length > KEPT) this.events.splice(0, this.events.length - KEPT);
    for (const fn of [...(this.handlers.get(type) ?? []), ...(this.handlers.get('*') ?? [])]) {
      try { fn(data, type); } catch (e) { console.error(`bus: ${type}:`, e); }
    }
  }

  /**
   * A window's command: run in the shell as if typed, its words and data
   * caught for the window that sent it. A question the command would ask
   * is answered No - a window asks its own (a Yes/No box) and says --yes.
   */
  async send(line, { from = '', secret = null, ...given } = {}) {
    const id = ++this.seq;
    this.emit('command', { id, line, from });
    const result = await this.shell.run(line, { capture: true, secret, from, ...given, ask: async () => null });
    const answer = { id, line, from, ...result };
    this.emit('answer', answer);
    return answer;
  }
}
