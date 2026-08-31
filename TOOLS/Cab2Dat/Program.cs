// ============================================================================
//  Cab2Dat - a vehicle cabin PNG -> a WIRE CITY span-stream blob.
//
//      dotnet run --project TOOLS\Cab2Dat -- shilka.png -pal SRC\PALPNL.INC
//                 -o INSTALL\SHCAB.DAT [-bmp res\shilka_art.bmp]
//                 [-left left.png -right right.png -so INSTALL\SHSIDE.DAT]
//
//  The Shilka's cabin cannot ride CITY.DAT: that file's directory holds
//  16-bit offsets and the jet's photo cockpit already fills it. So a cabin
//  is its own blob, and a SMARTER one: instead of 64000 raw bytes with a
//  transparent index, it is the SPANS themselves -
//
//      dw span_count
//      then per span:  dw dest (offset in the 320x200 screen)
//                      dw len
//                      len pixel bytes, immediately - INTERLEAVED, so the
//                      drawing loop is one LODSW/LODSW/REP MOVSB stream
//                      with SI never once recomputed
//
//  White in the artwork (the windscreen) becomes ABSENCE: no span covers
//  it, the world stays. Everything else is matched to the palette the jet's
//  cockpit already installed (PALPNL.INC, DAC slots 31..93) - the VGA DAC
//  lends this game 63 panel colours and a fourth picture has to live in
//  the same lease, not demand its own.
//
//  THE SIDE CONSOLES (-left/-right, 2026-08-30) ride a different format:
//  the F6/F7 views are FULL pictures, so they are RLE token streams - the
//  exact grammar SIDEBMPF already plays for the jet's CPSIDE.DAT - packed
//  as one file per card:
//
//      db 'SS'                 magic
//      dw llen, rlen           each stream's length in bytes
//      llen bytes              the left view, then
//      rlen bytes              the right
//
//  Two streams, two lengths, because they land on two different SHELVES:
//  there is no free 64K page left in the game's memory map (the cabin
//  page is the last one under the 640K ceiling), so the right view lives
//  in scrseg past the card bake and the left on the cabin page below
//  the radar's phosphor shelf. The caps below are those shelves' sizes -
//  DATA.INC names them SHSLOFF and SHSROFF - and this tool REFUSES to
//  emit a stream that would not fit, because the loader trusting a fat
//  file would write over the jet's own side art.
//
//  C#, per the project's tooling contract. Output is committed.
// ============================================================================
using System.IO.Compression;
using System.Text;

int OW = 320, OH = 200;

string src = null, palPath = null, outPath = null, bmpPath = null;
string leftPath = null, rightPath = null, sideOut = null;
for (int i = 0; i < args.Length; i++)
{
    switch (args[i])
    {
        case "-pal": palPath = args[++i]; break;
        case "-o": outPath = args[++i]; break;
        case "-bmp": bmpPath = args[++i]; break;
        case "-left": leftPath = args[++i]; break;
        case "-right": rightPath = args[++i]; break;
        case "-so": sideOut = args[++i]; break;
        default: src = args[i]; break;
    }
}
if (src == null || palPath == null || outPath == null)
{
    Console.Error.WriteLine("usage: Cab2Dat cabin.png -pal PALPNL.INC -o CAB.DAT [-bmp check.bmp] [-left l.png -right r.png -so SIDE.DAT]");
    return 1;
}
if ((leftPath != null || rightPath != null || sideOut != null) &&
    (leftPath == null || rightPath == null || sideOut == null))
{
    Console.Error.WriteLine("error: -left, -right and -so travel together - the two views share one file");
    return 1;
}

// ---- the palette the jet already installed: 63 DAC triplets, 0..63 --------
var pal = new List<(int r, int g, int b)>();
foreach (var line in File.ReadAllLines(palPath))
{
    var t = line.Trim();
    if (!t.StartsWith("db ")) continue;
    var nums = t.Substring(3).Split(';')[0].Split(',');
    if (nums.Length != 3) continue;
    pal.Add((int.Parse(nums[0].Trim()) << 2, int.Parse(nums[1].Trim()) << 2,
             int.Parse(nums[2].Trim()) << 2));
}
if (pal.Count != 63)
{ Console.Error.WriteLine($"error: {palPath} holds {pal.Count} colours, not 63"); return 1; }
Console.WriteLine($"palette: 63 colours from {Path.GetFileName(palPath)} (indexes 31..93)");

// ---- the curated EGA sixteen, VidRig's table verbatim ----------------------
int[][] ega16 = {
    new[]{0,0,0},   new[]{0,0,85},    new[]{0,85,170},  new[]{0,170,255},
    new[]{85,170,255}, new[]{170,255,255}, new[]{0,85,0}, new[]{85,170,85},
    new[]{85,255,85}, new[]{170,85,0}, new[]{85,85,85},  new[]{170,170,170},
    new[]{0,170,170}, new[]{255,0,0},  new[]{255,170,0}, new[]{255,255,255},
};
int Near16(int r, int g, int b)
{
    int best = 0, bd = int.MaxValue;
    for (int c = 0; c < 16; c++)
    {
        int dr = r - ega16[c][0], dg = g - ega16[c][1], db2 = b - ega16[c][2];
        int d = dr * dr + 2 * dg * dg + db2 * db2;
        if (d < bd) { bd = d; best = c; }
    }
    return best;
}
const int gDark = 10, gLite = 11, gWhit = 15, gRed = 13;   // 111, 222, white, lamp

// ============================================================================
//  THE ANALYSIS, one picture at a time - shrink, quantise, and draw the
//  retro versions (the pilot's ask, 2026-08-27: drawn, not converted).
//
//  The jet's panel taught the method (TOOLS\VidRig): classify every static
//  pixel into BANDS by the picture's own luminance - seam, texture, plate,
//  stroke, lamp - then let each card DRAW those bands in its own materials:
//  CGA a cyan panel with a checker weave, EGA a flat grey ladder with real
//  outlines, Hercules pure dot density. A naive per-pixel dither of the VGA
//  art gives mush; a drawn panel gives a drawing.
//
//  Markers are 200 + colour, a range the 137-entry palette never reaches;
//  VIDLUT.INC's tables already turn them into solid CGA inks, EGA nibbles
//  and Hercules densities, phase and all.
//
//    CGA       markers 200 black, 201 cyan, 202 magenta, 203 white,
//              204 the positional checker
//    EGA       markers 200+c, c = the curated EGA sixteen
//    Hercules  markers 200..203 = dot density off/quarter/half/full
// ============================================================================
(byte[] idx, byte[] cgaM, byte[] egaM, byte[] hgcM, int solid) Analyze(string path)
{
    var img = Png.Load(path);
    Console.WriteLine($"{Path.GetFileName(path)}: {img.W}x{img.H}");

    // ---- shrink to 320x200 by box average ----------------------------------
    var shr = new byte[OW * OH * 3];
    for (int y = 0; y < OH; y++)
    for (int x = 0; x < OW; x++)
    {
        int x0 = x * img.W / OW, x1 = Math.Max(x0 + 1, (x + 1) * img.W / OW);
        int y0 = y * img.H / OH, y1 = Math.Max(y0 + 1, (y + 1) * img.H / OH);
        long r = 0, g = 0, b = 0; int n = 0;
        for (int sy = y0; sy < y1; sy++)
        for (int sx = x0; sx < x1; sx++)
        {
            int o = (sy * img.W + sx) * 3;
            r += img.P[o]; g += img.P[o + 1]; b += img.P[o + 2]; n++;
        }
        int d = (y * OW + x) * 3;
        shr[d] = (byte)(r / n); shr[d + 1] = (byte)(g / n); shr[d + 2] = (byte)(b / n);
    }

    // ---- quantise: white is the windscreen, everything else finds its slot -
    var idx = new byte[OW * OH];        // 0 = transparent, else palette index
    int solid = 0;
    for (int i = 0; i < OW * OH; i++)
    {
        int r = shr[i * 3], g = shr[i * 3 + 1], b = shr[i * 3 + 2];
        if (r >= 240 && g >= 240 && b >= 240) { idx[i] = 0; continue; }
        int best = 0, bd = int.MaxValue;
        for (int c = 0; c < 63; c++)
        {
            int dr = r - pal[c].r, dg = g - pal[c].g, db2 = b - pal[c].b;
            int dist = dr * dr + 2 * dg * dg + db2 * db2;   // the eye leans green
            if (dist < bd) { bd = dist; best = c; }
        }
        idx[i] = (byte)(31 + best);
        solid++;
    }

    var dyn = new bool[OW * OH];
    for (int i = 0; i < OW * OH; i++) dyn[i] = idx[i] == 0;

    // ---- Kuwahara smooth (radius 2, calmest quadrant) + local mean luma ----
    // VidRig's Measure, verbatim in spirit: the bands must read the PAINT,
    // not the pixel noise the shrink left behind.
    var sm = new byte[OW * OH * 3];
    for (int y = 0; y < OH; y++)
        for (int x = 0; x < OW; x++)
        {
            int i = y * OW + x;
            if (dyn[i]) { Array.Copy(shr, i * 3, sm, i * 3, 3); continue; }
            double bestVar = double.MaxValue; int br = 0, bg = 0, bb = 0;
            for (int q = 0; q < 4; q++)
            {
                int dx0 = (q & 1) == 0 ? -2 : 0, dy0 = (q & 2) == 0 ? -2 : 0;
                long sr = 0, sg = 0, sb = 0, sl = 0, sl2 = 0; int n = 0;
                for (int dy = dy0; dy <= dy0 + 2; dy++)
                    for (int dx = dx0; dx <= dx0 + 2; dx++)
                    {
                        int xx = Math.Clamp(x + dx, 0, OW - 1), yy = Math.Clamp(y + dy, 0, OH - 1);
                        int j = yy * OW + xx;
                        if (dyn[j]) continue;
                        int rr = shr[j * 3], gg = shr[j * 3 + 1], bb2 = shr[j * 3 + 2];
                        int l = (rr * 77 + gg * 151 + bb2 * 28) >> 8;
                        sr += rr; sg += gg; sb += bb2; sl += l; sl2 += l * l; n++;
                    }
                if (n == 0) continue;
                double v = (double)sl2 / n - (double)(sl * sl) / n / n;
                if (v < bestVar) { bestVar = v; br = (int)(sr / n); bg = (int)(sg / n); bb = (int)(sb / n); }
            }
            sm[i * 3] = (byte)br; sm[i * 3 + 1] = (byte)bg; sm[i * 3 + 2] = (byte)bb;
        }
    var luma = new int[OW * OH];
    for (int i = 0; i < OW * OH; i++) luma[i] = (sm[i * 3] * 77 + sm[i * 3 + 1] * 151 + sm[i * 3 + 2] * 28) >> 8;
    var lmean = new int[OW * OH];
    for (int y = 0; y < OH; y++)
        for (int x = 0; x < OW; x++)
        {
            long s = 0; int n = 0;
            for (int dy = -3; dy <= 3; dy++)
                for (int dx = -3; dx <= 3; dx++)
                {
                    int xx = Math.Clamp(x + dx, 0, OW - 1), yy = Math.Clamp(y + dy, 0, OH - 1);
                    int j = yy * OW + xx;
                    if (dyn[j]) continue;
                    s += luma[j]; n++;
                }
            lmean[y * OW + x] = n > 0 ? (int)(s / n) : 0;
        }

    // ---- the coloured things keep their colour -----------------------------
    // The jet's panel had no coloured art - its screens were holes the game
    // drew into. The cabin's three screens, its lamps and legends ARE paint,
    // and grey bands would erase exactly what a gunner looks at. A saturated
    // pixel skips the bands and answers per card by hue.
    var satp = new bool[OW * OH];
    for (int i = 0; i < OW * OH; i++)
    {
        if (dyn[i]) continue;
        int r = sm[i * 3], g = sm[i * 3 + 1], b = sm[i * 3 + 2];
        int mx = Math.Max(r, Math.Max(g, b)), mn = Math.Min(r, Math.Min(g, b));
        satp[i] = mx - mn >= 48 && mx >= 60;
    }

    // ---- bands from the panel's OWN luminance (percentiles, not absolutes) -
    var pool = new List<int>();
    for (int i = 0; i < OW * OH; i++) if (!dyn[i] && !satp[i]) pool.Add(luma[i]);
    pool.Sort();
    int P(int pct) => pool[Math.Min(pool.Count - 1, pool.Count * pct / 100)];
    int tWhite = P(93), tSolid = P(62), tCheck = P(30);
    Console.WriteLine($"bands: checker >= {tCheck}, plate >= {tSolid}, stroke >= {tWhite}");

    var band = new byte[OW * OH];       // 0 seam, 1 texture, 2 plate, 3 stroke, 4 lamp
    for (int i = 0; i < OW * OH; i++)
    {
        if (dyn[i] || satp[i]) continue;
        int ridge = luma[i] - lmean[i];
        if (ridge > 12 || luma[i] >= tWhite) band[i] = 3;
        else if (ridge < -9) band[i] = 0;   // a seam CUTS through - the drawing
        else if (luma[i] >= tSolid) band[i] = 2;
        else if (luma[i] >= tCheck) band[i] = 1;
        else band[i] = 0;
    }
    // the black rim against the glass: a strut on a sky needs an edge
    for (int y = 0; y < OH; y++)
        for (int x = 0; x < OW; x++)
        {
            int i = y * OW + x;
            if (dyn[i] || satp[i] || band[i] == 0) continue;
            for (int dy = -1; dy <= 1 && band[i] != 0; dy++)
                for (int dx = -1; dx <= 1; dx++)
                {
                    int xx = Math.Clamp(x + dx, 0, OW - 1), yy = Math.Clamp(y + dy, 0, OH - 1);
                    if (dyn[yy * OW + xx]) { band[i] = 0; break; }
                }
        }
    // a stroke is a line or it is dirt: two stroke neighbours or demotion
    for (int pass = 0; pass < 2; pass++)
    {
        var keep = (byte[])band.Clone();
        for (int y = 0; y < OH; y++)
            for (int x = 0; x < OW; x++)
            {
                int i = y * OW + x;
                if (dyn[i] || satp[i] || band[i] != 3) continue;
                int n = 0;
                for (int dy = -1; dy <= 1; dy++)
                    for (int dx = -1; dx <= 1; dx++)
                    {
                        if (dx == 0 && dy == 0) continue;
                        int xx = Math.Clamp(x + dx, 0, OW - 1), yy = Math.Clamp(y + dy, 0, OH - 1);
                        int j = yy * OW + xx;
                        if (!dyn[j] && !satp[j] && band[j] == 3) n++;
                    }
                if (n < 2) keep[i] = (byte)(luma[i] >= tSolid ? 2 : 0);
            }
        band = keep;
    }

    // ---- the three marker maps ---------------------------------------------
    var cgaM = new byte[OW * OH];
    var egaM = new byte[OW * OH];
    var hgcM = new byte[OW * OH];
    for (int i = 0; i < OW * OH; i++)
    {
        if (dyn[i]) continue;
        int r = sm[i * 3], g = sm[i * 3 + 1], b = sm[i * 3 + 2];
        if (satp[i])
        {
            bool warm = r >= Math.Max(g, b);        // red and amber; green, cyan
                                                    //  and blue are the cool side
            cgaM[i] = (byte)(warm ? 202 : 201);     // magenta the warm, cyan the cool
            egaM[i] = (byte)(200 + Near16(r, g, b)); // EGA keeps the real hue
            hgcM[i] = 201;                          // a screen on a mono card is
                                                    //  DARK glass, a quarter weave:
                                                    //  the instruments the game
                                                    //  draws over it at full
                                                    //  density are what must read
        }
        else
        {
            cgaM[i] = band[i] switch
            { 1 => (byte)204, 2 => (byte)201, 3 => (byte)203, 4 => (byte)202, _ => (byte)200 };
            egaM[i] = band[i] switch
            { 1 => (byte)(200 + gDark), 2 => (byte)(200 + gLite), 3 => (byte)(200 + gWhit),
              4 => (byte)(200 + gRed), _ => (byte)200 };
            hgcM[i] = band[i] switch
            { 1 => (byte)201, 2 => (byte)202, 3 => (byte)203, 4 => (byte)203, _ => (byte)200 };
        }
    }
    // EGA: a plate EDGE is a drawn line - where texture meets plate, the dark
    // side goes black, and the plates get their outlines back
    for (int y = 0; y < OH; y++)
        for (int x = 0; x < OW; x++)
        {
            int i = y * OW + x;
            if (dyn[i] || satp[i] || band[i] != 1) continue;
            if ((x > 0 && band[i - 1] == 2) || (x < OW - 1 && band[i + 1] == 2) ||
                (y > 0 && band[i - OW] == 2) || (y < OH - 1 && band[i + OW] == 2))
                egaM[i] = 200;
        }

    return (idx, cgaM, egaM, hgcM, solid);
}

// ---- the check bitmaps: what the game will actually show -------------------
// The palette is picked BY EYE, so the eye gets a file. Magenta stays the
// windscreen; the rest renders the markers the way VIDLUT's tables will -
// CGA in mode-4 palette-1 inks with the positional checker, EGA in the
// curated sixteen, Hercules densities as four greys (a density IS a grey,
// at arm's length).
int[][] cgaInk = { new[]{0,0,0}, new[]{85,255,255}, new[]{255,85,255}, new[]{255,255,255} };
int[] hgcGrey = { 0, 85, 170, 255 };
void Previews(string artPath, byte[] idx, byte[] cgaM, byte[] egaM, byte[] hgcM)
{
    var chk = new byte[OW * OH * 3];
    for (int i = 0; i < OW * OH; i++)
    {
        if (idx[i] == 0) { chk[i * 3] = 255; chk[i * 3 + 1] = 0; chk[i * 3 + 2] = 255; }
        else
        {
            var c = pal[idx[i] - 31];
            chk[i * 3] = (byte)c.r; chk[i * 3 + 1] = (byte)c.g; chk[i * 3 + 2] = (byte)c.b;
        }
    }
    Bmp.Save(artPath, chk, OW, OH);
    Console.WriteLine($"check bitmap: {artPath} (magenta = windscreen)");

    void Preview(string suffix, byte[] map, Func<int, int, int[]> render)
    {
        var pv = new byte[OW * OH * 3];
        for (int y = 0; y < OH; y++)
            for (int x = 0; x < OW; x++)
            {
                int i = y * OW + x;
                int[] c;
                if (map[i] == 0) c = new[] { 255, 0, 255 };
                else c = render(map[i], (x & 1) ^ (y & 1));
                pv[i * 3] = (byte)c[0]; pv[i * 3 + 1] = (byte)c[1]; pv[i * 3 + 2] = (byte)c[2];
            }
        var p = Path.Combine(Path.GetDirectoryName(Path.GetFullPath(artPath))!,
                Path.GetFileNameWithoutExtension(artPath) + suffix + ".bmp");
        Bmp.Save(p, pv, OW, OH);
        Console.WriteLine($"check bitmap: {p}");
    }
    Preview("_cga", cgaM, (m, ph) => m == 204 ? cgaInk[ph] : cgaInk[Math.Clamp(m - 200, 0, 3)]);
    Preview("_ega", egaM, (m, ph) => ega16[Math.Clamp(m - 200, 0, 15)]);
    Preview("_hgc", hgcM, (m, ph) => { int g2 = hgcGrey[Math.Clamp(m - 200, 0, 3)]; return new[] { g2, g2, g2 }; });
}

// ============================================================================
//  THE CABIN - the span stream, four emissions off one skeleton.
// ============================================================================
var cab = Analyze(src);

// ---- spans, computed ONCE and shared by all four emissions ------------------
// The retro streams must carry the same span skeleton byte for byte:
// the game picks WHICH file to load by video card, and the draw loop is the
// same LODSW/LODSW/REP MOVSB whichever one is in memory.
var spanList = new List<(int dest, int len)>();
for (int y = 0; y < OH; y++)
{
    int x = 0;
    while (x < OW)
    {
        if (cab.idx[y * OW + x] == 0) { x++; continue; }
        int s = x;
        while (x < OW && cab.idx[y * OW + x] != 0) x++;
        spanList.Add((y * OW + s, x - s));
    }
}

// The cabin blob's ceiling is no longer the phosphor shelf: the LEFT side
// console now lives on the cabin page at SHSLOFF, and a cabin that grew
// past it would load itself over that stream. DATA.INC owns the number.
const int CABCAP = 0xA800;
int WriteStream(string path, byte[] map)
{
    var ms = new MemoryStream();
    var bw = new BinaryWriter(ms);
    bw.Write((ushort)spanList.Count);
    foreach (var (dest, len) in spanList)
    {
        bw.Write((ushort)dest);
        bw.Write((ushort)len);
        for (int i = dest; i < dest + len; i++) bw.Write(map[i]);
    }
    if (ms.Length > CABCAP)
    { Console.Error.WriteLine($"error: {ms.Length} bytes - the cabin must stay below the right console's shelf ({CABCAP})"); return 1; }
    File.WriteAllBytes(path, ms.ToArray());
    Console.WriteLine($"{Path.GetFileName(path)}: {spanList.Count} spans, {ms.Length} bytes");
    return 0;
}
if (WriteStream(outPath, cab.idx) != 0) return 1;
Console.WriteLine($"  ({cab.solid} solid pixels)");

var dir = Path.GetDirectoryName(Path.GetFullPath(outPath))!;
if (WriteStream(Path.Combine(dir, "SHCCGA.DAT"), cab.cgaM) != 0) return 1;
if (WriteStream(Path.Combine(dir, "SHCEGA.DAT"), cab.egaM) != 0) return 1;
if (WriteStream(Path.Combine(dir, "SHCHGC.DAT"), cab.hgcM) != 0) return 1;

if (bmpPath != null) Previews(bmpPath, cab.idx, cab.cgaM, cab.egaM, cab.hgcM);

// ============================================================================
//  THE SIDE CONSOLES - RLE streams, SIDEBMPF's own grammar (Panel2Inc's
//  encoder, adapted: here 0 is the transparent index, not 255).
//      00        end of image
//      40 | n    LITERAL n - n palette bytes follow
//      80 | n    RUN n     - one palette byte follows, repeated n times
//      C0 | n    SKIP n    - n transparent pixels, the world shows through
//  n = 0 means a word count follows the token.
// ============================================================================
if (leftPath != null)
{
    byte[] RLE(byte[] px)
    {
        var o = new List<byte>();
        void Tok(int type, int n)
        {
            if (n < 64) o.Add((byte)(type | n));
            else { o.Add((byte)type); o.Add((byte)(n & 255)); o.Add((byte)(n >> 8)); }
        }
        int i = 0;
        var lit = new List<byte>();
        void FlushLit()
        {
            while (lit.Count > 0)
            {
                int n = Math.Min(lit.Count, 65535);
                Tok(0x40, n);
                o.AddRange(lit.GetRange(0, n));
                lit.RemoveRange(0, n);
            }
        }
        while (i < px.Length)
        {
            int run = 1;
            while (i + run < px.Length && px[i + run] == px[i] && run < 65535) run++;
            if (px[i] == 0)                          // transparent: never stored
            { FlushLit(); Tok(0xC0, run); i += run; continue; }
            if (run >= 3)                            // a run pays for itself here
            { FlushLit(); Tok(0x80, run); o.Add(px[i]); i += run; continue; }
            for (int k = 0; k < run; k++) lit.Add(px[i]);
            i += run;
        }
        FlushLit();
        o.Add(0);
        return o.ToArray();
    }

    var L = Analyze(leftPath);
    var R = Analyze(rightPath);

    // The shelves, in bytes - see SHSLOFF/SHSROFF in DATA.INC. Measured
    // 2026-08-30: left 16847, right 21728 in VGA paint, so the FAT one
    // (right) rides scrseg from A000h (past the retro card bake at
    // 2000h+32000 = 9D00h) and the left rides the cabin page from A800h
    // (the cabin blob ends at A466h) up to the phosphor shelf at F000h.
    const int LCAP = 0xF000 - 0xA800;
    const int RCAP = 0x6000;
    var sdir = Path.GetDirectoryName(Path.GetFullPath(sideOut))!;
    int err = 0;
    void SideFile(string path, byte[] lm, byte[] rm)
    {
        var lp = RLE(lm);
        var rp = RLE(rm);
        Console.WriteLine($"{Path.GetFileName(path)}: left {lp.Length} + right {rp.Length} bytes");
        if (lp.Length > LCAP)
        { Console.Error.WriteLine($"error: {Path.GetFileName(path)} left stream {lp.Length} > {LCAP} - it will not fit its shelf"); err = 1; return; }
        if (rp.Length > RCAP)
        { Console.Error.WriteLine($"error: {Path.GetFileName(path)} right stream {rp.Length} > {RCAP} - it will not fit its shelf"); err = 1; return; }
        var ms = new MemoryStream();
        var bw = new BinaryWriter(ms);
        bw.Write((byte)'S'); bw.Write((byte)'S');
        bw.Write((ushort)lp.Length);
        bw.Write((ushort)rp.Length);
        bw.Write(lp);
        bw.Write(rp);
        File.WriteAllBytes(path, ms.ToArray());
    }
    SideFile(sideOut, L.idx, R.idx);
    SideFile(Path.Combine(sdir, "SHSCGA.DAT"), L.cgaM, R.cgaM);
    SideFile(Path.Combine(sdir, "SHSEGA.DAT"), L.egaM, R.egaM);
    SideFile(Path.Combine(sdir, "SHSHGC.DAT"), L.hgcM, R.hgcM);
    if (err != 0) return 1;

    if (bmpPath != null)
    {
        var bdir = Path.GetDirectoryName(Path.GetFullPath(bmpPath))!;
        Previews(Path.Combine(bdir, Path.GetFileNameWithoutExtension(leftPath) + "_art.bmp"),
                 L.idx, L.cgaM, L.egaM, L.hgcM);
        Previews(Path.Combine(bdir, Path.GetFileNameWithoutExtension(rightPath) + "_art.bmp"),
                 R.idx, R.cgaM, R.egaM, R.hgcM);
    }
}
return 0;

static class Png
{
    public class Image { public int W, H; public byte[] P; }
    public static Image Load(string path)
    {
        var f = File.ReadAllBytes(path);
        if (f.Length < 8 || f[0] != 0x89 || f[1] != 'P' || f[2] != 'N' || f[3] != 'G')
            throw new Exception($"{path}: not a PNG");
        int w = 0, h = 0, bit = 0, colour = 0, interlace = 0;
        var idat = new MemoryStream();
        int p = 8;
        while (p + 8 <= f.Length)
        {
            int len = (f[p] << 24) | (f[p + 1] << 16) | (f[p + 2] << 8) | f[p + 3];
            string type = Encoding.ASCII.GetString(f, p + 4, 4);
            int d = p + 8;
            if (type == "IHDR")
            {
                w = (f[d] << 24) | (f[d + 1] << 16) | (f[d + 2] << 8) | f[d + 3];
                h = (f[d + 4] << 24) | (f[d + 5] << 16) | (f[d + 6] << 8) | f[d + 7];
                bit = f[d + 8]; colour = f[d + 9]; interlace = f[d + 12];
            }
            else if (type == "IDAT") idat.Write(f, d, len);
            else if (type == "IEND") break;
            p = d + len + 4;
        }
        if (bit != 8 || (colour != 2 && colour != 6) || interlace != 0)
            throw new Exception($"{path}: need 8-bit RGB or RGBA, not interlaced");
        int ch = colour == 2 ? 3 : 4;
        idat.Position = 0;
        var raw = new MemoryStream();
        using (var z = new ZLibStream(idat, CompressionMode.Decompress)) z.CopyTo(raw);
        var s = raw.GetBuffer();
        var outp = new byte[w * h * 3];
        var prev = new byte[w * ch];
        var line = new byte[w * ch];
        int q = 0;
        for (int y = 0; y < h; y++)
        {
            int filt = s[q++];
            Buffer.BlockCopy(s, q, line, 0, w * ch); q += w * ch;
            for (int i = 0; i < w * ch; i++)
            {
                int a = i >= ch ? line[i - ch] : 0, b = prev[i], c = i >= ch ? prev[i - ch] : 0;
                int v = line[i];
                line[i] = filt switch
                {
                    0 => (byte)v,
                    1 => (byte)(v + a),
                    2 => (byte)(v + b),
                    3 => (byte)(v + ((a + b) >> 1)),
                    4 => (byte)(v + Paeth(a, b, c)),
                    _ => throw new Exception($"{path}: bad row filter {filt}")
                };
            }
            for (int x = 0; x < w; x++)
            {
                int o = (y * w + x) * 3, i = x * ch;
                outp[o] = line[i]; outp[o + 1] = line[i + 1]; outp[o + 2] = line[i + 2];
            }
            Buffer.BlockCopy(line, 0, prev, 0, w * ch);
        }
        return new Image { W = w, H = h, P = outp };
    }
    static int Paeth(int a, int b, int c)
    {
        int q = a + b - c, pa = Math.Abs(q - a), pb = Math.Abs(q - b), pc = Math.Abs(q - c);
        return (pa <= pb && pa <= pc) ? a : (pb <= pc ? b : c);
    }
}

static class Bmp
{
    public static void Save(string path, byte[] rgb, int w, int h)
    {
        int stride = (w * 3 + 3) & ~3, size = 54 + stride * h;
        var f = new byte[size];
        f[0] = (byte)'B'; f[1] = (byte)'M';
        void I32(int at, int v) { f[at] = (byte)v; f[at + 1] = (byte)(v >> 8); f[at + 2] = (byte)(v >> 16); f[at + 3] = (byte)(v >> 24); }
        I32(2, size); I32(10, 54); I32(14, 40); I32(18, w); I32(22, h);
        f[26] = 1; f[28] = 24; I32(34, stride * h);
        I32(38, 2835); I32(42, 2835);
        for (int y = 0; y < h; y++)
        {
            int row = 54 + (h - 1 - y) * stride;
            for (int x = 0; x < w; x++)
            {
                int o = (y * w + x) * 3;
                f[row + x * 3] = rgb[o + 2]; f[row + x * 3 + 1] = rgb[o + 1]; f[row + x * 3 + 2] = rgb[o];
            }
        }
        File.WriteAllBytes(path, f);
    }
}
