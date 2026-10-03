// A disk of the DOS machine running in this page (../dosbox/dosbox.js), as
// a place for files like any other in this folder: list(dir), read(path),
// readBytes(path), write(path, text or bytes), remove(path), mkdir(path),
// rename(from, to).
//
// The machine's disks live in the emulator's memory, and js-dos lets the
// page read and write them while DOS runs. DOSBox remembers what a folder
// held the last time DOS looked, so a file the page puts on a hard disk
// stays invisible to DOS until it looks again from scratch - except on a
// floppy, which DOSBox reads afresh every time, because a floppy can be
// swapped. So the disk the page and DOS share is a floppy, A:, and that is
// also the honest picture of it: the floppy you carried between machines.
//
// `folder` is where the disk is in the emulator's file system: the demo
// mounts A: from a folder called A.

export class DosDrive {
  constructor(dosbox, { folder = 'A', letter = 'A' } = {}) {
    this.dosbox = dosbox;
    this.folder = folder;
    this.title = `the DOS machine's floppy ${letter}:`;
    this.about = `Drive ${letter}: of the DOS machine running in this page: what DOS saves there, the page sees, and back.`;
    this.prefix = `dos-${letter.toLowerCase()}:`;
    this.changed = () => {};
  }

  get ci() {
    const ci = this.dosbox.ci;
    if (!ci) throw new Error('No DOS machine is running. DOS > Commander in DOS starts one.');
    return ci;
  }

  /** The emulator's name for a path here: /X/Y.TXT is A/X/Y.TXT. */
  real(path) {
    return this.folder + path.replace(/\/+$/, '');
  }

  async node(dir) {
    let n = await this.ci.fsTree();
    for (const part of this.real(dir).split('/').filter(Boolean)) {
      n = (n.nodes ?? []).find(x => x.name === part);
      if (!n) throw new Error(`There is no ${dir} on the DOS disk.`);
    }
    if (!n.nodes) throw new Error(`${dir} is a file, not a folder.`);
    return n;
  }

  async list(dir) {
    // No dates: the emulator's file system does not give them out. The
    // panel leaves the column empty rather than invent one.
    return (await this.node(dir)).nodes.map(n => ({ name: n.name, size: n.size ?? 0, date: null, dir: n.nodes !== null }));
  }

  async readBytes(path) {
    return new Uint8Array(await this.ci.fsReadFile(this.real(path)));
  }

  async read(path) {
    return new TextDecoder().decode(await this.readBytes(path));
  }

  async write(path, data) {
    const bytes = typeof data === 'string' ? new TextEncoder().encode(data)
      : data instanceof Blob ? new Uint8Array(await data.arrayBuffer()) : data;
    await this.ci.fsWriteFile(this.real(path), bytes);
    this.changed();
  }

  /** A file, or a folder and everything in it. */
  async remove(path) {
    const name = path.replace(/\/+$/, '');
    const dir = name.slice(0, name.lastIndexOf('/') + 1) || '/';
    const me = (await this.list(dir)).find(e => e.name === name.slice(name.lastIndexOf('/') + 1));
    if (me?.dir) {
      for (const e of await this.list(`${name}/`)) await this.remove(`${name}/${e.name}`);
    }
    await this.ci.fsDeleteFile(this.real(name));
    this.changed();
  }

  /** A folder: the emulator makes the folders a file is written into, so one is written and taken away. */
  async mkdir(path) {
    const dir = path.replace(/\/+$/, '');
    await this.ci.fsWriteFile(`${this.real(dir)}/.KEEP`, new Uint8Array(0));
    await this.ci.fsDeleteFile(`${this.real(dir)}/.KEEP`);
    this.changed();
  }

  async rename() {
    // There is no move in js-dos's interface: the caller copies and deletes.
    throw new Error('The DOS disk cannot rename from the page.');
  }
}
