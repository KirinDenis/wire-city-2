// A folder shared over WebDAV: the protocol NAS boxes, Nextcloud, and many
// servers share folders with. A folder is asked with PROPFIND and answers
// in XML; a file is a GET; saving is a PUT. RUN.CMD's own server shares
// Examples/Web/files at /dav/, so there is one to try without setting
// anything up.
//
// Another site's share must allow this page to call it (CORS); a login,
// if the share wants one, goes as HTTP Basic.
//
// Changing the share is WebDAV's own: DELETE, MKCOL for a folder, MOVE.
//
// Like every source in this folder: list(dir), read(path), readBytes(path),
// write(path, text or bytes), remove(path), mkdir(path), rename(from, to),
// with paths as /folder/file.txt and folders ending in /.

const PROPFIND = `<?xml version="1.0" encoding="utf-8"?>
<propfind xmlns="DAV:"><prop><displayname/><resourcetype/><getcontentlength/><getlastmodified/></prop></propfind>`;

export class WebDavFolder {
  /** url: the share, e.g. http://localhost:8765/dav/ */
  constructor(url, { user = '', password = '' } = {}) {
    this.base = url.replace(/\/+$/, '');
    this.auth = user ? { Authorization: 'Basic ' + btoa(`${user}:${password}`) } : {};
    this.title = 'the WebDAV folder';
    this.about = `The folder shared over WebDAV at ${this.base}/ - the way a NAS or Nextcloud shares one.`;
    this.prefix = 'webdav:';
  }

  url(path) {
    return this.base + path.split('/').map(encodeURIComponent).join('/');
  }

  async fetch(path, init = {}) {
    let r;
    try {
      r = await fetch(this.url(path), { ...init, headers: { ...this.auth, ...(init.headers ?? {}) } });
    } catch {
      throw new Error(`Nothing answered at ${this.base}/. Check the address - or the share does not allow this page (CORS).`);
    }
    if (r.status === 401) throw new Error('The share wants a user name and password.');
    if (!r.ok) throw new Error(`The share said ${r.status} ${r.statusText} for ${path}.`);
    return r;
  }

  async list(dir) {
    const r = await this.fetch(dir, { method: 'PROPFIND', headers: { Depth: '1', 'Content-Type': 'application/xml' }, body: PROPFIND });
    return parseMultistatus(await r.text(), new URL(this.url(dir)).pathname);
  }

  async read(path) {
    return (await this.fetch(path)).text();
  }

  async readBytes(path) {
    return new Uint8Array(await (await this.fetch(path)).arrayBuffer());
  }

  /** Text, or bytes: a Uint8Array or a Blob, saved as they are. */
  async write(path, data) {
    const headers = typeof data === 'string' ? { 'Content-Type': 'text/plain; charset=utf-8' } : {};
    await this.fetch(path, { method: 'PUT', body: data, headers });
  }

  /** A file, or a folder with everything in it. */
  async remove(path) {
    await this.fetch(path, { method: 'DELETE' });
  }

  async mkdir(path) {
    await this.fetch(path.replace(/\/?$/, '/'), { method: 'MKCOL' });
  }

  async rename(from, to) {
    await this.fetch(from, { method: 'MOVE', headers: { Destination: this.url(to), Overwrite: 'T' } });
  }
}

/**
 * A PROPFIND answer, as entries: every <response> but the folder's own.
 * Read by pattern, whatever prefix a server gives the DAV: namespace
 * (D:, d:, lp1:), so it works the same in a browser and in Node.
 */
export function parseMultistatus(xml, selfPath) {
  const tag = name => new RegExp(`<(?:[\\w-]+:)?${name}\\b[^>]*>([\\s\\S]*?)</(?:[\\w-]+:)?${name}>`, 'i');
  const unslash = p => decodeURIComponent(p).replace(/\/+$/, '');
  const out = [];
  for (const part of xml.split(/<(?:[\w-]+:)?response\b[^>]*>/i).slice(1)) {
    const href = (part.match(tag('href')) ?? [])[1];
    if (!href) continue;
    const path = new URL(href.trim(), 'http://x').pathname;
    if (unslash(path) === unslash(selfPath)) continue;
    const name = unslash(path).split('/').pop();
    const dir = /<(?:[\w-]+:)?collection\b/i.test(part);
    const size = Number((part.match(tag('getcontentlength')) ?? [])[1] ?? 0);
    const modified = (part.match(tag('getlastmodified')) ?? [])[1];
    out.push({ name, size, date: modified ? new Date(modified) : new Date(0), dir });
  }
  return out;
}
