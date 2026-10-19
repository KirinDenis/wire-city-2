// The world of OWL FLY II and III, built here as the game builds it (the
// pilot, 2026-10-18: the live map draws the room's own ground). The server's
// 'G' ad carries the seed; from it come the same heightmap, the same four
// aerodromes, the same two radar masts and the same block table the game
// has - because this is the game's own code, routine by routine, on 16-bit
// registers: the same random stream, the same integer sums, the same order.
// Change one line here and the map shows somebody else's world.
//
// The routines come from ENGINE\E_MATH.INC, ENGINE\E_TERR.INC and OWL FLY
// II's SRC (UI.INC, TOWN.INC, TERRAIN.INC, WORLD2.INC). OWL FLY III's copies
// are the same line for line. Its LOW detail (qual 2) is another world - one
// flat height, no Diamond-Square - and is not built here.
//
// THE BUILD, in the game's order (CITY.ASM / OWLFLY3.ASM, after the menu),
// and what each step takes from the one random stream:
//
//   rseed = wseed = seed    the joiner takes it from the ad, the host mints it
//   DSTCLR        0 draws   clears the rubble bits, not the map
//   DSGEN      4097         4 anchors, 4092 noise points, one extra at the end
//   AFINITF       0         sites the aerodromes and irons the ground flat
//   BLKTABF       0         the block table, read off the ironed map
//   MMAPGENF      0         the game's own minimap
//   BRDGEN       17         the front line
//   SKYBAKE     896         the clouds - nothing on the map, not built here
//   AFSPAWNF      0
//   RSTAINITF     0         the radar masts, beside fields 0 and 1
//
// So everything random on the map is DSGEN's or BRDGEN's, and nothing
// between the seed and BRDGEN draws anything else: the seed alone decides it.
// selfTest() holds DSGEN to its 4097.
//
// Units: a heightmap node is 1024 world units, a cell 256, a block 8 cells,
// the world a 65536 torus; +x east, +z north. Positions are 16-bit words,
// as the game holds them - 0..65535 here, so world -7680 is 57856. Compare
// them modulo 65536.
//
//   buildWorld(seed) -> { seed, hmap, fields, radars, blocks, border }
//     hmap     Uint8Array(4096), node (nx, nz) at nx*64 + nz, AFTER AFINITF
//     fields   the four aerodromes: { nx, nz, x, z, h, height, side, sited,
//              heading, halfLength, halfWidth }
//     radars   the two masts: { x, z, y, field, side, found }
//     blocks   Uint8Array(1024), BLKT: block (i, j) at i*32 + j
//     border   Int16Array(17), bordz: the front line's z offsets
//   nodeOf(x, z), mapCell(x, z), built(world, i, j), building(world, gi, gj),
//   groundHeight(world, x, z), selfTest()

export const WORLD = 65536, BIAS = 8192, NODE = 1024, CELL = 256;

// DATA.INC: the aerodromes. Four strips, even ours and odd theirs, laid
// north-south so ours point at the war and the takeoff heading is 0.
const NAF = 4;
const AFHLO = 96, AFHHI = 116;          // the band a strip's height is clamped into: grass, never city
const AFNW = 2, AFNL = 4;               // the patch AFPATCH judges, in nodes
const AFSW = 5, AFSL = 7;               // ...and the one AFINITF irons, a node wider all round
const AFSEA = 92, AFTOP = 190;          // no corner of the judged patch below, none of it above
const AFREACH = 12;                     // how far the siting walk goes, in nodes
const AFLEN = 1500, AFW = 150;          // the concrete: half-length along z, half-width across
const AFSITX = [24576 - 4000, 24576 - 4000, 24576 + 4000, 24576 + 4000];      // UI.INC: the nominal sites
const AFSITZ = [24576 - 9500, 24576 + 9500, 24576 - 11500, 24576 + 11500];
// The radar stations.
const NRSTA = 2;
const RSAPRON = 800;                    // the mast stands this far east of its runway's centreline
const GNDLO = 20, GNDHI = 430;          // FINDGND: world heights a site may stand on

const idiv = (a, b) => Math.trunc(a / b);      // IDIV: the quotient rounds toward zero
const word = v => Math.floor(v) & 0xFFFF;      // what a 16-bit register keeps of a number
const hget = (hm, x, z) => hm[((x & 63) << 6) | (z & 63)];   // HGET: the map is a torus

// ---------------------------------------------------------------------------
// RND16 (ENGINE\E_MATH.INC). x*25173 + 13849 on one word: MUL is 16x16->32
// and only AX is kept, so the product wraps at 65536. It counts its draws,
// so the test can hold every routine to the game's number.
// ---------------------------------------------------------------------------
function lcg(seed) {
  const r = { seed: seed & 0xFFFF, draws: 0 };
  r.next = () => { r.draws++; return (r.seed = (Math.imul(r.seed, 25173) + 13849) & 0xFFFF); };
  return r;
}

// ---------------------------------------------------------------------------
// DSGEN (ENGINE\E_TERR.INC). Diamond-Square on a 64x64 torus, then a stretch
// to the full 0..255. Every draw uses the HIGH byte: in a 2^16 LCG the low
// bits cycle short, and one map is exactly 4096 draws. `fill` is what HMAP
// held before - it cannot matter, every node is written before it is read,
// and the test proves that by building on 0 and on 255.
// ---------------------------------------------------------------------------
function dsgen(rnd, fill = 0) {
  const hm = new Uint8Array(4096).fill(fill);
  const put = (x, z, v) => { hm[((x & 63) << 6) | (z & 63)] = v; };
  const anchor = () => ((rnd.next() >> 8) & 127) + 64;       // anchors 64..191, mid range
  put(0, 0, anchor());
  put(32, 0, anchor());
  put(0, 32, anchor());
  put(32, 32, anchor());
  let s = 32, amp = 128;
  // .noise: the average of four plus (rnd & (amp-1)) - amp/2, clamped to a byte.
  const noise = sum => {
    const v = ((rnd.next() >> 8) & (amp - 1)) - (amp >> 1) + (sum >> 2);
    return v < 0 ? 0 : v > 255 ? 255 : v;
  };
  do {
    const h = s >> 1;
    // The diamond step: the middle of every square.
    for (let x = 0; x < 64; x += s) {
      for (let z = 0; z < 64; z += s) {
        put(x + h, z + h, noise(hget(hm, x, z) + hget(hm, x + s, z) + hget(hm, x + s, z + s) + hget(hm, x, z + s)));
      }
    }
    // The square step: two edge midpoints of every square, (x+h, z) first.
    for (let x = 0; x < 64; x += s) {
      for (let z = 0; z < 64; z += s) {
        put(x + h, z, noise(hget(hm, x, z) + hget(hm, x + s, z) + hget(hm, x + h, z - h) + hget(hm, x + h, z + h)));
        put(x, z + h, noise(hget(hm, x, z) + hget(hm, x, z + s) + hget(hm, x - h, z + h) + hget(hm, x + h, z + h)));
      }
    }
    s = h;                                // the next octave: half the side,
    amp = Math.max(4, amp >> 1);          // half the amplitude, never under 4
  } while (s > 1);
  // The stretch: min..max -> 0..255. MUL then DIV word, so it floors.
  let lo = 255, hi = 0;
  for (const v of hm) { if (v < lo) lo = v; if (v > hi) hi = v; }
  const range = hi - lo;
  if (range) for (let i = 0; i < 4096; i++) hm[i] = Math.floor(((hm[i] - lo) * 255) / range);
  rnd.next();                             // the one extra draw: 4097 is coprime with the period,
  return hm;                              //  so a run of islands does not loop every 8 worlds
}

// ---------------------------------------------------------------------------
// WORLDH (ENGINE\E_TERR.INC). A map height to a world height: the sea floor
// is 0, land rises 5 a unit, and above 560 (H 200) twice as fast.
// ---------------------------------------------------------------------------
function worldh(h) {
  let a = h - 88;
  if (a < 0) return 0;
  a *= 5;
  return a > 560 ? a + (a - 560) : a;
}

// ---------------------------------------------------------------------------
// TERRH (TERRAIN.INC). The height of the ground at a world point: the four
// nodes round it, blended in 1/64ths of a node. IMUL keeps the product in
// DX:AX, so (h10-h00)*fx may pass 32767 and still divides right.
// ---------------------------------------------------------------------------
function terrh(hm, x, z) {
  const u = word(x + BIAS), v = word(z + BIAS);
  const nx = u >> 10, fx = (u >> 4) & 63, nz = v >> 10, fz = (v >> 4) & 63;
  const h00 = worldh(hget(hm, nx, nz)), h10 = worldh(hget(hm, nx + 1, nz));
  const h01 = worldh(hget(hm, nx, nz + 1)), h11 = worldh(hget(hm, nx + 1, nz + 1));
  const ha = h00 + idiv((h10 - h00) * fx, 64);
  const hb = h01 + idiv((h11 - h01) * fx, 64);
  return ha + idiv((hb - ha) * fz, 64);
}

// ---------------------------------------------------------------------------
// AFPATCH (UI.INC). Judge one candidate patch, AFNW x AFNL nodes from its
// top-left node: -1 if a corner is in the sea or up the mountain, else the
// spread of its heights. A strip wants a legal patch, not a legal point.
// ---------------------------------------------------------------------------
function afpatch(hm, cx, cz) {
  let lo = 255, hi = 0;
  for (let u = 0; u < AFNW; u++) {
    for (let v = 0; v < AFNL; v++) {
      const h = hget(hm, cx + u, cz + v);
      if (h < lo) lo = h;
      if (h > hi) hi = h;
    }
  }
  return lo < AFSEA || hi > AFTOP ? -1 : hi - lo;
}

// ---------------------------------------------------------------------------
// AFINITF (UI.INC). Site the four aerodromes and iron the ground under them,
// before the block table is read off the map - that is what keeps houses
// off the runways. Each walks out in rings from its nominal node; the
// flattest patch wins, plus one per ring walked, the first found on a tie.
// The fields go one after another: field 1 is judged on the map field 0
// has already ironed.
// ---------------------------------------------------------------------------
function afinit(hm) {
  const fields = [];
  // afbx/afbz are words in the code segment, 0 in a freshly loaded EXE and
  // never reset: a field that finds no legal patch inherits the last one's.
  let bx = 0, bz = 0;
  for (let i = 0; i < NAF; i++) {
    const nx = word(AFSITX[i] + BIAS) >> 10, nz = word(AFSITZ[i] + BIAS) >> 10;
    let best = 0x7FFF, sited = false;
    for (let r = 0; r <= AFREACH; r++) {
      for (let du = -r; du <= r; du++) {
        for (let dv = -r; dv <= r; dv++) {
          if (Math.max(Math.abs(du), Math.abs(dv)) !== r) continue;     // a ring, not a square
          const spread = afpatch(hm, nx + du - (AFNW >> 1), nz + dv - (AFNL >> 1));
          if (spread < 0 || spread + r >= best) continue;
          best = spread + r;
          bx = nx + du;
          bz = nz + dv;
          sited = true;
        }
      }
    }
    // The middle of the chosen node, in the world.
    const x = word(((bx & 63) << 10) - BIAS + 512), z = word(((bz & 63) << 10) - BIAS + 512);
    const h = Math.min(AFHHI, Math.max(AFHLO, hget(hm, bx, bz)));
    // Iron AFSW x AFSL nodes round the centre node: TERRH blends the nodes
    // past the judged patch too, and the strip has to read level all along.
    const cx = word(x + BIAS) >> 10, cz = word(z + BIAS) >> 10;
    for (let u = 0; u < AFSW; u++) {
      for (let v = 0; v < AFSL; v++) hm[((cx + u - (AFSW >> 1)) & 63) << 6 | ((cz + v - (AFSL >> 1)) & 63)] = h;
    }
    fields.push({
      nx: cx, nz: cz, x, z,
      h,                                  // afh: the heightmap value every ironed node carries
      height: terrh(hm, x, z),            // afy: the concrete's world height
      side: i & 1,                        // even ours, odd theirs
      sited,                              // false: no legal patch in reach, the last field's node reused
      heading: 0, halfLength: AFLEN, halfWidth: AFW,   // north-south along z
    });
  }
  return fields;
}

// ---------------------------------------------------------------------------
// FINDGND (UI.INC). Walk out from a nominal spot until the ground is worth
// standing on: sixteen points a ring on a 3x3 compass, 10 units further
// each ring, and the highest legal one of the first ring that has any.
// ---------------------------------------------------------------------------
const compass = k => (k === 3 ? 0 : k - 1);    // (k & 3) - 1, and the stray 2 folded to 0
function findgnd(hm, x0, z0) {
  for (let p = 0; p < 40; p++) {
    let best = 0, gx = 0, gz = 0;
    for (let e = 0; e < 16; e++) {
      const x = word(x0 + compass(e & 3) * (p + 1) * 10), z = word(z0 + compass((e >> 2) & 3) * (p + 1) * 10);
      const y = terrh(hm, x, z);
      if (y < GNDLO || y > GNDHI || y <= best) continue;
      best = y;
      gx = x;
      gz = z;
    }
    if (best) return { x: gx, z: gz, y: best, found: true };
  }
  return { x: x0, z: z0, y: 0, found: false };      // nothing legal: left where it was, at height 0
}

// ---------------------------------------------------------------------------
// RSTAINIT + RSTAGND (UI.INC). The radar stands on the aerodrome: station 0
// beside field 0, station 1 beside field 1, RSAPRON east of the centreline,
// then FINDGND for its footing.
// ---------------------------------------------------------------------------
function rstainit(hm, fields) {
  const radars = [];
  for (let i = 0; i < NRSTA; i++) {
    const g = findgnd(hm, word(fields[i].x + RSAPRON), fields[i].z);
    radars.push({ x: g.x, z: g.z, y: g.y, field: i, side: i, found: g.found });
  }
  return radars;
}

// ---------------------------------------------------------------------------
// BLKHASH (TOWN.INC). The superblock hash of block (i, j), character for
// character the old SBHASH - the streets and the houses must agree on it.
// ---------------------------------------------------------------------------
function blkhash(i, j) {
  const s = ((331 * (i & 31)) + (769 * (j & 31))) & 0xFFFF;
  return s ^ (s >> 4);
}

// ---------------------------------------------------------------------------
// BLKTABF (TOWN.INC). One byte per block, the whole world in 32x32:
//   bits 0..3  the hash's low nibble - the 3-in-16 clustering test
//   bits 4..5  the district: 0/3 residential, 1 downtown, 2 industry
//   bit  6     BLKCITY: the block's centre node (2i+1, 2j+1) is in 120..167
// ---------------------------------------------------------------------------
function blktab(hm) {
  const blocks = new Uint8Array(1024);
  for (let i = 0; i < 32; i++) {
    for (let j = 0; j < 32; j++) {
      const h = hget(hm, 2 * i + 1, 2 * j + 1);
      blocks[(i << 5) + j] = (blkhash(i, j) & 0x3F) | (h >= 120 && h < 168 ? 0x40 : 0);
    }
  }
  return blocks;
}

// ---------------------------------------------------------------------------
// BRDGEN (TERRAIN.INC). The front line: 17 z offsets, +-768 round z = 24576.
// The game's maps draw it a band of four node columns at a time: column c
// takes border[c >> 2] (so the 17th is never drawn), at row
// 63 - (((border + 24576 + BIAS) & 0xFFFF) >> 10).
// ---------------------------------------------------------------------------
function brdgen(rnd) {
  const border = new Int16Array(17);
  for (let k = 0; k < 17; k++) border[k] = ((rnd.next() >> 8) - 128) * 6;
  return border;
}

/** The world of a seed, as the game has it once RSTAINITF is done. */
export function buildWorld(seed) {
  const rnd = lcg(seed);
  const hmap = dsgen(rnd);
  const fields = afinit(hmap);
  const blocks = blktab(hmap);
  const border = brdgen(rnd);         // MMAPGENF, between them, draws nothing
  const radars = rstainit(hmap, fields);
  return { seed: seed & 0xFFFF, hmap, fields, radars, blocks, border };
}

/** World point -> heightmap node, as AFINITF and TERRH take it. */
export function nodeOf(x, z) {
  return { nx: word(x + BIAS) >> 10, nz: word(z + BIAS) >> 10 };
}

/** World point -> the game's map: a pixel a node, north up (MAPHUM). */
export function mapCell(x, z) {
  return { col: word(x + BIAS) >> 10, row: 63 - (word(z + BIAS) >> 10) };
}

/**
 * Is block (i, j) a BUILT city block (BLKCTY, TOWN.INC)? Its centre node in
 * the city band and its nibble under 3. It is the game's own answer: its
 * streets are paved by it (ROADOKF) and its minimap paints it as town. The
 * houses themselves are planted plot by plot - see building().
 */
export function built(world, i, j) {
  const b = world.blocks[((i & 31) << 5) + (j & 31)];
  return (b & 0x40) !== 0 && (b & 15) < 3;
}

// CELLHASH (WORLD2.INC): mix(gi*1973 + gj*9277), IMUL keeping the low word.
function cellhash(gi, gj) {
  const s = (Math.imul(gi, 1973) + Math.imul(gj, 9277)) & 0xFFFF;
  return s ^ (s >> 7);
}

/**
 * Does a building stand on the plot at cell (gi, gj)? HBLD (WORLD2.INC), the
 * whole of its yes: not on the avenue strip (ISROAD: cells 0 and 1 of every
 * 8, each way), the cell's own node in the city band (GETZONE), the even
 * corner of a 2x2 plot, not a forest, pond or field patch (hash & 31 = 7, 8,
 * 9), and its block's nibble under 3. Nine plots a block at most; a house
 * covers cells gi..gi+1 x gj..gj+1, its centre at (gi*256 + 256 - BIAS,
 * gj*256 + 256 - BIAS). It does not ask BLKCITY: a block built() calls
 * empty can still carry a house or two where its own nodes are in the band,
 * with no street round them (about 18 blocks, 44 houses, a world). Cells
 * are 0..255 here. Within 9 cells of the seam (x or z near -8192) the game
 * hashes the cell number unwrapped - 256 rather than 0 - so seen from across
 * the seam a pond or a house there can come out the other way.
 */
export function building(world, gi, gj) {
  gi &= 0xFFFF;
  gj &= 0xFFFF;
  if ((gi & 7) < 2 || (gj & 7) < 2) return false;
  const h = hget(world.hmap, gi >> 2, gj >> 2);
  if (h < 120 || h >= 168) return false;
  if ((gi | gj) & 1) return false;
  const k = cellhash(gi, gj) & 31;
  if (k >= 7 && k <= 9) return false;
  return (world.blocks[(((gi >> 3) & 31) << 5) + ((gj >> 3) & 31)] & 15) < 3;
}

/** The ground's world height at a point, as the game's TERRH has it (0..1110). */
export function groundHeight(world, x, z) {
  return terrh(world.hmap, x, z);
}

/** The module held to the game's own numbers and to itself: the list of what is wrong, empty when nothing is. */
export function selfTest() {
  const bad = [];
  // RND16 has the full period: 65536 draws before the seed comes back.
  const r0 = lcg(1);
  let back = 0;
  for (let n = 1; n <= 65536; n++) if (r0.next() === 1) { back = n; break; }
  if (back !== 65536) bad.push(`RND16 returns to its seed after ${back} draws, not 65536`);

  for (const seed of [1, 12345, 38599, 21845, 0x8001, 0xFFFF]) {
    const t = `seed ${seed}`;
    const r = lcg(seed), raw = dsgen(r);
    if (r.draws !== 4097) bad.push(`${t}: DSGEN drew ${r.draws}, the game draws 4097`);
    let lo = 255, hi = 0;
    for (const v of raw) { lo = Math.min(lo, v); hi = Math.max(hi, v); }
    if (lo !== 0 || hi !== 255) bad.push(`${t}: the stretch left ${lo}..${hi}`);
    if (!same(raw, dsgen(lcg(seed), 255))) bad.push(`${t}: DSGEN read a node before writing it`);

    const w = buildWorld(seed), again = buildWorld(seed);
    if (!same(w.hmap, again.hmap) || !same(w.blocks, again.blocks) || !same(w.border, again.border) ||
      JSON.stringify([w.fields, w.radars]) !== JSON.stringify([again.fields, again.radars])) bad.push(`${t}: two builds differ`);
    if (w.fields.length !== NAF) bad.push(`${t}: ${w.fields.length} fields`);
    if (w.radars.length !== NRSTA) bad.push(`${t}: ${w.radars.length} radars`);

    // The fields: ironed flat at a grass height, the concrete at its world height.
    const ironed = new Uint8Array(4096);
    for (const [n, f] of w.fields.entries()) {
      if (f.h < AFHLO || f.h > AFHHI) bad.push(`${t}: field ${n} stamped at ${f.h}`);
      if (f.height !== worldh(f.h)) bad.push(`${t}: field ${n} concrete at ${f.height}, its map says ${worldh(f.h)}`);
      const c = nodeOf(f.x, f.z), m = mapCell(f.x, f.z);
      if (c.nx !== f.nx || c.nz !== f.nz || m.col !== f.nx || m.row !== 63 - f.nz) bad.push(`${t}: field ${n} is not where its node says`);
      for (let u = -2; u <= 2; u++) for (let v = -3; v <= 3; v++) ironed[((f.nx + u) & 63) << 6 | ((f.nz + v) & 63)] = 1;
    }
    // The last field's patch is the one standing; an earlier one may be partly ironed over by a later.
    const last = w.fields[NAF - 1];
    for (let u = -2; u <= 2; u++) for (let v = -3; v <= 3; v++) {
      if (hget(w.hmap, last.nx + u, last.nz + v) !== last.h) bad.push(`${t}: field ${NAF - 1}'s ground is not flat`);
    }
    for (let i = 0; i < 4096; i++) if (!ironed[i] && w.hmap[i] !== raw[i]) { bad.push(`${t}: node ${i} changed outside the fields`); break; }

    // The masts: on legal ground, the height TERRH gives there.
    for (const [n, s] of w.radars.entries()) {
      if (s.found && (s.y < GNDLO || s.y > GNDHI || groundHeight(w, s.x, s.z) !== s.y)) bad.push(`${t}: radar ${n} stands at ${s.y}`);
      if (!s.found && s.y !== 0) bad.push(`${t}: radar ${n} found nothing but stands at ${s.y}`);
    }

    // The block table: the hash's six bits, and BLKCITY from the centre node.
    for (let i = 0; i < 32; i++) for (let j = 0; j < 32; j++) {
      const b = w.blocks[i * 32 + j], h = hget(w.hmap, 2 * i + 1, 2 * j + 1);
      if ((b & 0x3F) !== (blkhash(i, j) & 0x3F) || !!(b & 0x40) !== (h >= 120 && h < 168) || b & 0x80) bad.push(`${t}: block ${i},${j} is ${b}`);
    }
    if (w.border.some(v => v < -768 || v > 762)) bad.push(`${t}: the front line strays past +-768`);
  }
  if (same(buildWorld(12345).hmap, buildWorld(38599).hmap)) bad.push('two seeds built one world');
  return bad;
}
const same = (a, b) => a.length === b.length && a.every((v, i) => v === b[i]);
