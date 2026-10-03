// The files of a zip - a .jsdos bundle is one - read in the page, so a
// program packed as a bundle can be put on a disk of the page's own
// machine instead of booting a machine of its own.
//
// A zip ends with a central directory: one record per file, saying where
// its local header is and how it was stored. Stored (0) is the bytes as
// they are; deflated (8) is what the browser's DecompressionStream
// ('deflate-raw') undoes. Nothing else is needed for a bundle.

export async function unzip(bytes) {
  const b = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
  const view = new DataView(b.buffer, b.byteOffset, b.byteLength);
  // The end-of-directory record: 22 bytes, at most a 64K comment after it.
  let end = -1;
  for (let i = b.length - 22; i >= Math.max(0, b.length - 22 - 65535); i--) {
    if (view.getUint32(i, true) === 0x06054b50) { end = i; break; }
  }
  if (end < 0) throw new Error('Not a zip: it has no central directory.');
  const count = view.getUint16(end + 10, true);
  let at = view.getUint32(end + 16, true);
  const out = [];
  for (let n = 0; n < count; n++) {
    if (view.getUint32(at, true) !== 0x02014b50) throw new Error('A damaged zip: a directory record is not where it should be.');
    const method = view.getUint16(at + 10, true);
    const packed = view.getUint32(at + 20, true);
    const nameLen = view.getUint16(at + 28, true);
    const extraLen = view.getUint16(at + 30, true);
    const commentLen = view.getUint16(at + 32, true);
    const local = view.getUint32(at + 42, true);
    const name = new TextDecoder().decode(b.subarray(at + 46, at + 46 + nameLen));
    at += 46 + nameLen + extraLen + commentLen;
    if (name.endsWith('/')) continue; // a folder: its files say so
    const start = local + 30 + view.getUint16(local + 26, true) + view.getUint16(local + 28, true);
    const data = b.subarray(start, start + packed);
    let contents;
    if (method === 0) contents = data.slice();
    else if (method === 8) contents = new Uint8Array(await new Response(new Blob([data]).stream().pipeThrough(new DecompressionStream('deflate-raw'))).arrayBuffer());
    else throw new Error(`${name} is packed a way this does not read (method ${method}).`);
    out.push({ path: name, contents });
  }
  return out;
}
