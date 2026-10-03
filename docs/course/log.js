// The page's diary: what the course and the DOS PC did, a line each, and
// every error the page meets. Each line also goes to the browser's
// console; log.lines is there for a test to read.

const now = () => new Date().toTimeString().slice(0, 8);

export const log = {
  lines: [],
  add(level, who, text) {
    const line = `${now()} ${who.padEnd(8)} ${text}`;
    this.lines.push(line);
    if (this.lines.length > 5000) this.lines.splice(0, 1000);
    (level === 'error' ? console.error : level === 'warn' ? console.warn : console.log)(line);
  },
  info(who, text) { this.add('info', who, text); },
  warn(who, text) { this.add('warn', who, text); },
  error(who, text) { this.add('error', who, text); },
};

/** What an error says, in one line, whatever kind of thing was thrown. */
export const describe = e => (e instanceof Error ? `${e.name}: ${e.message}` : String(e));

if (typeof window !== 'undefined') {
  window.addEventListener('error', e => log.error('error', `${describe(e.error ?? e.message)}${e.filename ? ` (${e.filename}:${e.lineno})` : ''}`));
  window.addEventListener('unhandledrejection', e => log.error('error', `unhandled: ${describe(e.reason)}`));
}
