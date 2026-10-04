// Files in editors: editor windows, File > New and Open from, and what an
// editor's window brings to the File menu while it is in front - Save (F2)
// and Save as. With the Open / Save as dialog: a file panel over a place,
// a folder walked, a name typed, a file already there asked about.
//
// The places are the page's (`places`): this browser's storage, the
// server's folder, a WebDAV share - lib/js/files/ - each with the words
// its menu item says. Every place answers list(dir), readBytes(path) and
// write(path, text or bytes), and says in `about` what it is in words a
// first-time visitor knows. The panel only draws: this reads the folder
// and hands it over.
//
// A file that is not a text - a program, a picture - opens as its bytes,
// one glyph each, as a DOS editor opened one, and is saved back byte for
// byte (owl.textOfBytes, owl.getTextBytes). A text keeps the line ends it
// came with.

import { Style, sub, Offer } from '../owlosui.js';
import { split } from '../files/browser.js';
import { WebDavFolder } from '../files/webdav.js';
import { binary } from './commander.js';

export const DocCm = {
  New: 500, Save: 501, FileOpen: 502, FileCancel: 503, DavConnect: 504, DavCancel: 505,
  SaveAsOk: 506, Replace: 507, Keep: 508, Dismiss: 509,
  /** Open from the page's place n: OpenFrom + n. */
  OpenFrom: 510,
  /** Save as into the page's place n: SaveAs + n. */
  SaveAs: 530,
};

export class Documents {
  static CmFirst = 500;
  static CmLast = 549;

  /**
   * places: [{ label, hint, saveHint, source }] - where Open from and
   * Save as go; `source` is a place, or a function that makes one when it
   * is chosen. A place { label, dav: { address, about } } asks for a WebDAV
   * address first. defaultSource: where Save puts a new file, with no
   * place of its own yet. closeCmd: what an editor's close box sends - the
   * page's Alt+F3, so the two are one road. newText: what File > New
   * starts with. place(n): where editor window n goes, { x, y, w, h }.
   * saved(doc): after a file is saved - the course builds it. opened(doc):
   * after a file is put in an editor.
   */
  constructor(owl, {
    places = [], defaultSource = null, closeCmd = 0, newText = '',
    place = n => ({ x: 2 + (n % 8), y: 1 + (n % 8), w: 60, h: 16 }),
    saved = null, opened = null,
  } = {}) {
    this.owl = owl;
    this.places = places;
    this.defaultSource = defaultSource;
    this.closeCmd = closeCmd;
    this.newText = newText;
    this.place = place;
    this.saved = saved;
    this.opened = opened;
    this.editors = [];
    this.docs = new Map();      // window -> { window, text, source, path, name, crlf, binary }
    this.open = null;           // the Open / Save as dialog, while it is up
    this.dav = null;            // the WebDAV address dialog, likewise
    this.box = 0;               // a message box of ours
    this.pending = Promise.resolve();
  }

  handles(cmd) { return cmd >= Documents.CmFirst && cmd <= Documents.CmLast; }
  owns(id) {
    return id !== 0 && (this.docs.has(id) || id === this.open?.dialog || id === this.dav?.dialog || id === this.box);
  }
  /** The document a window is, or undefined. */
  of(id) { return this.docs.get(id); }

  /** The page's File menu, without Exit: New, and Open from each place. Save and Save as come with an editor. */
  fileMenu() {
    const items = [{ label: '~N~ew', cmd: DocCm.New, shortcut: 'F3', hint: 'An editor window of its own' }];
    if (this.places.length) {
      items.push(sub('~O~pen from', ...this.places.map((p, i) => ({ label: p.label, cmd: DocCm.OpenFrom + i, hint: p.hint }))));
    }
    return items;
  }

  /** File > New: an editor of its own, a window like any other. */
  newEditor(text = this.newText) {
    const n = this.editors.length + 1;
    return this.add(`UNTITLED${n}.TXT`, text, null, null);
  }

  docTitle(name, source) { return source ? `${name} - ${source.title}` : name; }

  /**
   * An editor window for a file; `source` and `path` say where Save puts it
   * back. `text` is a string, or the file's bytes: a program, a picture,
   * anything that is not a text opens as its bytes, one glyph each, as a
   * DOS editor opened one - garbage on the screen, Edit > Hex view to see
   * the numbers - and is saved back byte for byte. rect: where its window
   * goes, if not where `place` says.
   */
  add(name, text, source, path, { readOnly = false, rect = null } = {}) {
    const owl = this.owl;
    const r = rect ?? this.place(this.editors.length + 1);
    const w = owl.window(this.docTitle(name, source), r.w, r.h, { x: r.x, y: r.y, closeCmd: this.closeCmd });
    const bytes = text instanceof Uint8Array;
    // A DOS or Windows file ends its lines with CR LF. The editor wants LF
    // alone - a CR would show as a glyph - so the CRs come off here and go
    // back on in save(), and the file keeps the line ends it came with.
    // A file opened as bytes keeps its CRs: they are bytes like the others.
    const crlf = !bytes && text.includes('\r\n');
    const t = owl.text(w, bytes ? owl.textOfBytes(text) : crlf ? text.replace(/\r\n/g, '\n') : text);
    // Everything the editor has, on an Edit menu of its own while this
    // window is in front: Find, Replace, Word wrap, Line numbers, Position,
    // Read only, Hex view, Classic keys. The core runs all of it. The
    // caret's line:column on the bottom edge, always.
    owl.editor(t, Offer.All, { readOnly, position: true });
    // Coloured as its language, which its name says: DEMO.PAS is Pascal.
    // A name no language answers to stays plain, and Edit > Syntax can
    // still choose one. Code gets its line numbers too - an assembler says
    // by number which line is wrong.
    if (!bytes && owl.syntax(t, name)) owl.editor(t, Offer.All, { readOnly, position: true, numbers: true });
    // Save and Save as, on the File menu above Exit and F2 on the status
    // line, while this window is in front - and only then.
    const saveAs = this.places.map((p, i) => ({ label: p.label, cmd: DocCm.SaveAs + i, hint: p.saveHint ?? p.hint }));
    owl.windowMenu(w, sub('~F~ile',
      { label: '~S~ave', cmd: DocCm.Save, shortcut: 'F2', hint: 'This file, back where it came from' },
      ...(saveAs.length ? [sub('Save ~a~s', ...saveAs)] : [])));
    owl.windowStatus(w, { label: '~F2~ Save', cmd: DocCm.Save, key: 'F2' });
    this.editors.push(w);
    const doc = { window: w, text: t, source, path, name, crlf, binary: bytes };
    this.docs.set(w, doc);
    this.opened?.(doc);
    return w;
  }

  /** The window `id` is closed: an editor, a dialog of ours, or a box. */
  closeWindow(id) {
    if (id === this.open?.dialog) return this.closeOpen();
    if (id === this.dav?.dialog) return this.closeDav();
    if (id === this.box) return this.closeBox();
    if (!this.docs.has(id)) return null;
    this.owl.close(id);
    this.docs.delete(id);
    this.editors = this.editors.filter(e => e !== id);
    return null;
  }

  tell(title, text) {
    this.closeBox();
    this.box = this.owl.messageBox(title, text, ['~O~K', DocCm.Dismiss]);
  }

  closeBox() {
    if (this.box) this.owl.close(this.box);
    this.box = 0;
  }

  /** Work that finishes later: what goes wrong is said in a box, and a test can wait for it. */
  track(promise) {
    this.pending = Promise.resolve(promise).catch(e => this.tell('Files', e.message)).finally(() => this.owl.refresh?.());
    return this.pending;
  }

  /** The page's place n, made if it is made on demand; null for a WebDAV one, which asks first. */
  placeAt(n) {
    const p = this.places[n];
    if (!p || p.dav) return null;
    return typeof p.source === 'function' ? p.source() : p.source;
  }

  // ------------------------------------------------------- open, save

  /**
   * File > Open from: the Open dialog, the place explained above the
   * panel. With `saveAs`, File > Save as: the same dialog, walking the
   * folders, with a line for the name the file in front is saved under.
   */
  openFrom(source, saveAs = null) {
    const owl = this.owl;
    this.closeOpen();
    const d = owl.window(`${saveAs ? 'Save as' : 'Open'} - ${source.title}`, 72, saveAs ? 23 : 21,
      { style: Style.ModalDialog, closeCmd: DocCm.FileCancel });
    // The panel first: the core gives a window's keys to a file panel only
    // when it is the window's first part. The words about the place go in
    // the rows it leaves free above itself.
    const panel = owl.files(d, `${source.prefix}/*.*`, [], { top: saveAs ? 5 : 3 });
    owl.staticText(d, 2, 1, source.about, 66, 2);
    let name = 0;
    if (saveAs) {
      // Between the words and the panel: a name chosen in the panel goes
      // here, and Save writes into the folder the panel shows.
      name = owl.input(d, 2, 3, 50, 'File name', saveAs.name);
      owl.buttons(d, { label: '~S~ave', cmd: DocCm.SaveAsOk, default: true }, { label: '~C~ancel', cmd: DocCm.FileCancel, cancel: true });
    } else {
      owl.buttons(d, { label: '~O~pen', cmd: DocCm.FileOpen, default: true }, { label: '~C~ancel', cmd: DocCm.FileCancel, cancel: true });
    }
    this.open = { dialog: d, panel, source, dir: '/', entries: [], saveAs, name };
    return this.track(this.showFolder('/'));
  }

  closeOpen() {
    if (this.open) this.owl.close(this.open.dialog);
    this.open = null;
  }

  /** A folder of the place into the panel - or, in the panel, why not. */
  async showFolder(dir) {
    const o = this.open;
    if (!o) return;
    try {
      const entries = await o.source.list(dir);
      if (dir !== '/') entries.unshift({ name: '..', size: 0, date: new Date(), dir: true });
      if (this.open !== o) return; // closed while the folder was on its way
      o.dir = dir;
      o.entries = entries;
      this.owl.setFiles(o.panel, `${o.source.prefix}${dir}*.*`, entries);
    } catch (e) {
      if (this.open === o) this.owl.filesError(o.panel, e.message);
    }
  }

  /**
   * A file into an editor window; the dialog closes. Read as bytes: a text
   * opens as text, anything else as its bytes (add). In Save as, a file
   * chosen in the panel is the name to save under instead.
   */
  async openFile(path) {
    const o = this.open;
    if (!o) return;
    if (o.saveAs) {
      this.owl.setText(o.name, split(path).name);
      return this.saveAsHere();
    }
    try {
      const bytes = await o.source.readBytes(path);
      this.closeOpen();
      this.add(split(path).name, binary(bytes) ? bytes : new TextDecoder().decode(bytes), o.source, path);
    } catch (e) {
      if (this.open === o) this.owl.filesError(o.panel, e.message);
    }
  }

  /**
   * A name entered in the panel: a folder is walked into, a file opened.
   * Enter on a name is reported twice - the panel says which name, and the
   * dialog's default button is pressed - and reading takes a while here,
   * so while one is on its way the second is let go.
   */
  chosen(name) {
    const o = this.open;
    if (!o || o.busy) return null;
    o.busy = true;
    const e = o.entries.find(x => x.name === name);
    const work = name === '..' ? this.showFolder(o.dir.replace(/[^/]+\/$/, ''))
      : e?.dir ? this.showFolder(`${o.dir}${name}/`)
        : this.openFile(`${o.dir}${name}`);
    return this.track(work.finally(() => { o.busy = false; }));
  }

  /** A path typed in the panel's path line: a folder, a mask, or a file. */
  typed(text) {
    const o = this.open;
    let p = text.startsWith(o.source.prefix) ? text.slice(o.source.prefix.length) : text;
    if (!p.startsWith('/')) p = o.dir + p;
    if (/[*?]/.test(p)) p = p.slice(0, p.lastIndexOf('/') + 1);
    return p.endsWith('/') ? this.track(this.showFolder(p)) : this.track(this.openFile(p));
  }

  /** What a document holds, as the file will have it: its text with its own line ends, or its bytes. */
  contentOf(doc) {
    if (doc.binary) return this.owl.getTextBytes(doc.text);
    const typed = this.owl.getText(doc.text);
    return doc.crlf ? typed.replace(/\r?\n/g, '\r\n') : typed;
  }

  /**
   * File > Save (F2): back where it came from; a new file goes to
   * `defaultSource`. Only an editor's window offers it, so there is always
   * a file in front - the check is for a program that calls this.
   */
  save(id = this.owl.active()) {
    const doc = this.docs.get(id);
    if (!doc) return null;
    if (!doc.source) {
      if (!this.defaultSource) {
        this.tell('Save', `${doc.name} has no place yet: File > Save as says where.`);
        return null;
      }
      doc.source = this.defaultSource;
      doc.path = `/${doc.name}`;
      this.owl.setText(id, this.docTitle(doc.name, doc.source));
    }
    const content = this.contentOf(doc);
    return this.track((async () => {
      await doc.source.write(doc.path, content);
      this.tell('Saved', `${doc.name} is saved in ${doc.source.title}, as ${doc.path}. File > Open from finds it there.`);
      await this.saved?.(doc);
    })());
  }

  /** File > Save as: the dialog over a place, for the file in front. */
  saveAs(source, id = this.owl.active()) {
    const doc = this.docs.get(id);
    if (!doc) return null;
    return this.openFrom(source, { window: id, name: doc.name });
  }

  /**
   * Save in the Save as dialog: the name typed, in the folder the panel
   * shows. A name already there is asked about first; a folder's name is
   * walked into, as Enter on it would.
   */
  saveAsHere(replace = false) {
    const o = this.open;
    if (!o?.saveAs || o.saving || (o.asking && !replace)) return null;
    o.asking = false;
    const name = this.owl.getText(o.name).trim();
    if (!name || /[\\:*?"<>|]/.test(name)) {
      this.owl.filesError(o.panel, name ? `"${name}" cannot be a file's name.` : 'Type a name to save under.');
      return null;
    }
    if (name.includes('/')) return this.typed(name);
    const there = o.entries.find(e => e.name.toLowerCase() === name.toLowerCase());
    if (there?.dir) return this.track(this.showFolder(`${o.dir}${there.name}/`));
    if (there && !replace) {
      o.asking = true;
      this.closeBox();
      this.box = this.owl.messageBox('Save as', `${there.name} is already in ${o.source.title}${o.dir}. Replace it?`,
        { label: '~R~eplace', cmd: DocCm.Replace }, { label: '~K~eep it', cmd: DocCm.Keep, default: true, cancel: true });
      return null;
    }
    const doc = this.docs.get(o.saveAs.window);
    if (!doc) { this.closeOpen(); return null; }
    const path = `${o.dir}${there?.name ?? name}`;
    const content = this.contentOf(doc);
    o.saving = true;
    return this.track((async () => {
      try {
        await o.source.write(path, content);
      } catch (e) {
        o.saving = false;
        if (this.open === o) this.owl.filesError(o.panel, e.message);
        return;
      }
      this.closeOpen();
      // From now on the window is that file: Save goes there, and the
      // title says so.
      Object.assign(doc, { source: o.source, path, name: split(path).name });
      this.owl.setText(o.saveAs.window, this.docTitle(doc.name, doc.source));
      if (!doc.binary) this.owl.syntax(doc.text, doc.name);
      this.tell('Saved', `${doc.name} is saved in ${doc.source.title}, as ${path}.`);
      await this.saved?.(doc);
    })());
  }

  // ------------------------------------------------------- WebDAV

  /** Open from, or Save as, a WebDAV place: where the share is, first. */
  davAsk(n, forSave = false) {
    const owl = this.owl;
    const p = this.places[n];
    this.davForSave = forSave;
    if (this.dav) { owl.activate(this.dav.dialog); return; }
    const d = owl.window('A WebDAV folder', 68, 16, { style: Style.ModalDialog, closeCmd: DocCm.DavCancel });
    owl.staticText(d, 2, 1, p?.dav?.about ?? 'WebDAV is how NAS boxes, Nextcloud and many servers share folders: type the address of one.', 62, 4);
    const origin = globalThis.location?.origin ?? 'http://localhost:8765';
    // An input's label is plain words; Tab walks the fields.
    const url = owl.input(d, 2, 6, 62, 'Address', p?.dav?.address ?? `${origin}/dav/`);
    const user = owl.input(d, 2, 8, 40, 'User, if it asks', '');
    const password = owl.input(d, 2, 10, 40, 'Password, shown as typed', '');
    owl.buttons(d, { label: 'C~o~nnect', cmd: DocCm.DavConnect, default: true }, { label: '~C~ancel', cmd: DocCm.DavCancel, cancel: true });
    this.dav = { dialog: d, url, user, password };
  }

  closeDav() {
    if (this.dav) this.owl.close(this.dav.dialog);
    this.dav = null;
  }

  davConnect() {
    const v = id => this.owl.getText(id).trim();
    const source = new WebDavFolder(v(this.dav.url), { user: v(this.dav.user), password: v(this.dav.password) });
    const forSave = this.davForSave;
    const back = this.saveFor;
    this.closeDav();
    return forSave ? this.saveAs(source, back) : this.openFrom(source);
  }

  // ------------------------------------------------------- commands

  onCommand(cmd) {
    const owl = this.owl;
    switch (cmd) {
      case DocCm.New: this.newEditor(); return true;
      case DocCm.Save: this.save(); return true;
      case DocCm.Dismiss: this.closeBox(); return true;
      case DocCm.FileCancel: this.closeOpen(); return true;
      case DocCm.DavConnect: this.davConnect(); return true;
      case DocCm.DavCancel: this.closeDav(); return true;
      case DocCm.FileOpen: {
        // The Open button: whatever is under the cursor.
        const [name] = this.open ? owl.markedNames(this.open.panel) : [];
        if (name) this.chosen(name);
        return true;
      }
      case DocCm.SaveAsOk: {
        // Enter on a name in the panel presses Save too, and before the
        // panel's own report is collected: take that first, so the name
        // under the cursor is the one saved to, not the one in the line.
        const o = this.open;
        const { kind, text } = o ? owl.takeFiles(o.panel) : { kind: 0 };
        if (kind === 1) this.chosen(text);
        else if (kind === 2) this.typed(text);
        else this.saveAsHere();
        return true;
      }
      case DocCm.Replace: this.closeBox(); this.saveAsHere(true); return true;
      case DocCm.Keep: this.closeBox(); if (this.open) this.open.asking = false; return true;
    }
    if (cmd >= DocCm.OpenFrom && cmd < DocCm.OpenFrom + this.places.length) {
      const n = cmd - DocCm.OpenFrom;
      if (this.places[n].dav) this.davAsk(n, false);
      else this.openFrom(this.placeAt(n));
      return true;
    }
    if (cmd >= DocCm.SaveAs && cmd < DocCm.SaveAs + this.places.length) {
      const n = cmd - DocCm.SaveAs;
      // The window the file is in, kept for a WebDAV address asked first:
      // by then the address dialog is in front.
      this.saveFor = owl.active();
      if (this.places[n].dav) this.davAsk(n, true);
      else this.saveAs(this.placeAt(n));
      return true;
    }
    return false;
  }

  /** What the file panel reports is not a command: a name entered, a path typed. */
  poll() {
    if (!this.open) return;
    const { kind, text } = this.owl.takeFiles(this.open.panel);
    if (kind === 1) this.chosen(text);
    else if (kind === 2) this.typed(text);
  }
}
