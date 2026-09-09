// ============================================================================
//  Ows - the OWS1 sprite files of a PICKUP (the .SPR things and the .SLT slot
//  pictures), read the way the game reads them, and the two ways the game
//  draws a slot: the picture itself, and its OUTLINE - every opaque pixel
//  with a transparent neighbour or an edge of the picture, in the palette's
//  grey. The rule is STORY.ASM's DRAWICO and PALCOLS, repeated here so that
//  what the desk shows in the panel is what the game will draw.
//
//  Until a pickup is converted there are no .SLT files; then a slot is made
//  from the layer itself, scaled to the slot's box by WPF - close enough to
//  place things by, and replaced by the product the moment it exists.
// ============================================================================

using System.IO;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace SceneDesk;

public static class Ows
{
    public sealed class Picture
    {
        public int W, H, X, Y;
        public int[] Bgra;                              // the pixels, opaque or 0
        public bool[] Opaque;

        public BitmapSource Colour() => Make(Bgra);

        public BitmapSource Outline(int greyBgra)
        {
            var px = new int[W * H];
            for (int y = 0; y < H; y++)
                for (int x = 0; x < W; x++)
                {
                    int i = y * W + x;
                    if (!Opaque[i]) continue;
                    bool edge = x == 0 || y == 0 || x == W - 1 || y == H - 1
                             || !Opaque[i - 1] || !Opaque[i + 1] || !Opaque[i - W] || !Opaque[i + W];
                    if (edge) px[i] = greyBgra;
                }
            return Make(px);
        }

        BitmapSource Make(int[] px)
        {
            var bmp = new WriteableBitmap(W, H, 96, 96, PixelFormats.Bgra32, null);
            bmp.WritePixels(new Int32Rect(0, 0, W, H), px, W * 4, 0);
            bmp.Freeze();
            return bmp;
        }
    }

    // The 256 entries of an OWV's header as BGRA, from the 6-bit values.
    public static int[] Palette(string owvPath)
    {
        var hdr = new byte[800];
        using (var f = File.OpenRead(owvPath)) f.ReadExactly(hdr, 0, 800);
        var pal = new int[256];
        for (int i = 0; i < 256; i++)
            pal[i] = unchecked((int)0xFF000000) | (hdr[32 + i * 3] << 2) << 16 | (hdr[33 + i * 3] << 2) << 8 | (hdr[34 + i * 3] << 2);
        return pal;
    }

    // PALCOLS's grey: the entry nearest a mid grey, measured as the distance
    // from the grey level AND the distance from being grey at all.
    public const int GREY_LEVEL = 38;                   // six-bit; 150 of 255
    public static byte GreyIndex(int[] pal)
    {
        int best = 0, bestD = int.MaxValue;
        for (int i = 0; i < 256; i++)
        {
            int r = ((pal[i] >> 16) & 255) >> 2, g = ((pal[i] >> 8) & 255) >> 2, b = (pal[i] & 255) >> 2;
            int d = Math.Abs(r - GREY_LEVEL) + Math.Abs(g - GREY_LEVEL) + Math.Abs(b - GREY_LEVEL) + Math.Abs(r - g) + Math.Abs(g - b);
            if (d < bestD) { bestD = d; best = i; }
        }
        return (byte)best;
    }

    // An OWS1 file in a palette.
    public static Picture Load(string path, int[] pal)
    {
        var b = File.ReadAllBytes(path);
        if (b.Length < 16 || b[0] != 'O' || b[1] != 'W' || b[2] != 'S' || b[3] != '1') throw new InvalidDataException("not an OWS1 file");
        var p = new Picture { W = b[4] | b[5] << 8, H = b[6] | b[7] << 8, X = (short)(b[8] | b[9] << 8), Y = (short)(b[10] | b[11] << 8) };
        byte tr = b[12];
        p.Bgra = new int[p.W * p.H]; p.Opaque = new bool[p.W * p.H];
        for (int i = 0; i < p.W * p.H && 16 + i < b.Length; i++)
        {
            byte ix = b[16 + i];
            if (ix == tr) continue;
            p.Opaque[i] = true; p.Bgra[i] = pal[ix];
        }
        return p;
    }

    // A layer PNG scaled into a box, alpha below half = transparent - the
    // converter's rule, without its palette.
    public static Picture FromLayer(string path, int boxW, int boxH)
    {
        var bi = new BitmapImage(); bi.BeginInit(); bi.CacheOption = BitmapCacheOption.OnLoad; bi.UriSource = new Uri(path); bi.EndInit();
        double f = Math.Min(Math.Min((double)boxW / bi.PixelWidth, (double)boxH / bi.PixelHeight), 1.0);
        int w = Math.Max(1, (int)Math.Round(bi.PixelWidth * f)), h = Math.Max(1, (int)Math.Round(bi.PixelHeight * f));
        var scaled = new TransformedBitmap(bi, new ScaleTransform((double)w / bi.PixelWidth, (double)h / bi.PixelHeight));
        var conv = new FormatConvertedBitmap(scaled, PixelFormats.Bgra32, null, 0);
        w = conv.PixelWidth; h = conv.PixelHeight;
        var px = new int[w * h];
        conv.CopyPixels(px, w * 4, 0);
        var p = new Picture { W = w, H = h, Bgra = new int[w * h], Opaque = new bool[w * h] };
        for (int i = 0; i < w * h; i++)
        {
            int a = (px[i] >> 24) & 255;
            if (a < 128) continue;
            p.Opaque[i] = true; p.Bgra[i] = px[i] | unchecked((int)0xFF000000);
        }
        return p;
    }
}
