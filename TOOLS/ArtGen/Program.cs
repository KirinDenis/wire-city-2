// ============================================================================
//  ArtGen - SOKOBAN's CGA pictures, drawn by rule, and a preview of a level
//  drawn the way SOKOBAN.ASM draws it.
//
//      dotnet run --project TOOLS\ArtGen -- GAMES\SOKOBAN\LEVELS.INC 0 PREV ART.INC
//
//  Writes ART.INC (the art as SOKOBAN.ASM includes it: one character a
//  pixel, . see-through, 0 black, 1 green, 2 red, 3 yellow, S and P the
//  man's shirt and cap) and PREVS.PNG, PREVB.PNG: that level at both cell
//  sizes, three times enlarged, in CGA palette 0 bright. ART.INC in the
//  game's folder may have been touched up by hand since: write elsewhere
//  and compare before you copy over it.
//
//  The view is three-quarter: grid rows run across the screen, a cell is
//  CW x CD pixels of floor (16x12, or 8x6 for the whole level), and a block
//  - wall or crate - shows its top face lifted, and its front face under it.
//  Rows are drawn top to bottom, so a nearer block covers the bottom of the
//  cell behind it. Walls are only half a cell high (6 of 12): taller, and a
//  wall in front hides most of a corridor. The isometric first version was
//  prettier, but every arrow went along a diagonal of the screen.
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
string[] Blank(int w, int rows) => Enumerable.Range(0, rows).Select(_ => new string('.', w)).ToArray();

// the two sizes: cell width, cell depth, wall height
(int cw, int cd, int wh) Size(bool big) => big ? (16, 12, 6) : (8, 6, 3);

string[] Floor(bool big, bool goal)
{
    var (cw, cd, _) = Size(big);
    var s = Blank(cw, cd);
    for (int y = 0; y < cd; y++)
        for (int x = 0; x < cw; x++)
            Put(s, x, y, y == 0 || x == 0 ? '1' : Chk(x, y, '1', '0'));  // lit top and left edge
    if (goal)
    {
        // a red ring with a yellow eye in the middle of the cell
        string[] g = big
            ? new[] { "....2222....", "...233332...", "..23333332..", "..23333332..", "...233332...", "....2222...." }
            : new[] { "2332", "2332" };
        int gx = (cw - g[0].Length) / 2, gy = (cd - g.Length) / 2 + (big ? 0 : 0);
        for (int y = 0; y < g.Length; y++)
            for (int x = 0; x < g[y].Length; x++)
                if (g[y][x] != '.') Put(s, gx + x, gy + y, g[y][x]);
    }
    return s;
}

// a wall: its top face (cd rows, a dark red checker under a lit edge), then
// wh rows of front face: a mortar line, then courses of bricks
string[] Wall(bool big)
{
    var (cw, cd, wh) = Size(big);
    var s = Blank(cw, cd + wh);
    for (int y = 0; y < cd; y++)
        for (int x = 0; x < cw; x++)
            Put(s, x, y, y == 0 ? '2' : Chk(x, y, '2', '0'));
    for (int v = 0; v < wh; v++)
        for (int x = 0; x < cw; x++)
        {
            char c;
            if (big)
            {
                // v0 mortar, v1-2 course A, v3 mortar, v4-5 course B
                if (v == 0 || v == 3) c = '0';
                else if (v < 3) c = (x & 7) == 7 ? '0' : '2';
                else c = (x & 7) == 3 ? '0' : '2';
            }
            else
            {
                // v0 mortar, v1-2 one course, short bricks
                c = v == 0 || (x & 3) == 3 ? '0' : '2';
            }
            Put(s, x, cd + v, c);
        }
    return s;
}

// a crate, a pixel in from the cell's sides: top face, then front face,
// each a red frame round yellow boards (green on a goal)
string[] Crate(bool big, bool onGoal)
{
    var (cw, _, _) = Size(big);
    int top = big ? 10 : 5, front = big ? 7 : 4;
    char fill = onGoal ? '1' : '3';
    var s = Blank(cw, top + front);
    for (int y = 0; y < top + front; y++)
        for (int x = 1; x < cw - 1; x++)
        {
            bool face = y >= top;
            int v = face ? y - top : y, h = face ? front : top;
            bool frame = x == 1 || x == cw - 2 || v == 0 || v == h - 1;
            bool plank = big && !frame && (face ? v == h / 2 : (x == cw / 2 - 1 || x == cw / 2));
            Put(s, x, y, frame || plank ? '2' : fill);
        }
    return s;
}

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
string[] manB = man1.Select(r => r.Substring(4, 16)).ToArray();
string[] manS = {
    "..0000..",
    ".0PPPP0.",
    ".033330.",
    "..0000..",
    "0SSSSSS0",
    "3SSSSSS3",
    ".0SSSS0.",
    ".0PPPP0.",
    ".0P00P0.",
    ".00..00.",
};
string[] youB = { "......3333......", ".......33......." };
string[] youS = { "..3333..", "...33..." };
string[] Man(string[] art, char sh, char pa) => art.Select(r => r.Replace('S', sh).Replace('P', pa)).ToArray();

// where each picture's top row goes against its cell's top row Y - the
// numbers in SOKOBAN.ASM's zoom records ZS and ZB
int Lift(bool big, string kind) => kind switch
{
    "wall" => big ? -6 : -3,
    "box" => big ? -5 : -3,       // the front face ends on the cell's last row
    "man" => big ? -8 : -4,       // feet two rows above it
    "you" => big ? -11 : -7,
    _ => 0
};

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

void Preview(bool big, string path)
{
    var (cw, cd, wh) = Size(big);
    var fl = Floor(big, false); var gl = Floor(big, true); var wl = Wall(big);
    var bx = Crate(big, false); var bg = Crate(big, true);
    var ma = Man(big ? manB : manS, '3', '2'); var yo = big ? youB : youS;
    var mb = Man(big ? manB : manS, '2', '1');
    int SW = Math.Max(320, W * cw + 16), SH = Math.Max(200, Hh * cd + 40);
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
    int ox = 8, oy = 24, extra = 0;
    for (int pass = 0; pass < 2; pass++)
        for (int r = 0; r < Hh; r++) for (int c = 0; c < W; c++)
            {
                int X = ox + c * cw, Y = oy + r * cd; char ch = At(c, r);
                if (pass == 0) { if (floor[c, r]) Draw(ch == '.' || ch == '*' || ch == '+' ? gl : fl, X, Y); continue; }
                if (ch == '#') Draw(wl, X, Y + Lift(big, "wall"));
                else if (ch == '$') Draw(bx, X, Y + Lift(big, "box"));
                else if (ch == '*') Draw(bg, X, Y + Lift(big, "box"));
                else if (ch == '@' || ch == '+') { Draw(ma, X, Y + Lift(big, "man")); Draw(yo, X, Y + Lift(big, "you")); }
                else if (floor[c, r] && ch == ' ' && extra == 0 && c > mc + 2) { Draw(mb, X, Y + Lift(big, "man")); extra++; }
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
Preview(false, args[2] + "S.PNG");
Preview(true, args[2] + "B.PNG");

// ---- the art as SOKOBAN.ASM includes it ----
var o = new StringBuilder();
foreach (var line in new[] {
    "; ART.INC - SOKOBAN's pictures, one character a pixel:",
    ";  .  see-through     0 black   1 green   2 red   3 yellow",
    ";  S  the man's shirt, P his cap and trousers (SOKOBAN.ASM LOOKS)",
    ";  Two sizes: ..B cells 16x12 (close up), ..S cells 8x6 (Z: the whole",
    ";  level). First drawn by rule with TOOLS\\ArtGen (C#); edit them freely",
    ";  by hand - keep each row 16 (or 8) characters and each count right." })
    o.Append(line).Append("\r\n");
void Emit(string name, string[] s, string note)
{
    o.Append($"{name}:\tdb {s.Length}\t\t\t; {note}\r\n");
    foreach (var r in s) o.Append($"\tdb '{r}'\r\n");
}
foreach (var big in new[] { false, true })
{
    string zz = big ? "B" : "S";
    Emit($"FLR{zz}", Floor(big, false), "floor");
    Emit($"GOL{zz}", Floor(big, true), "floor with a goal");
    Emit($"WAL{zz}", Wall(big), $"brick wall: drawn {-Lift(big, "wall")} above the cell");
    Emit($"BOX{zz}", Crate(big, false), $"crate: drawn {-Lift(big, "box")} above the cell");
    Emit($"BOG{zz}", Crate(big, true), "crate on a goal");
    Emit($"MAN{zz}", big ? manB : manS, $"a man, S shirt, P cap and trousers: {-Lift(big, "man")} above");
    Emit($"YOU{zz}", big ? youB : youS, "the arrow over your own man");
}
File.WriteAllText(args[3], o.ToString(), Encoding.ASCII);
Console.WriteLine($"LEV{want:D2} {W}x{Hh}: {args[2]}S.PNG, {args[2]}B.PNG, {args[3]}");
return 0;
