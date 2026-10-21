// ============================================================================
//  ArtGen - MULTSOKO's CGA pictures, drawn by rule, and a preview of a level
//  drawn the way MULTSOKO.ASM draws it.
//
//      dotnet run --project TOOLS\ArtGen -- GAMES\MULTSOKO\LEVELS.INC 1 PREV ART.INC
//
//  Writes ART.INC (the art as MULTSOKO.ASM includes it: one character a
//  pixel, . see-through, 0 black, 1 green, 2 red, 3 yellow, S and P the
//  man's shirt and cap) and PREVS.PNG, PREVB.PNG: that level at both cell
//  sizes, three times enlarged, in CGA palette 0 bright, with a ticking
//  mine and a blast beside the man. ART.INC in the game's folder may have
//  been touched up by hand since: write elsewhere and compare before you
//  copy over it.
//
//  The view is straight down: a cell is a square, 16x16 (or 8x8 for the
//  whole level), and nothing stands in front of anything. The players got
//  lost in the isometric version and then in the three-quarter one; seen
//  from above, a wall is a patch of brickwork - red bricks in black mortar,
//  each course shifted half a brick - and a crate a box with a cross.
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
string[] Blank(int n) => Enumerable.Range(0, n).Select(_ => new string('.', n)).ToArray();

string[] Floor(int n, bool goal)
{
    var s = Blank(n);
    for (int y = 0; y < n; y++)
        for (int x = 0; x < n; x++)
            Put(s, x, y, y == 0 || x == 0 ? '1' : Chk(x, y, '1', '0'));   // lit top and left edge
    if (goal)
    {
        string[] g = n == 16
            ? new[] { "...2222...", "..233332..", ".23333332.", ".23333332.", "..233332..", "...2222..." }
            : new[] { "2332", "2332" };
        int gx = (n - g[0].Length + 1) / 2, gy = (n - g.Length + 1) / 2;
        for (int y = 0; y < g.Length; y++)
            for (int x = 0; x < g[y].Length; x++)
                if (g[y][x] != '.') Put(s, gx + x, gy + y, g[y][x]);
    }
    return s;
}

// brickwork from above: courses of bricks, a mortar row under each, the
// joints of every other course half a brick along; a yellow glint on each
// brick's top left corner
string[] Wall(int n)
{
    var s = Blank(n);
    int course = n == 16 ? 4 : 4, brick = n == 16 ? 8 : 4;
    for (int y = 0; y < n; y++)
        for (int x = 0; x < n; x++)
        {
            int c = y / course, v = y % course;
            int u = (x + (c % 2 == 1 ? brick / 2 : 0)) % brick;
            char ch = v == course - 1 || u == brick - 1 ? '0' : (v == 0 && u == 0 && n == 16 ? '3' : '2');
            Put(s, x, y, ch);
        }
    return s;
}

// a crate from above: a red frame, yellow boards (green on a goal), a cross
string[] Crate(int n, bool onGoal)
{
    var s = Blank(n);
    char fill = onGoal ? '1' : '3';
    for (int y = 1; y < n - 1; y++)
        for (int x = 1; x < n - 1; x++)
        {
            bool frame = x == 1 || y == 1 || x == n - 2 || y == n - 2 || (n == 16 && (x == 2 || y == 2 || x == n - 3 || y == n - 3));
            bool cross = n == 16 && (x == y || x + y == n - 1 || x == y + 1 || x + 1 == y);
            Put(s, x, y, frame || cross ? '2' : fill);
        }
    return s;
}

string[] manB = {
    "......0000......",
    ".....0PPPP0.....",
    ".....0PPPP0.....",
    ".....033330.....",
    ".....030030.....",
    ".....033330.....",
    "......0000......",
    "...00SSSSSS00...",
    "..0SSSSSSSSSS0..",
    "..0S0SSSSSS0S0..",
    "..030SSSSSS030..",
    "...00SSSSSS00...",
    "....0PPPPPP0....",
    "....0PP00PP0....",
    "....0PP00PP0....",
    "...0000..0000...",
};
string[] manS = {
    "..0000..",
    "..0PP0..",
    "..0330..",
    ".0SSSS0.",
    "3SSSSSS3",
    ".0SSSS0.",
    "..P00P..",
    ".00..00.",
};
// your own man: four yellow corners round his cell
string[] youB = {
    "333..........333",
    "3..............3",
    "3..............3",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "3..............3",
    "3..............3",
    "333..........333",
};
string[] youS = { "33....33", "3......3", "........", "........", "........", "........", "3......3", "33....33" };
// a mine: a black ball with a lit fuse; its seconds are printed on it
string[] mineB = {
    "..........3.....",
    ".........3.2....",
    "........2.......",
    "......0000......",
    "....00000000....",
    "...0000000000...",
    "...0000000000...",
    "..000000000000..",
    "..000000000000..",
    "..000000000000..",
    "..000000000000..",
    "...0000000000...",
    "...0000000000...",
    "....00000000....",
    "......0000......",
    "................",
};
string[] mineS = { ".....3..", "....2...", "..0000..", ".000000.", ".000000.", ".000000.", "..0000..", "........" };
// the blast, on each of the nine cells for half a second
string[] blastB = {
    "3.....2..2.....3",
    ".3...232232...3.",
    "..3..233332..3..",
    "...323333332.3..",
    "....23333332....",
    ".22233333333222.",
    "2333333333333332",
    ".23333333333332.",
    ".23333333333332.",
    "2333333333333332",
    ".22233333333222.",
    "....23333332....",
    "..3.23333332.3..",
    "..3..233332..3..",
    ".3...232232...3.",
    "3.....2..2.....3",
};
string[] blastS = { "3..22..3", ".323323.", ".233332.", "23333332", "23333332", ".233332.", ".323323.", "3..22..3" };
string[] Man(string[] art, char sh, char pa) => art.Select(r => r.Replace('S', sh).Replace('P', pa)).ToArray();

// ---- the isometric set (V in the game): 2:1 diamonds 24x12 -------------
// A diamond of half-width t in a canvas 24 wide: row y spans [12-hw, 11+hw],
// hw = t - 2|y - (t/2 - 0.5)| - rows 2, 6, 10 ... wide, so neighbours meet
// without a gap. Walls are blocks only 6 px high: taller, and the walls in
// front hide the crates in a one-tile corridor (the first tries had 8).
const int T = 12;
(int a, int b) Span(int t, int y)
{
    int hw = t - (int)Math.Round(2 * Math.Abs(y - (t / 2.0 - 0.5)));
    return (T - hw, T - 1 + hw);
}
string[] IBlank(int rows) => Enumerable.Range(0, rows).Select(_ => new string('.', 2 * T)).ToArray();
string[] IsoFloor(bool goal)
{
    var s = IBlank(T);
    for (int y = 0; y < T; y++)
    {
        var (a, b) = Span(T, y);
        for (int x = a; x <= b; x++)
        {
            bool edge = x <= a + 1 || x >= b - 1;
            Put(s, x, y, edge ? (y < T / 2 ? '1' : '0') : Chk(x, y, '1', '0'));
        }
    }
    if (goal)
    {
        int g = T / 2;
        for (int y = 0; y < g; y++)
        {
            var (a, b) = Span(g, y);
            for (int x = a; x <= b; x++)
                Put(s, x, y + T / 4, x <= a + 1 || x >= b - 1 || y == 0 || y == g - 1 ? '2' : '3');
        }
    }
    return s;
}
// a block of half-width t: its top diamond, then H rows of faces under it
string[] IsoBlock(int t, int H, Func<int, int, char> top, Func<bool, int, int, int, char> face)
{
    var s = IBlank(t + H);
    for (int y = 0; y < t; y++) { var (a, b) = Span(t, y); for (int x = a; x <= b; x++) Put(s, x, y, top(x, y)); }
    var (wa, wb) = Span(t, t / 2);
    int wf = T - wa;
    for (int x = wa; x <= wb; x++)
    {
        bool left = x < T;
        int last = 0;
        for (int y = t - 1; y >= 0; y--) { var (a, b) = Span(t, y); if (x >= a && x <= b) { last = y; break; } }
        int u = left ? x - wa : wb - x;
        for (int v = 0; v < H; v++) Put(s, x, last + 1 + v, face(left, u, v, wf));
    }
    return s;
}
string[] IsoWall() => IsoBlock(T, 6,
    (x, y) => { var (a, b) = Span(T, y); return y < T / 2 && (x <= a + 1 || x >= b - 1) ? '2' : Chk(x, y, '2', '0'); },
    (left, u, v, wf) => v == 0 || v == 3 ? '0' : v < 3 ? (u == wf / 2 ? '0' : '2') : (u == wf / 4 || u == 3 * wf / 4 ? '0' : '2'));
string[] IsoCrate(bool onGoal)
{
    char fill = onGoal ? '1' : '3';
    const int t = 8, H = 10;
    return IsoBlock(t, H,
        (x, y) => { var (a, b) = Span(t, y); return x <= a + 1 || x >= b - 1 ? '2' : fill; },
        (left, u, v, wf) =>
        {
            bool frame = u == 0 || u == wf - 1 || v == 0 || v == H - 1;
            double d = v - (double)u * (H - 1) / (wf - 1);
            bool brace = left && Math.Abs(d) < 0.75 || !left && v == H / 2;
            return frame || brace ? '2' : fill;
        });
}
string[] IsoBlast()
{
    var s = IBlank(T);
    for (int y = 0; y < T; y++)
    {
        var (a, b) = Span(T, y);
        for (int x = a; x <= b; x++) Put(s, x, y, x <= a + 1 || x >= b - 1 ? '2' : ((x + 2 * y) % 5 == 0 ? '2' : '3'));
    }
    return s;
}
string[] manI = manB.Select(r => "...." + r + "....").ToArray();
string[] youI = { ".........333333.........", "..........3333..........", "...........33..........." };
string[] mineI = {
    "............3...........",
    "...........3.2..........",
    "..........2.............",
    ".........000000.........",
    "........00000000........",
    ".......0000000000.......",
    ".......0000000000.......",
    ".......0000000000.......",
    "........00000000........",
    ".........000000.........",
};
// where each isometric picture's top row goes against its tile's top row Y -
// the numbers in MULTSOKO.ASM's zoom record ZI
int ILift(string kind) => kind switch { "wall" => -6, "box" => -8, "man" => -8, "you" => -11, "mine" => -2, _ => 0 };

// ---- the level, out of LEVELS.INC ----
int want = int.Parse(args[1]);
var inc = File.ReadAllLines(args[0]);
int at = Array.FindIndex(inc, l => l.StartsWith($"LEV{want:D2}:"));
if (at < 0) { Console.Error.WriteLine($"no LEV{want:D2} in {args[0]}"); return 1; }
var wh0 = Regex.Match(inc[at], @"db\s+(\d+),(\d+)");
int W = int.Parse(wh0.Groups[1].Value), Hh = int.Parse(wh0.Groups[2].Value);
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

void Preview(int n, string path)
{
    var fl = Floor(n, false); var gl = Floor(n, true); var wl = Wall(n);
    var bx = Crate(n, false); var bg = Crate(n, true);
    var ma = Man(n == 16 ? manB : manS, '3', '2'); var mb = Man(n == 16 ? manB : manS, '2', '1');
    var yo = n == 16 ? youB : youS; var mi = n == 16 ? mineB : mineS; var bl = n == 16 ? blastB : blastS;
    int SW = Math.Max(320, W * n + 16), SH = Math.Max(200, Hh * n + 16);
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
    int ox = 8, oy = 8;
    // a second man two cells right of the start if that is floor, a mine left of it, a blast below
    for (int r = 0; r < Hh; r++) for (int c = 0; c < W; c++)
        {
            int X = ox + c * n, Y = oy + r * n; char ch = At(c, r);
            if (ch == '#') { Draw(wl, X, Y); continue; }
            if (!floor[c, r]) continue;
            Draw(ch == '.' || ch == '*' || ch == '+' ? gl : fl, X, Y);
            if (r == mr && c == mc - 1 && ch == ' ') Draw(mi, X, Y);
            if (ch == '$') Draw(bx, X, Y);
            else if (ch == '*') Draw(bg, X, Y);
            else if (ch == '@' || ch == '+') { Draw(ma, X, Y); Draw(yo, X, Y); }
            else if (r == mr - 1 && c == mc && floor[c, r]) Draw(mb, X, Y);
        }
    if (mr + 2 < Hh) Draw(bl, ox + mc * n, oy + (mr + 2) * n);
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
    for (uint q = 0; q < 256; q++) { uint cc = q; for (int k = 0; k < 8; k++) cc = (cc & 1) != 0 ? 0xEDB88320 ^ (cc >> 1) : cc >> 1; crcT[q] = cc; }
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
Preview(16, args[2] + "B.PNG");
PreviewIso(args[2] + "I.PNG");

// the isometric preview: tile (c,r) at x = (c-r)*12, y = (c+r)*6, every
// floor first, then row by row walls, crates, the man - as the game does
void PreviewIso(string path)
{
    var fl = IsoFloor(false); var gl = IsoFloor(true); var wl = IsoWall(); var bx = IsoCrate(false); var bg = IsoCrate(true);
    var ma = Man(manI, '3', '2'); var mi = mineI; var bl = IsoBlast();
    int SW = Math.Max(320, (W + Hh) * T + 16), SH = Math.Max(200, (W + Hh) * T / 2 + 40);
    var img = new int[SW * SH];
    void Draw(string[] spr, int X, int Y)
    {
        for (int y = 0; y < spr.Length; y++)
            for (int x = 0; x < spr[y].Length; x++)
            {
                char ch = spr[y][x]; if (ch == '.') continue;
                int px = X + x, py = Y + y;
                if (px >= 0 && py >= 0 && px < SW && py < SH) img[py * SW + px] = ch - '0';
            }
    }
    int ox = 8 + (Hh - 1) * T, oy = 24;
    for (int pass = 0; pass < 2; pass++)
        for (int r = 0; r < Hh; r++) for (int c = 0; c < W; c++)
            {
                int X = ox + (c - r) * T, Y = oy + (c + r) * T / 2; char ch = At(c, r);
                if (pass == 0) { if (floor[c, r]) Draw(ch == '.' || ch == '*' || ch == '+' ? gl : fl, X, Y); continue; }
                if (r == mr - 1 && c == mc && floor[c, r]) Draw(bl, X, Y);
                if (ch == '#') Draw(wl, X, Y + ILift("wall"));
                else if (ch == '$') Draw(bx, X, Y + ILift("box"));
                else if (ch == '*') Draw(bg, X, Y + ILift("box"));
                else if (ch == '@' || ch == '+') { Draw(ma, X, Y + ILift("man")); Draw(youI, X, Y + ILift("you")); }
                else if (r == mr && c == mc + 1 && floor[c, r]) Draw(mi, X, Y + ILift("mine"));
            }
    int S = 3, PW = SW * S, PH = SH * S;
    var raw = new MemoryStream();
    for (int y = 0; y < PH; y++)
    {
        raw.WriteByte(0);
        for (int x = 0; x < PW; x++) { var p = pal[img[(y / S) * SW + x / S]]; raw.WriteByte((byte)p.r); raw.WriteByte((byte)p.g); raw.WriteByte((byte)p.b); }
    }
    var z = new MemoryStream();
    using (var zs = new ZLibStream(z, CompressionLevel.Optimal, true)) { raw.Position = 0; raw.CopyTo(zs); }
    uint[] crcT = new uint[256];
    for (uint q = 0; q < 256; q++) { uint cc = q; for (int k = 0; k < 8; k++) cc = (cc & 1) != 0 ? 0xEDB88320 ^ (cc >> 1) : cc >> 1; crcT[q] = cc; }
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

// ---- the art as MULTSOKO.ASM includes it ----
var o = new StringBuilder();
foreach (var line in new[] {
    "; ART.INC - MULTSOKO's pictures, one character a pixel:",
    ";  .  see-through     0 black   1 green   2 red   3 yellow",
    ";  S  the man's shirt, P his cap and trousers (MULTSOKO.ASM LOOKS)",
    ";  Seen straight down, a cell each: ..B 16x16 (close up), ..S 8x8 (Z:",
    ";  the whole level). First drawn by rule with TOOLS\\ArtGen (C#); edit",
    ";  them freely by hand - keep each row 16 (or 8) characters, 16 (or 8)",
    ";  rows to a picture." })
    o.Append(line).Append("\r\n");
void Emit(string name, string[] s, string note)
{
    o.Append($"{name}:\tdb {s.Length}\t\t\t; {note}\r\n");
    foreach (var r in s) o.Append($"\tdb '{r}'\r\n");
}
foreach (var n in new[] { 8, 16 })
{
    string zz = n == 16 ? "B" : "S";
    Emit($"FLR{zz}", Floor(n, false), "floor");
    Emit($"GOL{zz}", Floor(n, true), "floor with a goal");
    Emit($"WAL{zz}", Wall(n), "brick wall");
    Emit($"BOX{zz}", Crate(n, false), "crate");
    Emit($"BOG{zz}", Crate(n, true), "crate on a goal");
    Emit($"MAN{zz}", n == 16 ? manB : manS, "a man: S shirt, P cap and trousers");
    Emit($"YOU{zz}", n == 16 ? youB : youS, "the corners round your own man");
    Emit($"MIN{zz}", n == 16 ? mineB : mineS, "a mine, ticking");
    Emit($"BLA{zz}", n == 16 ? blastB : blastS, "the blast, on each of its nine cells");
}
// the isometric set: 24 px wide, each drawn ILift rows above its tile
Emit("FLRI", IsoFloor(false), "isometric floor tile");
Emit("GOLI", IsoFloor(true), "isometric goal");
Emit("WALI", IsoWall(), $"isometric brick wall: drawn {-ILift("wall")} above the tile");
Emit("BOXI", IsoCrate(false), $"isometric crate: drawn {-ILift("box")} above the tile");
Emit("BOGI", IsoCrate(true), "isometric crate on a goal");
Emit("MANI", manI, $"isometric man: drawn {-ILift("man")} above the tile");
Emit("YOUI", youI, $"the arrow over your own man: drawn {-ILift("you")} above");
Emit("MINI", mineI, $"isometric mine: drawn {-ILift("mine")} above the tile");
Emit("BLAI", IsoBlast(), "the blast on an isometric tile");
File.WriteAllText(args[3], o.ToString(), Encoding.ASCII);
Console.WriteLine($"LEV{want:D2} {W}x{Hh}: {args[2]}S.PNG, {args[2]}B.PNG, {args[3]}");
return 0;
