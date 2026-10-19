// The console's terminal - THE SHARED CORE (2026-10-16), every UI's: the
// shell (./shell.js) in a window - the Quake console players
// know, dropped from the top over whatever screen is shown, the whole width
// and 38.2% of the height (the golden ratio). Ctrl+` opens and closes it
// (by the key's place, so a Russian layout's ё does too); Escape closes it.
//
// OWLOSUI's console is a record, output only. So the prompt and the line
// being typed are its last line, written again on every key - a carriage
// return, erase-line, the prompt, the line with its caret reversed (SGR 7).
// No OWLOSUI patch.
//
// The line edits as readline does: Left/Right, Home/End, Ctrl+A/E,
// Backspace/Delete, Ctrl+W (a word back), Ctrl+U/K (to the start/the end),
// Ctrl+L (clear), Ctrl+C (drop the line, or stop what runs), Ctrl+V (paste).
// Up/Down walk the history, Ctrl+R searches back in it, Tab finishes a word
// (twice: what it could become). The history is kept in this browser - never
// a line typed with a space first, never an answer to a question.

import { Style } from '../owlosui/owlosui.js';
import { ANSI, RESET } from './shell.js';
import { Bus } from './bus.js';

export const CmTerminalClose = 950;
const HISTORY_MAX = 500;
const clean = s => s.replace(/[\x00-\x1f\x7f]/g, '');

export class Terminal {
  /**
   * makeShell({ write, ask }): the UI's shell (./shell.js, with its own
   * commands and paths). makeBus(shell): its bus (./bus.js, or a UI's own
   * over it) - what the windows send runs in this same shell and shows
   * here as if typed, marked with its window, its words under it. title:
   * the window's; welcome: its first line, ANSI; historyKey: where this
   * browser keeps what was typed.
   *
   * A second terminal of a page - a chat whose "shell" is a model (the
   * WIRE CITY site's AI > Chat, 2026-10-19) - says hotkey: false (Ctrl+`
   * stays the first one's), a closeCmd of its own, place(owl): the window's
   * { x, y, w, h } instead of the drop from the top, and status: its own
   * status line.
   */
  constructor(owl, { makeShell, makeBus = shell => new Bus({ shell }), app = null, log = null, title = 'Terminal', welcome = '', historyKey = 'console.history',
    hotkey = true, closeCmd = CmTerminalClose, place = null, status = null } = {}) {
    Object.assign(this, { owl, app, log, title, welcome, historyKey, hotkey, closeCmd, place, status });
    this.shell = makeShell({ write: t => this.write(t), ask: (q, o) => this.ask(q, o) });
    this.shell.exit = () => this.close();
    this.shell.saveHistory = () => this.saveHistory();
    this.bus = makeBus(this.shell);
    // The prompt from the start: a window's command sent before the terminal
    // was ever opened shows after it too, not after a bare >.
    this.shell.prompt().then(p => { if (!this.prompt) this.prompt = p; }, () => {});
    this.bus.on('command', ({ line, from }) => this.write(`\r\x1b[K${this.prompt || '> '}${line}${from ? `${ANSI.muted}  # ${from}${RESET}` : ''}\r\n`));
    this.bus.on('answer', () => { if (!this.busy || this.asking) this.render(); });
    try { this.shell.history = JSON.parse(localStorage.getItem(historyKey) ?? '[]').slice(-HISTORY_MAX); } catch { this.shell.history = []; }
    this.win = 0;
    this.con = 0;
    this.transcript = '';       // what it showed, to show again when it opens again
    this.line = '';
    this.caret = 0;
    this.prompt = '';
    this.busy = false;          // a command runs: keys wait, Ctrl+C stops it
    this.abort = null;
    this.walk = null;           // { at, kept }: walking the history with Up/Down
    this.asking = null;         // { resolve, secret }: a question of a command
    this.search = null;         // { query, at }: Ctrl+R
    this.lastTab = 0;
    this.pending = '';          // what was written while it was closed: shown when it opens
    window.addEventListener('keydown', e => this.key(e), true);
    window.addEventListener('paste', e => this.pasteEvent(e), true);
  }

  // ------------------------------------------------------------ a tool of the page

  handles(cmd) { return cmd === this.closeCmd; }
  onCommand(cmd) { if (cmd === this.closeCmd) this.close(); }
  owns(id) { return id !== 0 && id === this.win; }
  closeWindow(id) { if (id === this.win) this.close(); }
  poll() {}

  get open() { return !!this.win && !!this.owl.place(this.win); }
  get front() { return this.open && this.owl.active() === this.win; }

  /** Ctrl+`: open; in front already, close; open but behind, to the front. */
  toggle() {
    if (this.front) this.close();
    else if (this.open) { this.owl.activate(this.win); this.owl.refresh?.(); }
    else this.show();
  }

  async show() {
    if (this.open) { this.owl.activate(this.win); return; }
    const owl = this.owl;
    const W = owl.width, H = owl.height - 2;
    const at = this.place?.(owl) ?? { x: 0, y: 1, w: W, h: Math.max(8, Math.round(H * 0.382)) };
    this.win = owl.window(this.title, at.w, at.h, { x: at.x, y: at.y, style: Style.Terminal, closeCmd: this.closeCmd });
    this.con = owl.console(this.win, { scrollback: 2000 });
    this.shell.width = at.w - 3;
    owl.windowStatus(this.win, ...(this.status ?? [
      { label: '~Tab~ Finish', cmd: 0 }, { label: '~Up~ Back', cmd: 0 }, { label: '~Ctrl-R~ Search', cmd: 0 },
      { label: '~Ctrl-C~ Stop', cmd: 0 }, { label: '~Esc~ Close', cmd: 0 }]));
    owl.activate(this.win);
    if (this.transcript) owl.consoleWrite(this.con, `${ANSI.muted}${this.transcript.replace(/\n/g, '\r\n')}${RESET}\r\n`);
    else if (this.welcome) this.write(`${this.welcome}\r\n`);
    if (this.pending) { owl.consoleWrite(this.con, this.pending); this.pending = ''; }
    if (this.busy) this.render();
    else await this.newPrompt();
  }

  close() {
    if (!this.open) { this.win = 0; return; }
    // What it showed, without the line being typed: there again next time.
    const text = this.owl.getText(this.con).split('\n');
    this.transcript = text.slice(Math.max(0, text.length - 400), -1).join('\n');
    this.owl.close(this.win);
    this.win = 0;
    this.con = 0;
    this.owl.refresh?.();
  }

  // ------------------------------------------------------------ the line

  /** Into the record - or, while closed, kept for when it opens (the windows' commands go on meanwhile). */
  write(text) {
    if (this.con) { this.owl.consoleWrite(this.con, text); this.owl.refresh?.(); return; }
    this.pending += text;
    if (this.pending.length > 200_000) this.pending = this.pending.slice(-150_000);
  }

  async newPrompt() {
    this.prompt = await this.shell.prompt();
    this.line = '';
    this.caret = 0;
    this.walk = null;
    this.render();
  }

  /** The last line again: the prompt, the line, its caret reversed. */
  render() {
    if (!this.con) return;
    if (this.search) {
      const match = this.search.at >= 0 ? this.shell.history[this.search.at] : '';
      this.write(`\r\x1b[K${ANSI.muted}(search back)'${RESET}${this.search.query}${ANSI.muted}': ${RESET}${match}`);
      return;
    }
    const shown = this.asking?.secret ? '*'.repeat(this.line.length) : this.line;
    const before = shown.slice(0, this.caret), at = shown[this.caret] ?? ' ', after = shown.slice(this.caret + 1);
    this.write(`\r\x1b[K${this.prompt}${before}\x1b[7m${at}\x1b[27m${after}`);
  }

  /** The line as it stays in the record once Enter is pressed: no caret, a secret as stars. */
  settle() {
    const shown = this.asking?.secret ? '*'.repeat(this.line.length) : this.line;
    this.write(`\r\x1b[K${this.prompt}${shown}\r\n`);
  }

  insert(text) {
    text = clean(text);
    this.line = this.line.slice(0, this.caret) + text + this.line.slice(this.caret);
    this.caret += text.length;
  }

  /** A command's question: the next line typed is its answer - hidden, for a secret. */
  ask(question, { secret = false } = {}) {
    return new Promise(resolve => {
      this.asking = { resolve, secret };
      this.prompt = `${ANSI.warn}${question}${RESET}`;
      this.line = '';
      this.caret = 0;
      this.render();
    });
  }

  // ------------------------------------------------------------ keys

  key(e) {
    // Ctrl+`, wherever the keys are: by the key's place, so ё on a Russian layout opens it too.
    if (this.hotkey && e.ctrlKey && !e.altKey && e.code === 'Backquote') { e.preventDefault(); e.stopImmediatePropagation(); this.toggle(); return; }
    if (!this.front) return;
    const handled = this.edit(e);
    // A paste: the key is let through to the browser, whose own paste event brings the text (pasteEvent).
    if (handled === 'native') { e.stopImmediatePropagation(); return; }
    if (handled) { e.preventDefault(); e.stopImmediatePropagation(); }
  }

  /**
   * Ctrl+V, Shift+Insert: the browser's own paste event brings the text -
   * it needs no permission, where navigator.clipboard.readText() is refused
   * in many places (a browser inside an app, a page not granted it) and
   * said nothing: a key could not be pasted into the site's AI chat
   * (2026-10-19). The old way stays, for a browser that sends no event.
   */
  awaitPaste() {
    this.pasted = false;
    setTimeout(() => { if (!this.pasted) navigator.clipboard?.readText?.().then(t => this.pasteText(t), () => {}); }, 200);
  }

  pasteEvent(e) {
    if (!this.front) return;
    e.preventDefault();
    e.stopImmediatePropagation();
    this.pasted = true;
    this.pasteText(e.clipboardData?.getData('text') ?? '');
  }

  /** Pasted text into the line: its first line - Enter is the person's to press. */
  pasteText(t) {
    if (this.busy && !this.asking) return;
    this.insert(String(t).split(/\r?\n/)[0]);
    this.render();
  }

  /** One key while the terminal is in front: true when it was the line's. */
  edit(e) {
    const k = e.key, ctrl = e.ctrlKey && !e.altKey;
    if (k === 'Escape' && !this.search) {
      // A question unanswered is a No; then away.
      if (this.asking) { const a = this.asking; this.asking = null; a.resolve(null); }
      this.close();
      return true;
    }
    if (ctrl && (k === 'c' || k === 'C')) { this.interrupt(); return true; }
    if (this.busy && !this.asking) return !e.altKey && !/^F\d+$/.test(k);   // a command runs: its keys wait
    if (this.search) return this.searchKey(e);
    if (k === 'Enter') { this.enter(); return true; }
    if (k === 'Tab') { this.tab(); return true; }
    if (k === 'ArrowUp' || k === 'ArrowDown') { this.history(k === 'ArrowUp' ? -1 : 1); return true; }
    if (e.shiftKey && k === 'Insert') { this.awaitPaste(); return 'native'; }
    if (ctrl) {
      switch (k.toLowerCase()) {
        case 'a': this.caret = 0; break;
        case 'e': this.caret = this.line.length; break;
        case 'u': this.line = this.line.slice(this.caret); this.caret = 0; break;
        case 'k': this.line = this.line.slice(0, this.caret); break;
        case 'w': {
          const start = this.line.slice(0, this.caret).replace(/\s+$/, '').search(/\S+$/);
          const from = start < 0 ? 0 : start;
          this.line = this.line.slice(0, from) + this.line.slice(this.caret);
          this.caret = from;
          break;
        }
        case 'l': this.write('\x1b[2J'); break;
        case 'r': if (!this.asking) { this.search = { query: '', at: -1 }; } break;
        case 'v': this.awaitPaste(); return 'native';
        default: return false;
      }
      this.render();
      return true;
    }
    if (e.altKey || e.metaKey) return false;
    switch (k) {
      case 'ArrowLeft': this.caret = Math.max(0, this.caret - 1); break;
      case 'ArrowRight': this.caret = Math.min(this.line.length, this.caret + 1); break;
      case 'Home': this.caret = 0; break;
      case 'End': this.caret = this.line.length; break;
      case 'Backspace': if (this.caret > 0) { this.line = this.line.slice(0, this.caret - 1) + this.line.slice(this.caret); this.caret--; } break;
      case 'Delete': this.line = this.line.slice(0, this.caret) + this.line.slice(this.caret + 1); break;
      default:
        if (k.length !== 1) return false;    // F-keys, PageUp/Down: the screen's and the console's own
        this.insert(k);
    }
    this.render();
    return true;
  }

  interrupt() {
    if (this.busy && !this.asking) { this.abort?.abort(); this.write(`${ANSI.muted}^C${RESET}\r\n`); return; }
    this.write(`\r\x1b[K${this.prompt}${this.asking?.secret ? '' : this.line}${ANSI.muted}^C${RESET}\r\n`);
    if (this.asking) { const a = this.asking; this.asking = null; a.resolve(null); return; }
    this.search = null;
    this.newPrompt();
  }

  /** Up/Down: back and on through what was typed; past the newest, the line that was being typed. */
  history(dir) {
    if (this.asking) return;
    const h = this.shell.history;
    if (!this.walk) { if (dir > 0) return; this.walk = { at: h.length, kept: this.line }; }
    const at = Math.max(0, Math.min(h.length, this.walk.at + dir));
    this.walk.at = at;
    this.line = at === h.length ? this.walk.kept : h[at];
    this.caret = this.line.length;
    this.render();
  }

  searchKey(e) {
    const k = e.key, s = this.search, h = this.shell.history;
    const find = (from) => { for (let i = from; i >= 0; i--) if (h[i].includes(s.query)) return i; return -1; };
    if (e.ctrlKey && k.toLowerCase() === 'r') { s.at = find((s.at < 0 ? h.length : s.at) - 1); this.render(); return true; }
    if (k === 'Enter' || k === 'Escape' || k.startsWith('Arrow')) {
      const match = s.at >= 0 ? h[s.at] : this.line;
      this.search = null;
      this.line = match;
      this.caret = match.length;
      if (k === 'Enter') { this.enter(); return true; }
      this.render();
      return true;
    }
    if (k === 'Backspace') s.query = s.query.slice(0, -1);
    else if (k.length === 1 && !e.ctrlKey && !e.altKey) s.query += k;
    else return true;
    s.at = find(h.length - 1);
    this.render();
    return true;
  }

  async enter() {
    const line = this.line;
    this.settle();
    if (this.asking) { const a = this.asking; this.asking = null; a.resolve(line); return; }
    // Kept in the history - not a line typed with a space first, not one the same as the last.
    if (line.trim() && !line.startsWith(' ') && this.shell.history.at(-1) !== line) {
      this.shell.history.push(line);
      if (this.shell.history.length > HISTORY_MAX) this.shell.history.splice(0, this.shell.history.length - HISTORY_MAX);
      this.saveHistory();
    }
    if (line.trim()) {
      this.busy = true;
      this.abort = new AbortController();
      try { await this.shell.run(line, { signal: this.abort.signal }); } catch (err) { this.write(`${ANSI.bad}${err?.message ?? err}${RESET}\r\n`); }
      this.busy = false;
      this.abort = null;
    }
    if (this.open) await this.newPrompt();
  }

  saveHistory() { try { localStorage.setItem(this.historyKey, JSON.stringify(this.shell.history)); } catch { /* a private window: this visit only */ } }

  /** Tab: the word finished as far as all it could become agree; twice, what those are. */
  async tab() {
    if (this.asking) return;
    const { start, end, candidates } = await this.shell.complete(this.line, this.caret);
    const word = this.line.slice(start, end);
    if (!candidates.length) return;
    let common = candidates[0];
    for (const c of candidates) { let i = 0; while (i < common.length && i < c.length && common[i].toLowerCase() === c[i].toLowerCase()) i++; common = common.slice(0, i); }
    if (candidates.length === 1) common = candidates[0] + (candidates[0].endsWith('/') ? '' : ' ');
    if (common.length > word.length) {
      this.line = this.line.slice(0, start) + common + this.line.slice(end);
      this.caret = start + common.length;
      this.render();
      this.lastTab = 0;
      return;
    }
    const now = performance.now();
    if (now - this.lastTab < 600 || candidates.length <= 40) {
      // What it could become, in columns; then the line again.
      const w = Math.max(...candidates.map(c => c.length)) + 2;
      const per = Math.max(1, Math.floor(this.shell.width / w));
      this.write('\r\x1b[K');
      for (let i = 0; i < candidates.length; i += per) this.write(`${ANSI.info}${candidates.slice(i, i + per).map(c => c.padEnd(w)).join('').trimEnd()}${RESET}\r\n`);
      this.render();
    }
    this.lastTab = now;
  }
}
