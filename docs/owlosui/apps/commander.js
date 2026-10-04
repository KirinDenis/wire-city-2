// A two-panel file manager in the page, the same one the desktop and DOS
// have, over the places a page can keep files: the page gives them
// (`sources`, lib/js/files/) - its own read-only files, this browser's
// storage, the server's folder, a WebDAV share.
//
// A "drive" here is one of those places, and Alt+F1 / Alt+F2 choose one
// for the left or the right side, as a drive letter was chosen on DOS.
// Between any two of them the keys are
// Volkov Commander's: F3 view, F4 edit, F5 copy, F6 rename or move, F7 make
// a folder, F8 delete, Insert marks, Tab the other side, Ctrl+U swaps the
// sides, Ctrl+R reads the folder again, Enter goes into a folder or opens
// a file the way its extension says (ASSOCIATIONS, below, or the page's
// own: a course assembles an .ASM and runs it).
//
// And what only a browser needs, on F2 - VC's user menu: upload files from
// this computer into the side in front, download the marked files to it.
// Dropping files on the page uploads them too.
//
// The two panels are ordinary windows that carry their keys: in front, F5
// is Copy; behind another window, F5 is the page's again.

import { Style } from '../owlosui.js';

const Cm = {
  View: 300, Edit: 301, Copy: 302, Move: 303, MkDir: 304, Delete: 305, Switch: 306,
  DriveLeft: 307, DriveRight: 308, Computer: 309, Close: 310, Swap: 311, Reread: 312,
  Yes: 320, No: 321, MkDirOk: 322, DriveOk: 323, CopyOk: 324, Upload: 325, Download: 326,
};

/**
 * What Enter does with a file, by its extension - VC.EXT's idea - unless
 * the page gives its own (`associations`). A DOS program runs on the
 * page's DOS PC; a picture goes to the browser, which shows pictures;
 * anything else is opened in an editor if it is text, or as bytes if it
 * is not. An action is one of the words 'program', 'browser', 'edit',
 * 'view', 'hex', or a function of { source, dir, name, path, commander },
 * which may return a promise: a course's "assemble it and run it".
 */
export const ASSOCIATIONS = {
  com: 'program', exe: 'program', bat: 'program',
  png: 'browser', jpg: 'browser', jpeg: 'browser', gif: 'browser', bmp: 'browser', svg: 'browser', webp: 'browser',
  pdf: 'browser', htm: 'browser', html: 'browser',
};
const TYPES = {
  png: 'image/png', jpg: 'image/jpeg', jpeg: 'image/jpeg', gif: 'image/gif', bmp: 'image/bmp',
  svg: 'image/svg+xml', webp: 'image/webp', pdf: 'application/pdf', htm: 'text/html', html: 'text/html',
};

const ext = name => (name.includes('.') ? name.slice(name.lastIndexOf('.') + 1).toLowerCase() : '');

/** A zero byte early on: not a text, whatever its name says. */
export function binary(bytes) {
  const n = Math.min(bytes.length, 4096);
  for (let i = 0; i < n; i++) if (bytes[i] === 0) return true;
  return false;
}

export class CommanderTool {
  static CmFirst = 300;
  static CmLast = 349;

  /**
   * sources: the drives, in the order Alt+F1 lists them; left and right,
   * which two the sides start on. open(name, text, source, path, options):
   * puts a text in an editor window - the page's own, so F2 there saves it
   * back where it came from. closeCmd: what a hex view's close box sends,
   * so the page's Alt+F3 and the close box are one road. quietKeys: the
   * program's own status items that still work in a panel but are not
   * shown there - eighty columns hold the seven F-keys or the program's
   * line, not both. run(source, dir, name): runs a DOS program - the
   * page's DOS PC does (DosTool.runProgram). associations: { extension:
   * action } - what Enter does with a file (ASSOCIATIONS above), and
   * otherwise: the action for an extension the table does not name.
   */
  constructor(owl, { sources, open, closeCmd, quietKeys = [], run = null, left = 0, right = 1, associations = ASSOCIATIONS, otherwise = 'edit' }) {
    this.owl = owl;
    this.run = run;
    this.associations = associations;
    this.otherwise = otherwise;
    this.quietKeys = quietKeys;
    this.sources = sources;
    this.open = open;
    this.closeCmd = closeCmd;
    this.start = [left, right];
    this.left = null;
    this.right = null;
    this.box = 0;
    this.dialog = null;
    this.hexes = [];
    this.work = Promise.resolve();
    this.attachDrop();
  }

  get id() { return this.left?.win ?? 0; }
  handles(cmd) { return cmd >= CommanderTool.CmFirst && cmd <= CommanderTool.CmLast; }
  owns(id) { return id !== 0 && (id === this.left?.win || id === this.right?.win || this.hexes.includes(id)); }

  // ------------------------------------------------------------ the panels

  /** Tools > Commander: the two sides over the whole desktop, or to the front if they are up. */
  /** left, right: drives - sources - to show on each side, instead of the ones they show. */
  /** leftDir, rightDir: the folders they open on, '/' unless said. */
  show({ left = null, right = null, leftDir = '/', rightDir = '/' } = {}) {
    if (this.left) {
      for (const [s, source, dir] of [[this.left, left, leftDir], [this.right, right, rightDir]]) {
        if (source && (s.source !== source || s.dir !== dir)) { s.source = source; s.dir = ''; this.track(this.go(s, dir)); }
      }
      this.owl.activate(this.left.win);
      return this.work;
    }
    const W = this.owl.width, H = this.owl.height;
    const half = Math.floor(W / 2);
    // Below the menu bar, above the status line, the whole width.
    this.right = this.side(half, W - half, H - 2, right ?? this.sources[this.start[1]]);
    this.left = this.side(0, half, H - 2, left ?? this.sources[this.start[0]]);
    this.owl.activate(this.left.win);
    return this.track(Promise.all([this.go(this.left, leftDir), this.go(this.right, rightDir)]));
  }

  /** Where the right side is on the screen: for a window that should sit exactly over it. */
  rightRect() {
    const W = this.owl.width, H = this.owl.height, half = Math.floor(W / 2);
    return { x: half, y: 1, w: W - half, h: H - 2 };
  }

  /** A drive changed from outside - DOS wrote to a floppy that is a folder of it: the sides showing it read it again. */
  refreshSource(source) {
    for (const s of [this.left, this.right]) if (s && s.source === source) this.track(this.go(s, s.dir));
  }

  side(x, w, h, source) {
    const owl = this.owl;
    const s = { source, dir: '/', entries: [], width: w };
    s.win = owl.window(this.title(s), w, h, { x, y: 1, closeCmd: Cm.Close, shadow: false });
    s.files = owl.files(s.win, `${source.prefix}/*.*`, [], { multi: true, pathLine: false, detailsOnly: true });
    // The keys this window carries. While it is in front they are these,
    // whatever the same keys are in the rest of the page; a key with no
    // label is bound and not shown - a commander's people know Tab.
    owl.windowStatus(s.win,
      { label: '~F2~ Up/Down', cmd: Cm.Computer, key: 'F2' },
      { label: '~F3~ View', cmd: Cm.View, key: 'F3' },
      { label: '~F4~ Edit', cmd: Cm.Edit, key: 'F4' },
      { label: '~F5~ Copy', cmd: Cm.Copy, key: 'F5' },
      { label: '~F6~ RenMov', cmd: Cm.Move, key: 'F6' },
      { label: '~F7~ Mkdir', cmd: Cm.MkDir, key: 'F7' },
      { label: '~F8~ Delete', cmd: Cm.Delete, key: 'F8' },
      { label: '', cmd: Cm.Switch, key: 'Tab' },
      { label: '', cmd: Cm.DriveLeft, key: 'F1', alt: true },
      { label: '', cmd: Cm.DriveRight, key: 'F2', alt: true },
      { label: '', cmd: Cm.Swap, key: 'u', ctrl: true },
      { label: '', cmd: Cm.Reread, key: 'r', ctrl: true },
      ...this.quietKeys.map(k => ({ ...k, label: '' })));
    owl.windowMenu(s.win, {
      label: '~C~ommander', items: [
        { label: '~L~eft drive...', cmd: Cm.DriveLeft, shortcut: 'Alt+F1', hint: "Which place the left side shows: this page's files, this browser, the server, WebDAV" },
        { label: '~R~ight drive...', cmd: Cm.DriveRight, shortcut: 'Alt+F2', hint: 'Which place the right side shows' },
        { label: '~S~wap panels', cmd: Cm.Swap, shortcut: 'Ctrl+U', hint: 'The left side and the right side change places' },
        { label: 'R~e~-read', cmd: Cm.Reread, shortcut: 'Ctrl+R', hint: 'Read both folders again' },
        { label: '', separator: true },
        { label: '~U~pload...', cmd: Cm.Upload, hint: 'Files from this computer into the side in front; dropping them on the page does the same' },
        { label: '~D~ownload', cmd: Cm.Download, hint: 'The marked files, or the one under the cursor, to this computer' },
      ],
    });
    return s;
  }

  /** The window's title: where the side is, cut from the left when it is long. */
  title(s) {
    const room = Math.max(8, s.width - 14);
    const t = `${s.source.prefix}${s.dir}`;
    return t.length <= room ? t : '...' + t.slice(t.length - room + 3);
  }

  /** The side in front, and the other one; nulls when neither is. */
  sides() {
    const a = this.owl.active();
    if (this.left && a === this.left.win) return [this.left, this.right];
    if (this.right && a === this.right.win) return [this.right, this.left];
    return [null, null];
  }

  /** The side whose dialog is up, or the last one in front. */
  get front() { return this.sides()[0] ?? this.last ?? this.left; }

  /** A folder into a side - or, in its foot, why not. */
  async go(s, dir) {
    try {
      const listed = await s.source.list(dir);
      const entries = dir === '/' ? listed : [{ name: '..', size: 0, date: null, dir: true }, ...listed];
      if (!this.left) return; // closed while the folder was on its way
      const moved = dir !== s.dir;
      s.dir = dir;
      s.entries = entries;
      this.owl.setFiles(s.files, `${s.source.prefix}${dir}*.*`, entries);
      if (moved) this.owl.unmark(s.files);
      this.owl.setText(s.win, this.title(s));
    } catch (e) {
      if (this.left) this.owl.filesError(s.files, e.message);
    }
  }

  refresh() {
    return Promise.all([this.left, this.right].map(s => this.go(s, s.dir)));
  }

  /** The names F5, F6, F8 and Download act on: the marks, or the cursor. Never `..`. */
  chosen(s) {
    return this.owl.markedNames(s.files).filter(n => n !== '..');
  }

  entry(s, name) { return s.entries.find(e => e.name === name); }

  // ------------------------------------------------------------- commands

  onCommand(cmd) {
    const [s, other] = this.sides();
    if (s) this.last = s;
    switch (cmd) {
      case Cm.Close: this.close(); return;
      case Cm.No: this.closeBox(); return;
      case Cm.Yes: { const yes = this.dialog?.yes; this.closeBox(); if (yes) this.track(yes()); return; }
      case Cm.MkDirOk: this.mkdirOk(); return;
      case Cm.DriveOk: this.driveOk(); return;
      case Cm.CopyOk: this.copyOk(); return;
      case Cm.DriveLeft: this.drives(this.left); return;
      case Cm.DriveRight: this.drives(this.right); return;
      // The side the This computer dialog was opened from - or, from the
      // window menu, the one in front.
      case Cm.Upload: { const f = this.dialog?.s ?? this.front; this.closeBox(); this.upload(f); return; }
      case Cm.Download: { const f = this.dialog?.s ?? this.front; this.closeBox(); this.track(this.download(f)); return; }
      case Cm.Swap: this.swap(); return;
      case Cm.Reread: this.track(this.refresh()); return;
    }
    if (!s) return;
    switch (cmd) {
      case Cm.Switch: this.owl.activate(other.win); return;
      case Cm.View: this.cursorFile(s, n => this.track(this.view(s, n))); return;
      case Cm.Edit: this.cursorFile(s, n => this.track(this.edit(s, n))); return;
      case Cm.Copy: this.askTransfer(s, other, false); return;
      case Cm.Move: this.askTransfer(s, other, true); return;
      case Cm.MkDir: this.askMkdir(s); return;
      case Cm.Delete: this.askDelete(s); return;
      case Cm.Computer: this.computer(s); return;
    }
  }

  /** The file under the cursor, if it is one file and not a folder. */
  cursorFile(s, then) {
    const [name] = this.owl.markedNames(s.files);
    const e = name && this.entry(s, name);
    if (e && !e.dir) then(name);
  }

  poll() {
    for (const s of [this.left, this.right]) {
      if (!s) continue;
      const { kind, text } = this.owl.takeFiles(s.files);
      if (kind === 1) this.enter(s, text);
    }
  }

  /** Enter on a name: a folder is walked into, a file opened as the associations say. */
  enter(s, name) {
    this.last = s;
    if (name === '..') return this.track(this.go(s, s.dir.replace(/[^/]+\/$/, '')));
    const e = this.entry(s, name);
    if (!e) return null;
    if (e.dir) return this.track(this.go(s, `${s.dir}${name}/`));
    const action = this.associations[ext(name)] ?? this.otherwise;
    if (typeof action === 'function') {
      return this.track(action({ source: s.source, dir: s.dir, name, path: `${s.dir}${name}`, commander: this }));
    }
    switch (action) {
      case 'program':
        if (this.run) return this.track(this.run(s.source, s.dir, name));
        this.tell(`${name} is a DOS program, and this page has no DOS to run it in. ` +
          'F2 downloads it to run in DOSBox; F3 shows its bytes.');
        return null;
      case 'browser': return this.track(this.browse(s, name));
      case 'view': return this.track(this.view(s, name));
      case 'hex': return this.track(s.source.readBytes(`${s.dir}${name}`).then(b => this.hex(name, b)));
      default: return this.track(this.edit(s, name, true));
    }
  }

  /**
   * Work that finishes later: what goes wrong is said in a box. `settled`
   * waits for everything asked so far, for a test.
   */
  track(job) {
    const p = Promise.resolve(job).catch(e => this.tell(e.message)).finally(() => this.owl.refresh?.());
    this.work = Promise.all([this.work, p]);
    return p;
  }

  get settled() { return this.work; }

  // ----------------------------------------------------- view, edit, hex

  /** F3: a text in an editor that will not change it; anything else as its bytes. */
  async view(s, name) {
    const path = `${s.dir}${name}`;
    const bytes = await s.source.readBytes(path);
    if (binary(bytes)) return this.hex(name, bytes);
    this.open(name, new TextDecoder().decode(bytes), s.source, path, { readOnly: true });
  }

  /**
   * F4, and Enter on a text: an editor, saving back where the file came
   * from. Anything that is not a text opens as its bytes, one glyph each,
   * as the DOS editors opened one - Edit > Hex view shows the numbers - and
   * is saved back byte for byte. Enter on one shows its bytes instead.
   */
  async edit(s, name, orHex = false) {
    const path = `${s.dir}${name}`;
    const bytes = await s.source.readBytes(path);
    const asBytes = binary(bytes);
    if (asBytes && orHex) return this.hex(name, bytes);
    this.open(name, asBytes ? bytes : new TextDecoder().decode(bytes), s.source, path, { readOnly: !!s.source.readOnly });
  }

  hex(name, bytes) {
    // Sixteen bytes and their sixteen characters are 78 columns, and the frame two more.
    const w = this.owl.window(`${name} - ${bytes.length} bytes`, Math.min(80, this.owl.width), Math.min(20, this.owl.height - 3), { closeCmd: this.closeCmd });
    this.owl.hex(w, bytes);
    this.hexes.push(w);
  }

  /** A picture, a PDF, a page: the browser shows it, in a tab of its own. */
  async browse(s, name) {
    // The tab is opened now, while the key press still counts as the
    // person's: a tab opened after the file has arrived is a pop-up, and
    // browsers block those.
    const tab = globalThis.open?.('', '_blank');
    const bytes = await s.source.readBytes(`${s.dir}${name}`);
    const url = URL.createObjectURL(new Blob([bytes], { type: TYPES[ext(name)] ?? 'application/octet-stream' }));
    if (tab) tab.location.href = url;
    else this.inPage(url, TYPES[ext(name)]);
  }

  /**
   * A browser that blocked the tab - pop-up blockers, embedded panes - is
   * still a browser: the file goes over the page instead, and any key or
   * click takes it away.
   */
  inPage(url, type) {
    const cover = document.createElement('div');
    cover.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.85);display:flex;align-items:center;justify-content:center;z-index:10;cursor:pointer';
    const shown = document.createElement(type?.startsWith('image/') ? 'img' : 'iframe');
    shown.src = url;
    shown.style.cssText = 'max-width:95vw;max-height:95vh;background:#fff;border:0;' + (shown.tagName === 'IFRAME' ? 'width:90vw;height:90vh' : '');
    cover.append(shown);
    document.body.append(cover);
    const gone = e => {
      e.preventDefault();
      e.stopImmediatePropagation();
      cover.remove();
      URL.revokeObjectURL(url);
      window.removeEventListener('keydown', gone, true);
    };
    window.addEventListener('keydown', gone, true);
    cover.addEventListener('click', gone);
  }

  // ----------------------------------------------- copy, move, mkdir, delete

  /**
   * F5 and F6: VC's dialog - what, and a line saying where to, which starts
   * as the other side's folder. A name typed there with no / is a new name
   * in this folder: F6 is how a file is renamed.
   */
  askTransfer(s, other, move) {
    const names = this.chosen(s);
    if (names.length === 0) return;
    const verb = move ? 'Rename or move' : 'Copy';
    const what = names.length === 1 ? `"${names[0]}"` : `${names.length} files`;
    const d = this.dialogBox(move ? 'Rename' : 'Copy', 66, 8, Cm.No);
    this.owl.staticText(d.win, 2, 1, `${verb} ${what} to`, 60, 1);
    d.target = this.owl.input(d.win, 2, 2, 60, '', `${other.source.prefix}${other.dir}`, 200);
    this.owl.buttons(d.win, { label: move ? '~M~ove' : '~C~opy', cmd: Cm.CopyOk, default: true }, { label: '~C~ancel', cmd: Cm.No, cancel: true });
    Object.assign(d, { s, names, move });
  }

  copyOk() {
    const { s, names, move, target } = this.dialog;
    const typed = this.owl.getText(target).trim();
    this.closeBox();
    // Which drive the line names - any of them, by its prefix - and where in it.
    const to = this.sources.find(x => typed.startsWith(x.prefix));
    const source = to ?? s.source;
    let path = to ? typed.slice(to.prefix.length) : typed;
    if (!path.startsWith('/')) path = s.dir + path;
    const intoFolder = path.endsWith('/') || names.length > 1;
    if (intoFolder && !path.endsWith('/')) path += '/';
    this.track(this.transfer(s, names, source, path, intoFolder, move));
  }

  async transfer(s, names, dst, path, intoFolder, move) {
    for (const n of names) {
      const from = `${s.dir}${n}`;
      const to = intoFolder ? `${path}${n}` : path;
      if (dst === s.source && from === to) throw new Error(`${n} cannot be copied onto itself.`);
      const dir = this.entry(s, n)?.dir;
      if (move && dst === s.source) {
        try { await dst.rename(from, to); continue; } catch { /* copy, then delete */ }
      }
      await this.copy(s.source, from, dst, to, dir);
      if (move) await s.source.remove(from);
    }
    this.owl.unmark(s.files);
    await this.refresh();
  }

  /** A file, or a folder and everything in it, from one place to another. */
  async copy(src, from, dst, to, dir) {
    if (!dir) {
      await dst.write(to, await src.readBytes(from));
      return;
    }
    try { await dst.mkdir(`${to}/`); } catch { /* there already */ }
    for (const e of await src.list(`${from}/`)) {
      await this.copy(src, `${from}/${e.name}`, dst, `${to}/${e.name}`, e.dir);
    }
  }

  askDelete(s) {
    const names = this.chosen(s);
    if (names.length === 0) return;
    const what = names.length === 1 ? `"${names[0]}"` : `the ${names.length} marked files`;
    this.ask('Delete', `Delete ${what} from ${s.source.prefix}${s.dir}? A folder goes with everything in it.`, async () => {
      for (const n of names) await s.source.remove(`${s.dir}${n}`);
      this.owl.unmark(s.files);
      await this.refresh();
    });
  }

  askMkdir(s) {
    const d = this.dialogBox('Make directory', 50, 8, Cm.No);
    this.owl.staticText(d.win, 2, 1, `Create the directory in ${s.source.prefix}${s.dir}`, 44, 1);
    d.name = this.owl.input(d.win, 2, 2, 44, '', '', 64);
    this.owl.buttons(d.win, { label: '~O~K', cmd: Cm.MkDirOk, default: true }, { label: '~C~ancel', cmd: Cm.No, cancel: true });
    d.s = s;
  }

  mkdirOk() {
    const { s, name: input } = this.dialog;
    const name = this.owl.getText(input).trim();
    this.closeBox();
    if (!name || name === '.' || name === '..' || /[\\/]/.test(name)) return this.tell('A folder needs a name, with no / in it.');
    this.track(s.source.mkdir(`${s.dir}${name}/`).then(() => this.refresh()));
  }

  // ---------------------------------------------------------------- drives

  /** Alt+F1, Alt+F2: which place a side shows. */
  drives(s) {
    if (!s) return;
    const rows = this.sources.length;
    const d = this.dialogBox(s === this.left ? 'Left side' : 'Right side', 64, rows + 6, Cm.No);
    d.list = this.owl.list(d.win, 2, 1, 58, rows, this.sources.map(x => `${x.prefix.padEnd(10)} ${x.title}`));
    this.owl.buttons(d.win, { label: '~O~K', cmd: Cm.DriveOk, default: true }, { label: '~C~ancel', cmd: Cm.No, cancel: true });
    d.s = s;
  }

  driveOk() {
    const { s, list } = this.dialog;
    const source = this.sources[this.owl.current(list)];
    this.closeBox();
    if (!source) return;
    s.source = source;
    s.dir = '';
    this.track(this.go(s, '/'));
  }

  /** Ctrl+U: the two sides change places - what each shows, not the windows. */
  swap() {
    if (!this.left) return;
    const l = this.left, r = this.right;
    [l.source, r.source] = [r.source, l.source];
    [l.dir, r.dir] = [r.dir, l.dir];
    this.owl.unmark(l.files);
    this.owl.unmark(r.files);
    this.track(this.refresh());
  }

  // -------------------------------------------------- upload, download

  /** F2: this computer - files from it, files to it. */
  computer(s) {
    const to = this.uploadSide(s);
    const d = this.dialogBox('This computer', 56, 8, Cm.No);
    this.owl.staticText(d.win, 2, 1, `Upload files into ${to.source.prefix}${to.dir}, or download the marked ones. Dropping files on the page uploads them too.`, 50, 3);
    this.owl.buttons(d.win, { label: '~U~pload...', cmd: Cm.Upload, default: true }, { label: '~D~ownload', cmd: Cm.Download }, { label: '~C~ancel', cmd: Cm.No, cancel: true });
    d.s = s;
  }

  /** Where an upload goes: the side in front - or, when that one is read-only, the other. */
  uploadSide(s) {
    const other = s === this.left ? this.right : this.left;
    return s.source.readOnly && other && !other.source.readOnly ? other : s;
  }

  /**
   * The browser's own file picker; the chosen files go into a side. The
   * picker is put on the page until it is done with: an element nothing
   * holds may be thrown away while its dialog is open, and then the files
   * chosen in it never arrive.
   */
  upload(s) {
    if (typeof document === 'undefined' || !s) return;
    const to = this.uploadSide(s);
    const input = document.createElement('input');
    input.type = 'file';
    input.multiple = true;
    input.style.display = 'none';
    const done = () => input.remove();
    input.addEventListener('change', () => { done(); this.track(this.put(to, [...input.files])); });
    input.addEventListener('cancel', done);
    document.body.append(input);
    input.click();
  }

  /** Files from this computer - picked, or dropped on the page - into a side. */
  async put(s, files) {
    if (s.source.readOnly) throw new Error(`${s.source.title} cannot be written to: upload into the other side.`);
    for (const f of files) await s.source.write(`${s.dir}${f.name}`, f);
    await this.refresh();
  }

  /** The marked files, or the one under the cursor, to this computer. Folders are left. */
  async download(s) {
    if (typeof document === 'undefined' || !s) return;
    for (const n of this.chosen(s)) {
      if (this.entry(s, n)?.dir) continue;
      const bytes = await s.source.readBytes(`${s.dir}${n}`);
      const url = URL.createObjectURL(new Blob([bytes]));
      const a = document.createElement('a');
      a.href = url;
      a.download = n;
      a.click();
      setTimeout(() => URL.revokeObjectURL(url), 5000);
    }
  }

  /** Files dropped anywhere on the page go into the side in front, while the commander is up. */
  attachDrop() {
    if (typeof document === 'undefined') return;
    document.addEventListener('dragover', e => { if (this.left) e.preventDefault(); });
    document.addEventListener('drop', e => {
      if (!this.left) return;
      e.preventDefault();
      this.track(this.put(this.uploadSide(this.front), [...e.dataTransfer.files]));
    });
  }

  // ------------------------------------------------------------- dialogs

  /** One dialog at a time; a new one closes the one before. */
  dialogBox(title, w, h, closeCmd) {
    this.closeBox();
    const win = this.owl.window(title, w, h, { style: Style.ModalDialog, closeCmd });
    this.dialog = { win };
    this.box = win;
    return this.dialog;
  }

  ask(title, text, yes) {
    this.closeBox();
    // No is the default: Enter and Escape leave the files as they are.
    this.box = this.owl.messageBox(title, text, { label: '~Y~es', cmd: Cm.Yes }, { label: '~N~o', cmd: Cm.No, default: true, cancel: true });
    this.dialog = { win: this.box, yes };
  }

  tell(text) {
    this.closeBox();
    this.box = this.owl.messageBox('Commander', text, { label: '~O~K', cmd: Cm.No, default: true, cancel: true });
  }

  closeBox() {
    if (this.box) this.owl.close(this.box);
    this.box = 0;
    this.dialog = null;
  }

  /** Either side closed: the commander is, and whatever it opened. */
  close() {
    this.closeBox();
    for (const s of [this.left, this.right]) if (s) this.owl.close(s.win);
    for (const h of this.hexes) this.owl.close(h);
    this.left = this.right = this.last = null;
    this.hexes = [];
  }

  /** Alt+F3 on a window of this tool. */
  closeWindow(id) {
    if (this.hexes.includes(id)) {
      this.owl.close(id);
      this.hexes = this.hexes.filter(h => h !== id);
    } else {
      this.close();
    }
  }
}
