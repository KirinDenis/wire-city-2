// ============================================================================
//  Cab2Dat - a vehicle cabin PNG -> a WIRE CITY span-stream blob.
//
//      dotnet run --project TOOLS\Cab2Dat -- shilka.png -pal SRC\PALPNL.INC
//                 -o INSTALL\SHCAB.DAT [-bmp res\shilka_art.bmp]
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
//  C#, per the project's tooling contract. Output is committed.
// ============================================================================
using System.IO.Compression;
using System.Text;

int OW = 320, OH = 200;

string src = null, palPath = null, outPath = null, bmpPath = null;
for (int i = 0; i < args.Length; i++)
{
    switch (args[i])
    {
        case "-pal": palPath = args[++i]; break;
        case "-o": outPath = args[++i]; break;
        case "-bmp": bmpPath = args[++i]; break;
        default: src = args[i]; break;
    }
}
if (src == null || palPath == null || outPath == null)
{
    Console.Error.WriteLine("usage: Cab2Dat cabin.png -pal PALPNL.INC -o CAB.DAT [-bmp check.bmp]");
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

var img = Png.Load(src);
Console.WriteLine($"{Path.GetFileName(src)}: {img.W}x{img.H}");

// ---- shrink to 320x200 by box average --------------------------------------
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

// ---- quantise: white is the windscreen, everything else finds its slot ----
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

// ---- spans, interleaved with their pixels ----------------------------------
var body = new MemoryStream();
var w16 = new BinaryWriter(body);
int spans = 0;
for (int y = 0; y < OH; y++)
{
    int x = 0;
    while (x < OW)
    {
        if (idx[y * OW + x] == 0) { x++; continue; }
        int s = x;
        while (x < OW && idx[y * OW + x] != 0) x++;
        w16.Write((ushort)(y * OW + s));
        w16.Write((ushort)(x - s));
        for (int i = s; i < x; i++) w16.Write(idx[y * OW + i]);
        spans++;
    }
}
var outMs = new MemoryStream();
var w = new BinaryWriter(outMs);
w.Write((ushort)spans);
body.Position = 0; body.CopyTo(outMs);
File.WriteAllBytes(outPath, outMs.ToArray());
if (outMs.Length > 65535)
{ Console.Error.WriteLine($"error: {outMs.Length} bytes - the blob must fit one segment"); return 1; }
Console.WriteLine($"{Path.GetFileName(outPath)}: {spans} spans, {solid} pixels, {outMs.Length} bytes");

// ---- the check bitmap: what the game will actually show --------------------
if (bmpPath != null)
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
    Bmp.Save(bmpPath, chk, OW, OH);
    Console.WriteLine($"check bitmap: {bmpPath} (magenta = windscreen)");
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
