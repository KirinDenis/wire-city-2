// A ZIP made in the page (the pilot, 2026-10-19: a model makes a DOS game
// and hands it over "as a ZIP"): the console's `zip` puts a folder of a
// drive into one, for this computer's downloads. Each file deflated by the
// browser's own CompressionStream - or stored, when that is no smaller -
// with DOS's date and time, as PKZIP wrote them. The library's unzip.js
// reads it back (the rigs check one against the other).

const CRC = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c >>> 0;
  }
  return t;
})();

function crc32(bytes) {
  let c = 0xFFFFFFFF;
  for (let i = 0; i < bytes.length; i++) c = CRC[(c ^ bytes[i]) & 255] ^ (c >>> 8);
  return (c ^ 0xFFFFFFFF) >>> 0;
}

async function deflate(bytes) {
  return new Uint8Array(await new Response(new Blob([bytes]).stream().pipeThrough(new CompressionStream('deflate-raw'))).arrayBuffer());
}

/** A date as DOS keeps one: two words, the time in two-second steps, the date from 1980. */
function dosTime(d) {
  const year = Math.max(1980, d.getFullYear());
  return {
    time: (d.getHours() << 11) | (d.getMinutes() << 5) | (d.getSeconds() >> 1),
    date: ((year - 1980) << 9) | ((d.getMonth() + 1) << 5) | d.getDate(),
  };
}

/** files: [{ path: 'HELI/HELI.ASM', bytes: Uint8Array, date?: Date }] -> a Blob of the ZIP. */
export async function zip(files) {
  const parts = [], central = [];
  let offset = 0;
  for (const f of files) {
    const name = new TextEncoder().encode(f.path);
    const crc = crc32(f.bytes);
    let data = await deflate(f.bytes), method = 8;
    if (data.length >= f.bytes.length) { data = f.bytes; method = 0; }
    const { time, date } = dosTime(f.date instanceof Date && !isNaN(f.date) ? f.date : new Date());
    const local = new Uint8Array(30 + name.length), l = new DataView(local.buffer);
    l.setUint32(0, 0x04034b50, true);         // a file's own header
    l.setUint16(4, 20, true);                 // version needed: 2.0
    l.setUint16(8, method, true);
    l.setUint16(10, time, true);
    l.setUint16(12, date, true);
    l.setUint32(14, crc, true);
    l.setUint32(18, data.length, true);
    l.setUint32(22, f.bytes.length, true);
    l.setUint16(26, name.length, true);
    local.set(name, 30);
    const cen = new Uint8Array(46 + name.length), c = new DataView(cen.buffer);
    c.setUint32(0, 0x02014b50, true);         // its line in the central directory
    c.setUint16(4, 20, true);                 // made by 2.0
    c.setUint16(6, 20, true);
    c.setUint16(10, method, true);
    c.setUint16(12, time, true);
    c.setUint16(14, date, true);
    c.setUint32(16, crc, true);
    c.setUint32(20, data.length, true);
    c.setUint32(24, f.bytes.length, true);
    c.setUint16(28, name.length, true);
    c.setUint32(42, offset, true);            // where its own header is
    cen.set(name, 46);
    parts.push(local, data);
    central.push(cen);
    offset += local.length + data.length;
  }
  const size = central.reduce((n, x) => n + x.length, 0);
  const end = new Uint8Array(22), e = new DataView(end.buffer);
  e.setUint32(0, 0x06054b50, true);           // the end of the directory
  e.setUint16(8, files.length, true);
  e.setUint16(10, files.length, true);
  e.setUint32(12, size, true);
  e.setUint32(16, offset, true);
  return new Blob([...parts, ...central, end], { type: 'application/zip' });
}

/** A Blob into this computer's downloads, under a name. */
export function download(blob, name) {
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = name;
  document.body.append(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(a.href), 60000);
}
