// ============================================================================
//  ArtGen - SOKOBAN's CGA pictures, drawn by rule, and a preview of a level
//  drawn the way SOKOBAN.ASM draws it.
//
//      dotnet run --project TOOLS\ArtGen -- GAMES\SOKOBAN\LEVELS.INC 0 PREV ART.INC
//
//  Writes ART.INC (the art as SOKOBAN.ASM includes it: one character a
//  pixel, . see-through, 0 black, 1 green, 2 red, 3 yellow, S and P the
//  man's shirt and cap) and PREVS.PNG, PREVB.PNG: that level at both tile
//  sizes, three times enlarged, in CGA palette 0 bright. ART.INC in the
//  game's folder may have been touched up by hand since: write elsewhere
//  and compare before you copy over it.
//
//  The two sizes are tiles of 16x8 and 24x12 - 2:1 diamonds whose rows
//  are 2, 6, 10 ... wide, so neighbours meet without a gap or an overlap.
//  A wall is a block 6 px high: taller, and in Sokoban's one-tile
//  corridors the walls in front hide the crates (the first tries had 8).
//  Its top is a dark red checker, its faces red bricks in black mortar.
//  A crate is a smaller block with a red frame and brace; on a goal it
//  turns green. The men are drawn by hand, below.
// ============================================================================
using System.IO.Compression;
using System.Text;
using System.Text.RegularExpressions;

if (args.Length != 4)
{
    Console.Error.WriteLine("usage: ArtGen <LEVELS.INC> <level number> <preview prefix> <out ART.INC>");
    return 1;
}

var pal = new (int r, int g, int b)[] { (0, 0, 0), (85, 255, 85), (255, 85, 85), (255, 255, 85) };
char Chk(int x, int y, char a, char b) => ((x + y) & 1) == 0 ? a : b;
void Put(string[] s, int x, int y, char c) { var a = s[y].ToCharArray(); a[x] = c; s[y] = new string(a); }

// a diamond of half-width t in a canvas 2T wide: row y spans [T-hw, T-1+hw]
(int a, int b) Span(int T, int t, int y)
{
    int hw = t - (int)Math.Round(2 * Math.Abs(y - (t / 2.0 - 0.5)));
    return (T - hw, T - 1 + hw);
}
string[] Blank(int T, int rows) => Enumerable.Range(0, rows).Select(_ => new string('.', 2 * T)).ToArray();

string[] Floor(int T, bool goal)
{
    var s = Blank(T, T);
    for (int y = 0; y < T; y++)
    {
        var (a, b) = Span(T, T, y);
        for (int x = a; x <= b; x++)
        {
            bool edge = x <= a + 1 || x >= b - 1;     // lit above, shadow below
            Put(s, x, y, edge ? (y < T / 2 ? '1' : '0') : Chk(x, y, '1', '0'));
        }
    }
    if (goal)
    {
        // a red diamond ring with a yellow eye, half the tile's size
        int g = T / 2;
        for (int y = 0; y < g; y++)
        {
            var (a, b) = Span(T, g, y);
            int yy = y + T / 4;
            for (int x = a; x <= b; x++)
            {
                bool rim = x <= a + 1 || x >= b - 1 || y == 0 || y == g - 1;
                Put(s, x, yy, rim ? '2' : '3');
            }
        }
    }
    return s;
}

// a block of half-width t: its top diamond, then H rows of faces under it.
// face(left, u, v, faceWidth, x+y): u from the outer edge, v down the face
string[] Block(int T, int t, int H, Func<int, int, char> top, Func<bool, int, int, int, int, char> face)
{
    var s = Blank(T, t + H);
    for (int y = 0; y < t; y++)
    {
        var (a, b) = Span(T, t, y);
        for (int x = a; x <= b; x++) Put(s, x, y, top(x, y));
    }
    var (wa, wb) = Span(T, t, t / 2);
    int wf = T - wa;
    for (int x = wa; x <= wb; x++)
    {
        bool left = x < T;
        int last = 0;
        for (int y = t - 1; y >= 0; y--) { var (a, b) = Span(T, t, y); if (x >= a && x <= b) { last = y; break; } }
        int u = left ? x - wa : wb - x;
        for (int v = 0; v < H; v++) Put(s, x, last + 1 + v, face(left, u, v, wf, x + last + 1 + v));
    }
    return s;
}

string[] Wall(int T)
{
    const int H = 6;
    return Block(T, T, H,
        (x, y) => { var (a, b) = Span(T, T, y); bool rim = y < T / 2 && (x <= a + 1 || x >= b - 1); return rim ? '2' : Chk(x, y, '2', '0'); },
        (left, u, v, wf, xy) =>
        {
            // v0 mortar, v1-2 course A, v3 mortar, v4-5 course B; joints staggered
            if (v == 0 || v == 3) return '0';
            if (v < 3) return u == wf / 2 ? '0' : '2';
            return u == wf / 4 || u == (3 * wf) / 4 ? '0' : '2';
        });
}

string[] Crate(int T, bool onGoal)
{
    int t = T == 8 ? 6 : 8, H = T == 8 ? 8 : 10;
    char fill = onGoal ? '1' : '3';
    return Block(T, t, H,
        (x, y) => { var (a, b) = Span(T, t, y); bool rim = x <= a + 1 || x >= b - 1; return rim ? '2' : fill; },
        (left, u, v, wf, xy) =>
        {
            bool frame = u == 0 || u == wf - 1 || v == 0 || v == H - 1;
            double d = v - (double)u * (H - 1) / (wf - 1);
            bool brace = left && Math.Abs(d) < 0.75 || !left && v == H / 2;
            return frame || brace ? '2' : fill;
        });
}

string[] man0 = {
    "......0000......",
    ".....0PPPP0.....",
    ".....033330.....",
    ".....030030.....",
    ".....033330.....",
    "......0000......",
    "....0SSSSSS0....",
    "...0SSSSSSSS0...",
    "...0S0SSSS0S0...",
    "...030SSSS030...",
    "....00SSSS00....",
    ".....0PPPP0.....",
    ".....0P00P0.....",
    ".....0P00P0.....",
    "....000..000....",
};
string[] man1 = {
    ".........000000.........",
    "........0PPPPPP0........",
    "........0PPPPPP0........",
    "........03333330........",
    "........03033030........",
    "........03333330........",
    ".........000000.........",
    ".......0SSSSSSSS0.......",
    "......0SSSSSSSSSS0......",
    "......0S0SSSSSS0S0......",
    "......0S0SSSSSS0S0......",
    "......0S0SSSSSS0S0......",
    "......030SSSSSS030......",
    ".......00SSSSSS00.......",
    "........0PPPPPP0........",
    "........0PP00PP0........",
    "........0PP00PP0........",
    "........0PP00PP0........",
    ".......0000..0000.......",
};
string[] you0 = { "......3333......", ".......33......." };
string[] you1 = { ".........333333.........", "..........3333..........", "...........33..........." };
string[] Man(string[] art, char sh, char pa) => art.Select(r => r.Replace('S', sh).Replace('P', pa)).ToArray();

// where each picture's top row goes against its tile's top row Y - the
// numbers in SOKOBAN.ASM's zoom records ZS and ZB
int Lift(int T, string kind) => kind switch
{
    "wall" => -6,
    "box" => T / 2 - (T == 8 ? 8 : 10) - (T == 8 ? 6 : 8) / 2,  // footprint on the tile's middle
    "man" => T == 8 ? -9 : -11,
    "you" => T == 8 ? -12 : -15,
    _ => 0
};

// ---- the level, out of LEVELS.INC ----
int want = int.Parse(args[1]);
var inc = File.ReadAllLines(args[0]);
int at = Array.FindIndex(inc, l => l.StartsWith($"LEV{want:D2}:"));
if (at < 0) { Console.Error.WriteLine($"no LEV{want:D2} in {args[0]}"); return 1; }
var wh = Regex.Match(inc[at], @"db\s+(\d+),(\d+)");
int W = int.Parse(wh.Groups[1].Value), Hh = int.Parse(wh.Groups[2].Value);
var rows = inc.Skip(at + 1).Take(Hh).Select(l => Regex.Match(l, "'(.*)'").Groups[1].Value).ToList();
char At(int c, int r) => rows[r][c];
var floor = new bool[W, Hh];
int mc = 0, mr = 0;
for (int r = 0; r < Hh; r++) for (int c = 0; c < W; c++) if (At(c, r) == '@' || At(c, r) == '+') { mc = c; mr = r; }
var st = new Stack<(int, int)>(); st.Push((mc, mr));
while (st.Count > 0)
{
    var (c, r) = st.Pop();
    if (c < 0 || r < 0 || c >= W || r >= Hh || floor[c, r] || At(c, r) == '#') continue;
    floor[c, r] = true; st.Push((c + 1, r)); st.Push((c - 1, r)); st.Push((c, r + 1)); st.Push((c, r - 1));
}

void Preview(int T, string path)
{
    var fl = Floor(T, false); var gl = Floor(T, true); var wl = Wall(T); var bx = Crate(T, false); var bg = Crate(T, true);
    var ma = Man(T == 8 ? man0 : man1, '3', '2'); var yo = T == 8 ? you0 : you1;
    int hx = T, hy = T / 2;
    int SW = Math.Max(320, (W + Hh) * hx + 16), SH = Math.Max(200, (W + Hh) * hy + 40);
    var img = new int[SW * SH];
    void Draw(string[] spr, int X, int Y)
    {
        for (int y = 0; y < spr.Length; y++)
            for (int x = 0; x < spr[y].Length; x++)
            {
                char ch = spr[y][x]; if (ch == '.') continue;
                int px = X + x, py = Y + y;
                if (px < 0 || py < 0 || px >= SW || py >= SH) continue;
                img[py * SW + px] = ch - '0';
            }
    }
    int ox = 8 + (Hh - 1) * hx, oy = 24;
    for (int pass = 0; pass < 2; pass++)
        for (int r = 0; r < Hh; r++) for (int c = 0; c < W; c++)
            {
                int X = ox + (c - r) * hx, Y = oy + (c + r) * hy; char ch = At(c, r);
                if (pass == 0) { if (floor[c, r]) Draw(ch == '.' || ch == '*' || ch == '+' ? gl : fl, X, Y); continue; }
                if (ch == '#') Draw(wl, X, Y + Lift(T, "wall"));
                else if (ch == '$') Draw(bx, X, Y + Lift(T, "box"));
                else if (ch == '*') Draw(bg, X, Y + Lift(T, "box"));
                else if (ch == '@' || ch == '+') { Draw(ma, X, Y + Lift(T, "man")); Draw(yo, X, Y + Lift(T, "you")); }
            }
    int S = 3, PW = SW * S, PH = SH * S;
    var raw = new MemoryStream();
    for (int y = 0; y < PH; y++)
    {
        raw.WriteByte(0);                                // PNG filter: none
        for (int x = 0; x < PW; x++) { var p = pal[img[(y / S) * SW + x / S]]; raw.WriteByte((byte)p.r); raw.WriteByte((byte)p.g); raw.WriteByte((byte)p.b); }
    }
    var z = new MemoryStream();
    using (var zs = new ZLibStream(z, CompressionLevel.Optimal, true)) { raw.Position = 0; raw.CopyTo(zs); }
    uint[] crcT = new uint[256];
    for (uint n = 0; n < 256; n++) { uint cc = n; for (int k = 0; k < 8; k++) cc = (cc & 1) != 0 ? 0xEDB88320 ^ (cc >> 1) : cc >> 1; crcT[n] = cc; }
    uint Crc(byte[] b) { uint cc = 0xFFFFFFFF; foreach (var x in b) cc = crcT[(cc ^ x) & 0xFF] ^ (cc >> 8); return cc ^ 0xFFFFFFFF; }
    using var f = File.Create(path);
    void Be(uint v) { f.WriteByte((byte)(v >> 24)); f.WriteByte((byte)(v >> 16)); f.WriteByte((byte)(v >> 8)); f.WriteByte((byte)v); }
    void Chunk(string t, byte[] d) { Be((uint)d.Length); var td = Encoding.ASCII.GetBytes(t).Concat(d).ToArray(); f.Write(td); Be(Crc(td)); }
    f.Write(new byte[] { 137, 80, 78, 71, 13, 10, 26, 10 });
    var ih = new MemoryStream();
    void B(uint v) { ih.WriteByte((byte)(v >> 24)); ih.WriteByte((byte)(v >> 16)); ih.WriteByte((byte)(v >> 8)); ih.WriteByte((byte)v); }
    B((uint)PW); B((uint)PH); ih.WriteByte(8); ih.WriteByte(2); ih.WriteByte(0); ih.WriteByte(0); ih.WriteByte(0);
    Chunk("IHDR", ih.ToArray()); Chunk("IDAT", z.ToArray()); Chunk("IEND", Array.Empty<byte>());
}
Preview(8, args[2] + "S.PNG");
Preview(12, args[2] + "B.PNG");

// ---- the art as SOKOBAN.ASM includes it ----
var o = new StringBuilder();
foreach (var line in new[] {
    "; ART.INC - SOKOBAN's pictures, one character a pixel:",
    ";  .  see-through     0 black   1 green   2 red   3 yellow",
    ";  S  the man's shirt, P his cap and trousers (SOKOBAN.ASM LOOKS)",
    ";  Two sizes: ..S tiles 16x8 (Z: the whole level), ..B tiles 24x12.",
    ";  First drawn by rule with TOOLS\\ArtGen (C#); edit them freely by hand -",
    ";  keep each row 16 (or 24) characters and each count right." })
    o.Append(line).Append("\r\n");
void Emit(string name, string[] s, string note)
{
    o.Append($"{name}:\tdb {s.Length}\t\t\t; {note}\r\n");
    foreach (var r in s) o.Append($"\tdb '{r}'\r\n");
}
foreach (var T in new[] { 8, 12 })
{
    string zz = T == 8 ? "S" : "B";
    Emit($"FLR{zz}", Floor(T, false), "floor tile");
    Emit($"GOL{zz}", Floor(T, true), "floor with a goal");
    Emit($"WAL{zz}", Wall(T), "brick wall: drawn 6 above the tile");
    Emit($"BOX{zz}", Crate(T, false), $"crate: drawn {-Lift(T, "box")} above the tile");
    Emit($"BOG{zz}", Crate(T, true), "crate on a goal");
    Emit($"MAN{zz}", T == 8 ? man0 : man1, "a man: S shirt, P cap and trousers");
    Emit($"YOU{zz}", T == 8 ? you0 : you1, "the arrow over your own man");
}
File.WriteAllText(args[3], o.ToString(), Encoding.ASCII);
Console.WriteLine($"LEV{want:D2} {W}x{Hh}: {args[2]}S.PNG, {args[2]}B.PNG, {args[3]}");
return 0;
