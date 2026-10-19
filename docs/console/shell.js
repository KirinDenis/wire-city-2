// The console's shell - THE SHARED CORE (2026-10-16): one grammar for every
// UI of the one OWLOS LAN server - this page (../shell.js adds the cafe),
// and the WIRE CITY site (wire-city-2/docs/console/ is a copy of this
// folder, by its pull-console.ps1). Nothing of a cafe here: a UI gives its
// commands and its paths, the core gives the grammar.
//
//   run(line)                  a line: words, quotes, $VARS, aliases, and
//                              `|` `&&` `;` `>` `>>`; resolves to its code
//   complete(line, caret)      Tab: what the word at the caret may become
//   register(spec)             a command (./commands.js has the core's)
//
// A command is a description: { name, group, summary, usage, where: 'here'
// | 'server', valued: [options that take a value], complete: 'path' |
// 'command' | (word, shell) => [...] | a word the paths know (paths.names),
// run(ctx) }. man, Tab and the check of options come from it. Its run(ctx)
// writes with ctx.out(text, tone) - lines that a pipe hands on as plain
// text, and the terminal colours by their tone - and ctx.err(text), which
// goes straight to the terminal in red; ctx.data(object) is what --json
// prints instead.
//
// The paths a UI gives: resolve(word) -> an absolute path; list(path) ->
// [{ name, dir, info?, tone? }]; read(path) -> text; isDir(path); write(path,
// text, { append }); complete(word) -> paths; names(how, word) -> words.
//
// Pipes are not streams: each command of a pipeline runs to its end and
// hands the next its lines. Enough for grep, sort, head and wc; tail -f
// will want more.

// The screens' tones, as ANSI: what the terminal shows a line in.
export const ANSI = {
  text: '\x1b[37m', strong: '\x1b[97m', muted: '\x1b[90m', info: '\x1b[96m',
  good: '\x1b[92m', warn: '\x1b[93m', bad: '\x1b[91m', heading: '\x1b[1;97m',
};
export const RESET = '\x1b[0m';

/** The DOS names, for people who came from DOS - on from the start, in every UI. */
export const DOS_ALIASES = [['dir', 'ls -l'], ['type', 'cat'], ['cls', 'clear'], ['ll', 'ls -l']];

/**
 * The words and operators of a line: [{ word }] and [{ op }]. Quotes and
 * escapes as bash - but a backslash before a letter or digit is kept, so a
 * DOS path is typed as DOS has it; ~ is $HOME.
 */
export function tokens(line, env = {}) {
  const out = [];
  let word = null, i = 0;
  const push = () => { if (word !== null) out.push({ word }); word = null; };
  const variable = () => {
    // $NAME, ${NAME}, $? - from the environment; nothing when unset.
    let name = '';
    if (line[i + 1] === '{') { const end = line.indexOf('}', i); name = line.slice(i + 2, end < 0 ? line.length : end); i = end < 0 ? line.length : end + 1; }
    else { let j = i + 1; while (j < line.length && /[A-Za-z0-9_?]/.test(line[j])) j++; name = line.slice(i + 1, j); i = j; }
    return name ? String(env[name] ?? '') : '$';
  };
  while (i < line.length) {
    const c = line[i];
    if (c === ' ' || c === '\t') { push(); i++; continue; }
    if (c === '|' || c === ';' || c === '&' || c === '>') {
      push();
      const two = line.slice(i, i + 2);
      if (two === '&&' || two === '>>' || two === '||') { out.push({ op: two }); i += 2; } else { out.push({ op: c }); i++; }
      continue;
    }
    if (c === "'") {
      const end = line.indexOf("'", i + 1);
      if (end < 0) throw new Error("a ' is not closed");
      word = (word ?? '') + line.slice(i + 1, end); i = end + 1; continue;
    }
    if (c === '"') {
      word = word ?? '';
      i++;
      while (i < line.length && line[i] !== '"') {
        if (line[i] === '\\' && i + 1 < line.length && '"\\$'.includes(line[i + 1])) { word += line[i + 1]; i += 2; }
        else if (line[i] === '$') word += variable();
        else word += line[i++];
      }
      if (i >= line.length) throw new Error('a " is not closed');
      i++; continue;
    }
    // A backslash before a letter, a digit, _ or . is a DOS path's (C:\GAMES\CITY.COM, the WIRE CITY site,
    // 2026-10-16) and stays; before anything else - a space, a quote, $, | - it escapes it, as bash's does.
    if (c === '\\' && i + 1 < line.length) {
      if (/[A-Za-z0-9_.]/.test(line[i + 1])) { word = (word ?? '') + '\\'; i++; continue; }
      word = (word ?? '') + line[i + 1]; i += 2; continue;
    }
    if (c === '$') { word = (word ?? '') + variable(); continue; }
    if (c === '~' && word === null && (i + 1 >= line.length || line[i + 1] === '/' || line[i + 1] === ' ')) { word = env.HOME ?? '/'; i++; continue; }
    word = (word ?? '') + c; i++;
  }
  push();
  return out;
}

/** A line cut at ; && || outside quotes: [{ text, then }] - then is what came after the part. */
export function segments(line) {
  const out = [];
  let start = 0, quote = null;
  for (let i = 0; i < line.length; i++) {
    const c = line[i];
    if (quote) { if (c === '\\' && quote === '"') i++; else if (c === quote) quote = null; continue; }
    if (c === "'" || c === '"') { quote = c; continue; }
    if (c === '\\') { i++; continue; }
    const two = line.slice(i, i + 2);
    if (c === ';' || two === '&&' || two === '||') {
      out.push({ text: line.slice(start, i), then: c === ';' ? ';' : two });
      if (c !== ';') i++;
      start = i + 1;
    }
  }
  if (quote) throw new Error(`a ${quote} is not closed`);
  out.push({ text: line.slice(start), then: null });
  return out.filter(p => p.text.trim() || p.then);
}

/** The options of a command's words: -l, -la, -n 5, --json, --days 7, --days=7; `--` ends them. */
export function options(words, valued = []) {
  const opts = {}, args = [];
  for (let i = 0; i < words.length; i++) {
    const w = words[i];
    if (w === '--') { args.push(...words.slice(i + 1)); break; }
    if (w.startsWith('--') && w.length > 2) {
      const [k, v] = w.slice(2).split('=');
      opts[k] = v ?? (valued.includes(k) ? words[++i] : true);
    } else if (w.startsWith('-') && w.length > 1 && !/^-\d/.test(w)) {
      for (let j = 1; j < w.length; j++) {
        const k = w[j];
        if (valued.includes(k)) { opts[k] = w.slice(j + 1) || words[++i]; break; }
        opts[k] = true;
      }
    } else args.push(w);
  }
  return { opts, args };
}

/** The nearest names to a mistyped one: the ones a letter or two away. */
function nearest(name, names) {
  const d = (a, b) => {
    const m = Array.from({ length: a.length + 1 }, (_, i) => [i, ...Array(b.length).fill(0)]);
    for (let j = 1; j <= b.length; j++) m[0][j] = j;
    for (let i = 1; i <= a.length; i++) for (let j = 1; j <= b.length; j++) m[i][j] = Math.min(m[i - 1][j] + 1, m[i][j - 1] + 1, m[i - 1][j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1));
    return m[a.length][b.length];
  };
  return names.map(n => [n, d(name, n)]).filter(([, k]) => k <= 2).sort((a, b) => a[1] - b[1]).slice(0, 3).map(([n]) => n);
}

export class Shell {
  /**
   * app: the page - its disks, games, DOS PC, screens; write(text): where
   * the terminal's text goes (ANSI); ask(question, { secret }): a line typed
   * in answer (the terminal's). commands: the UI's command descriptions;
   * groups: [[group, title]] in help's order; paths: shell => the UI's paths
   * (see above); home: where cd and ~ go; host: the name the prompt gives.
   */
  constructor({ app = null, write = () => {}, ask = async () => '', commands = [], groups = [], paths = null, home = '/', host = 'owlos', user = 'guest' } = {}) {
    Object.assign(this, { app, write, ask, groups, host });
    this.commands = new Map();
    for (const c of commands) this.register(c);
    this.aliases = new Map(DOS_ALIASES);
    this.builtinAliases = new Set(this.aliases.keys());
    this.env = { HOME: home, USER: user, '?': '0' };
    this.cwd = home;
    this.trace = false;           // set -x: what each command became
    this.paths = paths ? paths(this) : null;
    this.me = null;               // the nick, once asked
    this.history = [];            // the lines typed (the terminal keeps it, never a secret)
    this.width = 80;              // the terminal's columns, for ls
  }

  register(spec) { this.commands.set(spec.name, spec); }

  /**
   * A line typed: each part between ; && || in turn, as they say. A part's
   * words are made - its $VARS read - only when its turn comes, as bash does:
   * `export X=1; echo $X` says 1. Its code, as $? keeps it.
   *
   * capture: a window's command (a bus) - what it prints still goes to the
   * terminal, and is caught besides: resolves to { code, lines: [{ text,
   * tone }], data: [...], errors: [...] } instead of the code. secret: what
   * a form gave beside the line (a password), for the command alone. ask:
   * who answers the command's questions (a window: nobody - No). Anything
   * else given (a cafe, a table) goes to the commands as it is, in ctx.
   */
  async run(line, { signal = null, capture = false, secret = null, from = '', ask = null, ...given } = {}) {
    const io = { signal, secret, from, given, ask: ask ?? ((q, o) => this.ask(q, o)), caught: capture ? { lines: [], data: [], errors: [] } : null };
    const bad = text => { this.write(`${ANSI.bad}${text}${RESET}\r\n`); io.caught?.errors.push(text); };
    let parts, code = 0, skip = false;
    try { parts = segments(line); } catch (e) { bad(e.message); parts = []; code = 2; }
    for (const { text, then } of parts) {
      if (!skip) {
        try {
          const [first] = this.split(tokens(text, this.env));
          code = first ? await this.pipeline(first.pipeline, io) : 0;
        } catch (e) { bad(e.message); code = 2; }
        this.env['?'] = String(code);
        if (signal?.aborted) break;
      }
      // What comes after: && only on success, || only on failure, ; always.
      skip = (then === '&&' && code !== 0) || (then === '||' && code === 0);
    }
    return capture ? { code, ...io.caught } : code;
  }

  /** Tokens into pipelines: [{ pipeline: [{ words, to, append }], then }]. */
  split(toks) {
    const list = [];
    let pipeline = [], cmd = { words: [] };
    const endCmd = () => { if (cmd.words.length || cmd.to) pipeline.push(cmd); cmd = { words: [] }; };
    const endPipe = then => { endCmd(); if (pipeline.length) list.push({ pipeline, then }); pipeline = []; };
    for (let i = 0; i < toks.length; i++) {
      const t = toks[i];
      if (t.word !== undefined) { cmd.words.push(t.word); continue; }
      if (t.op === '|') { if (!cmd.words.length) throw new Error('nothing before |'); endCmd(); continue; }
      if (t.op === '>' || t.op === '>>') {
        const next = toks[++i];
        if (!next || next.word === undefined) throw new Error(`a file after ${t.op}`);
        cmd.to = next.word; cmd.append = t.op === '>>';
        continue;
      }
      if (t.op === '&') throw new Error('& - running in the background is not here yet');
      endPipe(t.op);
    }
    endPipe(null);
    return list;
  }

  /** One pipeline: each command's lines to the next; the last one's to the terminal, or to a file. */
  async pipeline(cmds, io) {
    const { signal, caught } = io;
    let input = null, code = 0;
    for (let n = 0; n < cmds.length; n++) {
      const last = n === cmds.length - 1;
      const { words, to, append } = cmds[n];
      if (!words.length) continue;
      const expanded = this.expand(words);
      const [name, ...rest] = expanded;
      const spec = this.commands.get(name);
      if (!spec) {
        const near = nearest(name, [...this.commands.keys(), ...this.aliases.keys()]);
        this.write(`${ANSI.bad}${name}: command not found${RESET}${near.length ? `${ANSI.muted} - did you mean ${near.join(', ')}?${RESET}` : ''}\r\n`);
        caught?.errors.push(`${name}: command not found`);
        return 127;
      }
      const { opts, args } = options(rest, spec.valued ?? []);
      const lines = [], rows = [];
      const json = !!opts.json;
      const ctx = {
        // What a window gave beside its line (OWLOS LAN: its cafe and table).
        ...io.given,
        // tty: its lines go to the terminal itself - not down a pipe, not into a file (ls prints columns then).
        name, args, opts, words: rest, stdin: input, shell: this, app: this.app, signal, json, tty: last && !to,
        // from: the window it came from ('' typed); secret: what a form gave beside the line.
        from: io.from, secret: io.secret,
        out: (text = '', tone = 'text') => { for (const l of String(text).split('\n')) lines.push({ text: l, tone }); },
        err: text => { this.write(`${ANSI.bad}${name}: ${text}${RESET}\r\n`); caught?.errors.push(text); },
        data: obj => rows.push(obj),
        ask: (q, o) => io.ask(q, o),
      };
      try {
        code = (await spec.run(ctx)) ?? 0;
      } catch (e) {
        ctx.err(String(e?.message ?? e));
        code = 1;
      }
      const result = json ? JSON.stringify(rows.length === 1 ? rows[0] : rows, null, 1).split('\n').map(text => ({ text, tone: 'text' })) : lines;
      // Caught lines are what the terminal shows - the JSON itself for --json (a model reads only lines).
      if (last && caught) { caught.lines.push(...(to ? lines : result)); caught.data.push(...rows); }
      if (to) {
        try { await this.paths.write(this.paths.resolve(to), result.map(l => l.text).join('\n') + '\n', { append }); }
        catch (e) { ctx.err(String(e?.message ?? e)); return 1; }
        input = null;
      } else if (last) {
        for (const l of result) this.write(`${ANSI[l.tone] ?? ''}${l.text}${RESET}\r\n`);
      } else input = result.map(l => l.text);
      if (signal?.aborted) return 130;
    }
    return code;
  }

  /** Aliases: the first word, once each (an alias of itself stops there). */
  expand(words) {
    const seen = new Set();
    let out = words;
    while (this.aliases.has(out[0]) && !seen.has(out[0])) {
      seen.add(out[0]);
      out = [...tokens(this.aliases.get(out[0]), this.env).filter(t => t.word !== undefined).map(t => t.word), ...out.slice(1)];
    }
    return out;
  }

  /** set -x: what a command became - an API call, or a step in this page. */
  traced(text) { if (this.trace) this.write(`${ANSI.muted}  ${text}${RESET}\r\n`); }

  /** A call to the server - the one OWLOS LAN server every UI talks to - traced, and its refusal in words. */
  async api(method, path, body) {
    const t0 = performance.now();
    const r = await fetch(path, {
      method, credentials: 'same-origin',
      headers: body ? { 'Content-Type': 'application/json' } : {},
      body: body ? JSON.stringify(body) : undefined,
    });
    let json = null;
    try { json = r.status === 204 ? null : await r.json(); } catch { /* no body */ }
    const shown = body ? ` ${JSON.stringify(body).replace(/"password":"[^"]*"/g, '"password":"********"')}` : '';
    this.traced(`${method} ${path}${shown} -> ${r.status}, ${Math.round(performance.now() - t0)} ms`);
    if (!r.ok) throw Object.assign(new Error(json?.error ?? `the server said ${r.status} ${r.statusText}`), { status: r.status });
    return json;
  }

  /** Who I am: the nick of this page's session, or null when not logged in (or no server answers). */
  async whoami() {
    if (this.me) return this.me;
    try { this.me = (await this.api('GET', '/api/me?soft=1')).nick; } catch { this.me = null; }
    this.env.USER = this.me ?? 'guest';
    return this.me;
  }

  /** The path as the prompt shows it: ~ for home. */
  shownPath() {
    const home = this.env.HOME;
    return this.cwd === home ? '~' : home !== '/' && this.cwd.startsWith(`${home}/`) ? `~${this.cwd.slice(home.length)}` : this.cwd;
  }

  /** The prompt: who@host:path$ - in colour. A UI may say more (OWLOS LAN: the cafe). */
  async prompt() {
    return `${ANSI.good}${this.env.USER}@${this.host}${RESET}:${ANSI.info}${this.shownPath()}${RESET}$ `;
  }

  /**
   * Tab: the word at the caret and what it may become -
   * { start, end, candidates }: a command for the first word, else what the
   * command says (a path when it says nothing).
   */
  async complete(line, caret) {
    const before = line.slice(0, caret);
    const start = Math.max(before.lastIndexOf(' '), before.lastIndexOf('|'), before.lastIndexOf(';')) + 1;
    const word = before.slice(start);
    const head = before.slice(0, start).split(/[|;&]/).pop().trim();
    let candidates;
    if (!head) candidates = [...this.commands.keys(), ...this.aliases.keys()].filter(n => n.startsWith(word)).sort();
    else {
      const name = this.expand(head.split(/\s+/))[0];
      const how = this.commands.get(name)?.complete ?? 'path';
      if (typeof how === 'function') candidates = (await how(word, this)).filter(c => c.startsWith(word));
      else if (how === 'command') candidates = [...this.commands.keys()].filter(n => n.startsWith(word)).sort();
      else if (how === 'path') candidates = await this.paths.complete(word);
      else candidates = await this.paths.names(how, word);
    }
    return { start, end: caret, candidates: [...new Set(candidates)] };
  }
}
