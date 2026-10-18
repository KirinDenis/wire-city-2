// The new WIRE CITY site, in OWLOSUI. MOCKUP, 2026-10-16.
//
// Built ON the course (../course/course.js): one codebase, one DOS machine.
// The course gives the editors, the two commanders, the DOS PC with the
// course disk on A:, every lesson - its source, build, run and video - and
// the site gives its own menu, its drive C: and the DOS window's ways:
//
//   Files     the drives by letter, Map Drives, the two commanders
//   Games     Catalog (what a first visit shows), then each game - started
//             from C:\GAMES\<dir>, where it lies as real files (site/C/,
//             made by ../pack-site.ps1, listed in drive-c.json)
//   Sources   Catalog, then each program whose source is here
//   Lessons   Catalog (the course's list), then the lessons by topic
//   LAN       the network: who is here, chat, shared DOS screens, the monitor
//   Help      last, as always
//
// What is not built yet says, in its hint and in the box it opens, what it
// will do. Plural for the catalogue menus, as Norton's "Left Files Commands
// Options Right". LAN takes N for its key: L is Lessons'.

import { sub, line, Style, Color } from '../owlosui/owlosui.js';
import { DocCm } from '../owlosui/apps/documents.js';
import { DosDrive } from '../owlosui/files/dosdrive.js';
import { DriveGates } from '../owlosui/dosbox/gates.js';
import { unzip } from '../owlosui/dosbox/unzip.js';
import { log } from '../owlosui/apps/log.js';
import { CourseApp, Cm, A } from '../course/course.js';
import { Drive, LocalFolder, crlf, fingerprint, guardRemovals, loadTable, saveTable, keepHandle, handleOf, forgetHandle, freeFolder, statsOf, sizeText, dateText, journalRemovals } from './drives.js';
import { CellTable } from './table.js';
import { Terminal, CmTerminalClose } from '../console/terminal.js';
import { ANSI, RESET } from '../console/shell.js';
import { siteShell } from './console.js';

// Before anything can remove a file: every removal from this browser's
// storage into a journal that outlives a reload (drives.js says why).
journalRemovals();

/** C:, the machine's hard disk, kept in this browser: what DOS writes there is there tomorrow. */
const C_FOLDER = '/DOS C Drive/';
/** D:, this browser's own folder for the visitor's files - OWLOS LAN's /me is the same one. */
const MY_FILES = '/My files/';
/** What the site last put on C:, file by file, to tell the visitor's changes from its own (seedC). */
const SHIPPED_KEY = 'site.c.shipped.1';

/** Map Drives' commands: numbers of the site's own, past its menu's. */
const Mp = {
  Up: 280, Down: 281, PageUp: 282, PageDown: 283, Home: 284, End: 285, Edit: 286, EditOk: 287, EditCancel: 288,
  Close: 290, Add: 291, Remove: 292, Open: 293, AddOk: 294, AddCancel: 295,
};
/** The smallest Map Drives can be made: the four buttons in a row (the pilot asked for about 50 columns), the table's Drive, Kind, Size and Where. */
const MAP_MIN = { w: 56, h: 20 };

/** How many lines a static folds `text` into at `width`: a word that does not fit goes to the next line. */
function wrappedLines(text, width) {
  let lines = 1, used = 0;
  for (const word of text.split(/\s+/)) {
    const need = (used ? 1 : 0) + word.length;
    if (used + need > width) { lines++; used = word.length; } else used += need;
  }
  return lines;
}

/** The kinds Map Drives can add, in its radio buttons' order. */
const ADD_KINDS = [
  ['folder', 'A folder of ~t~his browser - new, or one that is there'],
  ['local', 'A folder on this ~c~omputer (Chrome, Edge)'],
  ['zip', 'A ~Z~IP on this computer - copied into this browser'],
  ['link', 'A ~l~ink to a ZIP - copied into this browser'],
];

/** The most a drive may hold: DOS gets every file of every drive at switch-on, in the page's memory. */
const LIMIT = 256 << 20;

/** How many bytes a folder holds, counted up to `stop` and no further. */
async function sizeOf(source, dir, stop) {
  let total = 0;
  for (const e of await source.list(dir)) {
    total += e.dir ? await sizeOf(source, `${dir}${e.name}/`, stop - total) : e.size;
    if (total > stop) break;
  }
  return total;
}

/** A file of this computer, through the browser's file picker - or null if none was chosen. */
function pickFile(accept) {
  return new Promise(resolve => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = accept;
    input.onchange = () => resolve(input.files?.[0] ?? null);
    input.oncancel = () => resolve(null);
    input.click();
  });
}

// Every item of the site's menu: its command, its label, what it does or
// will do. The command numbers start at 100 - the course's own are 2..38
// and 600..614, OWLOSUI's tools 300..549 - and are given again each time
// the menu is built (once at the start, again when the lessons are in).
let next = 100;
const items = new Map();
function item(label, hint, { title = label.replace(/~/g, '').trim(), shortcut, act } = {}) {
  const cmd = next++;
  items.set(cmd, { title, hint, act });
  return { label, cmd, hint, ...(shortcut ? { shortcut } : {}) };
}

/**
 * The games, in the menu's order: C:\GAMES\<dir>, started by its RUN.BAT.
 * The networked ones join the same sky as their own pages on the relay.
 */
const GAMES = [
  { key: 'owlfly3', name: 'OWL FLY III', dir: 'OWLFLY3', room: 'owlfly3', hint: 'CGA, EGA, VGA and a Hercules edition of the same war; multiplayer' },
  { key: 'owlfly2', name: 'OWL FLY II', dir: 'OWLFLY2', room: 'owlfly2', hint: 'One shared sky over the network, an F-15 cockpit with three MFD pages' },
  { key: 'owlfly', name: 'OWL FLY', dir: 'OWLFLY', hint: 'The combat flight simulator: an island, a city, two air forces' },
  { key: 'trainer', name: 'The Flight School', dir: 'TRAINER', hint: 'Take off, fly the pattern, land: an airfield and a flight model that stalls' },
  { key: 'wirecity', name: 'WIRE CITY', dir: 'WIRECITY', hint: 'Where it started: a wireframe night flight over a city, one source file' },
];

/**
 * The lessons by topic, each in the course's order: all of them do not fit
 * in one menu. A lesson no topic names - a new one - goes under More.
 */
const TOPICS = [
  ['The machine', 'Memory, files, numbers, the keyboard - the PC itself', ['L01', 'L02', 'L04', 'L11']],
  ['Drawing', 'Mode 13h by hand: pixels, lines, a sine table, turns', ['L03', 'L05', 'L05B', 'L06', 'L07', 'L08', 'L09', 'L10', 'L12']],
  ['Into 3D', 'An arm, a cube, perspective, the camera, clipping', ['L13', 'L14', 'L15', 'L16', 'L18', 'L19']],
  ['The ground', 'Diamond-Square, relief, the painter, a town', ['L17', 'L21', 'L22', 'L23']],
  ['Flight', 'How the aeroplane flies: the rules, the forces, the three axes', ['L20', 'L24', 'L25']],
  ['The cockpit', 'Letters, the HUD tapes, the gunsight', ['L26', 'L27', 'L28']],
];

/** A lesson's title, up to its colon or dash: what fits in a menu. */
const shortTitle = t => t.split(/: | - /)[0];

/** A first visit's picture: whole multiples of DOS's pixels, as the course's. */
const SETTINGS_KEY = 'site.dosbox.1';
function siteSettings() {
  try {
    if (!localStorage.getItem(SETTINGS_KEY)) localStorage.setItem(SETTINGS_KEY, JSON.stringify({ picture: 'sharp', always: false }));
  } catch { /* storage refused: the library's defaults */ }
}

/** The sixteen colours of the IBM CGA, as OWLOSUI's screen draws them. */
const CGA = [
  '#000000', '#0000aa', '#00aa00', '#00aaaa', '#aa0000', '#aa00aa', '#aa5500', '#aaaaaa',
  '#555555', '#5555ff', '#55ff55', '#55ffff', '#ff5555', '#ff55ff', '#ffff55', '#ffffff',
];

export class SiteApp extends CourseApp {
  constructor(owl) {
    super(owl);
    this.cycles = null;
    this.extraGates = [];       // DriveGates over folders on this computer: outside the storage the library's gates watch
    // Every folder DOS shares - A: too, which the course keeps already: here
    // it is kept twice, and every removal from it goes in the journal.
    guardRemovals(this.browser, () => this.dos.gates.gates.map(g => g.folder), log);
    this.drives = this.makeDrives();
    this.commanderOnDrives();
    this.gatesForAll();
    this.mountDrives();
    this.frameByStart();
    this.watchMachine();
    // Map Drives laid out again when its corner is let go (watchMapSize).
    this.owl.afterPaint.add(() => this.watchMapSize());
    window.addEventListener('pointerdown', () => { this.mouseDown = true; }, true);
    window.addEventListener('pointerup', () => { this.mouseDown = false; }, true);
    this.buildMenus();          // again: the course's constructor built it before the drives were there
    this.makeTerminal();
  }

  /** The machine's own four: A: and B: floppies, C: the hard disk, D: My files - all kept in this browser. */
  makeDrives() {
    const S = this.browser;
    return [
      new Drive('A', { base: S, root: A, kind: 'floppy', title: 'the course disk', where: `browser ${A}`,
        about: "The lessons, the examples, the games' sources, FASM - kept in this browser" }),
      new Drive('B', { base: S, root: '/DOS B Drive/', kind: 'floppy', title: 'the second floppy', where: 'browser /DOS B Drive/',
        about: 'A floppy in this browser: an installer that asks for disk 2 finds it here' }),
      new Drive('C', { base: S, root: C_FOLDER, kind: 'hard disk', title: 'the games', where: `browser ${C_FOLDER}`,
        about: "The DOS machine's own disk, kept in this browser: C:\\GAMES; what DOS saves there stays" }),
      new Drive('D', { base: S, root: MY_FILES, kind: 'folder', title: 'My files', where: `browser ${MY_FILES}`,
        about: "Your own files, kept in this browser - a clean-up of the site's data loses them" }),
    ];
  }

  /** A drive's path as the storage under it has it: what the course's build and DOS's floppies know. */
  toBase(source, path) {
    return source instanceof Drive && source.base === this.browser ? { source: this.browser, path: source.real(path) } : { source, path };
  }

  /**
   * The web commander over the drive table: Alt+F1 lists the letters. What
   * it hands the course - a file to edit, a program to run, an .ASM to
   * build - goes back to the storage's own path, which the course and DOS
   * know (A:\GAMES is /DOS A Drive/GAMES/); and DOS writing to a floppy
   * reads again the sides that show a drive over it.
   */
  commanderOnDrives() {
    const c = this.commander;
    c.sources = this.drives;       // the same array: a drive added or taken away is in Alt+F1 at once
    const open = c.open, run = c.run, refresh = c.refreshSource.bind(c);
    c.open = (name, text, source, path, options) => { const b = this.toBase(source, path); return open(name, text, b.source, b.path, options); };
    c.run = (source, dir, name) => {
      if (source instanceof Drive && (source.letter === 'C' || source.base instanceof LocalFolder)) return this.runInPlace(source, dir, name);
      const b = this.toBase(source, dir);
      return run(b.source, b.path, name);
    };
    c.associations = Object.fromEntries(Object.entries(c.associations).map(([k, act]) => [k, typeof act !== 'function' ? act : x => {
      const b = this.toBase(x.source, x.dir);
      return act({ ...x, source: b.source, dir: b.path, path: `${b.path}${x.name}` });
    }]));
    c.refreshSource = source => {
      refresh(source);
      if (source === this.browser) for (const d of this.drives) if (d.base === this.browser) refresh(d);
      for (const d of this.drives) if (d.base instanceof LocalFolder) refresh(d);
    };
  }

  /**
   * Enter on a program on C: or on a folder of this computer: the machine
   * on and the program run where it is, in its own folder, as typed at the
   * prompt - not copied to A:\RUN as one from elsewhere is. A networked
   * game's sky first. Kirin Commander for DOS when it ends.
   */
  runInPlace(drive, dir, name) {
    const up = name.toUpperCase();
    const g = drive.letter === 'C' && GAMES.find(x => dir.toUpperCase().startsWith(`/GAMES/${x.dir}/`));
    if (g?.room) this.dos.settings = { ...this.dos.settings, room: g.room };
    const folder = dir.replace(/\/$/, '').replace(/\//g, '\\') || '\\';
    return this.dos.runLines(up, [`${drive.letter}:`, `cd ${folder}`, up.endsWith('.BAT') ? `call ${up}` : up, 'C:', 'cd \\', 'call C:\\COMMANDR.BAT'],
      { network: !!g?.room });
  }

  /**
   * DOS's side of the table. The library mounts A: and B: as floppies and C:
   * as a hard disk; every run of the site's machine begins with C: mounted
   * again as a floppy, and D: and every drive Map Drives added as floppies
   * too - DOSBox reads a floppy afresh each time DOS looks, so what the page
   * puts on any drive DOS sees at once (a hard disk it reads at switch-on
   * only). Seen 2026-10-16: "Drive C has successfully been removed", C:
   * mounted again, OWL FLY III started from it. DOS then counts C:'s free
   * room as a floppy's, 1.4 MB.
   */
  mountLines() {
    const more = this.drives?.filter(d => d.letter > 'D' && this.mounted(d)) ?? [];
    return ['z:', 'mount -u c', 'mount c C -t floppy', 'c:', 'mount d D -t floppy',
      ...more.map(d => `mount ${d.letter.toLowerCase()} ${d.letter} -t floppy`), 'cls'].join('\n');
  }

  /** Whether DOS has the drive: a folder of this computer only once the browser lets the page in. */
  mounted(d) { return !(d.base instanceof LocalFolder) || this.extraGates.some(x => x.letter === d.letter); }

  /** The mounts at the head of every start's line, and of every program's lines (run). */
  mountDrives() {
    const dos = this.dos;
    this.applyMounts();
    const run = dos.run.bind(dos);
    dos.run = (start, opts = {}) => run(start, opts.program ? { ...opts, program: { ...opts.program, line: `${this.mountLines()}\n${opts.program.line}` } } : opts);
  }
  applyMounts() {
    for (const [k, line] of Object.entries(this.baseLines ?? {})) if (this.dos.starts[k]) this.dos.starts[k].line = `${this.mountLines()}\n${line}`;
  }

  /**
   * The library's floppy gates, widened to the table: a drive over a folder
   * of this browser is one more gate of the library's own; a folder on this
   * computer has gates of its own (another storage), whose files go onto
   * the disks at switch-on with the rest, and - only if DOS was let write to
   * it - come back from DOS the same way. The library's README goes only
   * into the machine's own four folders, never into a folder Map Drives
   * added.
   */
  gatesForAll() {
    const g = this.dos.gates;
    const files = g.files.bind(g), started = g.started.bind(g), pull = g.pull.bind(g), ensure = g.ensure.bind(g);
    g.files = async () => [...await files(), ...(await Promise.all(this.extraGates.map(x => x.files()))).flat()];
    g.started = async () => { await started(); for (const x of this.extraGates) await x.started(); };
    g.pull = async () => {
      let got = await pull();
      for (const x of this.extraGates) if (x.writable) got = (await x.pull()) || got;
      return got;
    };
    // The library's README - "this folder is a floppy of the DOS PC" - for
    // A:, B: and D:; C: has its own (the toolkit's, seedC), and a folder
    // Map Drives added has none.
    g.ensure = async () => {
      const all = g.gates;
      g.gates = all.filter(x => 'ABD'.includes(x.letter));
      try { await ensure(); } finally { g.gates = all; }
      for (const x of all) if (!'ABD'.includes(x.letter)) await this.browser.mkdir(x.folder).catch(() => {});
    };
  }

  /** A drive on DOS's side: a gate for it. */
  gateFor(d) {
    const dos = this.dos;
    if (d.base === this.browser) {
      if (!dos.gates.gates.some(x => x.letter === d.letter)) {
        dos.gates.gates.push({ letter: d.letter, folder: d.root, drive: new DosDrive(dos.box, { folder: d.letter, letter: d.letter }) });
      }
      return;
    }
    if (!(d.base instanceof LocalFolder) || this.extraGates.some(x => x.letter === d.letter)) return;
    const x = new DriveGates(dos.box, d.base, [{ letter: d.letter, folder: '/' }]);
    x.letter = d.letter;
    x.writable = !!d.entry?.write;
    x.ensure = async () => {};                 // nothing written into a folder of this computer unasked
    x.activity = letter => dos.light(letter);
    x.pushed = () => dos.floppyChanged();
    this.extraGates.push(x);
    this.applyMounts();
  }

  /** The drives Map Drives added, back from the last visit: words in localStorage, a computer's folder by its handle. */
  async restoreDrives() {
    for (const e of loadTable()) {
      try { await this.addDrive(e, { keep: false }); } catch (err) { log.warn('drives', `${e.letter}: not back - ${err.message}`); }
    }
    this.afterTable();
  }

  /** One drive into the table from its entry: { letter, kind, title, folder?, url?, write? }. */
  async addDrive(e, { keep = true } = {}) {
    const S = this.browser;
    let d;
    if (e.kind === 'local') {
      const handle = e.handle ?? await handleOf(e.letter);
      if (!handle) throw new Error('its folder is not remembered');
      const base = new LocalFolder(handle);
      guardRemovals(base, () => ['/'], log);
      d = new Drive(e.letter, { base, kind: 'computer', title: handle.name, where: `computer ${handle.name}${e.write ? '' : ' (read-only)'}`,
        readOnly: !e.write, entry: e, about: `The folder ${handle.name} on this computer - DOS ${e.write ? 'reads it and writes to it' : 'reads it, never writes'}` });
      if (keep) await keepHandle(e.letter, handle);
      if (await base.permission(false, e.write) === 'granted') this.gateFor(d);
    } else {
      const kind = { folder: 'folder', zip: 'ZIP', link: 'link' }[e.kind];
      const where = e.kind === 'link' ? `browser ${e.folder} - a copy of ${e.url}` : e.kind === 'zip' ? `browser ${e.folder} - a copy of ${e.title}` : `browser ${e.folder}`;
      d = new Drive(e.letter, { base: S, root: e.folder, kind, title: e.title, where, entry: e,
        about: e.kind === 'folder' ? `The folder ${e.folder} of this browser` : `${e.title}, copied into this browser's ${e.folder}` });
      this.gateFor(d);
    }
    this.drives.push(d);
    this.drives.sort((a, b) => a.letter.localeCompare(b.letter));
    if (keep) saveTable([...loadTable().filter(x => x.letter !== e.letter), { ...e, handle: undefined }]);
    return d;
  }

  /** A drive out of the table - its files stay where they are. */
  async removeDrive(d) {
    const dos = this.dos;
    this.drives.splice(this.drives.indexOf(d), 1);
    dos.gates.gates = dos.gates.gates.filter(x => x.letter !== d.letter);
    this.extraGates = this.extraGates.filter(x => x.letter !== d.letter);
    if (d.base instanceof LocalFolder) await forgetHandle(d.letter).catch(() => {});
    saveTable(loadTable().filter(x => x.letter !== d.letter));
    this.afterTable();
  }

  /** After the table changed: the menu, DOS's mounts, Map Drives. */
  afterTable() {
    this.applyMounts();
    this.buildMenus();
    if (this.mapWin && this.owl.place(this.mapWin)) this.showDrives(this.mapRect);   // where and as big as it was
    this.owl.refresh?.();
  }

  /** The first free letter from E:. */
  freeLetter() {
    for (let c = 69; c <= 90; c++) { const l = String.fromCharCode(c); if (!this.drives.some(d => d.letter === l)) return l; }
    return null;
  }

  /** Kirin Commander for Web: `left` on the left and `right` on the right, at those folders. */
  async panels(left, leftDir = '/', right = this.drives[3], rightDir = '/') {
    for (const d of [left, right]) {
      if (d.letter === 'A') await this.installDisk();
      if (d.base instanceof LocalFolder && !this.mounted(d)) {
        // After a reload the browser asks again - this click is the asking.
        if (await d.base.permission(true, d.entry?.write) !== 'granted') throw new Error(`${d.prefix} this computer's folder ${d.title} was not let in.`);
        this.gateFor(d);
        this.afterTable();
      }
    }
    return this.commander.show({ left, right, leftDir, rightDir });
  }

  // ------------------------------------------------------------ Map Drives

  /**
   * Files > Map Drives, worked out with the pilot (2026-10-16):
   *
   *  - the window by the golden section: 61.8% of the screen wide (no
   *    narrower than its table needs), as tall as that over 1.618 in pixels,
   *    its top at 38.2% of the room above and below it - not fitted to the
   *    four drives there are now. Its corner makes it bigger and smaller,
   *    its zoom box whole-screen and back: what is in it is laid out again
   *    WHILE it changes (watchMapSize, layoutDrives), and a window let go
   *    smaller than MAP_MIN goes back to MAP_MIN;
   *  - the table one thing, heads and rows in one frame, single lines
   *    between the columns, a colour a column, the classic bar (CellTable);
   *    a narrower table leaves columns out, the least needed first;
   *  - what each drive IS, not only its name: how many files, how big, when
   *    it last changed - and where its files really are;
   *  - the drive's own buttons - Open, Add, Edit, Remove - in a row a line
   *    under the table, and the window's Close alone at the bottom right:
   *    working on the drives is one thing, leaving the window another. Edit
   *    and Remove are there only for a drive they can do something to - A:
   *    to D: are the machine's own.
   *
   * Keys: Enter opens, Ins adds, F4 edits, Del takes away (its files stay
   * where they are), the arrows, Home, End and the page keys move the bar.
   * rect: where the window goes, if not where the golden section puts it.
   */
  showDrives(rect = null) {
    const owl = this.owl, sc = owl.screen;
    if (this.mapWin && owl.place(this.mapWin)) owl.close(this.mapWin);
    const W = owl.width, H = owl.height;
    let { x, y, w, h } = rect ?? {};
    if (!rect) {
      w = Math.max(100, Math.round(W * 0.618));
      h = Math.round((w * (sc?.cellW ?? 10)) / ((sc?.cellH ?? 22) * 1.618));
    }
    w = Math.min(W, Math.max(MAP_MIN.w, w));
    h = Math.min(H - 2, Math.max(MAP_MIN.h, h));
    if (!rect) { x = Math.floor((W - w) / 2); y = 1 + Math.round((H - 2 - h) * 0.382); }
    // Grey as a dialog, but its size the person's: the core's FIXED bit
    // (0x02) and NO_ZOOM bit (0x04) taken off - the corner to drag, and the
    // zoom box to make it the whole screen and back.
    this.mapWin = owl.window('Map Drives', w, h, { x, y, style: Style.Dialog & ~0x06, closeCmd: Mp.Close });
    this.mapRect = { x, y, w, h };
    this.mapViews = [];
    this.mapButtons = { y: 0, rows: {} };
    this.layoutDrives();
    this.track(this.countDrives());
  }

  /**
   * What is in Map Drives, for the size it has now - made again whenever
   * that changes, inside the same window, so a drag of its corner goes on.
   * Inside: a margin of two columns and a row; the table, the whole width;
   * a line under it, on the left, the drive's own buttons; under them the
   * words, as many lines as they need at this width; at the bottom right,
   * alone, Close. Below MAP_MIN the views keep MAP_MIN's size, and the
   * window cuts them until it is let go.
   */
  layoutDrives() {
    const owl = this.owl, win = this.mapWin, p = win && owl.place(win);
    if (!p) return;
    const keep = this.mapTable?.current ?? 0;
    for (const id of [...this.mapViews, ...Object.values(this.mapButtons.rows)]) owl.close(id);
    this.mapViews = [];
    this.mapButtons.rows = {};
    const w = Math.max(MAP_MIN.w, p.w + 2), h = Math.max(MAP_MIN.h, p.h + 2);
    this.mapSize = { w: p.w + 2, h: p.h + 2 };
    const hint = 'Enter opens a drive in Kirin Commander for Web; Ins adds one, F4 edits it, Del takes it away ' +
      '- its files stay. One table for the menu, both commanders and DOS: DOS sees a change at its next switch-on.';
    // A static folds a column short of its width: counted at w - 7, it came out right at 56 and at 106.
    const hr = wrappedLines(hint, w - 7);
    // A free line between the words and Close: the table gives it up (the pilot - Close stays where it is).
    const tw = w - 2 - 4, th = Math.max(6, h - 10 - hr);
    this.mapTable = new CellTable(owl, win, {
      x: 2, y: 1, w: tw, h: th,
      columns: [
        { head: 'Drive', width: 7, colour: Color.White },
        { head: 'Kind', width: 11, colour: Color.Yellow, drop: 2 },
        { head: 'What', width: 22, colour: Color.White, drop: 3 },
        { head: 'Files', width: 7, align: 'right', colour: Color.LightGreen, drop: 4 },
        { head: 'Size', width: 9, align: 'right', colour: Color.LightGreen, drop: 1 },
        { head: 'Changed', width: 13, colour: Color.White, drop: 5 },
        { head: 'Where', width: 0, colour: Color.LightCyan },
      ],
      rows: this.driveRows(),
      onOpen: () => this.onCommand(Mp.Open),
      onSelect: () => this.driveButtons(),
    });
    this.mapViews.push(this.mapTable.canvas);
    this.mapButtons.y = 1 + th + 1;
    this.mapViews.push(owl.staticText(win, 2, 1 + th + 4, hint, w - 6, hr));
    // By hand, not owl.buttons: a dialog's own row makes its first button the
    // default, and Enter must open the drive, not close the window. Esc closes.
    this.mapViews.push(owl.buttonRow(win, w - 2 - 2 - 10, h - 2 - 2, [{ label: 'Close', cmd: Mp.Close, cancel: true }]));
    this.mapTable.select(keep);           // and with it the drive's buttons and keys
  }

  /**
   * The drive's own buttons for the drive in the bar: Open and Add always;
   * Edit and Remove only where they can do something - shown and taken away
   * as the bar moves, and the status line's keys with them.
   */
  driveButtons() {
    const owl = this.owl, b = this.mapButtons, win = this.mapWin;
    if (!b || !win || !owl.place(win)) return;
    const d = this.selectedDrive(), own = !d || 'ABCD'.includes(d.letter);
    const slots = [
      ['open', '~O~pen', Mp.Open, true, true],
      ['add', '~A~dd...', Mp.Add, false, true],
      ['edit', '~E~dit...', Mp.Edit, false, !own],
      ['remove', '~R~emove', Mp.Remove, false, !own],
    ];
    // Each button where it always is - a hidden one leaves its place - with
    // the same gap after each: its words, the padding and shadow, two cells.
    let x = 2;
    for (const [key, label, cmd, dflt, shown] of slots) {
      const at = b.rows[key];
      if (shown && !at) b.rows[key] = owl.buttonRow(win, x, b.y, [{ label, cmd, default: dflt }]);
      if (!shown && at) { owl.close(at); delete b.rows[key]; }
      x += label.replace(/~/g, '').length + 4 + 1 + 2;
    }
    owl.windowStatus(win,
      { label: '~Enter~ Open', cmd: Mp.Open, key: 'Enter' },
      { label: '~Ins~ Add', cmd: Mp.Add, key: 'Insert' },
      ...(own ? [] : [{ label: '~F4~ Edit', cmd: Mp.Edit, key: 'F4' }, { label: '~Del~ Remove', cmd: Mp.Remove, key: 'Delete' }]),
      { label: '', cmd: Mp.Up, key: 'ArrowUp' }, { label: '', cmd: Mp.Down, key: 'ArrowDown' },
      { label: '', cmd: Mp.PageUp, key: 'PageUp' }, { label: '', cmd: Mp.PageDown, key: 'PageDown' },
      { label: '', cmd: Mp.Home, key: 'Home' }, { label: '', cmd: Mp.End, key: 'End' });
    owl.refresh?.();
  }

  /**
   * After every paint: whether Map Drives changed its size - its corner, its
   * zoom box, Ctrl+F5. Laid out again at once, not after the paint it was
   * heard in. Let go smaller than MAP_MIN - the core lets a window go down
   * to 6 by 3 - it is made again at MAP_MIN, where it stood.
   */
  watchMapSize() {
    const owl = this.owl, win = this.mapWin;
    const p = win && owl.place(win);
    if (!p || !this.mapSize) return;
    const now = { x: p.x - 1, y: p.y - 1, w: p.w + 2, h: p.h + 2 };
    this.mapRect = now;
    if (now.w !== this.mapSize.w || now.h !== this.mapSize.h) {
      this.mapSize = { w: now.w, h: now.h };
      setTimeout(() => { if (this.mapWin === win) { this.layoutDrives(); owl.refresh?.(); } });
    }
    if (now.w >= MAP_MIN.w && now.h >= MAP_MIN.h) return;
    clearTimeout(this.mapResize);
    this.mapResize = setTimeout(() => {
      const q = this.mapWin === win && owl.place(win);
      if (!q) return;
      if (this.mouseDown) { this.watchMapSize(); return; }
      if (q.w + 2 < MAP_MIN.w || q.h + 2 < MAP_MIN.h) this.showDrives({ x: q.x - 1, y: q.y - 1, w: q.w + 2, h: q.h + 2 });
    }, 250);
  }

  /** The table's rows: a drive each - what it is, what it holds, where its files are. */
  driveRows() {
    return this.drives.map(d => {
      const s = this.driveStats?.get(d.letter);
      const counted = s && s !== 'asks';
      return [d.prefix, d.kind, d.title,
        counted ? String(s.files) : s === 'asks' ? 'asks' : '...',
        counted ? sizeText(s.bytes) : '',
        counted ? dateText(s.newest) : '',
        d.where];
    });
  }

  /** Every drive counted - files, bytes, the newest change - and the table shown again as each is done. */
  async countDrives() {
    this.driveStats ??= new Map();
    for (const d of [...this.drives]) {
      try {
        if (d.base instanceof LocalFolder && !this.mounted(d)) this.driveStats.set(d.letter, 'asks');
        else this.driveStats.set(d.letter, await statsOf(d));
      } catch { this.driveStats.delete(d.letter); }
      if (this.mapTable && this.mapWin && this.owl.place(this.mapWin)) this.mapTable.setRows(this.driveRows());
    }
  }

  selectedDrive() { return this.mapTable ? this.drives[this.mapTable.current] : null; }

  /**
   * F4 in Map Drives: a drive's letter and what it is called - and for a
   * folder on this computer whether DOS may write to it. A: to D: are the
   * machine's own and stay as they are.
   */
  showEdit() {
    const owl = this.owl, d = this.selectedDrive();
    if (!d) return;
    if ('ABCD'.includes(d.letter)) { this.tell('Map Drives', `${d.prefix} is one of the machine's own four: A: to D: stay as they are.`); return; }
    if (this.editWin && owl.place(this.editWin)) owl.close(this.editWin);
    const local = d.base instanceof LocalFolder;
    const win = this.editWin = owl.window(`Edit drive ${d.prefix}`, 66, local ? 14 : 12, { style: Style.ModalDialog, closeCmd: Mp.EditCancel });
    this.editing = { d };
    owl.staticText(win, 2, 1, `Where: ${d.where}`, 60, 2);
    this.editing.letter = owl.input(win, 2, 4, 20, 'Letter:', d.letter, 1);
    this.editing.title = owl.input(win, 2, 6, 60, 'Name:', d.title, 60);
    if (local) this.editing.write = owl.cluster(win, 2, 8, 60, ['DOS may ~w~rite to it'], { on: [!!d.entry?.write] });
    owl.buttons(win, { label: '~O~K', cmd: Mp.EditOk, default: true }, { label: 'Cancel', cmd: Mp.EditCancel, cancel: true });
  }

  closeEdit() { if (this.editWin && this.owl.place(this.editWin)) this.owl.close(this.editWin); this.editWin = 0; }

  /** OK in Edit: the drive out of the table and in again, under its new letter and name - its files where they were. */
  async editFromDialog() {
    const owl = this.owl, ed = this.editing, d = ed.d;
    const letter = owl.getText(ed.letter).trim().toUpperCase();
    const title = owl.getText(ed.title).trim() || d.title;
    const write = ed.write ? owl.clusterState(ed.write).on[0] : d.entry?.write;
    this.closeEdit();
    if (!/^[E-Z]$/.test(letter)) throw new Error('A drive Map Drives adds takes a letter from E to Z.');
    if (letter !== d.letter && this.drives.some(x => x.letter === letter)) throw new Error(`${letter}: is taken.`);
    const e = { ...d.entry, letter, title, write };
    if (d.base instanceof LocalFolder) e.handle = d.base.handle;
    await this.removeDrive(d);
    await this.addDrive(e);
    this.afterTable();
    this.mapTable?.select(this.drives.findIndex(x => x.letter === letter));
  }

  /** Ins in Map Drives: what the new drive is - a folder of this browser, of this computer, a ZIP, a link. */
  showAdd() {
    const owl = this.owl, letter = this.freeLetter();
    if (!letter) { this.tell('Map Drives', 'Every letter from E: to Z: is taken.'); return; }
    if (this.addWin && owl.place(this.addWin)) owl.close(this.addWin);
    const win = this.addWin = owl.window(`Add drive ${letter}:`, 70, 19, { style: Style.ModalDialog, closeCmd: Mp.AddCancel });
    this.adding = { letter };
    owl.staticText(win, 2, 1, `The new drive is ${letter}: - what is on it?`, 64);
    this.adding.kind = owl.cluster(win, 2, 3, 64, ADD_KINDS.map(([, label]) => label), { single: true, on: 0 });
    // Two fields, each one thing: what the drive is called, and - for a
    // link only - the link. (An input's label has no ~key~ of its own.)
    owl.staticText(win, 2, 8, 'Name - a folder of this browser is made under it; left empty, the drive is called by what it is:', 64, 2);
    this.adding.name = owl.input(win, 2, 10, 64, 'Name:', '', 60);
    this.adding.link = owl.input(win, 2, 12, 64, 'Link:', '', 400);
    this.adding.write = owl.cluster(win, 2, 14, 64, ['DOS may ~w~rite to it - a folder on this computer'], { on: [false] });
    owl.buttons(win, { label: '~O~K', cmd: Mp.AddOk, default: true }, { label: 'Cancel', cmd: Mp.AddCancel, cancel: true });
  }

  closeAdd() { if (this.addWin && this.owl.place(this.addWin)) this.owl.close(this.addWin); this.addWin = 0; }

  /**
   * OK in Add: the drive made and put in the table. A folder of this
   * browser is made if it is not there; a folder of this computer comes
   * from the browser's folder picker; a ZIP from its file picker; a link is
   * fetched - a site that does not let pages take its files says no, and
   * then the ZIP downloaded and added as a ZIP does it.
   */
  async addFromDialog() {
    const owl = this.owl, a = this.adding;
    const kind = ADD_KINDS[Math.max(0, owl.clusterState(a.kind).on.indexOf(true))][0];
    const name = owl.getText(a.name).trim().replace(/[\\/:*?"<>|]/g, ' ').trim();
    const link = owl.getText(a.link).trim();
    const write = owl.clusterState(a.write).on[0];
    this.closeAdd();
    const S = this.browser, letter = a.letter;
    if (kind === 'folder') {
      const title = name || `Drive ${letter}`;
      const folder = `/${title}/`;
      await S.mkdir(folder);
      await this.addDrive({ letter, kind, title, folder });
    } else if (kind === 'local') {
      if (!globalThis.showDirectoryPicker) throw new Error('This browser cannot give a page a folder of this computer: Chrome and Edge can.');
      const handle = await showDirectoryPicker({ mode: write ? 'readwrite' : 'read' });
      const total = await sizeOf(new LocalFolder(handle), '/', LIMIT);
      if (total > LIMIT) throw new Error(`${handle.name} holds more than ${LIMIT >> 20} MB: DOS gets every file of a drive at switch-on. A smaller folder, please.`);
      await this.addDrive({ letter, kind, title: name || handle.name, write, handle });
    } else if (kind === 'zip') {
      const file = await pickFile('.zip');
      if (!file) return;
      if (file.size > LIMIT) throw new Error(`${file.name} is bigger than ${LIMIT >> 20} MB.`);
      await this.addZip(letter, { kind, title: name || file.name }, new Uint8Array(await file.arrayBuffer()));
    } else {
      if (!/^https?:\/\//i.test(link)) throw new Error('A link begins with https:// - type it in the Link box, then OK.');
      let r;
      try { r = await fetch(link); } catch {
        throw new Error('That site does not let a page take its files. Download the ZIP, then add it as a ZIP on this computer.');
      }
      if (!r.ok) throw new Error(`${link}: ${r.status} ${r.statusText}`);
      const bytes = new Uint8Array(await r.arrayBuffer());
      await this.addZip(letter, { kind, title: name || decodeURIComponent(link.split(/[?#]/)[0].split('/').pop() || 'link'), url: link }, bytes);
    }
    this.afterTable();
  }

  /** A ZIP's files into a new folder of this browser, and the folder as a drive. */
  async addZip(letter, e, bytes) {
    const S = this.browser;
    const files = (await unzip(bytes)).filter(f => !f.path.endsWith('/'));
    if (!files.length) throw new Error(`${e.title} has no files in it - is it a ZIP?`);
    const folder = await freeFolder(S, e.title);
    await S.hush(async () => { for (const f of files) await S.write(`${folder}${f.path}`, f.contents); });
    log.info('drives', `${letter}: ${files.length} files of ${e.title} into ${folder}`);
    await this.addDrive({ letter, ...e, folder });
  }

  /**
   * The course's DOS PC, with the site's starts: the course's commander -
   * Kirin Commander for DOS - and the five games from C:\GAMES, each into
   * its folder, RUN, and back to the commander when it ends. The lines get
   * the table's mounts at their head (applyMounts). C: is a folder of this
   * browser, filled by seedC: the course's bundles are not used.
   */
  dosOptions() {
    siteSettings();
    const o = super.dosOptions();
    this.baseLines = {
      prompt: '',
      commander: o.starts.commander.line,
      ...Object.fromEntries(GAMES.map(g => [g.key, `C:\ncd \\GAMES\\${g.dir}\ncall RUN.BAT\ncd \\\ncall C:\\COMMANDR.BAT`])),
    };
    return {
      ...o,
      settingsKey: SETTINGS_KEY,
      // The library's two floppies, C: and D: - all four kept in this browser.
      floppies: [{ letter: 'A', folder: A }, { letter: 'B', folder: '/DOS B Drive/' }, { letter: 'C', folder: C_FOLDER }, { letter: 'D', folder: MY_FILES }],
      starts: {
        prompt: { name: 'the DOS prompt', line: '' },
        commander: { ...o.starts.commander, label: '~K~irin Commander for DOS', frame: 'blue' },
        ...Object.fromEntries(GAMES.map(g => [g.key, { name: g.name, hint: g.hint, network: !!g.room, frame: 'black', line: this.baseLines[g.key] }])),
      },
    };
  }

  /** Drive C: filled: the games, the toolkit and the batch files, before the PC's first switch-on. */
  async findGames() {
    const list = await (await fetch(new URL('drive-c.json', import.meta.url))).json();
    log.info('site', `drive C: ${list.files.length} files, ${list.source} (${Object.values(list.from).join(', ')})`);
    this.dos.bundles = [];
    await this.seedC(list);
  }

  /**
   * What the site puts on C: - the games' files (drive-c.json), the
   * library's toolkit and batch files - into C:'s folder, without undoing
   * what the visitor did there. What the site put last time is remembered
   * by its fingerprint: a file still as the site left it gets the new one;
   * a file the visitor changed is kept; a file the visitor deleted stays
   * deleted. A release the site has seen already is not fetched again.
   */
  async seedC(list) {
    const S = this.browser;
    let was = null;
    try { was = JSON.parse(localStorage.getItem(SHIPPED_KEY) ?? 'null'); } catch { /* none */ }
    const first = !was;
    was ??= { release: null, files: {} };
    const sameRelease = was.release === list.made;
    const now = { release: list.made, files: {} };
    const files = [
      ...list.files.map(f => ({ path: f.path, url: new URL(`C/${f.path}`, import.meta.url).href })),
      ...this.dos.diskList.map(([path, url]) => ({ path, url })),
      ...Object.entries(this.dos.written).filter(([p]) => p.startsWith('C/')).map(([p, text]) => ({ path: p.slice(2), bytes: new TextEncoder().encode(crlf(text)) })),
    ];
    let put = 0;
    await S.hush(async () => {
      for (const f of files) {
        const at = `${C_FOLDER}${f.path}`;
        const have = await S.readBytes(at).catch(() => null);
        const mine = was.files[f.path];
        // The library's floppy README, written into C:'s folder before the
        // site kept it out (2026-10-16): the library's words, not the visitor's.
        const gates = have && f.path === 'README.TXT' && new TextDecoder().decode(have.slice(0, 64)).startsWith('This folder is drive C:');
        if (!have && !first && mine !== undefined) continue;                       // the visitor deleted it
        if (have && !first && !gates && mine !== undefined && fingerprint(have) !== mine) {  // the visitor changed it
          now.files[f.path] = mine;
          continue;
        }
        if (have && sameRelease && !f.bytes) { now.files[f.path] = fingerprint(have); continue; }
        const bytes = f.bytes ?? new Uint8Array(await (await fetch(f.url)).arrayBuffer());
        if (!have || fingerprint(have) !== fingerprint(bytes)) { await S.write(at, bytes); put++; }
        now.files[f.path] = fingerprint(bytes);
      }
    });
    try { localStorage.setItem(SHIPPED_KEY, JSON.stringify(now)); } catch { /* a private window */ }
    log.info('site', `C: ${put} files put in ${C_FOLDER}${first ? ' (the first visit)' : ''}`);
  }

  /**
   * The course's list and the games' files; the menu again, now with the
   * lessons in it. Unlike the course, nothing opens by itself, and the
   * course disk goes onto A: only when a lesson first needs it.
   */
  async start() {
    this.course = await (await fetch(new URL('../course/course.json', import.meta.url))).json();
    this.sources = await (await fetch(new URL('sources.json', import.meta.url))).json();
    log.info('site', `${this.course.lessons.length} lessons, ${this.sources.games.length + this.sources.examples.length} sources`);
    await this.findGames();
    // Not from the constructor: the table's change repaints the screen, and
    // OWLOSUI cannot paint before the page's program is made.
    await this.restoreDrives();
    this.ready = true;
    await this.waitForScreen();
    this.buildMenus();
    this.owl.refresh?.();
  }

  async openLesson(lesson) {
    await this.installDisk();
    return super.openLesson(lesson);
  }

  /**
   * The Sources menu: every program whose source is on the course disk, A: -
   * each game, the examples, the engine (sources.json, from their .INFs).
   * An item puts the source in an editor; F9 builds what is in front, as in
   * the course: a game by its own MAKE.BAT, an example by FASM, and runs it.
   */
  sourcesMenu() {
    const s = this.sources ?? { games: [], examples: [] };
    const a = this.drives?.[0];
    return [
      item('~C~atalog...', 'Every program whose source is here, in the commander: the games on the left, the examples on the right',
        { title: 'Sources', act: () => this.track(this.panels(a, '/GAMES/', a, '/EXAMPLES/')) }),
      line(),
      ...s.games.map((g, i) => item(`~${i + 1}~ ${GAMES.find(x => x.dir === g.dir)?.name ?? g.dir}`, `${g.main.replace(/\//g, '\\')}: ${g.what}`,
        { title: g.title, act: () => this.track(this.openSource(g.main)) })),
      line(),
      sub('~E~xamples', ...s.examples.map(e => item(shortTitle(e.title), `${e.main.replace(/\//g, '\\')}: ${e.what}`,
        { title: e.title, act: () => this.track(this.openSource(e.main)) }))),
      item('The e~n~gine', 'The modules every game and lesson is built from: A:\\ENGINE, in the commander',
        { act: () => this.track(this.panels(a, '/ENGINE/', a, '/')) }),
    ];
  }

  /** A source from the course disk in an editor - the one already open, if it is. */
  async openSource(main) {
    await this.installDisk();
    const path = `${A}${main}`;
    const open = [...this.docs].find(([, d]) => d.path === path);
    if (open) { this.owl.activate(open[0]); return; }
    this.documents.add(main.split('/').pop(), await this.browser.read(path), this.browser, path);
  }

  /** The Lessons menu: the course's list, then a submenu a topic. */
  lessonsMenu() {
    const lessons = this.course?.lessons ?? [];
    const byId = new Map(lessons.map(l => [l.id, l]));
    const named = new Set(TOPICS.flatMap(([, , ids]) => ids));
    const topics = [...TOPICS, ['More', 'Lessons newer than this menu', lessons.filter(l => !named.has(l.id)).map(l => l.id)]];
    const lessonItem = l => item(`${l.lecture.padEnd(3)}${shortTitle(l.title)}`, l.title,
      { title: `Lesson ${l.lecture}`, act: () => this.track(this.openLesson(l)) });
    return [
      item('~C~atalog...', 'Every lesson: its video, its source, and a DOS machine that builds and runs it',
        { title: 'Lessons', shortcut: 'F1', act: () => this.list.show() }),
      line(),
      ...topics.map(([name, hint, ids]) => ({ name, hint, list: ids.map(id => byId.get(id)).filter(Boolean) }))
        .filter(t => t.list.length)
        .map((t, i) => ({ ...sub(`~${i + 1}~ ${t.name}`, ...t.list.map(lessonItem)), hint: t.hint })),
    ];
  }

  /** The site's menu bar and status line, over the course's. */
  buildMenus() {
    const owl = this.owl;
    next = 100;
    items.clear();
    const about = item('~A~bout WIRE CITY 86', 'What this site is', {
      act: () => this.tell('WIRE CITY 86', 'A DOS machine in your browser, with real files: our games, their sources, and the lessons ' +
        'that teach how they are made. A mockup: Games and Lessons work, every other item says what it will do.'),
    });
    const catalog = item('~C~atalog...', 'Every game, with a short video: Enter plays', { title: 'Games Catalog', shortcut: 'F3' });
    this.helpCmd = about.cmd;
    this.catalogCmd = catalog.cmd;

    owl.menuBar(
      sub('~F~iles',
        item('~M~ap Drives...', 'Which letter is where: one table for this menu, both commanders and DOS',
          { act: () => this.showDrives() }),
        line(),
        // The table, a letter a line: Enter opens the drive in the web commander.
        // A: to D: carry their letter as the key; the rest would take the other items' keys (K, L, M, P, T, W).
        ...(this.drives ?? []).map(d => item(`${'ABCD'.includes(d.letter) ? `~${d.letter}~` : d.letter}:  ${d.kind} - ${d.title}` +
          (this.mounted(d) ? '' : ' (asks to be let in)'), d.about,
          { title: `Drive ${d.prefix}`, act: () => this.track(this.panels(d, '/', d === this.drives[3] ? this.drives[0] : this.drives[3])) })),
        line(),
        item('~K~irin Commander for DOS', 'The file manager in DOS, on the same drives: Alt+F1, Alt+F2 pick a drive',
          { act: () => this.track(this.dos.run('commander')) }),
        item('Kirin Commander for ~W~eb', 'The same two panels in the page, over the same drives: A: on the left, D: on the right',
          { act: () => this.track(this.panels(this.drives[0])) }),
        item('~T~erminal', 'The console: the same drives as /mnt/a, /mnt/c, and what every window does', { shortcut: 'Ctrl+`', act: () => this.terminal?.toggle() }),
        line(),
        item('Save ~p~rofile...', 'Your drives and settings as a list of commands, in a file on your computer'),
        item('~L~oad profile...', 'Put a saved profile back: the drives come back with their letters')),
      sub('~G~ames',
        catalog,
        line(),
        ...GAMES.map((g, i) => item(`~${i + 1}~ ${g.name}`, g.hint, { title: g.name, act: () => this.play(g) }))),
      sub('~S~ources', ...this.sourcesMenu()),
      sub('~L~essons', ...this.lessonsMenu()),
      sub('LA~N~',
        item('~W~ho is online', 'Who else is here now, and what they are doing'),
        item('~C~hat', 'Talk to everyone here, the IRC way: channels, nicks, /join, /me'),
        item('~S~creens', 'DOS screens people share: watch a game being played'),
        item('~M~onitor', 'The network as it is: the relay, the delay, what is lost')),
      sub('~H~elp',
        item('~D~rives and letters', 'How the drives work: a letter, where its files are, who sees them'),
        item('~K~eys', 'Every key of the site'),
        line(),
        about),
    );
    owl.statusLine(
      { label: '~F1~ Lessons', cmd: Cm.Lessons, key: 'F1' },
      { label: '~F2~ Save', cmd: DocCm.Save, key: 'F2' },
      { label: '~F3~ Games', cmd: this.catalogCmd, key: 'F3' },
      { label: '~F9~ Build+run', cmd: Cm.Build, key: 'F9' },
      { label: '~F5~ Zoom', cmd: Cm.Zoom, key: 'F5' },
      { label: '~Alt-F3~ Close', cmd: Cm.Close, key: 'F3', alt: true },
    );
  }

  /**
   * The DOS window's frame in the colour of what runs in it (the pilot,
   * 2026-10-16): a game or a lesson's program is a black screen, and a blue
   * frame round it puzzles - black, as a monitor's case round its glass. A
   * file manager is a blue screen, and blue round it is right: a start says
   * `frame: 'blue'`. A window's style is fixed when it is made, so the
   * library's openWindow() is given it - its owl.window() call gets the
   * style - and a start in the other colour opens the window anew.
   */
  frameByStart() {
    const dos = this.dos, owl = this.owl;
    const styleOf = (start, program) => (!program && dos.starts[start]?.frame === 'blue' ? Style.Document : Style.Terminal);
    let style = null;
    const open = dos.openWindow.bind(dos);
    dos.openWindow = rect => {
      style = styleOf(dos.started, dos.program);
      const make = owl.window;
      owl.window = (title, w, h, opts = {}) => make.call(owl, title, w, h, { ...opts, style });
      try { return open(rect); } finally { owl.window = make; }
    };
    const run = dos.run.bind(dos);
    dos.run = (start, opts = {}) => {
      if (dos.win && styleOf(dos.starts[start] ? start : 'prompt', opts.program) !== style) { owl.close(dos.win); dos.win = 0; }
      return run(start, opts);
    };
  }

  /**
   * The machine's state on the bottom of the DOS window's frame, the pilot's
   * way: ===[3001 cyc]=[☼]=[↕]=─┘ at the right corner - the speed, awake,
   * the network - signs rather than words, each in brackets of the frame's own
   * white, tight round it, in a place of its own width, so nothing moves when
   * a number changes. Cycles are the speed the machine really runs at, in
   * DOSBox's own word - a millisecond's worth, measured from the emulator's
   * counter as the machine monitor does. Once a second while it runs.
   *
   * The library has no words for a frame's bottom: the line is drawn on the
   * canvas after every paint, and only over cells that still show this
   * window's own frame - a menu or a window over it keeps its place. [awake],
   * which the library puts after the title, moves down with the rest.
   * Both belong in OWLOSUI's DosTool, if its author agrees.
   */
  watchMachine() {
    const dos = this.dos, owl = this.owl;
    // The library's retitle(), as it is but for its [awake] tag: set and
    // painted there, then taken away here, the tag flickered once a second.
    dos.retitle = () => {
      if (!dos.win) return;
      const name = dos.program?.name ?? dos.starts[dos.started]?.name ?? 'DOS';
      const state = dos.box.crashed ? ' (crashed)' : !dos.box.running ? ' (off)' : dos.box.hasKeys() ? ' - keys in DOS' : '';
      owl.setText(dos.win, `DOS: ${name}${state}`);
      owl.windowTag(dos.win, '');
      owl.refresh?.();
    };
    owl.afterPaint.add(() => this.drawMachineLine());
    let last = null;
    setInterval(async () => {
      if (!dos.box.running || dos.box.crashed) { last = null; this.cycles = null; return; }
      const stats = await dos.box.stats().catch(() => null);
      if (stats) {
        const now = performance.now();
        if (last) this.cycles = Math.round(((stats.cycles - last.cycles) >>> 0) / (now - last.at));
        last = { cycles: stats.cycles, at: now };
      }
      dos.retitle();
    }, 1000);
  }

  /**
   * The fields of the machine's line: [text, colour, width]. The brackets
   * hold the text tight; the width is the field's place on the frame, its
   * longest text, and what the text leaves of it stays frame, on its left:
   * the speed comes first and grows leftwards, and every field is one cell
   * of frame from the next (the pilot, 2026-10-16). The signs are CP437's, as the
   * window's own boxes are: ☼ awake (grey: it pauses when hidden), ↕ the
   * network - green on, yellow connecting, red failed, grey off.
   */
  machineFields() {
    const dos = this.dos, s = dos.network.state;
    const awake = ['☼', dos.box.keepRunning ? CGA[10] : CGA[7], 1];
    const net = ['↕', s === 'connected' ? CGA[10] : s === 'connecting' ? CGA[14] : s.startsWith('not connected') ? CGA[12] : CGA[7], 1];
    const cpu = [this.cycles === null ? '- cyc' : `${this.cycles} cyc`, CGA[14], '999999 cyc'.length];
    return [cpu, awake, net];
  }

  /** The machine's line, over the bottom of the DOS window's frame: after every paint. */
  drawMachineLine() {
    const dos = this.dos, owl = this.owl, sc = owl.screen;
    if (!dos?.win || !dos.box.running || !sc) return;
    const p = owl.place(dos.win);
    if (!p) return;
    const f = owl.frame();
    const y = p.y + p.h, left = p.x - 1, right = p.x + p.w;
    // The window's own bottom-left corner, or the bottom is not this
    // window's to write on: off the screen, or under something.
    if (y >= f.h || !'╚└'.includes(f.char(left, y))) return;
    const frameAttr = f.attr(left, y);
    const { ctx, cellW: cw, cellH: ch } = sc;
    ctx.font = sc.font;
    // From the right corner leftwards: its ─┘ is the size grip, one cell of
    // frame before it, and the fields end there. A window too narrow for
    // them all keeps the ones on the right.
    let fields = this.machineFields();
    const room = (list) => list.reduce((n, [, , w]) => n + w + 2, 0) + list.length - 1;
    while (fields.length && room(fields) > right - 3 - p.x) fields = fields.slice(1);
    let x = right - 2 - room(fields);
    const put = (c, colour) => {
      if (x >= right - 2) return;
      if ('═─'.includes(f.char(x, y)) && f.attr(x, y) === frameAttr) {
        ctx.fillStyle = CGA[frameAttr >> 4];
        ctx.fillRect(x * cw, y * ch, cw, ch);
        ctx.fillStyle = colour ?? CGA[frameAttr & 15];
        ctx.fillText(c, x * cw, y * ch + ch / 2);
      }
      x++;
    };
    for (const [text, colour, width] of fields) {
      x += width - text.length;     // what the text leaves of its place: frame
      put('[');
      for (const c of text) put(c, colour);
      put(']');
      x++;                          // a cell of frame between two fields
    }
  }

  /** A game from the Games menu: its own sky first, then the machine on, in its folder. */
  play(g) {
    if (!this.ready) { this.tell(g.name, 'Drive C: is still being put together - a moment, and again.'); return; }
    if (g.room) this.dos.settings = { ...this.dos.settings, room: g.room };
    this.track(this.dos.run(g.key));
  }

  /** The games, for the console's play. */
  get games() { return GAMES; }

  /**
   * The console (console.js over ../console/, OWLOS LAN's shared core): the
   * terminal Ctrl+` drops - and Files > Terminal - over the same drives as
   * the menu, both commanders and DOS. Made once, at the first start(); its
   * history kept in this browser apart from OWLOS LAN's.
   */
  makeTerminal() {
    if (this.terminal) return;
    this.terminal = new Terminal(this.owl, {
      app: this,
      makeShell: io => siteShell(this, io),
      historyKey: 'site.history',
      welcome: `${ANSI.heading}WIRE CITY 86${RESET} ${ANSI.muted}- help lists the commands, man NAME says more, Tab finishes a word. ` +
        `The drives are /mnt/a, /mnt/c... - C:\\GAMES works too; ~ is D:, My files.${RESET}`,
    });
  }

  /** Alt+F3 on the terminal: closed its own way, its record kept for the next time. */
  closeActive() {
    if (this.terminal?.owns(this.owl.active())) { this.terminal.close(); return; }
    super.closeActive();
  }

  /** What is not a command: the course's tools, and a click on Map Drives' table. */
  poll() {
    super.poll();
    if (this.mapTable && this.mapWin && this.owl.place(this.mapWin)) this.mapTable.poll();
  }

  onCommand(cmd) {
    // The course ends its page on Alt+X (the commander passes it on); a
    // site is left by its browser tab.
    if (cmd === Cm.Exit) return true;
    if (this.terminal?.handles(cmd)) { this.terminal.onCommand(cmd); return true; }
    const t = this.mapTable;
    switch (cmd) {
      case Mp.Close:
        if (this.mapWin && this.owl.place(this.mapWin)) this.owl.close(this.mapWin);
        this.mapWin = 0; this.mapTable = null; this.mapButtons = null; this.mapRect = null;
        return true;
      case Mp.Up: t?.move(-1); return true;
      case Mp.Down: t?.move(1); return true;
      case Mp.PageUp: t?.move(-(t?.room ?? 1)); return true;
      case Mp.PageDown: t?.move(t?.room ?? 1); return true;
      case Mp.Home: t?.home(); return true;
      case Mp.End: t?.end(); return true;
      case Mp.Edit: this.showEdit(); return true;
      case Mp.EditCancel: this.closeEdit(); return true;
      case Mp.EditOk: this.track(this.editFromDialog()); return true;
      case Mp.Add: this.showAdd(); return true;
      case Mp.AddCancel: this.closeAdd(); return true;
      case Mp.AddOk: this.track(this.addFromDialog()); return true;
      case Mp.Remove: {
        const d = this.selectedDrive();
        if (d && 'ABCD'.includes(d.letter)) this.tell('Map Drives', `${d.prefix} is one of the machine's own four: A: to D: stay.`);
        else if (d) this.track(this.removeDrive(d));
        return true;
      }
      case Mp.Open: {
        const d = this.selectedDrive();
        if (d) { this.onCommand(Mp.Close); this.track(this.panels(d, '/', d === this.drives[3] ? this.drives[0] : this.drives[3])); }
        return true;
      }
    }
    const it = items.get(cmd);
    if (!it) return super.onCommand(cmd);
    if (it.act) it.act();
    else this.tell(it.title, `${it.hint}.\n\nMockup: not built yet.`);
    return true;
  }
}
