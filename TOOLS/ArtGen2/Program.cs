// ============================================================================
//  ArtGen2 - MULTIPLAY SOKO II's pictures: drawn by rule and by hand at 16
//  pixels a cell, brought down to 12, 10, 8 and 6, laid onto isometric
//  tiles; the game's own sixteen colours; and previews of a level drawn the
//  way the game draws it, on each of its cards (EGA/VGA, CGA, Hercules).
//  (TOOLS\ArtGen is the first MULTIPLAY SOKO's, and stays as it is.)
//
//      dotnet run --project TOOLS\ArtGen2 -- GAMES\MULTSOK2\LEVELS.INC 0 PREV GAMES\MULTSOK2
//
//  writes, in the folder named last:
//    KINDS.INC  NKIND, NSIZE, NWATER and a K_ number per kind - MULTSOK2.ASM's
//    ART.INC    the data ART.ASM turns into ART.DAT: a magic, the palette
//               (16 x R,G,B, 0..63, for a VGA's DAC), the CGA map (16 x 4:
//               each colour's 2x2 half-tone in CGA palette 1), the Hercules
//               brightness (16 x 0..4), then ARTDIR - a word per picture,
//               NKIND for each size 16, 12, 10, 8, 6, then NKIND for the
//               isometric view and its floor - then the pictures: db width,
//               height, and the rows, one character a pixel -
//                 .  see-through        0..9 A..F  a colour of the sixteen
//                 S s  the man's shirt and its shade   P p  his cap and trousers
//  A picture stands on its cell's bottom row, centred across it: a tall
//  one rises over the cell above, a wide one (32 at 16 px) over the next.
//
//  The look, the pilot's: the floor the men walk on BLACK and bare - only
//  what is played with on it, so the eye never hunts; the walls big grey
//  stones, juicy lime-green growth on their outer side; round it a park
//  with free-standing things, rippling water, towers with red roofs.
//  Light from the top left.
// ============================================================================
using System.IO.Compression;
using System.Text;
using System.Text.RegularExpressions;

if (args.Length != 4)
{
    Console.Error.WriteLine("usage: ArtGen2 <LEVELS.INC> <level number> <preview prefix> <out folder>");
    return 1;
}

// the game's sixteen, as a VGA's DAC takes them (0..63); a real EGA shows
// its own sixteen instead, which these keep the hue of, colour by colour.
// The greens are the EGA's own, juicy: the pilot's reference.
int[,] dac = {
    { 0, 0, 0 }, { 2, 6, 26 }, { 0, 38, 4 }, { 6, 26, 36 }, { 36, 8, 4 }, { 38, 14, 42 }, { 40, 22, 8 }, { 44, 44, 42 },
    { 21, 21, 22 }, { 16, 34, 63 }, { 24, 63, 18 }, { 42, 60, 63 }, { 60, 20, 12 }, { 63, 34, 50 }, { 63, 56, 18 }, { 63, 63, 63 } };
var pal = Enumerable.Range(0, 16).Select(i => (r: dac[i, 0] * 255 / 63, g: dac[i, 1] * 255 / 63, b: dac[i, 2] * 255 / 63)).ToArray();
// the looks: shirt, its shade, cap and trousers, their shade (MULTSOK2.ASM LOOKS)
var looks = new[] { "E691", "C4A2", "B3D5", "A2C4", "F7E6", "D5B3" };
int[] Look(int l) => looks[l].Select(c => Convert.ToInt32(c.ToString(), 16)).ToArray();

string[] Pic(int w, int h, Func<int, int, char> f) =>
    Enumerable.Range(0, h).Select(y => new string(Enumerable.Range(0, w).Select(x => f(x, y)).ToArray())).ToArray();
string[] Grid(int n, Func<int, int, char> f) => Pic(n, n, f);
double Dist(double x, double y, double cx, double cy) => Math.Sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy));
string[] Check(string[] s, int w, int h)
{
    foreach (var r in s) if (r.Length != w) throw new Exception($"a row of {r.Length}, not {w}: '{r}'");
    if (s.Length != h) throw new Exception($"{s.Length} rows, not {h}");
    return s;
}
string[] Over(string[] bottom, string[] top) =>
    bottom.Select((r, y) => new string(r.Select((c, x) => top[y][x] == '.' ? c : top[y][x]).ToArray())).ToArray();
bool Chk(int x, int y) => ((x + y) & 1) == 0;
int H2(int a, int b) { int x = (a * 73856093) ^ (b * 19349663); x ^= x >> 13; x *= 0x5bd1e995; x ^= x >> 15; return x & 0x7FFFFFFF; }
// a rounded thing lit from the top left: its colour by where on it a pixel is
char Shade(double nx, double ny, string ramp)   // ramp: highlight, lit, mid, shade, dark
{
    double l = -(nx + ny) * 0.7071, d = nx * nx + ny * ny;
    if (l > 0.55 && d < 0.5) return ramp[0];
    if (l > 0.15) return ramp[1];
    if (l > -0.25) return ramp[2];
    if (l > -0.6) return ramp[3];
    return ramp[4];
}
// leaves: lime where the light is, half-tone into green, green, then dark
char Leaf(double nx, double ny, int x, int y)
{
    double l = -(nx + ny) * 0.7071;
    if (l > 0.25) return H2(x, y) % 9 == 0 ? '2' : 'A';
    if (l > -0.2) return Chk(x, y) ? 'A' : '2';
    if (l > -0.6) return '2';
    return Chk(x, y) ? '2' : '0';
}
// a blob of leaves: a few round lobes; true where a pixel is in one
char Foliage(int x, int y, (double cx, double cy, double r)[] lobes)
{
    double best = 9; int at = -1;
    for (int i = 0; i < lobes.Length; i++)
    {
        double d = Dist(x + 0.5, y + 0.5, lobes[i].cx, lobes[i].cy) / lobes[i].r;
        if (d < 1 && (at < 0 || lobes[i].cy > lobes[at].cy || d < best)) { if (at < 0 || lobes[i].cy >= lobes[at].cy) { best = d; at = i; } }
    }
    if (at < 0) return '.';
    var (lx, ly, lr) = lobes[at];
    if (best > 0.86) return '0';
    return Leaf((x + 0.5 - lx) / lr, (y + 0.5 - ly) / lr, x, y);
}

// ---- the playing field: black.  A goal is a red mark ringed in gold ------
string[] Goal() => Grid(16, (x, y) =>
{
    double d = Dist(x + 0.5, y + 0.5, 8, 8);
    if (d < 1.4) return 'F';
    if (d < 3.4) return x + y < 15 ? 'C' : '4';
    if (d < 4.3) return '0';
    if (d < 5.6) return x + y < 15 ? 'E' : '6';
    if (d < 6.2) return '4';
    return '.';
});
// a candy, Pac-Man's: a little lit ball - green 1, gold 2, pink 3 points
string[] Candy(int v) => Grid(16, (x, y) =>
{
    double r = 1.8 + v * 0.42, nx = (x + 0.5 - 8) / r, ny = (y + 0.5 - 8) / r;
    if (nx * nx + ny * ny > 1) return '.';
    string ramp = v == 1 ? "FAA22" : v == 2 ? "FEE66" : "FDD55";
    return Shade(nx, ny, ramp);
});

// ---- the wall: big grey stones, three courses of two, every other course
//      half a stone along; each stone lit on its top and left, shaded on
//      its bottom and right, its corners rounded off into the dark joints;
//      the variants move the courses and darken a stone or two ----------
string[] Stones(int v) => Grid(16, (x, y) =>
{
    int course = y < 5 ? 0 : y < 11 ? 1 : 2;
    int top = course == 0 ? 0 : course == 1 ? 5 : 11, bot = course == 0 ? 4 : course == 1 ? 10 : 15;
    int shift = ((course + v) % 2) * 4 + (v % 3);
    int bx = (x + shift) % 8, stone = (x + shift) / 8 + course * 3 + v * 7;
    int sy = y - top, sh = bot - top;
    if (bx == 7 || y == bot) return '0';                                  // the joints
    bool corner = (bx == 0 || bx == 6) && (sy == 0 || sy == sh - 1);
    if (corner) return '0';
    bool dark = H2(stone, 5) % 5 == 0;
    char lit = dark ? '7' : 'F', body = dark ? '8' : '7', shade = dark ? '0' : '8';
    if (sy == 0 || bx == 0) return lit;
    if (sy == sh - 1 || bx == 6) return shade;
    if (H2(x * 3 + v, y) % 11 == 0) return shade;                         // a pit in the stone
    return body;
});
// growth on a wall's outer side: lime lobes over its edge (rule, any size)
string[] Growth(int n, int side)
{
    double r = n / 4.0, depth = n * 0.30;
    var lobes = new List<(double, double, double)>();
    for (int i = 0; i <= 3; i++)
    {
        double b = (i + 0.5) * n / 3.0 - n / 6.0 + (H2(i, side) % 3 - 1) * n / 16.0;
        double rr = r * (0.8 + (H2(side, i) % 3) * 0.15);
        double a = depth - rr * 0.35;
        (double cx, double cy) = side switch { 0 => (b, a), 1 => (n - a, b), 2 => (b, n - a), _ => (a, b) };
        lobes.Add((cx, cy, rr));
    }
    var arr = lobes.ToArray();
    return Grid(n, (x, y) =>
    {
        char c = Foliage(x, y, arr);
        if (c != '.' && c != '0' && H2(x + side * 9, y) % 29 == 0) return side % 2 == 0 ? 'D' : 'E';  // a flower
        return c;
    });
}
// the gate: a gatehouse of red brick, its arch, and the portcullis - gold
// bars down, half raised, up
string[] Gate(int open) => Grid(16, (x, y) =>
{
    bool hole = (y >= 7 && x >= 3 && x <= 12) || (y < 7 && Dist(x + 0.5, y + 0.5, 8, 7.5) < 5.1 && y >= 3);
    if (!hole)
    {
        int course = y / 3, u = (x + (course % 2) * 2) % 4;
        if (y % 3 == 2 || u == 3) return '0';
        return y % 3 == 0 ? 'C' : (x < 3 ? 'C' : '4');
    }
    int bottom = open == 0 ? 15 : open == 1 ? 9 : 4;
    bool bar = y <= bottom && (x % 2 == 0 || y == 6 || y == 10 || y == bottom);
    if (bar) return y == bottom && x % 2 == 0 ? 'F' : (x % 2 == 0 ? 'E' : '6');
    if (open == 2 && y >= 12) return '8';
    return '0';
});
string[] Bridge(bool across) => Grid(16, (x, y) =>
{
    int a = across ? y : x, b = across ? x : y;
    if (a <= 1 || a >= 14) return a == 0 || a == 15 ? '0' : '8';
    if (b % 4 == 3) return '0';
    if (b % 4 == 0) return 'E';
    return (a * 5 + b) % 9 == 0 ? '0' : '6';
});
// the moat, four frames: deep water; ripples - short light dashes on every
// fourth row - that move along two pixels a frame; a glint.  Every
// pattern repeats in 16, so the cells meet without a seam
string[] Water(int f) => Grid(16, (x, y) =>
{
    if (f == 4)                                                // a gust: the water torn up, white caps
    {
        int g = (x + y * 3) % 6;
        if (y % 3 == 0 && g < 3) return g == 1 ? 'F' : 'B';
        if (y % 3 == 1 && g < 4) return '9';
        if (H2(x, y + 77) % 5 == 0) return '3';
        return '1';
    }
    int lane = y / 4, u = (x + 16 - 2 * f + lane * 5) % 8;
    if (y % 4 == 1 && u < 3) return u == 1 ? 'B' : '9';
    if (y % 4 == 2 && u == 1) return '3';
    if (((x * 5 + y * 3 + f * 4) & 15) == 0 && y % 4 == 3) return 'B';
    return '1';
});
string[] Bank(int n, int side)
{
    int k = Math.Max(1, (n * 3 + 8) / 16);
    return Grid(n, (x, y) =>
    {
        int a = side switch { 0 => y, 1 => n - 1 - x, 2 => n - 1 - y, _ => x };
        int b = side switch { 0 => x, 1 => y, 2 => x, _ => y };
        if (a >= k + 1) return '.';
        if (a == k) return Chk(x, y) ? '0' : '.';
        return (b * 7 + a * 3) % 5 == 0 ? '8' : (H2(b, a) % 3 == 0 ? '7' : '6');
    });
}
// the park's grass: green, blades of lime, a dark speck
string[] Grass(bool stone) => Grid(16, (x, y) =>
{
    int h = H2(x + (stone ? 40 : 0), y);
    if (stone && Dist(x + 0.5, y + 0.5, 11, 5) < 1.7) return x + y < 16 ? '7' : '8';
    if (h % 9 == 0) return 'A';
    if (h % 9 == 1 && y < 15 && H2(x, y + 1) % 9 != 0) return 'A';
    if (h % 8 == 2) return '0';
    return '2';
});
// a meadow in the sun: lime half-tone through the green
string[] Meadow() => Grid(16, (x, y) =>
{
    int h = H2(x + 13, y + 29);
    if (h % 11 == 1) return 'E';                               // a buttercup
    if (h % 13 == 2) return '0';
    return h % 3 == 0 ? 'A' : '2';
});
// the floor of a pine wood: dark, needles and earth
string[] Forest() => Grid(16, (x, y) =>
{
    int h = H2(x + 51, y + 3);
    if (h % 9 == 0) return '6';
    if (h % 5 == 1) return '2';
    return Chk(x, y) ? '0' : (h % 4 == 0 ? '2' : '0');
});
string[] Road() => Grid(16, (x, y) =>
{
    int h = H2(x + 90, y + 7);
    if (h % 11 == 0) return '8';
    if (h % 17 == 1) return '7';
    if (h % 9 == 2) return 'E';
    return '6';
});

// ---- the park's things.  They stand on their cell's bottom row ----------
string[] Shadow(string[] s, double cx, double cy, double rx, double ry) => Pic(s[0].Length, s.Length, (x, y) =>
    s[y][x] != '.' ? s[y][x] : (Math.Pow((x + 0.5 - cx) / rx, 2) + Math.Pow((y + 0.5 - cy) / ry, 2) < 1 && Chk(x, y) ? '0' : '.'));
string[] Bush() => Shadow(Grid(16, (x, y) => Foliage(x, y, new[] { (5.5, 9.0, 4.6), (10.5, 8.5, 4.8), (8.0, 6.0, 5.0), (8.0, 11.0, 4.2) })), 9.5, 13.5, 7, 2.5);
string[] Tree() => Shadow(Pic(16, 24, (x, y) =>
{
    if (y >= 14 && y <= 21 && x >= 7 && x <= 8) return x == 7 ? '6' : '0';
    return Foliage(x, y, new[] { (8.0, 6.0, 5.6), (4.8, 9.5, 4.4), (11.2, 9.5, 4.4), (8.0, 11.5, 4.5) });
}), 10, 22, 6, 2);
string[] Pine() => Shadow(Pic(16, 32, (x, y) =>
{
    if (y >= 26 && y <= 29 && x >= 7 && x <= 8) return x == 7 ? '6' : '0';
    foreach (var (top, bot, half) in new[] { (0, 9, 3.5), (6, 17, 5.5), (12, 23, 6.8), (18, 27, 7.8) })
    {
        if (y < top || y > bot) continue;
        double w = half * (y - top + 1) / (bot - top + 1);
        double dx = x + 0.5 - 8;
        if (Math.Abs(dx) > w) continue;
        if (Math.Abs(dx) > w - 1 || y == bot) return '0';
        return dx < -w * 0.35 ? 'A' : (dx < w * 0.3 ? (Chk(x, y) ? 'A' : '2') : '2');
    }
    return '.';
}), 10, 30, 6, 2);
// an oak: two cells wide, two tall - a crown of many lobes, a thick trunk
string[] Oak() => Shadow(Pic(32, 32, (x, y) =>
{
    if (y >= 21 && y <= 29 && x >= 14 && x <= 18) return x <= 15 ? '6' : (x == 18 ? '0' : (Chk(x, y) ? '6' : '0'));
    if (y >= 28 && y <= 29 && (x == 13 || x == 19)) return '6';
    return Foliage(x, y, new[] { (16.0, 8.0, 8.0), (8.0, 12.0, 7.0), (24.0, 12.0, 7.0), (11.0, 18.0, 6.5), (21.0, 18.0, 6.5), (16.0, 15.0, 7.5) });
}), 19, 29.5, 12, 2.5);
// a hedge, trimmed square: two cells wide
string[] Hedge() => Pic(32, 16, (x, y) =>
{
    if (x < 1 || x > 30 || y < 3) return '.';
    if (y == 15) return Chk(x, y) ? '0' : '.';
    bool edge = x == 1 || x == 30 || y == 3 || y == 14;
    if ((x == 2 || x == 29) && y == 3) return '.';
    if (edge) return '0';
    if (y <= 6) return H2(x, y) % 7 == 0 ? '2' : 'A';                    // the top, in the light
    return H2(x, y) % 5 == 0 ? 'A' : (Chk(x, y) ? '2' : (H2(x, y + 3) % 3 == 0 ? '0' : '2'));
});
// a flower bed in a stone border: a mound of leaves, big bright blooms
string[] FlowerBed() => Pic(32, 16, (x, y) =>
{
    double nx = (x + 0.5 - 16) / 15.5, ny = (y + 0.5 - 9.5) / 6.2, d = nx * nx + ny * ny;
    if (d > 1) return '.';
    if (d > 0.8) return ny < 0 ? 'F' : (d > 0.92 ? '0' : '8');
    foreach (var (bx, by, c) in new[] { (6, 7, 'C'), (12, 5, 'E'), (19, 6, 'D'), (25, 8, 'C'), (9, 11, 'E'), (16, 10, 'F'), (22, 12, 'E') })
    {
        double e = Dist(x + 0.5, y + 0.5, bx + 0.5, by + 0.5);
        if (e < 0.8) return '6';                                               // its heart
        if (e < 1.9) return c;                                                 // its petals
    }
    return Leaf(nx, ny, x, y);                                                 // the leaves
});
// a pond: water in a ring of reeds, lily pads, one in flower
string[] Pond() => Pic(32, 16, (x, y) =>
{
    double nx = (x + 0.5 - 16) / 15.5, ny = (y + 0.5 - 8.5) / 7, d = nx * nx + ny * ny;
    if (d > 1) return '.';
    if (d > 0.74) return (x + y) % 3 == 0 ? 'A' : (Chk(x, y) ? '2' : '0');
    foreach (var (px, py) in new[] { (9.0, 7.0), (21.0, 10.0), (14.0, 11.0) })
        if (Dist(x + 0.5, (y + 0.5) * 1.6, px, py * 1.6) < 2.4) return (px == 21.0 && Dist(x + 0.5, y + 0.5, px, py) < 0.9) ? 'D' : 'A';
    if (y % 3 == 1 && (x * 3 + y) % 7 < 2) return '9';
    if (((x * 5 + y * 3) & 15) == 0) return 'B';
    return '1';
});
// a fountain, two cells wide: a wide basin, a column, a bowl, jets (two frames)
string[] Fountain(int f) => Shadow(Pic(32, 24, (x, y) =>
{
    double bx = (x + 0.5 - 16) / 15;
    if (y >= 16 && y <= 22 && Math.Abs(bx) <= 1)
    {
        if (y == 16) return Math.Abs(bx) > 0.94 ? '7' : ((x + f) % 4 == 0 ? 'B' : '9');
        if (y == 22) return '0';
        return bx < -0.7 ? 'F' : (bx < 0.2 ? '7' : (bx < 0.75 ? '8' : '0'));
    }
    if (y == 15 && Math.Abs(bx) < 0.97) return Math.Abs(bx) > 0.9 ? 'F' : '9';
    if (y >= 9 && y <= 15 && x >= 15 && x <= 16) return x == 15 ? 'F' : '8';      // the column
    if (y >= 8 && y <= 9 && x >= 11 && x <= 20) return y == 8 ? (x < 14 ? 'F' : '7') : '8';  // the bowl
    // the jet up the middle, and its water falling either side: four frames,
    // the drops a row further down each one - it flows
    if (y <= 7 && x >= 15 && x <= 16 && y >= 1) return (y + 4 - f) % 4 == 0 ? 'F' : 'B';
    for (int side = -1; side <= 1; side += 2)
        for (int jet = 0; jet < 2; jet++)
        {
            double t = (y - 1) / (jet == 0 ? 7.0 : 14.0), ax = 16 + side * (1 + (jet == 0 ? 5 : 11) * Math.Sqrt(Math.Max(0, t)));
            if (y >= 1 && y <= (jet == 0 ? 8 : 15) && Math.Abs(x + 0.5 - ax) < 0.8 && (y - f + jet * 2 + 8) % 4 < 2) return (y - f + 8) % 4 == 0 ? 'F' : 'B';
        }
    return '.';
}), 19, 23, 14, 1.5);
// a knight of stone on a tall pedestal
string[] Statue() => Check(new[] {
    "................",
    ".......00.......",
    "......0FF0......",
    "......07F0...0..",
    ".......00...070.",
    ".....0F770..070.",
    "....0F77770.070.",
    "....07077070F0..",
    "....0707707780..",
    ".....0F77800....",
    ".....0F70870....",
    ".....0F70870....",
    ".....0700870....",
    ".....000.000....",
    "...0000000000...",
    "...0FFF77778....",
    "...07777777780..",
    "...07777777780..",
    "...08888888880..",
    "....0F777780....",
    "....0F777780....",
    "....0F777780....",
    "....0F777880....",
    "....0F777880....",
    "....0F777880....",
    "...0000000000...",
    "..0FFFF77777780.",
    "..07777777777780",
    "..08888888888880",
    "..00000000000000",
    "...0.0.0.0.0.0..",
    "....0.0.0.0.0...",
}, 16, 32);
// a lantern on a post, burning
string[] Lamp() => Pic(16, 24, (x, y) =>
{
    if (y >= 9 && y <= 21 && x >= 7 && x <= 8) return x == 7 ? '8' : '0';
    if (y >= 20 && y <= 21 && x >= 5 && x <= 10) return y == 20 ? '8' : '0';
    if (y == 2 && x >= 6 && x <= 9) return '0';
    if (y == 1 && x >= 7 && x <= 8) return '0';
    if (y >= 3 && y <= 8 && x >= 5 && x <= 10)
    {
        if (x == 5 || x == 10 || y == 8) return '0';
        return Dist(x + 0.5, y + 0.5, 7.5, 5.5) < 1.5 ? 'F' : 'E';
    }
    if (y >= 22 && Math.Abs(x + 0.5 - 9) < 5 && Chk(x, y)) return '0';
    return '.';
});
// a well: a ring of stones, its dark water, two posts and a red roof
string[] Well() => Pic(16, 24, (x, y) =>
{
    if (y <= 6)
    {
        double w = 2 + y * 1.1, dx = x + 0.5 - 8;
        if (Math.Abs(dx) > w) return '.';
        if (Math.Abs(dx) > w - 1 || y == 6) return '0';
        return dx < 0 ? 'C' : '4';
    }
    if (y <= 13 && (x == 3 || x == 12)) return x == 3 ? '6' : '0';           // the posts
    if (y == 9 && x > 3 && x < 12) return '6';                               // the windlass
    if (y >= 10 && y <= 12 && x >= 7 && x <= 8) return y == 10 ? '0' : '8';   // the bucket's rope, the bucket
    if (y >= 14 && y <= 22 && x >= 2 && x <= 13)
    {
        if (y == 14) return x <= 2 || x >= 13 ? '0' : (Chk(x, y) ? '0' : '1');
        if (x == 2 || x == 13 || y == 22) return '0';
        if ((y - 15) % 3 == 2 || (x + ((y - 15) / 3) * 2) % 4 == 0) return '0';
        return x < 6 ? 'F' : (x < 10 ? '7' : '8');
    }
    if (y == 23 && x >= 3 && x <= 14 && Chk(x, y)) return '0';
    return '.';
});
string[] Boulder() => Grid(16, (x, y) =>
{
    foreach (var (cx, cy, rx, ry) in new[] { (9.5, 10.5, 5.5, 4.5), (5.0, 11.5, 3.8, 3.2) })
    {
        double nx = (x + 0.5 - cx) / rx, ny = (y + 0.5 - cy) / ry, d = nx * nx + ny * ny;
        if (d < 1) return d > 0.8 ? '0' : Shade(nx, ny, "F7788");
    }
    if (y >= 13 && H2(x, y) % 3 == 0) return 'A';
    return '.';
});
string[] Flowers()
{
    var s = Grid(16, (x, y) => '.');
    void Put(int x, int y, char c) { if (x >= 0 && x < 16 && y >= 0 && y < 16) { var a = s[y].ToCharArray(); a[x] = c; s[y] = new string(a); } }
    foreach (var (fx, fy, c) in new[] { (3, 4, 'C'), (10, 3, 'D'), (13, 10, 'E'), (5, 11, 'F'), (10, 13, 'C'), (7, 7, 'E') })
    {
        Put(fx, fy + 2, 'A'); Put(fx, fy + 3, '2');
        Put(fx - 1, fy, c); Put(fx + 1, fy, c); Put(fx, fy - 1, c); Put(fx, fy + 1, c); Put(fx, fy, 'E');
    }
    return s;
}
// a round tower of grey stone, its window, its crenels, a red cone of a
// roof and a gold pennant: 32 rows, a cell's 16 of them over the cell above
string[] Tower() => Pic(16, 32, (x, y) =>
{
    if (x == 8 && y <= 4) return '0';
    if (y <= 2 && x >= 9 && x <= 12 && x - 9 <= (y == 1 ? 3 : 1)) return 'E';
    if (y >= 3 && y <= 13)
    {
        double w = 1 + (y - 3) * 6.5 / 10;
        double dx = x + 0.5 - 8;
        if (Math.Abs(dx) > w) return '.';
        if (Math.Abs(dx) > w - 0.9 || y == 13) return '0';
        double u = dx / w;
        return u < -0.5 ? 'C' : (u < 0.1 ? (Chk(x, y) ? 'C' : '4') : (u < 0.6 ? '4' : (Chk(x, y) ? '4' : '0')));
    }
    if (y >= 14 && y <= 31 && x >= 2 && x <= 13)
    {
        if (y == 14 || y == 15) return (x % 3 == 2 && y == 14) ? '.' : (x == 2 || x == 13 ? '0' : (x < 6 ? 'F' : '7'));
        if (x == 2 || x == 13 || y == 31) return '0';
        if (y >= 18 && y <= 22 && x >= 7 && x <= 8) return y == 18 ? '8' : '0';
        int course = (y - 16) / 3;
        if ((y - 16) % 3 == 2 || ((x + course * 2) % 5 == 0)) return '8';
        double u = (x - 2) / 11.0;
        return u < 0.25 ? 'F' : (u < 0.6 ? '7' : (u < 0.85 ? (Chk(x, y) ? '7' : '8') : '8'));
    }
    return '.';
});

// ---- things on the floor ---------------------------------------------------
// a crate, drawn by rule at every size so its rim survives the smallest:
// on the black floor nothing of it may be black - a gold rim lit on its
// top and left, brown on its bottom and right, iron at the corners, planks
// with dark red seams.  Home, it is the same in the greens.
string[] CrateN(int n, bool home) => Grid(n, (x, y) =>
{
    char lit = home ? 'A' : 'E', wood = home ? '2' : '6', seam = home ? '0' : '4', dark = home ? '2' : '6';
    int c = n >= 10 ? 3 : 2;                                   // the iron corners
    bool corner = (x < c || x >= n - c) && (y < c || y >= n - c);
    if (corner)
    {
        if (c == 3 && (x == 1 || x == n - 2) && (y == 1 || y == n - 2)) return '8';   // a rivet
        return (x == 0 || y == 0) ? 'F' : '7';
    }
    if (x == 0 || y == 0) return lit;                          // the rim, in the light
    if (x == n - 1 || y == n - 1) return dark;                 //  ...and turned from it
    int b = n >= 12 ? 2 : 1;                                   // the frame inside it
    if (x <= b || y <= b || x >= n - 1 - b || y >= n - 1 - b) return y <= b ? lit : wood;
    int pitch = Math.Max(2, n / 5);                            // the planks
    if ((y - b - 1) % pitch == pitch - 1) return seam;
    return H2(x * 7 + (home ? 3 : 0), y / pitch) % 5 == 0 ? lit : wood;
});
// a candy's glint: a little white star over it, now and then
string[] Sparkle() => Grid(16, (x, y) =>
{
    int dx = x - 11, dy = y - 4;
    if (dx == 0 && dy == 0) return 'F';
    if ((dx == 0 && Math.Abs(dy) <= 3) || (dy == 0 && Math.Abs(dx) <= 3)) return Math.Abs(dx) + Math.Abs(dy) <= 1 ? 'F' : 'B';
    if (Math.Abs(dx) == 1 && Math.Abs(dy) == 1) return 'B';
    return '.';
});
string[] Man() => Check(new[] {
    "......0000......",
    ".....0PPPP0.....",
    "....0PPPPPPp0...",
    "....0pppppp0....",
    ".....0CCCC0.....",
    ".....C0CC0C.....",
    ".....0C66C0.....",
    "......0660......",
    "....0sSSSSs0....",
    "...0SSSSSSSS0...",
    "..0C0SSSSSS0C0..",
    "..060sSSSSs060..",
    ".....0PPPP0.....",
    ".....0Pp0Pp0....",
    ".....0P0.0P0....",
    "....000..000....",
}, 16, 16);
string[] You() => Grid(16, (x, y) =>
    (x < 4 || x > 11) && (y < 4 || y > 11) && (x == 0 || x == 15 || y == 0 || y == 15) ? 'E' : '.');
string[] Mine() => Grid(16, (x, y) =>
{
    if (x == 9 && y == 0) return 'F';
    if (x == 10 && y == 1) return 'E';
    if (x == 8 && y == 1) return 'C';
    if ((x == 9 && y == 2) || (x == 8 && y == 3)) return '6';
    double nx = (x + 0.5 - 8) / 5.6, ny = (y + 0.5 - 9.5) / 5.6, d = nx * nx + ny * ny;
    if (d > 1) return '.';
    if (d > 0.8) return '7';
    return Shade(nx, ny, "F7880");
});
string[] Blast() => Grid(16, (x, y) =>
{
    double dx = x + 0.5 - 8, dy = y + 0.5 - 8, d = Math.Sqrt(dx * dx + dy * dy);
    double ray = Math.Abs(Math.Sin(Math.Atan2(dy, dx) * 4)) * 1.6;
    if (d < 2.5) return 'F';
    if (d < 4.2 + ray * 0.5) return 'E';
    if (d < 6 + ray) return Chk(x, y) ? 'C' : 'E';
    if (d < 7.2 + ray) return Chk(x, y) ? '4' : 'C';
    if (d < 8 && (x * 3 + y * 5) % 4 == 0) return '8';
    return '.';
});
string[] Gem(double size, bool star) => Grid(16, (x, y) =>
{
    double cx = 8, cy = 8.5, dx = (x + 0.5 - cx) / size, dy = (y + 0.5 - cy) / size;
    if (star && ((x == 12 && y <= 4) || (y == 2 && x >= 10 && x <= 14))) return x == 12 && y == 2 ? 'F' : 'B';
    if (star && ((x == 3 && y >= 11 && y <= 13) || (y == 12 && x >= 2 && x <= 4))) return 'F';
    double rim = Math.Abs(dx) / 6 + (dy < -1.5 ? -dy / 4 : Math.Max(0, dy) / 6.5);
    if (dy < -4.5 || rim > 1) return '.';
    if (rim > 0.82) return '1';
    if (dy < -1.5) return dx < 0 ? 'F' : 'B';
    if (dy < -0.5) return '9';
    return dx < -1 ? 'B' : dx < 1.5 ? '3' : '9';
});
string[] Torch(int f) => Grid(16, (x, y) =>
{
    if (y >= 8 && y <= 13 && x >= 7 && x <= 8) return y == 8 ? '8' : (x == 7 ? '6' : '0');
    double fx = 7.5 + (f == 0 ? -0.5 : 0.5);
    double d = Math.Abs(x + 0.5 - fx) + Math.Abs(y + 0.5 - 5) * 0.5;
    if (y == 1 && Math.Abs(x + 0.5 - fx) < 1) return 'F';
    if (d < 1.2) return 'F';
    if (d < 2.2) return 'E';
    if (d < 3.2 && y < 8) return 'C';
    return '.';
});
// a crow: black, its wings edged in grey so it shows on the park, a gold
// beak - sitting, wings up, wings down
string[] Bird(int f) => f switch
{
    0 => Check(new[] {
        "................", "................", "................", "................",
        "........000.....", ".......00F0EE...", ".......00000E...", "......0000000...",
        ".....008800000..", "....0088877000..", "...00888770000..", "..0.00000000....",
        "......000000....", "......0...0.....", ".....EE...EE....", "................" }, 16, 16),
    1 => Check(new[] {
        "................", "0..............0", "80............08", "780..........087",
        ".780........087.", "..7800....0087..", "...880000008....", "....00F00E00....",
        ".....000000EE...", "......0000......", ".......00.......", "................",
        "................", "................", "................", "................" }, 16, 16),
    _ => Check(new[] {
        "................", "................", "................", "................",
        "................", "......0000......", ".....00F00EE....", "....00000000....",
        "...0880000880...", "..088700007880..", ".08870....07880.", "0870........0780",
        "870..........078", "70............07", "................", "................" }, 16, 16),
};

// ---- the kinds, in the directory's order: MULTSOK2.ASM's K_ numbers.
//      'm' brings a picture down by majority (outlines, little dots), 'a'
//      by the colours' average (round things), 'r' draws it by rule at
//      every size.  K_WA1..4, K_MO0..3 and K_FG? are runs the game counts on.
var kinds = new (string name, char how, Func<int, string[]> art)[] {
    ("GOL", 'm', n => Goal()), ("CA1", 'a', n => Candy(1)), ("CA2", 'a', n => Candy(2)), ("CA3", 'a', n => Candy(3)), ("CSP", 'm', n => Sparkle()),
    ("WA1", 'm', n => Stones(0)), ("WA2", 'm', n => Stones(1)), ("WA3", 'm', n => Stones(2)), ("WA4", 'm', n => Stones(3)),
    ("FGN", 'r', n => Growth(n, 0)), ("FGE", 'r', n => Growth(n, 1)), ("FGS", 'r', n => Growth(n, 2)), ("FGW", 'r', n => Growth(n, 3)),
    ("BOX", 'r', n => CrateN(n, false)), ("BOG", 'r', n => CrateN(n, true)), ("MAN", 'm', n => Man()), ("YOU", 'm', n => You()),
    ("MIN", 'a', n => Mine()), ("BLA", 'a', n => Blast()),
    ("DI0", 'a', n => Gem(0.55, false)), ("DI1", 'a', n => Gem(1, false)), ("DI2", 'a', n => Gem(1, true)),
    ("GT0", 'm', n => Gate(0)), ("GT1", 'm', n => Gate(1)), ("GT2", 'm', n => Gate(2)),
    ("BRV", 'm', n => Bridge(false)), ("BRH", 'm', n => Bridge(true)),
    ("GRS", 'm', n => Grass(false)), ("GR2", 'm', n => Grass(true)), ("ROD", 'm', n => Road()), ("GRL", 'm', n => Meadow()), ("GRD", 'm', n => Forest()),
    ("MO0", 'm', n => Water(0)), ("MO1", 'm', n => Water(1)), ("MO2", 'm', n => Water(2)), ("MO3", 'm', n => Water(3)), ("MO4", 'm', n => Water(4)),
    ("BKN", 'r', n => Bank(n, 0)), ("BKE", 'r', n => Bank(n, 1)), ("BKS", 'r', n => Bank(n, 2)), ("BKW", 'r', n => Bank(n, 3)),
    ("BSH", 'm', n => Bush()), ("TRE", 'm', n => Tree()), ("PIN", 'm', n => Pine()), ("OAK", 'm', n => Oak()),
    ("HED", 'm', n => Hedge()), ("FLB", 'm', n => FlowerBed()), ("PND", 'm', n => Pond()), ("FLW", 'm', n => Flowers()),
    ("FN0", 'm', n => Fountain(0)), ("FN1", 'm', n => Fountain(1)), ("FN2", 'm', n => Fountain(2)), ("FN3", 'm', n => Fountain(3)), ("STA", 'm', n => Statue()), ("ROK", 'a', n => Boulder()),
    ("LMP", 'm', n => Lamp()), ("WEL", 'm', n => Well()),
    ("TWR", 'm', n => Tower()), ("TR0", 'm', n => Torch(0)), ("TR1", 'm', n => Torch(1)),
    ("BD0", 'm', n => Bird(0)), ("BD1", 'm', n => Bird(1)), ("BD2", 'm', n => Bird(2)),
};
int[] sizes = { 16, 12, 10, 8, 6 };

// ---- down to n pixels a cell (a picture w x h becomes w*n/16 x h*n/16) -----
int Near(double r, double g, double b)
{
    int best = 0; double bd = double.MaxValue;
    for (int i = 0; i < 16; i++) { double d = (pal[i].r - r) * (pal[i].r - r) * 0.3 + (pal[i].g - g) * (pal[i].g - g) * 0.59 + (pal[i].b - b) * (pal[i].b - b) * 0.11; if (d < bd) { bd = d; best = i; } }
    return best;
}
string[] Down(string[] s, int n, char how)
{
    if (n == 16) return s;
    int W0 = s[0].Length, H0 = s.Length, w = W0 * n / 16, h = H0 * n / 16;
    return Pic(w, h, (tx, ty) =>
    {
        double fx0 = tx * 16.0 / n, fx1 = (tx + 1) * 16.0 / n, fy0 = ty * 16.0 / n, fy1 = (ty + 1) * 16.0 / n;
        var wt = new Dictionary<char, double>(); double tot = 0;
        for (int y = (int)fy0; y < Math.Min(H0, Math.Ceiling(fy1)); y++)
            for (int x = (int)fx0; x < Math.Min(W0, Math.Ceiling(fx1)); x++)
            {
                double ww = (Math.Min(x + 1, fx1) - Math.Max(x, fx0)) * (Math.Min(y + 1, fy1) - Math.Max(y, fy0));
                if (ww <= 0) continue;
                char c = s[y][x]; wt[c] = wt.GetValueOrDefault(c) + ww; tot += ww;
            }
        if (wt.GetValueOrDefault('.') * 2 >= tot) return '.';
        var ink = wt.Where(p => p.Key != '.').ToList();
        if (how == 'm' || ink.Any(p => "SsPp".Contains(p.Key)))
            return ink.OrderByDescending(p => p.Value).ThenBy(p => p.Key == '0' ? 0 : 1).First().Key;
        double r = 0, g = 0, b = 0, t = 0;
        foreach (var (c, ww) in ink) { var p = pal[Convert.ToInt32(c.ToString(), 16)]; r += p.r * ww; g += p.g * ww; b += p.b * ww; t += ww; }
        return "0123456789ABCDEF"[Near(r / t, g / t, b / t)];
    });
}
var art = new Dictionary<(string, int), string[]>();
foreach (var (name, how, f) in kinds)
{
    var m = how == 'r' ? null : f(16);
    if (m != null && (m[0].Length % 16 != 0 || m.Length % 8 != 0)) throw new Exception($"{name}: {m[0].Length}x{m.Length} - widths of 16 or 32, heights of 8s");
    foreach (var n in sizes) art[(name, n)] = how == 'r' ? f(n) : Down(m!, n, how);
}

// ---- the isometric tiles: 24x12 diamonds, the pictures laid on them -------
const int T = 12;
(int a, int b) Span(int t, int y) { int hw = t - (int)Math.Round(2 * Math.Abs(y - (t / 2.0 - 0.5))); return (T - hw, T - 1 + hw); }
char Dark(char c) => c switch
{
    '7' => '8', 'F' => '7', '8' => '0', '9' => '1', 'A' => '2', 'B' => '3', 'C' => '4', 'D' => '5', 'E' => '6',
    '4' => '0', '6' => '0', '2' => '0', '1' => '0', '3' => '1', '5' => '0', _ => c
};
char Tex(string[] t, double u, double v) => t[Math.Clamp((int)v, 0, 15)][Math.Clamp((int)u, 0, 15)];
string[] IsoBlock(string[] top, string[]? face, int t, int H)
{
    var s = Enumerable.Range(0, t + H).Select(_ => new string('.', 2 * T)).ToArray();
    void Put(int x, int y, char c) { var a = s[y].ToCharArray(); a[x] = c; s[y] = new string(a); }
    for (int y = 0; y < t; y++)
    {
        var (a, b) = Span(t, y);
        for (int x = a; x <= b; x++)
        {
            double ua = (x + 0.5 - T) / (2 * t) + (y + 0.5 - t / 2.0) / t + 0.5;
            double vb = (y + 0.5 - t / 2.0) / t - (x + 0.5 - T) / (2 * t) + 0.5;
            char c = Tex(top, ua * 16, vb * 16);
            Put(x, y, c == '.' ? '0' : c);
        }
    }
    if (H == 0 || face == null) return s;
    var (wa, wb) = Span(t, t / 2);
    int wf = T - wa;
    for (int x = wa; x <= wb; x++)
    {
        bool left = x < T;
        int last = 0;
        for (int y = t - 1; y >= 0; y--) { var (a, b) = Span(t, y); if (x >= a && x <= b) { last = y; break; } }
        double u = left ? (double)(x - wa) / wf : (double)(wb - x) / wf;
        for (int v = 0; v < H; v++)
        {
            char c = Tex(face, u * 16, (double)v / H * 16);
            if (c == '.') c = '0';
            if (left && Chk(x, v)) c = Dark(c);
            if (v == H - 1) c = '0';
            Put(x, last + 1 + v, c);
        }
    }
    return s;
}
string[] Mf(string k) => art[(k, 16)];
// the isometric wall's top: four big flat capstones, lit edges, dark
// joints, a tuft of green on some - calm, where the stone faces are busy
string[] Capstones(int v) => Grid(16, (x, y) =>
{
    if (x % 8 == 7 || y % 8 == 7) return '0';
    if (v > 0 && Dist(x + 0.5, y + 0.5, 3 + v * 3, 11 - v) < 2.2) return Chk(x, y) ? 'A' : '2';
    if (x % 8 == 0 || y % 8 == 0) return 'F';
    if (x % 8 == 6 || y % 8 == 6) return '8';
    return '7';
});
string[] youI = { ".........EEEEEE.........", "..........EEEE..........", "...........EE..........." };
var iso = new Dictionary<string, string[]> {
    ["GOL"] = IsoBlock(Over(Grid(16, (x, y) => '0'), Mf("GOL")), null, T, 0),
    ["WA1"] = IsoBlock(Capstones(0), Mf("WA1"), T, 6), ["WA2"] = IsoBlock(Capstones(1), Mf("WA2"), T, 6),
    ["WA3"] = IsoBlock(Capstones(0), Mf("WA3"), T, 6), ["WA4"] = IsoBlock(Capstones(2), Mf("WA4"), T, 6),
    ["BOX"] = IsoBlock(Mf("BOX"), Mf("BOX"), 8, 10), ["BOG"] = IsoBlock(Mf("BOG"), Mf("BOG"), 8, 10),
    ["GT0"] = IsoBlock(Mf("GT0"), Mf("GT0"), T, 6), ["GT1"] = IsoBlock(Mf("GT1"), Mf("GT1"), T, 6), ["GT2"] = IsoBlock(Mf("GT2"), null, T, 0),
    ["BRV"] = IsoBlock(Mf("BRV"), null, T, 0), ["BRH"] = IsoBlock(Mf("BRH"), null, T, 0),
    ["MO0"] = IsoBlock(Mf("MO0"), null, T, 0), ["MO1"] = IsoBlock(Mf("MO1"), null, T, 0), ["MO2"] = IsoBlock(Mf("MO2"), null, T, 0), ["MO3"] = IsoBlock(Mf("MO3"), null, T, 0),
    ["GRS"] = IsoBlock(Mf("GRS"), null, T, 0), ["GR2"] = IsoBlock(Mf("GR2"), null, T, 0), ["ROD"] = IsoBlock(Mf("ROD"), null, T, 0),
    ["BLA"] = IsoBlock(Mf("BLA"), null, T, 0), ["YOU"] = youI,
};
var isoFloor = IsoBlock(Grid(16, (x, y) => x == 0 || y == 0 ? '8' : '0'), null, T, 0);

// ---- the level, out of LEVELS.INC: the n-th, as LEVTAB counts ------------
int want = int.Parse(args[1]);
var inc = File.ReadAllLines(args[0]);
var labels = inc.Select((l, i) => (l, i)).Where(p => Regex.IsMatch(p.l, @"^LEV\d\d:")).Select(p => p.i).ToList();
int at = labels[want];
var wh0 = Regex.Match(inc[at], @"db\s+(\d+),(\d+)");
int W = int.Parse(wh0.Groups[1].Value), Hh = int.Parse(wh0.Groups[2].Value);
var rows = inc.Skip(at + 1).Take(Hh).Select(l => Regex.Match(l, "'(.*)'").Groups[1].Value).ToList();
char At(int c, int r) => c < 0 || r < 0 || c >= W || r >= Hh ? ' ' : rows[r][c];
bool IsWall(int c, int r) => At(c, r) == '#';
var floor = new bool[W, Hh];
int mc = 0, mr = 0;
for (int r = 0; r < Hh; r++) for (int c = 0; c < W; c++) if (At(c, r) == '@' || At(c, r) == '+') { mc = c; mr = r; }
{
    var st = new Stack<(int, int)>(); st.Push((mc, mr));
    while (st.Count > 0)
    {
        var (c, r) = st.Pop();
        if (c < 0 || r < 0 || c >= W || r >= Hh || floor[c, r] || IsWall(c, r)) continue;
        floor[c, r] = true; st.Push((c + 1, r)); st.Push((c - 1, r)); st.Push((c, r + 1)); st.Push((c, r - 1));
    }
}
bool IsFloor(int c, int r) => c >= 0 && r >= 0 && c < W && r < Hh && floor[c, r];
// the game's scatter, MULTSOK2.ASM HASH: the seed through the generator,
// its bytes swapped, through it again (without the swap, the cells of one
// column come out alike)
int Hash(int c, int r)
{
    int seed = (want * 4096 + (r & 63) * 64 + (c & 63)) & 0xFFFF;
    int x = (seed * 25173 + 13849) & 0xFFFF;
    x = ((x >> 8) | (x << 8)) & 0xFFFF;
    x = (x * 25173 + 13849) & 0xFFFF;
    return x >> 8;
}
var outside = new HashSet<(int, int)>();
{
    var st = new Stack<(int, int)>();
    for (int c = -1; c <= W; c++) { st.Push((c, -1)); st.Push((c, Hh)); }
    for (int r = -1; r <= Hh; r++) { st.Push((-1, r)); st.Push((W, r)); }
    while (st.Count > 0)
    {
        var (c, r) = st.Pop();
        if (c < -1 || r < -1 || c > W || r > Hh || outside.Contains((c, r)) || IsWall(c, r) || IsFloor(c, r)) continue;
        outside.Add((c, r)); st.Push((c + 1, r)); st.Push((c - 1, r)); st.Push((c, r + 1)); st.Push((c, r - 1));
    }
}
bool Out(int c, int r) => c < 0 || r < 0 || c >= W || r >= Hh || outside.Contains((c, r));
(int c, int r, int dc, int dr) gate = (-1, -1, 0, 0);
{
    int bestd = int.MaxValue;
    for (int r = 0; r < Hh; r++) for (int c = 0; c < W; c++)
        {
            if (!IsWall(c, r)) continue;
            foreach (var (dc, dr) in new[] { (0, 1), (1, 0), (0, -1), (-1, 0) })
                if (IsFloor(c - dc, r - dr) && Out(c + dc, r + dr))
                {
                    int d = Math.Abs(c - mc) + Math.Abs(r - mr);
                    if (d < bestd) { bestd = d; gate = (c, r, dc, dr); }
                }
        }
}
bool IsMoat(int c, int r)
{
    if (IsWall(c, r) || IsFloor(c, r)) return false;
    for (int dr = -1; dr <= 1; dr++) for (int dc = -1; dc <= 1; dc++) if (IsWall(c + dc, r + dr)) return true;
    return false;
}
bool OnRoad(int c, int r)
{
    if (gate.c < 0) return false;
    int k = (c - gate.c) * gate.dc + (r - gate.r) * gate.dr;
    int side = (c - gate.c) * gate.dr - (r - gate.r) * gate.dc;
    return side == 0 && k >= 2;
}
bool Park(int c, int r) => !IsWall(c, r) && !IsFloor(c, r) && !IsMoat(c, r) && !OnRoad(c, r) && Out(c, r);
bool Corner(int c, int r)
{
    bool L = IsWall(c - 1, r), R = IsWall(c + 1, r), U = IsWall(c, r - 1), D = IsWall(c, r + 1);
    if ((L ? 1 : 0) + (R ? 1 : 0) + (U ? 1 : 0) + (D ? 1 : 0) != 2 || L == R) return false;
    int hx = R ? 1 : -1, vy = D ? 1 : -1;
    return Out(c - hx, r - vy);
}
// the park's things: the kind a cell's scatter picks, and how many cells
// wide it stands (MULTSOK2.ASM DECOR - the same thresholds)
// The land round the castle: ENGINE\E_TERR.INC's DSGEN, the islands'
// Diamond-Square on a 64x64 torus, seeded by the level (MULTSOK2.ASM
// LANDGEN) - the same 4096 draws, the same stretch - so the preview is the
// game's park.  Low ground is wet (ponds, bushes, flowers), then the
// garden (beds, hedges, fountains, statues, lanterns, a well), then a wood
// of oaks and trees, the highest a pine wood with boulders.
var HM = new byte[64 * 64];
{
    int rseed = (want * 7919 + 4242) & 0xFFFF;
    int RND16() { rseed = (rseed * 25173 + 13849) & 0xFFFF; return rseed; }
    int HG(int x, int y) => HM[((x & 63) << 6) + (y & 63)];
    void HP(int x, int y, int v) => HM[((x & 63) << 6) + (y & 63)] = (byte)v;
    int dss = 32, dsamp = 128;
    HP(0, 0, ((RND16() >> 8) & 127) + 64); HP(32, 0, ((RND16() >> 8) & 127) + 64);
    HP(0, 32, ((RND16() >> 8) & 127) + 64); HP(32, 32, ((RND16() >> 8) & 127) + 64);
    int Noise(int ac) { int v = ((RND16() >> 8) & (dsamp - 1)) - dsamp / 2 + (ac >> 2); return Math.Clamp(v, 0, 255); }
    while (true)
    {
        int h = dss / 2;
        for (int x = 0; x < 64; x += dss) for (int y = 0; y < 64; y += dss)
                HP(x + h, y + h, Noise(HG(x, y) + HG(x + dss, y) + HG(x + dss, y + dss) + HG(x, y + dss)));
        for (int x = 0; x < 64; x += dss) for (int y = 0; y < 64; y += dss)
            {
                HP(x + h, y, Noise(HG(x, y) + HG(x + dss, y) + HG(x + h, y - h) + HG(x + h, y + h)));
                HP(x, y + h, Noise(HG(x, y) + HG(x, y + dss) + HG(x - h, y + h) + HG(x + h, y + h)));
            }
        dss = h; dsamp = Math.Max(4, dsamp >> 1);
        if (dss <= 1) break;
    }
    int mn = HM.Min(b => b), mx = HM.Max(b => b);
    if (mx > mn) for (int i = 0; i < HM.Length; i++) HM[i] = (byte)((HM[i] - mn) * 255 / (mx - mn));
}
int Land(int c, int r) => HM[((c & 63) << 6) + (r & 63)];
// the ground of a park cell, by the land; and its thing, by the land and
// the scatter (MULTSOK2.ASM ZONES, the same thresholds)
string Ground(int c, int r, int h) { int l = Land(c, r); return l < 64 ? "GRS" : l < 136 ? (h % 5 == 0 ? "GR2" : "GRL") : l < 196 ? "GRS" : "GRD"; }
(string kind, int w) Decor(int c, int r)
{
    int l = Land(c, r), h = Hash(c + 7, r + 3);
    if (l < 64) return h < 22 ? ("PND", 2) : h < 40 ? ("BSH", 1) : h < 60 ? ("FLW", 1) : ("", 0);
    if (l < 136) return h < 6 ? ("FN0", 2) : h < 12 ? ("STA", 1) : h < 18 ? ("LMP", 1) : h < 22 ? ("WEL", 1) : h < 34 ? ("FLB", 2) :
        h < 44 ? ("HED", 2) : h < 66 ? ("FLW", 1) : h < 80 ? ("BSH", 1) : h < 84 ? ("ROK", 1) : ("", 0);
    if (l < 196) return h < 30 ? ("OAK", 2) : h < 80 ? ("TRE", 1) : h < 100 ? ("BSH", 1) : h < 106 ? ("ROK", 1) : ("", 0);
    return h < 90 ? ("PIN", 1) : h < 105 ? ("ROK", 1) : h < 115 ? ("TRE", 1) : ("", 0);
}

// ---- a level drawn as MULTSOK2.ASM draws it, n px a cell -------------------
int[] Scene(int n, int SW, int SH, int oy, int ph, int frame)
{
    var img = new int[SW * SH];
    Array.Fill(img, 0);
    void Draw(string kind, int X, int Y, int look = 0)
    {
        var spr = art[(kind, n)]; var lk = Look(look);
        int h = spr.Length, w = spr[0].Length, Y0 = Y + n - h;
        for (int y = 0; y < h; y++) for (int x = 0; x < w; x++)
            {
                char ch = spr[y][x]; if (ch == '.') continue;
                int px = X + x, py = Y0 + y;
                if (px < 0 || py < oy || px >= SW || py >= SH) continue;
                img[py * SW + px] = ch switch { 'S' => lk[0], 's' => lk[1], 'P' => lk[2], 'p' => lk[3], _ => Convert.ToInt32(ch.ToString(), 16) };
            }
    }
    int ox = ((SW - W * n) / 2) & ~1, oyy = oy + (SH - oy - Hh * n) / 2;
    int c0 = -(ox + n - 1) / n, c1 = (SW - ox) / n, r0 = -(oyy - oy + n - 1) / n, r1 = (SH - oyy) / n + 2;
    var claimed = new HashSet<(int, int)>();
    // the ground first, every cell; then what stands up, row by row
    for (int pass = 0; pass < 2; pass++)
        for (int r = r0; r <= r1; r++) for (int c = c0; c <= c1; c++)
            {
                int X = ox + c * n, Y = oyy + r * n, h = Hash(c, r);
                if (IsFloor(c, r))
                {
                    if (pass == 0 && (At(c, r) == '.' || At(c, r) == '*' || At(c, r) == '+')) Draw("GOL", X, Y);
                    continue;
                }
                if (IsWall(c, r))
                {
                    if (pass == 0)
                    {
                        if (gate.c == c && gate.r == r) { Draw(ph == 0 ? "GT0" : ph == 1 ? "GT1" : "GT2", X, Y); continue; }
                        Draw("WA" + (1 + h % 4), X, Y);
                        // growth where the wall's side faces out of the castle
                        if (Out(c, r - 1) && !IsWall(c, r - 1)) Draw("FGN", X, Y);
                        if (Out(c + 1, r) && !IsWall(c + 1, r)) Draw("FGE", X, Y);
                        if (Out(c, r + 1) && !IsWall(c, r + 1)) Draw("FGS", X, Y);
                        if (Out(c - 1, r) && !IsWall(c - 1, r)) Draw("FGW", X, Y);
                    }
                    else
                    {
                        if (Corner(c, r) && h % 3 != 0) Draw("TWR", X, Y);
                        else if (h > 236 && (IsFloor(c, r + 1) || IsFloor(c + 1, r) || IsFloor(c - 1, r))) Draw("TR" + (frame & 1), X, Y);
                    }
                    continue;
                }
                if (IsMoat(c, r))
                {
                    if (pass == 1) continue;
                    bool bridge = ph >= 2 && gate.c >= 0 && c == gate.c + gate.dc && r == gate.r + gate.dr;
                    if (bridge) { Draw(gate.dc == 0 ? "BRV" : "BRH", X, Y); continue; }
                    // every cell its own phase - the wind is not a grid - and a gust
                    // sweeping across, the water torn white under it
                    Draw(X >= 96 && X < 160 ? "MO4" : "MO" + ((frame + Hash(c, r)) & 3), X, Y);
                    if (!IsMoat(c, r - 1) && !IsWall(c, r - 1)) Draw("BKN", X, Y);
                    if (!IsMoat(c + 1, r) && !IsWall(c + 1, r)) Draw("BKE", X, Y);
                    if (!IsMoat(c, r + 1) && !IsWall(c, r + 1)) Draw("BKS", X, Y);
                    if (!IsMoat(c - 1, r) && !IsWall(c - 1, r)) Draw("BKW", X, Y);
                    continue;
                }
                if (OnRoad(c, r)) { if (pass == 0) Draw("ROD", X, Y); continue; }
                if (pass == 0) { Draw(Out(c, r) ? Ground(c, r, h) : "GRS", X, Y); continue; }
                if (!Out(c, r) || claimed.Contains((c, r))) continue;
                var (kind, wide) = Decor(c, r);
                if (kind == "") continue;
                if (wide == 2 && (!Park(c + 1, r) || claimed.Contains((c + 1, r)))) continue;
                // every cell it covers: its foot on grass, what it rises over
                // grass or road, none of them taken (MULTSOK2.ASM STAND)
                int tall = (art[(kind, n)].Length + n - 1) / n;
                bool clear = true;
                for (int k = 1; k < tall && clear; k++) for (int q = 0; q < wide; q++)
                        if (!(Park(c + q, r - k) || OnRoad(c + q, r - k)) || claimed.Contains((c + q, r - k))) clear = false;
                if (!clear) continue;
                for (int k = 0; k < tall; k++) for (int q = 0; q < wide; q++) claimed.Add((c + q, r - k));
                int hj = Hash(c + 2, r + 11);
                int jx = (((hj & 7) - 3) * n / 16) & ~1, jy = ((hj >> 3) & 3) - 1;
                Draw(kind, X + jx, Y + jy * n / 8);
            }
    // dusk round the castle (MULTSOK2.ASM DUSK): across each side's margin
    // to the screen's edge the light goes by the golden section - the first
    // 0.382 of it in full light, then a colour step through a 4x4 ordered
    // dither, a few pixels at first, all of them at the edge; a margin
    // under 3 cells keeps its light
    int[] dim16 = { 0, 0, 0, 1, 0, 1, 4, 8, 0, 1, 2, 3, 4, 5, 6, 7 };
    int[] bayer = { 0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5 };
    int lx0 = ox, lx1 = ox + W * n - 1, ly0 = oyy, ly1 = oyy + Hh * n - 1;
    int Frac(int d, int D) => D < 3 * n ? 0 : Math.Min(255, d * 256 / D);
    int TX(int x) => x < lx0 ? Frac(lx0 - x, lx0) : x > lx1 ? Frac(x - lx1, SW - 1 - lx1) : 0;
    int TY(int y) => y < ly0 ? Frac(ly0 - y, ly0 - oy) : y > ly1 ? Frac(y - ly1, SH - 1 - ly1) : 0;
    for (int py = oy; py < SH; py++) for (int px = 0; px < SW; px++)
        {
            int t = Math.Max(TX(px), TY(py)), b = bayer[(py & 3) * 4 + (px & 3)];
            if (t > 98 + b * 150 / 16) img[py * SW + px] = dim16[img[py * SW + px]];
        }
    for (int r = 0; r < Hh; r++) for (int c = 0; c < W; c++)
        {
            int X = ox + c * n, Y = oyy + r * n; char ch = At(c, r);
            if (ch == '$') Draw("BOX", X, Y);
            else if (ch == '*') Draw("BOG", X, Y);
            else if (ch == '@' || ch == '+') { Draw("MAN", X, Y); Draw("YOU", X, Y); }
            else if (IsFloor(c, r) && ch == ' ' && !(Math.Abs(c - mc) <= 1 && r == mr))
            {
                Draw("CA" + (1 + Hash(c + 5, r + 9) % 3), X, Y);
                if (((r * 32 + c) * 37 + frame * 3) % 32 < 3) Draw("CSP", X, Y);   // one glinting now
            }
        }
    if (IsFloor(mc + 1, mr)) Draw("MAN", ox + (mc + 1) * n, oyy + mr * n, 1);
    if (IsFloor(mc - 1, mr)) Draw("MIN", ox + (mc - 1) * n, oyy + mr * n);
    if (IsFloor(mc, mr - 1)) Draw("DI2", ox + mc * n, oyy + (mr - 1) * n);
    if (gate.c >= 0 && ph == 2) Draw("BD0", ox + (gate.c + 1) * n, oyy + gate.r * n);
    return img;
}

// ---- the cards: EGA/VGA in the sixteen; CGA's four in 2x2 half-tones; the
//      Hercules' dots by brightness.  Both maps go into ART.DAT ------------
string[] cgmap = {      // per colour: [even row: even x, odd x][odd row: even x, odd x], CGA palette 1
    "0000", "0100", "1001", "1111", "2002", "2222", "2002", "3333",
    "3003", "1111", "1111", "1313", "2222", "2332", "3223", "3333" };
var cgpal = new (int, int, int)[] { (0, 0, 0), (85, 255, 255), (255, 85, 255), (255, 255, 255) };
int[] hglum = { 0, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4 };
string[] hgpat = { "0000", "1000", "1001", "1101", "1111" };   // MULTSOK2.ASM HGPAT: 2 dots x 2 rows
void Png(int PW, int PH, Func<int, int, (int r, int g, int b)> px, string path)
{
    var raw = new MemoryStream();
    for (int y = 0; y < PH; y++) { raw.WriteByte(0); for (int x = 0; x < PW; x++) { var p = px(x, y); raw.WriteByte((byte)p.r); raw.WriteByte((byte)p.g); raw.WriteByte((byte)p.b); } }
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
void Cards(int[] img, string path)
{
    const int SW = 320;
    Png(960, 600, (x, y) => pal[img[(y / 3) * SW + x / 3]], path + ".PNG");
    Png(960, 600, (x, y) => { int sx = x / 3, sy = y / 3; var m = cgmap[img[sy * SW + sx]]; return cgpal[m[(sy & 1) * 2 + (sx & 1)] - '0']; }, path + "C.PNG");
    var dots = new bool[640, 300];
    for (int oy = 0; oy < 300; oy++)
    {
        int sy = oy * 2 / 3;
        for (int ox = 0; ox < 640; ox++) { int sx = ox / 2; var p = hgpat[hglum[img[sy * SW + sx]]]; dots[ox, oy] = p[(oy & 1) * 2 + (ox & 1)] == '1'; }
    }
    Png(960, 600, (x, y) => dots[x * 2 / 3, y / 2] ? (255, 200, 90) : (0, 0, 0), path + "H.PNG");
}
foreach (var n in new[] { 16, 10, 8 })
    Cards(Scene(n, 320, 200, 8, 2, 0), $"{args[2]}{n}");
{
    var f1 = Scene(16, 320, 200, 8, 2, 1);          // the next frame: the ripples on, the torches flicker
    Png(960, 600, (x, y) => pal[f1[(y / 3) * 320 + x / 3]], $"{args[2]}16F1.PNG");
}
{
    int SW = 320, SH = 200; var img = new int[SW * SH]; Array.Fill(img, 0);
    void D(string[] spr, int X, int Y) { for (int y = 0; y < spr.Length; y++) for (int x = 0; x < spr[y].Length; x++) { char ch = spr[y][x]; if (ch == '.') continue; int px = X + x, py = Y + y; if (px >= 0 && py >= 0 && px < SW && py < SH) img[py * SW + px] = ch switch { 'S' => 14, 's' => 6, 'P' => 9, 'p' => 1, _ => Convert.ToInt32(ch.ToString(), 16) }; } }
    int x0 = 2, y0 = 2;
    foreach (var (name, _, _) in kinds)
    {
        var col = sizes.Select(n => art[(name, n)]).ToList();
        int h = col.Sum(p => p.Length + 1), w = col[0][0].Length;
        if (y0 + h > 150) { y0 = 2; x0 += 17; }
        if (w > 16 && x0 % 34 != 2) { }
        foreach (var p in col) { D(p, x0, y0); y0 += p.Length + 1; }
        y0 += 2;
        if (w > 16) { x0 += 17; y0 = 2; }
    }
    int ix = 2, iy = 158;
    foreach (var (name, spr) in iso) { D(spr, ix, iy); ix += 26; if (ix > 300) { ix = 2; iy += 20; } }
    D(isoFloor, ix, iy);
    Png(960, 600, (x, y) => pal[img[(y / 3) * SW + x / 3]], $"{args[2]}ALL.PNG");
}

// ---- KINDS.INC and ART.INC ---------------------------------------------------
var k = new StringBuilder();
void KL(string s) => k.Append(s).Append("\r\n");
KL("; KINDS.INC - MULTIPLAY SOKO II's picture numbers: made by TOOLS\\ArtGen2");
KL(";  (C#) with ART.INC; edit the generator, not this file.");
KL($"NKIND = {kinds.Length}");
KL($"NSIZE = {sizes.Length}");
for (int i = 0; i < kinds.Length; i++) KL($"K_{kinds[i].name} = {i}");
KL("K_IFLR = NKIND                  ; the isometric floor: in the isometric set only");
File.WriteAllText(Path.Combine(args[3], "KINDS.INC"), k.ToString(), Encoding.ASCII);

var o = new StringBuilder();
void L(string s) => o.Append(s).Append("\r\n");
L("; ART.INC - MULTIPLAY SOKO II's pictures, for ART.ASM: made by");
L(";  TOOLS\\ArtGen2 (C#) - edit the generator, not this file:");
L(";    dotnet run --project TOOLS\\ArtGen2 -- GAMES\\MULTSOK2\\LEVELS.INC 0 PREV GAMES\\MULTSOK2");
L(";  The 16-pixel pictures are drawn in its source; 12, 10, 8 and 6 are");
L(";  brought down from them, the isometric tiles laid out from them.");
L("\tdb 'SOKOART2'                   ; what this file is: the game checks it");
L($"\tdw NKIND, NSIZE");
L("ARTPAL:                         ; the sixteen, for a VGA's DAC: R, G, B, 0..63");
for (int i = 0; i < 16; i++) L($"\tdb {dac[i, 0]},{dac[i, 1]},{dac[i, 2]}");
L("ARTCGA:                         ; each colour on a CGA, palette 1: a 2x2 half-tone,");
L("                                ;  even row (even x, odd x), odd row (even x, odd x)");
for (int i = 0; i < 16; i++) L($"\tdb {string.Join(",", cgmap[i].Select(c => c))}");
L("ARTHGC:                         ; each colour's brightness on a Hercules: 0..4");
L($"\tdb {string.Join(",", hglum)}");
o.Append("ARTDIR:");
int k0 = 0;
foreach (var n in sizes) foreach (var (name, _, _) in kinds) o.Append((k0++ % 8 == 0 ? "\r\n\tdw " : ",") + $"{name}_{n}");
foreach (var (name, _, _) in kinds) o.Append((k0++ % 8 == 0 ? "\r\n\tdw " : ",") + (iso.ContainsKey(name) ? $"{name}_I" : $"{name}_16"));
o.Append("\r\n\tdw IFLR_I\r\n");
void Emit(string label, string[] s)
{
    o.Append($"{label}:\tdb {s[0].Length},{s.Length}\r\n");
    foreach (var r in s) o.Append($"\tdb '{r}'\r\n");
}
foreach (var n in sizes) foreach (var (name, _, _) in kinds) Emit($"{name}_{n}", art[(name, n)]);
foreach (var (name, s) in iso) Emit($"{name}_I", s);
Emit("IFLR_I", isoFloor);
File.WriteAllText(Path.Combine(args[3], "ART.INC"), o.ToString(), Encoding.ASCII);
Console.WriteLine($"level {want} {W}x{Hh}, gate ({gate.c},{gate.r}) out ({gate.dc},{gate.dr}); previews {args[2]}*.PNG; ART.INC {new FileInfo(Path.Combine(args[3], "ART.INC")).Length} bytes");
return 0;
