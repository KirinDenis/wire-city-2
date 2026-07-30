// ============================================================================
//  TextShot - render an 80x25 DOS text screen to a 640x400 PNG.
//
//  For the card images on the arcade index: the text-mode programs (the BBS
//  terminal) have nothing to photograph but characters, and driving the real
//  emulator to get them on screen needs a live relay, a bot and a visible
//  browser window. This draws the same screen from a text file instead, so
//  the dialogue is editable copy rather than a captured accident.
//
//  These are MOCKUPS of a real program's output, not captures. Keep the
//  banner text in sync with the program (EXAMPLES\BBS.ASM: MSGHI, MSGRE) or
//  the picture starts lying about what the software does.
//
//  Geometry is the real thing: VGA text mode is 80x25 cells of 8x16 pixels
//  = 640x400, which is exactly the 16:10 the cards crop to. Colour is the
//  DOS default attribute 07 - light grey (170,170,170) on black.
//
//  Build: BUILD.BAT (framework csc, no SDK, no packages)
//  Run:   TextShot.exe <screen.txt> <out.png> [--cursor]
//         --cursor draws the blinking underline cursor after the last line
// ============================================================================
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;
using System.IO;

static class TextShot
{
    const int COLS = 80, ROWS = 25, CW = 8, CH = 16;

    static readonly Color Grey = Color.FromArgb(170, 170, 170);  // attribute 07
    static readonly Color Black = Color.FromArgb(0, 0, 0);

    static int Main(string[] args)
    {
        if (args.Length < 2)
        {
            Console.Error.WriteLine("usage: TextShot <screen.txt> <out.png> [--cursor]");
            return 2;
        }
        string src = args[0], dst = args[1];
        bool cursor = Array.IndexOf(args, "--cursor") >= 0;

        if (!File.Exists(src)) { Console.Error.WriteLine("no such file: " + src); return 1; }

        // Read the screen, hard-wrapping at 80 like the real teletype would.
        List<string> rows = new List<string>();
        foreach (string raw in File.ReadAllLines(src))
        {
            string line = raw.TrimEnd();
            if (line.Length == 0) { rows.Add(""); continue; }
            while (line.Length > COLS)
            {
                rows.Add(line.Substring(0, COLS));
                line = line.Substring(COLS);
            }
            rows.Add(line);
        }
        if (rows.Count > ROWS)
        {
            Console.Error.WriteLine("warning: " + rows.Count + " rows, keeping the last "
                                    + ROWS + " (a real screen scrolls)");
            rows.RemoveRange(0, rows.Count - ROWS);
        }

        using (Bitmap bmp = new Bitmap(COLS * CW, ROWS * CH, PixelFormat.Format24bppRgb))
        {
            using (Graphics g = Graphics.FromImage(bmp))
            {
                g.Clear(Black);
                // Crisp pixels, not antialiased shapes: a DOS screen has hard edges.
                g.TextRenderingHint = TextRenderingHint.SingleBitPerPixelGridFit;
                g.InterpolationMode = InterpolationMode.NearestNeighbor;
                g.PixelOffsetMode = PixelOffsetMode.Half;

                // Consolas at 15px em lands ~7px of ink inside the 8px cell -
                // close to the VGA ROM font's proportions without shipping a
                // 4 KB glyph table. Each character is placed by hand so the
                // grid stays exactly 8 px, whatever the font's own advance is.
                using (Font f = new Font("Consolas", 15f, FontStyle.Regular, GraphicsUnit.Pixel))
                using (Brush fg = new SolidBrush(Grey))
                {
                    StringFormat sf = StringFormat.GenericTypographic;
                    sf.FormatFlags |= StringFormatFlags.MeasureTrailingSpaces
                                    | StringFormatFlags.NoWrap;
                    for (int r = 0; r < rows.Count; r++)
                    {
                        string line = rows[r];
                        for (int c = 0; c < line.Length && c < COLS; c++)
                        {
                            char ch = line[c];
                            if (ch == ' ') continue;
                            g.DrawString(ch.ToString(), f, fg,
                                         new PointF(c * CW, r * CH + 1f), sf);
                        }
                    }

                    if (cursor && rows.Count > 0)
                    {
                        // DOSBox draws the text cursor as an underline in the
                        // bottom two scanlines of the cell.
                        int cr = rows.Count - 1;
                        int cc = Math.Min(rows[cr].Length, COLS - 1);
                        g.FillRectangle(fg, cc * CW, cr * CH + CH - 3, CW - 1, 2);
                    }
                }
            }
            string dir = Path.GetDirectoryName(Path.GetFullPath(dst));
            if (dir.Length > 0) Directory.CreateDirectory(dir);
            bmp.Save(dst, ImageFormat.Png);
        }
        Console.WriteLine("wrote " + dst + "  " + (COLS * CW) + "x" + (ROWS * CH)
                          + "  (" + rows.Count + " rows of text)");
        return 0;
    }
}
