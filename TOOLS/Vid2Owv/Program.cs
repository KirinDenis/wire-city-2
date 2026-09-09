// ============================================================================
//  Vid2Owv - pack footage into the OWV video format read by OWL FLY 4.
//
//      dotnet run --project TOOLS\Vid2Owv -c Release -- <manifest.INF>
//
//  The manifest is the tracked recipe; the footage and the packed output are
//  not. Everything the converter needs to reproduce a scene byte for byte is
//  in that one file, which is the whole reason it exists. MODE picks the
//  job: a clip (the default), a PICKUP (the room, its things and their slot
//  pictures - see Pickup below) or a scene's MUSIC (an OWA1 track).
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
        if (m.Mode == "PICKUP") return Pickup(m, manifestPath);
        if (m.Mode == "MUSIC") return Music(m, manifestPath);
        return Encode(m, manifestPath, reuse);
    }

    // ---- the picture chain ---------------------------------------------------
    // Footage does not arrive in the shape of the screen. 640x400 is 16:10; a
    // 16:9 source has to lose something or gain something, and which one is a
    // framing decision, not a technical one - so FIT says it out loud in the
    // manifest.
    //
    //   crop     fill the screen, lose a little from the sides
    //   pad      keep the whole frame, black bars top and bottom
    //   stretch  fill the screen and distort - almost never right
    //
    // PAD is nearly free in this codec, which is worth knowing before
    // choosing: a black bar is uniform, so it costs two bytes a block on the
    // keyframe and is skipped in every frame after it.
    //
    // A PICKUP may reserve a PANEL band at the bottom of the screen for the
    // things' slots: then the picture is fitted into the rows above it and
    // the band is padded on below, dark, with the panel art (PANELART) laid
    // into it when there is any - so the room's one frame already holds the
    // panel's backing and the game restores under a taken thing and under the
    // slots from the same place.
    const string PANEL_FILL = "0x101018";

    static string FitChain(Manifest m)
    {
        int rh = m.Height - m.PanelHeight;
        string fit = m.Fit.ToLowerInvariant() switch
        {
            "pad" => $"scale={m.Width}:{rh}:force_original_aspect_ratio=decrease:flags=lanczos," +
                     $"pad={m.Width}:{rh}:(ow-iw)/2:(oh-ih)/2:color=black",
            "stretch" => $"scale={m.Width}:{rh}:flags=lanczos",
            _ => $"scale={m.Width}:{rh}:force_original_aspect_ratio=increase:flags=lanczos," +
                 $"crop={m.Width}:{rh}",
        };
        if (m.PanelHeight > 0) fit += $",pad={m.Width}:{m.Height}:0:0:color={PANEL_FILL}";
        return fit;
    }

    // The whole labelled picture graph: input 0 through `scale`, and the panel
    // art from input `panelInput` scaled into the band and laid over it. Ends
    // in `outLabel`, ready for palettegen or paletteuse to be chained on.
    static string PictureGraph(Manifest m, string scale, int panelInput, string outLabel)
    {
        if (m.PanelArt == "" || m.PanelHeight == 0) return $"[0:v]{scale}{outLabel}";
        return $"[0:v]{scale}[room];[{panelInput}:v]scale={m.Width}:{m.PanelHeight}:flags=lanczos[pnl];" +
               $"[room][pnl]overlay=0:{m.Height - m.PanelHeight}{outLabel}";
    }

    static string PanelInput(Manifest m, string baseDir)
        => m.PanelArt == "" || m.PanelHeight == 0 ? "" : $" -i \"{Path.GetFullPath(Path.Combine(baseDir, m.PanelArt))}\"";

    // One clip (or one still) from one source, with its own palette - or
    // with the palette handed in, when the still is the background of a
    // PICKUP and the things placed on it must share its colours.
    static int Encode(Manifest m, string manifestPath, bool reuse)
    {
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

            // FIT, and the PANEL band if the manifest reserves one - see
            // FitChain above.
            string fit = FitChain(m);
            string panelIn = PanelInput(m, baseDir);
            // A still is a one-frame OWV, and it comes from an image. The fps
            // filter on a single image yields NOTHING - a picture has no
            // duration to sample at twelve a second - so for an image the
            // chain has no fps stage and the output is capped at one frame.
            // Found the first time the desk asked for a still: 806 bytes,
            // zero frames, and a player with nothing to show.
            bool imageSource = new[] { ".png", ".jpg", ".jpeg", ".bmp" }
                .Contains(Path.GetExtension(source).ToLowerInvariant());
            string scale = (imageSource ? "" : $"fps={m.Fps},") + fit + denoise;
            string oneFrame = imageSource ? " -frames:v 1" : "";
            if (imageSource && m.AudioRate > 0)
            {
                Console.WriteLine("source    is an image - no audio, one frame");
                m.AudioRate = 0;
            }

            // One palette for the whole clip. stats_mode=full reads every
            // frame, so a scene that darkens does not drag the palette after
            // it and then swim when it comes back.
            if (m.Palette != null) File.Copy(m.Palette, palPng, true);          // shared with the things on top of it
            else if (!Run(ffmpeg, $"-y -v error -i \"{source}\"{panelIn} " +
                                  $"-lavfi \"{PictureGraph(m, scale, 1, "[pic]")};[pic]palettegen=stats_mode=full\" \"{palPng}\"")) return 1;

            // paletteuse needs its two inputs wired by hand. Left implicit,
            // the palette is fed into the head of the chain instead and
            // ffmpeg stops with "Palette input must contain exactly 256
            // pixels" - which is the good case; the bad case is a filter
            // graph that quietly does something else. The panel art, when
            // there is one, is input 2 here and input 1 above.
            if (!Run(ffmpeg, $"-y -v error -i \"{source}\" -i \"{palPng}\"{panelIn} " +
                             $"-lavfi \"{PictureGraph(m, scale, 2, "[x]")};[x][1:v]paletteuse=dither={m.Dither}\"{oneFrame} " +
                             $"-f rawvideo -pix_fmt pal8 \"{framesRaw}\"")) return 1;

            if (!Run(ffmpeg, $"-y -v error -i \"{palPng}\" -f rawvideo -pix_fmt rgba \"{palRaw}\"")) return 1;

            if (m.AudioRate > 0)
            {
                // SIXTEEN BITS, by default. Eight-bit sound hisses, and it is
                // the bits, not the card: measured on the same clip, the
                // quiet passages sit at -49 dBFS after the compressor whether
                // dithered or not, because one step of an 8-bit DAC is -42 dB
                // and the quantisation noise lands just under that. Sixteen
                // bits puts the floor 48 dB lower, the Sound Blaster 16 plays
                // them, and the sound costs 44 KB/s against a megabyte a
                // second of picture. AUDIOBITS = 8 is still here for a file
                // meant for an older card, and then everything below applies:
                //
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
                string chain = m.AudioBits == 16
                    ? $"{af}aresample=osr={m.AudioRate}:osf=s16:dither_method=triangular"
                    : $"{af}aresample=osr={m.AudioRate}:osf=u8:dither_method=triangular_hp";
                if (!Run(ffmpeg, $"-y -v error -i \"{source}\" -ac 1 -af \"{chain}\" " +
                                 $"-f {(m.AudioBits == 16 ? "s16le" : "u8")} -ar {m.AudioRate} \"{audioRaw}\"")) return 1;
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
        int bps = m.AudioBits / 8;                    // bytes per sample
        if (audio.Length > 0)
            Console.WriteLine($"audio     {audio.Length} bytes, {m.AudioRate} Hz mono {m.AudioBits}-bit ({audio.Length / (double)bps / m.AudioRate:F2} s)");

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
                    // sample boundaries, then bytes - a 16-bit chunk is never
                    // cut through the middle of a word
                    int from = (int)((long)i * m.AudioRate / m.Fps) * bps;
                    int to = (int)((long)(i + 1) * m.AudioRate / m.Fps) * bps;
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
        // Written beside the target, then put in its place - so a player that
        // has the old file open sees either the old one or the new, never a
        // half. On Windows a reader that allowed FILE_SHARE_DELETE does not
        // stop the old file being RENAMED, but the name stays taken until the
        // reader lets go, and "replace" fails with access denied; so the old
        // file is moved aside under another name, deleted from there (it
        // goes when the last reader closes), and the new one takes the name.
        // A reader that allowed nothing still wins; then say so in one line.
        string tmp = output + ".tmp";
        try
        {
            using (var os = File.Create(tmp))
            {
                WriteHeaderAndChunks(os, hdrOf(), chunks);
            }
            if (File.Exists(output))
            {
                string aside = $"{output}.{DateTime.UtcNow.Ticks:x}.old";
                File.Move(output, aside);
                try { File.Delete(aside); } catch { }
            }
            File.Move(tmp, output);
        }
        catch (Exception ex) when (ex is IOException || ex is UnauthorizedAccessException)
        {
            Console.Error.WriteLine($"FAILED: cannot write {output} - it is held open by another program, " +
                                    $"probably a player. ({ex.Message})");
            try { File.Delete(tmp); } catch { }
            return 3;
        }

        stats.Report(output, frameCount, m.Fps, maxChunk);
        return 0;

        byte[] hdrOf()
        {
            var hdr = new byte[HEADER_SIZE];
            Encoding.ASCII.GetBytes("OWV1").CopyTo(hdr, 0);
            PutU16(hdr, 4, w);
            PutU16(hdr, 6, h);
            hdr[8] = (byte)m.Fps;
            hdr[9] = (byte)(audio.Length > 0 ? (m.AudioBits == 16 ? 3 : 1) : 0);   // bit 0 has audio, bit 1 16-bit
            PutU16(hdr, 10, frameCount);
            PutU16(hdr, 12, audio.Length > 0 ? m.AudioRate : 0);
            PutU32(hdr, 16, (uint)maxChunk);
            PutU32(hdr, 20, 0);                       // no index
            palette.CopyTo(hdr, 32);
            return hdr;
        }
    }

    static void WriteHeaderAndChunks(Stream os, byte[] hdr, List<byte[]> chunks)
    {
        os.Write(hdr, 0, hdr.Length);
        foreach (var c in chunks) os.Write(c, 0, c.Length);
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
    //  PICKUP - a still with things in it that can be clicked away.
    //
    //  The manifest names EMPTY (the room without the things), FULL (with
    //  them - only the palette comes from it, so the things get their own
    //  colours) and one ITEM line per thing: where it sits in the SOURCE
    //  picture, and its cut-out with alpha. Out come:
    //
    //      BG.OWV        the empty room, one frame, the shared palette - and,
    //                    when the manifest reserves a PANEL band, the panel's
    //                    backing in the rows below the room
    //      <NAME>.SPR    each thing, scaled and cropped exactly as the room
    //                    was, in the same palette, with index 255 meaning
    //                    "not there" - and where it stands ON SCREEN in the
    //                    header, so the game never scales anything.
    //      <NAME>.SLT    the same thing at slot size, for the panel: the game
    //                    draws its outline while the thing is still in the
    //                    room and the picture itself once it is taken. Same
    //                    format; the position is the slot's, worked out here
    //                    so that the desk and the game agree by construction.
    //
    //  The .SPR / .SLT file:
    //      +0   'OWS1'
    //      +4   word  width          +6  word  height
    //      +8   int16 x on screen    +10 int16 y on screen
    //      +12  byte  the transparent index (255)
    //      +13  3 bytes zero
    //      +16  width*height palette indices, row by row
    // ========================================================================
    // The slots: a cell per thing, centred as a row in the band; the icon
    // fits a box inside the cell. Sixteen things at 640 wide still get 40
    // pixels each.
    public const int SLOT_CELL = 88, SLOT_W = 72, SLOT_H = 48;

    public static (int x, int y, int cell) SlotAt(int index, int count, int width, int height, int panelH, int w, int h)
    {
        int cell = Math.Min(SLOT_CELL, width / Math.Max(1, count));
        int x0 = (width - count * cell) / 2;
        return (x0 + index * cell + (cell - w) / 2, height - panelH + (panelH - h) / 2, cell);
    }

    static int Pickup(Manifest m, string manifestPath)
    {
        string baseDir = Path.GetDirectoryName(manifestPath)!;
        string outDir = Path.GetFullPath(Path.Combine(baseDir, m.OutDir));
        string work = Path.Combine(outDir, "frames");
        Directory.CreateDirectory(work);
        string empty = Path.GetFullPath(Path.Combine(baseDir, m.Empty));
        string full = m.Full == "" ? empty : Path.GetFullPath(Path.Combine(baseDir, m.Full));
        if (!File.Exists(empty)) { Console.Error.WriteLine($"EMPTY not found: {empty}"); return 2; }
        if (!File.Exists(full)) { Console.Error.WriteLine($"FULL not found: {full}"); return 2; }
        if (m.PanelArt != "" && !File.Exists(Path.GetFullPath(Path.Combine(baseDir, m.PanelArt))))
        { Console.Error.WriteLine($"PANELART not found: {m.PanelArt}"); return 2; }
        if (m.PanelHeight < 0 || m.PanelHeight >= m.Height || m.PanelHeight % BLOCK != 0)
        { Console.Error.WriteLine($"PANEL must be a multiple of {BLOCK} below the height, not {m.PanelHeight}"); return 2; }
        string ffmpeg = FindFfmpeg();
        if (ffmpeg == null) { Console.Error.WriteLine("ffmpeg not found. Put it on PATH or set FFMPEG to its full path."); return 2; }

        var (sw, sh) = ImageSize(empty);
        if (sw == 0) { Console.Error.WriteLine($"cannot read the size of {empty}"); return 2; }
        int rh = m.Height - m.PanelHeight;                    // the rows the room gets
        Console.WriteLine($"manifest  {manifestPath}");
        Console.WriteLine($"pickup    {sw}x{sh} -> {m.Width}x{rh}, fit {m.Fit}, {m.Items.Count} item(s)" +
                          (m.PanelHeight > 0 ? $", panel {m.PanelHeight} below" + (m.PanelArt != "" ? $" ({Path.GetFileName(m.PanelArt)})" : " (no art: dark)") : ", no panel"));

        // How the room reaches the screen: a scale, and an offset. The
        // things go through the same two numbers, so they land where they
        // were placed.
        double sx, sy, ox, oy;
        switch (m.Fit.ToLowerInvariant())
        {
            case "stretch": sx = (double)m.Width / sw; sy = (double)rh / sh; ox = oy = 0; break;
            case "pad": sx = sy = Math.Min((double)m.Width / sw, (double)rh / sh); ox = (sw * sx - m.Width) / 2; oy = (sh * sy - rh) / 2; break;
            default: sx = sy = Math.Max((double)m.Width / sw, (double)rh / sh); ox = (sw * sx - m.Width) / 2; oy = (sh * sy - rh) / 2; break;
        }

        // the palette, from the picture that has everything in it - the
        // things AND the panel's backing, laid out exactly as the room is
        string fit = FitChain(m);
        string palPng = Path.Combine(work, "pickup-pal.png");
        if (!Run(ffmpeg, $"-y -v error -i \"{full}\"{PanelInput(m, baseDir)} " +
                         $"-lavfi \"{PictureGraph(m, fit, 1, "[pic]")};[pic]palettegen=stats_mode=full\" \"{palPng}\"")) return 1;

        // the room: a one-frame OWV through the ordinary path, palette given
        var bg = new Manifest
        {
            Source = empty, Output = Path.Combine(outDir, "BG.OWV"), Palette = palPng,
            Width = m.Width, Height = m.Height, Fps = m.Fps, KeyEvery = m.KeyEvery, AudioRate = 0,
            Dither = m.Dither, Denoise = "", Fit = m.Fit, Tolerance = m.Tolerance, Search = m.Search, CopySearch = m.CopySearch, Copy = m.Copy,
            PanelHeight = m.PanelHeight, PanelArt = m.PanelArt == "" ? "" : Path.GetFullPath(Path.Combine(baseDir, m.PanelArt)),
        };
        int rc = Encode(bg, Path.Combine(outDir, "PICKUP.INF"), false);
        if (rc != 0) return rc;

        // the things: each scaled by the room's factor, quantised to the
        // room's palette, alpha below half -> the reserved index; and each
        // again at slot size, into its slot
        int index = 0;
        foreach (var it in m.Items)
        {
            string layer = Path.GetFullPath(Path.Combine(baseDir, it.Layer));
            if (!File.Exists(layer)) { Console.Error.WriteLine($"FAILED: layer not found for {it.Name}: {layer}"); return 2; }
            var (lw, lh) = ImageSize(layer);
            int w = Math.Max(1, (int)Math.Round(lw * sx)), h = Math.Max(1, (int)Math.Round(lh * sy));
            int gx = (int)Math.Round(it.X * sx - ox), gy = (int)Math.Round(it.Y * sy - oy);
            var data = Quantise(ffmpeg, layer, palPng, m.Dither, w, h, Path.Combine(work, it.Name + ".raw"));
            if (data == null) return 1;
            int seen = WriteOws(Path.Combine(outDir, it.Name + ".SPR"), w, h, gx, gy, data);
            Console.WriteLine($"  item      {it.Name,-8} {w,4}x{h,-4} at {gx,4},{gy,-4} on screen   {seen * 100 / Math.Max(1, w * h),3}% opaque   ({Path.GetFileName(it.Layer)} at {it.X},{it.Y})");

            if (m.PanelHeight > 0)
            {
                double f = Math.Min(Math.Min((double)SLOT_W / lw, (double)SLOT_H / lh), 1.0);
                int iw = Math.Max(1, (int)Math.Round(lw * f)), ih = Math.Max(1, (int)Math.Round(lh * f));
                var (ix, iy, _) = SlotAt(index, m.Items.Count, m.Width, m.Height, m.PanelHeight, iw, ih);
                var icon = Quantise(ffmpeg, layer, palPng, m.Dither, iw, ih, Path.Combine(work, it.Name + "-slot.raw"));
                if (icon == null) return 1;
                WriteOws(Path.Combine(outDir, it.Name + ".SLT"), iw, ih, ix, iy, icon);
                Console.WriteLine($"  slot      {it.Name,-8} {iw,4}x{ih,-4} at {ix,4},{iy,-4}");
            }
            index++;
        }
        Console.WriteLine($"  wrote     BG.OWV and {m.Items.Count} sprite(s){(m.PanelHeight > 0 ? " with their slots" : "")} into {outDir}");
        return 0;
    }

    // A layer with alpha, scaled to w x h and quantised to the palette:
    // w*h indices, 255 where the alpha is below half. Null on failure.
    static byte[] Quantise(string ffmpeg, string layer, string palPng, string dither, int w, int h, string raw)
    {
        if (!Run(ffmpeg, $"-y -v error -i \"{layer}\" -i \"{palPng}\" " +
                         $"-lavfi \"format=rgba,scale={w}:{h}:flags=lanczos[x];[x][1:v]paletteuse=dither={dither}:alpha_threshold=128\" " +
                         $"-frames:v 1 -f rawvideo -pix_fmt pal8 \"{raw}\"")) return null;
        var data = File.ReadAllBytes(raw);
        if (data.Length != w * h && data.Length != w * h + 1024)
        { Console.Error.WriteLine($"FAILED: {Path.GetFileName(raw)}: {data.Length} bytes for {w}x{h}"); return null; }
        return data;
    }

    // An OWS1 file. Returns how many pixels are not the transparent index.
    static int WriteOws(string path, int w, int h, int x, int y, byte[] data)
    {
        var spr = new byte[16 + w * h];
        Encoding.ASCII.GetBytes("OWS1").CopyTo(spr, 0);
        PutU16(spr, 4, w); PutU16(spr, 6, h);
        PutU16(spr, 8, x & 0xFFFF); PutU16(spr, 10, y & 0xFFFF);
        spr[12] = 255;
        Array.Copy(data, 0, spr, 16, w * h);
        int seen = 0; for (int i = 0; i < w * h; i++) if (data[i] != 255) seen++;
        File.WriteAllBytes(path, spr);
        return seen;
    }

    // ========================================================================
    //  MUSIC - a track for a scene. Sixteen-bit mono PCM that the engine pours
    //  into the same queue the clips use: on its own while the room is on
    //  the screen, and mixed under the clip's sound while a clip plays. The
    //  file has a sixteen-byte header, because raw PCM with no rate written
    //  down is a trap, and a WAV header is forty-four bytes of chunk parsing
    //  the engine has no reason to learn:
    //
    //      +0   'OWA1'
    //      +4   word   rate, Hz        +6   byte  bits per sample, 16
    //      +7   byte   zero            +8   dword samples
    //      +12  dword  zero
    //      +16  the samples, signed little-endian words
    //
    //  The track is meant to LOOP - the engine rewinds at the end - so a
    //  source that already loops cleanly is the one to give it. No
    //  compressor by default: that chain is for speech.
    // ========================================================================
    static int Music(Manifest m, string manifestPath)
    {
        string baseDir = Path.GetDirectoryName(manifestPath)!;
        string work = Path.Combine(baseDir, "frames");
        Directory.CreateDirectory(work);
        string source = Path.GetFullPath(Path.Combine(baseDir, m.Source));
        string output = Path.GetFullPath(Path.Combine(baseDir, m.Output));
        string raw = Path.Combine(work, Path.GetFileNameWithoutExtension(output) + ".raw");
        if (!File.Exists(source)) { Console.Error.WriteLine($"music source not found: {source}"); return 2; }
        string ffmpeg = FindFfmpeg();
        if (ffmpeg == null) { Console.Error.WriteLine("ffmpeg not found. Put it on PATH or set FFMPEG to its full path."); return 2; }
        int rate = m.AudioRate > 0 ? m.AudioRate : 22050;
        if (m.AudioBits != 16) Console.WriteLine("music     is always sixteen-bit: the engine mixes words, AUDIOBITS ignored");

        Console.WriteLine($"manifest  {manifestPath}");
        Console.WriteLine($"source    {source}");
        Console.WriteLine($"output    {output}");
        string af = m.AudioFilterGiven && m.AudioFilter.Length > 0 ? m.AudioFilter + "," : "";
        string vol = Math.Abs(m.Volume - 1.0) > 0.0005 ? $"volume={m.Volume.ToString("0.###", System.Globalization.CultureInfo.InvariantCulture)}," : "";
        string chain = $"{af}{vol}aresample=osr={rate}:osf=s16:dither_method=triangular";
        if (!Run(ffmpeg, $"-y -v error -i \"{source}\" -vn -ac 1 -af \"{chain}\" -f s16le -ar {rate} \"{raw}\"")) return 1;

        var pcm = File.ReadAllBytes(raw);
        if (pcm.Length < 2) { Console.Error.WriteLine("FAILED: no samples came out of the source"); return 1; }
        var hdr = new byte[16];
        Encoding.ASCII.GetBytes("OWA1").CopyTo(hdr, 0);
        PutU16(hdr, 4, rate); hdr[6] = 16; hdr[7] = 0;
        PutU32(hdr, 8, (uint)(pcm.Length / 2)); PutU32(hdr, 12, 0);
        string tmp = output + ".tmp";
        try
        {
            using (var os = File.Create(tmp)) { os.Write(hdr, 0, 16); os.Write(pcm, 0, pcm.Length); }
            if (File.Exists(output))
            {
                string aside = $"{output}.{DateTime.UtcNow.Ticks:x}.old";
                File.Move(output, aside);
                try { File.Delete(aside); } catch { }
            }
            File.Move(tmp, output);
        }
        catch (Exception ex) when (ex is IOException || ex is UnauthorizedAccessException)
        {
            Console.Error.WriteLine($"FAILED: cannot write {output} - it is held open by another program. ({ex.Message})");
            try { File.Delete(tmp); } catch { }
            return 3;
        }
        Console.WriteLine($"  wrote     {Path.GetFileName(output)}  {pcm.Length + 16:N0} bytes");
        Console.WriteLine($"  duration  {pcm.Length / 2.0 / rate:F2} s   {rate} Hz mono 16-bit" + (vol != "" ? $"   volume {m.Volume}" : "") + (af != "" ? $"   filter {m.AudioFilter}" : ""));
        return 0;
    }

    // Width and height from the file's own header - PNG, JPEG, BMP. Enough
    // to place things; ffmpeg does the real decoding.
    static (int w, int h) ImageSize(string path)
    {
        using var fs = File.OpenRead(path);
        var b = new byte[32];
        int n = fs.Read(b, 0, 32);
        if (n >= 24 && b[0] == 0x89 && b[1] == 'P' && b[2] == 'N' && b[3] == 'G')
            return ((b[16] << 24) | (b[17] << 16) | (b[18] << 8) | b[19], (b[20] << 24) | (b[21] << 16) | (b[22] << 8) | b[23]);
        if (n >= 26 && b[0] == 'B' && b[1] == 'M')
            return (BitConverter.ToInt32(b, 18), Math.Abs(BitConverter.ToInt32(b, 22)));
        if (n >= 4 && b[0] == 0xFF && b[1] == 0xD8)
        {
            fs.Seek(2, SeekOrigin.Begin);
            var mk = new byte[4];
            while (fs.Read(mk, 0, 4) == 4)
            {
                if (mk[0] != 0xFF) break;
                int marker = mk[1], len = (mk[2] << 8) | mk[3];
                if (marker >= 0xC0 && marker <= 0xCF && marker != 0xC4 && marker != 0xC8 && marker != 0xCC)
                {
                    var sof = new byte[5];
                    if (fs.Read(sof, 0, 5) != 5) break;
                    return ((sof[3] << 8) | sof[4], (sof[1] << 8) | sof[2]);
                }
                fs.Seek(len - 2, SeekOrigin.Current);
            }
        }
        return (0, 0);
    }

    // ========================================================================
    class Manifest
    {
        public string Source = "", Output = "";
        public string Mode = "VIDEO";                 // or PICKUP, or MUSIC
        public string Palette;                        // a pal.png to use instead of making one
        public string Empty = "", Full = "", OutDir = ".";
        public List<PickItem> Items = new();
        public int PanelHeight = 0;                   // PICKUP: rows reserved below the room for the slots
        public string PanelArt = "";                  // PICKUP: a picture laid into that band, or nothing (dark)
        public double Volume = 1.0;                   // MUSIC: a gain before the resample
        public bool AudioFilterGiven;                 // MUSIC: whether AUDIOFILTER was in the file at all
        public int Width = 640, Height = 400, Fps = 12, KeyEvery = 48;
        public int AudioRate = 22050, Search = 24, CopySearch = 4;
        public int AudioBits = 16;                    // 16 for the SB16; 8 for older cards, and it hisses
        public string Dither = "bayer:bayer_scale=3";
        public string Denoise = "";
        public string Fit = "crop";
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
                    case "AUDIOBITS":
                        m.AudioBits = int.Parse(v);
                        if (m.AudioBits != 8 && m.AudioBits != 16) throw new InvalidDataException("AUDIOBITS is 8 or 16");
                        break;
                    case "DITHER": m.Dither = v; break;
                    case "DENOISE": m.Denoise = v.Equals("off", StringComparison.OrdinalIgnoreCase) ? "" : v; break;
                    case "AUDIOFILTER": m.AudioFilter = v.Equals("none", StringComparison.OrdinalIgnoreCase) ? "" : v; m.AudioFilterGiven = true; break;
                    case "PANEL": m.PanelHeight = int.Parse(v); break;
                    case "PANELART": m.PanelArt = v; break;
                    case "VOLUME": m.Volume = double.Parse(v, System.Globalization.CultureInfo.InvariantCulture); break;
                    case "FIT": m.Fit = v; break;
                    case "TOLERANCE": m.Tolerance = int.Parse(v); break;
                    case "SEARCH": m.Search = int.Parse(v); break;
                    case "COPYSEARCH": m.CopySearch = int.Parse(v); break;
                    case "COPY": m.Copy = v.Equals("on", StringComparison.OrdinalIgnoreCase); break;
                    case "MODE": m.Mode = v.ToUpperInvariant(); break;
                    case "EMPTY": m.Empty = v; break;
                    case "FULL": m.Full = v; break;
                    case "OUTDIR": m.OutDir = v; break;
                    default:
                        // ITEM NAME = x,y layer.png
                        if (k.StartsWith("ITEM "))
                        {
                            var parts = v.Split(' ', 2, StringSplitOptions.RemoveEmptyEntries);
                            var xy = parts[0].Split(',');
                            if (parts.Length < 2 || xy.Length != 2) throw new InvalidDataException("ITEM wants: NAME = x,y layer.png");
                            m.Items.Add(new PickItem { Name = k.Substring(5).Trim(), X = int.Parse(xy[0]), Y = int.Parse(xy[1]), Layer = parts[1].Trim() });
                        }
                        break;
                }
            }
            if (m.Mode == "PICKUP") { if (m.Empty == "") throw new InvalidDataException("a PICKUP manifest needs EMPTY"); }
            else if (m.Source == "" || m.Output == "") throw new InvalidDataException("manifest needs SOURCE and OUTPUT");
            if (m.PanelHeight % BLOCK != 0) throw new InvalidDataException($"PANEL must be a multiple of {BLOCK}");
            if (m.Width % BLOCK != 0 || m.Height % BLOCK != 0)
                throw new InvalidDataException($"width and height must be multiples of {BLOCK}");
            return m;
        }
    }

    class PickItem { public string Name = "", Layer = ""; public int X, Y; }

    class Stats
    {
        public int KeyFrames, DeltaFrames, PannedFrames;
        public long KeyBytes, DeltaBytes, AudioBytes, RleBytes;
        public long Skip, SkipOps, Fill, Copy, Literal, Rle;

        public void Report(string output, int frames, int fps, int maxChunk)
        {
            long total = new FileInfo(output).Length;
            double seconds = Math.Max(frames, 1) / (double)fps;   // a still is one frame, not zero time
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
