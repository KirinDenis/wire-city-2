// ============================================================================
//  Vid2Owv - pack footage into the OWV video format read by OWL FLY 4.
//
//      dotnet run --project TOOLS\Vid2Owv -c Release -- <manifest.INF>
//
//  The manifest is the tracked recipe; the footage and the packed output are
//  not. Everything the converter needs to reproduce a scene byte for byte is
//  in that one file, which is the whole reason it exists.
//
//  WHAT THIS TOOL DOES NOT DO: quantise. ffmpeg picks one palette for the
//  whole clip (palettegen with stats_mode=full) and dithers against it, and
//  this tool reads indices that are already decided. Writing a quantiser
//  would be a month of work to arrive somewhere worse.
//
//  WHY THE DITHER MUST BE ORDERED. paletteuse is called with dither=bayer,
//  and that is not a preference. Ordered dithering is deterministic - the
//  same input pixel yields the same index every frame - so an unchanged part
//  of the picture stays byte-identical and every SKIP and COPY below works.
//  Error diffusion produces a better-looking still and a useless codec: the
//  error arrives from a different place each frame, so no block is ever
//  unchanged and the delta frames degenerate into whole literal frames.
//
//  See LAB/OWLFLY4/VIDEO/FORMAT.md for the file layout this writes.
// ============================================================================

using System.Diagnostics;
using System.Text;

static class Program
{
    // ---- chunk types ------------------------------------------------------
    const byte CHUNK_KEY = 0x01;
    const byte CHUNK_DELTA = 0x02;
    const byte CHUNK_AUDIO = 0x03;
    const byte CHUNK_PALETTE = 0x04;
    const byte CHUNK_END = 0xFF;

    // ---- block opcodes ----------------------------------------------------
    // 0x00-0x7F  skip n+1 blocks
    const byte OP_FILL = 0x80;
    const byte OP_LITERAL = 0x81;
    const byte OP_COPY = 0x82;
    const byte OP_RLE = 0x83;
    const byte OP_ENDFRAME = 0xFF;

    const int BLOCK = 8;
    const int HEADER_SIZE = 800;

    // How different two pixels may be and still count as unchanged.
    //
    // This has to be asked of the COLOURS, not of the indices: two indices
    // far apart as numbers can be the same colour, and two neighbours can be
    // nothing alike, because palettegen orders entries by how it found them.
    // So the whole 256x256 table of distances is built once per clip.
    //
    // With TOLERANCE = 0 the codec is exact against the previous frame. Above
    // zero it is lossy in time, which is what every codec of this kind
    // actually is - the alternative on noisy footage is no skipped blocks at
    // all, and then the format has no reason to exist.
    static int[] Dist;
    static int Threshold;

    static int Main(string[] args)
    {
        if (args.Length < 1)
        {
            Console.Error.WriteLine("usage: Vid2Owv <manifest.INF> [/reuse]");
            Console.Error.WriteLine("  /reuse  keep the ffmpeg intermediates from last time");
            return 2;
        }

        bool reuse = args.Any(a => a.Equals("/reuse", StringComparison.OrdinalIgnoreCase));
        string manifestPath = Path.GetFullPath(args[0]);
        if (!File.Exists(manifestPath))
        {
            Console.Error.WriteLine($"manifest not found: {manifestPath}");
            return 2;
        }

        var m = Manifest.Load(manifestPath);
        string baseDir = Path.GetDirectoryName(manifestPath)!;
        string work = Path.Combine(baseDir, "frames");
        Directory.CreateDirectory(work);

        string source = Path.GetFullPath(Path.Combine(baseDir, m.Source));
        string output = Path.GetFullPath(Path.Combine(baseDir, m.Output));
        string palPng = Path.Combine(work, "pal.png");
        string palRaw = Path.Combine(work, "pal.raw");
        string framesRaw = Path.Combine(work, "frames.raw");
        string audioRaw = Path.Combine(work, "audio.raw");

        if (!File.Exists(source))
        {
            Console.Error.WriteLine($"source footage not found: {source}");
            Console.Error.WriteLine("Footage lives in src\\ and is not tracked - see the folder README.");
            return 2;
        }

        Console.WriteLine($"manifest  {manifestPath}");
        Console.WriteLine($"source    {source}");
        Console.WriteLine($"output    {output}");
        Console.WriteLine($"mode      {m.Width}x{m.Height} at {m.Fps} fps, keyframe every {m.KeyEvery}");

        // -- ffmpeg ---------------------------------------------------------
        if (!reuse)
        {
            string ffmpeg = FindFfmpeg();
            if (ffmpeg == null)
            {
                Console.Error.WriteLine("ffmpeg not found. Put it on PATH or set FFMPEG to its full path.");
                return 2;
            }
            Console.WriteLine($"ffmpeg    {ffmpeg}");

            // The denoiser is not cosmetic. Live footage has grain, and grain
            // means a "still" part of the picture is not still at pixel level:
            // it lands on a different palette index every frame, no block is
            // ever unchanged, and the delta frames degenerate into literals.
            // hqdn3d's last two parameters are the TEMPORAL ones, and those
            // are the ones that matter here.
            string denoise = m.Denoise.Length > 0 ? "," + m.Denoise : "";
            string scale = $"fps={m.Fps},scale={m.Width}:{m.Height}:flags=lanczos{denoise}";

            // One palette for the whole clip. stats_mode=full reads every
            // frame, so a scene that darkens does not drag the palette after
            // it and then swim when it comes back.
            if (!Run(ffmpeg, $"-y -v error -i \"{source}\" -vf \"{scale},palettegen=stats_mode=full\" \"{palPng}\"")) return 1;

            // paletteuse needs its two inputs wired by hand. Left implicit,
            // the palette is fed into the head of the chain instead and
            // ffmpeg stops with "Palette input must contain exactly 256
            // pixels" - which is the good case; the bad case is a filter
            // graph that quietly does something else.
            if (!Run(ffmpeg, $"-y -v error -i \"{source}\" -i \"{palPng}\" " +
                             $"-lavfi \"{scale}[x];[x][1:v]paletteuse=dither={m.Dither}\" " +
                             $"-f rawvideo -pix_fmt pal8 \"{framesRaw}\"")) return 1;

            if (!Run(ffmpeg, $"-y -v error -i \"{palPng}\" -f rawvideo -pix_fmt rgba \"{palRaw}\"")) return 1;

            if (m.AudioRate > 0)
            {
                // Eight-bit audio has about 48 dB to work with, and a quiet
                // passage sits so low in that range that the quantisation
                // error stops being masked and becomes audible hiss - the
                // sound of a worn video tape. Two things fix it, and both
                // are what the era did:
                //
                //   DITHER, so the error becomes steady noise instead of
                //   distortion that follows the signal. Undithered eight-bit
                //   does not hiss evenly; it swells with the material, which
                //   is why it draws attention to itself.
                //
                //   COMPRESSION, so quiet passages are lifted off the noise
                //   floor rather than left sitting in it. Games of this kind
                //   compressed their speech hard for exactly this reason.
                //
                // Both are in AUDIOFILTER and can be changed per scene.
                string af = m.AudioFilter.Length > 0 ? m.AudioFilter + "," : "";
                string chain = $"{af}aresample=osr={m.AudioRate}:osf=u8:dither_method=triangular_hp";
                if (!Run(ffmpeg, $"-y -v error -i \"{source}\" -ac 1 -af \"{chain}\" " +
                                 $"-f u8 -ar {m.AudioRate} \"{audioRaw}\"")) return 1;
            }
        }
        else
        {
            Console.WriteLine("ffmpeg    skipped (/reuse)");
        }

        // -- read what ffmpeg produced ---------------------------------------
        int w = m.Width, h = m.Height, plane = w * h;

        // rawvideo pal8 appends the 1024-byte palette to EVERY frame, so the
        // stride is not the plane size. Older builds may not; both are
        // accepted rather than assumed, because guessing wrong here shifts
        // every frame by a kilobyte and the picture merely looks odd.
        long rawLen = new FileInfo(framesRaw).Length;
        int stride;
        if (rawLen % (plane + 1024) == 0) stride = plane + 1024;
        else if (rawLen % plane == 0) stride = plane;
        else
        {
            Console.Error.WriteLine($"frames.raw is {rawLen} bytes, which is not a whole number of " +
                                    $"{plane}-byte or {plane + 1024}-byte frames. Wrong width/height?");
            return 1;
        }
        int frameCount = (int)(rawLen / stride);
        Console.WriteLine($"frames    {frameCount}  (stride {stride}{(stride > plane ? ", palette appended per frame" : "")})");

        byte[] palette = ReadPalette(palRaw);
        BuildDistance(palette, m.Tolerance);
        Console.WriteLine($"tolerance {m.Tolerance}" + (m.Tolerance == 0 ? "  (exact match required to skip a block)" : ""));
        byte[] audio = m.AudioRate > 0 && File.Exists(audioRaw) ? File.ReadAllBytes(audioRaw) : Array.Empty<byte>();
        if (audio.Length > 0)
            Console.WriteLine($"audio     {audio.Length} bytes, {m.AudioRate} Hz mono 8-bit ({audio.Length / (double)m.AudioRate:F2} s)");

        // -- encode -----------------------------------------------------------
        var stats = new Stats();
        var chunks = new List<byte[]>();

        // recon is what the PLAYER will be holding, not what the footage
        // holds. The moment a skip became approximate the two stopped being
        // the same thing, and comparing against the footage would let the
        // error compound quietly for a whole keyframe interval - the picture
        // rots and nothing in the encoder ever notices. So the encoder
        // reconstructs exactly what it just described, and predicts from it.
        byte[] recon = new byte[plane];
        byte[] cur = new byte[plane];
        byte[] predicted = new byte[plane];

        using (var fs = File.OpenRead(framesRaw))
        {
            for (int i = 0; i < frameCount; i++)
            {
                fs.Seek((long)i * stride, SeekOrigin.Begin);
                ReadExactly(fs, cur, plane);

                if (audio.Length > 0)
                {
                    int from = (int)((long)i * m.AudioRate / m.Fps);
                    int to = (int)((long)(i + 1) * m.AudioRate / m.Fps);
                    if (from > audio.Length) from = audio.Length;
                    if (to > audio.Length) to = audio.Length;
                    if (to > from)
                    {
                        var a = new byte[to - from];
                        Array.Copy(audio, from, a, 0, to - from);
                        chunks.Add(MakeChunk(CHUNK_AUDIO, a));
                        stats.AudioBytes += a.Length;
                    }
                }

                bool key = (i == 0) || (m.KeyEvery > 0 && i % m.KeyEvery == 0);
                byte[] payload;
                if (key)
                {
                    payload = Rle(cur, 0, plane);
                    chunks.Add(MakeChunk(CHUNK_KEY, payload));
                    stats.KeyFrames++;
                    stats.KeyBytes += payload.Length;
                    Array.Copy(cur, recon, plane);   // a keyframe is exact
                }
                else
                {
                    payload = EncodeDelta(cur, recon, predicted, w, h, m, stats);
                    chunks.Add(MakeChunk(CHUNK_DELTA, payload));
                    stats.DeltaFrames++;
                    stats.DeltaBytes += payload.Length;
                    (recon, predicted) = (predicted, recon);
                }
            }
        }
        chunks.Add(MakeChunk(CHUNK_END, Array.Empty<byte>()));

        // -- write -------------------------------------------------------------
        int maxChunk = chunks.Max(c => c.Length);
        using (var os = File.Create(output))
        {
            var hdr = new byte[HEADER_SIZE];
            Encoding.ASCII.GetBytes("OWV1").CopyTo(hdr, 0);
            PutU16(hdr, 4, w);
            PutU16(hdr, 6, h);
            hdr[8] = (byte)m.Fps;
            hdr[9] = (byte)(audio.Length > 0 ? 1 : 0);
            PutU16(hdr, 10, frameCount);
            PutU16(hdr, 12, audio.Length > 0 ? m.AudioRate : 0);
            PutU32(hdr, 16, (uint)maxChunk);
            PutU32(hdr, 20, 0);                       // no index
            palette.CopyTo(hdr, 32);
            os.Write(hdr, 0, hdr.Length);
            foreach (var c in chunks) os.Write(c, 0, c.Length);
        }

        stats.Report(output, frameCount, m.Fps, maxChunk);
        return 0;
    }

    // ========================================================================
    //  Delta frames
    // ========================================================================
    // predicted comes in as scratch and goes out as the reconstruction: what
    // the player will hold after acting on the bytes this returns.
    static byte[] EncodeDelta(byte[] cur, byte[] recon, byte[] predicted,
                              int w, int h, Manifest m, Stats stats)
    {
        var (gdx, gdy) = FindGlobalVector(cur, recon, w, h, m.Search);
        if (gdx != 0 || gdy != 0) stats.PannedFrames++;

        // Build what the player will be looking at after it shifts the
        // previous frame. Anything outside the source is undefined, and the
        // blocks that touch it are forbidden from skipping - the player has
        // stale pixels there and nothing else to put in them.
        Shift(recon, predicted, w, h, gdx, gdy);

        var body = new MemoryStream();
        body.WriteByte((byte)(sbyte)gdx);
        body.WriteByte((byte)(sbyte)gdy);

        int bw = w / BLOCK, bh = h / BLOCK;
        int skipRun = 0;
        var block = new byte[BLOCK * BLOCK];
        int lastCoded = -1;

        // Find the last block that needs coding, so the frame can be cut
        // short with ENDFRAME rather than paying for trailing skips.
        var needs = new bool[bw * bh];
        for (int by = 0; by < bh; by++)
            for (int bx = 0; bx < bw; bx++)
            {
                bool valid = SourceInRange(bx, by, w, h, gdx, gdy);
                bool same = valid && BlockEquals(cur, predicted, w, bx, by);
                needs[by * bw + bx] = !same;
                if (!same) lastCoded = by * bw + bx;
            }

        for (int idx = 0; idx <= lastCoded; idx++)
        {
            int bx = idx % bw, by = idx / bw;
            if (!needs[idx]) { skipRun++; if (skipRun == 128) { EmitSkip(body, ref skipRun, stats); } continue; }
            EmitSkip(body, ref skipRun, stats);

            Gather(cur, block, w, bx, by);

            // FILL - a night scene is mostly one dark colour, and 64 equal
            // bytes for two is the cheapest win in the format.
            byte first = block[0];
            bool uniform = true;
            for (int k = 1; k < block.Length; k++) if (block[k] != first) { uniform = false; break; }
            if (uniform)
            {
                body.WriteByte(OP_FILL); body.WriteByte(first);
                FillBlock(predicted, w, bx, by, first);
                stats.Fill++; continue;
            }

            // COPY - exact matches only. An approximate match would need a
            // threshold, and on indexed colour the distance between two
            // indices means nothing. Whether this earns its place at all is
            // an open question the statistics below are meant to settle.
            if (m.Copy)
            {
                var (cdx, cdy, found) = FindBlockVector(cur, recon, w, h, bx, by, block, m.CopySearch);
                if (found)
                {
                    body.WriteByte(OP_COPY);
                    body.WriteByte((byte)(sbyte)cdx);
                    body.WriteByte((byte)(sbyte)cdy);
                    CopyBlock(recon, predicted, w, bx, by, cdx, cdy);
                    stats.Copy++; continue;
                }
            }

            Scatter(predicted, block, w, bx, by);   // RLE and LITERAL are exact
            byte[] rle = Rle(block, 0, block.Length);
            if (rle.Length < block.Length)
            {
                body.WriteByte(OP_RLE);
                PutU16Stream(body, rle.Length);
                body.Write(rle, 0, rle.Length);
                stats.Rle++; stats.RleBytes += rle.Length;
            }
            else
            {
                body.WriteByte(OP_LITERAL);
                body.Write(block, 0, block.Length);
                stats.Literal++;
            }
        }

        body.WriteByte(OP_ENDFRAME);
        return body.ToArray();
    }

    static void EmitSkip(MemoryStream body, ref int run, Stats stats)
    {
        while (run > 0)
        {
            int n = Math.Min(run, 128);
            body.WriteByte((byte)(n - 1));
            stats.Skip += n; stats.SkipOps++;
            run -= n;
        }
    }

    // The global vector is what makes a slow pan cost thirty bytes instead of
    // four thousand blocks. Searched coarse then fine: a full search of the
    // whole range at full density is 40 million comparisons a frame and buys
    // nothing, because a pan is smooth.
    static (int, int) FindGlobalVector(byte[] cur, byte[] prev, int w, int h, int range)
    {
        int bestDx = 0, bestDy = 0;
        long bestScore = ScoreShift(cur, prev, w, h, 0, 0, 8);

        for (int dy = -range; dy <= range; dy += 4)
            for (int dx = -range; dx <= range; dx += 4)
            {
                if (dx == 0 && dy == 0) continue;
                long s = ScoreShift(cur, prev, w, h, dx, dy, 8);
                if (s > bestScore) { bestScore = s; bestDx = dx; bestDy = dy; }
            }

        int cx = bestDx, cy = bestDy;
        bestScore = ScoreShift(cur, prev, w, h, cx, cy, 4);
        for (int dy = cy - 3; dy <= cy + 3; dy++)
            for (int dx = cx - 3; dx <= cx + 3; dx++)
            {
                if (dx == cx && dy == cy) continue;
                if (dx < -127 || dx > 127 || dy < -127 || dy > 127) continue;
                long s = ScoreShift(cur, prev, w, h, dx, dy, 4);
                if (s > bestScore) { bestScore = s; bestDx = dx; bestDy = dy; }
            }

        // A still scene must come out as (0,0). Ties go to no motion, or a
        // flat night sky invents a vector and every block below it changes.
        long zero = ScoreShift(cur, prev, w, h, 0, 0, 4);
        if (zero >= bestScore) return (0, 0);
        return (bestDx, bestDy);
    }

    static long ScoreShift(byte[] cur, byte[] prev, int w, int h, int dx, int dy, int step)
    {
        long hits = 0;
        for (int y = 0; y < h; y += step)
        {
            int sy = y - dy;
            if (sy < 0 || sy >= h) continue;
            int rowC = y * w, rowP = sy * w;
            for (int x = 0; x < w; x += step)
            {
                int sx = x - dx;
                if (sx < 0 || sx >= w) continue;
                if (cur[rowC + x] == prev[rowP + sx]) hits++;
            }
        }
        return hits;
    }

    static void Shift(byte[] prev, byte[] dst, int w, int h, int dx, int dy)
    {
        Array.Clear(dst, 0, dst.Length);
        for (int y = 0; y < h; y++)
        {
            int sy = y - dy;
            if (sy < 0 || sy >= h) continue;
            int x0 = Math.Max(0, dx), x1 = Math.Min(w, w + dx);
            if (x1 <= x0) continue;
            Array.Copy(prev, sy * w + (x0 - dx), dst, y * w + x0, x1 - x0);
        }
    }

    static bool SourceInRange(int bx, int by, int w, int h, int dx, int dy)
    {
        int x0 = bx * BLOCK - dx, y0 = by * BLOCK - dy;
        return x0 >= 0 && y0 >= 0 && x0 + BLOCK <= w && y0 + BLOCK <= h;
    }

    static void BuildDistance(byte[] pal, int tolerance)
    {
        // Weighted squared distance on the 6-bit values the DAC will get.
        // The weights sum to nine, so a threshold of 9*t*t makes TOLERANCE
        // read as roughly "how many of sixty-four levels a channel may move".
        Threshold = 9 * tolerance * tolerance;
        Dist = new int[256 * 256];
        for (int a = 0; a < 256; a++)
            for (int b = 0; b < 256; b++)
            {
                int dr = pal[a * 3] - pal[b * 3];
                int dg = pal[a * 3 + 1] - pal[b * 3 + 1];
                int db = pal[a * 3 + 2] - pal[b * 3 + 2];
                Dist[(a << 8) | b] = 2 * dr * dr + 4 * dg * dg + 3 * db * db;
            }
    }

    static bool BlockEquals(byte[] a, byte[] b, int w, int bx, int by)
    {
        for (int r = 0; r < BLOCK; r++)
        {
            int o = (by * BLOCK + r) * w + bx * BLOCK;
            for (int c = 0; c < BLOCK; c++)
            {
                int x = a[o + c], y = b[o + c];
                if (x != y && Dist[(x << 8) | y] > Threshold) return false;
            }
        }
        return true;
    }

    static void Gather(byte[] src, byte[] block, int w, int bx, int by)
    {
        for (int r = 0; r < BLOCK; r++)
            Array.Copy(src, (by * BLOCK + r) * w + bx * BLOCK, block, r * BLOCK, BLOCK);
    }

    static void Scatter(byte[] dst, byte[] block, int w, int bx, int by)
    {
        for (int r = 0; r < BLOCK; r++)
            Array.Copy(block, r * BLOCK, dst, (by * BLOCK + r) * w + bx * BLOCK, BLOCK);
    }

    static void FillBlock(byte[] dst, int w, int bx, int by, byte v)
    {
        for (int r = 0; r < BLOCK; r++)
        {
            int o = (by * BLOCK + r) * w + bx * BLOCK;
            for (int c = 0; c < BLOCK; c++) dst[o + c] = v;
        }
    }

    static void CopyBlock(byte[] src, byte[] dst, int w, int bx, int by, int dx, int dy)
    {
        for (int r = 0; r < BLOCK; r++)
            Array.Copy(src, (by * BLOCK + r + dy) * w + bx * BLOCK + dx,
                       dst, (by * BLOCK + r) * w + bx * BLOCK, BLOCK);
    }

    static (int, int, bool) FindBlockVector(byte[] cur, byte[] prev, int w, int h,
                                            int bx, int by, byte[] block, int range)
    {
        int px = bx * BLOCK, py = by * BLOCK;
        for (int dy = -range; dy <= range; dy++)
            for (int dx = -range; dx <= range; dx++)
            {
                int sx = px + dx, sy = py + dy;
                if (sx < 0 || sy < 0 || sx + BLOCK > w || sy + BLOCK > h) continue;
                bool ok = true;
                for (int r = 0; r < BLOCK && ok; r++)
                {
                    int o = (sy + r) * w + sx, b = r * BLOCK;
                    for (int c = 0; c < BLOCK; c++)
                    {
                        int x = prev[o + c], y = block[b + c];
                        if (x != y && Dist[(x << 8) | y] > Threshold) { ok = false; break; }
                    }
                }
                if (ok) return (dx, dy, true);
            }
        return (0, 0, false);
    }

    // ========================================================================
    //  RLE.  Lead byte under 0x80 is a literal run of n+1; at or above, a
    //  repeat of (n - 0x7F). The player tests one bit and masks - no table,
    //  no branch tree.
    // ========================================================================
    static byte[] Rle(byte[] src, int off, int len)
    {
        var o = new MemoryStream(len);
        int i = 0;
        while (i < len)
        {
            int run = 1;
            while (i + run < len && src[off + i + run] == src[off + i] && run < 128) run++;
            if (run >= 2)
            {
                o.WriteByte((byte)(0x7F + run));
                o.WriteByte(src[off + i]);
                i += run;
            }
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

    // ========================================================================
    //  Plumbing
    // ========================================================================
    static byte[] MakeChunk(byte type, byte[] payload)
    {
        var c = new byte[6 + payload.Length];
        c[0] = type;
        c[1] = 0;
        PutU32(c, 2, (uint)payload.Length);
        payload.CopyTo(c, 6);
        return c;
    }

    static byte[] ReadPalette(string palRaw)
    {
        // pal.png rendered as rgba: R,G,B,A per entry. The VGA DAC takes six
        // bits, so the shift happens here and the player never divides.
        var raw = File.ReadAllBytes(palRaw);
        if (raw.Length < 1024) throw new InvalidDataException($"{palRaw} is {raw.Length} bytes, expected 1024");
        var pal = new byte[768];
        for (int i = 0; i < 256; i++)
        {
            pal[i * 3 + 0] = (byte)(raw[i * 4 + 0] >> 2);
            pal[i * 3 + 1] = (byte)(raw[i * 4 + 1] >> 2);
            pal[i * 3 + 2] = (byte)(raw[i * 4 + 2] >> 2);
        }
        return pal;
    }

    static void ReadExactly(Stream s, byte[] buf, int count)
    {
        int done = 0;
        while (done < count)
        {
            int n = s.Read(buf, done, count - done);
            if (n <= 0) throw new EndOfStreamException();
            done += n;
        }
    }

    static void PutU16(byte[] b, int o, int v) { b[o] = (byte)v; b[o + 1] = (byte)(v >> 8); }
    static void PutU32(byte[] b, int o, uint v) { b[o] = (byte)v; b[o + 1] = (byte)(v >> 8); b[o + 2] = (byte)(v >> 16); b[o + 3] = (byte)(v >> 24); }
    static void PutU16Stream(MemoryStream s, int v) { s.WriteByte((byte)v); s.WriteByte((byte)(v >> 8)); }

    static string FindFfmpeg()
    {
        var env = Environment.GetEnvironmentVariable("FFMPEG");
        if (!string.IsNullOrWhiteSpace(env) && File.Exists(env)) return env;
        foreach (var dir in (Environment.GetEnvironmentVariable("PATH") ?? "").Split(Path.PathSeparator))
        {
            if (string.IsNullOrWhiteSpace(dir)) continue;
            try { var p = Path.Combine(dir, "ffmpeg.exe"); if (File.Exists(p)) return p; } catch { }
        }
        foreach (var p in new[] { @"C:\ffmpeg\bin\ffmpeg.exe", @"C:\Program Files\ffmpeg\bin\ffmpeg.exe" })
            if (File.Exists(p)) return p;
        return null;
    }

    static bool Run(string exe, string args)
    {
        var psi = new ProcessStartInfo(exe, args) { UseShellExecute = false, RedirectStandardError = true };
        using var p = Process.Start(psi);
        string err = p.StandardError.ReadToEnd();
        p.WaitForExit();
        if (p.ExitCode != 0)
        {
            Console.Error.WriteLine($"ffmpeg failed ({p.ExitCode}): {exe} {args}");
            Console.Error.WriteLine(err);
            return false;
        }
        if (!string.IsNullOrWhiteSpace(err)) Console.Error.WriteLine(err.Trim());
        return true;
    }

    // ========================================================================
    class Manifest
    {
        public string Source = "", Output = "";
        public int Width = 640, Height = 400, Fps = 12, KeyEvery = 48;
        public int AudioRate = 22050, Search = 24, CopySearch = 4;
        public string Dither = "bayer:bayer_scale=3";
        public string Denoise = "";
        // Everything before the eight-bit conversion. The high-pass takes out
        // rumble that would only eat headroom; the compressor lifts quiet
        // passages off the noise floor; the limiter stops the makeup gain
        // clipping. Set AUDIOFILTER = none in a manifest to hear the material
        // raw, which is worth doing once to know what the rest is buying.
        public string AudioFilter =
            "highpass=f=50,acompressor=threshold=0.06:ratio=4:attack=5:release=200:makeup=2,alimiter=limit=0.97";
        public int Tolerance = 0;
        public bool Copy = true;

        public static Manifest Load(string path)
        {
            var m = new Manifest();
            foreach (var raw in File.ReadAllLines(path))
            {
                var line = raw.Trim();
                if (line.Length == 0 || line[0] == ';' || line[0] == '#') continue;
                int eq = line.IndexOf('=');
                if (eq < 0) continue;
                string k = line.Substring(0, eq).Trim().ToUpperInvariant();
                string v = line.Substring(eq + 1).Trim();
                switch (k)
                {
                    case "SOURCE": m.Source = v; break;
                    case "OUTPUT": m.Output = v; break;
                    case "WIDTH": m.Width = int.Parse(v); break;
                    case "HEIGHT": m.Height = int.Parse(v); break;
                    case "FPS": m.Fps = int.Parse(v); break;
                    case "KEYEVERY": m.KeyEvery = int.Parse(v); break;
                    case "AUDIO": m.AudioRate = int.Parse(v); break;
                    case "DITHER": m.Dither = v; break;
                    case "DENOISE": m.Denoise = v.Equals("off", StringComparison.OrdinalIgnoreCase) ? "" : v; break;
                    case "AUDIOFILTER": m.AudioFilter = v.Equals("none", StringComparison.OrdinalIgnoreCase) ? "" : v; break;
                    case "TOLERANCE": m.Tolerance = int.Parse(v); break;
                    case "SEARCH": m.Search = int.Parse(v); break;
                    case "COPYSEARCH": m.CopySearch = int.Parse(v); break;
                    case "COPY": m.Copy = v.Equals("on", StringComparison.OrdinalIgnoreCase); break;
                }
            }
            if (m.Source == "" || m.Output == "") throw new InvalidDataException("manifest needs SOURCE and OUTPUT");
            if (m.Width % BLOCK != 0 || m.Height % BLOCK != 0)
                throw new InvalidDataException($"width and height must be multiples of {BLOCK}");
            return m;
        }
    }

    class Stats
    {
        public int KeyFrames, DeltaFrames, PannedFrames;
        public long KeyBytes, DeltaBytes, AudioBytes, RleBytes;
        public long Skip, SkipOps, Fill, Copy, Literal, Rle;

        public void Report(string output, int frames, int fps, int maxChunk)
        {
            long total = new FileInfo(output).Length;
            double seconds = frames / (double)fps;
            long coded = Fill + Copy + Literal + Rle;

            Console.WriteLine();
            Console.WriteLine($"  wrote     {Path.GetFileName(output)}  {total:N0} bytes");
            Console.WriteLine($"  duration  {seconds:F2} s   ->  {total / seconds / 1024:F0} KB/s");
            Console.WriteLine($"  largest chunk {maxChunk:N0} bytes (the player allocates this once)");
            Console.WriteLine();
            Console.WriteLine($"  keyframes {KeyFrames,6}   {KeyBytes,12:N0} bytes   {(KeyFrames > 0 ? KeyBytes / KeyFrames : 0),8:N0} each");
            Console.WriteLine($"  delta     {DeltaFrames,6}   {DeltaBytes,12:N0} bytes   {(DeltaFrames > 0 ? DeltaBytes / DeltaFrames : 0),8:N0} each");
            if (AudioBytes > 0)
                Console.WriteLine($"  audio            {AudioBytes,12:N0} bytes");
            Console.WriteLine($"  panned frames {PannedFrames} of {DeltaFrames} (a global vector was worth using)");
            Console.WriteLine();
            Console.WriteLine("  block opcodes across all delta frames");
            long all = Skip + coded;
            if (all == 0) all = 1;
            Console.WriteLine($"    skip    {Skip,10:N0}  {Skip * 100.0 / all,5:F1}%   in {SkipOps:N0} runs");
            Console.WriteLine($"    fill    {Fill,10:N0}  {Fill * 100.0 / all,5:F1}%");
            Console.WriteLine($"    copy    {Copy,10:N0}  {Copy * 100.0 / all,5:F1}%");
            Console.WriteLine($"    rle     {Rle,10:N0}  {Rle * 100.0 / all,5:F1}%   {(Rle > 0 ? RleBytes / Rle : 0)} bytes each");
            Console.WriteLine($"    literal {Literal,10:N0}  {Literal * 100.0 / all,5:F1}%");
            if (Copy == 0 && DeltaFrames > 0)
                Console.WriteLine("    NB copy never fired - it is complexity the player could drop.");
        }
    }
}
