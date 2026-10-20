// A page of one's own, the whole of it (stage 4, the pilot, 2026-10-20: "I
// meant that the style could be changed completely" - a site of one's own,
// Bootstrap or anything else). An HTML file on D:\PAGES, made by the person
// or their model, laid over the site's desktop: its look is all its own,
// what it DOES is the site's. There is no code of the page's in it:
//
//   - the file is taken apart (DOMParser, inert) and only markup and CSS
//     are kept - no <script>, no on...= handler, no javascript: link, no
//     frame, no form, no url() in its CSS but a data: picture; stylesheets
//     only from STYLES, each checked by its hash;
//   - what its buttons do is console lines: data-run="build A:\MY\GAME\GAME.ASM",
//     judged by the command contract as an INI page's are (page.js) - what
//     deletes, changes the setup or gives something out asks the person
//     each time, what a model may never run is refused;
//   - what it shows is the commands' data: data-list="ls A:\MY\GAME" fills
//     its first child once a row, data-field="name" a row's field - only
//     commands that read;
//   - the site's own parts go where it says: data-part="dos" is the DOS PC;
//   - a Content-Security-Policy goes on with it, so whatever slipped past
//     stays dead text, and nothing it shows can call another address;
//   - the WIRE CITY button is the site's, in the corner of every page, in
//     a closed shadow root: a page that hides or covers it is taken off.
//
// OWLOS-LAN references/ui-and-security.md has the reasons; the guide's
// PAGES topic says it for models. INI pages (page.js) stay - the cheap kind.

import { judgeLine } from './page.js';

/** The stylesheets a page may load: exact addresses, each with its hash (SRI) - computed from the files themselves, 2026-10-20. */
export const STYLES = {
  'https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css':
    { name: 'Bootstrap 5.3.3', integrity: 'sha384-QWTKZyjpPEjISv5WaRU9OFeRpok6YctnYmDr5pNlyT2bRjXh0JMhjY6hW+ALEwIH' },
  'https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.min.css':
    { name: 'Bootstrap Icons 1.11.3', integrity: 'sha384-XGjxtQfXaH2tnPFa9x+ruJTuLE3Aa6LhHSWRr1XeTyhezb4abCG4ccI5AkVDxqC+' },
};

/** The site's parts a page may hold, by data-part. */
export const PARTS = {
  dos: 'the DOS PC - switched on if it is off; a click on it gives it the keyboard, Right Ctrl takes it back',
  map: 'the live map of a game\'s sky - data-room="owlfly3" (or owlfly2); every jet where it is, the wheel zooms, a drag moves it',
  chat: 'AI - chat (not in an HTML page yet: the slot says so, WIRE CITY > Whole site has it)',
  terminal: 'the terminal (not in an HTML page yet: the slot says so, Ctrl+` on the whole site)',
};

/** What an HTML page can say, each with an example - `page --parts` lists it, for a model to build from. */
export const MARKUP = [
  { name: 'data-part="dos"', what: PARTS.dos, example: '<div style="aspect-ratio: 4 / 3" data-part="dos"></div>' },
  { name: 'data-part="map"', what: PARTS.map, example: '<div style="aspect-ratio: 1" data-part="map" data-room="owlfly3"></div>' },
  { name: 'data-run="LINE"', what: 'a click runs a console line, judged by what it does: deletes, setup and shares ask each time; in a list\'s row, {field} puts the row\'s field in',
    example: '<button class="btn btn-primary" data-run="build A:\\MY\\GAME\\GAME.ASM">Build and run</button>' },
  { name: 'data-list="LINE"', what: 'a command that only reads (ls, who, net, net --packets, machine, df, page, window, info --list): its first child is a row, repeated once a row of its data',
    example: '<ul data-list="who" data-every="5"><li><b data-field="name"></b> <span data-field="doing"></span></li></ul>' },
  { name: 'data-field="NAME"', what: 'in a row: shows that field of the row - man COMMAND names a command\'s fields (its --json)', example: '<span data-field="name"></span>' },
  { name: 'data-text="LINE"', what: 'shows what a reading command prints', example: '<pre data-text="net" data-every="2"></pre>' },
  { name: 'data-every="SECONDS"', what: 'on a list or a text: read again every so many seconds, 2 at the least', example: '<ul data-list="net --packets" data-every="2">...</ul>' },
  { name: 'data-room="ROOM"', what: 'on the map: whose sky - owlfly3, owlfly2', example: '<div data-part="map" data-room="owlfly2"></div>' },
];

const LIMIT = 65536;
const KEEP = new Set(['div', 'span', 'p', 'a', 'ul', 'ol', 'li', 'dl', 'dt', 'dd', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
  'header', 'footer', 'main', 'nav', 'section', 'article', 'aside', 'button', 'img', 'table', 'thead', 'tbody', 'tfoot',
  'tr', 'th', 'td', 'caption', 'colgroup', 'col', 'strong', 'em', 'b', 'i', 'u', 's', 'small', 'big', 'br', 'hr', 'pre',
  'code', 'kbd', 'samp', 'blockquote', 'q', 'cite', 'figure', 'figcaption', 'label', 'sup', 'sub', 'mark', 'abbr',
  'time', 'details', 'summary', 'progress', 'meter', 'address', 'picture']);
/** Gone with all inside them: what runs, frames, takes input or sends. */
const DROP = new Set(['script', 'iframe', 'frame', 'frameset', 'object', 'embed', 'applet', 'svg', 'math', 'template',
  'noscript', 'input', 'textarea', 'select', 'option', 'optgroup', 'base', 'meta', 'title', 'audio', 'video', 'source',
  'track', 'canvas', 'dialog', 'slot', 'portal', 'marquee', 'param', 'head']);
const ATTRS = new Set(['class', 'id', 'title', 'alt', 'role', 'lang', 'dir', 'colspan', 'rowspan', 'width', 'height', 'open',
  'value', 'max', 'min', 'low', 'high', 'optimum', 'datetime', 'span', 'start', 'reversed', 'type', 'scope', 'abbr',
  'data-part', 'data-run', 'data-list', 'data-field', 'data-text', 'data-room', 'data-every']);
/** A row's value put into a line: a name, nothing a shell would read as more - no space, quote, ;, |, &, >, $. */
const SAFE = /^[A-Za-z0-9_.~()^@\-]{1,64}$/;

/**
 * The file taken apart: { name, nodes (the body's children, clean, inert),
 * css, styles: [address], removed: { what: count }, runs, lists, texts,
 * parts, size }. Runs only in a browser (DOMParser).
 */
export function cleanPage(text) {
  const removed = {};
  const count = what => { removed[what] = (removed[what] ?? 0) + 1; };
  const doc = new DOMParser().parseFromString(String(text), 'text/html');
  const name = (doc.querySelector('title')?.textContent ?? doc.querySelector('h1')?.textContent ?? '').trim().replace(/\s+/g, ' ').slice(0, 60);
  const styles = [], css = [];
  for (const l of doc.querySelectorAll('link')) {
    const href = l.getAttribute('href') ?? '';
    if (/stylesheet/i.test(l.getAttribute('rel') ?? '') && STYLES[href]) { if (!styles.includes(href)) styles.push(href); }
    else count(`<link> to ${hostOf(href)}`);
    l.remove();
  }
  for (const s of doc.querySelectorAll('style')) { css.push(cleanCss(s.textContent, count)); s.remove(); }
  // The head's own: only its <title> is read; anything else there (a <script>, a <meta> refresh) is said and left behind.
  for (const e of [...doc.head.children]) if (!/^(title|meta)$/i.test(e.tagName) || e.getAttribute('http-equiv')) count(`<${e.tagName.toLowerCase()}> in <head>`);
  const walk = el => {
    for (const c of [...el.children]) {
      const tag = c.tagName.toLowerCase();
      if (DROP.has(tag)) { count(`<${tag}>`); c.remove(); continue; }
      walk(c);
      if (!KEEP.has(tag)) { count(`<${tag}> (its contents kept)`); c.replaceWith(...c.childNodes); continue; }
      for (const a of [...c.attributes]) {
        const n = a.name.toLowerCase(), v = a.value;
        if (n.startsWith('on')) { count(`${n}=`); c.removeAttribute(a.name); continue; }
        if (n === 'href' && tag === 'a') {
          if (/^#[\w-]*$/.test(v)) continue;
          if (/^https:\/\/[^\s"'<>]+$/i.test(v)) { c.setAttribute('target', '_blank'); c.setAttribute('rel', 'noopener noreferrer'); continue; }
          count(`a link that is not https: (${v.split(':')[0].slice(0, 12) || 'relative'})`);
          c.removeAttribute(a.name);
          continue;
        }
        if (n === 'src' && tag === 'img') {
          if (/^data:image\/(png|gif|jpeg|webp|svg\+xml)[;,]/i.test(v)) continue;
          count(`a picture from ${hostOf(v)}`);
          c.removeAttribute(a.name);
          continue;
        }
        if (n === 'style') { c.setAttribute('style', cleanCss(v, count)); continue; }
        if (n === 'target' || n === 'rel') continue;            // set above for an https: link, dropped below for the rest
        if (n === 'id' && (/^screen$/i.test(v) || /^wc-/i.test(v))) { count(`id="${v}" (the site's)`); c.removeAttribute(a.name); continue; }
        if (ATTRS.has(n) || n.startsWith('aria-') || n.startsWith('data-bs-')) continue;
        count(`${n}=`);
        c.removeAttribute(a.name);
      }
      if (tag === 'a' && !c.hasAttribute('href')) { c.removeAttribute('target'); c.removeAttribute('rel'); }
    }
  };
  walk(doc.body);
  const all = sel => [...doc.body.querySelectorAll(sel)];
  return {
    name, styles, css: css.join('\n'), removed, size: String(text).length,
    nodes: [...doc.body.childNodes],
    runs: all('[data-run]').map(e => ({ label: label(e), line: e.dataset.run, row: !!e.closest('[data-list]') })),
    lists: all('[data-list]').map(e => ({ line: e.dataset.list })),
    texts: all('[data-text]').map(e => ({ line: e.dataset.text })),
    parts: all('[data-part]').map(e => e.dataset.part),
  };
}

/** A page's CSS with nothing that reaches out: no @import, no url() but a data: picture, no escapes to hide one behind. */
function cleanCss(css, count) {
  let out = String(css);
  if (out.includes('\\')) { count('CSS escapes (\\)'); out = out.replace(/\\/g, ''); }
  out = out.replace(/@import[^;]*;?/gi, () => { count('@import'); return ''; });
  out = out.replace(/url\(\s*(['"]?)(.*?)\1\s*\)/gi, (m, q, u) => (/^data:image\//i.test(u.trim()) ? m : (count(`url() to ${hostOf(u)}`), 'none')));
  out = out.replace(/(-webkit-)?image-set\s*\(|expression\s*\(|-moz-binding|behavior\s*:/gi, m => { count(`CSS ${m.replace(/\W/g, '')}`); return 'x-blocked('; });
  return out;
}

function hostOf(u) { try { return new URL(u, 'https://x.invalid/').host.replace('x.invalid', 'this site') || 'nowhere'; } catch { return 'nowhere'; } }
function label(e) { return (e.textContent ?? '').trim().replace(/\s+/g, ' ').slice(0, 40) || e.getAttribute('title') || e.dataset.run; }

/**
 * The page checked, in words a person reads before it is put on - as
 * page.js's checkPage says an INI page: { lines, problems, asks, data,
 * page: { name, kind } }.
 */
export function checkHtmlPage(shell, file, text) {
  const lines = [], problems = [], asks = [];
  const say = (t, tone = 'text') => lines.push({ text: t, tone });
  if (String(text).length > LIMIT) problems.push(`${String(text).length} characters: an HTML page is ${LIMIT} at most`);
  const p = cleanPage(text);
  say(`${file} - "${p.name || 'a page with no <title>'}" - a page of HTML and CSS`, 'heading');
  say(p.styles.length ? `styles: ${p.styles.map(s => STYLES[s].name).join(', ')} (cdn.jsdelivr.net, each checked by its hash)` : 'styles: its own only');
  const unknown = p.parts.filter(x => !PARTS[x]);
  for (const x of unknown) problems.push(`data-part="${x}": a part is ${Object.keys(PARTS).join(', ')}`);
  if (p.parts.length) say(`parts: ${p.parts.join(', ')}${p.parts.some(x => x === 'chat' || x === 'terminal') ? ' - chat and terminal come to HTML pages next; their slots say so' : ''}`);
  const row = (what, line, mustRead) => {
    const j = judgeLine(shell, line.replace(/\{\w+\}/g, 'NAME'));
    let problem = j.problem;
    if (!problem && mustRead && j.effect !== 'reads') problem = `${j.effect}: what a page shows must only read`;
    if (problem) problems.push(`${what} "${line}": ${problem}`);
    if (j.asks && !mustRead) asks.push(`${what} (${line})`);
    say(`  ${what.padEnd(22)} ${line.padEnd(34)} ${problem ? 'REFUSED' : `${j.effect}${j.asks ? ' - asks you each time' : ''}`}`,
      problem ? 'bad' : j.asks ? 'warn' : 'text');
    return { label: what, line, effect: j.effect, asks: j.asks, problem };
  };
  if (p.runs.length) say('buttons:');
  const runs = p.runs.map(r => row(r.label, r.line, false));
  if (p.lists.length || p.texts.length) say('shows:');
  const lists = [...p.lists, ...p.texts].map(l => row('list', l.line, true));
  const removed = Object.entries(p.removed).map(([w, n]) => `${n > 1 ? `${n} x ` : ''}${w}`);
  if (removed.length) say(`taken out, never run: ${removed.join(', ')}`, 'warn');
  if (!p.nodes.some(n => n.nodeType === 1 || n.textContent.trim())) problems.push('nothing in its <body>');
  // The site's own elements are not a page's to style; the tripwire takes off what this does not catch.
  if (/wc-|#screen\b/i.test(p.css)) problems.push("its CSS names the site's own elements (wc-..., #screen) - the WIRE CITY button is not a page's to style");
  say('The WIRE CITY button stays in the corner of every page: the whole site again, your pages, your page off. ?ui=off is the whole site for one visit.', 'muted');
  for (const x of problems) say(x, 'bad');
  say(problems.length ? `${problems.length} problem${problems.length > 1 ? 's' : ''}: not put on until they are mended`
    : `fine${asks.length ? ` - ${asks.length} button${asks.length > 1 ? 's' : ''} ask${asks.length > 1 ? '' : 's'} you each time` : ''}`,
  problems.length ? 'bad' : 'good');
  return {
    lines, problems, asks, page: { name: p.name, kind: 'html' },
    data: { file, name: p.name, kind: 'html', styles: p.styles.map(s => STYLES[s].name), parts: p.parts, runs, lists, removed, asks, problems,
      open: [], menus: [], keys: [] },
  };
}

/**
 * The policy that goes on with a page: our scripts only, pictures from
 * here, styles from here and the CDN, nothing sent elsewhere. js-dos
 * evaluates strings (measured 2026-10-20: "Oops... 'unsafe-eval' is not an
 * allowed source" in its slot) - so eval is let; inline script is not,
 * so no code of a page's own ever runs to call it.
 */
function policy(api) {
  return ["default-src 'self'", "script-src 'self' 'unsafe-eval' 'wasm-unsafe-eval' blob:", "worker-src 'self' blob:",
    "style-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net", "font-src 'self' data: https://cdn.jsdelivr.net",
    "img-src 'self' data: blob:", "media-src 'self' data: blob:", `connect-src 'self' ws: wss: blob: data: ${api}`,
    'frame-src https://www.youtube.com https://www.youtube-nocookie.com', "object-src 'none'", "base-uri 'none'", "form-action 'none'"].join('; ');
}

const UI_CSS = `
  :host { all: initial; }
  * { box-sizing: border-box; font: 14px/1.35 "Cascadia Mono", Consolas, "Courier New", monospace; }
  .corner { position: fixed; right: 10px; bottom: 10px; z-index: 2; display: flex; flex-direction: column; align-items: flex-end; gap: 4px; }
  .main { background: #000; color: #ff5; border: 2px solid #ff5; padding: 5px 10px; cursor: pointer; font-weight: bold; }
  .menu { background: #aaa; color: #000; border: 2px solid #fff; box-shadow: 4px 4px 0 #000; padding: 4px; display: none; }
  .menu.on { display: block; }
  .menu button { display: block; width: 100%; text-align: left; background: none; border: 0; padding: 4px 10px; cursor: pointer; color: #000; }
  .menu button:hover, .menu button:focus { background: #0a0; color: #fff; outline: none; }
  .veil { position: fixed; inset: 0; z-index: 3; background: rgba(0,0,0,.45); display: flex; align-items: center; justify-content: center; }
  .box { background: #aaa; color: #000; border: 2px solid #fff; box-shadow: 6px 6px 0 #000; max-width: min(640px, 92vw); padding: 0 0 12px; }
  .box h2 { margin: 0 0 10px; padding: 3px 10px; background: #fff; color: #00a; text-align: center; font-weight: bold; }
  .box p { margin: 0 16px 12px; white-space: pre-wrap; }
  .box .row { display: flex; gap: 12px; justify-content: flex-end; margin: 0 16px; }
  .box .row button { background: #0a0; color: #fff; border: 0; box-shadow: 3px 3px 0 #000; padding: 4px 16px; cursor: pointer; }
  .box .row button.no { background: #555; }
  .box .row button:focus { outline: 2px solid #ff5; }
`;

/**
 * The page laid over the site: mount() puts one on, unmount() takes it
 * off, peek() steps it aside for the whole site and back. While it is
 * shown, the site's Yes boxes and messages are its own here (ask, tell):
 * the desktop's would be under the page, unseen.
 */
export class HtmlPage {
  constructor(app) {
    this.app = app;
    this.root = null;             // the page's element over the desktop
    this.peeking = false;
    this.rows = new WeakMap();    // a list's row element -> its data, for {field} in its buttons
    this.templates = new WeakMap(); // a list -> its first child, the row it repeats
  }

  get shown() { return !!this.root && !this.peeking; }

  /** The page's slot for a part, while it is shown. */
  slot(name) { return this.shown ? this.root.querySelector(`[data-part="${name}"]`) : null; }

  /** Put on: the clean markup, its styles and CSS, the policy, the site's button; its lists filled, its DOS PC in its slot. */
  async mount(page) {
    this.unmount();
    const p = cleanPage(page.text);
    this.page = page;
    this.policyOn();
    for (const href of p.styles) {
      const l = document.createElement('link');
      Object.assign(l, { rel: 'stylesheet', href, integrity: STYLES[href].integrity, crossOrigin: 'anonymous' });
      l.dataset.wcPage = '';
      document.head.append(l);
    }
    if (p.css) { const s = document.createElement('style'); s.dataset.wcPage = ''; s.textContent = p.css; document.head.append(s); }
    const root = document.createElement('div');
    root.id = 'wc-page';
    root.dataset.owlOwnKeys = '';           // its keys are its own: the desktop's are not pressed under it (owlosui.js)
    root.style.cssText = 'position:fixed;inset:0;z-index:20;overflow:auto;background:#fff;color:#212529';
    root.append(...p.nodes.map(n => document.adoptNode(n)));
    document.body.append(root);
    this.root = root;
    this.wire();
    this.corner();
    this.trip = setInterval(() => this.tripwire(), 1000);
    if (this.slot('dos')) this.dosIn();
    if (this.slot('map')) this.mapIn();
    this.tick();
    // data-every="5": a list or a text read again every so many seconds, 2 at the least - who is here, the network.
    this.timers = [...root.querySelectorAll('[data-every]')].map(el => setInterval(() => {
      if (this.shown) this.app.track(el.hasAttribute('data-list') ? this.fillList(el) : this.fillText(el));
    }, Math.max(2, Number(el.dataset.every) || 5) * 1000));
    for (const part of ['chat', 'terminal']) {
      for (const el of root.querySelectorAll(`[data-part="${part}"]`)) {
        el.textContent = `The ${part} comes to HTML pages next - WIRE CITY (the button in the corner) > Whole site has it now.`;
      }
    }
    await this.fill();
  }

  /** Taken off: its element, its styles, the site's button; the DOS PC back in its window. The policy stays until the page is loaded again. */
  unmount() {
    clearInterval(this.trip);
    for (const t of this.timers ?? []) clearInterval(t);
    this.timers = [];
    cancelAnimationFrame(this.frame);
    this.root?.remove();
    this.root = null;
    this.peeking = false;
    for (const e of document.querySelectorAll('[data-wc-page]')) e.remove();
    this.ui?.remove();
    this.ui = null;
    this.dosOut();
  }

  /** The whole site for a while (on): the page hidden, the button says "Back to my page"; off: the page again. */
  peek(on) {
    if (!this.root || this.peeking === on) return;
    this.peeking = on;
    this.root.style.display = on ? 'none' : '';
    this.app.dos.box.layout();
    this.app.owl.refresh?.();
    this.cornerMenu(false);
    this.cornerLabel();
  }

  // ------------------------------------------------------------ what it shows and does

  wire() {
    for (const el of this.root.querySelectorAll('[data-list]')) {
      this.templates.set(el, el.firstElementChild?.cloneNode(true) ?? null);
      el.replaceChildren();
    }
    this.root.addEventListener('click', e => {
      const run = e.target.closest?.('[data-run]');
      if (run && this.root.contains(run)) { e.preventDefault(); this.app.track(this.run(run)); return; }
      const a = e.target.closest?.('a[href^="https://"]');
      if (a && this.root.contains(a)) { e.preventDefault(); this.app.track(this.leave(a.href)); }
    });
  }

  /** Every list and text again, from the commands that read them. */
  async fill() {
    if (!this.root) return;
    for (const el of this.root.querySelectorAll('[data-list]')) await this.fillList(el);
    for (const el of this.root.querySelectorAll('[data-text]')) await this.fillText(el);
  }

  async fillText(el) {
    const a = await this.query(el.dataset.text);
    if (a) el.textContent = a.lines.map(l => l.text).join('\n');
  }

  async fillList(el) {
    const row = this.templates.get(el);
    const a = row ? await this.query(el.dataset.list) : null;
    if (!a) return;
    el.replaceChildren(...a.data.slice(0, 200).map(d => {
      const r = row.cloneNode(true);
      this.rows.set(r, d);
      for (const f of [r, ...r.querySelectorAll('[data-field]')]) if (f.dataset?.field) f.textContent = String(d[f.dataset.field] ?? '');
      return r;
    }));
  }

  /**
   * A line that reads, run for its data - judged first: a page shows only
   * what reads. Quietly, by the shell itself, not on the bus: what a page
   * shows every few seconds is not a command anybody gave, and would fill
   * the terminal's record. Its buttons go on the bus.
   */
  async query(line) {
    const shell = this.app.readShell(), j = judgeLine(shell, line);
    if (j.problem || j.effect !== 'reads') return null;
    return shell.run(line, { capture: true, from: this.page?.name || 'Your page' });
  }

  /** A button: its line - a row's {field} put in, only as a plain name - run as an INI page's item is (site.js runPageLine). */
  async run(el) {
    let line = el.dataset.run;
    const d = this.rowOf(el);
    try {
      line = line.replace(/\{(\w+)\}/g, (m, f) => {
        const v = String(d?.[f] ?? '');
        if (!SAFE.test(v)) throw new Error(`"${v}" is not a plain name - not put into a command`);
        return v;
      });
    } catch (e) { this.tell(this.page?.name || 'Your page', e.message); return; }
    const owl = this.app.owl, before = owl.active();
    await this.app.runPageLine(line, label(el));
    // A window of the whole site opened (an editor, the commander): the page steps aside, so it is seen.
    const now = owl.active(), slotted = [this.slot('dos') && this.app.dos.win, this.slot('map') && this.app.skymap.win];
    if (now && now !== before && !slotted.includes(now)) this.peek(true);
    await this.fill();
  }

  rowOf(el) {
    for (let e = el; e && e !== this.root; e = e.parentElement) if (this.rows.has(e)) return this.rows.get(e);
    return null;
  }

  /** An https: link: the real address said first, then a tab of its own with nothing of ours. */
  async leave(href) {
    let host = href;
    try { host = new URL(href).host; } catch { /* said as it is */ }
    if (await this.ask(`You are leaving WIRE CITY for\n\n${host}\n\n${href}`, 'A link')) window.open(href, '_blank', 'noopener,noreferrer');
  }

  // ------------------------------------------------------------ the DOS PC in its slot

  /** The picture follows the slot instead of its window, and the PC is switched on. */
  dosIn() {
    const app = this.app, box = app.dos.box;
    if (!box.wcLayout) {
      box.wcLayout = box.layout.bind(box);
      box.layout = () => (app.htmlPage?.layoutDos() ? undefined : box.wcLayout());
    }
    if (!app.dos.box.running) app.track(app.dos.run(app.dos.started || app.dos.settings.start));
  }

  /** The live map in its slot: opened as `sky ROOM` opens it, its picture following the slot, its mouse its own there (skymap.js slotted). */
  mapIn() {
    const app = this.app, map = app.skymap, room = String(this.slot('map').dataset.room ?? '').toLowerCase();
    if (!map.wcLayout) {
      map.wcLayout = map.layout.bind(map);
      map.layout = () => (app.htmlPage?.layoutMap() ? undefined : map.wcLayout());
      map.slotted = () => !!app.htmlPage?.slot('map');
    }
    app.track(this.app.terminal.bus.send(`sky${/^[a-z0-9]{1,16}$/.test(room) ? ` ${room}` : ''}`, { from: this.page?.name || 'Your page' }));
  }

  /** Every frame while a page is on: the pictures over their slots, as the page scrolls. */
  tick() {
    cancelAnimationFrame(this.frame);
    const step = () => {
      if (!this.root) return;
      if (this.slot('dos')) this.app.dos.box.layout();
      if (this.slot('map') && this.app.skymap.win) this.app.skymap.layout();
      this.frame = requestAnimationFrame(step);
    };
    this.frame = requestAnimationFrame(step);
  }

  /** The map over its slot, as layoutDos does the DOS picture: true when it placed it. */
  layoutMap() {
    const slot = this.slot('map'), map = this.app.skymap;
    if (!slot || !map.el || !map.win) return false;
    const r = slot.getBoundingClientRect(), v = this.root.getBoundingClientRect(), dpr = devicePixelRatio || 1;
    map.area = { left: r.left, top: r.top, w: Math.max(1, r.width), h: Math.max(1, r.height) };
    const cut = [Math.max(0, v.top - r.top), Math.max(0, r.right - v.right), Math.max(0, r.bottom - v.bottom), Math.max(0, v.left - r.left)];
    Object.assign(map.el.style, {
      left: `${r.left}px`, top: `${r.top}px`, width: `${map.area.w}px`, height: `${map.area.h}px`, zIndex: '21',
      visibility: r.width > 0 && r.height > 0 ? 'visible' : 'hidden', clipPath: `inset(${cut.map(c => `${c}px`).join(' ')})`,
    });
    const W = Math.round(map.area.w * dpr), H = Math.round(map.area.h * dpr);
    if (map.canvas.width !== W || map.canvas.height !== H) { map.canvas.width = W; map.canvas.height = H; }
    map.canvas.style.width = `${map.area.w}px`;
    map.canvas.style.height = `${map.area.h}px`;
    return true;
  }

  dosOut() { cancelAnimationFrame(this.frame); try { this.app.dos.box.layout(); } catch { /* not running */ } }

  /** Over the slot, clipped to what of it the page shows; true when it placed the picture. */
  layoutDos() {
    const slot = this.slot('dos'), box = this.app.dos.box;
    if (!slot || !box.el) return false;
    const r = slot.getBoundingClientRect(), v = this.root.getBoundingClientRect();
    const area = { x: r.left, y: r.top, w: Math.max(1, r.width), h: Math.max(1, r.height) };
    const cut = [Math.max(0, v.top - r.top), Math.max(0, r.right - v.right), Math.max(0, r.bottom - v.bottom), Math.max(0, v.left - r.left)];
    Object.assign(box.el.style, {
      left: `${area.x}px`, top: `${area.y}px`, width: `${area.w}px`, height: `${area.h}px`, zIndex: '21',
      visibility: r.width > 0 && r.height > 0 ? 'visible' : 'hidden', clipPath: `inset(${cut.map(c => `${c}px`).join(' ')})`,
    });
    const s = box.pictureRect(area);
    Object.assign(box.screenEl.style, { left: `${s.x - area.x}px`, top: `${s.y - area.y}px`, width: `${s.w}px`, height: `${s.h}px` });
    return true;
  }

  // ------------------------------------------------------------ the site's own: the button, the boxes

  /** The WIRE CITY button, in a closed shadow root: the page's CSS does not reach in. */
  corner() {
    const host = document.createElement('div');
    host.id = 'wc-ui';
    host.dataset.owlOwnKeys = '';
    host.style.cssText = 'position:fixed;inset:auto 0 0 auto;z-index:2147483000';
    const sh = host.attachShadow({ mode: 'closed' });
    sh.innerHTML = `<style>${UI_CSS}</style><div class="corner"><div class="menu"></div><button class="main"></button></div>`;
    document.body.append(host);
    this.ui = host;
    this.shadow = sh;
    sh.querySelector('.main').addEventListener('click', () => (this.peeking ? this.peek(false) : this.cornerMenu(!sh.querySelector('.menu.on'))));
    this.cornerLabel();
  }

  cornerLabel() { const b = this.shadow?.querySelector('.main'); if (b) b.textContent = this.peeking ? 'Back to my page' : 'WIRE CITY'; }

  cornerMenu(on) {
    const menu = this.shadow?.querySelector('.menu');
    if (!menu) return;
    menu.classList.toggle('on', on);
    if (!on) return;
    const items = [
      ['The whole site, for a while', () => this.peek(true)],
      ['My pages', () => { this.peek(true); this.app.send('window pages', 'WIRE CITY'); }],
      ['Take my page off', () => this.app.send('page --off', 'WIRE CITY')],
    ];
    menu.replaceChildren(...items.map(([t, act]) => {
      const b = document.createElement('button');
      b.textContent = t;
      b.addEventListener('click', () => { this.cornerMenu(false); act(); });
      return b;
    }));
    menu.querySelector('button')?.focus();
  }

  /** Yes or No, the site's own box over the page; Esc and the default are No. */
  ask(text, title = 'WIRE CITY') { return this.box(title, text, true); }
  tell(title, text) { return this.box(title, text, false); }

  box(title, text, question) {
    if (!this.shadow) return Promise.resolve(false);
    return new Promise(resolve => {
      const veil = document.createElement('div');
      veil.className = 'veil';
      veil.innerHTML = '<div class="box" role="dialog"><h2></h2><p></p><div class="row"></div></div>';
      veil.querySelector('h2').textContent = title;
      veil.querySelector('p').textContent = text;
      const done = v => { veil.remove(); resolve(v); };
      const row = veil.querySelector('.row');
      const button = (t, v, cls = '') => { const b = document.createElement('button'); b.textContent = t; b.className = cls; b.addEventListener('click', () => done(v)); row.append(b); return b; };
      if (question) { button('Yes', true); button('No', false, 'no'); } else button('OK', false);
      veil.addEventListener('keydown', e => { if (e.key === 'Escape') done(false); });
      this.shadow.append(veil);
      (row.querySelector('.no') ?? row.querySelector('button'))?.focus();
    });
  }

  /** The button must be there, seen and uppermost: a page that hides or covers it is taken off (site.js pageTripped). */
  tripwire() {
    if (!this.shown || !this.ui) return;
    const b = this.shadow.querySelector('.main'), r = b.getBoundingClientRect(), cs = getComputedStyle(this.ui);
    const seen = this.ui.isConnected && cs.display !== 'none' && cs.visibility === 'visible' && Number(cs.opacity) > 0.9
      && r.width >= 40 && r.height >= 16 && r.right <= innerWidth + 1 && r.bottom <= innerHeight + 1 && r.left >= 0 && r.top >= 0
      && document.elementFromPoint(r.left + r.width / 2, r.top + r.height / 2) === this.ui;
    if (!seen) this.app.pageTripped('the page hid or covered the WIRE CITY button');
  }

  /** The policy on, once: a page's document keeps it until it is loaded again. */
  policyOn() {
    if (document.querySelector('meta[data-wc-policy]')) return;
    let api = 'https://api.anthropic.com';
    try { api = new URL(JSON.parse(localStorage.getItem('site.ai.1') ?? '{}').api ?? api).origin; } catch { /* the default (ai.js SETTINGS) */ }
    const m = document.createElement('meta');
    m.httpEquiv = 'Content-Security-Policy';
    m.content = policy(api);
    m.dataset.wcPolicy = '';
    document.head.prepend(m);
  }
}
