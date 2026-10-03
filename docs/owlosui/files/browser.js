// This browser's own storage for the page: the Origin Private File System.
//
// Every modern browser keeps a small private disk for each site - Chrome,
// Edge, Firefox and Safari all have it - and a page may make folders and
// files in it without asking anyone. Nothing is uploaded; nothing outside
// this site can see it; clearing the site's data empties it. The name for
// it is OPFS, and a person trying the demo does not need to know that:
// the demo calls it "this browser's storage".
//
// Like every source in this folder: list(dir), read(path), readBytes(path),
// write(path, text or bytes), remove(path), mkdir(path), rename(from, to),
// with paths as /folder/file.txt and folders ending in /.

const WELCOME = `This file is in this browser's own storage.

Every modern browser keeps a small private disk for each web site. This
page can make files and folders in it; nothing is sent anywhere, and no
other site can see it. Browsers call it OPFS, the Origin Private File
System. Clearing this site's data in the browser's settings empties it.

Try it: change this text, press F2 to save, then open it again from
File > Open from > This browser's storage.
`;

export class BrowserStorage {
  /**
   * samples: files to put in the storage the first time it is opened, as
   * [path here, URL to fetch it from] pairs - a URL without a scheme is
   * taken from this site's root. Each is fetched once; one that is
   * missing is left out, and one deleted later stays deleted.
   */
  constructor({ samples = [] } = {}) {
    this.title = "this browser's storage";
    this.about =
      'Files this browser keeps for this page, on this computer. Nothing is uploaded, and it works offline.';
    this.prefix = 'browser:';
    this.samples = samples;
    this.seeded = null;
    this.watchers = new Set();
    this.quiet = 0;
  }

  /**
   * Hear of every change made through this object: f(kind, path, echo) -
   * kind 'write', 'remove' or 'mkdir'. echo is true for a change made while
   * hush() runs: one that came FROM whoever is listening, which it should
   * not carry back to where it came from.
   */
  watch(f) { this.watchers.add(f); return () => this.watchers.delete(f); }
  changed(kind, path) { for (const f of this.watchers) f(kind, path, this.quiet > 0); }
  async hush(work) {
    this.quiet++;
    try { return await work(); } finally { this.quiet--; }
  }

  /** The first visit's files: WELCOME.TXT into an empty storage, and the samples once ever. */
  seed() {
    this.seeded ??= (async () => {
      const root = await this.root();
      let empty = true;
      for await (const _ of root.keys()) { empty = false; break; }
      if (empty) await this.write('/WELCOME.TXT', WELCOME);
      // Remembered beside the files, so clearing the site's data brings
      // the samples back along with the empty storage.
      const done = await root.getFileHandle('.samples', { create: false }).then(() => true, () => false);
      if (done || this.samples.length === 0) return;
      const origin = globalThis.location?.origin ?? '';
      for (const [path, from] of this.samples) {
        try {
          const r = await fetch(/^\w+:/.test(from) ? from : `${origin}/${from}`);
          if (r.ok) await this.write(path, new Uint8Array(await r.arrayBuffer()));
        } catch { /* not there: left out */ }
      }
      await this.write('/.samples', 'The samples were put here once; delete this file to have them again.\n');
    })();
    return this.seeded;
  }

  async root() {
    if (!globalThis.navigator?.storage?.getDirectory) {
      throw new Error("This browser has no storage for a page's files. Chrome, Edge, Firefox and Safari have it.");
    }
    return navigator.storage.getDirectory();
  }

  async folder(dir, create = false) {
    let h = await this.root();
    for (const part of dir.split('/').filter(Boolean)) h = await h.getDirectoryHandle(part, { create });
    return h;
  }

  async list(dir) {
    await this.seed();
    const folder = await this.folder(dir);
    const out = [];
    for await (const [name, h] of folder.entries()) {
      if (dir === '/' && name === '.samples') continue;
      if (h.kind === 'directory') out.push({ name, size: 0, date: new Date(), dir: true });
      else {
        const f = await h.getFile();
        out.push({ name, size: f.size, date: new Date(f.lastModified), dir: false });
      }
    }
    return out;
  }

  async read(path) {
    const { dir, name } = split(path);
    const h = await (await this.folder(dir)).getFileHandle(name);
    return (await h.getFile()).text();
  }

  async readBytes(path) {
    const { dir, name } = split(path);
    const h = await (await this.folder(dir)).getFileHandle(name);
    return new Uint8Array(await (await h.getFile()).arrayBuffer());
  }

  /** Text, or bytes: a Uint8Array or a Blob, saved as they are. */
  async write(path, data) {
    const { dir, name } = split(path);
    const h = await (await this.folder(dir, true)).getFileHandle(name, { create: true });
    if (!h.createWritable) {
      throw new Error('This browser can read its storage but not save to it from a page yet.');
    }
    const w = await h.createWritable();
    await w.write(data);
    await w.close();
    this.changed('write', path);
  }

  /** A file, or a folder with everything in it. */
  async remove(path) {
    const { dir, name } = split(path.replace(/\/$/, ''));
    await (await this.folder(dir)).removeEntry(name, { recursive: true });
    this.changed('remove', path);
  }

  async mkdir(path) {
    await this.folder(path, true);
    this.changed('mkdir', path);
  }

  /**
   * A new name in the same storage. Browsers that can move an entry do it
   * in one step; the others are told no, and the caller copies and deletes.
   */
  async rename(from, to) {
    const f = split(from.replace(/\/$/, ''));
    const t = split(to.replace(/\/$/, ''));
    const parent = await this.folder(f.dir);
    let h;
    try { h = await parent.getFileHandle(f.name); } catch { h = await parent.getDirectoryHandle(f.name); }
    if (!h.move) throw new Error('This browser cannot rename in its storage.');
    await h.move(await this.folder(t.dir, true), t.name);
    // What moved, gone from one place and - a file, or a folder whole - in another.
    this.changed('remove', from);
    this.changed('write', to);
  }
}

/** /a/b/c.txt into its folder, /a/b/, and its name, c.txt. */
export function split(path) {
  const cut = path.lastIndexOf('/');
  return { dir: path.slice(0, cut + 1) || '/', name: path.slice(cut + 1) };
}
