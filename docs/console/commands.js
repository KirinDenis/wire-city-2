// The console's own commands - THE SHARED CORE (2026-10-16), the ones every
// UI of the OWLOS LAN server has: the shell's, files and paths, text in
// pipes. A UI adds its own (OWLOS LAN: ../commands.js - disks, people, a
// cafe, tables; the WIRE CITY site: its drives, games, lessons). Linux names
// wherever Linux has the word. Never rename one, never change what one
// means: a profile is a list of commands, and old ones must still run.

/** The core's groups, in help's order; a UI puts its own after them. */
export const CORE_GROUPS = [['shell', 'The shell'], ['files', 'Files and paths'], ['text', 'Text, in pipes']];

/**
 * THE COMMAND CONTRACT (2026-10-19; references/console.md says it whole).
 * Every UI's buttons and every model run commands, so each command says
 * what it does - its `effect` - and what it gives as data (`data`: the
 * shape of its --json); `effects` names an option that changes the effect
 * (rm is deletes; history -c is too), `bare` the effect with no words
 * after the name (alias alone only lists), `model: 'never'` a command a model
 * may not run at all. `help --json` is the whole list - the API a UI or a
 * model builds on.
 *
 *   reads    only looks: nothing changes anywhere
 *   shows    changes what this page shows or where the terminal is; nothing kept
 *   runs     starts something on the machine (what ran before is gone)
 *   writes   makes new files or new things
 *   deletes  takes away, or writes over, what was there
 *   setup    changes the person's setup: drives, settings, names, variables
 *   shares   gives something to others, or sends it out of this page
 */
export const EFFECTS = ['reads', 'shows', 'runs', 'writes', 'deletes', 'setup', 'shares'];
/** What a model - or a UI somebody else described - runs only after the person's Yes. */
export const ASK_EFFECTS = ['deletes', 'setup', 'shares'];

/**
 * A command's effect for the options and words it was given: an option of
 * `effects` that is there wins, then `bare` when no word follows; a
 * command that declares none counts as setup - not knowing what it does is
 * a reason to ask.
 */
export function effectOf(spec, opts = {}, args = []) {
  for (const [o, e] of Object.entries(spec?.effects ?? {})) if (opts[o] !== undefined) return e;
  if (!args.length && spec?.bare) return spec.bare;
  return spec?.effect ?? 'setup';
}

/** A command's contract as data: what help --json and man --json give. */
export function contractOf(c) {
  return {
    name: c.name, group: c.group, summary: c.summary, usage: c.usage, where: c.where ?? 'here',
    options: c.options ?? {}, valued: c.valued ?? [], effect: c.effect ?? null, effects: c.effects ?? {},
    bare: c.bare ?? null, data: c.data ?? null, model: c.model ?? 'yes',
  };
}

/** The lines a text command works on: what came down the pipe, else the files named. */
export async function inputLines(ctx, files) {
  if (!files.length) return ctx.stdin ?? [];
  const out = [];
  for (const f of files) out.push(...(await ctx.shell.paths.read(ctx.shell.paths.resolve(f))).split('\n'));
  return out;
}

/** Names in columns, as ls prints them to a terminal; one a line into a pipe. */
export function columns(ctx, entries) {
  if (!ctx.tty) { for (const e of entries) ctx.out(e.name + (e.dir ? '/' : '')); return; }
  const w = Math.max(1, ...entries.map(e => e.name.length + (e.dir ? 1 : 0))) + 2;
  const per = Math.max(1, Math.floor((ctx.shell.width ?? 80) / w));
  for (let i = 0; i < entries.length; i += per) {
    // One line of several tones cannot be one out(): the terminal colours a line by one tone.
    ctx.out(entries.slice(i, i + per).map(e => (e.name + (e.dir ? '/' : '')).padEnd(w)).join('').trimEnd(), entries[i].dir ? 'info' : 'text');
  }
}

/** A typed answer that says yes: y, yes, д, да. */
export const yes = a => /^(y|yes|д|да)$/i.test((a ?? '').trim());

export const CORE_COMMANDS = [
  // ------------------------------------------------------------ the shell
  {
    name: 'help', group: 'shell', summary: 'the commands, by what they are for; --json: every command\'s contract, the API a UI is built on', usage: 'help [--json]', where: 'here', complete: 'command',
    effect: 'reads', data: '[{ name, group, summary, usage, where, options, valued, effect, effects, bare, data, model }]',
    run(ctx) {
      for (const [g, title] of ctx.shell.groups) {
        const list = [...ctx.shell.commands.values()].filter(c => c.group === g);
        if (!list.length) continue;
        ctx.out(title, 'heading');
        for (const c of list) { ctx.out(`  ${c.name.padEnd(9)} ${c.summary}`); ctx.data(contractOf(c)); }
      }
      // A command in a group nobody listed is still in the contract.
      const grouped = new Set(ctx.shell.groups.map(([g]) => g));
      for (const c of ctx.shell.commands.values()) if (!grouped.has(c.group)) ctx.data(contractOf(c));
      ctx.out('man NAME says more of one. Tab finishes a word; Up and Down bring back what you typed.', 'muted');
    },
  },
  {
    name: 'man', group: 'shell', summary: 'what a command does, its options, where it runs, its effect and its data', usage: 'man NAME [--json]', where: 'here', complete: 'command',
    effect: 'reads', data: '{ name, group, summary, usage, where, options, valued, effect, effects, bare, data, model }',
    run(ctx) {
      const name = ctx.args[0];
      if (!name) { ctx.err('which command? man NAME'); return 1; }
      const c = ctx.shell.commands.get(name) ?? ctx.shell.commands.get(ctx.shell.expand([name])[0]);
      if (!c) { ctx.err(`${name}: no such command`); return 1; }
      ctx.data(contractOf(c));
      ctx.out(`${c.name} - ${c.summary}`, 'heading');
      ctx.out(`usage: ${c.usage}`);
      for (const [o, what] of Object.entries(c.options ?? {})) ctx.out(`  ${o.length === 1 ? '-' : '--'}${o.padEnd(10)} ${what}`);
      ctx.out(`runs ${c.where === 'server' ? 'on the server (set -x shows the call)' : 'here, in this page'}`, 'muted');
      const fx = Object.entries(c.effects ?? {}).map(([o, e]) => `${o.length === 1 ? '-' : '--'}${o}: ${e}`);
      if (c.bare) fx.push(`alone: ${c.bare}`);
      ctx.out(`effect: ${c.effect ?? 'not declared - counts as setup'}${fx.length ? `; ${fx.join(', ')}` : ''}${c.model === 'never' ? '; never run by a model' : ''}`, 'muted');
      if (c.data) ctx.out(`--json: ${c.data}`, 'muted');
      const aliases = [...ctx.shell.aliases].filter(([, v]) => v.split(' ')[0] === c.name).map(([k]) => k);
      if (aliases.length) ctx.out(`also: ${aliases.join(', ')}`, 'muted');
      if (c.old) ctx.out(`old: ${c.old}`, 'warn');
    },
  },
  {
    name: 'clear', group: 'shell', summary: 'an empty terminal', usage: 'clear', where: 'here', effect: 'shows', data: 'nothing',
    run(ctx) { ctx.shell.write('\x1b[2J'); },
  },
  {
    name: 'history', group: 'shell', summary: 'what you typed (never a secret)', usage: 'history [-c]', where: 'here', options: { c: 'forget it all' },
    effect: 'reads', effects: { c: 'deletes' }, data: '[{ n, line }]',
    run(ctx) {
      const h = ctx.shell.history;
      if (ctx.opts.c) { h.length = 0; ctx.shell.saveHistory?.(); return; }
      h.forEach((l, i) => { ctx.out(`${String(i + 1).padStart(4)}  ${l}`); ctx.data({ n: i + 1, line: l }); });
    },
  },
  {
    name: 'alias', group: 'shell', summary: 'a short name for a command', usage: "alias [NAME='COMMAND ...']", where: 'here',
    effect: 'setup', bare: 'reads', data: '[{ name, line }]',
    run(ctx) {
      if (!ctx.words.length) { for (const [k, v] of ctx.shell.aliases) { ctx.out(`alias ${k}='${v}'`); ctx.data({ name: k, line: v }); } return; }
      for (const w of ctx.words) {
        const eq = w.indexOf('=');
        if (eq < 0) { const v = ctx.shell.aliases.get(w); if (v) { ctx.out(`alias ${w}='${v}'`); ctx.data({ name: w, line: v }); } else { ctx.err(`${w}: no such alias`); return 1; } continue; }
        ctx.shell.aliases.set(w.slice(0, eq), w.slice(eq + 1));
        ctx.data({ name: w.slice(0, eq), line: w.slice(eq + 1) });
      }
    },
  },
  {
    name: 'unalias', group: 'shell', summary: 'forget a short name', usage: 'unalias NAME', where: 'here', effect: 'setup', data: '[{ name }]',
    complete: (word, shell) => [...shell.aliases.keys()],
    run(ctx) { for (const a of ctx.args) { if (!ctx.shell.aliases.delete(a)) { ctx.err(`${a}: no such alias`); return 1; } ctx.data({ name: a }); } },
  },
  {
    name: 'echo', group: 'shell', summary: 'words back', usage: 'echo WORDS', where: 'here', effect: 'reads', data: '{ text }',
    run(ctx) { ctx.out(ctx.words.join(' ')); ctx.data({ text: ctx.words.join(' ') }); },
  },
  {
    name: 'export', group: 'shell', summary: 'a variable, for $NAME', usage: 'export [NAME=VALUE]', where: 'here', effect: 'setup', bare: 'reads', data: '[{ name, value }]',
    run(ctx) {
      if (!ctx.words.length) { for (const [k, v] of Object.entries(ctx.shell.env)) if (k !== '?') { ctx.out(`${k}=${v}`); ctx.data({ name: k, value: v }); } return; }
      for (const w of ctx.words) { const eq = w.indexOf('='); if (eq > 0) { ctx.shell.env[w.slice(0, eq)] = w.slice(eq + 1); ctx.data({ name: w.slice(0, eq), value: w.slice(eq + 1) }); } }
    },
  },
  {
    name: 'unset', group: 'shell', summary: 'forget a variable', usage: 'unset NAME', where: 'here', effect: 'setup', data: 'nothing',
    run(ctx) {
      for (const w of ctx.words) {
        if (['HOME', 'USER', '?'].includes(w)) { ctx.err(`${w} stays: the shell needs it`); return 1; }
        if (!(w in ctx.shell.env)) { ctx.err(`${w}: no such variable`); return 1; }
        delete ctx.shell.env[w];
      }
    },
  },
  {
    name: 'set', group: 'shell', summary: 'set -x: show what each command becomes (an API call, a step here); set +x: stop', usage: 'set -x | set +x', where: 'here',
    options: { x: 'show what each command becomes' }, effect: 'shows', data: '{ xtrace }',
    run(ctx) {
      if (ctx.opts.x) ctx.shell.trace = true;
      else if (ctx.words.includes('+x')) ctx.shell.trace = false;
      else ctx.out(`xtrace ${ctx.shell.trace ? 'on' : 'off'}`);
      ctx.data({ xtrace: ctx.shell.trace });
    },
  },
  {
    // A file's lines may do anything: the person decides, as for the setup.
    name: 'source', group: 'shell', summary: 'run the commands of a file, line by line', usage: 'source FILE', where: 'here', complete: 'path',
    effect: 'setup', data: "{ code } - each line's own data goes to the terminal",
    async run(ctx) {
      const file = ctx.args[0];
      if (!file) { ctx.err('which file? source FILE'); return 1; }
      let code = 0;
      for (const line of (await ctx.shell.paths.read(ctx.shell.paths.resolve(file))).split('\n')) {
        const l = line.trim();
        if (!l || l.startsWith('#')) continue;
        code = await ctx.shell.run(l, { signal: ctx.signal });
        if (ctx.signal?.aborted) break;
      }
      ctx.data({ code });
      return code;
    },
  },
  {
    name: 'exit', group: 'shell', summary: 'close the terminal', usage: 'exit', where: 'here', effect: 'shows', data: 'nothing',
    run(ctx) { ctx.shell.exit?.(); },
  },

  // ------------------------------------------------------------ files and paths
  {
    name: 'pwd', group: 'files', summary: 'where you are', usage: 'pwd', where: 'here', effect: 'reads', data: '{ path }',
    run(ctx) { ctx.out(ctx.shell.cwd); ctx.data({ path: ctx.shell.cwd }); },
  },
  {
    name: 'cd', group: 'files', summary: 'go to a folder', usage: 'cd [PATH]', where: 'here', complete: 'path', effect: 'shows', data: '{ path }',
    async run(ctx) {
      const to = ctx.shell.paths.resolve(ctx.args[0] ?? ctx.shell.env.HOME);
      if (!(await ctx.shell.paths.isDir(to))) { ctx.err(`${ctx.args[0]}: not a folder`); return 1; }
      ctx.shell.cwd = to;
      ctx.data({ path: to });
    },
  },
  {
    name: 'ls', group: 'files', summary: "what is in a folder", usage: 'ls [-l] [PATH...]', where: 'here', complete: 'path',
    options: { l: 'one a line, with sizes and what each is', json: 'as data' }, effect: 'reads', data: '[{ name, dir, info }]',
    async run(ctx) {
      const paths = ctx.args.length ? ctx.args : ['.'];
      let code = 0;
      for (const p of paths) {
        let entries;
        try { entries = await ctx.shell.paths.list(ctx.shell.paths.resolve(p)); } catch (e) { ctx.err(e.message); code = 2; continue; }
        if (paths.length > 1) ctx.out(`${p}:`, 'heading');
        for (const e of entries) ctx.data(e);
        if (ctx.opts.l) {
          const w = Math.max(4, ...entries.map(e => e.name.length + 1));
          for (const e of entries) ctx.out(`${(e.dir ? `${e.name}/` : e.name).padEnd(w)}  ${e.info ?? ''}`.trimEnd(), e.tone ?? (e.dir ? 'info' : 'text'));
        } else columns(ctx, entries);
      }
      return code;
    },
  },
  {
    name: 'cat', group: 'files', summary: "a file's text", usage: 'cat FILE...', where: 'here', complete: 'path', effect: 'reads', data: '[{ file, text }]',
    async run(ctx) {
      if (!ctx.args.length) { for (const l of ctx.stdin ?? []) ctx.out(l); ctx.data({ file: null, text: (ctx.stdin ?? []).join('\n') }); return; }
      let code = 0;
      for (const f of ctx.args) {
        try { const text = await ctx.shell.paths.read(ctx.shell.paths.resolve(f)); ctx.out(text); ctx.data({ file: f, text }); } catch (e) { ctx.err(e.message); code = 1; }
      }
      return code;
    },
  },

  // ------------------------------------------------------------ text, in pipes
  {
    name: 'grep', group: 'text', summary: 'the lines that hold a pattern', usage: 'grep [-i] [-v] [-c] PATTERN [FILE...]', where: 'here',
    options: { i: 'big and small letters alike', v: 'the lines that do NOT hold it', c: 'only how many' }, complete: 'path',
    effect: 'reads', data: '{ lines, count }',
    async run(ctx) {
      const [pattern, ...files] = ctx.args;
      if (pattern === undefined) { ctx.err('what to look for? grep PATTERN'); return 2; }
      let re;
      try { re = new RegExp(pattern, ctx.opts.i ? 'i' : ''); } catch { re = new RegExp(pattern.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), ctx.opts.i ? 'i' : ''); }
      const hits = (await inputLines(ctx, files)).filter(l => re.test(l) !== !!ctx.opts.v);
      if (ctx.opts.c) ctx.out(String(hits.length)); else for (const l of hits) ctx.out(l);
      ctx.data({ lines: hits, count: hits.length });
      return hits.length ? 0 : 1;
    },
  },
  {
    name: 'sort', group: 'text', summary: 'lines in order', usage: 'sort [-r] [-n] [-u] [FILE...]', where: 'here',
    options: { r: 'the other way', n: 'by the number they start with', u: 'each line once' }, complete: 'path', effect: 'reads', data: '{ lines }',
    async run(ctx) {
      let lines = await inputLines(ctx, ctx.args);
      lines = ctx.opts.n ? lines.sort((a, b) => (parseFloat(a) || 0) - (parseFloat(b) || 0)) : lines.sort((a, b) => a.localeCompare(b));
      if (ctx.opts.r) lines.reverse();
      if (ctx.opts.u) lines = [...new Set(lines)];
      for (const l of lines) ctx.out(l);
      ctx.data({ lines });
    },
  },
  {
    name: 'head', group: 'text', summary: 'the first lines', usage: 'head [-n N] [FILE...]', where: 'here', valued: ['n'], options: { n: 'how many (10)' }, complete: 'path',
    effect: 'reads', data: '{ lines }',
    async run(ctx) { const lines = (await inputLines(ctx, ctx.args)).slice(0, Number(ctx.opts.n ?? 10)); for (const l of lines) ctx.out(l); ctx.data({ lines }); },
  },
  {
    name: 'tail', group: 'text', summary: 'the last lines', usage: 'tail [-n N] [FILE...]', where: 'here', valued: ['n'], options: { n: 'how many (10)' }, complete: 'path',
    effect: 'reads', data: '{ lines }',
    async run(ctx) { const lines = (await inputLines(ctx, ctx.args)).slice(-Number(ctx.opts.n ?? 10)); for (const l of lines) ctx.out(l); ctx.data({ lines }); },
  },
  {
    name: 'wc', group: 'text', summary: 'how many lines, words, letters', usage: 'wc [-l] [-w] [-c] [FILE...]', where: 'here',
    options: { l: 'lines', w: 'words', c: 'letters' }, complete: 'path', effect: 'reads', data: '{ lines, words, letters }',
    async run(ctx) {
      const lines = (await inputLines(ctx, ctx.args)).filter((l, i, a) => i < a.length - 1 || l !== '');
      const n = { l: lines.length, w: lines.join(' ').split(/\s+/).filter(Boolean).length, c: lines.reduce((s, l) => s + l.length + 1, 0) };
      const asked = ['l', 'w', 'c'].filter(k => ctx.opts[k]);
      ctx.out((asked.length ? asked : ['l', 'w', 'c']).map(k => String(n[k])).join(' '));
      ctx.data({ lines: n.l, words: n.w, letters: n.c });
    },
  },
];
