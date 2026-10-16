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

import { Shell } from '../console/shell.js';
import { CORE_COMMANDS, CORE_GROUPS } from '../console/commands.js';
import { statsOf, sizeText, dateText, LocalFolder } from './drives.js';

/** A path's place: the root, /mnt, or a drive and the path inside it ('/' its top). */
function locate(app, path) {
  if (path === '/') return { kind: 'root' };
  const m = /^\/mnt(?:\/([a-z])(\/.*)?)?$/i.exec(path);
  if (!m) return { kind: 'none' };
  if (!m[1]) return { kind: 'mnt' };
  const drive = app.drives.find(d => d.letter === m[1].toUpperCase());
  return drive ? { kind: 'drive', drive, sub: m[2] ?? '/' } : { kind: 'none' };
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
    return [];
  }
}

/** A path to a drive and a file in it: { drive, dir, name } - dir ends in /, as the commander's do. */
async function fileOn(ctx, word) {
  const paths = ctx.shell.paths, path = paths.resolve(word);
  const at = locate(ctx.app, path);
  if (at.kind !== 'drive' || at.sub === '/') throw new Error(`${word}: not a file on a drive`);
  const spelled = (await paths.spelled(at.drive, at.sub)).replace(/\/$/, '');
  const cut = spelled.lastIndexOf('/');
  return { drive: at.drive, dir: spelled.slice(0, cut + 1), name: spelled.slice(cut + 1), path };
}

export const SITE_GROUPS = [['drives', 'Drives and the DOS PC'], ['programs', 'Games, programs, lessons']];

export const SITE_COMMANDS = [
  // ------------------------------------------------------------ drives
  {
    name: 'mount', group: 'drives', where: 'here', complete: 'letter',
    summary: 'the drives, a letter each - or a new one: a folder of this browser, a folder of this computer, a link to a ZIP',
    usage: 'mount [LETTER: FOLDER | LETTER: https://LINK | LETTER: --computer [--write]]',
    options: { computer: 'a folder of this computer, through the browser\'s picker (Chrome, Edge)', write: 'DOS may write to that folder' },
    async run(ctx) {
      const app = ctx.app;
      if (!ctx.args.length && !ctx.opts.computer) {
        for (const d of app.drives) {
          ctx.data({ letter: d.letter, kind: d.kind, what: d.title, where: d.where });
          ctx.out(`${d.prefix}  ${d.kind.padEnd(11)} ${d.title.padEnd(24)} ${d.where}`, 'ABCD'.includes(d.letter) ? 'text' : 'info');
        }
        return 0;
      }
      const letter = (ctx.args[0] ?? '').replace(/:$/, '').toUpperCase();
      if (!/^[E-Z]$/.test(letter)) { ctx.err('a new drive takes a letter from E: to Z: - mount E: GAMES'); return 1; }
      if (app.drives.some(d => d.letter === letter)) { ctx.err(`${letter}: is taken - umount ${letter}: first, or another letter`); return 1; }
      const what = ctx.args.slice(1).join(' ');
      if (ctx.opts.computer) {
        if (!globalThis.showDirectoryPicker) { ctx.err('this browser cannot give a page a folder of this computer: Chrome and Edge can'); return 1; }
        const handle = await showDirectoryPicker({ mode: ctx.opts.write ? 'readwrite' : 'read' });
        await app.addDrive({ letter, kind: 'local', title: what || handle.name, write: !!ctx.opts.write, handle });
      } else if (/^https?:\/\//i.test(what)) {
        const r = await fetch(what).catch(() => null);
        if (!r) { ctx.err('that site does not let a page take its files - download the ZIP and add it in Files > Map Drives'); return 1; }
        if (!r.ok) { ctx.err(`${what}: ${r.status} ${r.statusText}`); return 1; }
        await app.addZip(letter, { kind: 'link', title: decodeURIComponent(what.split(/[?#]/)[0].split('/').pop() || 'link'), url: what }, new Uint8Array(await r.arrayBuffer()));
      } else {
        if (!what) { ctx.err(`which folder? mount ${letter}: NAME - a folder of this browser, made if it is not there`); return 1; }
        const name = what.replace(/[\\/:*?"<>|]/g, ' ').trim();
        await app.browser.mkdir(`/${name}/`);
        await app.addDrive({ letter, kind: 'folder', title: name, folder: `/${name}/` });
      }
      app.afterTable();
      const d = app.drives.find(x => x.letter === letter);
      ctx.out(`${letter}: ${d.kind} - ${d.title} (${d.where}); DOS sees it at its next switch-on`, 'good');
      return 0;
    },
  },
  {
    name: 'umount', group: 'drives', summary: 'a drive taken off its letter - its files stay where they are', usage: 'umount LETTER:', where: 'here', complete: 'letter',
    async run(ctx) {
      const letter = (ctx.args[0] ?? '').replace(/:$/, '').toUpperCase();
      const d = ctx.app.drives.find(x => x.letter === letter);
      if (!d) { ctx.err(`${ctx.args[0] ?? '?'}: no such drive (mount lists them)`); return 1; }
      if ('ABCD'.includes(letter)) { ctx.err(`${letter}: is one of the machine's own four - A: to D: stay`); return 1; }
      await ctx.app.removeDrive(d);
      ctx.out(`${letter}: free again; its files are where they were (${d.where})`, 'muted');
      return 0;
    },
  },
  {
    name: 'df', group: 'drives', summary: "what each drive holds, and how much of this browser's room they take", usage: 'df', where: 'here',
    async run(ctx) {
      ctx.out(`${'drive'.padEnd(7)}${'kind'.padEnd(12)}${'files'.padStart(6)}${'size'.padStart(10)}  changed`, 'heading');
      for (const d of ctx.app.drives) {
        let s = null;
        try { s = d.base instanceof LocalFolder && !ctx.app.mounted(d) ? null : await statsOf(d); } catch { /* not readable now */ }
        ctx.data({ letter: d.letter, kind: d.kind, files: s?.files ?? null, bytes: s?.bytes ?? null, newest: s?.newest ?? null, where: d.where });
        ctx.out(`${d.prefix.padEnd(7)}${d.kind.padEnd(12)}${(s ? String(s.files) : '-').padStart(6)}${(s ? sizeText(s.bytes) : '-').padStart(10)}  ${s ? dateText(s.newest) : 'asks to be let in'}`);
      }
      const est = await navigator.storage?.estimate?.().catch(() => null);
      if (est) ctx.out(`this browser holds ${sizeText(est.usage ?? 0)} of the ${sizeText(est.quota ?? 0)} it allows this site - a clean-up of the site's data takes it all: profile > D:\\PROFILE.TXT`, 'warn');
    },
  },
  {
    name: 'du', group: 'drives', summary: 'how much a folder holds', usage: 'du [PATH]', where: 'here', complete: 'path',
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
    name: 'mkdir', group: 'files', summary: 'a folder', usage: 'mkdir PATH', where: 'here', complete: 'path',
    async run(ctx) {
      for (const w of ctx.args) {
        const path = ctx.shell.paths.resolve(w), at = locate(ctx.app, path);
        if (at.kind !== 'drive' || at.sub === '/') { ctx.err(`${w}: a folder is made inside a drive`); return 1; }
        await at.drive.mkdir(`${await ctx.shell.paths.spelled(at.drive, at.sub)}`);
      }
    },
  },
  {
    name: 'cp', group: 'files', summary: 'a file copied - to a folder, or to a new name; from one drive to another too', usage: 'cp FILE DEST', where: 'here', complete: 'path',
    async run(ctx) {
      const [from, to] = ctx.args;
      if (!from || !to) { ctx.err('cp FILE DEST'); return 1; }
      const src = await fileOn(ctx, from);
      const bytes = await src.drive.readBytes(`${src.dir}${src.name}`);
      const destPath = ctx.shell.paths.resolve(to);
      const into = await ctx.shell.paths.isDir(destPath);
      const dest = await fileOn(ctx, into ? `${destPath}/${src.name}` : to);
      await dest.drive.write(`${dest.dir}${dest.name}`, bytes);
      ctx.out(`${src.path} -> ${dest.path}`, 'muted');
    },
  },
  {
    name: 'mv', group: 'files', summary: 'a file moved or renamed', usage: 'mv FILE DEST', where: 'here', complete: 'path',
    async run(ctx) {
      const code = await ctx.shell.commands.get('cp').run(ctx);
      if (code) return code;
      const src = await fileOn(ctx, ctx.args[0]);
      await src.drive.remove(`${src.dir}${src.name}`);
    },
  },
  {
    name: 'rm', group: 'files', summary: 'a file gone - or a folder and all in it (-r)', usage: 'rm [-r] PATH...', where: 'here', complete: 'path', options: { r: 'a folder, with all in it' },
    async run(ctx) {
      for (const w of ctx.args) {
        const path = ctx.shell.paths.resolve(w), at = locate(ctx.app, path);
        if (at.kind !== 'drive' || at.sub === '/') { ctx.err(`${w}: only files and folders inside a drive (umount takes a drive off its letter)`); return 1; }
        if (await ctx.shell.paths.isDir(path) && !ctx.opts.r) { ctx.err(`${w}: a folder - rm -r takes it and all in it`); return 1; }
        await at.drive.remove(`${await ctx.shell.paths.spelled(at.drive, at.sub)}`.replace(/\/$/, ctx.opts.r ? '/' : ''));
      }
    },
  },
  {
    name: 'profile', group: 'drives', where: 'here',
    summary: 'the commands that set this browser up again - the drives you added, your aliases; profile > D:\\PROFILE.TXT, source it back',
    usage: 'profile',
    run(ctx) {
      const app = ctx.app, sh = ctx.shell;
      ctx.out('# WIRE CITY - this browser set up again: source this file');
      for (const d of app.drives.filter(x => !'ABCD'.includes(x.letter))) {
        const e = d.entry ?? {};
        if (e.kind === 'folder') ctx.out(`mount ${d.prefix} ${e.folder.slice(1, -1)}`);
        else if (e.kind === 'link') ctx.out(`mount ${d.prefix} ${e.url}`);
        else if (e.kind === 'local') ctx.out(`# ${d.prefix} the folder ${d.title} of this computer: mount ${d.prefix} --computer${e.write ? ' --write' : ''}`);
        else ctx.out(`# ${d.prefix} ${d.title}: a copy of a ZIP, in this browser's ${e.folder} - add the ZIP again in Files > Map Drives`);
      }
      for (const [k, v] of sh.aliases) if (!sh.builtinAliases.has(k)) ctx.out(`alias ${k}='${v}'`);
      for (const [k, v] of Object.entries(sh.env)) if (!['HOME', 'USER', '?'].includes(k)) ctx.out(`export ${k}=${v}`);
    },
  },

  // ------------------------------------------------------------ games, programs, lessons
  {
    name: 'play', group: 'programs', summary: 'a game: the machine on, in its folder on C:', usage: 'play GAME', where: 'here', complete: 'game',
    run(ctx) {
      const w = (ctx.args.join(' ') || '').toLowerCase();
      const g = ctx.app.games.find(x => x.key === w || x.name.toLowerCase() === w || x.dir.toLowerCase() === w);
      if (!g) { ctx.err(`which game? ${ctx.app.games.map(x => x.key).join(', ')}`); return 1; }
      ctx.app.play(g);
      ctx.out(`${g.name}: C:\\GAMES\\${g.dir}, RUN`, 'muted');
    },
  },
  {
    name: 'run', group: 'programs', summary: 'a program run on the DOS PC, where it is - run C:\\GAMES\\WIRECITY\\CITY.COM', usage: 'run PROGRAM', where: 'here', complete: 'path',
    async run(ctx) {
      if (!ctx.args[0]) { ctx.err('which program? run C:\\GAMES\\WIRECITY\\CITY.COM'); return 1; }
      const f = await fileOn(ctx, ctx.args[0]);
      if (!/\.(COM|EXE|BAT)$/i.test(f.name)) { ctx.err(`${f.name}: DOS runs a .COM, an .EXE or a .BAT`); return 1; }
      ctx.app.commander.run(f.drive, f.dir, f.name);
      ctx.out(`${f.drive.prefix}${f.dir.replace(/\//g, '\\')}${f.name} on the DOS PC`, 'muted');
    },
  },
  {
    name: 'edit', group: 'programs', summary: 'a file in an editor', usage: 'edit FILE', where: 'here', complete: 'path',
    async run(ctx) {
      if (!ctx.args[0]) { ctx.err('which file? edit A:\\EXAMPLES\\TERRA.ASM'); return 1; }
      const f = await fileOn(ctx, ctx.args[0]);
      ctx.app.commander.open(f.name, await f.drive.read(`${f.dir}${f.name}`), f.drive, `${f.dir}${f.name}`, { readOnly: f.drive.readOnly });
    },
  },
  {
    name: 'build', group: 'programs', summary: 'an .ASM assembled with FASM on the DOS PC, then run (F9) - a game by its own MAKE.BAT', usage: 'build FILE.ASM', where: 'here', complete: 'path',
    async run(ctx) {
      if (!ctx.args[0]) { ctx.err('which source? build A:\\EXAMPLES\\TERRA.ASM'); return 1; }
      const f = await fileOn(ctx, ctx.args[0]);
      if (!/\.ASM$/i.test(f.name)) { ctx.err(`${f.name}: FASM assembles an .ASM`); return 1; }
      await ctx.app.commander.associations.asm({ source: f.drive, dir: f.dir, name: f.name, path: `${f.dir}${f.name}`, commander: ctx.app.commander });
      ctx.out(`${f.name}: FASM on the DOS PC - its words in the Build strip`, 'muted');
    },
  },
  {
    name: 'lesson', group: 'programs', summary: 'a lesson opened: its source, its build, its video - lesson 3, lesson 1C', usage: 'lesson NUMBER', where: 'here', complete: 'lesson',
    async run(ctx) {
      const w = (ctx.args[0] ?? '').toUpperCase().replace(/^L/, '');
      const all = ctx.app.course?.lessons ?? [];
      const l = all.find(x => x.lecture.toUpperCase() === w) ?? all.find(x => x.id === `L${w.padStart(2, '0')}`);
      if (!l) { ctx.err(`which lesson? ${all.map(x => x.lecture).join(' ')}`); return 1; }
      ctx.out(`${l.lecture}  ${l.title}`, 'muted');
      await ctx.app.openLesson(l);
    },
  },
  {
    name: 'commander', group: 'programs', summary: 'Kirin Commander - for Web (the page\'s two panels), or for DOS', usage: 'commander [web|dos]', where: 'here',
    complete: () => ['web', 'dos'],
    async run(ctx) {
      if ((ctx.args[0] ?? 'web') === 'dos') { ctx.app.dos.run('commander'); return 0; }
      await ctx.app.panels(ctx.app.drives[0]);
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
