// ============================================================================
//  Img2Owv - make a 320x200 OWV (the OWL FLY 4 video format, read by the
//  kit's KIT\LIB\K_OWV.INC) without ffmpeg and without footage.
//
//      dotnet run --project TOOLS\Img2Owv -c Release -- /test KIT\TEST
//          writes the kit's test set: VTEST.OWV (a clip that uses every
//          chunk and every block opcode), VTEST.SUM (the 16-bit sum of every
//          decoded frame, for the DOS test to compare against) and
//          VBAD1..VBAD6.OWV (broken files the decoder must refuse with CF).
//
//      dotnet run --project TOOLS\Img2Owv -c Release -- OUT.OWV [/fps 12] [/key 48] A.BMP B.BMP ...
//          packs 8-bit (256-colour, uncompressed) 320x200 BMP files into a
//          clip, one BMP a frame; the palette is the first BMP's. One BMP is
//          a still: a compressed background for OWV_STILL.
//
//  The encoder is Vid2Owv's (TOOLS\Vid2Owv\Program.cs EncodeDelta, Rle) with
//  its tolerance at 0: exact, so the frame the player holds is the frame
//  that went in, and a checksum can prove it. Every file written is decoded
//  again here by an independent C# decoder before the tool says OK.
//  The format: KIT\ART\OWV.TXT (and LAB\OWLFLY4\VIDEO\FORMAT.md).
// ============================================================================

using System.Text;

static class Program
{
    const int W = 320, H = 200, PLANE = W * H, BLOCK = 8;
    const byte CH_KEY = 1, CH_DELTA = 2, CH_AUDIO = 3, CH_PAL = 4, CH_END = 0xFF;
    const byte OP_FILL = 0x80, OP_LIT = 0x81, OP_COPY = 0x82, OP_RLE = 0x83, OP_END = 0xFF;
    const int MAXPAY = 65000;           // a payload the 8086 player can hold in one segment

    static int Main(string[] args)
    {
        try
        {
            if (args.Length == 2 && args[0].Equals("/test", StringComparison.OrdinalIgnoreCase))
                return TestSet(args[1]);
            if (args.Length >= 2) return FromBmps(args);
        }
        catch (Exception ex) { Console.Error.WriteLine("FAILED: " + ex.Message); return 1; }
        Console.Error.WriteLine("Img2Owv /test DIR                      the kit's test clip and broken files");
        Console.Error.WriteLine("Img2Owv OUT.OWV [/fps N] [/key N] A.BMP ...   8-bit 320x200 BMPs, one a frame");
        return 2;
    }

    // ========================================================================
    //  The writer: chunks in order, the player's frame kept beside them.
    // ========================================================================
    class Owv
    {
        public byte[] Pal = new byte[768];          // 6-bit
        public int Fps = 12, Flags = 0, Rate = 0;
        public List<byte[]> Chunks = new();
        public List<ushort> Sums = new();
        public byte[] Recon = new byte[PLANE];      // what the player holds now
        public int[] Ops = new int[6];              // skip fill lit copy rle shifted
        public int Frames;

        public void Key(byte[] cur)
        {
            Chunks.Add(Chunk(CH_KEY, Rle(cur, 0, PLANE)));
            Array.Copy(cur, Recon, PLANE);
            Done();
        }

        // gdx, gdy: the global shift; null = search for it.
        public void Delta(byte[] cur, int? gdx = null, int? gdy = null)
        {
            int dx, dy;
            if (gdx.HasValue) { dx = gdx.Value; dy = gdy.Value; }
            else (dx, dy) = FindGlobal(cur, Recon, 8);
            var pred = new byte[PLANE];
            Shift(Recon, pred, dx, dy);
            var body = new MemoryStream();
            body.WriteByte((byte)(sbyte)dx);
            body.WriteByte((byte)(sbyte)dy);
            if (dx != 0 || dy != 0) Ops[5]++;
            int bw = W / BLOCK, bh = H / BLOCK, last = -1;
            var needs = new bool[bw * bh];
            for (int by = 0; by < bh; by++)
                for (int bx = 0; bx < bw; bx++)
                {
                    bool same = InRange(bx, by, dx, dy) && BlockEq(cur, pred, bx, by);
                    needs[by * bw + bx] = !same;
                    if (!same) last = by * bw + bx;
                }
            int skip = 0;
            var blk = new byte[64];
            for (int i = 0; i <= last; i++)
            {
                int bx = i % bw, by = i / bw;
                if (!needs[i]) { if (++skip == 128) Skip(body, ref skip); continue; }
                Skip(body, ref skip);
                Gather(cur, blk, bx, by);
                if (blk.All(b => b == blk[0]))
                {
                    body.WriteByte(OP_FILL); body.WriteByte(blk[0]);
                    Scatter(pred, blk, bx, by); Ops[1]++; continue;
                }
                var (cdx, cdy, found) = FindCopy(Recon, blk, bx, by, 4);
                if (found)
                {
                    body.WriteByte(OP_COPY); body.WriteByte((byte)(sbyte)cdx); body.WriteByte((byte)(sbyte)cdy);
                    Scatter(pred, blk, bx, by); Ops[3]++; continue;
                }
                Scatter(pred, blk, bx, by);
                var r = Rle(blk, 0, 64);
                if (r.Length < 64)
                {
                    body.WriteByte(OP_RLE); body.WriteByte((byte)r.Length); body.WriteByte((byte)(r.Length >> 8));
                    body.Write(r, 0, r.Length); Ops[4]++;
                }
                else { body.WriteByte(OP_LIT); body.Write(blk, 0, 64); Ops[2]++; }
            }
            body.WriteByte(OP_END);
            var pay = body.ToArray();
            if (pay.Length > MAXPAY) { Key(cur); return; }   // a keyframe is never over 64500
            for (int k = 0; k < PLANE; k++)
                if (pred[k] != cur[k]) throw new Exception("encoder: the delta does not rebuild the frame");
            Chunks.Add(Chunk(CH_DELTA, pay));
            Array.Copy(cur, Recon, PLANE);
            Done();
        }

        void Skip(MemoryStream body, ref int run)
        {
            while (run > 0) { int n = Math.Min(run, 128); body.WriteByte((byte)(n - 1)); Ops[0]++; run -= n; }
        }

        void Done()
        {
            int s = 0;
            foreach (var b in Recon) s += b;
            Sums.Add((ushort)s);
            Frames++;
        }

        public void Palette(int first, byte[] entries6)
        {
            var p = new byte[2 + entries6.Length];
            p[0] = (byte)first; p[1] = (byte)(entries6.Length / 3 - 1);
            entries6.CopyTo(p, 2);
            Chunks.Add(Chunk(CH_PAL, p));
        }

        public byte[] Header()
        {
            var h = new byte[800];
            Encoding.ASCII.GetBytes("OWV1").CopyTo(h, 0);
            U16(h, 4, W); U16(h, 6, H);
            h[8] = (byte)Fps; h[9] = (byte)Flags;
            U16(h, 10, Frames); U16(h, 12, Rate);
            int max = Chunks.Count == 0 ? 0 : Chunks.Max(c => c.Length);
            U32(h, 16, (uint)max);                   // max chunk where Vid2Owv puts it: a dword at +16
                                                     // (FORMAT.md says a word at +14; nothing reads it)
            Pal.CopyTo(h, 32);
            return h;
        }

        public byte[] File()
        {
            var o = new MemoryStream();
            var h = Header(); o.Write(h, 0, h.Length);
            foreach (var c in Chunks) o.Write(c, 0, c.Length);
            var e = Chunk(CH_END, Array.Empty<byte>()); o.Write(e, 0, e.Length);
            return o.ToArray();
        }
    }

    // ========================================================================
    //  The kit's test set
    // ========================================================================
    static int TestSet(string dir)
    {
        Directory.CreateDirectory(dir);
        var v = new Owv { Fps = 12, Flags = 1, Rate = 11025 };     // audio, unsigned 8-bit
        // palette: 0 black, 1-63 grey, 64-127 blue, 128-191 green, 192-255 a rainbow
        for (int i = 0; i < 256; i++)
        {
            int r, g, b, t = i & 63;
            if (i < 64) { r = g = b = t; }
            else if (i < 128) { r = t / 4; g = t / 2; b = t; }
            else if (i < 192) { r = t / 3; g = t; b = t / 4; }
            else { r = Tri(t, 0); g = Tri(t, 21); b = Tri(t, 42); }
            v.Pal[i * 3] = (byte)r; v.Pal[i * 3 + 1] = (byte)g; v.Pal[i * 3 + 2] = (byte)b;
        }
        // the pan of the background, frame by frame (content moves by this)
        int[][] pans = {
            new[]{0,0}, new[]{-2,0}, new[]{-2,0}, new[]{-2,0}, new[]{0,0}, new[]{0,0}, new[]{1,-1},
            new[]{1,-1}, new[]{0,2}, new[]{0,2}, new[]{3,1}, new[]{-1,-2}, new[]{0,0}, new[]{0,0},
            new[]{-4,0}, new[]{-4,0}, new[]{0,0}, new[]{2,2}, new[]{2,2}, new[]{0,0}, new[]{-1,0},
            new[]{-1,0}, new[]{0,-1}, new[]{0,0} };
        int camx = 0, camy = 0;
        var rnd = new Random(1978);
        var audio = new Queue<byte>();
        int frames = pans.Length;
        for (int f = 0; f < frames; f++)
        {
            camx -= pans[f][0]; camy -= pans[f][1];
            var img = Scene(f, camx, camy, rnd);
            // audio first, as in every OWV: 11025/12 = 918.75 samples a frame
            int from = f * 11025 / 12, to = (f + 1) * 11025 / 12;
            var a = new byte[to - from];
            for (int k = 0; k < a.Length; k++) a[k] = (byte)(128 + 40 * Math.Sin((from + k) * 2 * Math.PI * 440 / 11025));
            v.Chunks.Add(Chunk(CH_AUDIO, a));
            if (f == 3) v.Chunks.Add(Chunk(0x42, Encoding.ASCII.GetBytes("an unknown chunk: the player steps over it")));
            if (f == 6)
            {
                var e = new byte[64 * 3];                 // the rainbow, turned by 16
                for (int k = 0; k < 64; k++) Array.Copy(v.Pal, (192 + ((k + 16) & 63)) * 3, e, k * 3, 3);
                v.Palette(192, e);
            }
            if (f == 0 || f == 16) v.Key(img);
            else v.Delta(img, pans[f][0], pans[f][1]);
        }
        string[] names = { "skip", "fill", "literal", "copy", "rle", "shifted frames" };
        for (int k = 0; k < 6; k++)
        {
            Console.WriteLine($"{names[k],-15}{v.Ops[k]}");
            if (v.Ops[k] == 0) throw new Exception("the test clip does not use " + names[k]);
        }
        var file = v.File();
        string owv = Path.Combine(dir, "VTEST.OWV");
        System.IO.File.WriteAllBytes(owv, file);
        var sum = new byte[2 + 2 * v.Sums.Count];
        U16(sum, 0, v.Sums.Count);
        for (int k = 0; k < v.Sums.Count; k++) U16(sum, 2 + 2 * k, v.Sums[k]);
        System.IO.File.WriteAllBytes(Path.Combine(dir, "VTEST.SUM"), sum);
        Check(file, v.Sums);
        Console.WriteLine($"VTEST.OWV      {file.Length} bytes, {v.Frames} frames, decoded again: sums match");

        // ---- broken files ---------------------------------------------------
        // VBAD1: cut in the middle of the third video chunk's payload -> CF 5
        int pos = 800, video = 0, cut = -1;
        while (pos + 6 <= file.Length)
        {
            int len = (int)BitConverter.ToUInt32(file, pos + 2);
            if (file[pos] == CH_KEY || file[pos] == CH_DELTA) { if (++video == 3) { cut = pos + 6 + len / 2; break; } }
            pos += 6 + len;
        }
        System.IO.File.WriteAllBytes(Path.Combine(dir, "VBAD1.OWV"), file.AsSpan(0, cut).ToArray());
        var hdr = v.Header();
        var key = v.Chunks.First(c => c[0] == CH_KEY);
        // VBAD2: a delta with an opcode the format does not have (90h) -> CF 6
        Bad(dir, "VBAD2.OWV", hdr, key, Chunk(CH_DELTA, new byte[] { 0, 0, 0x05, 0x90, 1, 2, 3, OP_END }));
        // VBAD3: a key chunk that says 70000 bytes - over one segment -> CF 4
        var big = new byte[6]; big[0] = CH_KEY; U32(big, 2, 70000);
        Bad(dir, "VBAD3.OWV", hdr, big, new byte[100]);
        // VBAD4: not OWV1 -> CF 2 from OWV_OPEN
        var h4 = (byte[])hdr.Clone(); h4[3] = (byte)'9';
        Bad(dir, "VBAD4.OWV", h4, key);
        // VBAD5: a 640x400 file -> CF 3 from OWV_OPEN
        var h5 = (byte[])hdr.Clone(); U16(h5, 4, 640); U16(h5, 6, 400);
        Bad(dir, "VBAD5.OWV", h5, key);
        // VBAD6: a COPY from outside the frame (block 0, from -4,-4) -> CF 6
        Bad(dir, "VBAD6.OWV", hdr, key, Chunk(CH_DELTA, new byte[] { 0, 0, OP_COPY, 0xFC, 0xFC, OP_END }));
        Console.WriteLine("VBAD1..VBAD6   written");
        return 0;
    }

    static int Tri(int t, int ph) { int x = (t + ph) % 64; return x < 32 ? x * 2 : (63 - x) * 2; }

    static void Bad(string dir, string name, params byte[][] parts)
    {
        var o = new MemoryStream();
        foreach (var p in parts) o.Write(p, 0, p.Length);
        System.IO.File.WriteAllBytes(Path.Combine(dir, name), o.ToArray());
    }

    // One frame of the test scene. Every region is there to make one opcode:
    //  the background (world coordinates, panned)   -> global shift + skip
    //  a solid square that moves                    -> FILL
    //  a noise sprite that moves by (3,1) a frame    -> COPY from the frame before
    //  a "waterfall": fresh stripes every frame     -> RLE
    //  a box of fresh noise every frame              -> LITERAL
    static byte[] Scene(int f, int camx, int camy, Random rnd)
    {
        var p = new byte[PLANE];
        for (int y = 0; y < H; y++)
            for (int x = 0; x < W; x++)
            {
                int wx = x + camx, wy = y + camy;
                int c = ((((wx >> 4) ^ (wy >> 4)) & 1) != 0) ? 70 : 140;          // a checker of 16
                c += ((wx * 7 + wy * 13) >> 3) & 15;                                 // a slow ripple
                if (((wx & 31) == 3) || ((wy & 31) == 5)) c = 40;                    // grid lines
                p[y * W + x] = (byte)c;
            }
        // the solid square, 40x40, moving (+4,+2) a frame
        int sx = 120 + 4 * f, sy = 20 + 2 * f;
        for (int y = sy; y < sy + 40 && y < H; y++)
            for (int x = sx; x < sx + 40 && x < W; x++) p[y * W + x] = 200;
        // the noise sprite, 48x48, its pixels its own (sprite coordinates)
        int nx = 20 + 3 * f, ny = 40 + 1 * f;
        for (int y = 0; y < 48; y++)
            for (int x = 0; x < 48; x++)
            {
                int X = nx + x, Y = ny + y;
                if (X < W && Y < H) p[Y * W + X] = (byte)(1 + (Hash(x, y) % 62));
            }
        // the waterfall: 3-pixel stripes, new colours each frame
        for (int y = 120; y < 184; y++)
            for (int x = 200; x < 264; x++)
                p[y * W + x] = (byte)(192 + (Hash(y / 3, f * 977 + (x >= 232 ? 1 : 0)) & 63));
        // the static box: fresh noise
        for (int y = 128; y < 184; y++)
            for (int x = 248 + 24; x < 312; x++) p[y * W + x] = (byte)rnd.Next(256);
        return p;
    }

    static int Hash(int a, int b)
    {
        uint h = (uint)(a * 73856093) ^ (uint)(b * 19349663);
        h ^= h >> 13; h *= 0x5bd1e995; h ^= h >> 15;
        return (int)(h & 0x7FFFFFFF);
    }

    // ========================================================================
    //  BMP frames
    // ========================================================================
    static int FromBmps(string[] args)
    {
        string output = args[0];
        var v = new Owv();
        int keyEvery = 48;
        var files = new List<string>();
        for (int i = 1; i < args.Length; i++)
        {
            string a = args[i].ToLowerInvariant();
            if (a == "/fps") v.Fps = int.Parse(args[++i]);
            else if (a == "/key") keyEvery = int.Parse(args[++i]);
            else files.Add(args[i]);
        }
        if (v.Fps < 1 || v.Fps > 255) throw new Exception("/fps is 1..255");
        if (files.Count == 0) throw new Exception("no BMP files");
        for (int i = 0; i < files.Count; i++)
        {
            var (pix, pal) = ReadBmp(files[i]);
            if (i == 0) pal.CopyTo(v.Pal, 0);
            if (i == 0 || (keyEvery > 0 && i % keyEvery == 0)) v.Key(pix); else v.Delta(pix);
        }
        var file = v.File();
        System.IO.File.WriteAllBytes(output, file);
        Check(file, v.Sums);
        Console.WriteLine($"{output}  {file.Length} bytes, {v.Frames} frames, decoded again: OK");
        return 0;
    }

    static (byte[], byte[]) ReadBmp(string path)
    {
        var b = System.IO.File.ReadAllBytes(path);
        if (b.Length < 54 || b[0] != 'B' || b[1] != 'M') throw new Exception(path + ": not a BMP");
        int off = BitConverter.ToInt32(b, 10), hs = BitConverter.ToInt32(b, 14);
        int w = BitConverter.ToInt32(b, 18), h = BitConverter.ToInt32(b, 22);
        int bits = BitConverter.ToUInt16(b, 28), comp = BitConverter.ToInt32(b, 30);
        int used = hs >= 40 ? BitConverter.ToInt32(b, 46) : 0;
        if (bits != 8 || comp != 0) throw new Exception(path + ": needs 8 bits a pixel, uncompressed");
        bool down = h < 0; h = Math.Abs(h);
        if (w != W || h != H) throw new Exception($"{path}: is {w}x{h}, needs {W}x{H}");
        var pal = new byte[768];
        int n = used == 0 ? 256 : Math.Min(used, 256);
        for (int i = 0; i < n; i++)
        {
            int q = 14 + hs + i * 4;
            pal[i * 3] = (byte)(b[q + 2] >> 2); pal[i * 3 + 1] = (byte)(b[q + 1] >> 2); pal[i * 3 + 2] = (byte)(b[q] >> 2);
        }
        int stride = (W + 3) & ~3;
        var pix = new byte[PLANE];
        for (int y = 0; y < H; y++)
            Array.Copy(b, off + (down ? y : H - 1 - y) * stride, pix, y * W, W);
        return (pix, pal);
    }

    // ========================================================================
    //  The independent decoder: what the 8086 player does, in C#.
    // ========================================================================
    static void Check(byte[] f, List<ushort> sums)
    {
        if (Encoding.ASCII.GetString(f, 0, 4) != "OWV1") throw new Exception("check: magic");
        var cur = new byte[PLANE]; var prev = new byte[PLANE];
        int pos = 800, n = 0;
        while (true)
        {
            byte type = f[pos]; int len = (int)BitConverter.ToUInt32(f, pos + 2);
            int p = pos + 6; pos = p + len;
            if (type == CH_END) break;
            if (type != CH_KEY && type != CH_DELTA) continue;
            if (len > 65535) throw new Exception("check: a chunk over 64 KB");
            (prev, cur) = (cur, prev);
            if (type == CH_KEY) UnRle(f, ref p, cur, 0, PLANE);
            else
            {
                int dx = (sbyte)f[p], dy = (sbyte)f[p + 1]; p += 2;
                Shift(prev, cur, dx, dy);
                int blk = 0;
                while (p < pos && blk < 1000)
                {
                    byte op = f[p++];
                    if (op == OP_END) break;
                    int bx = blk % 40, by = blk / 40, o = by * 8 * W + bx * 8;
                    if (op < 0x80) { blk += op + 1; continue; }
                    var t = new byte[64];
                    if (op == OP_FILL) { byte c = f[p++]; Array.Fill(t, c); }
                    else if (op == OP_LIT) { Array.Copy(f, p, t, 0, 64); p += 64; }
                    else if (op == OP_COPY)
                    {
                        int cx = (sbyte)f[p], cy = (sbyte)f[p + 1]; p += 2;
                        for (int r = 0; r < 8; r++) Array.Copy(prev, o + (r + cy) * W + cx, t, r * 8, 8);
                    }
                    else if (op == OP_RLE) { int l = f[p] | f[p + 1] << 8; p += 2; int q = p; UnRle(f, ref q, t, 0, 64); p += l; }
                    else throw new Exception("check: bad opcode");
                    for (int r = 0; r < 8; r++) Array.Copy(t, r * 8, cur, o + r * W, 8);
                    blk++;
                }
            }
            int s = 0; foreach (var b in cur) s += b;
            if ((ushort)s != sums[n]) throw new Exception($"check: frame {n} sum {(ushort)s:X4}, wanted {sums[n]:X4}");
            n++;
        }
        if (n != sums.Count) throw new Exception("check: frame count");
    }

    static void UnRle(byte[] src, ref int p, byte[] dst, int o, int count)
    {
        while (count > 0)
        {
            int lead = src[p++];
            if (lead < 0x80) { int n = Math.Min(lead + 1, count); Array.Copy(src, p, dst, o, n); p += lead + 1; o += n; count -= n; }
            else { int n = Math.Min(lead - 0x7F, count); byte c = src[p++]; for (int k = 0; k < n; k++) dst[o++] = c; count -= n; }
        }
    }

    // ========================================================================
    //  Vid2Owv's pieces, for a 320x200 frame
    // ========================================================================
    static byte[] Rle(byte[] src, int off, int len)
    {
        var o = new MemoryStream(len);
        int i = 0;
        while (i < len)
        {
            int run = 1;
            while (i + run < len && src[off + i + run] == src[off + i] && run < 128) run++;
            if (run >= 2) { o.WriteByte((byte)(0x7F + run)); o.WriteByte(src[off + i]); i += run; }
            else
            {
                int start = i, lit = 0;
                while (i < len && lit < 128)
                {
                    int r = 1;
                    while (i + r < len && src[off + i + r] == src[off + i] && r < 3) r++;
                    if (r >= 3) break;
                    i++; lit++;
                }
                o.WriteByte((byte)(lit - 1));
                o.Write(src, off + start, lit);
            }
        }
        return o.ToArray();
    }

    static void Shift(byte[] prev, byte[] dst, int dx, int dy)
    {
        Array.Clear(dst, 0, dst.Length);
        for (int y = 0; y < H; y++)
        {
            int sy = y - dy;
            if (sy < 0 || sy >= H) continue;
            int x0 = Math.Max(0, dx), x1 = Math.Min(W, W + dx);
            if (x1 <= x0) continue;
            Array.Copy(prev, sy * W + (x0 - dx), dst, y * W + x0, x1 - x0);
        }
    }

    static (int, int) FindGlobal(byte[] cur, byte[] prev, int range)
    {
        long best = long.MaxValue; int bx = 0, by = 0;
        for (int dy = -range; dy <= range; dy++)
            for (int dx = -range; dx <= range; dx++)
            {
                long bad = 0;
                for (int y = Math.Max(0, dy); y < Math.Min(H, H + dy); y += 2)
                    for (int x = Math.Max(0, dx); x < Math.Min(W, W + dx); x += 2)
                        if (cur[y * W + x] != prev[(y - dy) * W + x - dx]) bad++;
                bad += 2 * (Math.Abs(dx) * H + Math.Abs(dy) * W) / 4;   // the strip that must be coded
                if (bad < best) { best = bad; bx = dx; by = dy; }
            }
        return (bx, by);
    }

    static bool InRange(int bx, int by, int dx, int dy)
    {
        int x0 = bx * BLOCK - dx, y0 = by * BLOCK - dy;
        return x0 >= 0 && y0 >= 0 && x0 + BLOCK <= W && y0 + BLOCK <= H;
    }

    static bool BlockEq(byte[] a, byte[] b, int bx, int by)
    {
        for (int r = 0; r < 8; r++)
        {
            int o = (by * 8 + r) * W + bx * 8;
            for (int c = 0; c < 8; c++) if (a[o + c] != b[o + c]) return false;
        }
        return true;
    }

    static void Gather(byte[] src, byte[] blk, int bx, int by)
    { for (int r = 0; r < 8; r++) Array.Copy(src, (by * 8 + r) * W + bx * 8, blk, r * 8, 8); }

    static void Scatter(byte[] dst, byte[] blk, int bx, int by)
    { for (int r = 0; r < 8; r++) Array.Copy(blk, r * 8, dst, (by * 8 + r) * W + bx * 8, 8); }

    static (int, int, bool) FindCopy(byte[] prev, byte[] blk, int bx, int by, int range)
    {
        int px = bx * 8, py = by * 8;
        for (int dy = -range; dy <= range; dy++)
            for (int dx = -range; dx <= range; dx++)
            {
                int sx = px + dx, sy = py + dy;
                if (sx < 0 || sy < 0 || sx + 8 > W || sy + 8 > H) continue;
                bool ok = true;
                for (int r = 0; r < 8 && ok; r++)
                    for (int c = 0; c < 8; c++)
                        if (prev[(sy + r) * W + sx + c] != blk[r * 8 + c]) { ok = false; break; }
                if (ok) return (dx, dy, true);
            }
        return (0, 0, false);
    }

    static byte[] Chunk(byte type, byte[] payload)
    {
        var c = new byte[6 + payload.Length];
        c[0] = type; U32(c, 2, (uint)payload.Length);
        payload.CopyTo(c, 6);
        return c;
    }

    static void U16(byte[] b, int o, int v) { b[o] = (byte)v; b[o + 1] = (byte)(v >> 8); }
    static void U32(byte[] b, int o, uint v) { b[o] = (byte)v; b[o + 1] = (byte)(v >> 8); b[o + 2] = (byte)(v >> 16); b[o + 3] = (byte)(v >> 24); }
}
