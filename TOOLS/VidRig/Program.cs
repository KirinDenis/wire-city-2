// ---------------------------------------------------------------------------
//  VidRig - the retro-card preview rig for OWL FLY III (Skill\VIDTASK.md).
//
//  The house rule: palettes are picked BY EYE, not argued in the abstract.
//  This tool takes a real captured VGA frame (320x200 PNG) plus the game's
//  own PALDAY table (parsed straight out of SRC\UI.INC, PALPNL.INC and all,
//  so the numbers can never drift from the source), reconstructs the
//  palette-index image, and renders what each proposed converter would
//  put on the glass:
//
//    CGA   mode 4:  both hardware palettes, black and blue backgrounds,
//                   flat nearest-colour and 2x2 ordered dither
//    EGA   mode 0D: 16 colours greedily picked from EGA's 64 to cover the
//                   game's table (weighted by how often the frame uses
//                   each entry), flat and dithered
//    HGC   720x348: mono, 320->640 doubled, 200->300 two-rows-into-three,
//                   letterboxed, 4x4 ordered dither on luminance
//
//  The same tables it computes here (256->N lookup, 2x2 dither pairs) are
//  the ones the DOS converters will carry, so once a palette is picked
//  this rig doubles as the oracle: the game's screenshot must match the
//  rig's prediction.
//
//    dotnet run --project TOOLS\VidRig -c Release -- <frame.png> <ui.inc> <outdir>
// ---------------------------------------------------------------------------

using System.Text;
using System.IO.Compression;

class Program
{
    const int W = 320, H = 200;

    // The curated EGA sixteen, as 2-bit guns 0..3 (multiply by 85 for
    // RGB). Edit HERE and re-run - this table is the whole palette
    // discussion. Families, in order: the blues (five steps, sky and
    // depth), the greens (three, terrain), rock brown, the cool panel
    // pair (blue-greys, not neutral - the mood lives in that tint),
    // teal (water), then black, white, lamp red, legend amber.
    static readonly int[][] EGA16 = {
        new[]{0,0,0},   // black
        new[]{0,0,1},   // abyss blue - the night under everything
        new[]{0,1,2},   // deep sky
        new[]{0,2,3},   // sky
        new[]{1,2,3},   // pale sky
        new[]{2,3,3},   // haze at the horizon
        new[]{0,1,0},   // forest
        new[]{1,2,1},   // grass
        new[]{1,3,1},   // bright green (IFF, lit fields)
        new[]{2,1,0},   // rock brown
        new[]{1,1,1},   // panel shadow - NEUTRAL grey (the pilot: no
        new[]{2,2,2},   // panel plate  - azure, no purple on the panel;
                        // EGA hardware owns exactly TWO pure greys
                        // between black and white, so the panel ladder
                        // is black -> 111 -> 222 -> white)
        new[]{0,2,2},   // teal - the water
        new[]{3,0,0},   // lamp red
        new[]{3,2,0},   // legend amber
        new[]{3,3,3},   // white
    };

    static int Main(string[] args)
    {
        if (args.Length >= 5 && args[0] == "panel")
            return RunPanel(args[1], args[2], args[3], args[4]);
        if (args.Length >= 5 && args[0] == "emit")
            return RunEmit(args[1], args[2], args[3], args[4]);
        if (args.Length < 3)
        {
            Console.WriteLine("usage: VidRig <frame.png 320x200> <path to UI.INC> <outdir>");
            Console.WriteLine("       VidRig panel <cockpit2_edit.png> <frame.png> <UI.INC> <outdir>");
            return 1;
        }
        string framePath = args[0], uiPath = args[1], outDir = args[2];
        Directory.CreateDirectory(outDir);

        // ---- the game's palette, from the source of truth ----
        var pal = ParsePal(uiPath, "PALDAY");
        Console.WriteLine($"PALDAY: {pal.Count} entries");
        var rgb = pal.Select(p => new[] { Dac(p[0]), Dac(p[1]), Dac(p[2]) }).ToArray();

        // ---- the frame, mapped back to palette indexes ----
        var img = Png.Load(framePath);
        if (img.W != W || img.H != H) throw new Exception($"{framePath}: need 320x200, got {img.W}x{img.H}");
        var idx = new byte[W * H];
        var hist = new int[pal.Count];
        for (int i = 0; i < W * H; i++)
        {
            int best = 0, bd = int.MaxValue;
            for (int c = 0; c < rgb.Length; c++)
            {
                int d = Dist(img.P[i * 3], img.P[i * 3 + 1], img.P[i * 3 + 2], rgb[c][0], rgb[c][1], rgb[c][2]);
                if (d < bd) { bd = d; best = c; }
            }
            idx[i] = (byte)best; hist[best]++;
        }

        // ---- CGA: the two hardware palettes, two backgrounds ----
        int[][] CGA = {                       // the full CGA 16 for reference
            new[]{0,0,0},    new[]{0,0,170},   new[]{0,170,0},   new[]{0,170,170},
            new[]{170,0,0},  new[]{170,0,170}, new[]{170,85,0},  new[]{170,170,170},
            new[]{85,85,85}, new[]{85,85,255}, new[]{85,255,85}, new[]{85,255,255},
            new[]{255,85,85},new[]{255,85,255},new[]{255,255,85},new[]{255,255,255}
        };
        var variants = new (string name, int[] set)[] {
            // THE PICK (2026-08-18): the pilot asked for cyan/white/red -
            // that is CGA's third palette, mode 5 / colour burst off:
            // cyan, red, white. It exists in hardware and games shipped
            // on it; the two textbook palettes stay for comparison.
            ("cga_cyanred_black", new[]{0, 11, 12, 15}), // mode 5 intense
            ("cga_cyan_black",  new[]{0, 11, 13, 15}),   // pal 1 intense, black bg
            ("cga_green_black", new[]{0, 10, 12, 14}),   // pal 0 intense, black bg
        };
        foreach (var (name, set) in variants)
        {
            var cols = set.Select(c => CGA[c]).ToArray();
            Emit(outDir, name + "_flat", idx, rgb, cols, dither: false);
            Emit(outDir, name + "_dith", idx, rgb, cols, dither: true);
        }

        // ---- EGA: 16 of 64, CURATED (2026-08-18, the pilot's verdict on
        // the greedy set: "неприятный серый и жёлтый, нет загадочности").
        // The machine optimised for coverage; the pilot asked for MOOD.
        // So: the yellows and flat greys are out, and their slots went to
        // SHADES - five steps of blue for the sky and the deep, cool
        // blue-greys for the panel instead of neutral grey, a teal for
        // the water. One amber survives for the legends, one red for the
        // lamps. And NO dither on EGA anywhere - his call - so the
        // families need their steps to band cleanly.
        var chosen = EGA16.Select(c => new[] { c[0] * 85, c[1] * 85, c[2] * 85 }).ToList();
        Console.WriteLine("EGA 16 (curated): " + string.Join(" ", EGA16.Select(c => $"{c[0]}{c[1]}{c[2]}")));
        // EGA is mode 10h, 640x350 (the pilot asked for EGA's best; that
        // IS its best - 640x480x16 is VGA's mode 12h, EGA never had it).
        // The picture rides 640x300 - width doubled, 2 rows into 3, the
        // same walk Hercules takes - letterboxed 25 lines top and bottom.
        // The dither phase keys on the OUTPUT pixel, so the checker
        // stays 1:1 on the glass instead of doubling with the picture.
        {
            var cols = chosen.ToArray();
            var lut = BuildLut(rgb, cols, dither: false);   // NO grids on EGA
            int EW = 640, EH = 350, eoy = (EH - 300) / 2;
            var ep = new byte[EW * EH * 3];
            for (int y = 0; y < 300; y++)
            {
                int sy = y * 2 / 3;
                for (int x = 0; x < EW; x++)
                {
                    int phase = (x & 1) + ((y & 1) << 1);
                    var c = cols[lut[idx[sy * W + (x >> 1)], phase]];
                    int o = ((y + eoy) * EW + x) * 3;
                    ep[o] = (byte)c[0]; ep[o + 1] = (byte)c[1]; ep[o + 2] = (byte)c[2];
                }
            }
            Png.Save(Path.Combine(outDir, "ega640_flat.png"), ep, EW, EH);
            Console.WriteLine("wrote ega640_flat.png");
        }

        // ---- Hercules: mono, doubled wide, 2 rows -> 3, letterboxed ----
        int[,] bayer = { { 0, 8, 2, 10 }, { 12, 4, 14, 6 }, { 3, 11, 1, 9 }, { 15, 7, 13, 5 } };
        var luma = rgb.Select(c => (c[0] * 77 + c[1] * 151 + c[2] * 28) >> 8).ToArray();
        int HW = 720, HH = 348, ox = (HW - 640) / 2, oy = (HH - 300) / 2;
        var hp = new byte[HW * HH * 3];
        for (int y = 0; y < 300; y++)
        {
            int sy = y * 2 / 3;                       // 2 source rows fill 3
            for (int x = 0; x < 640; x++)
            {
                int sx = x >> 1;
                int l = luma[idx[sy * W + sx]];
                // near-black and near-white go SOLID: a lone lit dot in a
                // dark cockpit reads as dirt on the glass, and this
                // project has fought lone pixels before (the minimap)
                bool on = l > 215 || (l >= 40 && l > (bayer[y & 3, x & 3] * 255 + 8) / 16);
                if (on)
                {
                    int o = ((y + oy) * HW + x + ox) * 3;
                    hp[o] = 224; hp[o + 1] = 224; hp[o + 2] = 208;   // P4 phosphor white
                }
            }
        }
        Png.Save(Path.Combine(outDir, "herc_dith.png"), hp, HW, HH);
        Console.WriteLine("wrote herc_dith.png");
        return 0;
    }

    // -----------------------------------------------------------------------
    //  The PANEL pass. The pilot's verdict on the straight conversion:
    //  "просто конвертированием не получится в лоб" - the photo panel
    //  dissolves into noise through a per-pixel table. He is right, and
    //  the fix costs the game nothing at runtime: the panel is STATIC,
    //  so it can be baked once, offline, with its eyes open:
    //
    //    1. Kuwahara smoothing - flat regions go flat, edges stay sharp
    //       (per-pixel: of the four quadrant windows, take the mean of
    //       the calmest one). This is what kills the photo grain.
    //    2. Meaning first: red lamps stay red, bright plates stay bright.
    //    3. Lines are RIDGES, not noise: a pixel clearly brighter than
    //       its neighbourhood is a bezel highlight - it snaps to the
    //       light colour so struts and diagonals come out as continuous
    //       1px strokes instead of dashed speckle. Darker-than-around
    //       snaps down, which keeps the panel seams black.
    //
    //  The world and the MFD glass stay per-pixel through the same LUT
    //  as ever - they are vector art and convert clean. The masks come
    //  from cockpit2_edit.png itself: pure white = viewport, the pure
    //  red/blue/green rectangles = the three screens.
    // -----------------------------------------------------------------------
    // load the panel, find the dynamic masks and screen boxes, smooth,
    // measure - shared by the preview pass and the DOS-data emitter so
    // the two can never disagree about what the bake looks like
    static void Prep(string panelPath, out byte[] smO, out int[] lumaO, out int[] lmeanO,
                     out bool[] dynO, out int[] bx0, out int[] by0, out int[] bx1, out int[] by1)
    {
        var pan = Png.Load(panelPath);
        if (pan.W != W || pan.H != H) throw new Exception($"{panelPath}: need 320x200");

        // dynamic pixels: the viewport and the three marked screens. The
        // markers are Paint's stock red/blue/green - probed, not guessed:
        // (237,28,36), (0,162,232), (34,177,76); the viewport pure white.
        var dyn = new bool[W * H];
        int[][] marks = { new[]{255,255,255}, new[]{237,28,36}, new[]{0,162,232}, new[]{34,177,76} };
        // bounding box per SCREEN marker (1..3) - the drawn bezel
        // rectangles hang off these
        bx0 = new int[4]; by0 = new int[4]; bx1 = new int[4]; by1 = new int[4];
        for (int m = 1; m < 4; m++) { bx0[m] = W; by0[m] = H; bx1[m] = -1; by1[m] = -1; }
        for (int y = 0; y < H; y++)
            for (int x = 0; x < W; x++)
            {
                int i = y * W + x;
                int r = pan.P[i * 3], g = pan.P[i * 3 + 1], b = pan.P[i * 3 + 2];
                for (int m = 0; m < 4; m++)
                {
                    int dr = r - marks[m][0], dg = g - marks[m][1], db = b - marks[m][2];
                    if (dr * dr + dg * dg + db * db < 2500)
                    {
                        dyn[i] = true;
                        if (m > 0)
                        {
                            bx0[m] = Math.Min(bx0[m], x); by0[m] = Math.Min(by0[m], y);
                            bx1[m] = Math.Max(bx1[m], x); by1[m] = Math.Max(by1[m], y);
                        }
                        break;
                    }
                }
            }

        Measure(pan.P, dyn, out smO, out lumaO, out lmeanO);
        dynO = dyn;
    }

    // Kuwahara + luminance + neighbourhood mean, on any 320x200 RGB -
    // the front panel and the two side consoles all pass through here
    static void Measure(byte[] rgbP, bool[] dyn, out byte[] smO, out int[] lumaO, out int[] lmeanO)
    {
        // 1. Kuwahara, radius 2: four 3x3 quadrants, mean of the calmest
        var sm = new byte[W * H * 3];
        for (int y = 0; y < H; y++)
            for (int x = 0; x < W; x++)
            {
                int i = y * W + x;
                if (dyn[i]) { Array.Copy(rgbP, i * 3, sm, i * 3, 3); continue; }
                double bestVar = double.MaxValue; int br = 0, bg = 0, bb = 0;
                for (int q = 0; q < 4; q++)
                {
                    int dx0 = (q & 1) == 0 ? -2 : 0, dy0 = (q & 2) == 0 ? -2 : 0;
                    long sr = 0, sg2 = 0, sb = 0, sl = 0, sl2 = 0; int n = 0;
                    for (int dy = dy0; dy <= dy0 + 2; dy++)
                        for (int dx = dx0; dx <= dx0 + 2; dx++)
                        {
                            int xx = Math.Clamp(x + dx, 0, W - 1), yy = Math.Clamp(y + dy, 0, H - 1);
                            int j = yy * W + xx;
                            if (dyn[j]) continue;
                            int rr = rgbP[j * 3], gg = rgbP[j * 3 + 1], bb2 = rgbP[j * 3 + 2];
                            int l = (rr * 77 + gg * 151 + bb2 * 28) >> 8;
                            sr += rr; sg2 += gg; sb += bb2; sl += l; sl2 += l * l; n++;
                        }
                    if (n == 0) continue;
                    double var_ = (double)sl2 / n - (double)(sl * sl) / n / n;
                    if (var_ < bestVar) { bestVar = var_; br = (int)(sr / n); bg = (int)(sg2 / n); bb = (int)(sb / n); }
                }
                sm[i * 3] = (byte)br; sm[i * 3 + 1] = (byte)bg; sm[i * 3 + 2] = (byte)bb;
            }

        // local mean luma, 7x7, panel pixels only - the ridge reference
        var luma = new int[W * H];
        for (int i = 0; i < W * H; i++) luma[i] = (sm[i * 3] * 77 + sm[i * 3 + 1] * 151 + sm[i * 3 + 2] * 28) >> 8;
        var lmean = new int[W * H];
        for (int y = 0; y < H; y++)
            for (int x = 0; x < W; x++)
            {
                long s = 0; int n = 0;
                for (int dy = -3; dy <= 3; dy++)
                    for (int dx = -3; dx <= 3; dx++)
                    {
                        int xx = Math.Clamp(x + dx, 0, W - 1), yy = Math.Clamp(y + dy, 0, H - 1);
                        int j = yy * W + xx;
                        if (dyn[j]) continue;
                        s += luma[j]; n++;
                    }
                lmean[y * W + x] = n > 0 ? (int)(s / n) : 0;
            }
        smO = sm; lumaO = luma; lmeanO = lmean;
    }

    static int RunPanel(string panelPath, string framePath, string uiPath, string outDir)
    {
        Directory.CreateDirectory(outDir);
        Prep(panelPath, out var sm, out var luma, out var lmean, out var dyn,
             out var bx0, out var by0, out var bx1, out var by1);

        // ---- the BANDS, the way 1988 drew it (the pilot's samples:
        // Falcon, F-16 CP, F-15 SE II). One classification serves every
        // card: 0 seam/black, 1 surface texture, 2 body plate, 3 bezel
        // stroke, 4 lamp. Each card then dresses the bands in what it
        // has: CGA in cyan/accent/white, EGA in lifted greys, Hercules
        // in dither density.
        var band = PanelBands(sm, luma, lmean, dyn);
        var cgaPan = CgaFromBands(band);

        // ---- EGA-16 bake, from the one curated table (EGA16 above) ----
        var pal = ParsePal(uiPath, "PALDAY");
        var prgb = pal.Select(p => new[] { Dac(p[0]), Dac(p[1]), Dac(p[2]) }).ToArray();
        var egaCols = EGA16.Select(c => new[] { c[0] * 85, c[1] * 85, c[2] * 85 }).ToArray();
        var egaPan = EgaFromBands(band, dyn, bx0, by0, bx1, by1, egaCols);

        // ---- previews: the panel alone, and composed over the frame ----
        var frame = Png.Load(framePath);
        if (frame.W != W || frame.H != H) throw new Exception($"{framePath}: need 320x200");
        var fidx = new byte[W * H];
        for (int i = 0; i < W * H; i++)
        {
            int best = 0, bd = int.MaxValue;
            for (int c = 0; c < prgb.Length; c++)
            {
                int d = Dist(frame.P[i * 3], frame.P[i * 3 + 1], frame.P[i * 3 + 2], prgb[c][0], prgb[c][1], prgb[c][2]);
                if (d < bd) { bd = d; best = c; }
            }
            fidx[i] = (byte)best;
        }
        // both real CGA palettes wear the same bake - the pilot's samples
        // (Falcon, F-16 CP) fly palette 1's magenta, his earlier pick was
        // mode 5's red; colour 2 is the only difference, so show both
        int[][] cgaMode5 = { new[]{0,0,0}, new[]{85,255,255}, new[]{255,85,85},  new[]{255,255,255} };
        int[][] cgaPal1  = { new[]{0,0,0}, new[]{85,255,255}, new[]{255,85,255}, new[]{255,255,255} };
        var egaLut = BuildLut(prgb, egaCols, dither: false);   // NO grids on EGA - the pilot's call
        SavePanelComp(Path.Combine(outDir, "comp_cga_red.png"),     cgaPan, dyn, fidx, BuildLut(prgb, cgaMode5, true), cgaMode5);
        SavePanelComp(Path.Combine(outDir, "comp_cga_magenta.png"), cgaPan, dyn, fidx, BuildLut(prgb, cgaPal1, true),  cgaPal1);
        SavePanelComp(Path.Combine(outDir, "panel_ega.png"), egaPan, dyn, null, null, egaCols);
        SavePanelComp(Path.Combine(outDir, "comp_ega.png"), egaPan, dyn, fidx, egaLut, egaCols);

        // ---- Hercules from the same bands: dither DENSITY is the paint.
        // Seam off, texture a quarter, body half, strokes and lamps full -
        // and the world through the luminance Bayer as before.
        {
            int[,] bayer = { { 0, 8, 2, 10 }, { 12, 4, 14, 6 }, { 3, 11, 1, 9 }, { 15, 7, 13, 5 } };
            var lumaPal = prgb.Select(c => (c[0] * 77 + c[1] * 151 + c[2] * 28) >> 8).ToArray();
            int HW = 720, HH = 348, ox = (HW - 640) / 2, oy2 = (HH - 300) / 2;
            var hp = new byte[HW * HH * 3];
            for (int y = 0; y < 300; y++)
            {
                int sy = y * 2 / 3;
                for (int x = 0; x < 640; x++)
                {
                    int sx = x >> 1, i = sy * W + sx;
                    bool on;
                    if (dyn[i])
                    {
                        int l = lumaPal[fidx[i]];
                        on = l > 215 || (l >= 40 && l > (bayer[y & 3, x & 3] * 255 + 8) / 16);
                    }
                    else on = band[i] switch
                    {
                        1 => (x & 1) == 1 && (y & 1) == 1,     // texture: a quarter
                        2 => ((x ^ y) & 1) == 1,               // body: half
                        3 or 4 => true,                          // strokes and lamps burn
                        _ => false
                    };
                    if (on)
                    {
                        int o = ((y + oy2) * HW + x + ox) * 3;
                        hp[o] = 224; hp[o + 1] = 224; hp[o + 2] = 208;
                    }
                }
            }
            Png.Save(Path.Combine(outDir, "comp_herc.png"), hp, HW, HH);
            Console.WriteLine("wrote comp_herc.png");
        }
        return 0;
    }

    // colour bands tuned by eye against the 1988 samples; the checker is
    // baked positionally (x^y parity), so it ships as plain pixels
    // The pilot's art direction (2026-08-18): the EGA panel is DRAWN,
    // not converted - grey ladder only (black -> 111 -> 222 -> white,
    // the two greys being all EGA hardware owns between the ends),
    // no azure and no purple on an instrument, plate edges as real
    // LINES, and every screen wearing an explicit bezel rectangle.
    static byte[] EgaFromBands(byte[] band, bool[] dyn, int[] bx0, int[] by0, int[] bx1, int[] by1, int[][] egaCols)
    {
        int gDark = Nearest(new[] { 85, 85, 85 }, egaCols);
        int gLite = Nearest(new[] { 170, 170, 170 }, egaCols);
        int gWhit = Nearest(new[] { 255, 255, 255 }, egaCols);
        int gRed  = Nearest(new[] { 255, 80, 80 }, egaCols);
        var egaPan = new byte[W * H];
        for (int i = 0; i < W * H; i++)
        {
            if (dyn[i]) continue;
            egaPan[i] = band[i] switch
            {
                1 => (byte)gDark,       // surface: dark grey, FLAT
                2 => (byte)gLite,       // plates: light grey, FLAT
                3 => (byte)gWhit,       // bezel highlight: white stroke
                4 => (byte)gRed,        // lamps
                _ => (byte)0            // seams
            };
        }
        // a plate EDGE is a drawn line: where light plate meets dark
        // surface, the dark side goes black - the plates get outlines
        for (int y = 0; y < H; y++)
            for (int x = 0; x < W; x++)
            {
                int i = y * W + x;
                if (dyn[i] || band[i] != 1) continue;
                if ((x > 0 && band[i - 1] == 2) || (x < W - 1 && band[i + 1] == 2) ||
                    (y > 0 && band[i - W] == 2) || (y < H - 1 && band[i + W] == 2))
                    egaPan[i] = 0;
            }
        // the three screens wear DRAWN rectangles: the +1 ring is already
        // black (the rim in the bands), +2 is the white bezel, +3 black
        void Ring(int m, int o, byte col)
        {
            for (int x = bx0[m] - o; x <= bx1[m] + o; x++)
            {
                Put(x, by0[m] - o, col); Put(x, by1[m] + o, col);
            }
            for (int y = by0[m] - o; y <= by1[m] + o; y++)
            {
                Put(bx0[m] - o, y, col); Put(bx1[m] + o, y, col);
            }
            void Put(int x, int y, byte c)
            {
                if (x < 0 || x >= W || y < 0 || y >= H) return;
                int j = y * W + x;
                if (!dyn[j]) egaPan[j] = c;
            }
        }
        for (int m = 1; m < 4; m++)
        {
            if (bx1[m] < 0) continue;
            Ring(m, 2, (byte)gWhit);
            Ring(m, 3, 0);
        }
        return egaPan;
    }

    // bands to CGA colours: 0 black, 1 body cyan, 2 accent, 3 white
    static byte[] CgaFromBands(byte[] band)
    {
        var cgaPan = new byte[W * H];
        for (int y = 0; y < H; y++)
            for (int x = 0; x < W; x++)
            {
                int i = y * W + x;
                cgaPan[i] = band[i] switch
                {
                    1 => (byte)(((x ^ y) & 1) != 0 ? 1 : 0),   // texture: checker
                    2 => (byte)1,                                // body: solid colour
                    3 => (byte)3,                                // stroke: white
                    4 => (byte)2,                                // lamp: the accent
                    _ => (byte)0
                };
            }
        return cgaPan;
    }

    // -----------------------------------------------------------------------
    //  RunEmit - the DOS-facing data, byte for byte what the game ships:
    //
    //    <srcDir>\VIDLUT.INC   the 256x4 lookup, day then night, values
    //                          0..3 (CGA mode 5: black cyan red white),
    //                          eight 256-byte tables, 512-ALIGNED so the
    //                          blit toggles phase with "xor bh,1"
    //    <installDir>\CPCGA.DAT  the baked panel, 4 pixels a byte MSB
    //                          first, 80 bytes a row, 16000 bytes
    //
    //  The blit's rule for WHICH pixel is static needs no mask and ships
    //  in no file: a pixel whose bufseg byte equals the panel artwork's
    //  byte at that position is the artwork, everything else - MFD
    //  contents, lamps, digits, the whole viewport, the splash - differs
    //  from it and converts through the lookup. The artwork to compare
    //  against is already in the game's memory: resseg:pimgo.
    // -----------------------------------------------------------------------
    static int RunEmit(string panelPath, string uiPath, string srcDir, string installDir)
    {
        Prep(panelPath, out var sm, out var luma, out var lmean, out var dyn,
             out var bx0, out var by0, out var bx1, out var by1);
        var band = PanelBands(sm, luma, lmean, dyn);
        var cgaPan = CgaFromBands(band);

        var packed = new byte[16000];
        for (int i = 0; i < W * H; i++)
            packed[i >> 2] |= (byte)(cgaPan[i] << ((3 - (i & 3)) * 2));
        File.WriteAllBytes(Path.Combine(installDir, "CPCGA.DAT"), packed);
        Console.WriteLine("wrote CPCGA.DAT (16000 bytes)");

        // ---- the Hercules bake: per pixel a 2-bit DENSITY code from
        // the bands - 0 off (seams), 1 a quarter (texture), 2 half
        // (plates), 3 full (strokes and lamps) - four codes a byte,
        // MSB pixel first. The blit expands codes to real dot pairs
        // per output-row parity through an assemble-time table. ----
        var hcode = new byte[W * H];
        for (int i = 0; i < W * H; i++)
            hcode[i] = band[i] switch { 1 => (byte)1, 2 => (byte)2, 3 => (byte)3, 4 => (byte)3, _ => (byte)0 };
        var hpk = new byte[16000];
        for (int i = 0; i < W * H; i++)
            hpk[i >> 2] |= (byte)(hcode[i] << ((3 - (i & 3)) * 2));
        File.WriteAllBytes(Path.Combine(installDir, "CPHGC.DAT"), hpk);
        Console.WriteLine("wrote CPHGC.DAT (16000 bytes)");

        // ---- the EGA bake: the drawn grey panel, two pixels a byte,
        // even pixel in the HIGH nibble ----
        var egaCols = EGA16.Select(c => new[] { c[0] * 85, c[1] * 85, c[2] * 85 }).ToArray();
        var egaPan = EgaFromBands(band, dyn, bx0, by0, bx1, by1, egaCols);
        var epk = new byte[32000];
        for (int i = 0; i < W * H; i++)
            epk[i >> 1] |= (byte)(egaPan[i] << ((1 - (i & 1)) * 4));
        File.WriteAllBytes(Path.Combine(installDir, "CPEGA.DAT"), epk);
        Console.WriteLine("wrote CPEGA.DAT (32000 bytes)");

        // ---- THE SIDE CONSOLES (F6/F7). They live only as RLE streams
        // (CPSIDE.INC - there is no flat copy anywhere, that is what
        // saves them a far page each), so their bake ships as flat
        // MARKER maps and the game transcodes the streams IN PLACE at
        // load: every artwork byte becomes 200+colour - a range the
        // 137-entry palette never reaches - and the lookup tables carry
        // entries for the markers, phase tables and all, so checkers
        // and densities stay positional. SIDEBMPF never learns any of
        // it: it keeps copying bytes, the bytes just mean better.
        var incPath = Path.Combine(srcDir, "CPSIDE.INC");
        var scga = new byte[128000]; var sega2 = new byte[128000]; var shgc = new byte[128000];
        int soff = 0;
        foreach (var lbl in new[] { "CPLIMG", "CPRIMG" })
        {
            var (sidx, sop) = DecodeSide(incPath, lbl);
            var rgbP = new byte[W * H * 3];
            var sdyn = new bool[W * H];
            var pd = ParsePal(uiPath, "PALDAY");
            for (int i = 0; i < W * H; i++)
            {
                sdyn[i] = !sop[i];
                if (sop[i] && sidx[i] < pd.Count)
                {
                    rgbP[i * 3] = (byte)Dac(pd[sidx[i]][0]);
                    rgbP[i * 3 + 1] = (byte)Dac(pd[sidx[i]][1]);
                    rgbP[i * 3 + 2] = (byte)Dac(pd[sidx[i]][2]);
                }
            }
            Measure(rgbP, sdyn, out var ssm, out var sluma, out var slmean);
            var sband = PanelBands(ssm, sluma, slmean, sdyn);
            var nb0 = new int[4]; var nb1 = new[] { -1, -1, -1, -1 };
            var sEga = EgaFromBands(sband, sdyn, nb0, nb0, nb1, nb1, egaCols);
            for (int i = 0; i < W * H; i++)
            {
                if (sdyn[i]) continue;      // transparent: never read
                scga[soff + i] = sband[i] switch
                { 1 => (byte)204, 2 => (byte)201, 3 => (byte)203, 4 => (byte)202, _ => (byte)200 };
                sega2[soff + i] = (byte)(200 + sEga[i]);
                shgc[soff + i] = sband[i] switch
                { 1 => (byte)201, 2 => (byte)202, 3 => (byte)203, 4 => (byte)203, _ => (byte)200 };
            }
            soff += 64000;
        }
        File.WriteAllBytes(Path.Combine(installDir, "CPSCGA.DAT"), scga);
        File.WriteAllBytes(Path.Combine(installDir, "CPSEGA.DAT"), sega2);
        File.WriteAllBytes(Path.Combine(installDir, "CPSHGC.DAT"), shgc);
        Console.WriteLine("wrote CPSCGA/CPSEGA/CPSHGC.DAT (128000 bytes each: left, right)");

        // THE CLASSIC, the pilot's final call (2026-08-18): mode 4,
        // palette 1, intense - black/cyan/magenta/white, the palette
        // every CGA game wore and every player recognises. Mode 5's
        // burst-off cyan/red/white was tried first and looked wrong in
        // the emulator's CGA - "народ не поймёт".
        int[][] cgaPal1 = { new[]{0,0,0}, new[]{85,255,255}, new[]{255,85,255}, new[]{255,255,255} };
        var sb = new StringBuilder();
        sb.Append("; VIDLUT.INC - generated by TOOLS\\VidRig emit. DO NOT EDIT BY HAND.\r\n");
        sb.Append("; The 256->4 lookup for the CGA converter: PALDAY then PALNITE,\r\n");
        sb.Append("; four 256-byte tables each (phase = x&1 + (y&1)*2), values 0..3\r\n");
        sb.Append("; in CGA palette 1 intense: black, cyan, magenta, white.\r\n");
        sb.Append("; 512-aligned so the blit walks phases with XOR on BH alone.\r\n");
        sb.Append("        align 512\r\n");
        sb.Append("VLUT:\r\n");
        foreach (var palName in new[] { "PALDAY", "PALNITE" })
        {
            var p = ParsePal(uiPath, palName);
            var rgb = new int[256][];
            for (int i = 0; i < 256; i++)
                rgb[i] = i < p.Count ? new[] { Dac(p[i][0]), Dac(p[i][1]), Dac(p[i][2]) } : new[] { 0, 0, 0 };
            var lut = BuildLut(rgb, cgaPal1, dither: true);
            for (int phase = 0; phase < 4; phase++)
            {
                sb.Append($"; {palName}, phase {phase}\r\n");
                for (int row = 0; row < 16; row++)
                {
                    sb.Append("        db ");
                    for (int c = 0; c < 16; c++)
                    {
                        int i = row * 16 + c;
                        // the side-console markers: 200..203 solid
                        // colours, 204 the cyan/black checker - the
                        // phase keeps it positional inside RLE runs
                        int v = i is >= 200 and <= 203 ? i - 200
                              : i == 204 ? ((((phase & 1) ^ (phase >> 1)) & 1) != 0 ? 1 : 0)
                              : lut[i, phase];
                        sb.Append(v);
                        if (c < 15) sb.Append(',');
                    }
                    sb.Append("\r\n");
                }
            }
        }
        // ---- the EGA lookup: 256 -> 0..15, FLAT (no grids on EGA - the
        // pilot's call), day then night ----
        sb.Append("; the EGA lookup: 256 -> colour 0..15 in the curated sixteen,\r\n");
        sb.Append("; FLAT nearest (no dither on EGA anywhere), day then night\r\n");
        sb.Append("ELUT:\r\n");
        foreach (var palName in new[] { "PALDAY", "PALNITE" })
        {
            var p = ParsePal(uiPath, palName);
            sb.Append($"; {palName}\r\n");
            for (int row = 0; row < 16; row++)
            {
                sb.Append("        db ");
                for (int c = 0; c < 16; c++)
                {
                    int i = row * 16 + c;
                    int v = i is >= 200 and <= 215 ? i - 200   // side markers
                        : i < p.Count
                        ? Nearest(new[] { Dac(p[i][0]), Dac(p[i][1]), Dac(p[i][2]) }, egaCols)
                        : 0;
                    sb.Append(v);
                    if (c < 15) sb.Append(',');
                }
                sb.Append("\r\n");
            }
        }
        // ---- the EGA palette, as BIOS INT 10h AX=1002h wants it: 16
        // attribute values (6-bit rgbRGB) plus the border ----
        sb.Append("; the curated sixteen as 6-bit EGA attribute values (rgbRGB),\r\n");
        sb.Append("; 17th byte the border - feed to INT 10h AX=1002h, ES:DX\r\n");
        sb.Append("EPAL    db ");
        for (int i = 0; i < 16; i++)
        {
            int r = EGA16[i][0], g = EGA16[i][1], b = EGA16[i][2];
            int v = ((r >> 1) << 2) | ((g >> 1) << 1) | (b >> 1)
                  | ((r & 1) << 5) | ((g & 1) << 4) | ((b & 1) << 3);
            sb.Append(v);
            sb.Append(',');
        }
        sb.Append("0\r\n");
        // ---- the Hercules world lookup: per palette byte, TWO output
        // dots (the pixel is doubled), thresholded on luminance against
        // the 4x4 Bayer cell of the OUTPUT position. Eight 256-byte
        // tables per bank - phase = (screen row & 3)*2 + (source x & 1),
        // the pair 256 apart so the blit toggles with XOR BH - then the
        // night bank at +2048. Near-black and near-white go solid: lone
        // dots read as dirt (the minimap's war).
        int[,] hbay = { { 0, 8, 2, 10 }, { 12, 4, 14, 6 }, { 3, 11, 1, 9 }, { 15, 7, 13, 5 } };
        sb.Append("; the Hercules lookup: two dots per palette byte, Bayer on\r\n");
        sb.Append("; luminance, phase = (row&3)*2 + (source x&1), day then night\r\n");
        sb.Append("        align 512\r\n");
        sb.Append("HLUT:\r\n");
        foreach (var palName in new[] { "PALDAY", "PALNITE" })
        {
            var p = ParsePal(uiPath, palName);
            for (int phase = 0; phase < 8; phase++)
            {
                int y3 = phase >> 1, sxp = phase & 1;
                int thrL = (hbay[y3, sxp * 2] * 255 + 8) / 16;
                int thrR = (hbay[y3, sxp * 2 + 1] * 255 + 8) / 16;
                sb.Append($"; {palName}, row&3 = {y3}, source x&1 = {sxp}\r\n");
                for (int row = 0; row < 16; row++)
                {
                    sb.Append("        db ");
                    for (int c = 0; c < 16; c++)
                    {
                        int i = row * 16 + c;
                        int v;
                        if (i is >= 200 and <= 203)
                        {
                            // side markers carry DENSITY codes; the
                            // phase turns them into the right dots, so
                            // texture stays texture inside an RLE run
                            int code = i - 200, yodd = y3 & 1;
                            v = code switch
                            {
                                1 => yodd != 0 ? 1 : 0,          // quarter
                                2 => yodd != 0 ? 2 : 1,          // half
                                3 => 3,                            // full
                                _ => 0
                            };
                        }
                        else
                        {
                            int l = 0;
                            if (i < p.Count)
                                l = (Dac(p[i][0]) * 77 + Dac(p[i][1]) * 151 + Dac(p[i][2]) * 28) >> 8;
                            int bl = (l > 215 || (l >= 40 && l > thrL)) ? 2 : 0;
                            int br = (l > 215 || (l >= 40 && l > thrR)) ? 1 : 0;
                            v = bl + br;
                        }
                        sb.Append(v);
                        if (c < 15) sb.Append(',');
                    }
                    sb.Append("\r\n");
                }
            }
        }
        File.WriteAllText(Path.Combine(srcDir, "VIDLUT.INC"), sb.ToString());
        Console.WriteLine("wrote VIDLUT.INC (CGA 8 tables + EGA lookup + EGA palette)");
        return 0;
    }

    // one side console out of CPSIDE.INC's own RLE - the exact bytes
    // the game ships, so the bake can never drift from the stream it
    // will be transcoding. Token: 40|n literal, 80|n run, C0|n skip
    // (transparent), 00 end; n = 0 means a word count follows.
    static (byte[] idx, bool[] op) DecodeSide(string path, string label)
    {
        var bytes = new List<byte>();
        bool inb = false;
        foreach (var raw in File.ReadAllLines(path))
        {
            var t = raw.Trim();
            if (!inb) { if (t.StartsWith(label + ":")) inb = true; continue; }
            if (t.StartsWith(label + "END")) break;
            if (t.StartsWith("db"))
                foreach (var s in t[2..].Split(',')) bytes.Add(byte.Parse(s.Trim()));
        }
        var idx = new byte[W * H]; var op = new bool[W * H];
        int p = 0, pos = 0;
        while (true)
        {
            byte tok = bytes[p++];
            if (tok == 0) break;
            int type = tok & 0xC0, n = tok & 0x3F;
            if (n == 0) { n = bytes[p] | (bytes[p + 1] << 8); p += 2; }
            if (type == 0xC0) pos += n;
            else if (type == 0x80)
            {
                byte v = bytes[p++];
                for (int k = 0; k < n; k++) { idx[pos] = v; op[pos] = true; pos++; }
            }
            else
                for (int k = 0; k < n; k++) { idx[pos] = bytes[p++]; op[pos] = true; pos++; }
        }
        if (pos != W * H) throw new Exception($"{label}: decoded {pos} of 64000 - the stream walk is wrong");
        return (idx, op);
    }

    // 0 seam/black, 1 surface texture, 2 body plate, 3 bezel stroke, 4 lamp
    static byte[] PanelBands(byte[] sm, int[] luma, int[] lmean, bool[] dyn)
    {
        // The 1988 samples are BRIGHT because the artists lifted the
        // exposure, not because their plastic was light. So the bands
        // are percentiles of THIS panel's own luminance, not absolutes -
        // whatever the photograph's actual exposure was.
        var sorted = new List<int>();
        for (int i = 0; i < W * H; i++) if (!dyn[i]) sorted.Add(luma[i]);
        sorted.Sort();
        int P(int pct) => sorted[Math.Min(sorted.Count - 1, sorted.Count * pct / 100)];
        int tWhite = P(93), tSolid = P(62), tCheck = P(30);

        var band = new byte[W * H];
        for (int i = 0; i < W * H; i++)
        {
            if (dyn[i]) continue;
            int r = sm[i * 3], g = sm[i * 3 + 1], b = sm[i * 3 + 2];
            int ridge = luma[i] - lmean[i];
            if (r > 60 && r * 10 > g * 16 && r * 10 > b * 16) band[i] = 4;      // a lamp is a lamp
            else if (ridge > 12 || luma[i] >= tWhite) band[i] = 3;              // bezel highlight -> stroke
            else if (ridge < -9) band[i] = 0;                                    // a seam CUTS through the colour -
                                                                                 // that is what keeps the drawing
            else if (luma[i] >= tSolid) band[i] = 2;                             // lighter plates: body
            else if (luma[i] >= tCheck) band[i] = 1;                             // surface texture
            else band[i] = 0;
        }
        // the panel wears a black rim against the glass: a coloured strut
        // on a coloured sky has no edge, and an edge is the whole drawing
        for (int y = 0; y < H; y++)
            for (int x = 0; x < W; x++)
            {
                int i = y * W + x;
                if (dyn[i] || band[i] == 4) continue;
                for (int dy = -1; dy <= 1 && band[i] != 0; dy++)
                    for (int dx = -1; dx <= 1; dx++)
                    {
                        int xx = Math.Clamp(x + dx, 0, W - 1), yy = Math.Clamp(y + dy, 0, H - 1);
                        if (dyn[yy * W + xx]) { band[i] = 0; break; }
                    }
            }
        // a stroke is a line or it is dirt: it keeps its place only with
        // two stroke neighbours (the minimap's war, refought in C#)
        for (int pass = 0; pass < 2; pass++)
        {
            var keep = (byte[])band.Clone();
            for (int y = 0; y < H; y++)
                for (int x = 0; x < W; x++)
                {
                    int i = y * W + x;
                    if (dyn[i] || band[i] != 3) continue;
                    int n = 0;
                    for (int dy = -1; dy <= 1; dy++)
                        for (int dx = -1; dx <= 1; dx++)
                        {
                            if (dx == 0 && dy == 0) continue;
                            int xx = Math.Clamp(x + dx, 0, W - 1), yy = Math.Clamp(y + dy, 0, H - 1);
                            int j = yy * W + xx;
                            if (!dyn[j] && band[j] == 3) n++;
                        }
                    if (n < 2) keep[i] = (byte)(luma[i] >= tSolid ? 2 : 0);
                }
            band = keep;
        }
        return band;
    }

    // panel index image at 2x; dynamic pixels from the frame through the
    // LUT when given, else mid-grey so the masks are visible
    static void SavePanelComp(string path, byte[] panIdx, bool[] dyn, byte[] fidx, byte[,] lut, int[][] cols)
    {
        var outp = new byte[(W * 2) * (H * 2) * 3];
        for (int y = 0; y < H * 2; y++)
            for (int x = 0; x < W * 2; x++)
            {
                int sx = x >> 1, sy = y >> 1, i = sy * W + sx;
                int[] c;
                if (!dyn[i]) c = cols[panIdx[i]];
                else if (fidx != null) c = cols[lut[fidx[i], (sx & 1) + ((sy & 1) << 1)]];
                else c = new[] { 100, 100, 100 };
                int o = (y * W * 2 + x) * 3;
                outp[o] = (byte)c[0]; outp[o + 1] = (byte)c[1]; outp[o + 2] = (byte)c[2];
            }
        Png.Save(path, outp, W * 2, H * 2);
        Console.WriteLine($"wrote {Path.GetFileName(path)}");
    }

    // ---- render one converter preview: LUT per palette entry, optional
    // 2x2 ordered dither by best two-colour mix (the exact table the DOS
    // converter will carry: 4 bytes per palette entry, phase = x&1 + (y&1)*2)
    static void Emit(string dir, string name, byte[] idx, int[][] pal, int[][] cols, bool dither)
    {
        var lut = BuildLut(pal, cols, dither);
        // paint at 2x so the preview reads at desk distance
        var outp = new byte[(W * 2) * (H * 2) * 3];
        for (int y = 0; y < H * 2; y++)
            for (int x = 0; x < W * 2; x++)
            {
                int sx = x >> 1, sy = y >> 1;
                int phase = (sx & 1) + ((sy & 1) << 1);
                var c = cols[lut[idx[sy * W + sx], phase]];
                int o = (y * W * 2 + x) * 3;
                outp[o] = (byte)c[0]; outp[o + 1] = (byte)c[1]; outp[o + 2] = (byte)c[2];
            }
        Png.Save(Path.Combine(dir, name + ".png"), outp, W * 2, H * 2);
        Console.WriteLine($"wrote {name}.png");
    }

    // The table the DOS converter will carry, byte for byte: 4 entries
    // per palette index, picked by phase = x&1 + (y&1)*2.
    static byte[,] BuildLut(int[][] pal, int[][] cols, bool dither)
    {
        int n = pal.Length;
        var lut = new byte[n, 4];
        for (int i = 0; i < n; i++)
        {
            if (!dither)
            {
                int best = Nearest(pal[i], cols);
                for (int p = 0; p < 4; p++) lut[i, p] = (byte)best;
            }
            else
            {
                // SOLID FIRST. A checker everywhere is how a picture
                // dissolves into noise - the pilot's word was "creeps".
                // A mix has to EARN its speckle: it wins only when it
                // cuts the solid colour's error by better than half.
                int solid = Nearest(pal[i], cols);
                int d0 = Dist(pal[i][0], pal[i][1], pal[i][2],
                              cols[solid][0], cols[solid][1], cols[solid][2]);
                int ba = 0, bb = 0, bk = 0, bd = int.MaxValue;
                for (int a = 0; a < cols.Length; a++)
                    for (int b = a + 1; b < cols.Length; b++)
                        for (int k = 1; k <= 3; k++)
                        {
                            int mr = (cols[a][0] * (4 - k) + cols[b][0] * k) / 4;
                            int mg = (cols[a][1] * (4 - k) + cols[b][1] * k) / 4;
                            int mb2 = (cols[a][2] * (4 - k) + cols[b][2] * k) / 4;
                            int d = Dist(pal[i][0], pal[i][1], pal[i][2], mr, mg, mb2);
                            // far-apart colours make a shimmering checker
                            // even when their average is right - tax them
                            d += Dist(cols[a][0], cols[a][1], cols[a][2], cols[b][0], cols[b][1], cols[b][2]) / 4;
                            if (d < bd) { bd = d; ba = a; bb = b; bk = k; }
                        }
                if (bd * 2 >= d0)
                {
                    for (int p = 0; p < 4; p++) lut[i, p] = (byte)solid;
                }
                else
                {
                    // phase order 0,3,1,2 spreads k over the 2x2 like Bayer
                    int[] order = { 0, 3, 1, 2 };
                    for (int p = 0; p < 4; p++)
                        lut[i, order[p]] = (byte)(p < bk ? bb : ba);
                }
            }
        }
        return lut;
    }

    static int Nearest(int[] c, int[][] set)
    {
        int best = 0, bd = int.MaxValue;
        for (int i = 0; i < set.Length; i++)
        {
            int d = Dist(c[0], c[1], c[2], set[i][0], set[i][1], set[i][2]);
            if (d < bd) { bd = d; best = i; }
        }
        return best;
    }

    // weighted RGB distance - red and blue matter less than green to the eye
    static int Dist(int r1, int g1, int b1, int r2, int g2, int b2)
    {
        int dr = r1 - r2, dg = g1 - g2, db = b1 - b2;
        return 3 * dr * dr + 6 * dg * dg + 2 * db * db;
    }

    static int Dac(int v) => (v << 2) | (v >> 4);    // 6-bit DAC as DOSBox shows it

    // ---- PALDAY out of UI.INC, following its include of PALPNL.INC ----
    static List<int[]> ParsePal(string uiPath, string label)
    {
        var outp = new List<int[]>();
        bool inPal = false;
        foreach (var raw in Expand(uiPath))
        {
            var line = raw;
            int sc = line.IndexOf(';'); if (sc >= 0) line = line[..sc];
            line = line.Trim();
            if (!inPal)
            {
                if (line.StartsWith(label)) { inPal = true; line = line[label.Length..].Trim(); }
                else continue;
            }
            else if (line.Length > 0 && !line.StartsWith("db") && !line.StartsWith("include"))
                break;                                 // the next label ends the table
            if (line.StartsWith("db"))
            {
                var nums = line[2..].Split(',').Select(s => int.Parse(s.Trim())).ToArray();
                if (nums.Length != 3) throw new Exception($"odd palette line: {raw}");
                outp.Add(nums);
            }
        }
        if (outp.Count == 0) throw new Exception($"{label} not found in {uiPath}");
        return outp;
    }

    static IEnumerable<string> Expand(string path)
    {
        foreach (var line in File.ReadAllLines(path))
        {
            var t = line.Trim();
            if (t.StartsWith("include", StringComparison.OrdinalIgnoreCase))
            {
                int q1 = t.IndexOf('\''), q2 = t.LastIndexOf('\'');
                var inc = t[(q1 + 1)..q2].Replace('\\', Path.DirectorySeparatorChar);
                var full = Path.Combine(Path.GetDirectoryName(path), inc);
                if (File.Exists(full))
                    foreach (var l in File.ReadAllLines(full)) yield return l;
                else yield return line;               // engine includes we don't need
            }
            else yield return line;
        }
    }
}

class Image { public int W, H; public byte[] P; }

// The PNG pair from Panel2Inc: reads the one variant art tools write
// (8-bit RGB/RGBA, not interlaced), writes 8-bit RGB, filter 0.
static class Png
{
    public static Image Load(string path)
    {
        var f = File.ReadAllBytes(path);
        if (f.Length < 8 || f[0] != 0x89 || f[1] != 'P' || f[2] != 'N' || f[3] != 'G')
            throw new Exception($"{path}: not a PNG");
        int w = 0, h = 0, bit = 0, colour = 0, interlace = 0;
        var idat = new MemoryStream();
        var plte = Array.Empty<byte>();
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
            else if (type == "PLTE") { plte = new byte[len]; Array.Copy(f, d, plte, 0, len); }
            else if (type == "IDAT") idat.Write(f, d, len);
            else if (type == "IEND") break;
            p = d + len + 4;
        }
        if (bit != 8 || (colour != 2 && colour != 6 && colour != 3) || interlace != 0)
            throw new Exception($"{path}: need 8-bit RGB, RGBA or palette, not interlaced (got bit {bit}, colour {colour})");
        int ch = colour == 2 ? 3 : colour == 6 ? 4 : 1;
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
                int o = (y * w + x) * 3;
                if (ch == 1)
                {
                    int pi = line[x] * 3;
                    outp[o] = plte[pi]; outp[o + 1] = plte[pi + 1]; outp[o + 2] = plte[pi + 2];
                }
                else
                {
                    int i = x * ch;
                    outp[o] = line[i]; outp[o + 1] = line[i + 1]; outp[o + 2] = line[i + 2];
                }
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

    public static void Save(string path, byte[] rgb, int w, int h)
    {
        var ms = new MemoryStream();
        void U32(uint v) { ms.WriteByte((byte)(v >> 24)); ms.WriteByte((byte)(v >> 16)); ms.WriteByte((byte)(v >> 8)); ms.WriteByte((byte)v); }
        void Chunk(string type, byte[] data)
        {
            U32((uint)data.Length);
            var t = Encoding.ASCII.GetBytes(type);
            ms.Write(t); ms.Write(data);
            uint crc = Crc(t, data); U32(crc);
        }
        ms.Write(new byte[] { 0x89, (byte)'P', (byte)'N', (byte)'G', 13, 10, 26, 10 });
        var ihdr = new byte[13];
        ihdr[0] = (byte)(w >> 24); ihdr[1] = (byte)(w >> 16); ihdr[2] = (byte)(w >> 8); ihdr[3] = (byte)w;
        ihdr[4] = (byte)(h >> 24); ihdr[5] = (byte)(h >> 16); ihdr[6] = (byte)(h >> 8); ihdr[7] = (byte)h;
        ihdr[8] = 8; ihdr[9] = 2;
        Chunk("IHDR", ihdr);
        var rawd = new byte[h * (1 + w * 3)];
        for (int y = 0; y < h; y++)
        {
            rawd[y * (1 + w * 3)] = 0;
            Buffer.BlockCopy(rgb, y * w * 3, rawd, y * (1 + w * 3) + 1, w * 3);
        }
        var zs = new MemoryStream();
        using (var z = new ZLibStream(zs, CompressionLevel.Optimal, true)) z.Write(rawd);
        Chunk("IDAT", zs.ToArray());
        Chunk("IEND", Array.Empty<byte>());
        File.WriteAllBytes(path, ms.ToArray());
    }

    static uint[] crcTab;
    static uint Crc(byte[] a, byte[] b)
    {
        if (crcTab == null)
        {
            crcTab = new uint[256];
            for (uint n = 0; n < 256; n++)
            {
                uint c = n;
                for (int k = 0; k < 8; k++) c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
                crcTab[n] = c;
            }
        }
        uint crc = 0xFFFFFFFF;
        foreach (var x in a) crc = crcTab[(crc ^ x) & 255] ^ (crc >> 8);
        foreach (var x in b) crc = crcTab[(crc ^ x) & 255] ^ (crc >> 8);
        return crc ^ 0xFFFFFFFF;
    }
}
