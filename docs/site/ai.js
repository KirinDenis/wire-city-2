// The AI section of the site (the pilot, 2026-10-19: "a section of its own
// for AI - connected agents, tasks, console, chat"). Four windows over the
// same hands (agent.js):
//
//   AI > Chat      this page's own chat: the person's Anthropic API key,
//                  kept in this browser only, the model called from here -
//                  it writes, builds, runs, looks and plays in this page
//                  while the person watches. The site's terminal with a
//                  model for its shell (../console/terminal.js): the line,
//                  its history, Ctrl+C to stop.
//   AI > Agents    who works here: the chat, and each token a person's own
//                  Claude (Claude Code, MCP) holds - a new one, its line on
//                  the clipboard, taken back.
//   AI > Tasks     what they work on: each chat request, and what an MCP
//                  model says with its `task` tool - its state, its cost.
//   AI > Console   every call any of them made, as it happens.
//
// Nothing here costs the site: a model is paid for by the key it runs on.

import { Style } from '../owlosui/owlosui.js';
import { Terminal } from '../console/terminal.js';
import { ANSI, RESET } from '../console/shell.js';
import { TableWindow } from './tablewin.js';
import { INSTRUCTIONS, TOOL_DEFS } from './agent.js';

const KEY = 'site.ai.key';
const SETTINGS = 'site.ai.1';
const CHAT_CLOSE = 962, CONSOLE_CLOSE = 963;
const AGENTS_BASE = 900, Ag = { New: 907, Copy: 908, Revoke: 909, Chat: 910, Key: 911 };
const TASKS_BASE = 920, Tk = { Stop: 927, Clear: 928 };
const TURNS = 40;

/**
 * Dollars a million tokens - input, output - to estimate what a task costs.
 * An estimate only: the person's Anthropic Console has the bill.
 */
const PRICES = { 'claude-sonnet-5-5': [3, 15], 'claude-haiku-5-5': [1, 5], 'claude-opus-5-5': [5, 25] };

const ago = t => { const s = Math.round((Date.now() - t) / 1000); return s < 60 ? `${s} s ago` : s < 3600 ? `${Math.round(s / 60)} min ago` : `${Math.round(s / 3600)} h ago`; };
const clock = t => new Date(t).toTimeString().slice(0, 8);
const brief = (s, n = 100) => { s = String(s ?? '').replace(/\s+/g, ' ').trim(); return s.length > n ? `${s.slice(0, n - 3)}...` : s; };
const crlf = s => String(s).replace(/\r?\n/g, '\r\n');

/** The chat's "shell", as the terminal wants one: its lines go to the model. */
class ChatShell {
  constructor(chat, { write, ask }) {
    Object.assign(this, { chat, write, ask });
    this.history = [];
    this.width = 80;
    this.env = {};
  }
  async prompt() { return `${ANSI.good}you${RESET}> `; }
  async complete(line) {
    const words = ['/key', '/forget', '/model', '/budget', '/new', '/help'];
    return { start: 0, end: line.length, candidates: line.startsWith('/') ? words.filter(w => w.startsWith(line)) : [] };
  }
  run(line, { signal } = {}) { return this.chat.say(line, signal); }
}

export class AiChat {
  constructor(app) {
    this.app = app;
    this.messages = [];               // the conversation, for the next question to follow on
    this.task = null;                 // the task the model works on now
    try { this.settings = { model: 'claude-sonnet-5-5', budget: 0.5, api: 'https://api.anthropic.com', ...JSON.parse(localStorage.getItem(SETTINGS) ?? '{}') }; } catch { this.settings = { model: 'claude-sonnet-5-5', budget: 0.5, api: 'https://api.anthropic.com' }; }
    this.term = new Terminal(app.owl, {
      makeShell: io => (this.shell = new ChatShell(this, io)),
      title: 'AI - chat', historyKey: 'site.ai.history', hotkey: false, closeCmd: CHAT_CLOSE,
      welcome: `${ANSI.heading}A model works in this page${RESET}: it writes, builds, runs and looks while you watch - every call is in AI > Console.\r\n` +
        `${ANSI.muted}Your own Anthropic API key pays for it: /key sets it (kept in this browser only). /help says the rest.${RESET}`,
      place: owl => {
        const W = owl.width, H = owl.height, w = Math.min(W, Math.max(50, Math.round(W * 0.45)));
        return { x: W - w, y: 1, w, h: H - 2 };
      },
      status: [{ label: '~Enter~ Send', cmd: 0 }, { label: '~Up~ Back', cmd: 0 }, { label: '~Ctrl-C~ Stop', cmd: 0 }, { label: '~Esc~ Close', cmd: 0 }],
    });
  }

  get key() { try { return localStorage.getItem(KEY) ?? ''; } catch { return ''; } }
  saveSettings() { try { localStorage.setItem(SETTINGS, JSON.stringify(this.settings)); } catch { /* this visit only */ } }
  get working() { return this.term.busy; }

  show() { return this.term.show(); }
  /** Stop what the model does - Ctrl+C's, from AI > Tasks. */
  stop() { if (this.term.busy) this.term.interrupt(); }

  out(text) { this.shell.write(crlf(text)); }

  /** A line typed: a /command of the chat's own, or words for the model. */
  async say(line, signal) {
    const [cmd, ...rest] = line.trim().split(/\s+/);
    if (cmd.startsWith('/')) return this.command(cmd.toLowerCase(), rest.join(' '));
    if (!this.key) { this.out(`${ANSI.warn}No key yet: /key sets your Anthropic API key (Console > API keys) - it stays in this browser.${RESET}\n`); return 1; }
    return this.work(line.trim(), signal);
  }

  async command(cmd, arg) {
    switch (cmd) {
      case '/key': {
        const k = (await this.shell.ask('your API key (sk-ant-...): ', { secret: true }))?.trim();
        if (!k) { this.out(`${ANSI.muted}no key given - nothing changed${RESET}\n`); return 1; }
        if (!/^sk-ant-[\w-]{20,}$/.test(k)) { this.out(`${ANSI.bad}that does not look like an Anthropic key (sk-ant-...)${RESET}\n`); return 1; }
        try { localStorage.setItem(KEY, k); } catch { this.out(`${ANSI.bad}this browser would not keep it${RESET}\n`); return 1; }
        this.out(`${ANSI.good}the key is kept in this browser; /forget takes it out${RESET}\n`);
        this.app.agent.tell('tokens');
        return 0;
      }
      case '/forget':
        try { localStorage.removeItem(KEY); } catch { /* none */ }
        this.out(`${ANSI.muted}the key is gone from this browser${RESET}\n`);
        this.app.agent.tell('tokens');
        return 0;
      case '/model':
        if (arg && !PRICES[arg]) { this.out(`${ANSI.bad}${arg}: one of ${Object.keys(PRICES).join(', ')}${RESET}\n`); return 1; }
        if (arg) { this.settings.model = arg; this.saveSettings(); }
        this.out(`the model: ${this.settings.model}   (${Object.keys(PRICES).join(', ')})\n`);
        return 0;
      case '/budget': {
        if (arg) {
          const n = Number(arg);
          if (!(n > 0 && n <= 20)) { this.out(`${ANSI.bad}a budget a task in dollars, 0.05 to 20${RESET}\n`); return 1; }
          this.settings.budget = n;
          this.saveSettings();
        }
        this.out(`a task stops at about $${this.settings.budget.toFixed(2)} (an estimate - your Console has the bill)\n`);
        return 0;
      }
      case '/new':
        this.messages = [];
        this.out(`${ANSI.muted}a new conversation: the model remembers nothing of the last one${RESET}\n`);
        return 0;
      case '/help':
        this.out([
          'Say what you want, in any language: "make a small game where stars fall and a paddle catches them".',
          'The model works in THIS page: its commands show in the terminal (# chat), each call in AI > Console,',
          'the task in AI > Tasks. Anything that would delete or replace your files asks you first.',
          '  /key      your Anthropic API key, kept in this browser only     /forget  take it out',
          `  /model    which model (${this.settings.model})     /budget  where a task stops ($${this.settings.budget.toFixed(2)})`,
          '  /new      a new conversation     Ctrl+C  stop the model     Esc  close (it keeps working)', ''].join('\n'));
        return 0;
      default:
        this.out(`${ANSI.bad}${cmd}: /key, /forget, /model, /budget, /new, /help${RESET}\n`);
        return 1;
    }
  }

  /** One request to the Messages API, from this browser. */
  async post(body, signal) {
    let r;
    try {
      r = await fetch(`${this.settings.api}/v1/messages`, {
        method: 'POST', signal,
        headers: {
          'content-type': 'application/json', 'x-api-key': this.key, 'anthropic-version': '2023-06-01',
          // The key is the person's own, typed into their own browser: calling from the page is the point.
          'anthropic-dangerous-direct-browser-access': 'true',
        },
        body: JSON.stringify(body),
      });
    } catch (e) {
      if (signal?.aborted) throw e;
      throw new Error(`no answer from ${this.settings.api} - offline, or something in this browser blocks it`);
    }
    const j = await r.json().catch(() => null);
    if (r.ok) return j;
    const said = j?.error?.message ?? r.statusText;
    if (r.status === 401) throw new Error(`the key was refused (401): /key sets it again`);
    if (r.status === 429) throw new Error(`too many requests (429): wait a little - ${said}`);
    if (r.status >= 500) throw new Error(`Anthropic is busy (${r.status}): again in a moment`);
    throw new Error(`${r.status}: ${said}`);
  }

  /** The model at work on one request: its turns, its calls, until it says it is done. */
  async work(text, signal) {
    const agent = this.app.agent, model = this.settings.model, [pin, pout] = PRICES[model] ?? PRICES['claude-sonnet-5-5'];
    const task = this.task = agent.taskSay('Chat', text, 'working', '', { cost: 0, turns: 0 });
    this.messages.push({ role: 'user', content: text });
    let spent = 0;
    const end = (state, note) => { agent.taskSay('Chat', task.title, state, note, { cost: spent }); this.task = null; };
    try {
      for (let turn = 1; turn <= TURNS; turn++) {
        if (signal?.aborted) { end('stopped', 'stopped by Ctrl+C'); return 1; }
        const sent = structuredClone(this.messages);
        keepLastScreens(sent, 2);
        markCache(sent);
        const r = await this.post({
          model, max_tokens: 16000,
          system: [{ type: 'text', text: INSTRUCTIONS, cache_control: { type: 'ephemeral' } }],
          tools: TOOL_DEFS, messages: sent,
        }, signal);
        const u = r.usage ?? {};
        spent += ((u.input_tokens ?? 0) * pin + (u.cache_creation_input_tokens ?? 0) * pin * 1.25 + (u.cache_read_input_tokens ?? 0) * pin * 0.1 + (u.output_tokens ?? 0) * pout) / 1e6;
        agent.taskSay('Chat', task.title, 'working', '', { cost: spent, turns: turn });
        this.messages.push({ role: 'assistant', content: r.content });
        const cut = r.stop_reason === 'max_tokens';
        const results = [];
        for (const b of r.content) {
          if (b.type === 'text' && b.text.trim()) this.out(`${ANSI.info}model${RESET}> ${b.text.trim()}\n`);
          if (b.type !== 'tool_use') continue;
          if (cut) { results.push({ type: 'tool_result', tool_use_id: b.id, is_error: true, content: 'Your reply was cut at the token limit, so this call was not made. Write big files in parts, or shorter.' }); continue; }
          results.push(await this.call(b, task));
          if (signal?.aborted) break;
        }
        if (signal?.aborted) {
          // Every call asked for needs its answer, or the conversation cannot go on.
          for (const b of r.content) if (b.type === 'tool_use' && !results.some(x => x.tool_use_id === b.id)) results.push({ type: 'tool_result', tool_use_id: b.id, is_error: true, content: 'stopped by the person' });
          this.messages.push({ role: 'user', content: results });
          end('stopped', 'stopped by Ctrl+C');
          return 1;
        }
        if (!results.length && !cut) {
          this.out(`${ANSI.muted}(done: ${turn} turn${turn > 1 ? 's' : ''}, about $${spent.toFixed(2)})${RESET}\n`);
          end('done', r.content.filter(b => b.type === 'text').map(b => b.text).join(' '));
          return 0;
        }
        this.messages.push({ role: 'user', content: results.length ? results : '(Your reply was cut at the token limit - go on.)' });
        if (spent >= this.settings.budget) {
          this.out(`${ANSI.warn}stopped at about $${spent.toFixed(2)}: the budget a task is $${this.settings.budget.toFixed(2)} - /budget raises it; say "go on" to continue${RESET}\n`);
          end('over budget', `stopped at about $${spent.toFixed(2)}`);
          return 1;
        }
      }
      this.out(`${ANSI.warn}stopped after ${TURNS} turns - say "go on" to continue${RESET}\n`);
      end('stopped', `${TURNS} turns`);
      return 1;
    } catch (e) {
      if (signal?.aborted) {
        // Stopped while the model was answering: its question stays without a reply - drop it.
        if (this.messages.at(-1)?.role === 'user' && typeof this.messages.at(-1).content === 'string') this.messages.pop();
        end('stopped', 'stopped by Ctrl+C');
        return 1;
      }
      if (this.messages.at(-1)?.role === 'user' && typeof this.messages.at(-1).content === 'string') this.messages.pop();
      this.out(`${ANSI.bad}${e.message}${RESET}\n`);
      end('failed', e.message);
      return 1;
    }
  }

  /** One tool the model asked for, run by this page's hands - and its answer, as the API takes it. */
  async call(b, task) {
    const args = b.input ?? {};
    const what = b.name === 'console' ? args.line : b.name === 'keys' ? args.keys : b.name === 'task' ? `${args.title}: ${args.state}` : args.path ?? '';
    this.out(`${ANSI.muted}  > ${b.name}${what ? ` ${brief(what, 90)}` : ''}${RESET}\n`);
    // In the chat the task is the request itself: the model's own word about it is its news.
    if (b.name === 'task') {
      this.app.agent.taskSay('Chat', task.title, 'working', args.note || args.state);
      return { type: 'tool_result', tool_use_id: b.id, content: 'noted in AI > Tasks' };
    }
    const r = await this.app.agent.run(b.name, args, 'Chat');
    const content = r.content.map(c => (c.type === 'image'
      ? { type: 'image', source: { type: 'base64', media_type: c.mimeType, data: c.data } }
      : { type: 'text', text: c.text }));
    const said = r.content.filter(c => c.type === 'text').map(c => c.text).join(' ');
    this.out(`${r.isError ? ANSI.bad : ANSI.muted}    ${r.content.some(c => c.type === 'image') ? '[a picture] ' : ''}${brief(said, 110)}${RESET}\n`);
    return { type: 'tool_result', tool_use_id: b.id, content, ...(r.isError ? { is_error: true } : {}) };
  }
}

/** The conversation's end marked for the prompt cache: next turn it is read back at a tenth of the price. */
function markCache(messages) {
  const last = messages.at(-1);
  if (!last) return;
  if (typeof last.content === 'string') last.content = [{ type: 'text', text: last.content }];
  const end = last.content.at(-1);
  if (end) end.cache_control = { type: 'ephemeral' };
}

/** Older pictures out of what is sent: a line in their place - fifty looks would be fifty pictures paid for on every turn. */
function keepLastScreens(messages, keep) {
  const found = [];
  for (const m of messages) {
    if (!Array.isArray(m.content)) continue;
    for (const b of m.content) {
      if (b.type !== 'tool_result' || !Array.isArray(b.content)) continue;
      b.content.forEach((c, i) => { if (c.type === 'image') found.push([b.content, i]); });
    }
  }
  for (const [list, i] of found.slice(0, Math.max(0, found.length - keep))) list[i] = { type: 'text', text: '(an earlier screen, dropped to save room)' };
}

/**
 * The AI section: its menu's four windows, kept up to date from the hands'
 * news (agent.js on('event' | 'task' | 'tokens')).
 */
export class AiSection {
  constructor(app) {
    this.app = app;
    this.owl = app.owl;
    this.agent = app.agent;
    this.chat = new AiChat(app);
    this.agents = this.makeAgents();
    this.tasks = this.makeTasks();
    this.con = { win: 0, view: 0 };
    this.agent.on((kind, data) => this.news(kind, data));
    setInterval(() => { if (this.agents.isOpen) this.agents.refreshRows(); }, 5000);   // "2 min ago" moves on
  }

  /** Something happened: whichever window shows it, again. */
  news(kind, data) {
    for (const t of [this.agents, this.tasks]) {
      if (!t.isOpen) continue;
      if (t.rows().length !== t.table?.rows.length) t.again(); else { t.refreshRows(); t.place(); }
    }
    if (kind === 'event' && this.con.view && this.owl.place(this.con.win)) this.owl.consoleWrite(this.con.view, eventText(data));
  }

  // ------------------------------------------------------------ AI > Agents

  /** The rows of AI > Agents: this page's chat, then each token a person's own Claude holds. */
  agentRows() {
    const a = this.agent, rows = [];
    const last = who => a.events.findLast(e => e.who === who);
    const calls = who => a.events.filter(e => e.who === who).length;
    const chatLast = last('Chat');
    rows.push({ kind: 'chat', cells: ['Chat (this page)', this.chat.working ? 'working' : this.chat.key ? 'ready' : 'no key', String(calls('Chat')),
      chatLast ? `${chatLast.tool} ${chatLast.what} - ${ago(chatLast.at)}` : this.chat.key ? this.chat.settings.model : 'AI > Chat, then /key', ''] });
    a.held.forEach((t, i) => {
      const who = `Claude #${i + 1}`, e = last(who);
      const line = a.state === 'on' && a.claimed ? (e && Date.now() - e.at < 20000 ? 'working' : e ? 'connected' : 'waiting') : a.state === 'connecting' ? 'connecting' : 'no server';
      const until = new Date(t.until);
      rows.push({ kind: 'token', index: i, cells: [who, line, String(calls(who)), e ? `${e.tool} ${e.what} - ${ago(e.at)}` : 'no call yet',
        `${until.toLocaleDateString(undefined, { day: 'numeric', month: 'short' })} ${clock(t.until).slice(0, 5)}`] });
    });
    return rows;
  }

  makeAgents() {
    return new TableWindow(this.app, {
      title: 'AI - agents', base: AGENTS_BASE, min: { w: 64, h: 20 },
      columns: [
        { head: 'Who', width: 18, colour: 15 },
        { head: 'State', width: 12, colour: 11 },
        { head: 'Calls', width: 7, colour: 14 },
        { head: 'Last', width: 0, colour: 7 },
        { head: 'Ends', width: 12, colour: 10, drop: 1 },
      ],
      rows: () => this.agentRows().map(r => r.cells),
      buttons: i => {
        const r = this.agentRows()[i];
        return [
          { key: 'chat', label: '~O~pen chat', cmd: Ag.Chat, shown: r?.kind === 'chat', default: true },
          { key: 'key', label: '~K~ey...', cmd: Ag.Key, shown: r?.kind === 'chat' },
          { key: 'copy', label: '~C~opy line', cmd: Ag.Copy, shown: r?.kind === 'token', default: true },
          { key: 'revoke', label: '~R~evoke', cmd: Ag.Revoke, shown: r?.kind === 'token' },
          { key: 'new', label: '~N~ew token', cmd: Ag.New, shown: true },
        ];
      },
      words: i => {
        const r = this.agentRows()[i];
        if (r?.kind === 'token') {
          return [`A token for your own Claude - Claude Code, through MCP. It works while this page is open, until ${new Date(this.agent.held[r.index].until).toLocaleString()}.`,
            'Copy line puts the command that connects Claude Code on the clipboard: run it in a terminal, start Claude Code, and ask it for what you want - it works here, in this page. Revoke takes the token back at once.'];
        }
        return ["This page's own chat: your Anthropic API key, kept in this browser only - the model is called from here and works with the same hands, while you watch.",
          'New token: the same for your own Claude Code, through MCP - no key of yours on this page at all.'];
      },
      open: i => this.agentDo(this.agentRows()[i]?.kind === 'token' ? Ag.Copy : Ag.Chat),
    });
  }

  /** AI > New token: one for Claude Code, its line on the clipboard - and AI > Agents open on it. */
  async newToken() {
    if (!this.agents.isOpen) this.agents.show();
    await this.agentDo(Ag.New);
  }

  /** AI > Agents's buttons. */
  async agentDo(cmd) {
    const r = this.agentRows()[this.agents.current];
    switch (cmd) {
      case Ag.Chat: this.chat.show(); break;
      case Ag.Key: await this.chat.show(); this.chat.term.line = '/key'; this.chat.term.enter(); break;
      case Ag.New: {
        const token = await this.agent.make(1);
        this.agents.again();
        this.agents.select(this.agent.held.length);
        await this.copy(this.agent.addLine(token), 'A token for Claude Code, for a day.');
        break;
      }
      case Ag.Copy: if (r?.kind === 'token') await this.copy(this.agent.addLine(this.agent.held[r.index].token), `The line for Claude #${r.index + 1}.`); break;
      case Ag.Revoke: if (r?.kind === 'token') { await this.agent.revoke(r.index + 1); this.agents.again(); } break;
    }
    this.owl.refresh?.();
  }

  /** A line onto the clipboard - and in a box, for when the browser would not. */
  async copy(text, what) {
    let copied = false;
    try { await navigator.clipboard.writeText(text); copied = true; } catch { /* no clipboard from here */ }
    this.app.tell('AI', `${what} ${copied ? 'The line is on the clipboard' : 'Copy the line'} - run it in a terminal, then start Claude Code:\n\n${text}\n\nWhoever has it acts in this page as you while it is open; Revoke takes it back.`);
  }

  // ------------------------------------------------------------ AI > Tasks

  makeTasks() {
    const list = () => this.agent.tasks;
    return new TableWindow(this.app, {
      title: 'AI - tasks', base: TASKS_BASE, min: { w: 64, h: 18 },
      columns: [
        { head: 'Task', width: 0, colour: 15 },
        { head: 'Who', width: 11, colour: 11 },
        { head: 'State', width: 12, colour: 14 },
        { head: 'Cost', width: 8, colour: 10, drop: 2 },
        { head: 'Started', width: 10, colour: 7, drop: 1 },
      ],
      rows: () => (list().length ? list().map(t => [t.title, t.who, t.state, t.cost ? `$${t.cost.toFixed(2)}` : '', clock(t.started)])
        : [['nothing yet - AI > Chat, or your own Claude', '', '', '', '']]),
      buttons: i => {
        const t = list()[i];
        return [
          { key: 'stop', label: '~S~top', cmd: Tk.Stop, shown: t?.who === 'Chat' && t.state === 'working', default: true },
          { key: 'clear', label: 'C~l~ear finished', cmd: Tk.Clear, shown: list().some(x => x.state !== 'working') },
        ];
      },
      words: i => {
        const t = list()[i];
        if (!t) return ['What the models work on: each request to the chat, and what your own Claude says it does.'];
        return [t.note || '(no news yet)', `${t.turns ? `${t.turns} turns, ` : ''}${t.cost ? `about $${t.cost.toFixed(2)} (an estimate), ` : ''}last news ${ago(t.updated ?? t.started)}.`];
      },
    });
  }

  // ------------------------------------------------------------ AI > Console

  showConsole() {
    const owl = this.owl;
    if (this.con.win && owl.place(this.con.win)) { owl.activate(this.con.win); return; }
    const W = owl.width, H = owl.height, w = Math.min(W, Math.max(60, Math.round(W * 0.618))), h = Math.max(10, Math.round((H - 2) * 0.5));
    this.con.win = owl.window('AI - console: every call', w, h, { x: Math.floor((W - w) / 2), y: H - 1 - h, style: Style.Document, closeCmd: CONSOLE_CLOSE });
    this.con.view = owl.console(this.con.win, { scrollback: 1000 });
    owl.windowStatus(this.con.win, { label: '~End~ Newest', cmd: 0 }, { label: '~Alt-F3~ Close', cmd: 0 });
    const ev = this.agent.events;
    owl.consoleWrite(this.con.view, ev.length ? ev.map(eventText).join('') : `${ANSI.muted}No call yet: every tool a model calls here - the chat's or your own Claude's - shows up here as it happens.${RESET}\r\n`);
    owl.activate(this.con.win);
    owl.refresh?.();
  }

  // ------------------------------------------------------------ the page's tool

  handles(cmd) {
    return cmd === CONSOLE_CLOSE || Object.values(Ag).includes(cmd) || Object.values(Tk).includes(cmd)
      || this.chat.term.handles(cmd) || this.agents.handles(cmd) || this.tasks.handles(cmd);
  }

  onCommand(cmd) {
    if (this.chat.term.handles(cmd)) return this.chat.term.onCommand(cmd);
    if (this.agents.handles(cmd)) return this.agents.onCommand(cmd);
    if (this.tasks.handles(cmd)) return this.tasks.onCommand(cmd);
    if (Object.values(Ag).includes(cmd)) return this.agentDo(cmd);
    if (cmd === Tk.Stop) { this.chat.stop(); return; }
    if (cmd === Tk.Clear) { this.agent.clearTasks(); this.tasks.again(); return; }
    if (cmd === CONSOLE_CLOSE && this.con.win) { if (this.owl.place(this.con.win)) this.owl.close(this.con.win); this.con = { win: 0, view: 0 }; }
  }

  owns(id) { return id !== 0 && (this.chat.term.owns(id) || id === this.con.win); }
  closeWindow(id) { if (this.chat.term.owns(id)) this.chat.term.close(); else if (id === this.con.win) this.onCommand(CONSOLE_CLOSE); }
  poll() { this.agents.poll(); this.tasks.poll(); }
}

/** A call, for AI > Console: when, who, what - and under it what came back. */
function eventText(e) {
  return `${ANSI.muted}${clock(e.at)}${RESET} ${ANSI.info}${e.who.padEnd(10)}${RESET} ${e.tool.padEnd(10)} ${e.what}\r\n` +
    `${' '.repeat(9)}${e.ok ? ANSI.muted : ANSI.bad}${e.ok ? '' : 'x '}${e.said} (${e.ms} ms)${RESET}\r\n`;
}
