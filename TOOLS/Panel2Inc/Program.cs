// ============================================================================
//  Panel2Inc - cockpit artwork -> WIRE CITY engine resources, as TASM
//  includes plus the two 320x200 BMPs the old pipeline kept by hand.
//  The C# replacement for res\mkpanel.py (the tooling contract: no Python).
//
//      dotnet run --project TOOLS\Panel2Inc -- cockpit.png -o SRC -bmp res
//
//  ONE source image, at ANY size, does the whole job. mkpanel.py needed two
//  hand-made 320x200 bitmaps - panel1 the art, panel2 the markup - because
//  it could not tell a drawn instrument from a marker rectangle. This finds
//  the markers in the FULL-RESOLUTION artwork, where they are hundreds of
//  pixels wide and perfectly flat, and only then shrinks the picture. The
//  markers are simply the largest flat, strongly-saturated rectangles in
//  the image: no exact RGB has to be typed into the artist's colour picker.
//
//  Outputs (into -o):
//    PANELIMG.INC - 64000 palette-index bytes, resource id 2 in CITY.DAT,
//                   255 = transparent, panel colours at palette 31..93
//    PALPNL.INC   - 63 VGA DAC triplets appended to PALDAY/PALNITE
//    PANELZON.INC - the instrument rectangles as equs. mkpanel.py PRINTED
//                   these and a human retyped them into HUD.INC; with a
//                   live panel wanting dozens of zones that stops scaling.
//  Outputs (into -bmp): <name>_art.bmp and <name>_mark.bmp, the shrunk art
//  and the same with the found zones flagged - for eyeballing, not input.
//
//  No NuGet: the PNG reader is here (8-bit RGB/RGBA, non-interlaced - what
//  every art tool writes) and inflate comes from System.IO.Compression.
// ============================================================================
using System.IO.Compression;
using System.Text;

int OW = 320, OH = 200;          // the screen this cockpit has to fit
int NPAL = 63;                   // palette slots 31..93 in the game's DAC
int SPANCAP = 399;               // see the span check at the bottom

string src = null, outDir = null, bmpDir = null;
bool probe = false;
for (int i = 0; i < args.Length; i++)
{
    switch (args[i])
    {
        case "-o": outDir = args[++i]; break;
        case "-bmp": bmpDir = args[++i]; break;
        case "-probe": probe = true; break;
        default: src = args[i]; break;
    }
}
if (src == null || outDir == null)
{
    Console.Error.WriteLine("usage: Panel2Inc cockpit.png -o SRCDIR [-bmp RESDIR] [-probe]");
    return 1;
}

var img = Png.Load(src);
Console.WriteLine($"{Path.GetFileName(src)}: {img.W}x{img.H}");
if (img.W < OW || img.H < OH)
{ Console.Error.WriteLine($"error: source is smaller than {OW}x{OH}"); return 1; }

// The artwork must be the same shape as the screen or the instruments come
// out oval. 320x200 is 1.6:1 - the 1980s VGA aspect, not 16:10 by accident.
double aspect = (double)img.W / img.H, want = (double)OW / OH;
if (Math.Abs(aspect - want) > 0.02)
    Console.Error.WriteLine($"warning: source aspect {aspect:F3} is not {want:F3} - the panel will be stretched");

// ---------------------------------------------------------------------------
//  THE MARKERS, found at full resolution.
//  A marker is a big region of one strongly-saturated colour - no instrument
//  painted in metal greys can be mistaken for one. It is grown from a
//  saturated seed and every pixel is tested against THAT SEED, never against
//  its neighbour, so the blob cannot walk off along a gradient. The
//  tolerance is not decoration: this artwork carries 39000 distinct colours
//  because it has been through a lossy pass, and its "flat" red is really
//  (191,23,25) smeared over a few dozen neighbouring values. Exact matching
//  found nothing at all.
// ---------------------------------------------------------------------------
int SAT = 60;                    // max-min channel spread that reads as "keyed"
int TOL = 30;                    // how far a pixel may drift from its seed
int MINBLOB = (img.W * img.H) / 4000;   // ignore specks; scales with the art

if (probe)
{
    var hist = new Dictionary<int, int>();
    int satN = 0;
    for (int i = 0; i < img.W * img.H; i++)
    {
        int p = i * 3;
        int r = img.P[p], g = img.P[p + 1], b = img.P[p + 2];
        if (Math.Max(r, Math.Max(g, b)) - Math.Min(r, Math.Min(g, b)) >= SAT) satN++;
        int key = (r << 16) | (g << 8) | b;
        hist.TryGetValue(key, out int c); hist[key] = c + 1;
    }
    Console.WriteLine($"-- {hist.Count} distinct colours, {satN} pixels with saturation >= {SAT} --");
    foreach (var kv in hist.OrderByDescending(k => k.Value).Take(24))
    {
        int r = (kv.Key >> 16) & 255, g = (kv.Key >> 8) & 255, b = kv.Key & 255;
        int s = Math.Max(r, Math.Max(g, b)) - Math.Min(r, Math.Min(g, b));
        Console.WriteLine($"   {kv.Value,8} px  rgb({r,3},{g,3},{b,3})  sat {s,3}");
    }
}

var zones = FindFlatBlobs(img, SAT, TOL, MINBLOB);
if (probe || zones.Count == 0)
{
    Console.WriteLine("-- flat saturated blobs found, largest first --");
    foreach (var z in zones)
        Console.WriteLine($"   {z.N,8} px  rgb({z.R},{z.G},{z.B})  x {z.X0}..{z.X1}  y {z.Y0}..{z.Y1}");
    if (zones.Count == 0) { Console.Error.WriteLine("error: no marker rectangles in this image"); return 1; }
}

// Assign the three screens by dominant channel: red = radar, blue = ADI,
// green = map, the order the game has always used.
Blob radar = null, adi = null, map = null;
foreach (var z in zones)
{
    if (z.R > z.G && z.R > z.B) { radar ??= z; }
    else if (z.B > z.R && z.B > z.G) { adi ??= z; }
    else if (z.G > z.R && z.G > z.B) { map ??= z; }
}
// Anything left over that is neither of the three is a TEXT/lamp zone - the
// cyan of the old markup. They are reported, never painted over.
var text = new List<Blob>();
foreach (var z in zones)
    if (z != radar && z != adi && z != map) text.Add(z);

if (radar == null || adi == null || map == null)
{ Console.Error.WriteLine("error: need one red, one blue and one green screen marker"); return 1; }

// ---------------------------------------------------------------------------
//  SHRINK. Box average over the source block each output pixel covers, so
//  a 5x5 patch of rivets becomes one honest grey instead of whichever pixel
//  a nearest-neighbour sample happened to land on.
// ---------------------------------------------------------------------------
var art = new byte[OW * OH * 3];
for (int y = 0; y < OH; y++)
{
    int sy0 = (int)((long)y * img.H / OH), sy1 = (int)((long)(y + 1) * img.H / OH);
    if (sy1 <= sy0) sy1 = sy0 + 1;
    for (int x = 0; x < OW; x++)
    {
        int sx0 = (int)((long)x * img.W / OW), sx1 = (int)((long)(x + 1) * img.W / OW);
        if (sx1 <= sx0) sx1 = sx0 + 1;
        long r = 0, g = 0, b = 0, n = 0;
        for (int sy = sy0; sy < sy1; sy++)
            for (int sx = sx0; sx < sx1; sx++)
            { int p = (sy * img.W + sx) * 3; r += img.P[p]; g += img.P[p + 1]; b += img.P[p + 2]; n++; }
        int o = (y * OW + x) * 3;
        art[o] = (byte)(r / n); art[o + 1] = (byte)(g / n); art[o + 2] = (byte)(b / n);
    }
}

// ---------------------------------------------------------------------------
//  TRANSPARENCY, decided at full resolution and then voted on.
//  The game calls a pixel transparent if it is near-white; averaging first
//  would smear the canopy edge into a one-pixel halo of not-quite-white
//  that draws as dirty grey over the sky. So: test the SOURCE pixels, then
//  let the majority of each block decide. Hard edge, no fringe - the same
//  result the artist used to get by hand with anti-aliasing switched off.
// ---------------------------------------------------------------------------
var clear = new bool[OW * OH];
int clearN = 0;
for (int y = 0; y < OH; y++)
{
    int sy0 = (int)((long)y * img.H / OH), sy1 = (int)((long)(y + 1) * img.H / OH);
    if (sy1 <= sy0) sy1 = sy0 + 1;
    for (int x = 0; x < OW; x++)
    {
        int sx0 = (int)((long)x * img.W / OW), sx1 = (int)((long)(x + 1) * img.W / OW);
        if (sx1 <= sx0) sx1 = sx0 + 1;
        int white = 0, n = 0;
        for (int sy = sy0; sy < sy1; sy++)
            for (int sx = sx0; sx < sx1; sx++)
            {
                int p = (sy * img.W + sx) * 3; n++;
                if (img.P[p] >= 240 && img.P[p + 1] >= 240 && img.P[p + 2] >= 240) white++;
            }
        if (white * 2 > n) { clear[y * OW + x] = true; clearN++; }
    }
}
Console.WriteLine($"transparent pixels: {clearN}  (viewport {clearN * 100 / (OW * OH)}% of the screen)");

// ---------------------------------------------------------------------------
//  The screens are INSTRUCTIONS, not art: flatten them to dark glass so the
//  radar, the map and the target page draw on a clean background.
// ---------------------------------------------------------------------------
(int x0, int y0, int x1, int y1) Scale(Blob z) => (
    (int)((long)z.X0 * OW / img.W), (int)((long)z.Y0 * OH / img.H),
    (int)((long)z.X1 * OW / img.W), (int)((long)z.Y1 * OH / img.H));

byte GD = 10, GG = 14, GB = 20;   // SCREEN_DARK, as mkpanel.py had it
foreach (var z in new[] { radar, adi, map })
{
    var (x0, y0, x1, y1) = Scale(z);
    for (int y = Math.Max(0, y0 - 1); y <= Math.Min(OH - 1, y1 + 1); y++)
        for (int x = Math.Max(0, x0 - 1); x <= Math.Min(OW - 1, x1 + 1); x++)
        { int o = (y * OW + x) * 3; art[o] = GD; art[o + 1] = GG; art[o + 2] = GB; clear[y * OW + x] = false; }
}

var rz = Scale(radar); var az = Scale(adi); var mz = Scale(map);
Console.WriteLine($"RADAR  x {rz.x0}..{rz.x1}  y {rz.y0}..{rz.y1}   ({rz.x1 - rz.x0 + 1}x{rz.y1 - rz.y0 + 1})");
Console.WriteLine($"ADI    x {az.x0}..{az.x1}  y {az.y0}..{az.y1}   ({az.x1 - az.x0 + 1}x{az.y1 - az.y0 + 1})");
Console.WriteLine($"MAP    x {mz.x0}..{mz.x1}  y {mz.y0}..{mz.y1}   ({mz.x1 - mz.x0 + 1}x{mz.y1 - mz.y0 + 1})");
foreach (var z in text)
{
    var s = Scale(z);
    Console.WriteLine($"TEXT   x {s.x0}..{s.x1}  y {s.y0}..{s.y1}   ({s.x1 - s.x0 + 1}x{s.y1 - s.y0 + 1})  rgb({z.R},{z.G},{z.B})");
}

// ---------------------------------------------------------------------------
//  QUANTISE to the 63 slots the game lends us. Transparent pixels are left
//  out of the histogram - the viewport is never drawn, and letting a third
//  of the screen vote for "white" would spend palette entries on a colour
//  nobody sees. The chosen colours are snapped to the VGA DAC's 6 bits
//  BEFORE the pixels are matched, so the dither compensates for what the
//  card will really show instead of for a precision it does not have.
// ---------------------------------------------------------------------------
var pal = MedianCut(art, clear, OW, OH, NPAL);
for (int i = 0; i < pal.Length; i++)
    pal[i] = ((pal[i].r >> 2) << 2, (pal[i].g >> 2) << 2, (pal[i].b >> 2) << 2);

var data = new byte[OW * OH];
var err = new double[OW * OH * 3];
for (int y = 0; y < OH; y++)
    for (int x = 0; x < OW; x++)
    {
        int i = y * OW + x, o = i * 3;
        if (clear[i]) { data[i] = 255; continue; }
        double r = art[o] + err[o], g = art[o + 1] + err[o + 1], b = art[o + 2] + err[o + 2];
        int best = 0; double bd = double.MaxValue;
        for (int k = 0; k < pal.Length; k++)
        {
            double dr = r - pal[k].r, dg = g - pal[k].g, db = b - pal[k].b;
            double d = dr * dr + dg * dg + db * db;
            if (d < bd) { bd = d; best = k; }
        }
        data[i] = (byte)(31 + best);
        double er = r - pal[best].r, eg = g - pal[best].g, eb = b - pal[best].b;
        void Spill(int nx, int ny, double f)
        {
            if (nx < 0 || nx >= OW || ny < 0 || ny >= OH) return;
            int q = (ny * OW + nx) * 3;
            err[q] += er * f; err[q + 1] += eg * f; err[q + 2] += eb * f;
        }
        Spill(x + 1, y, 7.0 / 16); Spill(x - 1, y + 1, 3.0 / 16);
        Spill(x, y + 1, 5.0 / 16); Spill(x + 1, y + 1, 1.0 / 16);
    }

// ---------------------------------------------------------------------------
//  THE SPAN COUNT - the one number that can silently break the panel.
//  The loader in CITY.ASM walks the 64000 bytes once and records every run
//  of non-transparent pixels as a (offset,length) pair, stopping dead at
//  PSPAN+1596. That is 399 pairs. Past that the rest of the cockpit is not
//  blitted at all - no crash, no message, just a panel with its bottom
//  missing. (mkpanel.py checked against 449, which was never the real
//  limit.) Runs merge ACROSS rows, so a solid band of panel is one span
//  and the cost is entirely in the canopy, where the frame crosses the sky.
// ---------------------------------------------------------------------------
int spans = 0; bool prevClear = true;
foreach (var v in data)
{
    bool t = (v == 255);
    if (prevClear && !t) spans++;
    prevClear = t;
}
Console.WriteLine($"blit spans: {spans} (loader cap {SPANCAP})");

Directory.CreateDirectory(outDir);
var sb = new StringBuilder();
sb.Append("; PANELIMG.INC - generated by TOOLS\\Panel2Inc from ").Append(Path.GetFileName(src)).Append("\r\n");
sb.Append("; 320x200 palette indexes, 255 = transparent. DO NOT EDIT BY HAND.\r\n");
for (int i = 0; i < data.Length; i += 20)
{
    sb.Append("        db ");
    for (int k = 0; k < 20 && i + k < data.Length; k++)
    { if (k > 0) sb.Append(','); sb.Append(data[i + k]); }
    sb.Append("\r\n");
}
File.WriteAllText(Path.Combine(outDir, "PANELIMG.INC"), sb.ToString());
Console.WriteLine("wrote PANELIMG.INC");

sb.Clear();
sb.Append("; PALPNL.INC - generated by TOOLS\\Panel2Inc, 63 panel colours\r\n");
sb.Append("; (VGA DAC 0..63), palette indexes 31..93. DO NOT EDIT BY HAND.\r\n");
for (int i = 0; i < NPAL; i++)
    sb.Append($"        db {pal[i].r >> 2},{pal[i].g >> 2},{pal[i].b >> 2}          ;{31 + i}\r\n");
File.WriteAllText(Path.Combine(outDir, "PALPNL.INC"), sb.ToString());
Console.WriteLine("wrote PALPNL.INC");

sb.Clear();
sb.Append("; PANELZON.INC - generated by TOOLS\\Panel2Inc from ").Append(Path.GetFileName(src)).Append("\r\n");
sb.Append("; Where the instruments live on the cockpit bitmap. mkpanel.py printed\r\n");
sb.Append("; these for a human to retype into HUD.INC; they are equs now, so moving\r\n");
sb.Append("; a screen in the artwork moves it in the game. DO NOT EDIT BY HAND.\r\n");
void Zone(string n, (int x0, int y0, int x1, int y1) z)
{
    sb.Append($"{n}X0 equ {z.x0}\r\n{n}Y0 equ {z.y0}\r\n{n}X1 equ {z.x1}\r\n{n}Y1 equ {z.y1}\r\n");
    sb.Append($"{n}CX equ {(z.x0 + z.x1) / 2}\r\n{n}CY equ {(z.y0 + z.y1) / 2}\r\n");
    sb.Append($"{n}W  equ {z.x1 - z.x0 + 1}\r\n{n}H  equ {z.y1 - z.y0 + 1}\r\n");
}
Zone("PZRDR", rz); Zone("PZADI", az); Zone("PZMAP", mz);
sb.Append($"PZTEXTN equ {text.Count}\r\n");
for (int i = 0; i < text.Count; i++) Zone($"PZT{i}", Scale(text[i]));
File.WriteAllText(Path.Combine(outDir, "PANELZON.INC"), sb.ToString());
Console.WriteLine("wrote PANELZON.INC");

if (bmpDir != null)
{
    Directory.CreateDirectory(bmpDir);
    string stem = Path.GetFileNameWithoutExtension(src);
    // the art as the game will show it, transparent shown as pure white
    var shown = new byte[OW * OH * 3];
    for (int i = 0; i < OW * OH; i++)
    {
        if (clear[i]) { shown[i * 3] = 255; shown[i * 3 + 1] = 255; shown[i * 3 + 2] = 255; }
        else { var c = pal[data[i] - 31]; shown[i * 3] = (byte)c.r; shown[i * 3 + 1] = (byte)c.g; shown[i * 3 + 2] = (byte)c.b; }
    }
    Bmp.Save(Path.Combine(bmpDir, stem + "_art.bmp"), shown, OW, OH);
    // the same with the found zones flagged back in, to check the fit by eye
    var mark = (byte[])shown.Clone();
    void Paint((int x0, int y0, int x1, int y1) z, byte r, byte g, byte b)
    {
        for (int y = z.y0; y <= z.y1; y++)
            for (int x = z.x0; x <= z.x1; x++)
            { int o = (y * OW + x) * 3; mark[o] = r; mark[o + 1] = g; mark[o + 2] = b; }
    }
    Paint(rz, 237, 28, 36); Paint(az, 0, 162, 232); Paint(mz, 34, 177, 76);
    foreach (var t in text) Paint(Scale(t), 153, 217, 234);
    Bmp.Save(Path.Combine(bmpDir, stem + "_mark.bmp"), mark, OW, OH);
    Console.WriteLine($"wrote {stem}_art.bmp and {stem}_mark.bmp");
}

if (spans > SPANCAP)
{
    Console.Error.WriteLine($"error: {spans} spans over the loader's {SPANCAP} - the bottom of the");
    Console.Error.WriteLine("       panel would silently not draw. Simplify the transparent area,");
    Console.Error.WriteLine("       or move PSPAN off BSS and raise the cap.");
    return 1;
}
return 0;


// ---------------------------------------------------------------------------
//  Flat-blob finder: 4-connected regions grown from a saturated seed, every
//  pixel within tol of THE SEED - bounded, so it cannot creep down a ramp.
//  The average colour is reported, not the seed's, so a noisy fill still
//  names itself honestly.
// ---------------------------------------------------------------------------
static List<Blob> FindFlatBlobs(Image im, int sat, int tol, int minpx)
{
    var seen = new bool[im.W * im.H];
    var outp = new List<Blob>();
    var stack = new Stack<int>();
    for (int i0 = 0; i0 < im.W * im.H; i0++)
    {
        if (seen[i0]) continue;
        int p0 = i0 * 3;
        byte r = im.P[p0], g = im.P[p0 + 1], b = im.P[p0 + 2];
        int mx = Math.Max(r, Math.Max(g, b)), mn = Math.Min(r, Math.Min(g, b));
        if (mx - mn < sat) { seen[i0] = true; continue; }
        int n = 0, x0 = int.MaxValue, y0 = int.MaxValue, x1 = -1, y1 = -1;
        long sr = 0, sg = 0, sb = 0;
        stack.Push(i0); seen[i0] = true;
        while (stack.Count > 0)
        {
            int i = stack.Pop(), x = i % im.W, y = i / im.W;
            n++;
            int pp = i * 3; sr += im.P[pp]; sg += im.P[pp + 1]; sb += im.P[pp + 2];
            if (x < x0) x0 = x; if (x > x1) x1 = x;
            if (y < y0) y0 = y; if (y > y1) y1 = y;
            void Try(int nx, int ny)
            {
                if (nx < 0 || nx >= im.W || ny < 0 || ny >= im.H) return;
                int j = ny * im.W + nx;
                if (seen[j]) return;
                int q = j * 3;
                if (Math.Abs(im.P[q] - r) > tol || Math.Abs(im.P[q + 1] - g) > tol
                    || Math.Abs(im.P[q + 2] - b) > tol) return;
                seen[j] = true; stack.Push(j);
            }
            Try(x + 1, y); Try(x - 1, y); Try(x, y + 1); Try(x, y - 1);
        }
        if (n >= minpx) outp.Add(new Blob
        {
            N = n, R = (int)(sr / n), G = (int)(sg / n), B = (int)(sb / n),
            X0 = x0, Y0 = y0, X1 = x1, Y1 = y1
        });
    }
    outp.Sort((a, c) => c.N.CompareTo(a.N));
    return outp;
}

// ---------------------------------------------------------------------------
//  Median cut: split the colour box with the widest channel at its median
//  until there are NPAL boxes, then average each. Old, cheap, and it keeps
//  the dark greys this artwork is almost entirely made of.
// ---------------------------------------------------------------------------
static (int r, int g, int b)[] MedianCut(byte[] rgb, bool[] skip, int w, int h, int want)
{
    var px = new List<(byte r, byte g, byte b)>();
    for (int i = 0; i < w * h; i++)
        if (!skip[i]) px.Add((rgb[i * 3], rgb[i * 3 + 1], rgb[i * 3 + 2]));
    if (px.Count == 0) px.Add((0, 0, 0));
    var boxes = new List<List<(byte r, byte g, byte b)>> { px };
    while (boxes.Count < want)
    {
        int pick = -1, widest = -1, chan = 0;
        for (int i = 0; i < boxes.Count; i++)
        {
            var bx = boxes[i];
            if (bx.Count < 2) continue;
            int rlo = 255, rhi = 0, glo = 255, ghi = 0, blo = 255, bhi = 0;
            foreach (var c in bx)
            {
                if (c.r < rlo) rlo = c.r; if (c.r > rhi) rhi = c.r;
                if (c.g < glo) glo = c.g; if (c.g > ghi) ghi = c.g;
                if (c.b < blo) blo = c.b; if (c.b > bhi) bhi = c.b;
            }
            int dr = rhi - rlo, dg = ghi - glo, db = bhi - blo;
            int m = Math.Max(dr, Math.Max(dg, db));
            if (m > widest) { widest = m; pick = i; chan = (m == dr) ? 0 : (m == dg ? 1 : 2); }
        }
        if (pick < 0 || widest <= 0) break;
        var box = boxes[pick];
        box.Sort((a, c) => (chan == 0 ? a.r.CompareTo(c.r) : chan == 1 ? a.g.CompareTo(c.g) : a.b.CompareTo(c.b)));
        int mid = box.Count / 2;
        boxes[pick] = box.GetRange(0, mid);
        boxes.Add(box.GetRange(mid, box.Count - mid));
    }
    var pal = new (int r, int g, int b)[want];
    for (int i = 0; i < want; i++)
    {
        if (i >= boxes.Count || boxes[i].Count == 0) { pal[i] = (0, 0, 0); continue; }
        long r = 0, g = 0, b = 0;
        foreach (var c in boxes[i]) { r += c.r; g += c.g; b += c.b; }
        pal[i] = ((int)(r / boxes[i].Count), (int)(g / boxes[i].Count), (int)(b / boxes[i].Count));
    }
    return pal;
}


class Blob { public int N, R, G, B, X0, Y0, X1, Y1; }
class Image { public int W, H; public byte[] P; }

// ---------------------------------------------------------------------------
//  A PNG reader for the one variant art tools actually write: 8 bits per
//  channel, RGB or RGBA, not interlaced. Inflate is in the framework, the
//  rest is five filter cases. No NuGet, in keeping with Obj2Inc.
// ---------------------------------------------------------------------------
static class Png
{
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
            throw new Exception($"{path}: need 8-bit RGB or RGBA, not interlaced (got bit {bit}, colour {colour}, interlace {interlace}). Re-export it that way.");
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

// 24-bit bottom-up BMP - the format the old hand-made panel files used, so
// the artist can still open the result in Paint and see what the game got.
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
