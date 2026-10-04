// The page's log: everything that happens, from the first moment, kept in
// memory - so that when something goes wrong the question is not "what did
// you do?" but "show me what is in the console" (Tools > Console).
//
// Each line is a time, a source and the words, coloured with ANSI
// sequences: the console window is a terminal and colours them itself, and
// the same text pasted anywhere else reads plainly once they are taken out.
//
// What comes in by itself, once catchThePage() has run:
//   * errors nobody caught, and promises rejected with nobody listening;
//   * console.error, console.warn and console.log - js-dos and the
//     emulator speak there;
//   * every window opened and closed;
//   * where the page is running, said once at the start.
// The tools add what only they know: the DOS PC switching on and off, its
// settings, programs run, the network, files crossing to the floppies -
// and a page anything of its own, with log.info(source, text).

const KEEP = 2000;

const ESC = '\x1b[';
const tone = {
  time: `${ESC}90m`,
  reset: `${ESC}0m`,
  page: `${ESC}36m`,
  window: `${ESC}32m`,
  dos: `${ESC}33m`,
  'dos out': `${ESC}93m`,
  net: `${ESC}35m`,
  files: `${ESC}94m`,
  console: `${ESC}37m`,
  state: `${ESC}97m`,
  error: `${ESC}1;31m`,
  warn: `${ESC}93m`,
};

const pad2 = n => String(n).padStart(2, '0');
const stamp = (d = new Date()) => `${pad2(d.getHours())}:${pad2(d.getMinutes())}:${pad2(d.getSeconds())}.${String(d.getMilliseconds()).padStart(3, '0')}`;

class PageLog {
  constructor() {
    this.lines = [];
    this.listeners = new Set();
  }

  /** One line: `source` is a word (page, window, dos, net, files), `level` info, warn or error. */
  write(source, text, level = 'info') {
    const colour = level === 'error' ? tone.error : level === 'warn' ? tone.warn : (tone[source] ?? tone.page);
    const words = level === 'info' ? text : `${colour}${text}`;
    const line = `${tone.time}${stamp()}${tone.reset} ${colour}${source.padEnd(8)}${tone.reset} ${words}${tone.reset}\n`;
    this.lines.push(line);
    if (this.lines.length > KEEP + KEEP / 8) this.lines.splice(0, this.lines.length - KEEP);
    for (const f of this.listeners) { try { f(line); } catch { /* a listener's own trouble is not the log's */ } }
  }

  info(source, text) { this.write(source, text, 'info'); }
  warn(source, text) { this.write(source, text, 'warn'); }
  error(source, text) { this.write(source, text, 'error'); }

  /** Hear every line from now on; returns how to stop. */
  listen(f) { this.listeners.add(f); return () => this.listeners.delete(f); }

  /** Everything so far, as one text. */
  text() { return this.lines.join(''); }
}

export const log = new PageLog();

/** A value, for a line: errors with their stack, objects as JSON when they will go. */
export function describe(v) {
  if (v instanceof Error) return v.stack && v.stack.includes(v.message) ? v.stack : `${v.name}: ${v.message}${v.stack ? `\n${v.stack}` : ''}`;
  if (typeof v === 'string') return v;
  try { return JSON.stringify(v); } catch { return String(v); }
}

let caught = false;

/**
 * What arrives by itself, once this is called: the page's errors and its
 * console. A page calls it first thing - before the core, before anything
 * can go wrong unseen. Not on import: a library that patched console just
 * by being imported would be doing it to pages that did not ask.
 */
export function catchThePage() {
  if (caught || typeof window === 'undefined') return;
  caught = true;
  window.addEventListener('error', e => {
    const where = e.filename ? ` (${e.filename.replace(location.origin, '')}:${e.lineno}:${e.colno})` : '';
    log.error('error', `${e.error ? describe(e.error) : e.message}${where}`);
  });
  window.addEventListener('unhandledrejection', e => log.error('error', `a promise failed and nobody asked: ${describe(e.reason)}`));
  for (const [name, level] of [['error', 'error'], ['warn', 'warn'], ['log', 'info']]) {
    const original = console[name].bind(console);
    console[name] = (...args) => {
      original(...args);
      // %c and the CSS after it are for the browser's own console.
      let rest = args;
      if (typeof args[0] === 'string' && args[0].includes('%c')) {
        const styles = args[0].split('%c').length - 1;
        rest = [args[0].replace(/%c/g, ''), ...args.slice(1 + styles)];
      }
      log.write('console', rest.map(describe).join(' '), level);
    };
  }
  window.addEventListener('blur', () => log.info('page', 'the page lost the focus'));
  window.addEventListener('focus', () => log.info('page', 'the page has the focus'));
  document.addEventListener('visibilitychange', () => log.info('page', document.hidden ? 'hidden: another tab or the window minimised' : 'visible again'));
  log.info('page', `${location.href}`);
  log.info('page', `${navigator.userAgent}`);
  log.info('page', `screen ${screen.width}x${screen.height}, window ${innerWidth}x${innerHeight}, ` +
    `device pixels ${devicePixelRatio}, ${navigator.hardwareConcurrency ?? '?'} cores` +
    `${navigator.deviceMemory ? `, about ${navigator.deviceMemory} GB` : ''}, language ${navigator.language}`);
  log.info('page', `isolated: ${globalThis.crossOriginIsolated ? 'yes' : 'no'} (DOSBox needs it), ` +
    `SharedArrayBuffer: ${typeof SharedArrayBuffer !== 'undefined' ? 'yes' : 'no'}, ` +
    `service worker: ${navigator.serviceWorker?.controller ? 'in control' : 'none'}`);
  navigator.storage?.estimate?.().then(s => log.info('page', `storage: ${mb(s.usage)} used of ${mb(s.quota)}`), () => {});
  // The heap, now and then, when it has moved: memory that only grows is a leak.
  let heap = 0;
  setInterval(() => {
    const m = performance.memory;
    if (!m) return;
    if (Math.abs(m.usedJSHeapSize - heap) > 16 * 1024 * 1024) {
      heap = m.usedJSHeapSize;
      log.info('page', `memory: ${mb(m.usedJSHeapSize)} in use of ${mb(m.jsHeapSizeLimit)}`);
    }
  }, 30000);
}

export const mb = n => (n == null ? '?' : `${(n / 1048576).toFixed(n < 10 * 1048576 ? 1 : 0)} MB`);

/**
 * Windows opening and closing, by their titles: the toolkit is asked
 * through two calls, and both are heard here.
 */
export function watchWindows(owl) {
  const titles = new Map();
  const open = owl.window.bind(owl), close = owl.close.bind(owl), message = owl.messageBox.bind(owl);
  owl.window = (title, ...rest) => {
    const id = open(title, ...rest);
    titles.set(id, title);
    log.info('window', `#${id} "${title}" opened`);
    return id;
  };
  owl.messageBox = (title, text, ...rest) => {
    const id = message(title, text, ...rest);
    titles.set(id, title);
    log.info('window', `#${id} message "${title}": ${text}`);
    return id;
  };
  owl.close = id => {
    if (titles.has(id)) log.info('window', `#${id} "${titles.get(id)}" closed`);
    titles.delete(id);
    return close(id);
  };
  return titles;
}

