// Folders of this browser's storage that ARE a DOS PC's floppies.
//
// "DOS A Drive" in the storage is drive A: of the PC in the page, and "DOS
// B Drive" is B: - not a copy made once, the same files seen from both
// sides. When the PC is switched on, what the folders hold goes onto its
// disks. While it runs, what the page writes there - an upload, a copy, an
// editor's save - goes straight into the PC; and what DOS writes, the page
// finds in the folder within a couple of seconds. Switched off, reloaded,
// days later: the files are in the folders, as they would be on a floppy
// in a drawer.
//
// Floppies, because DOSBox reads a floppy's folder afresh every time DOS
// looks, and keeps a hard disk's in memory: a file the page put on a hard
// disk would stay out of DOS's sight until the next switch-on.
//
// The emulator says what its files are called and how big they are, never
// when they changed - so DOS's changes are found by size, and every few
// rounds by content.

import { DosDrive } from '../files/dosdrive.js';

/** The words a gate folder holds about itself: the same file is A:\README.TXT in DOS. */
const README = letter => `This folder is drive ${letter}: of the DOS PC on this page.

Whatever is here, DOS finds on ${letter}:, and what DOS saves on ${letter}:
comes back here - the PC in the page and this browser's storage share
it, as a floppy is shared by being carried between two machines.

Put files here from Tools > Commander - F5 copies, F2 uploads them from
your computer - then open DOS > Commander on DOS, choose drive ${letter}:
(Alt+F1 or Alt+F2) and press Enter on a program to run it. It stays here
after the page is closed.

DOS names are 8.3: up to eight letters, a dot, three more. A longer name
is shown to DOS cut short, as PROGRA~1.TXT. A floppy has room for about
1.4 MB of what DOS writes; the page may put bigger files here.
`.replace(/\n/g, '\r\n');

/** A quick fingerprint of some bytes: FNV-1a, 32 bits. */
function fingerprint(bytes) {
  let h = 0x811c9dc5;
  for (let i = 0; i < bytes.length; i++) h = Math.imul(h ^ bytes[i], 0x01000193);
  return h >>> 0;
}

export class DriveGates {
  /**
   * box: the DosBox. storage: the BrowserStorage the folders are in.
   * gates: [{ letter, folder }], e.g. { letter: 'A', folder: '/DOS A Drive/' }.
   */
  constructor(box, storage, gates) {
    this.box = box;
    this.storage = storage;
    this.gates = gates.map(g => ({
      letter: g.letter,
      folder: g.folder.replace(/\/?$/, '/'),
      drive: new DosDrive(box, { folder: g.letter, letter: g.letter }),
    }));
    this.known = new Map();   // the emulator's path -> { size, print } (print null for a folder)
    this.round = 0;
    this.empty = [];          // folders with nothing in them, made in DOS after the switch-on
    this.activity = () => {}; // (letter): a disk was read or written - the drive's light
    this.pushed = () => {};   // (letter): the page put something on a disk DOS is showing
    storage.watch((kind, path, echo) => { if (!echo) this.push(kind, path).catch(() => {}); });
  }

  /** The gate a storage path is in, if any. */
  gateOf(path) {
    return this.gates.find(g => path === g.folder.slice(0, -1) || path.startsWith(g.folder));
  }

  /** A storage path as a gate's own: /DOS A Drive/RUN/X.EXE is /RUN/X.EXE on A:. */
  inside(g, path) {
    return '/' + path.slice(g.folder.length).replace(/\/+$/, '');
  }

  /** As DOS writes it: A:\RUN\X.EXE. */
  dosPath(path) {
    const g = this.gateOf(path);
    return g ? `${g.letter}:${this.inside(g, path).replace(/\//g, '\\')}` : null;
  }

  /** The folders there, each with its README - the first visit makes them. */
  async ensure() {
    for (const g of this.gates) {
      let names;
      try { names = (await this.storage.list(g.folder)).map(e => e.name); } catch { names = null; }
      if (!names) await this.storage.mkdir(g.folder);
      if (!names?.includes('README.TXT')) await this.storage.write(`${g.folder}README.TXT`, README(g.letter));
    }
  }

  /** Everything in the folders, for the disks of a PC switching on: [{ path, contents }]. */
  async files() {
    await this.ensure();
    this.known.clear();
    this.empty = [];
    const out = [];
    const walk = async (g, dir) => {
      const entries = await this.storage.list(dir);
      if (entries.length === 0 && dir !== g.folder) this.empty.push({ g, dir });
      for (const e of entries) {
        const path = `${dir}${e.name}`;
        const emu = `${g.letter}${this.inside(g, path)}`;
        if (e.dir) {
          this.known.set(emu, { size: 0, print: null });
          await walk(g, `${path}/`);
        } else {
          const contents = await this.storage.readBytes(path);
          this.known.set(emu, { size: contents.length, print: fingerprint(contents) });
          out.push({ path: emu, contents });
        }
      }
    };
    for (const g of this.gates) await walk(g, g.folder);
    return out;
  }

  /** After the switch-on: the empty folders, which a list of files cannot carry. */
  async started() {
    for (const { g, dir } of this.empty) await g.drive.mkdir(this.inside(g, dir)).catch(() => {});
  }

  /** The page changed something in a gate folder: the same change on the running PC's disk. */
  async push(kind, path) {
    const g = this.gateOf(path);
    if (!g || !this.box.running) return;
    const rel = this.inside(g, path);
    const emu = `${g.letter}${rel}`;
    if (kind === 'remove') {
      await g.drive.remove(rel).catch(() => {});
      for (const k of [...this.known.keys()]) if (k === emu || k.startsWith(`${emu}/`)) this.known.delete(k);
    } else if (kind === 'mkdir') {
      await g.drive.mkdir(rel);
      this.known.set(emu, { size: 0, print: null });
    } else {
      // A file - or a folder moved in whole, whose files go one by one.
      let contents = null;
      try { contents = await this.storage.readBytes(path.replace(/\/+$/, '')); } catch { /* a folder */ }
      if (contents) {
        await g.drive.write(rel, contents);
        this.known.set(emu, { size: contents.length, print: fingerprint(contents) });
      } else {
        for (const e of await this.storage.list(`${path.replace(/\/+$/, '')}/`)) {
          await this.push(e.dir ? 'mkdir' : 'write', `${path.replace(/\/+$/, '')}/${e.name}`);
          if (e.dir) await this.push('write', `${path.replace(/\/+$/, '')}/${e.name}/`);
        }
      }
    }
    this.activity(g.letter);
    this.pushed(g.letter);
  }

  /**
   * What DOS changed on the disks, into the folders. True if anything was.
   * A file whose size changed is read; every fifth round, every file is,
   * for an edit that kept the size.
   */
  async pull() {
    if (!this.box.running) return false;
    const ci = this.box.ci;
    const tree = await ci.fsTree();
    const thorough = this.round++ % 5 === 0;
    let changed = false;
    for (const g of this.gates) {
      const seen = new Set();
      const walk = async (node, emu) => {
        for (const n of node.nodes ?? []) {
          const path = `${emu}/${n.name}`;
          const where = `${g.folder}${path.slice(2)}`;
          seen.add(path);
          const was = this.known.get(path);
          if (n.nodes) {
            if (!was) {
              await this.storage.hush(() => this.storage.mkdir(`${where}/`));
              this.known.set(path, { size: 0, print: null });
              changed = true;
            }
            await walk(n, path);
          } else if (!was || was.size !== n.size || (thorough && n.size < 262144)) {
            const contents = new Uint8Array(await ci.fsReadFile(path));
            const print = fingerprint(contents);
            if (!was || was.print !== print || was.size !== contents.length) {
              await this.storage.hush(() => this.storage.write(where, contents));
              this.known.set(path, { size: contents.length, print });
              changed = true;
            }
          }
        }
      };
      const root = (tree.nodes ?? []).find(n => n.name === g.letter);
      if (!root) continue;
      await walk(root, g.letter);
      // What DOS deleted: known here, gone there - deepest first.
      const gone = [...this.known.keys()].filter(k => k.startsWith(`${g.letter}/`) && !seen.has(k)).sort((a, b) => b.length - a.length);
      for (const k of gone) {
        this.known.delete(k);
        await this.storage.hush(() => this.storage.remove(`${g.folder}${k.slice(2)}`)).catch(() => {});
        changed = true;
      }
      if (changed) this.activity(g.letter);
    }
    return changed;
  }
}
