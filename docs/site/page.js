// A page of one's own (stage 4, the pilot, 2026-10-19: "I only want to make
// games with an AI agent - I need nothing else; or I only want to write and
// build code, and I need something else"). The site's whole desktop -
// its menus, its keys, the windows it opens and where - described in an
// INI file on D:, the person's own: made by them, or by their model with
// write_file. There is no code in it to run: every menu item and every key
// is a line of the console, and the command contract (console/commands.js)
// says what each does. What deletes, changes the setup or gives something
// out asks the person each time, as it does for a model; what a model may
// never run, a page never runs either.
//
// Only one's own (OWLOS-LAN references/ui-and-security.md): a page is put on
// from D:, My files, never from another drive or a profile - sharing a page
// is sharing its words, which the other person's own file then says again.
// The WIRE CITY menu stays the site's in every page: the whole site again,
// the pages, the terminal, the tokens. ?ui=off is the whole site for one
// visit, whatever page is on.
//
//   ; GAMES.INI
//   [PAGE]
//   Name=Games with my AI
//   Open=chat left, dos right
//   [MENU ~G~ame]
//   ~B~uild and run=build A:\MY\GAME\GAME.ASM
//   -
//   ~Z~ip it=zip A:\MY\GAME
//   [KEYS]
//   F9 Build=build A:\MY\GAME\GAME.ASM
//
// The guide's PAGES topic (docs/guide/PAGES.MD) says it for models and people.

import { ASK_EFFECTS } from '../console/commands.js';
import { commandsOf } from './agent.js';

/** The page that is on: { file, text } - what was checked when it was put on, not the file as it is now. */
export const PAGE_KEPT = 'site.page.1';
/** Where a person's pages are: D:\PAGES. */
export const PAGES_DIR = 'D:\\PAGES';

/** The windows a page may open, by the name `window` takes - and whether `at` places them. */
export const WINDOWS = {
  dos: { what: 'the DOS PC - switched on if it is off', placed: true },
  chat: { what: 'AI - chat: a model on your own key', placed: true },
  agents: { what: 'AI - agents: the chat and your Claude Code, their tokens', placed: true },
  tasks: { what: 'AI - tasks: what the models work on', placed: true },
  calls: { what: 'AI - console: every call a model made', placed: true },
  terminal: { what: 'the terminal (Ctrl+`)', placed: true },
  who: { what: 'who is online', placed: true },
  drives: { what: 'Map Drives: which letter is where', placed: true },
  catalog: { what: 'the games on C:', placed: true },
  pages: { what: 'your pages: one put on, edited, or the whole site again', placed: true },
  netmon: { what: 'the network monitor: the DOS PC on the relay - bytes, a graph, every packet', placed: false },
  machine: { what: 'the machine monitor: how fast the DOS PC runs, how busy it is, its disks', placed: false },
  lessons: { what: 'the course\'s lessons', placed: false },
  commander: { what: 'Kirin Commander for Web, its two panels', placed: false },
};
export const PLACES = ['left', 'right', 'top', 'bottom', 'full'];

/** Keys the site keeps in every page: the menu, saving, zoom, closing a window. */
const KEPT_KEYS = ['F2', 'F5', 'F10', 'Alt+F3', 'Alt+X'];
const LIMIT = { bytes: 16384, menus: 8, items: 30, keys: 12, label: 40, line: 300, name: 60 };
const KEY = /^(?:(ctrl|alt)\+)?(f(?:[1-9]|1[0-2]))$/i;

/**
 * An INI page read: { name, open: [{ window, at }], menus: [{ title, items:
 * [{ label, line } | { line: null }] }], keys: [{ key, ctrl, alt, label,
 * line }], problems: [text] } - a problem a line, said with its line number.
 */
export function parsePage(text) {
  const page = { name: '', open: [], menus: [], keys: [], problems: [] };
  const bad = (n, what) => page.problems.push(`line ${n}: ${what}`);
  if (text.length > LIMIT.bytes) { page.problems.push(`${text.length} characters: a page is ${LIMIT.bytes} at most`); return page; }
  let section = null, menu = null;
  text.split(/\r?\n/).forEach((raw, i) => {
    const n = i + 1, l = raw.trim();
    if (!l || l.startsWith(';') || l.startsWith('#')) return;
    const head = /^\[(.+)\]$/.exec(l);
    if (head) {
      const h = head[1].trim(), m = /^menu\s+(.+)$/i.exec(h);
      if (/^page$/i.test(h)) section = 'page';
      else if (/^keys$/i.test(h)) section = 'keys';
      else if (m) {
        section = 'menu';
        if (page.menus.length >= LIMIT.menus) { bad(n, `${LIMIT.menus} menus at most`); menu = null; return; }
        const title = m[1].trim();
        if (title.replace(/~/g, '').length > LIMIT.label) bad(n, `a menu's title is ${LIMIT.label} letters at most`);
        menu = { title, items: [] };
        page.menus.push(menu);
      } else { bad(n, `[${h}]: a page has [PAGE], [MENU title] and [KEYS]`); section = null; }
      return;
    }
    if (section === 'menu' && /^-+$/.test(l)) { if (menu) menu.items.push({ line: null }); return; }
    const eq = l.indexOf('=');
    if (eq < 1) { bad(n, `"${l}": NAME=VALUE`); return; }
    const key = l.slice(0, eq).trim(), value = l.slice(eq + 1).trim();
    if (section === 'page') {
      if (/^name$/i.test(key)) page.name = value.slice(0, LIMIT.name);
      else if (/^open$/i.test(key)) {
        for (const part of value.split(',').map(s => s.trim()).filter(Boolean)) {
          const [w, at = null, ...more] = part.toLowerCase().split(/\s+/);
          if (!WINDOWS[w]) bad(n, `${w}: no such window - ${Object.keys(WINDOWS).join(', ')}`);
          else if (at && !PLACES.includes(at)) bad(n, `${at}: a place is ${PLACES.join(', ')}`);
          else if (more.length) bad(n, `"${part}": a window and a place`);
          else page.open.push({ window: w, at });
        }
      } else bad(n, `${key}: [PAGE] has Name and Open`);
    } else if (section === 'menu') {
      if (!menu) return;
      if (menu.items.length >= LIMIT.items) { bad(n, `${LIMIT.items} items a menu at most`); return; }
      if (key.replace(/~/g, '').length > LIMIT.label) bad(n, `"${key}": a label is ${LIMIT.label} letters at most`);
      if (value.length > LIMIT.line) bad(n, `a line is ${LIMIT.line} characters at most`);
      if (!value) bad(n, `${key}: what does it run?`);
      menu.items.push({ label: key, line: value });
    } else if (section === 'keys') {
      const [k, ...words] = key.split(/\s+/);
      const m = KEY.exec(k);
      if (!m) { bad(n, `${k}: a key is F1..F12, Ctrl+F1.., Alt+F1..`); return; }
      const name = `${m[1] ? `${m[1][0].toUpperCase()}${m[1].slice(1).toLowerCase()}+` : ''}${m[2].toUpperCase()}`;
      if (KEPT_KEYS.includes(name)) { bad(n, `${name} is the site's in every page (${KEPT_KEYS.join(', ')})`); return; }
      if (page.keys.length >= LIMIT.keys) { bad(n, `${LIMIT.keys} keys at most`); return; }
      if (page.keys.some(x => x.name === name)) { bad(n, `${name} twice`); return; }
      if (!value) { bad(n, `${name}: what does it run?`); return; }
      page.keys.push({ name, key: m[2].toUpperCase(), ctrl: /ctrl/i.test(m[1] ?? ''), alt: /alt/i.test(m[1] ?? ''), label: words.join(' ').slice(0, LIMIT.label), line: value });
    } else bad(n, `"${l}" is in no section - [PAGE], [MENU title] or [KEYS] first`);
  });
  if (!page.menus.length && !page.keys.length) page.problems.push('no [MENU] and no [KEYS]: a page with nothing to do');
  return page;
}

/**
 * What a line of a page would do, by the contract: { effect, asks, problem }.
 * Several commands (;, &&, |) - the worst of them; a problem refuses the page.
 */
export function judgeLine(shell, line) {
  let c;
  try { c = commandsOf(shell, line); } catch (e) { return { effect: null, asks: false, problem: e.message }; }
  if (c.redirect) return { effect: null, asks: false, problem: 'a redirect (> or >>) - not in a page' };
  if (c.unknown.length) return { effect: null, asks: false, problem: `${c.unknown.join(', ')}: not a command` };
  const never = c.list.find(x => x.never);
  if (never) return { effect: never.effect, asks: false, problem: `${never.name}: the person's own command, never in a page` };
  const ask = c.list.find(x => ASK_EFFECTS.includes(x.effect));
  const order = ['reads', 'shows', 'writes', 'runs', 'deletes', 'setup', 'shares'];
  const worst = c.list.map(x => x.effect).sort((a, b) => order.indexOf(b) - order.indexOf(a))[0] ?? 'reads';
  return { effect: ask?.effect ?? worst, asks: !!ask, problem: null };
}

/**
 * The page checked, in words a person reads before it is put on: where it
 * opens what, each item and key with what it does, what asks each time,
 * what refuses it. { lines: [{ text, tone }], data, problems, asks }.
 */
export function checkPage(shell, file, page) {
  const lines = [], problems = [...page.problems], asks = [];
  const say = (text, tone = 'text') => lines.push({ text, tone });
  say(`${file} - "${page.name || 'a page with no Name'}"`, 'heading');
  if (page.open.length) say(`opens: ${page.open.map(o => `${o.window}${o.at ? ` ${o.at}` : ''}${o.at && !WINDOWS[o.window].placed ? ' (where it always opens)' : ''}`).join(', ')}`);
  else say('opens nothing: the windows stay as they are', 'muted');
  const row = (label, line, from) => {
    const j = judgeLine(shell, line);
    if (j.problem) problems.push(`${from} "${label}": ${j.problem}`);
    if (j.asks) asks.push(`${label.replace(/~/g, '')} (${line})`);
    say(`  ${label.replace(/~/g, '').padEnd(22)} ${line.padEnd(34)} ${j.problem ? 'REFUSED' : `${j.effect}${j.asks ? ' - asks you each time' : ''}`}`,
      j.problem ? 'bad' : j.asks ? 'warn' : 'text');
    return { label: label.replace(/~/g, ''), line, effect: j.effect, asks: j.asks, problem: j.problem };
  };
  const menus = page.menus.map(m => {
    say(`menu ${m.title.replace(/~/g, '')}:`);
    return { title: m.title.replace(/~/g, ''), items: m.items.filter(x => x.line).map(x => row(x.label, x.line, `menu ${m.title.replace(/~/g, '')}`)) };
  });
  if (page.keys.length) say('keys:');
  const keys = page.keys.map(k => ({ key: k.name, ...row(`${k.name}${k.label ? ` ${k.label}` : ''}`, k.line, 'key') }));
  say('The WIRE CITY menu stays: the whole site again, the pages, the terminal, your tokens. ?ui=off is the whole site for one visit.', 'muted');
  for (const p of problems) say(p, 'bad');
  say(problems.length ? `${problems.length} problem${problems.length > 1 ? 's' : ''}: not put on until they are mended` : `fine${asks.length ? ` - ${asks.length} line${asks.length > 1 ? 's' : ''} ask${asks.length > 1 ? '' : 's'} you each time` : ''}`,
    problems.length ? 'bad' : 'good');
  return { lines, problems, asks, data: { file, name: page.name, open: page.open, menus, keys, asks, problems } };
}

/** The page in one breath, for a Yes box: its name, its menus - or buttons, lists, styles and what was taken out of it - what asks. */
export function pageBrief(check) {
  const d = check.data;
  const n = (k, w) => `${k} ${w}${k === 1 ? '' : 's'}`;
  if (d.kind === 'html') {
    return `"${d.name || d.file}": a page of HTML and CSS - ${n(d.runs.length, 'button')}, ${n(d.lists.length, 'list')}` +
      `${d.parts.length ? `; holds ${d.parts.join(', ')}` : ''}${d.styles.length ? `; styles: ${d.styles.join(', ')}` : ''}` +
      `${d.removed.length ? `; taken out, never run: ${d.removed.join(', ')}` : ''}` +
      `${d.asks.length ? `; asks you each time before: ${d.asks.join('; ')}` : ''}`;
  }
  const items = d.menus.reduce((n, m) => n + m.items.length, 0);
  return `"${d.name || d.file}": ${d.menus.map(m => m.title).join(', ') || 'no menus'} - ${items} item${items === 1 ? '' : 's'}, ${d.keys.length} key${d.keys.length === 1 ? '' : 's'}` +
    `${d.open.length ? `; opens ${d.open.map(o => o.window).join(', ')}` : ''}` +
    `${d.asks.length ? `; asks you each time before: ${d.asks.join('; ')}` : ''}`;
}

/** An HTML page by its name: HTML and CSS, the whole look its own (htmlpage.js). */
export const isHtml = file => /\.html?$/i.test(String(file));

/** The file an example is written to in D:\PAGES. */
export const exampleName = k => (k === 'studio' ? 'STUDIO.HTM' : `${k.toUpperCase()}.INI`);

/** The pages `page --example` writes to D:\PAGES - the two the pilot named, and a whole site of one's own. */
export const EXAMPLES = {
  games: `; GAMES.INI - a page for making DOS games with an AI, and nothing else.
; page D:\\PAGES\\GAMES.INI --use puts it on; WIRE CITY > Whole site takes it off.
; The game lives in A:\\MY\\GAME - the model makes it there; change the
; lines below to your game's folder and name.
[PAGE]
Name=Games with my AI
Open=chat left, dos right

[MENU ~G~ame]
~B~uild and run=build A:\\MY\\GAME\\GAME.ASM
~R~un again=run A:\\MY\\GAME\\GAME.COM
~E~dit the source=edit A:\\MY\\GAME\\GAME.ASM
-
~Z~ip it to downloads=zip A:\\MY\\GAME
~F~iles of the game=commander A:\\MY\\GAME A:\\ENGINE

[MENU ~A~I]
~C~hat=window chat left
~T~asks=window tasks
C~a~lls=window calls
-
~H~ow pages work=man page

[KEYS]
F9 Build=build A:\\MY\\GAME\\GAME.ASM
Ctrl+F9 Run=run A:\\MY\\GAME\\GAME.COM
F3 Chat=window chat left
`,
  code: `; CODE.INI - a page for writing and building code: the files, an editor,
; FASM, the DOS PC and the terminal - no games, no lessons, no network.
; page D:\\PAGES\\CODE.INI --use puts it on; WIRE CITY > Whole site takes it off.
; F9 builds the .ASM in the editor in front, as on the whole site.
[PAGE]
Name=Write and build
Open=terminal left, dos right

[MENU ~F~iles]
~M~y code=commander A:\\MY D:\\
~E~xamples=commander A:\\EXAMPLES A:\\MY
The e~n~gine=commander A:\\ENGINE A:\\MY
-
~T~erminal=window terminal left

[MENU ~B~uild]
~B~uild and run what is in front=build
~R~un what was built=run
-
The ~D~OS PC=window dos right
DOS ~p~rompt again=dos prompt

[KEYS]
F9 Build=build
Ctrl+F9 Run=run
F3 Files=commander A:\\MY D:\\
`,
  studio: `<!doctype html>
<!-- STUDIO.HTM - the whole site as a page of one's own: HTML and CSS, Bootstrap's look.
     page D:\\PAGES\\STUDIO.HTM --use puts it on; the WIRE CITY button in the corner takes it off.
     data-run is a console line, data-list a command that reads (its first child once a row,
     data-field a row's field), data-part="dos" the DOS PC. No script runs in a page. -->
<html lang="en">
<head>
<title>My game studio</title>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css">
<style>
  .dos { aspect-ratio: 4 / 3; background: #000; border-radius: .375rem; }
  .map { aspect-ratio: 16 / 10; background: #000; border-radius: .375rem; }
  .studio { min-height: 100vh; }
</style>
</head>
<body>
<div class="studio bg-body-tertiary">
  <nav class="navbar bg-dark border-bottom border-body" data-bs-theme="dark">
    <div class="container-fluid"><span class="navbar-brand">My game studio</span>
      <span class="navbar-text">A:\\MY\\GAME</span></div>
  </nav>
  <main class="container-fluid py-4">
    <div class="row g-4">
      <div class="col-lg-8">
        <div class="card shadow-sm"><div class="card-body p-2"><div class="dos" data-part="dos"></div></div>
          <div class="card-footer text-body-secondary small">A click on the picture gives the DOS PC the keyboard; Right Ctrl takes it back.</div></div>
      </div>
      <div class="col-lg-4">
        <div class="card shadow-sm mb-4">
          <div class="card-header fw-semibold">My game</div>
          <div class="card-body d-grid gap-2">
            <button class="btn btn-primary" data-run="build A:\\MY\\GAME\\GAME.ASM">Build and run</button>
            <button class="btn btn-outline-secondary" data-run="run A:\\MY\\GAME\\GAME.COM">Run again</button>
            <button class="btn btn-outline-secondary" data-run="zip A:\\MY\\GAME">Zip it to my downloads</button>
          </div>
        </div>
        <div class="card shadow-sm mb-4">
          <div class="card-header fw-semibold">Files of the game</div>
          <ul class="list-group list-group-flush" data-list="ls A:\\MY\\GAME">
            <li class="list-group-item d-flex justify-content-between"><span data-field="name"></span><small class="text-body-secondary" data-field="info"></small></li>
          </ul>
        </div>
        <div class="card shadow-sm">
          <div class="card-header fw-semibold">Who is here</div>
          <ul class="list-group list-group-flush" data-list="who" data-every="5">
            <li class="list-group-item"><span data-field="name"></span> <small class="text-body-secondary" data-field="doing"></small></li>
          </ul>
        </div>
      </div>
    </div>
    <div class="row g-4 mt-1">
      <div class="col-lg-6">
        <div class="card shadow-sm"><div class="card-header fw-semibold">The sky of OWL FLY III</div>
          <div class="card-body p-2"><div class="map" data-part="map" data-room="owlfly3"></div></div>
          <div class="card-footer small text-body-secondary">The wheel zooms, a drag moves it; a click on a jet that shares its screen watches it.</div></div>
      </div>
      <div class="col-lg-6">
        <div class="card shadow-sm"><div class="card-header fw-semibold">The network</div>
          <div class="card-body"><pre class="small mb-2" data-text="net" data-every="2"></pre>
            <table class="table table-sm small mb-0"><thead><tr><th>time</th><th>way</th><th>bytes</th><th>to</th></tr></thead>
              <tbody data-list="net --packets" data-every="2"><tr><td data-field="at"></td><td data-field="dir"></td><td data-field="size"></td><td data-field="to"></td></tr></tbody></table></div></div>
      </div>
    </div>
  </main>
</div>
</body>
</html>
`,
};
