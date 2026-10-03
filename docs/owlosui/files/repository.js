// The examples' own sources, read-only: the folder RUN.CMD's server serves
// the pages from. A folder's names come back as JSON when it is asked with
// ?list, a file is a GET, and nothing can be changed - which is why it is a
// good place to copy from: the demo's file manager starts its other side
// here, so there is something real to look at, view in colour and copy.
//
// A static host - GitHub Pages - answers no ?list. For one, the site's
// build writes every folder's names into one file, listing.json, beside
// the folder, and a list that ?list cannot give is read from there.
//
// Like every source in this folder: list(dir), read(path), readBytes(path);
// write, remove, mkdir and rename say that it is read-only.

export class Repository {
  /** base: the folder, as a URL; by default this repository's Examples, wherever the page is served from. */
  constructor(base = new URL('../../../Examples', import.meta.url).href) {
    this.base = base.replace(/\/+$/, '');
    this.listing = null;
    this.title = 'the examples (read-only)';
    this.about = "This project's Examples folder, as the server shows it: read it, copy from it.";
    this.prefix = 'examples:';
    this.readOnly = true;
  }

  url(path) {
    return this.base + path.split('/').map(encodeURIComponent).join('/');
  }

  async fetch(path, suffix = '') {
    let r;
    try {
      r = await fetch(this.url(path) + suffix);
    } catch {
      throw new Error(`The server did not answer at ${this.base}. Is RUN.CMD still running?`);
    }
    if (!r.ok) throw new Error(`The server said ${r.status} ${r.statusText} for ${path}.`);
    return r;
  }

  async list(dir) {
    let entries;
    try {
      const r = await fetch(this.url(dir) + '?list');
      if (r.ok && (r.headers.get('content-type') ?? '').includes('json')) entries = await r.json();
    } catch { /* no server here: the listing file, below */ }
    entries ??= await this.fromListing(dir);
    return entries.map(e => ({ name: e.name, size: e.size, date: new Date(e.modified * 1000), dir: e.dir }));
  }

  /** A folder out of listing.json: { "/": [entries], "/DOS/": [...] }, every folder by its path. */
  async fromListing(dir) {
    if (!this.listing) {
      let r;
      try { r = await fetch(`${this.base}/listing.json`); } catch { r = null; }
      if (!r?.ok) throw new Error(`Nothing lists ${this.base}: not the demo's server, and no listing.json. Is RUN.CMD still running?`);
      this.listing = await r.json();
    }
    const entries = this.listing[dir];
    if (!entries) throw new Error(`There is no ${dir} in the examples.`);
    return entries;
  }

  async read(path) {
    return (await this.fetch(path)).text();
  }

  async readBytes(path) {
    return new Uint8Array(await (await this.fetch(path)).arrayBuffer());
  }

  async write() { throw new Error('The examples are read-only: copy to the other side first.'); }
  async remove() { throw new Error('The examples are read-only.'); }
  async mkdir() { throw new Error('The examples are read-only.'); }
  async rename() { throw new Error('The examples are read-only.'); }
}
