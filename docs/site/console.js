// The site's console: OWLOS LAN's shared core (../console/ - a copy, by
// ../pull-console.ps1: the grammar, the shell's commands, files, text in
// pipes, the terminal Ctrl+` drops) with what only the site has - its paths
// over the drive table, and its commands for drives, games, programs and
// lessons. The drives are the same ones the Files menu, both commanders and
// DOS show (the pilot, 2026-10-16), seen the way WSL shows Windows' drives:
//
//   /                 mnt/
//   /mnt              a/ b/ c/ d/ ... - a letter each
//   /mnt/c/GAMES      C:\GAMES - and C:\GAMES, c:/games, cd C: are the same
//
// Names inside a drive are found whatever their case, as DOS finds them.
// HOME is D:, My files: ~ and a bare cd go there.

import { Shell, tokens, ANSI, RESET } from '../console/shell.js';
import { CORE_COMMANDS, CORE_GROUPS } from '../console/commands.js';
import { statsOf, sizeText, dateText, LocalFolder } from './drives.js';
import { doingText, serverUrl } from './net.js';
import { MANUALS } from './manuals.js';
import { zip, download } from './zip.js';

/** A path's place: the root, /mnt, or a drive and the path inside it ('/' its top). */
function locate(app, path) {
  if (path === '/') return { kind: 'root' };
  const m = /^\/mnt(?:\/([a-z])(\/.*)?)?$/i.exec(path);
  if (!m) return { kind: 'none' };
  if (!m[1]) return { kind: 'mnt' };
  const drive = app.drives.find(d => d.letter === m[1].toUpperCase());
  return drive ? { kind: 'drive', drive, sub: m[2] ?? '/' } : { kind: 'none' };
}

/**
 * The DOS PC's settings, as OWLOSUI's DOSBox dialog offers them (its
 * apps/dos.js, PAGES): a choice of these, a number between two, yes or no,
 * or a word. What a profile keeps of the machine; `dosbox` reads and sets them.
 */
const yesNo = { yes: true, no: false, on: true, off: false, true: true, false: false };
const DOSBOX = {
  machine: { of: ['svga_s3', 'vgaonly', 'ega', 'cga', 'hercules', 'tandy'], what: 'the video card' },
  memsize: { of: [16, 32, 63], what: 'its memory, MB' },
  picture: { of: ['sharp', 'fill', 'monitor'], what: 'the picture: whole pixels, the whole window, a smoothed monitor' },
  core: { of: ['auto', 'dynamic', 'normal', 'simple'], what: 'how DOSBox runs the code - FASM needs normal' },
  cputype: { of: ['auto', '386', '486_slow', 'pentium_slow'], what: 'the processor' },
  cycles: { of: ['auto', 'max', 'fixed'], what: 'the speed: auto, as fast as it goes, or the fixed below' },
  fixed: { from: 100, to: 1000000, what: 'cycles a millisecond, when cycles is fixed' },
  sbtype: { of: ['sb16', 'sbpro2', 'sb2', 'none'], what: 'the Sound Blaster - none for silence' },
  rate: { of: [44100, 22050, 11025], what: 'the sound, samples a second' },
  gus: { yes: true, what: 'a Gravis Ultrasound too' },
  pcspeaker: { yes: true, what: 'the PC speaker' },
  ems: { yes: true, what: 'EMS memory' },
  umb: { yes: true, what: 'upper memory blocks' },
  awake: { yes: true, what: 'it keeps running in a background tab' },
  start: { starts: true, what: 'what a switch-on starts' },
  ipx: { yes: true, what: 'an IPX network card' },
  always: { yes: true, what: 'the network for every program, not only the networked games' },
  relay: { word: true, what: 'the network relay' },
  room: { word: true, what: 'the network room' },
};
/** The video cards a game can be played on for one run (play --machine). */
const MACHINES = DOSBOX.machine.of;

/** A setting's value from its word, or an Error that says what it takes. */
function dosboxValue(dos, name, word) {
  const s = DOSBOX[name];
  if (!s) return new Error(`${name}: no such setting (dosbox lists them)`);
  if (s.of) {
    const v = s.of.find(x => String(x).toLowerCase() === word.toLowerCase());
    return v ?? new Error(`${name} takes ${s.of.join(', ')}`);
  }
  if (s.from) {
    const n = Number(word);
    return Number.isInteger(n) && n >= s.from && n <= s.to ? n : new Error(`${name} takes a number from ${s.from} to ${s.to}`);
  }
  if (s.yes) return yesNo[word.toLowerCase()] ?? new Error(`${name} takes yes or no`);
  if (s.starts) return dos.starts[word.toLowerCase()] ? word.toLowerCase() : new Error(`${name} takes ${Object.keys(dos.starts).join(', ')}`);
  return word.trim() ? word.trim() : new Error(`${name} takes a word`);
}
const dosboxWord = v => (v === true ? 'yes' : v === false ? 'no' : String(v));

/** What changed between two sets of settings, as a `dosbox` line - or null: what the Settings dialog's OK says on the bus. */
export function dosboxLine(before, after) {
  const changed = Object.keys(DOSBOX).filter(k => after[k] !== undefined && after[k] !== before[k]);
  return changed.length ? `dosbox ${changed.map(k => `${k}=${quoted(dosboxWord(after[k]))}`).join(' ')}` : null;
}

/** A word as the shell reads it back: quoted if it has a space or a sign the shell would take. */
export const quoted = v => (/^[\w./:@%+,=-]*$/.test(v) ? v : v.includes("'") ? `"${v.replace(/(["\\$`])/g, '\\$1')}"` : `'${v}'`);

/** What a profile may hold, and Files > Load profile runs: nothing that deletes or starts anything. */
export const PROFILE_COMMANDS = ['mount', 'dosbox', 'alias', 'export'];

/**
 * Why Files > Load profile will not run a line - or null, it may. A profile
 * can come from someone else, so a line is one of PROFILE_COMMANDS and only
 * that: no ; | && > riding behind it, no alias that would make `mount` or
 * `ls` mean something else, no HOME moved under the visitor's feet.
 */
export function profileRefuses(shell, line) {
  let toks;
  try { toks = tokens(line, {}); } catch (e) { return e.message; }
  if (toks.some(t => t.op)) return 'one command a line - no ; | && or > in a profile';
  const [first, second = ''] = toks.map(t => t.word);
  if (!PROFILE_COMMANDS.includes(first)) return `a profile runs ${PROFILE_COMMANDS.join(', ')} - nothing else`;
  const name = second.split('=')[0];
  if (first === 'alias' && (shell.commands.has(name) || shell.builtinAliases.has(name))) return `${name} is a command already - an alias does not change what it does`;
  if (first === 'export' && ['HOME', 'USER'].includes(name)) return `${name} stays as it is`;
  return null;
}

/**
 * A profile: the commands that set a browser up as this one is - the drives
 * Map Drives added, the DOS PC's settings that are not a first visit's, the
 * aliases and variables made in the terminal. Its files are not in it: a
 * folder of this browser comes back by its name, empty in another browser.
 * The `profile` command prints it; Files > Save profile puts it in a file.
 */
export function profileLines(app, shell) {
  const now = new Date(), two = v => String(v).padStart(2, '0');
  const out = ['# WIRE CITY 86 - a profile: Files > Load profile puts it back, or source FILE in the terminal',
    `# saved ${now.getFullYear()}-${two(now.getMonth() + 1)}-${two(now.getDate())} ${two(now.getHours())}:${two(now.getMinutes())}`];
  const drives = [];
  for (const d of app.drives.filter(x => !'ABCD'.includes(x.letter))) {
    const e = d.entry ?? {};
    if (e.kind === 'folder') drives.push(`mount ${d.prefix} ${quoted(e.folder.slice(1, -1))}`);
    else if (e.kind === 'link') drives.push(`mount ${d.prefix} ${e.url}`);
    else if (e.kind === 'local') drives.push(`# ${d.prefix} the folder ${d.title} of this computer: the browser asks for it again - mount ${d.prefix} --computer${e.write ? ' --write' : ''}`);
    else drives.push(`# ${d.prefix} ${d.title}: a copy of a ZIP in this browser - add the ZIP again in Files > Map Drives`);
  }
  if (drives.length) out.push('', '# the drives added in Map Drives', ...drives);
  const dos = app.dos, first = app.dosDefaults;
  // Not the room: each networked game sets its own when it starts (play).
  const changed = Object.keys(DOSBOX).filter(k => k !== 'room' && dos.settings[k] !== undefined && dos.settings[k] !== first[k]);
  if (changed.length) out.push('', "# the DOS PC's settings a first visit does not have", `dosbox ${changed.map(k => `${k}=${quoted(dosboxWord(dos.settings[k]))}`).join(' ')}`);
  const mine = [...shell.aliases].filter(([k]) => !shell.builtinAliases.has(k)).map(([k, v]) => `alias ${k}=${quoted(v)}`);
  const vars = Object.entries(shell.env).filter(([k]) => !['HOME', 'USER', '?'].includes(k)).map(([k, v]) => `export ${k}=${quoted(v)}`);
  if (mine.length || vars.length) out.push('', '# made in the terminal', ...mine, ...vars);
  if (out.length === 2) out.push('', '# nothing yet: no drives added, the DOS PC as a first visit has it');
  return out;
}

/** The bytes of a text file look like text: no NUL, few control codes. */
function isText(bytes) {
  let odd = 0;
  for (let i = 0; i < Math.min(bytes.length, 4096); i++) {
    const b = bytes[i];
    if (b === 0) return false;
    if (b < 9 || (b > 13 && b < 32)) odd++;
  }
  return odd <= Math.min(bytes.length, 4096) / 10;
}

/** The site's paths, as the core's shell asks for them (../console/shell.js says what). */
export class SitePaths {
  constructor(shell, app) { this.shell = shell; this.app = app; }

  /** A word typed into a path: relative to where the shell is; C:\X, c:/x and C: as /mnt/c. */
  resolve(word = '.') {
    let w = String(word).replace(/\\/g, '/');
    const dos = /^([A-Za-z]):(.*)$/.exec(w);
    if (dos) w = `/mnt/${dos[1].toLowerCase()}/${dos[2].replace(/^\/+/, '')}`;
    const abs = w.startsWith('/') ? w : `${this.shell.cwd}/${w}`;
    const parts = [];
    for (const p of abs.split('/')) { if (!p || p === '.') continue; if (p === '..') parts.pop(); else parts.push(p); }
    if (parts[0] === 'mnt' && parts[1]) parts[1] = parts[1].toLowerCase();
    return `/${parts.join('/')}`;
  }

  /** A path inside a drive with each name as the drive spells it - DOS's way, case does not matter. */
  async spelled(drive, sub) {
    let at = '/';
    for (const part of sub.split('/').filter(Boolean)) {
      const names = await drive.list(at).then(l => l.map(e => e.name), () => []);
      at += `${names.find(n => n === part) ?? names.find(n => n.toLowerCase() === part.toLowerCase()) ?? part}/`;
    }
    return at;              // ends in /: a folder's way of being written
  }

  async list(path) {
    const at = locate(this.app, path);
    if (at.kind === 'root') return [{ name: 'mnt', dir: true, info: 'the drives, a letter each' }];
    if (at.kind === 'mnt') {
      return this.app.drives.map(d => ({ name: d.letter.toLowerCase(), dir: true, info: `${d.prefix} ${d.kind} - ${d.title}  (${d.where})` }));
    }
    if (at.kind !== 'drive') throw new Error(`${path}: no such folder`);
    const entries = await at.drive.list(await this.spelled(at.drive, at.sub));
    entries.sort((a, b) => (b.dir - a.dir) || a.name.localeCompare(b.name));
    return entries.map(e => ({ name: e.name, dir: e.dir, info: e.dir ? '<DIR>' : `${sizeText(e.size ?? 0).padStart(9)}  ${dateText(e.date instanceof Date ? e.date.getTime() : 0)}` }));
  }

  /** A file's words - or why not: a folder, a program (bytes, not words). */
  async read(path) {
    const at = locate(this.app, path);
    if (at.kind !== 'drive' || at.sub === '/') throw new Error(`${path}: a folder, not a file`);
    const sub = (await this.spelled(at.drive, at.sub)).replace(/\/$/, '');
    const bytes = await at.drive.readBytes(sub);
    if (!isText(bytes)) throw new Error(`${path}: not text - ${sizeText(bytes.length)} of bytes (a program, a picture)`);
    // DOS's line ends as the shell's; the file's last line end is no line of its own (cat would print it).
    return new TextDecoder().decode(bytes).replace(/\r\n/g, '\n').replace(/\n$/, '');
  }

  async isDir(path) {
    const at = locate(this.app, path);
    if (at.kind === 'root' || at.kind === 'mnt') return true;
    if (at.kind !== 'drive') return false;
    if (at.sub === '/') return true;
    const parts = at.sub.split('/').filter(Boolean), name = parts.pop().toLowerCase();
    const entries = await at.drive.list(await this.spelled(at.drive, `/${parts.join('/')}`)).catch(() => []);
    return entries.some(e => e.dir && e.name.toLowerCase() === name);
  }

  /** `>` and `>>`: words into a file of a drive, in DOS's line ends. */
  async write(path, text, { append = false } = {}) {
    const at = locate(this.app, path);
    if (at.kind !== 'drive' || at.sub === '/') throw new Error(`${path}: only a file on a drive can be written to (/mnt/d is My files)`);
    const sub = (await this.spelled(at.drive, at.sub)).replace(/\/$/, '');
    const before = append ? await at.drive.read(sub).catch(() => '') : '';
    await at.drive.write(sub, before + text.replace(/\r?\n/g, '\r\n'));
  }

  /** Tab on a path: what its last name may become - folders with their /. */
  async complete(word) {
    const cut = word.lastIndexOf('/') >= 0 ? word.lastIndexOf('/') : word.lastIndexOf('\\');
    const head = cut >= 0 ? word.slice(0, cut + 1) : '', tail = word.slice(cut + 1).toLowerCase();
    const entries = await this.list(this.resolve(head || '.')).catch(() => []);
    return entries.filter(e => e.name.toLowerCase().startsWith(tail)).map(e => `${head}${e.name}${e.dir ? '/' : ''}`);
  }

  /** Tab on what is not a path: a drive's letter, a game, a lesson. */
  async names(how, word) {
    if (how === 'letter') return this.app.drives.map(d => d.prefix).filter(l => l.toLowerCase().startsWith(word.toLowerCase()));
    if (how === 'game') return this.app.games.map(g => g.key).filter(k => k.startsWith(word.toLowerCase()));
    if (how === 'lesson') return (this.app.course?.lessons ?? []).map(l => l.lecture.toLowerCase()).filter(k => k.startsWith(word.toLowerCase()));
    if (how === 'setting') {
      // NAME=VALUE whole: cyc and Tab gives cycles=, a second Tab what it takes.
      const dos = this.app.dos;
      return Object.entries(DOSBOX).flatMap(([k, s]) => (s.of ?? (s.yes ? ['yes', 'no'] : s.starts ? Object.keys(dos.starts) : [dosboxWord(dos.settings[k])]))
        .map(v => `${k}=${v}`)).filter(c => c.toLowerCase().startsWith(word.toLowerCase()));
    }
    return [];
  }
}

/** A path to a drive and a file in it: { drive, dir, name } - dir ends in /, as the commander's do. */
async function fileOn(ctx, word) {
  const paths = ctx.shell.paths, path = paths.resolve(word);
  const at = locate(ctx.app, path);
  if (at.kind !== 'drive' || at.sub === '/') throw new Error(`${word}: not a file on a drive`);
  if (at.drive.letter === 'A') await ctx.app.installDisk();      // the course disk, if a fresh visit has not got it yet
  const spelled = (await paths.spelled(at.drive, at.sub)).replace(/\/$/, '');
  const cut = spelled.lastIndexOf('/');
  return { drive: at.drive, dir: spelled.slice(0, cut + 1), name: spelled.slice(cut + 1), path };
}

/** --net of build and run: a program's own room on the WIRE CITY relay (the pilot: "multiplayer through our server"). */
const NET_OPTION = "the IPX card on the WIRE CITY relay for this run, in a room of the program's own - its folder's name (A:\\MY\\TAG: room tag), or --net=ROOM; everyone who runs it so meets there";

/** The room --net names: the folder's name by default - letters and digits, 16 at most - never a game's that the server hosts a sky in. */
function netRoom(ctx, given, dir) {
  const word = given === true ? (dir.split('/').filter(Boolean).pop() ?? '') : String(given);
  const room = word.toLowerCase().replace(/[^a-z0-9]/g, '').slice(0, 16);
  if (!room) { ctx.err('--net=ROOM: a room is letters and digits'); return null; }
  if (ctx.app.games.some(g => g.room === room)) { ctx.err(`${room}: that is ${ctx.app.games.find(g => g.room === room).name}'s room - give your program one of its own (--net=ROOM)`); return null; }
  return room;
}

export const SITE_GROUPS = [['drives', 'Drives and the DOS PC'], ['programs', 'Games, programs, lessons'], ['network', 'Who is here']];

export const SITE_COMMANDS = [
  // ------------------------------------------------------------ who is here
  {
    name: 'who', group: 'network', where: 'here',
    summary: 'who is here now: an animal a connection - yours too - and what each one does (LAN > Who is online)',
    usage: 'who [--json]', effect: 'reads', data: '[{ name, you, doing, what, bot, sharing, since }]',
    run(ctx) {
      const p = ctx.app.presence;
      if (!p || p.state !== 'on' || !p.me) { ctx.err(`not connected to the server (${serverUrl()}) - ${p?.state === 'connecting' ? 'connecting' : 'it tries again by itself'}`); return 1; }
      ctx.out(`${p.here} here - you are ${p.me}`, 'heading');
      for (const x of p.people) {
        ctx.data({ name: x.name, you: x.name === p.me, doing: x.doing, what: x.what, bot: !!x.bot, sharing: x.sharing, since: x.since });
        ctx.out(`${(x.name + (x.name === p.me ? ' (you)' : '')).padEnd(18)} ${doingText(x, ctx.app.games).padEnd(28)}${x.bot ? ' with a model' : ''}${x.sharing ? ' shares the screen' : ''}`, x.name === p.me ? 'good' : 'text');
      }
      return 0;
    },
  },
  {
    name: 'share', group: 'network', where: 'here',
    summary: 'your DOS screen on air, for the others here to watch - under your animal; --stop ends it',
    usage: 'share [--stop]',
    options: { stop: 'off the air' }, effect: 'shares', effects: { stop: 'shows' }, data: '{ onAir, name, viewers }',
    run(ctx) {
      const app = ctx.app, p = app.presence;
      if (ctx.opts.stop) {
        ctx.out(app.stopSharing() ? 'your screen is off the air' : 'your screen is not on the air', 'muted');
        ctx.data({ onAir: false, name: p?.me ?? null, viewers: 0 });
        return 0;
      }
      if (app.caster.onAir) {
        const n = p?.people.find(x => x.name === p.me)?.viewers ?? 0;
        ctx.out(`your screen is on the air as ${p?.me} - ${n} watching; share --stop ends it`, 'info');
        ctx.data({ onAir: true, name: p?.me ?? null, viewers: n });
        return 0;
      }
      app.shareScreen();
      ctx.data({ onAir: true, name: p?.me ?? null, viewers: 0 });
      ctx.out(`your DOS screen is on the air as ${p.me}${app.dos.box.running ? '' : ' - it shows when the DOS PC is on'}; share --stop ends it`, 'good');
      return 0;
    },
  },
  {
    name: 'watch', group: 'network', where: 'here', complete: (word, sh) => (sh.app.presence?.people ?? [])
      .filter(x => x.sharing && x.name !== sh.app.presence.me).map(x => x.name.toLowerCase().replace(/\s+/g, '-')).filter(n => n.startsWith(word.toLowerCase())),
    summary: "someone's shared DOS screen, in a window - watch fox; alone, who shares",
    usage: 'watch [NAME]', effect: 'shows', data: '[{ name, doing, what, viewers }] who shares; { watching } when one opens',
    run(ctx) {
      const app = ctx.app, p = app.presence;
      if (!p || p.state !== 'on' || !p.me) { ctx.err(`not connected to the server (${serverUrl()})`); return 1; }
      const sharing = p.people.filter(x => x.sharing && x.name !== p.me);
      if (!ctx.args[0]) {
        if (!sharing.length) { ctx.out('nobody shares a screen now', 'muted'); return 0; }
        for (const x of sharing) { ctx.data({ name: x.name, doing: x.doing, what: x.what, viewers: x.viewers }); ctx.out(`${x.name.padEnd(18)} ${doingText(x, app.games)}`); }
        return 0;
      }
      const x = app.person(ctx.args.join(' '));
      if (!x) { ctx.err(`${ctx.args.join(' ')}: nobody of that name here now (who lists them)`); return 1; }
      if (x.name === p.me) { ctx.err('that is you - your own screen is the DOS window'); return 1; }
      if (!x.sharing) { ctx.err(`${x.name} does not share a screen now`); return 1; }
      app.screens.open(x.name);
      ctx.data({ watching: x.name });
      ctx.out(`watching ${x.name}`, 'muted');
      return 0;
    },
  },
  {
    name: 'map', group: 'network', where: 'here', complete: () => ['owlfly3', 'owlfly2'],
    summary: "the map a game room flies: the server's, one for everyone, a new one every half hour (alone, without the server, a game flies its own)",
    usage: 'map [ROOM]', effect: 'reads', data: '{ room, seed, gid, rubble, next, every, pilots, war }',
    async run(ctx) {
      const app = ctx.app, p = app.presence;
      // The room: the one named, else the game this PC flies, else OWL FLY III's.
      const playing = app.games.find(g => g.key === app.dos.started && g.room);
      const room = (ctx.args[0] ?? playing?.room ?? 'owlfly3').toLowerCase();
      if (!app.games.some(g => g.room === room)) { ctx.err(`${room}: no game flies there - ${app.games.filter(g => g.room).map(g => g.room).join(', ')}`); return 1; }
      if (!p || p.state !== 'on') { ctx.err(`not connected to the server (${serverUrl()}) - a game started now flies a map of its own`); return 1; }
      const s = (await p.map(room)).sky;
      ctx.data(s);
      const down = [0, 1].filter(i => s.rubble & (1 << i)).map(i => `radar ${i + 1}`);
      const next = s.next >= 60 ? `${Math.round(s.next / 60)} min` : `${s.next} s`;
      ctx.out(`${room}: seed ${s.seed}, ${s.pilots.length} flying${down.length ? `, ${down.join(' and ')} down` : ''}; a new map in ${next} (every ${s.every} min, the server's)`);
      // The shared war, as its host's last packets had it (WAR.INC): who runs it, what is left.
      const w = s.war;
      if (w) ctx.out(`the war: run by jet ${String.fromCharCode(65 + (w.host % 26))} (pid ${w.host}); bots ${w.bots} up, ${w.down} down; Shilkas ${w.shilkas} up, ${w.burning} burning`);
      else if (s.pilots.length) ctx.out('the war: nobody runs it on the wire yet', 'muted');
      return 0;
    },
  },
  {
    name: 'sky', group: 'network', where: 'here', complete: () => ['owlfly3', 'owlfly2'],
    summary: 'the live map of a game room: its ground, every jet in the server\'s sky - who, how high, a shared screen to click',
    usage: 'sky [ROOM]', effect: 'shows', data: '{ room }',
    run(ctx) {
      const app = ctx.app;
      const playing = app.games.find(g => g.key === app.dos.started && g.room);
      const room = (ctx.args[0] ?? playing?.room ?? 'owlfly3').toLowerCase();
      if (!app.games.some(g => g.room === room)) { ctx.err(`${room}: no game flies there - ${app.games.filter(g => g.room).map(g => g.room).join(', ')}`); return 1; }
      app.showSky(room);
      ctx.data({ room });
      ctx.out(`the live map of ${room}${app.presence?.state === 'on' ? '' : ' - not connected to the server: it waits'}`, 'muted');
      return 0;
    },
  },
  {
    // Your own model in this page, through MCP (agent.js, OWLOS-LAN Agents.cs): the token is made
    // here and kept in this browser; the server is told only its hash.
    name: 'agent', group: 'network', where: 'here', complete: () => ['token', 'revoke'],
    summary: 'your own model (Claude, any MCP client) working in this page - agent token makes its key, agent revoke takes keys back',
    usage: 'agent [token [--days N] | revoke N|all]',
    options: { days: 'how long the token lives: 1 to 7 days (1)' }, valued: ['days'],
    effect: 'setup', bare: 'reads', model: 'never', data: '{ token, address, days } made; [{ n, made, until }] listed',
    async run(ctx) {
      const app = ctx.app, a = app.agent, p = app.presence;
      if (!a) { ctx.err('not here yet: the page is still starting'); return 1; }
      const [word, arg] = ctx.args;
      if (word === 'token') {
        const days = ctx.opts.days === undefined ? 1 : Number(ctx.opts.days);
        if (!Number.isInteger(days) || days < 1 || days > 7) { ctx.err('--days takes 1 to 7'); return 1; }
        const token = await a.make(days);
        ctx.out(`a token for your model, ${days} day${days > 1 ? 's' : ''} - it works while this page is open:`, 'heading');
        ctx.out(token, 'good');
        ctx.data({ token, address: a.address, days });
        ctx.out(`Claude Code: ${a.addLine(token)}`);
        ctx.out('Whoever has it acts in this page as you while it is open - keep it to yourself. agent revoke takes it back.', 'muted');
        if (p?.state !== 'on') ctx.out(`not connected to the server (${serverUrl()}) - the model waits until it is`, 'bad');
        return 0;
      }
      if (word === 'revoke') {
        if (!arg || (arg !== 'all' && !(Number(arg) >= 1 && Number(arg) <= a.held.length))) { ctx.err(`agent revoke N (1..${a.held.length}) or all`); return 1; }
        const n = await a.revoke(arg);
        ctx.out(`${n} token${n === 1 ? '' : 's'} taken back - ${a.held.length} left`, 'muted');
        return 0;
      }
      if (word) { ctx.err(`${word}: agent token, agent revoke N|all, or agent alone`); return 1; }
      if (!a.held.length) { ctx.out('no model works here: agent token makes a key for one', 'muted'); return 0; }
      ctx.out(`${a.held.length} token${a.held.length > 1 ? 's' : ''}; the line: ${a.state}, ${a.claimed} held by the server; ${a.calls} call${a.calls === 1 ? '' : 's'} this visit`, 'heading');
      a.held.forEach((t, i) => {
        ctx.data({ n: i + 1, made: t.made, until: t.until });
        ctx.out(`${String(i + 1).padStart(2)}  ${t.token.slice(0, 6)}...  made ${new Date(t.made).toLocaleString()}, ends ${new Date(t.until).toLocaleString()}`);
      });
      ctx.out(`the address: ${a.address}`, 'muted');
      return 0;
    },
  },
  // ------------------------------------------------------------ drives
  {
    name: 'mount', group: 'drives', where: 'here', complete: 'letter',
    summary: 'the drives, a letter each - or a new one: a folder of this browser, a folder or a ZIP of this computer, a link to a ZIP',
    usage: 'mount [LETTER: FOLDER | LETTER: https://LINK | LETTER: --computer [--write] | LETTER: --zip] [--name NAME]',
    options: {
      computer: 'a folder of this computer, through the browser\'s picker (Chrome, Edge)', write: 'DOS may write to that folder',
      zip: 'a ZIP of this computer, through the browser\'s file picker, copied into this browser', name: 'what the drive is called',
    },
    valued: ['name'],
    // With a letter it changes the drive table - and a link reaches out; alone it only lists.
    effect: 'setup', bare: 'reads', data: '[{ letter, kind, what, where }] - the drives; the new one when a letter is given',
    async run(ctx) {
      const app = ctx.app;
      if (!ctx.args.length) {
        for (const d of app.drives) {
          ctx.data({ letter: d.letter, kind: d.kind, what: d.title, where: d.where });
          ctx.out(`${d.prefix}  ${d.kind.padEnd(11)} ${d.title.padEnd(24)} ${d.where}`, 'ABCD'.includes(d.letter) ? 'text' : 'info');
        }
        return 0;
      }
      const letter = ctx.args[0].replace(/:$/, '').toUpperCase();
      if (!/^[E-Z]$/.test(letter)) { ctx.err('a new drive takes a letter from E: to Z: - mount E: GAMES'); return 1; }
      const what = ctx.args.slice(1).join(' '), called = typeof ctx.opts.name === 'string' ? ctx.opts.name.trim() : '';
      const name = what.replace(/[\\/:*?"<>|]/g, ' ').trim();
      const taken = app.drives.find(d => d.letter === letter);
      if (taken) {
        // The same drive again - a profile loaded twice - is no mistake.
        const e = taken.entry ?? {};
        if ((e.kind === 'folder' && name && e.folder.toLowerCase() === `/${name}/`.toLowerCase()) || (e.kind === 'link' && e.url === what)) {
          ctx.out(`${letter}: is ${taken.title} already`, 'muted');
          return 0;
        }
        ctx.err(`${letter}: is taken - umount ${letter}: first, or another letter`);
        return 1;
      }
      if (ctx.opts.computer) {
        if (!await app.mountComputer(letter, { write: !!ctx.opts.write, name: called || what })) { ctx.out('no folder chosen - nothing mounted', 'muted'); return 0; }
      } else if (ctx.opts.zip) {
        if (!await app.mountZip(letter, called || what)) { ctx.out('no ZIP chosen - nothing mounted', 'muted'); return 0; }
      } else if (/^https?:\/\//i.test(what)) {
        await app.mountLink(letter, what, called);
      } else {
        if (!name) { ctx.err(`which folder? mount ${letter}: NAME - a folder of this browser, made if it is not there`); return 1; }
        await app.mountFolder(letter, name);
      }
      const d = app.drives.find(x => x.letter === letter);
      ctx.data({ letter: d.letter, kind: d.kind, what: d.title, where: d.where });
      ctx.out(`${letter}: ${d.kind} - ${d.title} (${d.where}); DOS sees it at its next switch-on`, 'good');
      return 0;
    },
  },
  {
    name: 'relabel', group: 'drives', where: 'here', complete: 'letter',
    summary: 'a drive under another letter or name - its files stay where they are; a folder of this computer written to by DOS, or not',
    usage: 'relabel LETTER: [--letter NEW] [--name NAME] [--write | --read-only]',
    options: { letter: 'the new letter, E to Z', name: 'the new name', write: 'DOS may write to the folder of this computer', 'read-only': 'DOS only reads it' },
    valued: ['letter', 'name'], effect: 'setup', data: '{ letter, kind, what, where } - the drive as it is now',
    async run(ctx) {
      const app = ctx.app, at = (ctx.args[0] ?? '').replace(/:$/, '').toUpperCase();
      const d = app.drives.find(x => x.letter === at);
      if (!d) { ctx.err(`${ctx.args[0] ?? '?'}: no such drive (mount lists them)`); return 1; }
      const next = {};
      if (typeof ctx.opts.letter === 'string') next.letter = ctx.opts.letter.replace(/:$/, '').toUpperCase();
      if (typeof ctx.opts.name === 'string' && ctx.opts.name.trim()) next.title = ctx.opts.name.trim();
      if (ctx.opts.write) next.write = true;
      if (ctx.opts['read-only']) next.write = false;
      if (!Object.keys(next).length) { ctx.err(`what of ${d.prefix}? relabel ${d.prefix} --letter G, --name NAME, --write or --read-only`); return 1; }
      if ('write' in next && !(d.base instanceof LocalFolder)) { ctx.err(`${d.prefix} is not a folder of this computer: --write and --read-only are for those`); return 1; }
      const now = await app.relabelDrive(d, next);
      ctx.data({ letter: now.letter, kind: now.kind, what: now.title, where: now.where });
      ctx.out(`${now.prefix} ${now.kind} - ${now.title} (${now.where}); DOS sees it at its next switch-on`, 'good');
      return 0;
    },
  },
  {
    name: 'umount', group: 'drives', summary: 'a drive taken off its letter - its files stay where they are', usage: 'umount LETTER:', where: 'here', complete: 'letter',
    effect: 'setup', data: '{ letter, where }',
    async run(ctx) {
      const letter = (ctx.args[0] ?? '').replace(/:$/, '').toUpperCase();
      const d = ctx.app.drives.find(x => x.letter === letter);
      if (!d) { ctx.err(`${ctx.args[0] ?? '?'}: no such drive (mount lists them)`); return 1; }
      if ('ABCD'.includes(letter)) { ctx.err(`${letter}: is one of the machine's own four - A: to D: stay`); return 1; }
      await ctx.app.removeDrive(d);
      ctx.data({ letter, where: d.where });
      ctx.out(`${letter}: free again; its files are where they were (${d.where})`, 'muted');
      return 0;
    },
  },
  {
    name: 'df', group: 'drives', summary: "what each drive holds, and how much of this browser's room they take", usage: 'df', where: 'here',
    effect: 'reads', data: '[{ letter, kind, files, bytes, newest, where }]',
    async run(ctx) {
      ctx.out(`${'drive'.padEnd(7)}${'kind'.padEnd(12)}${'files'.padStart(6)}${'size'.padStart(10)}  changed`, 'heading');
      for (const d of ctx.app.drives) {
        let s = null;
        try { s = d.base instanceof LocalFolder && !ctx.app.mounted(d) ? null : await statsOf(d); } catch { /* not readable now */ }
        ctx.data({ letter: d.letter, kind: d.kind, files: s?.files ?? null, bytes: s?.bytes ?? null, newest: s?.newest ?? null, where: d.where });
        ctx.out(`${d.prefix.padEnd(7)}${d.kind.padEnd(12)}${(s ? String(s.files) : '-').padStart(6)}${(s ? sizeText(s.bytes) : '-').padStart(10)}  ${s ? dateText(s.newest) : 'asks to be let in'}`);
      }
      const est = await navigator.storage?.estimate?.().catch(() => null);
      if (est) ctx.out(`this browser holds ${sizeText(est.usage ?? 0)} of the ${sizeText(est.quota ?? 0)} it allows this site - a clean-up of the site's data takes it all, D: too: Files > Save profile keeps the drive table on your computer`, 'warn');
    },
  },
  {
    name: 'du', group: 'drives', summary: 'how much a folder holds', usage: 'du [PATH]', where: 'here', complete: 'path',
    effect: 'reads', data: '{ path, files, bytes, newest }',
    async run(ctx) {
      const path = ctx.shell.paths.resolve(ctx.args[0] ?? '.');
      const at = locate(ctx.app, path);
      if (at.kind !== 'drive') { ctx.err(`${path}: not inside a drive`); return 1; }
      const s = await statsOf(at.drive, await ctx.shell.paths.spelled(at.drive, at.sub));
      ctx.data({ path, ...s });
      ctx.out(`${sizeText(s.bytes).padStart(9)}  ${s.files} files  ${path}`);
    },
  },
  {
    name: 'mkdir', group: 'files', summary: 'a folder', usage: 'mkdir PATH', where: 'here', complete: 'path', effect: 'writes', data: '[{ path }]',
    async run(ctx) {
      for (const w of ctx.args) {
        const path = ctx.shell.paths.resolve(w), at = locate(ctx.app, path);
        if (at.kind !== 'drive' || at.sub === '/') { ctx.err(`${w}: a folder is made inside a drive`); return 1; }
        await at.drive.mkdir(`${await ctx.shell.paths.spelled(at.drive, at.sub)}`);
        ctx.data({ path });
      }
    },
  },
  {
    // A copy onto a name that is there writes over that file: deletes, as the contract counts it.
    name: 'cp', group: 'files', summary: 'a file copied - to a folder, or to a new name; from one drive to another too', usage: 'cp FILE DEST', where: 'here', complete: 'path',
    effect: 'deletes', data: '{ from, to }',
    async run(ctx) {
      const [from, to] = ctx.args;
      if (!from || !to) { ctx.err('cp FILE DEST'); return 1; }
      const src = await fileOn(ctx, from);
      const bytes = await src.drive.readBytes(`${src.dir}${src.name}`);
      const destPath = ctx.shell.paths.resolve(to);
      const into = await ctx.shell.paths.isDir(destPath);
      const dest = await fileOn(ctx, into ? `${destPath}/${src.name}` : to);
      await dest.drive.write(`${dest.dir}${dest.name}`, bytes);
      if (ctx.name === 'cp') ctx.data({ from: src.path, to: dest.path });
      ctx.out(`${src.path} -> ${dest.path}`, 'muted');
    },
  },
  {
    name: 'mv', group: 'files', summary: 'a file moved or renamed', usage: 'mv FILE DEST', where: 'here', complete: 'path',
    effect: 'deletes', data: '{ from, to }',
    async run(ctx) {
      const code = await ctx.shell.commands.get('cp').run(ctx);
      if (code) return code;
      const src = await fileOn(ctx, ctx.args[0]);
      await src.drive.remove(`${src.dir}${src.name}`);
      ctx.data({ from: src.path, to: ctx.shell.paths.resolve(ctx.args[1]) });
    },
  },
  {
    name: 'rm', group: 'files', summary: 'a file gone - or a folder and all in it (-r)', usage: 'rm [-r] PATH...', where: 'here', complete: 'path', options: { r: 'a folder, with all in it' },
    effect: 'deletes', data: '[{ path }]',
    async run(ctx) {
      for (const w of ctx.args) {
        const path = ctx.shell.paths.resolve(w), at = locate(ctx.app, path);
        if (at.kind !== 'drive' || at.sub === '/') { ctx.err(`${w}: only files and folders inside a drive (umount takes a drive off its letter)`); return 1; }
        if (await ctx.shell.paths.isDir(path) && !ctx.opts.r) { ctx.err(`${w}: a folder - rm -r takes it and all in it`); return 1; }
        await at.drive.remove(`${await ctx.shell.paths.spelled(at.drive, at.sub)}`.replace(/\/$/, ctx.opts.r ? '/' : ''));
        ctx.data({ path });
      }
    },
  },
  {
    name: 'zip', group: 'files', where: 'here', complete: 'path',
    summary: "a folder as a ZIP, into this computer's downloads - zip A:\\MY\\HELI gives HELI.ZIP with the folder in it",
    usage: 'zip FOLDER', effect: 'writes', data: '{ name, files, size }',
    async run(ctx) {
      if (!ctx.args[0]) { ctx.err('which folder? zip A:\\MY\\HELI'); return 1; }
      const paths = ctx.shell.paths, path = paths.resolve(ctx.args[0]), at = locate(ctx.app, path);
      if (at.kind !== 'drive' || at.sub === '/' || !await paths.isDir(path)) { ctx.err(`${ctx.args[0]}: a folder inside a drive`); return 1; }
      const top = (await paths.spelled(at.drive, at.sub)).replace(/\/$/, ''), base = top.split('/').pop();
      const files = [];
      const walk = async (dir, rel) => {
        for (const e of await at.drive.list(dir)) {
          if (e.dir) await walk(`${dir}${e.name}/`, `${rel}${e.name}/`);
          else files.push({ path: `${rel}${e.name}`, bytes: await at.drive.readBytes(`${dir}${e.name}`), date: e.date });
        }
      };
      await walk(`${top}/`, `${base}/`);
      if (!files.length) { ctx.err(`${ctx.args[0]}: an empty folder - nothing to give`); return 1; }
      const blob = await zip(files);
      download(blob, `${base.toUpperCase()}.ZIP`);
      ctx.data({ name: `${base.toUpperCase()}.ZIP`, files: files.length, size: blob.size });
      ctx.out(`${base.toUpperCase()}.ZIP: ${files.length} file${files.length > 1 ? 's' : ''}, ${sizeText(blob.size)} - in this computer's downloads`, 'good');
      return 0;
    },
  },
  {
    name: 'profile', group: 'drives', where: 'here',
    summary: "the commands that set a browser up as this one - the drives you added, the DOS PC's settings, your aliases; Files > Save profile puts them in a file",
    usage: 'profile [--save | --load]',
    options: { save: 'into a file on this computer (Files > Save profile)', load: 'from a file of this computer, line by line (Files > Load profile)' },
    effect: 'reads', effects: { save: 'writes', load: 'setup' }, data: '[{ line }] - the commands, comments left out',
    async run(ctx) {
      const app = ctx.app, sh = ctx.shell;
      if (ctx.opts.save) {
        const said = await app.saveProfile();
        if (said) ctx.out(said, 'good');          // the picker closed: nothing to say
        return 0;
      }
      if (ctx.opts.load) {
        const p = await app.pickProfile();
        if (!p) return 0;
        // Each line shown as if typed, then run - written at once, not
        // gathered as ctx.out's are, so each comes before what it prints.
        // Only what a profile holds runs (profileRefuses): it may be a file
        // someone else passed on.
        sh.write(`${ANSI.muted}# ${p.name}: ${p.lines.length} command${p.lines.length === 1 ? '' : 's'}${RESET}\r\n`);
        for (const l of p.lines) {
          sh.write(`${await sh.prompt()}${l}\r\n`);
          const no = profileRefuses(sh, l);
          if (no) { sh.write(`${ANSI.warn}skipped: ${no}${RESET}\r\n`); continue; }
          await sh.run(l, { signal: ctx.signal });
          if (ctx.signal?.aborted) break;
        }
        return 0;
      }
      for (const l of profileLines(app, sh)) {
        if (!l.startsWith('#')) ctx.data({ line: l });
        ctx.out(l, l.startsWith('#') ? 'muted' : 'text');
      }
    },
  },
  {
    name: 'dosbox', group: 'drives', where: 'here', complete: 'setting',
    summary: "the DOS PC's settings - dosbox cycles=max sbtype=none; it takes them at its next switch-on, or --now",
    usage: 'dosbox [NAME=VALUE ...] [--now]',
    options: { now: 'a running PC switched on again with them, as the Settings dialog does' },
    effect: 'setup', bare: 'reads', data: '[{ name, value, first }] - first is what it starts as',
    run(ctx) {
      const dos = ctx.app.dos, first = ctx.app.dosDefaults;
      if (!ctx.args.length) {
        for (const [k, s] of Object.entries(DOSBOX)) {
          const v = dos.settings[k];
          ctx.data({ name: k, value: v, first: first[k] });
          ctx.out(`${`${k}=${dosboxWord(v)}`.padEnd(22)} ${s.what}`, v === first[k] ? 'muted' : 'info');
        }
        return 0;
      }
      const next = {};
      for (const w of ctx.args) {
        const m = /^([a-z]+)=(.*)$/i.exec(w);
        if (!m) { ctx.err(`${w}: NAME=VALUE - dosbox cycles=max`); return 1; }
        const v = dosboxValue(dos, m[1].toLowerCase(), m[2]);
        if (v instanceof Error) { ctx.err(v.message); return 1; }
        next[m[1].toLowerCase()] = v;
      }
      dos.settings = { ...dos.settings, ...next };
      for (const [k, v] of Object.entries(next)) ctx.data({ name: k, value: v, first: first[k] });
      try { localStorage.setItem(dos.settingsKey, JSON.stringify(dos.settings)); } catch { /* a private window: for this visit only */ }
      const again = ctx.opts.now && dos.box.running;
      if (again) ctx.app.track(dos.run(dos.started ?? dos.settings.start, { program: dos.program }));
      ctx.out(`${Object.entries(next).map(([k, v]) => `${k}=${dosboxWord(v)}`).join(' ')}: ` +
        `${again ? 'the DOS PC switches on again with them' : dos.box.running ? 'the DOS PC takes them at its next switch-on' : 'kept'}`, 'good');
      return 0;
    },
  },

  // ------------------------------------------------------------ games, programs, lessons
  {
    name: 'play', group: 'programs', summary: 'a game: the machine on, in its folder on C:', usage: 'play GAME [--machine CARD]', where: 'here', complete: 'game',
    options: { machine: `the video card for this run only, the settings left as they are: ${MACHINES.join(', ')}` },
    valued: ['machine'], effect: 'runs', data: '{ game, dir, machine }',
    run(ctx) {
      const w = (ctx.args.join(' ') || '').toLowerCase();
      const g = ctx.app.games.find(x => x.key === w || x.name.toLowerCase() === w || x.dir.toLowerCase() === w);
      if (!g) { ctx.err(`which game? ${ctx.app.games.map(x => x.key).join(', ')}`); return 1; }
      const machine = ctx.opts.machine ? String(ctx.opts.machine).toLowerCase() : null;
      if (machine && !MACHINES.includes(machine)) { ctx.err(`--machine ${machine}: one of ${MACHINES.join(', ')}`); return 1; }
      ctx.app.play(g, { machine });
      ctx.data({ game: g.key, dir: `C:\\GAMES\\${g.dir}`, machine });
      ctx.out(`${g.name}: C:\\GAMES\\${g.dir}, RUN${machine ? `, on ${machine} this once` : ''}`, 'muted');
    },
  },
  {
    name: 'manual', group: 'programs', summary: "how to play a game or a demo - its keys, what it is - in a window beside the DOS PC; the one running now if none is named",
    usage: 'manual [GAME]', where: 'here', complete: () => Object.keys(MANUALS), effect: 'shows', data: '{ manual, title }',
    run(ctx) {
      const asked = (ctx.args[0] ?? ctx.app.runningManual ?? '').toLowerCase();
      const key = { field: 'trainer', owlfly3h: 'owlfly3' }[asked] ?? asked;
      if (!key) { ctx.err(`which one? nothing with a manual runs now - manual ${Object.keys(MANUALS).join(' | ')}`); return 1; }
      if (!MANUALS[key]) { ctx.err(`${asked}: no manual - ${Object.keys(MANUALS).join(', ')}`); return 1; }
      ctx.app.showManual(key);
      ctx.data({ manual: key, title: MANUALS[key].title });
      ctx.out(`the manual of ${MANUALS[key].title}`, 'muted');
      return 0;
    },
  },
  {
    name: 'run', group: 'programs', summary: 'a program run on the DOS PC, where it is - run C:\\GAMES\\WIRECITY\\CITY.COM; --net puts it on the network', usage: 'run PROGRAM [--net[=ROOM]]', where: 'here', complete: 'path',
    options: { net: NET_OPTION }, effect: 'runs', data: '{ program, room }',
    async run(ctx) {
      if (!ctx.args[0]) { ctx.err('which program? run C:\\GAMES\\WIRECITY\\CITY.COM'); return 1; }
      const f = await fileOn(ctx, ctx.args[0]);
      if (!/\.(COM|EXE|BAT)$/i.test(f.name)) { ctx.err(`${f.name}: DOS runs a .COM, an .EXE or a .BAT`); return 1; }
      const room = ctx.opts.net ? netRoom(ctx, ctx.opts.net, f.dir) : null;
      if (ctx.opts.net && !room) return 1;
      const go = () => ctx.app.commander.run(f.drive, f.dir, f.name);
      if (room) await ctx.app.withNet(room, go); else go();
      ctx.data({ program: `${f.drive.prefix}${f.dir.replace(/\//g, '\\')}${f.name}`, room });
      ctx.out(`${f.drive.prefix}${f.dir.replace(/\//g, '\\')}${f.name} on the DOS PC${room ? ` - on the network, room ${room}: ${ctx.app.dos.network.state}` : ''}`, 'muted');
    },
  },
  {
    name: 'edit', group: 'programs', summary: 'a file in an editor', usage: 'edit FILE', where: 'here', complete: 'path',
    effect: 'shows', data: '{ file }',
    async run(ctx) {
      if (!ctx.args[0]) { ctx.err('which file? edit A:\\EXAMPLES\\TERRA.ASM'); return 1; }
      const f = await fileOn(ctx, ctx.args[0]);
      await ctx.app.editFile(f.drive, `${f.dir}${f.name}`);
      ctx.data({ file: `${f.drive.prefix}${f.dir.replace(/\//g, '\\')}${f.name}` });
    },
  },
  {
    name: 'build', group: 'programs', where: 'here', complete: 'path',
    summary: "an .ASM assembled with FASM on the DOS PC and run (F9) - a game's by its own MAKE.BAT; FASM's answer here",
    usage: 'build FILE.ASM [--net[=ROOM]] - build A:\\LESSONS\\L07\\LINE.ASM',
    options: { net: NET_OPTION },
    // ok is FASM's verdict when its answer reached this page; null when a game's MAKE.BAT built it.
    effect: 'runs', data: '{ file, ok, text, room }',
    async run(ctx) {
      if (!ctx.args[0]) { ctx.err('which source? build A:\\EXAMPLES\\TERRA.ASM'); return 1; }
      const f = await fileOn(ctx, ctx.args[0]);
      if (!/\.ASM$/i.test(f.name)) { ctx.err(`${f.name}: FASM assembles an .ASM`); return 1; }
      // From A:, as the course page builds: BUILD.BAT beside the source calls A:\TOOLS\FASM.
      if (f.drive.letter !== 'A') { ctx.err(`${f.name}: the DOS PC builds on A: - copy it there (cp ${ctx.args[0]} A:\\) and build it there`); return 1; }
      const app = ctx.app;
      const room = ctx.opts.net ? netRoom(ctx, ctx.opts.net, f.dir) : null;
      if (ctx.opts.net && !room) return 1;
      const go = () => app.build({ dir: `${f.drive.root}${f.dir.slice(1)}`, asm: f.name.toUpperCase() });
      if (room) await app.withNet(room, go); else await go();
      if (room) ctx.out(`on the network: room ${room} (${app.dos.network.state}) - everyone who runs this program with --net here meets there`, 'muted');
      // FASM's last words, if this build is the one they answer (a newer F9 takes over).
      const said = app.lastBuildShown ?? '';
      const answered = /bytes\.|error/i.test(said);
      ctx.data({ file: `A:${f.dir.replace(/\//g, '\\')}${f.name}`, ok: answered ? !/error/i.test(said) : null, text: said, room });
      if (/bytes\.|error/i.test(said)) for (const l of said.split('\n').slice(0, -1)) ctx.out(l, /error/i.test(said) ? 'bad' : 'good');
      else if (/MAKE\.BAT/.test(said)) ctx.out(said, 'muted');
      return /error/i.test(said) ? 1 : 0;
    },
  },
  {
    name: 'lesson', group: 'programs', summary: "a lesson opened: its source, its build, its video - lesson 3, lesson 1C; --reset puts its files back as the course ships them",
    usage: 'lesson NUMBER [--reset]', where: 'here', complete: 'lesson',
    options: { reset: "its files on A: as the course ships them - what was changed in them is gone" },
    effect: 'shows', effects: { reset: 'deletes' }, data: '{ lesson, title, reset }',
    async run(ctx) {
      const w = (ctx.args[0] ?? '').toUpperCase().replace(/^L/, '');
      const all = ctx.app.course?.lessons ?? [];
      const l = all.find(x => x.lecture.toUpperCase() === w) ?? all.find(x => x.id === `L${w.padStart(2, '0')}`);
      if (!l) { ctx.err(`which lesson? ${all.map(x => x.lecture).join(' ')}`); return 1; }
      if (ctx.opts.reset) {
        if (!l.buildable) { ctx.err(`${l.id} has no source to put back`); return 1; }
        await ctx.app.installDisk();
        await ctx.app.install(l, true);
        ctx.data({ lesson: l.lecture, title: l.title, reset: true });
        ctx.out(`${l.id} is on A: as the course ships it - an editor open on it still holds the old text: close it, open it again`, 'good');
        return 0;
      }
      ctx.data({ lesson: l.lecture, title: l.title, reset: false });
      ctx.out(`${l.lecture}  ${l.title}`, 'muted');
      await ctx.app.openLesson(l);
    },
  },
  {
    name: 'dos', group: 'programs', where: 'here', complete: () => ['prompt', 'commander'],
    summary: 'the DOS PC switched on - into what it runs, else what its settings say; or into START: prompt, commander, a game',
    usage: 'dos [START]', effect: 'runs', data: '{ start }',
    async run(ctx) {
      const dos = ctx.app.dos, w = (ctx.args[0] ?? '').toLowerCase();
      if (w && !dos.starts[w]) { ctx.err(`${w}: no such start - ${Object.keys(dos.starts).join(', ')}`); return 1; }
      const start = w || dos.started || dos.settings.start;
      ctx.app.track(dos.run(start));
      ctx.data({ start });
      ctx.out(`the DOS PC: ${dos.starts[start]?.name ?? start}`, 'muted');
      return 0;
    },
  },
  {
    name: 'poweroff', group: 'programs', where: 'here',
    summary: 'the DOS PC switched off - what DOS saved goes back to its drives first; its window closes',
    usage: 'poweroff', effect: 'runs', data: '{ was }',
    async run(ctx) {
      if (!ctx.app.dos.box.running && !ctx.app.dos.win) { ctx.data({ was: 'off' }); ctx.out('the DOS PC is off already', 'muted'); return 0; }
      await ctx.app.powerOff();
      ctx.data({ was: 'on' });
      ctx.out('the DOS PC is off', 'muted');
      return 0;
    },
  },
  {
    name: 'commander', group: 'programs', where: 'here', complete: 'path',
    summary: "Kirin Commander - for Web, the page's two panels, at a drive or a folder each; or for DOS",
    usage: 'commander [dos | [LEFT [RIGHT]]] - commander C:\\GAMES\\WIRECITY A:\\GAMES\\WIRECITY',
    // For DOS it switches the PC on into it - runs, as the contract counts it, and asks no more than shows.
    effect: 'shows', data: '{ left, right } - or { dos: true }',
    async run(ctx) {
      const app = ctx.app, words = ctx.args.filter(w => w !== 'web');
      if (words[0] === 'dos') { app.track(app.dos.run('commander')); ctx.data({ dos: true }); ctx.out('Kirin Commander for DOS, on the DOS PC', 'muted'); return 0; }
      const side = async w => {
        const path = ctx.shell.paths.resolve(w), at = locate(app, path);
        if (at.kind !== 'drive') throw new Error(`${w}: not a drive, nor a folder on one`);
        if (at.drive.letter === 'A') await app.installDisk();
        if (at.sub !== '/' && !await ctx.shell.paths.isDir(path)) throw new Error(`${w}: not a folder`);
        return { drive: at.drive, dir: at.sub === '/' ? '/' : await ctx.shell.paths.spelled(at.drive, at.sub) };
      };
      // As the Files menu has it: A: on the left, D: on the right - or, D: on the left, A: beside it.
      const left = words[0] ? await side(words[0]) : { drive: app.drives[0], dir: '/' };
      const right = words[1] ? await side(words[1]) : { drive: left.drive === app.drives[3] ? app.drives[0] : app.drives[3], dir: '/' };
      await app.panels(left.drive, left.dir, right.drive, right.dir);
      const dos = s => `${s.drive.prefix}${s.dir.replace(/\//g, '\\')}`;
      ctx.data({ left: dos(left), right: dos(right) });
      ctx.out(`Kirin Commander for Web: ${dos(left)} and ${dos(right)}`, 'muted');
      return 0;
    },
  },
];

/** The site's shell: the core's grammar and commands, the site's paths and commands; HOME is D:, My files. */
export function siteShell(app, io) {
  return new Shell({
    app, ...io,
    commands: [...CORE_COMMANDS, ...SITE_COMMANDS],
    groups: [...CORE_GROUPS, ...SITE_GROUPS],
    paths: shell => new SitePaths(shell, app),
    home: '/mnt/d', host: 'wirecity',
  });
}
