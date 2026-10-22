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
import { DosCm } from '../owlosui/apps/dos.js';
import { DriveGates } from '../owlosui/dosbox/gates.js';
import { unzip } from '../owlosui/dosbox/unzip.js';
import { log } from '../owlosui/apps/log.js';
import { CourseApp, Cm, A, lessonFromAddress, leaveIsolation } from '../course/course.js';
import { Drive, LocalFolder, crlf, fingerprint, guardRemovals, loadTable, saveTable, keepHandle, handleOf, forgetHandle, freeFolder, statsOf, sizeText, dateText, journalRemovals } from './drives.js';
import { TableWindow } from './tablewin.js';
import { Presence, doingText, serverUrl } from './net.js';
import { Screens } from './screens.js';
import { Caster } from '../console/cast.js';
import { SkyMap } from './skymap.js';
import { MANUALS, manualLines } from './manuals.js';
import { Terminal, CmTerminalClose } from '../console/terminal.js';
import { ANSI, RESET } from '../console/shell.js';
import { siteShell, profileLines, quoted, dosboxLine, pageFile } from './console.js';
import { AgentLink } from './agent.js';
import { AiSection } from './ai.js';
import { PAGE_KEPT, PAGES_DIR, EXAMPLES, parsePage, checkPage, judgeLine, pageBrief, isHtml, exampleName } from './page.js';
import { HtmlPage, checkHtmlPage } from './htmlpage.js';
import { Help } from './help.js';
import { DosBox } from '../owlosui/dosbox/dosbox.js';

// Before anything can remove a file: every removal from this browser's
// storage into a journal that outlives a reload (drives.js says why).
journalRemovals();

/** C:, the machine's hard disk, kept in this browser: what DOS writes there is there tomorrow. */
const C_FOLDER = '/DOS C Drive/';
/** D:, this browser's own folder for the visitor's files - OWLOS LAN's /me is the same one. */
const MY_FILES = '/My files/';
/** What the site last put on C:, file by file, to tell the visitor's changes from its own (seedC). */
const SHIPPED_KEY = 'site.c.shipped.1';

/**
 * The site's own command numbers, past its menu's (100 on) and below
 * OWLOSUI's tools (300..549). A table window takes seven from its base -
 * its bar's keys and Close: Map Drives from MAP_BASE, the Games catalog
 * from GAME_BASE.
 */
const Mp = { Edit: 286, EditOk: 287, EditCancel: 288, Add: 291, Remove: 292, Open: 293, AddOk: 294, AddCancel: 295 };
const MAP_BASE = 270;
const Gm = { Play: 296, Source: 297, Folder: 298, Manual: 247 };
/** The Manual window's close box; and which manuals have opened by themselves once (firstManual). */
const MANUAL_CLOSE = 248;
const MANUALS_SEEN = 'site.manuals.1';
const WHO_BASE = 250;
const Wh = { Watch: 257, Share: 258 };
const SCREEN_CLOSE = 259;
const MAP_CLOSE = 249;
const GAME_BASE = 260;
/** Files > Pages (page.js): the person's pages and the two examples, a row each. */
const PAGES_BASE = 930;
const Pg = { Use: 937, Edit: 938, Off: 939 };
/** The smallest Map Drives can be made: the four buttons in a row (the pilot asked for about 50 columns), the table's Drive, Kind, Size and Where. */
const MAP_MIN = { w: 56, h: 20 };

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
  { key: 'owlfly3', name: 'OWL FLY III', dir: 'OWLFLY3', room: 'owlfly3', hint: 'CGA, EGA, VGA and a Hercules edition of the same war; multiplayer',
    about: 'The same war on every video card a PC could have: CGA in cyan and magenta, EGA, VGA, and a Hercules edition in monochrome. ' +
      'Its first menu asks the machine - a card it has not got refuses the key - and every card has a cockpit drawn for it.',
    keys: 'arrows fly, W/S throttle, A burner, Enter locks, Space cannon, Backspace missile, F2-F7 views, Esc pauses' },
  { key: 'owlfly2', name: 'OWL FLY II', dir: 'OWLFLY2', room: 'owlfly2', hint: 'One shared sky over the network, an F-15 cockpit with three MFD pages',
    about: 'One shared sky over the network, and no menu: you arrive watching the war through an orbit camera, and Enter takes a jet on your own runway. ' +
      'An F-15 cockpit with a radar, three MFD pages, and a name over every human pilot in view.',
    keys: 'before a jet: arrows swing the camera, Z/X in and out, Enter takes one; then arrows fly, W/S throttle, Enter locks, Space cannon' },
  { key: 'owlfly', name: 'OWL FLY', dir: 'OWLFLY', hint: 'The combat flight simulator: an island, a city, two air forces',
    about: 'The combat flight simulator: an island made by the program, a city that can be destroyed, two air forces of five aircraft types ' +
      'across a front line, homing missiles, a cockpit with a working radar, and a jet engine on the Sound Blaster.',
    keys: 'arrows fly, W/S or +/- throttle, Space (hold) cannon, Backspace missile, F4 orbits the target; after GAME OVER Space flies again' },
  { key: 'trainer', name: 'The Flight School', dir: 'TRAINER', hint: 'Take off, fly the pattern, land: an airfield and a flight model that stalls',
    about: 'Take off, fly the pattern, land. An airfield - a numbered runway, a taxiway, hangars, a tower and a turning radar - and a flight model ' +
      'that knows the take-off speed, the stall and the ground cushion. Its 3-D models came from Blender, through the OBJ-to-8086 converter.',
    keys: 'W/S or +/- throttle, arrows steer; F flaps, G gear, B brakes, V view, R starts again' },
  { key: 'wirecity', name: 'WIRE CITY', dir: 'WIRECITY', hint: 'Where it started: a wireframe night flight over a city, one source file',
    about: 'Where it started: a night flight over a wireframe city that the program builds rather than stores. One source file, small enough ' +
      'to read in a sitting, with the three ideas everything here is made of: fixed-point 3-D, hidden lines by the painter, a world from a seed.',
    keys: 'arrows steer - the horizon banks with you' },
  { key: 'multsoko', name: 'MULTIPLAY SOKO', dir: 'MULTSOKO', room: 'multsoko', hint: 'Sokoban on CGA for up to eight: one warehouse, 60 levels, mines, a score each; multiplayer',
    about: 'Crates onto the red marks, in a brick warehouse seen from above, on a CGA screen in four colours - or isometric, turned any of four ways. ' +
      'Everyone who plays it on the site works the same warehouse: up to eight men, a score each, a mine each that stops whoever it catches.',
    keys: 'arrows or W A S D walk and push, Space a mine, Q/E turn, V isometric, Z the whole level, R R anew, N N / P P next or previous' },
  { key: 'multsoko2', name: 'MULTIPLAY SOKO II', dir: 'MULTSOK2', room: 'multsok2', hint: 'Sokoban in a castle for up to eight: EGA 640 or 320, CGA or Hercules, Sound Blaster, candies, a gate out; multiplayer',
    about: 'Crates onto the red marks, in a castle seen from above: a black floor with candies on it, walls of big stones overgrown with green, a moat, ' +
      'a park with oaks, fountains and statues. Every crate home and the gate rises: out through it, and the winner of the level is on the podium.',
    keys: 'arrows or W A S D walk and push, Space a mine, Q/E turn, V isometric, Z close up, R R anew, N N / P P next or previous' },
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

/** A path of the course disk as DOS and the terminal write it: GAMES/X/Y.ASM -> A:\GAMES\X\Y.ASM. */
const onA = path => `A:\\${path.replace(/\//g, '\\')}`;

/**
 * A first visit's machine, where it is not the library's: the picture in
 * whole multiples of DOS's pixels, as the course's; and the CPU AS FAST AS
 * IT GOES. The library's `auto` is DOSBox's: 3000 cycles a millisecond in
 * real mode, where the games, the commander and DOS itself all run - OWL FLY
 * III at about a frame a second, which a visitor takes for the site being
 * slow (the pilot, 2026-10-19). `max` measured 113 million cycles a second
 * against 3, the page as quick to answer. Nothing here runs too fast for it:
 * the OWL FLYs and the Flight School keep time by the BIOS clock, WIRE CITY
 * by the screen's retrace, and every lesson sets its own 30000 (course.js
 * LESSON_CYCLES). `site` counts the changes a saved setting must follow.
 */
const SETTINGS_KEY = 'site.dosbox.1';
const SITE_DOSBOX = { picture: 'sharp', always: false, cycles: 'max', site: 2 };
function siteSettings() {
  try {
    if (!localStorage.getItem(SETTINGS_KEY)) localStorage.setItem(SETTINGS_KEY, JSON.stringify(SITE_DOSBOX));
    const s = JSON.parse(localStorage.getItem(SETTINGS_KEY) ?? '{}');
    // A relay kept from before the site had its own (the course page's, a
    // developer's): forgotten, so the games meet in the server's sky (Sky.cs).
    if (OLD_RELAYS.includes(s.relay)) delete s.relay;
    // Saved before the site's default became `max`: an `auto` then was the
    // default (the dialog saves every setting, chosen or not), not a choice.
    if ((s.site ?? 1) < 2) {
      if (s.cycles === undefined || s.cycles === 'auto') s.cycles = SITE_DOSBOX.cycles;
      s.site = 2;
    }
    localStorage.setItem(SETTINGS_KEY, JSON.stringify(s));
  } catch { /* storage refused: the library's defaults */ }
}

/**
 * What an address's ?play=KEY starts (playFromAddress): the keys the old
 * pages had - owlfly2.html's own, play.html's g= (field was the Flight
 * School there) - a game of C: or an example of A:\EXAMPLES. A key not here
 * is tried as an example's name: ?play=ring builds RING.ASM.
 */
const ADDRESS_PLAYS = {
  owlfly3: { game: 'owlfly3' }, owlfly3h: { game: 'owlfly3', machine: 'hercules' }, owlfly2: { game: 'owlfly2' },
  owlfly: { game: 'owlfly' }, trainer: { game: 'trainer' }, field: { game: 'trainer' }, wirecity: { game: 'wirecity' },
  multsoko: { game: 'multsoko' }, sokoban: { game: 'multsoko' },
  multsoko2: { game: 'multsoko2' }, multsok2: { game: 'multsoko2' },
  jet: { example: 'JET' }, terra: { example: 'TERRA' }, relief: { example: 'RELIEF' }, smoke: { example: 'SMOKE' }, avio: { example: 'AVIO' },
};

/** The relays the site's games used before its server hosted their sky. */
const OLD_RELAYS = ['wss://view.owlos.sk', 'ws://localhost:1900'];

/** A profile's name on the visitor's computer. */
const PROFILE_FILE = 'wirecity-profile.txt';

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
    this.dosOnBus();
    this.documents.saved = doc => this.savedOnBus(doc);
    this.mapDrives = this.makeMapDrives();
    this.catalog = this.makeCatalog();
    this.who = this.makeWho();
    this.pagesWin = this.makePages();
    this.htmlPage = new HtmlPage(this);
    this.help = new Help(this);
    // Screens: this PC's, on air (the console core's Caster), and others', watched (screens.js).
    this.caster = new Caster(this.dos.box, log);
    const stop = this.caster.stop.bind(this.caster);
    this.caster.stop = () => { const was = this.caster.onAir; stop(); if (was) this.buildMenus(); };
    this.screens = new Screens(this.owl, {
      url: name => `${serverUrl()}/site/watch/${encodeURIComponent(name)}`,
      closeCmd: SCREEN_CLOSE, changed: () => this.netStatus(), log,
    });
    // The live map (skymap.js): a room's sky from the server, its ground from world.js.
    this.skymap = new SkyMap(this.owl, {
      closeCmd: MAP_CLOSE, games: GAMES, log,
      loadWorld: async seed => { const m = await import('./world.js'); return { ...m.buildWorld(seed), built: m.built, building: m.building }; },
      onPick: p => {
        if (p.sharing && p.name && p.name !== this.presence?.me) this.send(`watch ${p.name.toLowerCase().replace(/\s+/g, '-')}`, 'Live map');
      },
      closed: () => this.presence?.follow(''),
    });
    this.owl.afterPaint?.add(() => this.stackPictures());
    this.watchJet();
    this.buildMenus();         // again: the course's constructor built it before the drives were there
    this.makeTerminal();
  }

  /**
   * The pictures under the windows - the DOS PC's, a watched screen's, the
   * live map's - are page elements under the canvas, each seen through its
   * window's hole. Where two such windows overlap, BOTH are holes there,
   * and the order of the elements in the page decided which showed, not the
   * order of the windows: a watched screen came out over the DOS window in
   * front of it (the pilot's screenshot, 2026-10-19). So the windows' order
   * is kept here as OWLOSUI shows it - the one made active last is in front,
   * a new one opens in front - and the elements are stacked the same way,
   * all still under the canvas (site.css lifts it to 10): the front one 9,
   * the next 8... Not below 0: the page's own black would cover them. The
   * lesson video is not one of them: it lies OVER the canvas and hides
   * whenever anything covers it (course.js layVideo) - here at 11 (watch).
   */
  stackPictures() {
    const pictures = [];
    // In an HTML page's slot the DOS picture is the page's to place (htmlpage.js layoutDos), over the page.
    if (this.dos?.win && this.dos.box?.el && !this.htmlPage?.slot('dos')) pictures.push({ win: this.dos.win, el: this.dos.box.el });
    for (const v of this.screens?.views.values() ?? []) if (v.win && v.el) pictures.push({ win: v.win, el: v.el });
    if (this.skymap?.win && this.skymap.el && !this.htmlPage?.slot('map')) pictures.push({ win: this.skymap.win, el: this.skymap.el });
    const alive = new Set(pictures.map(p => p.win));
    let order = (this.pictureOrder ?? []).filter(w => alive.has(w));
    for (const p of pictures) if (!order.includes(p.win)) order.unshift(p.win);
    const active = this.owl.active();
    if (alive.has(active) && order[0] !== active) order = [active, ...order.filter(w => w !== active)];
    this.pictureOrder = order;
    for (const p of pictures) {
      const z = String(Math.max(1, 9 - order.indexOf(p.win)));
      if (p.el.style.zIndex !== z) p.el.style.zIndex = z;
    }
  }

  /** The lesson video (course.js), over the site's canvas - which site.css lifts to 10 - as the course has it over its own. */
  watch(...args) {
    super.watch(...args);
    if (this.video?.frame) this.video.frame.style.zIndex = '11';
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
  /**
   * A folder of this browser for a new drive: the one there, whatever the
   * case of its name, or a new one - none made if a letter has it already.
   */
  async folderFor(name) {
    const there = (await this.browser.list('/')).find(e => e.dir && e.name.toLowerCase() === name.toLowerCase());
    const folder = `/${there?.name ?? name}/`;
    this.oneLetter(folder);
    if (!there) await this.browser.mkdir(folder);
    return folder;
  }

  /** One folder, one letter: two would be two of DOS's floppies over the same files, each mirroring what the other wrote. */
  oneLetter(folder) {
    const owner = this.drives.find(x => x.base === this.browser && x.root.toLowerCase() === folder.toLowerCase());
    if (owner) throw new Error(`the folder ${folder.slice(1, -1)} is ${owner.prefix} already - one folder, one letter`);
  }

  async addDrive(e, { keep = true } = {}) {
    const S = this.browser;
    if (e.kind === 'folder') this.oneLetter(e.folder);
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
    this.mapDrives.again();       // where and as big as it was
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
   * Files > Map Drives, worked out with the pilot (2026-10-16) - the window
   * every table window of the site is now made as (tablewin.js):
   *
   *  - the window by the golden section, resizable, back to MAP_MIN when let
   *    go smaller; the table one thing, heads and rows in one frame, a colour
   *    a column, the classic bar (CellTable);
   *  - what each drive IS, not only its name: how many files, how big, when
   *    it last changed - and where its files really are;
   *  - the drive's own buttons - Open, Add, Edit, Remove - in a row a line
   *    under the table, and Close alone at the bottom right. Edit and Remove
   *    are there only for a drive they can do something to - A: to D: are
   *    the machine's own.
   *
   * Keys: Enter opens, Ins adds, F4 edits, Del takes away (its files stay
   * where they are), the arrows, Home, End and the page keys move the bar.
   */
  makeMapDrives() {
    const own = i => { const d = this.drives[i]; return !d || 'ABCD'.includes(d.letter); };
    return new TableWindow(this, {
      title: 'Map Drives', base: MAP_BASE, min: MAP_MIN,
      columns: [
        { head: 'Drive', width: 7, colour: Color.White },
        { head: 'Kind', width: 11, colour: Color.Yellow, drop: 2 },
        { head: 'What', width: 22, colour: Color.White, drop: 3 },
        { head: 'Files', width: 7, align: 'right', colour: Color.LightGreen, drop: 4 },
        { head: 'Size', width: 9, align: 'right', colour: Color.LightGreen, drop: 1 },
        { head: 'Changed', width: 13, colour: Color.White, drop: 5 },
        { head: 'Where', width: 0, colour: Color.LightCyan },
      ],
      rows: () => this.driveRows(),
      buttons: i => [
        { key: 'open', label: '~O~pen', cmd: Mp.Open, default: true, shown: true },
        { key: 'add', label: '~A~dd...', cmd: Mp.Add, shown: true },
        { key: 'edit', label: '~E~dit...', cmd: Mp.Edit, shown: !own(i) },
        { key: 'remove', label: '~R~emove', cmd: Mp.Remove, shown: !own(i) },
      ],
      keys: i => [
        { label: '~Enter~ Open', cmd: Mp.Open, key: 'Enter' },
        { label: '~Ins~ Add', cmd: Mp.Add, key: 'Insert' },
        ...(own(i) ? [] : [{ label: '~F4~ Edit', cmd: Mp.Edit, key: 'F4' }, { label: '~Del~ Remove', cmd: Mp.Remove, key: 'Delete' }]),
      ],
      words: () => ['Enter opens a drive in Kirin Commander for Web; Ins adds one, F4 edits it, Del takes it away ' +
        '- its files stay. One table for the menu, both commanders and DOS: DOS sees a change at its next switch-on.'],
      open: () => this.onCommand(Mp.Open),
    });
  }

  /** Map Drives open - the drives counted as it shows them. */
  showDrives() {
    this.mapDrives.show();
    this.track(this.countDrives());
  }

  // ------------------------------------------------------------ the Games catalog

  /**
   * Games > Catalog (F3), and what the site opens on: the games on C:, a
   * row each, made as Map Drives is (tablewin.js) - under the table the game
   * in the bar, what it is and its keys. Play runs it on the DOS PC, Source
   * puts its source in an editor, Folder shows the game on C: beside its
   * source on A: in Kirin Commander for Web.
   */
  makeCatalog() {
    return new TableWindow(this, {
      title: 'Games', base: GAME_BASE, min: MAP_MIN, tall: true,
      columns: [
        { head: 'Game', width: 19, colour: Color.White },
        { head: 'What it is', width: 0, colour: Color.LightCyan },
        { head: 'Players', width: 13, colour: Color.Yellow, drop: 2 },
        { head: 'Size', width: 9, align: 'right', colour: Color.LightGreen, drop: 1 },
        { head: 'On C:', width: 19, colour: Color.White, drop: 3 },
      ],
      rows: () => GAMES.map(g => {
        const s = this.gameStats?.get(g.key);
        return [g.name, g.hint, g.room ? 'network too' : 'one', s ? sizeText(s.bytes) : '...', `C:\\GAMES\\${g.dir}`];
      }),
      buttons: () => [
        { key: 'play', label: '~P~lay', cmd: Gm.Play, default: true, shown: true },
        { key: 'source', label: '~S~ource', cmd: Gm.Source, shown: true },
        { key: 'folder', label: '~F~older', cmd: Gm.Folder, shown: true },
        { key: 'manual', label: '~M~anual', cmd: Gm.Manual, shown: true },
      ],
      keys: () => [
        { label: '~Enter~ Play', cmd: Gm.Play, key: 'Enter' },
        { label: '~F4~ Source', cmd: Gm.Source, key: 'F4' },
      ],
      words: i => [GAMES[i].about, `Keys: ${GAMES[i].keys}.`],
      open: () => this.fromCatalog(Gm.Play),
    });
  }

  // ------------------------------------------------------------ who is here

  /**
   * The network, the anonymous way (the pilot, 2026-10-18; net.js): this
   * page's connection to the server, named an animal by it, and its status
   * - what it does, as a code - kept up to date from what this page does:
   * a game on the DOS PC, a lesson's program, the last command on the bus,
   * away while the tab is hidden. The terminal's prompt says the animal.
   */
  startNet() {
    if (this.presence) return;
    this.presence = new Presence({
      log, onChange: () => this.netChanged(),
      // The server's clock on the maps (Sky.cs): a minute's warning, then the new map -
      // a game of that room flown here starts again into it, with everyone else's.
      onSoon: (room, seconds) => {
        this.mapSoon = { room, at: Date.now() + seconds * 1000 };
        this.netEvent(`a new map of ${room} in ${seconds} s${this.flying(room) ? ' - your game starts again into it' : ''}`);
      },
      onPilots: m => {
        this.skymap.me = this.jet?.room === m.room ? this.jet.pid : null;
        this.skymap.update(m);
      },
      onMap: ({ sky }) => {
        this.mapSoon = null;
        this.netEvent(`the server's new map of ${sky.room}: seed ${sky.seed}`);
        const g = this.flying(sky.room);
        if (g) this.send(`play ${g.key}`, 'new map');
        else this.dos.retitle();
      },
    });
    // The DOS window's title counts the warning's minute down.
    setInterval(() => { if (this.mapSoon && this.flying(this.mapSoon.room)) this.dos.retitle(); }, 1000);
    this.terminal.bus.on('command', ({ line, from }) => {
      const [word, arg = ''] = line.trim().split(/\s+/);
      if (!from) this.lastDoing = ['terminal'];
      else if (word === 'lesson') this.lastDoing = ['lesson', arg];
      else if (word === 'build') this.lastDoing = ['build'];
      else if (word === 'edit') this.lastDoing = ['edit'];
      else if (word === 'commander') this.lastDoing = ['files'];
      this.netStatus();
    });
    document.addEventListener('visibilitychange', () => this.netStatus());
    setInterval(() => this.netStatus(), 3000);
    this.presence.start();
    // A model's hands in this page (agent.js): its line follows the presence's.
    this.agent = new AgentLink(this);
    // ...and the AI menu's windows over them (ai.js): the chat, the agents, their tasks, every call.
    this.ai = new AiSection(this);
    this.netStatus();
  }

  /**
   * This DOS PC's jet: the relay's first answer on a game's line (/site/ipx/
   * <room>) is its registration, whose destination is this machine's IPX
   * address - and OWL FLY names its pilot by the last two bytes of it,
   * little-endian (NET.INC). Told to the server with the status, it puts
   * this animal's name on this jet on the live map. Heard as js-dos opens
   * the line: the page's WebSocket, wrapped once more (the network tap is
   * one such wrapping already).
   */
  watchJet() {
    const Base = window.WebSocket, app = this;
    window.WebSocket = class extends Base {
      constructor(url, protocols) {
        super(url, protocols);
        const m = /\/site\/ipx\/([a-z0-9]+)/i.exec(String(url));
        if (!m) return;
        const room = m[1].toLowerCase();
        this.addEventListener('message', async e => {
          if (app.jet?.room === room) return;
          const b = new Uint8Array(e.data instanceof Blob ? await e.data.arrayBuffer() : e.data);
          if (b.length < 30 || b[0] !== 0xFF || b[1] !== 0xFF || ((b[16] << 8) | b[17]) !== 2) return;
          app.jet = { room, pid: b[14] | (b[15] << 8) };
          app.netStatus();
        });
        this.addEventListener('close', () => { if (app.jet?.room === room) { app.jet = null; app.netStatus(); } });
      }
    };
  }

  /** The live map of a room - the one named, else the game this PC flies, else OWL FLY III's: `sky`. */
  showSky(room) {
    this.skymap.show(room);
    this.skymap.me = this.jet?.room === room ? this.jet.pid : null;
    this.presence?.follow(room);
  }

  /**
   * The game this DOS PC flies in a networked room - the room's game - or
   * null. Not without the IPX card: to fly alone is to switch the network
   * off (the pilot, 2026-10-19), and then no new map restarts the game.
   */
  flying(room) {
    const dos = this.dos, g = GAMES.find(x => x.key === dos.started);
    return dos.box.running && !dos.program && dos.settings.ipx && g?.room === room ? g : null;
  }

  /** A line of the network's in the terminal's record, as a file saved is. */
  netEvent(text) {
    const t = this.terminal;
    t.write(`\r\x1b[K${ANSI.muted}# ${text}${RESET}\r\n`);
    if (!t.busy) t.render();
  }

  /** What this page is doing now, as the others will see it. */
  netStatus() {
    const dos = this.dos, p = this.presence;
    if (!p) return;
    // The jet goes with every status while the game flies - away in another tab, the jet still flies there.
    const jet = this.jet && this.flying(this.jet.room) ? this.jet : null;
    if (document.hidden) return p.status('away', '', jet);
    if (dos.box.running && !dos.program && GAMES.some(g => g.key === dos.started)) return p.status('play', dos.started, jet);
    if (dos.box.running && dos.program && this.lesson) return p.status('lesson', this.lesson.lecture);
    if (this.screens?.watching.length) return p.status('watch');
    p.status(...(this.lastDoing ?? ['here']));
  }

  /**
   * `share`: this DOS PC's screen on air, under this connection's animal -
   * its token proves it is ours (Site.cs). It ends with `share --stop`, or
   * with the connection: a new connection, a new animal, a new `share`.
   */
  shareScreen() {
    const p = this.presence;
    if (!p || p.state !== 'on' || !p.token) throw new Error(`not connected to the server (${serverUrl()}) - it tries again by itself`);
    if (this.caster.onAir) return false;
    this.caster.start(p.me, `${serverUrl()}/site/cast?token=${p.token}`);
    this.buildMenus();
    return true;
  }

  stopSharing() {
    if (!this.caster.onAir) return false;
    this.caster.stop();
    return true;
  }

  /** A person in the list by name, whatever its case: Fox, fox. */
  person(name) {
    const w = String(name).toLowerCase().replace(/-/g, ' ');
    return this.presence?.people.find(x => x.name.toLowerCase() === w) ?? null;
  }

  /** The name or the list changed: the prompt, the open window. */
  netChanged() {
    const p = this.presence, sh = this.terminal.shell;
    sh.env.USER = p.me ? p.me.toLowerCase().replace(/\s+/g, '-') : 'guest';
    // The prompt again, open or not: a window's command shows after it even while the terminal is closed.
    if (!this.terminal.busy) this.terminal.shell.prompt().then(x => { this.terminal.prompt = x; if (this.terminal.open) this.terminal.render(); });
    this.screens?.revive(p.people.filter(x => x.sharing).map(x => x.name));
    this.agent?.tick();
    if (this.who.isOpen) {
      if (this.who.rows().length !== this.who.table?.rows.length) this.who.again();
      else { this.who.refreshRows(); this.who.place(); }      // the row in the bar may share now: its Watch
    }
  }

  /**
   * LAN > Who is online: the connections there are, an animal each, what
   * each is doing - as Map Drives is made (tablewin.js). Yours is marked.
   */
  makeWho() {
    const since = s => (s < 60 ? 'just now' : s < 3600 ? `${Math.floor(s / 60)} min` : `${Math.floor(s / 3600)} h`);
    return new TableWindow(this, {
      title: 'Who is online', base: WHO_BASE, min: MAP_MIN,
      columns: [
        { head: 'Who', width: 20, colour: Color.White },
        { head: 'Doing', width: 0, colour: Color.LightCyan },
        { head: 'Screen', width: 10, colour: Color.Yellow, drop: 2 },
        { head: 'Here for', width: 12, colour: Color.LightGreen, drop: 1 },
      ],
      rows: () => {
        const p = this.presence;
        if (!p || p.state !== 'on' || !p.me) return [[p?.state === 'connecting' ? 'connecting...' : 'not connected', `the server: ${serverUrl()}`, '', '']];
        return p.people.map(x => [x.name + (x.name === p.me ? ' (you)' : '') + (x.bot ? ' +bot' : ''), doingText(x, GAMES),
          x.sharing ? `shares${x.viewers ? `, ${x.viewers}` : ''}` : '', since(x.since)]);
      },
      // Watch: someone else's shared screen; Share: this PC's, on and off.
      buttons: i => {
        const x = this.presence?.people[i], p = this.presence;
        return [
          { key: 'watch', label: '~W~atch', cmd: Wh.Watch, default: true, shown: !!x?.sharing && x.name !== p?.me },
          { key: 'share', label: this.caster?.onAir ? '~S~top sharing' : '~S~hare my screen', cmd: Wh.Share, shown: p?.state === 'on' },
        ];
      },
      keys: i => {
        const x = this.presence?.people[i];
        return x?.sharing && x.name !== this.presence?.me ? [{ label: '~Enter~ Watch', cmd: Wh.Watch, key: 'Enter' }] : [];
      },
      open: () => this.onCommand(Wh.Watch),
      words: () => {
        const p = this.presence, n = p?.here ?? 0;
        return [`${p?.state === 'on' ? `${n} here now${p.me ? ` - you are ${p.me}` : ''}.` : 'Not connected to the server yet.'} ` +
          'A name belongs to a connection: a reload is a new animal. Nobody\'s address is shown or kept; ' +
          'what each one does is a word - never a file\'s name, never what was typed. Help > Who sees what says all of it.'];
      },
    });
  }

  /** The catalog open - each game's folder on C: weighed as it shows them; rect: a page's place for it. */
  showCatalog(rect = null) {
    this.catalog.show(rect);
    this.track((async () => {
      this.gameStats ??= new Map();
      for (const g of GAMES) {
        try { this.gameStats.set(g.key, await statsOf(this.drives[2], `/GAMES/${g.dir}/`)); } catch { /* not on C: yet */ }
        this.catalog.refreshRows();
      }
    })());
  }

  /** Play, Source or Folder for the game in the catalog's bar. */
  fromCatalog(cmd) {
    const g = GAMES[this.catalog.current];
    if (!g) return;
    if (cmd === Gm.Manual) { this.send(`manual ${g.key}`, 'Games'); return; }
    this.catalog.close();
    if (cmd === Gm.Play) this.send(`play ${g.key}`, 'Games');
    else if (cmd === Gm.Source) {
      const s = this.sources?.games.find(x => x.dir === g.dir);
      if (s) this.send(`edit ${onA(s.main)}`, 'Games');
      else this.tell(g.name, `Its source is not on the course disk.`);
    } else this.send(`commander C:\\GAMES\\${g.dir} A:\\GAMES\\${g.dir}`, 'Games');
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
      this.mapDrives.refreshRows();
    }
  }

  selectedDrive() { return this.mapDrives.isOpen ? this.drives[this.mapDrives.current] : null; }

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

  /** OK in Edit: what changed, as `relabel` - the drive under its new letter and name, its files where they were. */
  editFromDialog() {
    const owl = this.owl, ed = this.editing, d = ed.d;
    const letter = owl.getText(ed.letter).trim().toUpperCase().replace(/:$/, '');
    const title = owl.getText(ed.title).trim() || d.title;
    const write = ed.write ? owl.clusterState(ed.write).on[0] : null;
    this.closeEdit();
    const changes = [
      letter !== d.letter ? `--letter ${quoted(letter)}` : '',
      title !== d.title ? `--name ${quoted(title)}` : '',
      write !== null && write !== !!d.entry?.write ? (write ? '--write' : '--read-only') : '',
    ].filter(Boolean);
    if (changes.length) this.send(`relabel ${d.prefix} ${changes.join(' ')}`, 'Map Drives');
  }

  /**
   * A drive under another letter, another name - for a folder on this
   * computer, written to by DOS or not: out of the table and in again, its
   * files where they were. What `relabel` does.
   */
  async relabelDrive(d, { letter = d.letter, title = d.title, write = d.entry?.write } = {}) {
    if ('ABCD'.includes(d.letter)) throw new Error(`${d.prefix} is one of the machine's own four: A: to D: stay as they are`);
    if (!/^[E-Z]$/.test(letter)) throw new Error('a drive Map Drives adds takes a letter from E: to Z:');
    if (letter !== d.letter && this.drives.some(x => x.letter === letter)) throw new Error(`${letter}: is taken`);
    const e = { ...d.entry, letter, title, write };
    if (d.base instanceof LocalFolder) e.handle = d.base.handle;
    await this.removeDrive(d);
    await this.addDrive(e);
    this.afterTable();
    this.mapDrives.select(this.drives.findIndex(x => x.letter === letter));
    return this.drives.find(x => x.letter === letter);
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
   * OK in Add: what was asked, as `mount` - the terminal's record shows it
   * and the next time it can be typed. A link that is not one is the
   * dialog's to say, before anything is sent.
   */
  addFromDialog() {
    const owl = this.owl, a = this.adding;
    const kind = ADD_KINDS[Math.max(0, owl.clusterState(a.kind).on.indexOf(true))][0];
    const name = owl.getText(a.name).trim().replace(/[\\/:*?"<>|]/g, ' ').trim();
    const link = owl.getText(a.link).trim();
    const write = owl.clusterState(a.write).on[0];
    this.closeAdd();
    if (kind === 'link' && !/^https?:\/\//i.test(link)) { this.tell('Map Drives', 'A link begins with https:// - type it in the Link box, then OK.'); return; }
    const L = `${a.letter}:`, named = name ? ` --name ${quoted(name)}` : '';
    this.send(kind === 'folder' ? `mount ${L} ${quoted(name || `Drive ${a.letter}`)}`
      : kind === 'local' ? `mount ${L} --computer${write ? ' --write' : ''}${named}`
        : kind === 'zip' ? `mount ${L} --zip${named}`
          : `mount ${L} ${quoted(link)}${named}`, 'Map Drives');
  }

  // What `mount` does, a kind of drive each. Each puts the drive in the
  // table and says so to the menu, the commanders and DOS (afterTable).

  /** A folder of this browser - the one there, or a new one. */
  async mountFolder(letter, name) {
    const folder = await this.folderFor(name);
    await this.addDrive({ letter, kind: 'folder', title: folder.slice(1, -1), folder });
    this.afterTable();
  }

  /** A folder of this computer, through the browser's picker - its name, or null if none was chosen. */
  async mountComputer(letter, { write = false, name = '' } = {}) {
    if (!globalThis.showDirectoryPicker) throw new Error('this browser cannot give a page a folder of this computer: Chrome and Edge can');
    let handle;
    try { handle = await showDirectoryPicker({ mode: write ? 'readwrite' : 'read' }); } catch (e) {
      if (e.name === 'AbortError') return null;
      throw e;
    }
    const total = await sizeOf(new LocalFolder(handle), '/', LIMIT);
    if (total > LIMIT) throw new Error(`${handle.name} holds more than ${LIMIT >> 20} MB: DOS gets every file of a drive at switch-on - a smaller folder, please`);
    await this.addDrive({ letter, kind: 'local', title: name || handle.name, write, handle });
    this.afterTable();
    return handle.name;
  }

  /** A ZIP of this computer, through the browser's file picker, copied into this browser - its name, or null. */
  async mountZip(letter, name = '') {
    const file = await pickFile('.zip');
    if (!file) return null;
    if (file.size > LIMIT) throw new Error(`${file.name} is bigger than ${LIMIT >> 20} MB`);
    await this.addZip(letter, { kind: 'zip', title: name || file.name }, new Uint8Array(await file.arrayBuffer()));
    this.afterTable();
    return file.name;
  }

  /** A link to a ZIP, fetched and copied into this browser - a site that does not let pages take its files says no. */
  async mountLink(letter, url, name = '') {
    let r;
    try { r = await fetch(url); } catch {
      throw new Error('that site does not let a page take its files - download the ZIP, then mount it with --zip');
    }
    if (!r.ok) throw new Error(`${url}: ${r.status} ${r.statusText}`);
    const bytes = new Uint8Array(await r.arrayBuffer());
    await this.addZip(letter, { kind: 'link', title: name || decodeURIComponent(url.split(/[?#]/)[0].split('/').pop() || 'link'), url }, bytes);
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
      // The networked games on the site's own server, in its rooms (/site/ipx/owlfly3):
      // there the server hosts one sky for all (OWLOS-LAN Sky.cs); without it, each flies its own.
      network: { relay: `${serverUrl()}/site`, room: 'owlfly3' },
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
   * deleted - remembered in `gone`, for good: until 2026-10-18 it was
   * forgotten at once, and back at the next load. A release the site has
   * seen already is not fetched again. And a file that was LOST is not
   * taken for one the visitor deleted: see lostFromC.
   */
  async seedC(list) {
    const S = this.browser;
    let was = null;
    try { was = JSON.parse(localStorage.getItem(SHIPPED_KEY) ?? 'null'); } catch { /* none */ }
    const first = !was;
    was ??= { release: null, files: {} };
    const sameRelease = was.release === list.made;
    const now = { release: list.made, files: {}, gone: [] };
    const files = [
      ...list.files.map(f => ({ path: f.path, url: new URL(`C/${f.path}`, import.meta.url).href })),
      ...this.dos.diskList.map(([path, url]) => ({ path, url })),
      ...Object.entries(this.dos.written).filter(([p]) => p.startsWith('C/')).map(([p, text]) => ({ path: p.slice(2), bytes: new TextEncoder().encode(crlf(text)) })),
    ];
    const lost = first ? new Set() : await this.lostFromC(files, was);
    let put = 0;
    await S.hush(async () => {
      for (const f of files) {
        const at = `${C_FOLDER}${f.path}`;
        const have = await S.readBytes(at).catch(() => null);
        const mine = was.files[f.path];
        // The library's floppy README, written into C:'s folder before the
        // site kept it out (2026-10-16): the library's words, not the visitor's.
        const gates = have && f.path === 'README.TXT' && new TextDecoder().decode(have.slice(0, 64)).startsWith('This folder is drive C:');
        if (!have && !first && mine !== undefined && !lost.has(f.path)) {          // the visitor deleted it: it stays so
          now.files[f.path] = mine;
          now.gone.push(f.path);
          continue;
        }
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
   * FILES VANISH FROM THIS BROWSER, FOLDERS STAY (2026-10-16 every file of
   * A:, twice; 2026-10-18 WELCOME.TXT, then every file of C:) - and nothing
   * deleted them that the removal journal (drives.js) could see. seedC took
   * every missing file for one the visitor had deleted, and C: stayed empty.
   * So a loss is told from a deletion by its shape: a folder still standing
   * with MORE THAN HALF of what the site put in it gone since the last load
   * is a loss, and all of it goes back - said in the log, in a box when the
   * screen is up (start), and in localStorage `site.losses` for whoever
   * hunts the cause. A file or two gone, or a whole folder, is the visitor's.
   * The price: a visitor who empties a folder of the site's files by hand,
   * and keeps the folder, gets them back once - the box says to delete the
   * folder itself. Returns the paths (as in drive-c.json) to put back.
   */
  async lostFromC(files, was) {
    const S = this.browser, gone = new Set(was.gone ?? []), byDir = new Map();
    for (const f of files) {
      if (was.files[f.path] === undefined || gone.has(f.path)) continue;    // never ours there, or deleted long since
      const dir = f.path.slice(0, f.path.lastIndexOf('/') + 1);             // '' is C:\ itself
      if (!byDir.has(dir)) byDir.set(dir, { names: await S.list(`${C_FOLDER}${dir}`).then(l => new Set(l.map(e => e.name)), () => null), ours: 0, missing: [] });
      const d = byDir.get(dir);
      d.ours++;
      if (d.names && !d.names.has(f.path.slice(dir.length))) d.missing.push(f.path);
    }
    const lost = new Set(), dirs = [];
    for (const [dir, d] of byDir) {
      // No folder at all: deleted whole, the visitor's. Half or less: theirs too.
      if (!d.names || d.missing.length * 2 <= d.ours) continue;
      for (const p of d.missing) lost.add(p);
      dirs.push(`C:\\${dir.replace(/\//g, '\\')}`);
    }
    if (!lost.size) return lost;
    log.warn('site', `C: ${lost.size} of the site's files had vanished from this browser - their folders still there, nothing deleted that anyone asked for - and are put back: ${dirs.join(', ')}`);
    this.cLost = { count: lost.size, dirs };
    try {
      const all = JSON.parse(localStorage.getItem('site.losses') ?? '[]');
      all.push({ at: new Date().toISOString(), page: location.pathname + location.search, drive: 'C', files: lost.size, dirs });
      localStorage.setItem('site.losses', JSON.stringify(all.slice(-50)));
    } catch { /* storage full or refused: the files go back all the same */ }
    return lost;
  }

  /**
   * The course's list and the games' files; the menu again, now with the
   * lessons in it. Unlike the course, nothing opens by itself, and the
   * course disk goes onto A: only when a lesson first needs it.
   */
  async start() {
    if (await leaveIsolation()) return;      // YouTube in a lesson's window, in Firefox too: as the course page
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
    // The course disk onto A: behind the games: the Sources menu, the
    // commanders and the console find it there without opening a lesson.
    this.track(this.installDisk({ quiet: true }));
    // Who is here: this page's connection, an animal (net.js).
    this.startNet();
    // A page of the person's own, if one is on (page.js) - its menus now, its windows below.
    const paged = this.restorePage();
    // The front door: the lesson the address names (?l=7, as on the course
    // page - a lesson opened here writes it), else the games.
    // ?play=owlfly2: a game or a demo the address names - the old pages send
    // here - in front, with no catalog over it; one it does not know, the catalog.
    // With a page on, its own windows instead of the games.
    const asked = lessonFromAddress(this.course.lessons);
    const wanted = asked ? null : new URLSearchParams(location.search).get('play');
    if (asked) await this.track(this.openLesson(asked));
    else if (wanted) await this.track(this.playFromAddress(wanted));
    else if (paged) await this.track(this.openPageWindows());
    else this.showCatalog();
    // Files of the site's that vanished from C: and were put back (lostFromC): said, over all of it.
    if (this.cLost) {
      this.tell('Drive C:', `${this.cLost.count} of the site's files had vanished from this browser's storage - their folders still there, `
        + `nothing deleted that anyone asked for - and they are back: ${this.cLost.dirs.join(', ')}. `
        + 'If you emptied a folder yourself, delete the folder itself, and it stays deleted.');
    }
    this.owl.refresh?.();
  }

  /** What went wrong, in a box with the site's name - the course's says Course. */
  track(promise) {
    this.pending = promise.catch(e => { log.error('site', e.message); this.tell('WIRE CITY 86', e.message); }).finally(() => this.owl.refresh?.());
    return this.pending;
  }

  /**
   * Until the canvas has its size. The course waits for 80 columns - a
   * phone never has them, and the site stood still: here, until the width
   * holds for half a second, or 80 come.
   */
  waitForScreen() {
    return new Promise(resolve => {
      let last = -1, same = 0;
      const t = setInterval(() => {
        const w = this.owl.width;
        same = w > 0 && w === last ? same + 1 : 0;
        last = w;
        if (w >= 80 || same >= 10) { clearInterval(t); resolve(); }
      }, 50);
    });
  }

  /**
   * The course's installDisk, once at a time: the one started behind the
   * games is the one a lesson opened meanwhile waits for. quiet: without the
   * course's Build strip - nobody asked for it yet.
   */
  installDisk({ quiet = false } = {}) {
    if (!this.diskJob) {
      const show = this.showBuild;
      if (quiet) this.showBuild = () => {};
      this.diskJob = super.installDisk()
        .then(() => { if (quiet) this.commander.refreshSource?.(this.browser); })
        .catch(e => { this.diskJob = null; throw e; })
        .finally(() => { this.showBuild = show; });
    }
    return this.diskJob;
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
        { title: 'Sources', act: () => this.send('commander A:\\GAMES A:\\EXAMPLES', 'Sources') }),
      line(),
      ...s.games.map((g, i) => item(`~${i + 1}~ ${GAMES.find(x => x.dir === g.dir)?.name ?? g.dir}`, `${onA(g.main)}: ${g.what}`,
        { title: g.title, act: () => this.send(`edit ${onA(g.main)}`, 'Sources') })),
      line(),
      sub('~E~xamples', ...s.examples.map(e => item(shortTitle(e.title), `${onA(e.main)}: ${e.what}`,
        { title: e.title, act: () => this.send(`edit ${onA(e.main)}`, 'Sources') }))),
      item('The e~n~gine', 'The modules every game and lesson is built from: A:\\ENGINE, in the commander',
        { act: () => this.send('commander A:\\ENGINE A:\\', 'Sources') }),
    ];
  }

  /**
   * A file in an editor - the one already open, if it is. The course disk
   * is put on A: first, if it is not there yet. What `edit` does.
   */
  async editFile(drive, path) {
    if (drive.letter === 'A') await this.installDisk();
    const b = this.toBase(drive, path);
    const open = [...this.docs].find(([, d]) => d.path === b.path && (!d.source || d.source === b.source));
    if (open) { this.owl.activate(open[0]); this.owl.refresh?.(); return; }
    this.commander.open(path.split('/').pop(), await drive.read(path), drive, path, { readOnly: drive.readOnly });
  }

  /** The Lessons menu: the course's list, then a submenu a topic. */
  lessonsMenu() {
    const lessons = this.course?.lessons ?? [];
    const byId = new Map(lessons.map(l => [l.id, l]));
    const named = new Set(TOPICS.flatMap(([, , ids]) => ids));
    const topics = [...TOPICS, ['More', 'Lessons newer than this menu', lessons.filter(l => !named.has(l.id)).map(l => l.id)]];
    const lessonItem = l => item(`${l.lecture.padEnd(3)}${shortTitle(l.title)}`, l.title,
      { title: `Lesson ${l.lecture}`, act: () => this.send(`lesson ${l.lecture.toLowerCase()}`, 'Lessons') });
    return [
      item('~C~atalog...', 'Every lesson: its video, its source, and a DOS machine that builds and runs it',
        { title: 'Lessons', shortcut: 'F1', act: () => this.send('window lessons', 'Lessons') }),
      line(),
      // As the course page has them - Build, Run and Reset go on the bus (onCommand).
      { label: '~B~uild and run', cmd: Cm.Build, shortcut: 'F9', hint: 'Save, assemble the .ASM in front with FASM on the DOS PC, and run what it made' },
      { label: '~R~un', cmd: Cm.Run, shortcut: 'Ctrl+F9', hint: 'Run it again as it was last built' },
      { label: '~W~atch the video', cmd: Cm.Watch, hint: 'The lesson on YouTube, in a window of its own' },
      { label: 'Re~s~et this lesson', cmd: Cm.Reset, hint: "The lesson's files as the course ships them - your changes go" },
      line(),
      ...topics.map(([name, hint, ids]) => ({ name, hint, list: ids.map(id => byId.get(id)).filter(Boolean) }))
        .filter(t => t.list.length)
        .map((t, i) => ({ ...sub(`~${i + 1}~ ${t.name}`, ...t.list.map(lessonItem)), hint: t.hint })),
    ];
  }

  /** The site's menu bar and status line, over the course's - or a page's of the person's own. */
  buildMenus() {
    if (this.page?.kind === 'ini') { this.buildPageMenus(); return; }
    const owl = this.owl;
    next = 100;
    items.clear();
    const about = item('A~b~out WIRE CITY 86', 'What this site is, and what it is made with: OWLOSUI, js-dos, DOSBox, FASM...',
      { act: () => this.send('info about', 'Help') });
    const catalog = item('~C~atalog...', 'Every game on C:, what it is and its keys: Enter plays', { title: 'Games', shortcut: 'F3', act: () => this.send('window catalog', 'Games') });
    this.helpCmd = about.cmd;
    this.catalogCmd = catalog.cmd;

    owl.menuBar(
      sub('~F~iles',
        item('~M~ap Drives...', 'Which letter is where: one table for this menu, both commanders and DOS',
          { act: () => this.send('window drives', 'Files') }),
        line(),
        // The table, a letter a line: Enter opens the drive in the web commander.
        // A: to D: carry their letter as the key; the rest would take the other items' keys (K, L, M, P, T, W).
        ...(this.drives ?? []).map(d => item(`${'ABCD'.includes(d.letter) ? `~${d.letter}~` : d.letter}:  ${d.kind} - ${d.title}` +
          (this.mounted(d) ? '' : ' (asks to be let in)'), d.about,
          { title: `Drive ${d.prefix}`, act: () => this.send(`commander ${d.prefix}`, 'Files') })),
        line(),
        item('~K~irin Commander for DOS', 'The file manager in DOS, on the same drives: Alt+F1, Alt+F2 pick a drive',
          { act: () => this.send('commander dos', 'Files') }),
        item('Kirin Commander for ~W~eb', 'The same two panels in the page, over the same drives: A: on the left, D: on the right',
          { act: () => this.send('commander', 'Files') }),
        item('~T~erminal', 'The console: the same drives as /mnt/a, /mnt/c, and what every window does', { shortcut: 'Ctrl+`', act: () => this.terminal?.toggle() }),
        line(),
        item('Save ~p~rofile...', 'Your drives and settings as a list of commands, in a file on your computer',
          { act: () => this.send('profile --save', 'Save profile', { say: true }) }),
        item('~L~oad profile...', 'Put a saved profile back: the drives come back with their letters',
          { act: async () => { await this.terminal.show(); this.send('profile --load', 'Load profile'); } }),
        item('Pa~g~es...', 'A page of your own: only the menus, keys and windows you want - an INI file on D:, made by you or your AI',
          { act: () => this.send('window pages', 'Files') })),
      sub('~G~ames',
        catalog,
        line(),
        ...GAMES.map((g, i) => item(`~${i + 1}~ ${g.name}`, g.hint, { title: g.name, act: () => this.send(`play ${g.key}`, 'Games') }))),
      sub('~S~ources', ...this.sourcesMenu()),
      sub('~L~essons', ...this.lessonsMenu()),
      sub('LA~N~',
        item('~W~ho is online', 'Who else is here now, and what they are doing - an animal a connection, nothing more',
          { act: () => this.send('window who', 'LAN') }),
        item('~L~ive map', 'The server\'s sky of the game you fly - or OWL FLY III\'s: every jet where it is, a click watches a shared screen',
          { act: () => this.send('sky', 'LAN') }),
        item('~C~hat', 'Talk to everyone here, the IRC way: channels, nicks, /join, /me'),
        item(this.caster?.onAir ? '~S~top sharing my screen' : '~S~hare my screen', 'Your DOS screen for the others to watch, under your animal - Who is online shows who shares',
          { title: 'Share my screen', act: () => this.send(this.caster?.onAir ? 'share --stop' : 'share', 'LAN') }),
        item('~M~onitor', 'The network as the DOS PC has it: the relay, its state, bytes each way, a graph of the last minute, every packet',
          { act: () => this.send('window netmon', 'LAN') })),
      // A model's hands on the site (agent.js, ai.js): the person's own model, paid for by their own key.
      sub('~A~I',
        item('~C~hat', 'A model works in this page while you watch: it writes, builds, runs and plays - on your own Anthropic API key',
          { act: () => this.send('window chat', 'AI') }),
        item('~A~gents', 'Who works here: the chat, and your own Claude Code through MCP - a new token, its line, taken back',
          { act: () => this.send('window agents', 'AI') }),
        item('~T~asks', 'What the models work on: each request, where it stands, what it cost',
          { act: () => this.send('window tasks', 'AI') }),
        item('C~o~nsole', 'Every call a model made here, as it happens',
          { act: () => this.send('window calls', 'AI') }),
        line(),
        item('~N~ew token for Claude Code', 'A token, and the line that connects your own Claude Code to this page - on the clipboard',
          { act: () => this.ai?.newToken() })),
      this.windowMenu(),
      this.helpMenu(about),
    );
    owl.statusLine(
      { label: '~F1~ Lessons', cmd: Cm.Lessons, key: 'F1' },
      { label: '~F2~ Save', cmd: DocCm.Save, key: 'F2' },
      { label: '~F3~ Games', cmd: this.catalogCmd, key: 'F3' },
      { label: '~F9~ Build+run', cmd: Cm.Build, key: 'F9' },
      { label: '~Ctrl-F9~ Run', cmd: Cm.Run, key: 'F9', ctrl: true },
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
      // A page that put the DOS PC somewhere (window dos right): a window opened anew goes there.
      if (!opts.rect && this.dosPlace && !(dos.win && owl.place(dos.win))) opts = { ...opts, rect: this.dosPlace };
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
      // The server's minute before a new map, counted down while this game flies that room.
      const soon = this.mapSoon && this.flying(this.mapSoon.room) ? ` - new map in ${Math.max(0, Math.ceil((this.mapSoon.at - Date.now()) / 1000))} s` : '';
      owl.setText(dos.win, `DOS: ${name}${state}${soon}`);
      owl.windowTag(dos.win, '');
      owl.refresh?.();
    };
    // The drive lights by the table: the library adds a C: of DOSBox's own
    // to its floppies - here C: is one of them, and it said C: twice and
    // never E: on.
    dos.showLights = () => {
      if (!dos.win) return;
      const lights = this.drives.filter(d => this.mounted(d)).map(d => (dos.lit.has(d.letter) ? `~${d.prefix}~` : d.prefix));
      owl.windowIndicator(dos.win, `[${lights.join(' ')}]`);
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
    // On air: this DOS screen shared (share), in red as a studio's light.
    const cast = ['►', this.caster?.onAir ? CGA[12] : CGA[7], 1];
    return [cpu, awake, net, cast];
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
    const fieldsAt = x;
    for (const [text, colour, width] of fields) {
      x += width - text.length;     // what the text leaves of its place: frame
      put('[');
      for (const c of text) put(c, colour);
      put(']');
      x++;                          // a cell of frame between two fields
    }
    // The keys of the game or the demo running (manuals.js), on the frame's
    // left: as much of them as the fields leave room for - the whole of
    // them is in Help > Manual.
    const keys = MANUALS[this.runningManual]?.keys;
    const fits = fieldsAt - 2 - (left + 2);
    if (keys && fits > 12) {
      const text = ` ${keys} `;
      x = left + 2;
      for (const c of text.length <= fits ? text : `${text.slice(0, fits - 4)}... `) put(c, CGA[7]);
    }
  }

  /**
   * A game: its own sky first, then the machine on, in its folder on C:,
   * its window zoomed as F5 zooms it - people do not think of F5 (the pilot,
   * 2026-10-22: "people won't guess to maximise it") - and the first time
   * this browser plays it, its manual beside it, where there is room.
   * machine: a card for this run only (owlfly3h.html: Hercules), the
   * settings left as they are.
   */
  play(g, { machine = null } = {}) {
    if (!this.ready) { this.tell(g.name, 'Drive C: is still being put together - a moment, and again.'); return; }
    if (g.room) this.dos.settings = { ...this.dos.settings, room: g.room };
    const card = this.dos.settings.machine;
    if (machine) this.dos.settings = { ...this.dos.settings, machine };
    this.exampleKey = null;
    this.track(this.dos.run(g.key)
      .finally(() => { if (machine) this.dos.settings = { ...this.dos.settings, machine: card }; })
      .then(() => {
        if (this.dos.box.running && !this.dosBig) this.zoomDos();
        this.firstManual(g.key);
      }));
  }

  /**
   * A program on the WIRE CITY relay for one run - `build ... --net`, `run
   * ... --net` (the pilot, 2026-10-19: multiplayer through our server for
   * the games a model makes): the IPX card on the line, in a room of the
   * program's own - a room with no sky and no clock of the server's, its
   * players only (OWLOS-LAN Sky.cs, [SKY] Rooms). The person's setup is
   * theirs again when the run has started; the room stays, as a game's does.
   */
  async withNet(room, go) {
    const was = this.dos.settings;
    this.dos.settings = { ...was, ipx: true, always: true, room };
    try { return await go(); } finally { this.dos.settings = { ...this.dos.settings, ipx: was.ipx, always: was.always }; }
  }

  /**
   * A build of A:\EXAMPLES - an F9, the console's `build`, an address's
   * ?play=jet - remembers which demo runs, for the keys on the DOS window's
   * frame and Help > Manual; and the first time, its manual beside it.
   */
  async build(o) {
    const t = o ?? this.target();         // F9 passes nothing: the editor's source, as the course has it
    const name = String(t?.asm ?? '').replace(/\.ASM$/i, '').toLowerCase();
    this.exampleKey = /EXAMPLES\/$/i.test(t?.dir ?? '') && MANUALS[name]?.example ? name : null;
    const done = await super.build(o);
    if (this.exampleKey) this.firstManual(this.exampleKey);
    return done;
  }

  /** The manual of what the DOS PC runs now: a game started by play, or a demo built from A:\EXAMPLES. */
  get runningManual() {
    const d = this.dos;
    if (!d?.box.running) return null;
    if (d.program) return this.exampleKey && /BUILD/i.test(d.program.name ?? '') ? this.exampleKey : null;
    return MANUALS[d.started] ? d.started : null;
  }

  /** A manual opened by itself, the first time this browser plays the thing - once, and only where it fits beside the DOS window. */
  firstManual(key) {
    let seen = [];
    try { seen = JSON.parse(localStorage.getItem(MANUALS_SEEN) ?? '[]'); } catch { /* none */ }
    if (seen.includes(key)) return;
    if (!this.showManual(key, { beside: true })) return;
    try { localStorage.setItem(MANUALS_SEEN, JSON.stringify([...seen, key])); } catch { /* a private window */ }
  }

  /**
   * A game's or a demo's manual (manuals.js) in a window BESIDE the DOS
   * PC's, never over it - on its wider side, the shadow's two cells left
   * clear - and the DOS window kept in front, the keys still in DOS. beside:
   * opened by itself: where there is no room beside, not at all. Asked for
   * (Help > Manual, `manual`), it goes in the middle when there is none.
   * False if nothing was shown.
   */
  showManual(key, { beside = false } = {}) {
    const m = MANUALS[key], owl = this.owl;
    if (!m) return false;
    if (this.manualWin && owl.place(this.manualWin)) owl.close(this.manualWin);
    this.manualWin = 0;
    const MIN = 26, WANT = 66, d = this.dos.win ? owl.place(this.dos.win) : null;
    let x = null, w = Math.min(owl.width, WANT);
    if (d) {
      const leftRoom = d.x - 1, rightRoom = owl.width - (d.x + d.w + 1) - 2;     // the DOS window's shadow takes 2 on its right
      const room = Math.max(leftRoom, rightRoom);
      if (room >= MIN) {
        w = Math.min(WANT, room);
        x = rightRoom >= leftRoom ? d.x + d.w + 3 : leftRoom - w;
      }
    }
    if (x === null) {
      if (beside) return false;
      x = Math.floor((owl.width - w) / 2);
    }
    const h = owl.height - 2;
    // The frame drops a title it cannot fit beside the window's number: a narrow one is just "Manual".
    const full = `Manual - ${m.title}`, title = full.length <= w - 10 ? full : 'Manual';
    this.manualWin = owl.window(title, w, h, { x, y: 1, style: Style.Document, closeCmd: MANUAL_CLOSE });
    owl.text(this.manualWin, manualLines(key, w - 4).join('\n'), { readOnly: true });
    if (beside && this.dos.win && owl.place(this.dos.win)) owl.activate(this.dos.win);
    owl.refresh?.();
    return true;
  }

  /**
   * ?play=KEY - what the old pages' addresses open (2026-10-19, the pilot:
   * "a link to the game should open the new site and start that game"):
   * owlfly2.html sends here with ?play=owlfly2, play.html?g=jet with
   * ?play=jet. A game starts on C: by `play`; an example of A:\EXAMPLES is
   * built by FASM on the DOS PC and run, by `build` - as F9 would. Both go
   * by the bus, so the terminal shows what the address did.
   */
  async playFromAddress(key) {
    const k = key.toLowerCase();
    const p = ADDRESS_PLAYS[k] ?? (/^[a-z0-9_]{1,8}$/.test(k) ? { example: k.toUpperCase() } : null);
    if (p?.game) {
      this.send(`play ${p.game}${p.machine ? ` --machine ${p.machine}` : ''}`, 'the address');
      return;
    }
    if (p?.example) {
      await this.installDisk({ quiet: true });
      const there = await this.browser.readBytes(`${A}EXAMPLES/${p.example}.ASM`).then(() => true, () => false);
      if (there) { this.send(`build A:\\EXAMPLES\\${p.example}.ASM`, 'the address'); return; }
    }
    this.showCatalog();
    this.tell('WIRE CITY', `The address asks for "${key}", and there is no game or demo of that name here. The catalog has them all.`);
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
        `The drives are /mnt/a, /mnt/c... - C:\\GAMES works too; ~ is D:, My files. What the menu and the windows do shows here too.${RESET}`,
    });
    this.keepShell();
    // What is not a command but is worth seeing there: a file saved.
    this.terminal.bus.on('file.saved', ({ path }) => {
      const t = this.terminal;
      t.write(`\r\x1b[K${ANSI.muted}# saved ${path}${RESET}\r\n`);
      if (!t.busy) t.render();
      // A page saved in the editor: the Pages window, if open, checks it again.
      if (this.pagesWin?.isOpen) this.track(this.loadPages());
    });
  }

  /**
   * The DOS window's own actions on the bus, as the menu's are (the pilot,
   * 2026-10-18): its close box and Alt+F3 - the PC switched off with it -
   * are `poweroff`; its Machine menu's Switch on, DOS prompt and starts are
   * `dos`, `dos prompt`, `play GAME`, `commander dos`, and Stop `poweroff`;
   * the Settings dialog's OK is `dosbox NAME=VALUE... --now`. The library's
   * own ways stay, for the commands to call (powerOff).
   */
  dosOnBus() {
    const dos = this.dos;
    const close = dos.closeWindow.bind(dos), stop = dos.stop.bind(dos), onCommand = dos.onCommand.bind(dos), settingsOk = dos.settingsOk.bind(dos);
    this.powerOff = async () => { if (dos.win && this.owl.place(dos.win)) await close(dos.win); else await stop(); };
    dos.closeWindow = id => (id && id === dos.win ? this.send('poweroff', 'DOS') : close(id));
    dos.onCommand = cmd => {
      if (cmd === DosCm.Stop || cmd === DosCm.Close) return this.send('poweroff', 'DOS');
      if (cmd === DosCm.Restart) return this.send('dos', 'DOS');
      if (cmd === DosCm.Prompt) return this.send('dos prompt', 'DOS');
      if (cmd >= DosCm.Start && cmd < DosCm.Start + dos.pageStarts.length) {
        const k = dos.pageStarts[cmd - DosCm.Start];
        return this.send(GAMES.some(g => g.key === k) ? `play ${k}` : k === 'commander' ? 'commander dos' : `dos ${k}`, 'DOS');
      }
      return onCommand(cmd);
    };
    dos.settingsOk = () => {
      // The dialog's own OK keeps the settings; its switch-on again is the command's.
      const before = { ...dos.settings }, run = dos.run;
      dos.run = () => Promise.resolve();
      try { settingsOk(); } finally { dos.run = run; }
      const line = dosboxLine(before, dos.settings);
      if (line) this.send(`${line} --now`, 'DOS settings');
    };
  }

  /** A file saved in an editor: an event on the bus, its place as DOS and the terminal write it. */
  savedOnBus(doc) {
    let path = doc.path ?? doc.name;
    if (doc.source instanceof Drive) path = `${doc.source.prefix}${path}`;
    else {
      const d = this.drives.filter(x => x.base === doc.source && path.startsWith(x.root)).sort((a, b) => b.root.length - a.root.length)[0];
      if (d) path = `${d.prefix}${path.slice(d.root.length - 1)}`;
    }
    this.terminal.bus.emit('file.saved', { path: path.replace(/\//g, '\\') });
  }

  /**
   * The terminal's aliases and variables kept in this browser, as its
   * history is and the drives are: what was set up yesterday is there
   * today. Taken back at the start, put away after every command.
   */
  keepShell() {
    const sh = this.terminal.shell, KEY = 'site.shell.1';
    try {
      const kept = JSON.parse(localStorage.getItem(KEY) ?? '{}');
      for (const [k, v] of kept.aliases ?? []) sh.aliases.set(k, v);
      Object.assign(sh.env, kept.env ?? {});
    } catch { /* none, or not ours */ }
    const fixed = new Set(['HOME', 'USER', '?']);
    const run = sh.run.bind(sh);
    sh.run = async (...a) => {
      try { return await run(...a); } finally {
        try {
          localStorage.setItem(KEY, JSON.stringify({
            aliases: [...sh.aliases].filter(([k]) => !sh.builtinAliases.has(k)),
            env: Object.fromEntries(Object.entries(sh.env).filter(([k]) => !fixed.has(k))),
          }));
        } catch { /* a private window: this visit only */ }
      }
    };
  }

  /** The DOS PC's settings as a first visit has them: the library's, with the site's own picture and network. */
  get dosDefaults() { return { ...this.dos.defaults, ...SITE_DOSBOX }; }

  /**
   * `profile --save` (Files > Save profile): the profile - the drives Map
   * Drives added, the DOS PC's settings, the terminal's aliases - in a text
   * file on the visitor's computer, where a clean-up of the site's data does
   * not reach. Chrome and Edge ask where; the others put it in Downloads.
   * What it says, or null when the picker was closed.
   */
  async saveProfile() {
    const lines = profileLines(this, this.terminal.shell);
    const text = crlf(`${lines.join('\n')}\n`);
    const said = lines.filter(l => l && !l.startsWith('#')).length;
    const what = said ? `${said} command${said === 1 ? '' : 's'}` : 'nothing to set up yet';
    const back = 'Files > Load profile puts it back - here after a clean-up, or in another browser';
    if (globalThis.showSaveFilePicker) {
      let file;
      try {
        file = await showSaveFilePicker({ suggestedName: PROFILE_FILE, types: [{ description: 'A WIRE CITY profile', accept: { 'text/plain': ['.txt'] } }] });
      } catch (e) {
        if (e.name === 'AbortError') return null;    // the picker closed: nothing saved, nothing to say
        throw e;
      }
      const w = await file.createWritable();
      await w.write(text);
      await w.close();
      return `${file.name} is on your computer: ${what}. ${back}.`;
    }
    const a = document.createElement('a');
    a.href = URL.createObjectURL(new Blob([text], { type: 'text/plain' }));
    a.download = PROFILE_FILE;
    a.click();
    setTimeout(() => URL.revokeObjectURL(a.href), 10000);
    return `${PROFILE_FILE} went to your downloads: ${what}. ${back}.`;
  }

  /** `profile --load` (Files > Load profile): a profile from this computer - { name, lines } without its comments, or null. */
  async pickProfile() {
    const file = await pickFile('.txt,text/plain');
    if (!file) return null;
    if (file.size > 64 * 1024) throw new Error(`${file.name} is ${sizeText(file.size)}: a profile is a few lines - not this one`);
    return { name: file.name, lines: (await file.text()).split(/\r?\n/).map(l => l.trim()).filter(l => l && !l.startsWith('#')) };
  }

  /**
   * What the menu and the windows DO, as commands on the bus (the pilot,
   * 2026-10-18, OWLOS LAN's way, one person for now): run in the terminal's
   * shell as if typed, shown in its record marked with where they came
   * from - so every click can be typed next time, and read back. What went
   * wrong comes back in a box; say: what it said, too.
   */
  async send(line, from, { say = false } = {}) {
    const a = await this.terminal.bus.send(line, { from });
    if (a.errors.length) this.tell(from, a.errors.join('\n'));
    else if (say && a.lines.length) this.tell(from, a.lines.map(l => l.text).join('\n'));
    this.owl.refresh?.();
    return a;
  }

  // ------------------------------------------------------------ a page of the person's own (page.js)

  /**
   * The page kept in this browser, on again at the start: its menus now,
   * its windows when start() opens them. Not on ?ui=off - the whole site
   * for this visit, whatever the page did - nor when what was kept no longer
   * reads as a page.
   */
  restorePage() {
    let kept = null;
    try { kept = JSON.parse(localStorage.getItem(PAGE_KEPT) ?? 'null'); } catch { /* none kept */ }
    if (!kept?.text) return false;
    if (new URLSearchParams(location.search).get('ui') === 'off') {
      this.tell('Your page', `${kept.file} is your page. ?ui=off in the address shows the whole site this visit; the address without it brings your page back - or WIRE CITY > Whole site, then Files > Pages.`);
      return false;
    }
    // Checked again as it is put on again: an HTML page is taken apart anew each time (htmlpage.js).
    const html = isHtml(kept.file);
    const c = html ? checkHtmlPage(this.terminal.bus.shell, kept.file, kept.text) : null;
    const page = html ? null : parsePage(kept.text);
    const problems = c?.problems ?? page.problems;
    if (problems.length) {
      this.tell('Your page', `${kept.file} no longer reads as a page - the whole site instead:\n\n${problems.join('\n')}`);
      return false;
    }
    this.page = html ? { file: kept.file, name: c.page.name, kind: 'html', text: kept.text } : { file: kept.file, name: page.name, kind: 'ini', page };
    this.buildMenus();
    return true;
  }

  /** `page FILE --use`: what was checked is kept - not the file, which may change after - and put on. */
  async usePage(r) {
    try { localStorage.setItem(PAGE_KEPT, JSON.stringify({ file: r.file, text: r.text })); } catch { /* for this visit only */ }
    this.htmlPage.unmount();
    this.page = r.kind === 'html' ? { file: r.file, name: r.page.name, kind: 'html', text: r.text } : { file: r.file, name: r.page.name, kind: 'ini', page: r.page };
    this.buildMenus();
    await this.openPageWindows();
  }

  /** `page --off`: the whole site again; the page's file stays where it is. The file that was kept, if one was - on or not (?ui=off). */
  async pageOff() {
    let kept = null;
    try { kept = JSON.parse(localStorage.getItem(PAGE_KEPT) ?? 'null')?.file ?? null; localStorage.removeItem(PAGE_KEPT); } catch { /* nothing kept */ }
    kept ??= this.page?.file ?? null;
    this.htmlPage.unmount();
    this.page = null;
    this.dosPlace = null;
    this.buildMenus();
    this.owl.refresh?.();
    return kept;
  }

  /** An HTML page that hid or covered the WIRE CITY button: taken off, and said why. */
  async pageTripped(why) {
    const file = this.page?.file;
    await this.pageOff();
    this.tell('Your page', `${file} is off: ${why}. The button is the way back to the whole site - a page may not take it away. Its file stays on D:.`);
  }

  /** What tells and asks while an HTML page is shown: its own boxes over it - the desktop's would be under it, unseen. */
  tell(title, text) {
    if (this.htmlPage?.shown) { this.htmlPage.tell(title, text); return; }
    super.tell(title, text);
  }

  /** The windows the page's Open= names, in its order - one that cannot open says why in the log, the rest still do. An HTML page: laid over the desktop. */
  async openPageWindows() {
    if (this.page?.kind === 'html') { await this.htmlPage.mount(this.page); return; }
    for (const o of this.page?.page.open ?? []) {
      try { await this.showWindow(o.window, o.at); } catch (e) { log.warn('site', `page: ${o.window}: ${e.message}`); }
    }
    this.owl.refresh?.();
  }

  /** Where a place puts a window, in cells: the menu bar above it, the status line below. */
  placeRect(at) {
    const W = this.owl.width, H = this.owl.height, half = Math.floor(W / 2), mid = Math.floor((H - 2) / 2);
    return {
      left: { x: 0, y: 1, w: half, h: H - 2 }, right: { x: half, y: 1, w: W - half, h: H - 2 },
      top: { x: 0, y: 1, w: W, h: mid }, bottom: { x: 0, y: 1 + mid, w: W, h: H - 2 - mid },
      full: { x: 0, y: 1, w: W, h: H - 2 },
    }[at] ?? null;
  }

  /** The DOS window in a place: its picture as big as the place holds - in whole multiples when sharp, 4:3 else - centred in it. */
  dosRect(box) {
    const sc = this.owl.screen, cw = sc?.cellW ?? 10, ch = sc?.cellH ?? 22;
    let iw, ih;
    if (this.dos.settings.picture === 'sharp') ({ w: iw, h: ih } = DosBox.insideFor(this.owl, box.w - 2, box.h - 2));
    else {
      ih = box.h - 2;
      iw = Math.round((ih * ch * 4) / 3 / cw);
      if (iw > box.w - 2) { iw = box.w - 2; ih = Math.round((iw * cw * 3) / 4 / ch); }
    }
    return { x: box.x + Math.floor((box.w - iw - 2) / 2), y: box.y + Math.floor((box.h - ih - 2) / 2), w: iw + 2, h: ih + 2 };
  }

  /** A terminal - the console's, the chat's - at a place, or at its own; one open elsewhere opens again there. */
  placeTerminal(term, box) {
    if (!('homePlace' in term)) term.homePlace = term.place;      // null for the console's: its own default
    term.place = box ? () => box : term.homePlace;
    if (box && term.open) term.close();
    return term.show();
  }

  /**
   * `window tile`, `window next`...: the windows arranged as the course's
   * Window menu does it (its onCommand - the DOS window zoomed its own way).
   * Over an HTML page the desktop steps forward first: it is what they move.
   * False when there is no window in front for what wants one.
   */
  arrangeWindows(op) {
    const cm = { tile: Cm.Tile, cascade: Cm.Cascade, next: Cm.Next, previous: Cm.Previous, zoom: Cm.Zoom,
      minimize: Cm.Minimize, close: Cm.Close, list: Cm.List, size: Cm.SizeMove }[op];
    if (!cm) return false;
    if (['zoom', 'minimize', 'close', 'size'].includes(op) && !this.owl.active()) return false;
    if (this.htmlPage?.shown) this.htmlPage.peek(true);
    this.onCommand(cm);
    this.owl.refresh?.();
    return true;
  }

  /** The Help menu: its pages (help.js), as `info` lines on the bus; Manual is the game's own. */
  helpMenu(about) {
    const page = (label, topic, hint) => item(label, hint, { title: `Help: ${topic}`, act: () => this.send(topic === 'index' ? 'info' : `info ${topic}`, 'Help') });
    return sub('~H~elp',
      page('~C~ontents', 'index', 'The help: every page, and what can be opened from it at once'),
      item('~M~anual', 'How to play the game or the demo running now - its keys, what it is', { act: () => this.send('manual', 'Help') }),
      line(),
      page('The ~g~ames', 'games', 'What each game is, and a link that plays it'),
      page('The ~l~essons', 'lessons', 'The course in 8086 assembly: a video, a source and a DOS PC each'),
      page('~D~rives and letters', 'drives', 'How the drives work: a letter, where its files are, who sees them'),
      page('~K~eys', 'keys', 'Every key of the site'),
      page('~W~indows', 'windows', 'Side by side, one over the other, the list - and a window in a half of the screen'),
      page('The ~t~erminal', 'console', 'The commands every window and menu runs, and what each command does'),
      page('The ~n~etwork', 'network', 'Who is here, shared screens, the live map, games for several'),
      page('~A~I', 'ai', 'A model that writes, builds and plays in this page, on your own key'),
      page('~P~ages of your own', 'pages', 'The site with only what you want - or a look all your own'),
      page('Who ~s~ees what', 'privacy', 'What the others here see of you, what the server sees, what is never sent'),
      line(),
      about);
  }

  /** The Window menu, as lines on the bus - the whole site's and an INI page's alike: arranging windows is the site's. */
  windowMenu() {
    const w = (label, op, hint, shortcut) => item(label, hint, { title: `Window: ${op}`, ...(shortcut ? { shortcut } : {}), act: () => this.send(`window ${op}`, 'Window') });
    return sub('~W~indow',
      w('~T~ile', 'tile', 'Every window side by side'),
      w('C~a~scade', 'cascade', 'Every window one over the other, each title seen'),
      line(),
      w('~N~ext', 'next', 'The next window to the front', 'F6'),
      w('~P~revious', 'previous', 'The window before it', 'Shift+F6'),
      w('~Z~oom', 'zoom', 'The window in front as big as it goes - or back', 'F5'),
      w('~S~ize/Move', 'size', 'The window in front moved or sized with the arrows; Enter when done', 'Ctrl+F5'),
      w('Mi~n~imize', 'minimize', 'The window in front put away into its bar, bottom right'),
      w('~C~lose', 'close', 'The window in front closed', 'Alt+F3'),
      line(),
      w('~L~ist...', 'list', 'Every window there is, to pick one', 'Alt+0'));
  }

  /** `window NAME [AT]`: a window of the site, where a page - or anyone - says. */
  async showWindow(name, at = null) {
    const box = at ? this.placeRect(at) : null;
    // Over an HTML page a desktop window is unseen: the page steps aside for it - not for the DOS PC in its slot.
    if (this.htmlPage?.shown && !(name === 'dos' && this.htmlPage.slot('dos'))) this.htmlPage.peek(true);
    switch (name) {
      case 'dos': {
        // A running machine stays as it is - a new place would switch it off and on - and takes the place at its next window.
        if (box) this.dosPlace = this.dosRect(box);
        if (this.dos.win && this.owl.place(this.dos.win) && this.dos.box.running) { this.owl.activate(this.dos.win); return; }
        this.track(this.dos.run(this.dos.started || this.dos.settings.start));
        return;
      }
      case 'chat': await this.placeTerminal(this.ai.chat.term, box); return;
      case 'terminal': await this.placeTerminal(this.terminal, box); return;
      case 'calls': this.ai.showConsole(box); return;
      case 'agents': this.ai.agents.show(box); return;
      case 'tasks': this.ai.tasks.show(box); return;
      case 'who': this.who.show(box); return;
      case 'drives': this.mapDrives.show(box); this.track(this.countDrives()); return;
      case 'catalog': this.showCatalog(box); return;
      case 'pages': await this.loadPages(); this.pagesWin.show(box); return;
      // OWLOSUI's own monitors of the DOS PC (apps/monitors.js), as its window's Machine menu opens them.
      case 'netmon': this.dos.monitors.showNet(); return;
      case 'machine': this.dos.monitors.showMachine(); return;
      case 'lessons': this.list.show(); return;
      case 'commander': await this.send('commander', 'window'); return;
      default: throw new Error(`${name}: no such window`);
    }
  }

  /**
   * The page's menus and keys, and the site's own WIRE CITY menu after
   * them - the whole site again, the pages, the terminal, the tokens: what
   * a page never takes away. Each item's hint is its line and what it does.
   */
  buildPageMenus() {
    const owl = this.owl, p = this.page.page, shell = this.terminal?.bus.shell;
    next = 100;
    items.clear();
    const says = text => {
      const j = shell ? judgeLine(shell, text) : null;
      return j?.problem ? `refused: ${j.problem}` : j ? `${j.effect}${j.asks ? ', asks you first' : ''}` : '';
    };
    const runs = (label, text) => item(label, `${text} - ${says(text)}`, { title: label.replace(/~/g, '').trim(), act: () => this.runPageLine(text, label) });
    const about = item('A~b~out WIRE CITY 86', 'What this site is, and what it is made with', { act: () => this.send('info about', 'WIRE CITY') });
    owl.menuBar(
      ...p.menus.map(m => sub(m.title, ...m.items.map(x => (x.line ? runs(x.label, x.line) : line())))),
      this.windowMenu(),
      sub('~W~IRE CITY',
        item('The ~w~hole site', `Every menu of the site again - ${this.page.file} stays where it is, page FILE --use puts it back`,
          { act: () => this.send('page --off', 'WIRE CITY') }),
        item('~P~ages...', 'Your pages and the one that is on: another put on, one edited', { act: () => this.send('window pages', 'WIRE CITY') }),
        item('~T~erminal', 'The console: every line this page runs is there, and every command', { shortcut: 'Ctrl+`', act: () => this.terminal?.toggle() }),
        item('~A~gents and tokens', 'Who works here, and the tokens of your own Claude Code - the site\'s, never a page\'s',
          { act: () => this.send('window agents', 'AI') }),
        line(),
        item('~H~elp', 'The site\'s help: pages with links - to other pages, and to what they tell of, opened at once',
          { act: () => this.send('info', 'WIRE CITY') }),
        item('Who ~s~ees what', 'What the others here see of you, what the server sees, what is never sent',
          { act: () => this.send('info privacy', 'WIRE CITY') }),
        about),
    );
    owl.statusLine(
      ...p.keys.map(k => {
        const label = k.label || k.line.split(/\s+/)[0];
        const it = runs(label, k.line);
        return { label: `~${k.ctrl ? 'Ctrl-' : k.alt ? 'Alt-' : ''}${k.key}~ ${label}`, cmd: it.cmd, key: k.key, ...(k.ctrl ? { ctrl: true } : {}), ...(k.alt ? { alt: true } : {}) };
      }),
      { label: '~F2~ Save', cmd: DocCm.Save, key: 'F2' },
      { label: '~F5~ Zoom', cmd: Cm.Zoom, key: 'F5' },
      { label: '~Alt-F3~ Close', cmd: Cm.Close, key: 'F3', alt: true },
    );
  }

  /**
   * A page's item or key: its line run as if typed - after the person's Yes
   * when the contract says it deletes, changes the setup or gives something
   * out, never when a model may never run it either. What only reads comes
   * back in a box; what goes wrong always does.
   */
  async runPageLine(text, label, { from = this.page?.name || 'Your page', whose = 'of your page' } = {}) {
    const name = label.replace(/~/g, '').trim();
    const j = judgeLine(this.terminal.bus.shell, text);
    if (j.problem) { this.tell(from, `${name}: ${j.problem} - not run.`); return; }
    if (j.asks) {
      const said = { deletes: 'takes away, or writes over, what was there', setup: 'changes your setup', shares: 'gives something to others, or out of this page' }[j.effect];
      if (!this.agent || !await this.agent.confirm(`"${name}" ${whose} runs:\n\n${text}\n\nIt ${said}. Let it?`, `${from} asks`)) return;
    }
    await this.send(text, from, { say: j.effect === 'reads' });
  }

  /** A link to another site (the help's About, a page's https: link): its real address said, then a tab of its own with nothing of ours. */
  async leaveFor(href) {
    let host = href;
    try { host = new URL(href).host; } catch { /* said as it is */ }
    const ask = this.htmlPage?.shown ? this.htmlPage.ask.bind(this.htmlPage) : (t, title) => this.agent?.confirm(t, title) ?? Promise.resolve(false);
    if (await ask(`You are leaving WIRE CITY for\n\n${host}\n\n${href}\n\nOpen it in a tab of its own?`, 'A link')) window.open(href, '_blank', 'noopener,noreferrer');
  }

  /**
   * A shell of the site's that writes nowhere and asks nothing: what an HTML
   * page of one's own reads for its lists, every few seconds, without
   * filling the terminal - the site's commands, its drives, none of the
   * person's aliases.
   */
  readShell() {
    this.quietShell ??= siteShell(this, { write: () => {}, ask: async () => null });
    return this.quietShell;
  }

  /** `info [TOPIC]`: a help page - over an HTML page of one's own, the page steps aside for it. */
  showInfo(topic) {
    if (this.htmlPage?.shown) this.htmlPage.peek(true);
    return this.help.show(topic || 'INDEX');
  }

  /**
   * The Pages window (Files > Pages, WIRE CITY > Pages: `window pages`):
   * the person's pages in D:\PAGES, the one that is on, and the two
   * examples not written yet - a row each, made as Map Drives is
   * (tablewin.js). Under the table, what the page in the bar does, as its
   * check says it. Use puts it on after a Yes box that says the page - an
   * example is written to D:\PAGES first; Edit opens its file, which then
   * takes Use again: what is on is what was checked.
   */
  makePages() {
    const row = i => this.pageRows()[i];
    return new TableWindow(this, {
      title: 'Pages', base: PAGES_BASE, min: MAP_MIN, tall: true,
      columns: [
        { head: 'Page', width: 14, colour: Color.White },
        { head: 'Name', width: 24, colour: Color.LightCyan },
        { head: 'State', width: 16, colour: Color.Yellow, drop: 2 },
        { head: 'Opens', width: 0, colour: Color.White, drop: 1 },
      ],
      rows: () => this.pageRows().map(r => [r.label, r.name, r.state, r.opens]),
      buttons: i => [
        { key: 'use', label: '~U~se', cmd: Pg.Use, default: true, shown: !!row(i) && !row(i).gone },
        { key: 'edit', label: '~E~dit', cmd: Pg.Edit, shown: !!row(i) && !row(i).example && !row(i).gone },
        { key: 'off', label: 'The ~w~hole site', cmd: Pg.Off, shown: !!this.page },
      ],
      keys: i => [
        ...(row(i) && !row(i).gone ? [{ label: '~Enter~ Use', cmd: Pg.Use, key: 'Enter' }] : []),
        ...(row(i) && !row(i).example && !row(i).gone ? [{ label: '~F4~ Edit', cmd: Pg.Edit, key: 'F4' }] : []),
      ],
      words: i => this.pageWords(row(i)),
      open: () => this.onCommand(Pg.Use),
    });
  }

  pageRows() { return this.pagesFound ?? []; }

  /** The rows read again: each page of D:\PAGES checked, the one on, the examples not there yet. */
  async loadPages() {
    const shell = this.terminal.bus.shell, paths = shell.paths;
    // What a page opens: an INI's windows; an HTML page is the whole screen.
    const opens = p => (!p || p.kind === 'html' || isHtml(p.file ?? '') ? 'the whole screen, HTML'
      : p.open.map(o => `${o.window}${o.at ? ` ${o.at}` : ''}`).join(', ') || '-');
    const rows = [];
    const names = (await paths.list(paths.resolve(PAGES_DIR)).catch(() => []))
      .filter(e => !e.dir && /\.(INI|HTM)$/i.test(e.name)).map(e => e.name.toUpperCase());
    for (const n of names) {
      const file = `${PAGES_DIR}\\${n}`;
      try {
        const c = await pageFile(shell, file), on = this.page?.file === file;
        const n2 = c.problems.length, asks = c.asks.length;
        rows.push({ file, label: n, name: c.page.name, check: c, on, opens: opens(c.page),
          state: on ? 'on' : n2 ? `${n2} problem${n2 > 1 ? 's' : ''}` : asks ? `fine, ${asks} ask${asks > 1 ? '' : 's'}` : 'fine' });
      } catch (e) { rows.push({ file, label: n, name: '', state: 'unreadable', opens: '-', error: e.message }); }
    }
    // On, but its file gone from D: (a cleaned browser, a deleted file): what was checked is kept and works.
    if (this.page && !rows.some(r => r.file === this.page.file)) {
      rows.unshift({ file: this.page.file, label: this.page.file.split('\\').pop(), name: this.page.name, state: 'on, file gone', gone: true,
        opens: opens(this.page.kind === 'html' ? { kind: 'html' } : this.page.page) });
    }
    for (const [k, text] of Object.entries(EXAMPLES)) {
      const n = exampleName(k), file = `${PAGES_DIR}\\${n}`;
      if (names.includes(n)) continue;
      const check = isHtml(n) ? checkHtmlPage(shell, file, text) : checkPage(shell, file, parsePage(text));
      rows.push({ example: k, file, label: n, name: check.data.name, state: 'example', opens: opens(isHtml(n) ? { kind: 'html' } : parsePage(text)), check });
    }
    this.pagesFound = rows;
    const t = this.pagesWin;
    if (t?.isOpen) { if (t.rows().length !== t.table?.rows.length) t.again(); else { t.refreshRows(); t.place(); } }
  }

  /** Under the table: the page in the bar in words - what it is, what it does, what keeps it off. */
  pageWords(r) {
    const always = r && isHtml(r.file)
      ? 'An HTML page is the whole look your own - Bootstrap or anything - and no code of its own: its buttons are lines of the console, ' +
        'what deletes, changes your setup or gives something out asks you each time. The WIRE CITY button stays in its corner; ' +
        '?ui=off in the address is the whole site for one visit.'
      : 'A page is the site with only its menus, keys and windows, each item a line of the console: what deletes, ' +
        'changes your setup or gives something out asks you each time. The WIRE CITY menu stays in every page; ' +
        '?ui=off in the address is the whole site for one visit.';
    if (!r) return [always];
    if (r.gone) return [`${r.file} is on, and its file is gone from D: - what was checked when it was put on is kept and works. The whole site takes it off.`, always];
    if (r.error) return [`${r.file}: ${r.error}`, always];
    const first = r.example ? `An example to begin from. Use writes it to ${r.file} and puts it on; edit it after, to make it yours.`
      : r.on ? 'On now. Edited and saved, it takes Use again: what is on is what was checked.'
        : `Enter puts it on: its check first, then your Yes. F4 edits it - by hand, or your AI does (the guide's PAGES).`;
    const c = r.check;
    const bad = c?.problems.length ? `Not put on until mended: ${c.problems.slice(0, 3).join('; ')}${c.problems.length > 3 ? ' ...' : ''}` : '';
    return [first, c ? pageBrief(c) : '', bad, always].filter(Boolean);
  }

  /** Use: the row's page on - an example written first; read and checked again now, then the person's Yes. */
  async pagesUse() {
    const r = this.pageRows()[this.pagesWin.current];
    if (!r || r.gone) return;
    if (r.example) {
      const a = await this.send(`page --example ${r.example}`, 'Pages');
      if (a.errors.length) return;
    }
    // Again from the file: it may have changed since the table was made.
    const c = await pageFile(this.terminal.bus.shell, r.file);
    if (c.problems.length) {
      await this.loadPages();
      this.tell('Pages', `${r.file} is not put on - mend it first (F4 edits it):\n\n${c.problems.join('\n')}`);
      return;
    }
    if (!this.agent || !await this.agent.confirm(`Put this page on?\n\n${pageBrief(c)}\n\nThe WIRE CITY menu stays in it; ?ui=off in the address is the whole site for one visit.`, 'Your page')) {
      await this.loadPages();
      return;
    }
    this.pagesWin.close();
    await this.send(`page ${r.file} --use --yes`, 'Pages');
  }

  /** The .ASM in the editor in front - or the one built last - as `build` and `run` alone take it: what F9 and Ctrl+F9 do. */
  inFront() {
    const t = this.target();
    if (!t) return null;
    const game = this.gameOf(t.dir);
    return {
      build: `A:\\${(t.dir.slice(A.length) + t.asm).replace(/\//g, '\\')}`,
      run: game ? `A:\\${game.slice(A.length).replace(/\//g, '\\')}RUN.BAT` : `A:\\${(t.dir.slice(A.length) + t.asm.replace(/\.ASM$/i, '.COM')).replace(/\//g, '\\')}`,
    };
  }

  /** Alt+F3 on the terminal: closed its own way, its record kept for the next time. */
  closeActive() {
    if (this.terminal?.owns(this.owl.active())) { this.terminal.close(); return; }
    if (this.screens?.owns(this.owl.active())) { this.screens.closeWindow(this.owl.active()); return; }
    if (this.skymap?.owns(this.owl.active())) { this.skymap.close(); return; }
    if (this.ai?.owns(this.owl.active())) { this.ai.closeWindow(this.owl.active()); return; }
    if (this.help?.owns(this.owl.active())) { this.help.close(); return; }
    super.closeActive();
  }

  /** What is not a command: the course's tools, and a click on a table window's table. */
  poll() {
    super.poll();
    this.mapDrives?.poll();
    this.catalog?.poll();
    this.pagesWin?.poll();
    this.help?.poll();
    this.who?.poll();
    this.ai?.poll();
  }

  onCommand(cmd) {
    // The course ends its page on Alt+X (the commander passes it on); a
    // site is left by its browser tab.
    if (cmd === Cm.Exit) return true;
    if (this.terminal?.handles(cmd)) { this.terminal.onCommand(cmd); return true; }
    // The course's list of lessons opens one as the menu does: `lesson N`, on the bus.
    if (cmd === Cm.Open && this.list.owns(this.owl.active()) && this.list.current()) {
      const l = this.list.current();
      this.list.close();
      this.send(`lesson ${(l.lecture || l.id).toLowerCase()}`, 'Lessons');
      return true;
    }
    for (const t of [this.mapDrives, this.catalog, this.who, this.pagesWin, this.help, this.agent, this.ai]) if (t?.handles(cmd)) { t.onCommand(cmd); return true; }
    switch (cmd) {
      // F9: what is in front, built - as `build`, on the bus. Nothing to build: the lessons.
      case Cm.Build: {
        const t = this.target();
        if (t) this.send(`build A:\\${(t.dir.slice(A.length) + t.asm).replace(/\//g, '\\')}`, 'F9');
        else this.list.show();
        return true;
      }
      // Ctrl+F9: what was built, run again - a game by its RUN.BAT, a lesson's or an example's .COM at the lessons' speed.
      case Cm.Run: {
        const t = this.target();
        const game = t && this.gameOf(t.dir);
        if (!t) this.list.show();
        else if (game) this.send(`run A:\\${game.slice(A.length).replace(/\//g, '\\')}RUN.BAT`, 'Ctrl+F9');
        else this.send(`run A:\\${(t.dir.slice(A.length) + t.asm.replace(/\.ASM$/i, '.COM')).replace(/\//g, '\\')}`, 'Ctrl+F9');
        return true;
      }
      case Cm.Reset:
        if (this.lesson?.buildable) this.send(`lesson ${(this.lesson.lecture || this.lesson.id).toLowerCase()} --reset`, 'Reset', { say: true });
        else this.tell('Reset', 'Open a lesson first: Reset puts its files back as the course ships them.');
        return true;
      case Gm.Play: case Gm.Source: case Gm.Folder: case Gm.Manual: this.fromCatalog(cmd); return true;
      case Wh.Watch: {
        const x = this.presence?.people[this.who.current];
        if (x?.sharing && x.name !== this.presence.me) this.send(`watch ${x.name.toLowerCase().replace(/\s+/g, '-')}`, 'Who is online');
        return true;
      }
      case Wh.Share: this.send(this.caster.onAir ? 'share --stop' : 'share', 'Who is online'); return true;
      case Pg.Use: this.track(this.pagesUse()); return true;
      case Pg.Edit: {
        const r = this.pageRows()[this.pagesWin.current];
        if (r?.file && !r.example && !r.gone) { this.pagesWin.close(); this.send(`edit ${r.file}`, 'Pages'); }
        return true;
      }
      case Pg.Off: this.track((async () => { await this.send('page --off', 'Pages'); await this.loadPages(); })()); return true;
      case SCREEN_CLOSE: this.screens.closeWindow(this.owl.active()); return true;
      case MAP_CLOSE: this.skymap.close(); return true;
      case MANUAL_CLOSE: if (this.manualWin && this.owl.place(this.manualWin)) this.owl.close(this.manualWin); this.manualWin = 0; return true;
      case Mp.Edit: this.showEdit(); return true;
      case Mp.EditCancel: this.closeEdit(); return true;
      case Mp.EditOk: this.editFromDialog(); return true;
      case Mp.Add: this.showAdd(); return true;
      case Mp.AddCancel: this.closeAdd(); return true;
      case Mp.AddOk: this.addFromDialog(); return true;
      case Mp.Remove: {
        const d = this.selectedDrive();
        if (d) this.send(`umount ${d.prefix}`, 'Map Drives');
        return true;
      }
      case Mp.Open: {
        const d = this.selectedDrive();
        if (d) { this.mapDrives.close(); this.send(`commander ${d.prefix}`, 'Map Drives'); }
        return true;
      }
    }
    const it = items.get(cmd);
    if (!it) return super.onCommand(cmd);
    if (it.act) it.act();
    else this.tell(it.title, `${it.hint}.\n\nThat comes with LAN, the network: not on this site yet.`);
    return true;
  }
}
