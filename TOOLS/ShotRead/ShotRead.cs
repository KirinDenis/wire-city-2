// ============================================================================
//  ShotRead - read a screen captured by SCRGRAB and say what is in it.
//
//  SCRGRAB brings back 4000 bytes of video memory. This turns them into the
//  two things worth knowing:
//
//    the picture      25 lines of CP437, so you can see which screen it is
//    the attributes   every distinct colour pair that appears, by name, with
//                     a count and the first place it occurs
//
//  The second one is the point. "Which blue is the window background" is not
//  a question to answer by looking at a screenshot; it is 0x71 or it is 0x17,
//  and the byte says so. Everything this tool exists to settle is settled by
//  the legend it prints.
//
//  Build: BUILD.BAT (framework csc, no SDK, no packages)
//  Run:   ShotRead.exe SHOT00.BIN [--grid]
//         --grid also prints the attribute of every cell, in hex
// ============================================================================
using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

static class ShotRead
{
    const int COLS = 80, ROWS = 25;

    // The IBM PC attribute byte: low nibble foreground, high nibble background.
    static readonly string[] ColorName =
    {
        "black", "blue", "green", "cyan", "red", "magenta", "brown", "lightgray",
        "darkgray", "ltblue", "ltgreen", "ltcyan", "ltred", "ltmagenta", "yellow", "white"
    };

    // CP437 to Unicode. Only what a text UI actually uses is interesting here,
    // but the whole page is cheap and saves guessing at the odd one.
    const string CP437 =
        " ☺☻♥♦♣♠•◘○◙♂♀♪♫☼" +
        "►◄↕‼¶§▬↨↑↓→←∟↔▲▼" +
        " !\"#$%&'()*+,-./0123456789:;<=>?" +
        "@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_" +
        "`abcdefghijklmnopqrstuvwxyz{|}~⌂" +
        "ÇüéâäàåçêëèïîìÄÅ" +
        "ÉæÆôöòûùÿÖÜ¢£¥₧ƒ" +
        "áíóúñÑªº¿⌐¬½¼¡«»" +
        "░▒▓│┤╡╢╖╕╣║╗╝╜╛┐" +
        "└┴┬├─┼╞╟╚╔╩╦╠═╬╧" +
        "╨╤╥╙╘╒╓╫╪┘┌█▄▌▐▀" +
        "αßΓπΣσµτΦΘΩδ∞φε∩" +
        "≡±≥≤⌠⌡÷≈°∙·√ⁿ²■ ";

    static int Main(string[] args)
    {
        if (args.Length < 1)
        {
            Console.Error.WriteLine("usage: ShotRead <SHOTnn.BIN> [--grid]");
            return 2;
        }
        bool grid = Array.IndexOf(args, "--grid") >= 0;

        byte[] b;
        try { b = File.ReadAllBytes(args[0]); }
        catch (Exception e) { Console.Error.WriteLine(e.Message); return 1; }

        if (b.Length != COLS * ROWS * 2)
        {
            Console.Error.WriteLine(
                "{0} is {1} bytes; an 80x25 screen is {2}. Wrong file, or a capture " +
                "taken in a different text mode.", args[0], b.Length, COLS * ROWS * 2);
            return 1;
        }

        Console.OutputEncoding = Encoding.UTF8;
        Console.WriteLine("{0}  -  80x25, {1} bytes", Path.GetFileName(args[0]), b.Length);
        Console.WriteLine();

        // --- the picture ----------------------------------------------------
        Console.WriteLine("     " + Ruler());
        for (int y = 0; y < ROWS; y++)
        {
            var sb = new StringBuilder();
            for (int x = 0; x < COLS; x++) sb.Append(CP437[b[(y * COLS + x) * 2]]);
            Console.WriteLine("{0,3}  {1}", y, sb);
        }
        Console.WriteLine();

        // --- the legend, which is what the tool is for -----------------------
        var seen = new Dictionary<byte, int>();
        var first = new Dictionary<byte, string>();
        for (int y = 0; y < ROWS; y++)
            for (int x = 0; x < COLS; x++)
            {
                byte a = b[(y * COLS + x) * 2 + 1];
                if (!seen.ContainsKey(a)) { seen[a] = 0; first[a] = string.Format("{0},{1}", x, y); }
                seen[a]++;
            }

        Console.WriteLine("attributes in use ({0} distinct)", seen.Count);
        Console.WriteLine("  hex   fg           bg           cells  first at");
        var keys = new List<byte>(seen.Keys);
        keys.Sort((p, q) => seen[q].CompareTo(seen[p]));
        foreach (byte a in keys)
            Console.WriteLine("  0x{0:X2}  {1,-12} {2,-12} {3,5}  {4}",
                a, ColorName[a & 0x0F], ColorName[a >> 4], seen[a], first[a]);

        if (grid)
        {
            Console.WriteLine();
            Console.WriteLine("attribute of every cell:");
            for (int y = 0; y < ROWS; y++)
            {
                var sb = new StringBuilder();
                for (int x = 0; x < COLS; x++)
                    sb.AppendFormat("{0:X2} ", b[(y * COLS + x) * 2 + 1]);
                Console.WriteLine("{0,3}  {1}", y, sb);
            }
        }
        return 0;
    }

    static string Ruler()
    {
        var sb = new StringBuilder();
        for (int x = 0; x < COLS; x++) sb.Append(x % 10 == 0 ? (char)('0' + (x / 10) % 10) : '.');
        return sb.ToString();
    }
}
