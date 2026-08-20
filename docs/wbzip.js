// wbzip.js - add ONE small file to a .jsdos bundle, in the browser, without
// a zip library and without recompressing a byte of it.
//
// WHY THIS EXISTS. js-dos 8.3.20 gives a page three ways in, and two of them
// are closed to us. Reading its loader:
//
//     if (options.url)             -> initFs is hardcoded null
//     else if (options.dosboxConf) -> initFs is honoured, but there is no url
//
// so a bundle loaded by URL can be given NEITHER a custom dosbox.conf NOR
// extra files, and the conf-mode with the whole bundle handed over as initFs
// boots to a black screen. The second bundle js-dos does layer on top is its
// own cloud-saves blob, fetched from its storage - not ours to supply.
//
// What is left is the plain `url` path that every page here already uses -
// and `url` may be a blob:, because the loader simply fetch()es it. So the
// page fetches the real bundle once, appends one tiny file to those exact
// bytes, and hands the result over as a blob URL. Nothing is re-deflated:
// the original entries are copied byte for byte and the new one is STORED.
//
// The appended file is how the page tells the disk where to go:
//
//     GOTO.TXT   one line, e.g.  LESSONS\L07
//
// MENU.COM reads it at startup, opens that entry's screen, and deletes
// nothing - reloading the page gives a clean machine either way.

(function (root) {
  var T = null;
  function crc32(buf) {
    if (T === null) {
      T = new Uint32Array(256);
      for (var n = 0; n < 256; n++) {
        var c = n;
        for (var k = 0; k < 8; k++) c = (c & 1) ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
        T[n] = c >>> 0;
      }
    }
    var crc = 0xFFFFFFFF;
    for (var i = 0; i < buf.length; i++) crc = T[(crc ^ buf[i]) & 0xFF] ^ (crc >>> 8);
    return (crc ^ 0xFFFFFFFF) >>> 0;
  }

  // The End of Central Directory record is the last thing in the file, and
  // it is what every reader starts from: it says how many entries there are
  // and where the central directory begins. Scan back for its signature -
  // the comment field means it is not at a fixed offset.
  function findEOCD(b) {
    for (var i = b.length - 22; i >= 0 && i > b.length - 22 - 65536; i--) {
      if (b[i] === 0x50 && b[i + 1] === 0x4B && b[i + 2] === 0x05 && b[i + 3] === 0x06) return i;
    }
    return -1;
  }

  // name: an ASCII path inside the zip. text: the file's contents.
  function addFile(bundle, name, text) {
    var b = new Uint8Array(bundle);
    var eocd = findEOCD(b);
    if (eocd < 0) throw new Error("not a zip: no end-of-central-directory");
    var dv = new DataView(b.buffer, b.byteOffset, b.byteLength);
    var count = dv.getUint16(eocd + 10, true);
    var cdSize = dv.getUint32(eocd + 12, true);
    var cdOff = dv.getUint32(eocd + 16, true);

    var nameB = new Uint8Array(name.length);
    for (var i = 0; i < name.length; i++) nameB[i] = name.charCodeAt(i) & 0xFF;
    var dataB = new Uint8Array(text.length);
    for (var j = 0; j < text.length; j++) dataB[j] = text.charCodeAt(j) & 0xFF;
    var crc = crc32(dataB);

    var lfh = new Uint8Array(30 + nameB.length);
    var lv = new DataView(lfh.buffer);
    lv.setUint32(0, 0x04034B50, true);   // local file header
    lv.setUint16(4, 20, true);           // version needed
    lv.setUint16(6, 0, true);            // flags
    lv.setUint16(8, 0, true);            // method 0 = STORED, nothing to inflate
    lv.setUint16(10, 0, true);           // time
    lv.setUint16(12, 0x21, true);        // date (1 Jan 1996 - a date, not a lie)
    lv.setUint32(14, crc, true);
    lv.setUint32(18, dataB.length, true);
    lv.setUint32(22, dataB.length, true);
    lv.setUint16(26, nameB.length, true);
    lv.setUint16(28, 0, true);
    lfh.set(nameB, 30);

    var cdh = new Uint8Array(46 + nameB.length);
    var cv = new DataView(cdh.buffer);
    cv.setUint32(0, 0x02014B50, true);   // central directory header
    cv.setUint16(4, 20, true);
    cv.setUint16(6, 20, true);
    cv.setUint16(8, 0, true);
    cv.setUint16(10, 0, true);
    cv.setUint16(12, 0, true);
    cv.setUint16(14, 0x21, true);
    cv.setUint32(16, crc, true);
    cv.setUint32(20, dataB.length, true);
    cv.setUint32(24, dataB.length, true);
    cv.setUint16(28, nameB.length, true);
    cv.setUint32(42, cdOff, true);       // our entry starts where the old CD did
    cdh.set(nameB, 46);

    // the new file goes exactly where the central directory used to start,
    // and the directory - old entries unchanged, ours appended - follows it
    var out = new Uint8Array(cdOff + lfh.length + dataB.length + cdSize + cdh.length + 22);
    var p = 0;
    out.set(b.subarray(0, cdOff), p); p += cdOff;
    out.set(lfh, p); p += lfh.length;
    out.set(dataB, p); p += dataB.length;
    var newCdOff = p;
    out.set(b.subarray(cdOff, cdOff + cdSize), p); p += cdSize;
    out.set(cdh, p); p += cdh.length;

    var ev = new DataView(out.buffer, p, 22);
    ev.setUint32(0, 0x06054B50, true);
    ev.setUint16(4, 0, true);
    ev.setUint16(6, 0, true);
    ev.setUint16(8, count + 1, true);
    ev.setUint16(10, count + 1, true);
    ev.setUint32(12, cdSize + cdh.length, true);
    ev.setUint32(16, newCdOff, true);
    ev.setUint16(20, 0, true);
    return out;
  }

  root.WBZip = { addFile: addFile, crc32: crc32 };
  if (typeof module !== "undefined" && module.exports) module.exports = root.WBZip;
})(typeof window !== "undefined" ? window : globalThis);
