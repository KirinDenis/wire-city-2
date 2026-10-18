// The site's drives: a letter over a place files are kept (the pilot,
// 2026-10-16: "a drive is a letter, and it is not hidden"). ONE table of
// them for the Files menu, Map Drives, both commanders and DOS.
//
//   A: B:   floppies, folders of this browser's storage (the course disk on A:)
//   C:      the machine's hard disk - a folder of this browser too, so what
//           DOS writes there is there tomorrow; the games are put on it
//   D:      My files, in this browser
//   E: on   what Map Drives adds: a folder of this browser, a folder on this
//           computer (Chrome and Edge), a ZIP or a link to one - the last
//           two copied into a folder of this browser
//
// Every drive is a source as OWLOSUI's files/ are - list, read, readBytes,
// write, remove, mkdir, rename; paths /folder/file, folders ending in / -
// with its own paths: A:'s /GAMES/ is /DOS A Drive/GAMES/ in the storage.

import { BrowserStorage } from '../owlosui/files/browser.js';

export const crlf = s => s.replace(/\r?\n/g, '\r\n');

/** A quick fingerprint of some bytes: FNV-1a, 32 bits - as OWLOSUI's DriveGates takes one. */
export function fingerprint(bytes) {
  let h = 0x811c9dc5;
  for (let i = 0; i < bytes.length; i++) h = Math.imul(h ^ bytes[i], 0x01000193);
  return h >>> 0;
}

export class Drive {
  /**
   * kind: what it is, in a word - floppy, hard disk, folder, your computer,
   * ZIP, link. title: what is on it. where: where its files really are, in
   * words, for Map Drives. readOnly: by the table (a folder on this computer
   * unless DOS was let write to it).
   */
  constructor(letter, { base, root = '/', kind, title, about, where = '', readOnly = false, entry = null }) {
    Object.assign(this, { letter, base, root, kind, title, about, where, entry, fixedReadOnly: readOnly });
    this.prefix = `${letter}:`;       // what the commander shows: its path line and Alt+F1
  }
  get readOnly() { return this.fixedReadOnly || !!this.base.readOnly; }
  real(path) { return this.root.replace(/\/$/, '') + path; }
  list(dir) { return this.base.list(this.real(dir)); }
  read(path) { return this.base.read(this.real(path)); }
  readBytes(path) { return this.base.readBytes(this.real(path)); }
  write(path, data) { return this.guard() ?? this.base.write(this.real(path), data); }
  remove(path) { return this.guard() ?? this.base.remove(this.real(path)); }
  mkdir(path) { return this.guard() ?? this.base.mkdir(this.real(path)); }
  rename(from, to) { return this.guard() ?? this.base.rename(this.real(from), this.real(to)); }
  guard() { return this.fixedReadOnly ? Promise.reject(new Error(`${this.prefix} is read-only.`)) : null; }
}

/**
 * A folder on this computer, given by its owner through the browser's
 * folder picker (Chrome and Edge; Firefox and Safari have no picker). The
 * same code as this browser's storage, over the folder the picker gave
 * instead of the storage's root. It never writes a welcome file into it.
 */
export class LocalFolder extends BrowserStorage {
  constructor(handle) {
    super();
    this.handle = handle;
    this.title = `the folder ${handle.name} on this computer`;
    this.prefix = 'local:';
  }
  root() { return this.handle; }
  seed() { return Promise.resolve(); }
  /** Whether the page may use it now: 'granted', or 'prompt' after a reload until a click asks again. */
  async permission(ask = false, write = false) {
    const mode = { mode: write ? 'readwrite' : 'read' };
    const now = await this.handle.queryPermission?.(mode) ?? 'granted';
    if (now === 'granted' || !ask) return now;
    return this.handle.requestPermission(mode);
  }
}

/**
 * NOTHING IS DELETED BECAUSE DOS SEEMS TO HAVE LOST IT. OWLOSUI's DriveGates
 * takes a file DOS no longer shows for deleted by DOS and removes it from
 * the storage; on 2026-10-04 that emptied the course disk (course.js,
 * guardTheDisk, which keeps A:). The site keeps every other drive the same
 * way - and a folder on this computer above all: those are the owner's own
 * files. The price: a file DEL'd inside DOS comes back at the next switch-on.
 */
export function guardRemovals(storage, folders, log) {
  const remove = storage.remove.bind(storage);
  storage.remove = path => {
    const shared = folders().some(f => path === f.slice(0, -1) || path.startsWith(f));
    if (storage.quiet > 0 && shared) {
      log?.warn('files', `kept ${path}: the DOS PC no longer shows it, but nothing is deleted that way`);
      return Promise.resolve();
    }
    // A journal of every removal from a drive DOS shares, with who asked: on
    // 2026-10-16 every file of A: was found gone, the folders left, the
    // cause not found - the next time says who did it.
    if (shared) log?.info('files', `removed ${path} - asked by ${(new Error().stack ?? '').split('\n').slice(2, 4).map(s => s.trim()).join(' < ')}`);
    return remove(path);
  };
}

/**
 * A DIAGNOSTIC, 2026-10-16, until the cause is found: twice that day every
 * FILE of A: (the course disk) was found gone from this browser, its folders
 * left - with guardTheDisk and guardRemovals in place, so not by DOS's
 * mirroring. Every removal from this browser's storage, whoever asks for it,
 * goes into localStorage `site.removals` (the last 300: when, the name, the
 * calls that led there) - it outlives a reload, as the log does not.
 * `JSON.parse(localStorage['site.removals'])` reads it.
 */
export function journalRemovals() {
  const proto = globalThis.FileSystemDirectoryHandle?.prototype;
  if (!proto || proto.removeEntry.journaled) return;
  const removeEntry = proto.removeEntry;
  proto.removeEntry = function (name, options) {
    try {
      const all = JSON.parse(localStorage.getItem('site.removals') ?? '[]');
      all.push({ at: new Date().toISOString(), in: this.name, name, recursive: !!options?.recursive,
        by: (new Error().stack ?? '').split('\n').slice(2, 8).map(s => s.trim()).join(' < ') });
      localStorage.setItem('site.removals', JSON.stringify(all.slice(-300)));
    } catch { /* storage full or refused: the removal goes on */ }
    return removeEntry.call(this, name, options);
  };
  proto.removeEntry.journaled = true;
}

// ---- the table, kept in this browser -------------------------------------

const TABLE_KEY = 'site.drives.1';

/**
 * The drives Map Drives added: [{ letter, kind: 'folder'|'local'|'zip'|'link',
 * title, folder?, url?, write? }]. A folder on this computer is kept by its
 * handle, in IndexedDB - localStorage holds only words.
 */
export function loadTable() {
  try { return JSON.parse(localStorage.getItem(TABLE_KEY) ?? '[]'); } catch { return []; }
}
export function saveTable(entries) {
  try { localStorage.setItem(TABLE_KEY, JSON.stringify(entries)); } catch { /* a private window: for this visit only */ }
}

function handles() {
  return new Promise((resolve, reject) => {
    const r = indexedDB.open('site.drives', 1);
    r.onupgradeneeded = () => r.result.createObjectStore('handles');
    r.onsuccess = () => resolve(r.result);
    r.onerror = () => reject(r.error);
  });
}
export async function keepHandle(letter, handle) {
  const db = await handles();
  await new Promise((ok, no) => { const t = db.transaction('handles', 'readwrite'); t.objectStore('handles').put(handle, letter); t.oncomplete = ok; t.onerror = () => no(t.error); });
}
export async function handleOf(letter) {
  const db = await handles();
  return new Promise((ok, no) => { const q = db.transaction('handles').objectStore('handles').get(letter); q.onsuccess = () => ok(q.result ?? null); q.onerror = () => no(q.error); });
}
export async function forgetHandle(letter) {
  const db = await handles();
  await new Promise(ok => { const t = db.transaction('handles', 'readwrite'); t.objectStore('handles').delete(letter); t.oncomplete = ok; t.onerror = ok; });
}

/** What a drive holds: its files, their bytes, and when the newest of them changed (ms, 0 for none). */
export async function statsOf(source, dir = '/', s = { files: 0, bytes: 0, newest: 0 }) {
  for (const e of await source.list(dir)) {
    if (e.dir) { await statsOf(source, `${dir}${e.name}/`, s); continue; }
    s.files++;
    s.bytes += e.size ?? 0;
    const t = e.date instanceof Date ? e.date.getTime() : 0;
    if (t > s.newest) s.newest = t;
  }
  return s;
}

/** Bytes as a person reads them: 512 B, 12.3 KB, 9.1 MB. */
export function sizeText(n) {
  if (n < 1024) return `${n} B`;
  if (n < 1024 * 1024) return `${(n / 1024).toFixed(n < 10240 ? 1 : 0)} KB`;
  return `${(n / 1048576).toFixed(n < 10485760 ? 1 : 0)} MB`;
}

/** A moment, short: today 14:49 if it was today, else the day as DOS's DIR writes it, 16-10-26. */
export function dateText(ms) {
  if (!ms) return '';
  const d = new Date(ms), two = v => String(v).padStart(2, '0');
  if (d.toDateString() === new Date().toDateString()) return `today ${two(d.getHours())}:${two(d.getMinutes())}`;
  return `${two(d.getDate())}-${two(d.getMonth() + 1)}-${two(d.getFullYear() % 100)}`;
}

/** A ZIP's name as a folder of this browser: DOOM.ZIP -> /DOOM/, and /DOOM 2/ if that is taken. */
export async function freeFolder(storage, name) {
  const base = (name.replace(/\.[^.]*$/, '').replace(/[\\/:*?"<>|]/g, ' ').trim() || 'Drive').slice(0, 40);
  const taken = new Set((await storage.list('/')).map(e => e.name.toLowerCase()));
  for (let i = 1; ; i++) {
    const n = i === 1 ? base : `${base} ${i}`;
    if (!taken.has(n.toLowerCase())) return `/${n}/`;
  }
}
