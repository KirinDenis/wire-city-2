// ============================================================================
//  LevConv - Base-Z-47's Sokoban levels into MULTSOKO's LEVELS.INC.
//
//      dotnet run --project TOOLS\LevConv -- <levels dir> GAMES\MULTSOKO\LEVELS.INC
//
//  <levels dir> is BASE-Z47\src\levels of github.com/KirinDenis/
//  Base-Z-47-Rust-Game: level0.rs, level1.rs ... each a Rust function
//  returning a [[char; W]; H] array, one row of quoted characters a line.
//  It reads level1.rs onward until the first number that is missing
//  (level61.rs_mod is not a level file and is left out). Not level0.rs:
//  it is level1.rs again, one column narrower, and the players met the
//  same level twice at the start.
//
//  Each level is trimmed to the box its non-space characters fill and
//  written as  db width,height  and height rows of width bytes, in the
//  standard Sokoban characters the levels already use:
//      #  wall    $  crate    .  goal    *  crate on a goal
//      @  man     +  man on a goal       space  floor or the void
//  Then NLEVELS and LEVTAB, a word per level.
//
//  To stdout: each level's size, crates and goals, and any character
//  outside that set or a level whose crates and goals do not pair up.
// ============================================================================
using System.Text;
using System.Text.RegularExpressions;

if (args.Length != 2)
{
    Console.Error.WriteLine("usage: LevConv <levels dir> <out LEVELS.INC>");
    return 1;
}
var dir = args[0];
var sb = new StringBuilder();
sb.Append("; LEVELS.INC - the Sokoban levels of Base-Z-47 (github.com/KirinDenis/\r\n");
sb.Append(";  Base-Z-47-Rust-Game, BASE-Z47/src/levels/level1..60.rs), each trimmed\r\n");
sb.Append(";  to its walls. Made by TOOLS\\LevConv (C#):\r\n");
sb.Append(";    dotnet run --project TOOLS\\LevConv -- <levels dir> GAMES\\MULTSOKO\\LEVELS.INC\r\n");
sb.Append(";  DO NOT EDIT BY HAND.  A level: db width, height, then height rows of\r\n");
sb.Append(";  width bytes: # wall  $ box  . goal  * box on goal  @ man  + man on goal\r\n");
var names = new List<string>();
bool bad = false;
for (int i = 1; ; i++)                  // from 1: level0.rs repeats level1.rs
{
    var path = Path.Combine(dir, $"level{i}.rs");
    if (!File.Exists(path)) break;
    var rows = new List<string>();
    foreach (var line in File.ReadAllLines(path))
    {
        var ms = Regex.Matches(line, "'(.)'");
        if (ms.Count < 10) continue;                    // not a row of the map
        rows.Add(string.Concat(ms.Select(m => m.Groups[1].Value)));
    }
    var used = rows.Where(r => r.Trim().Length > 0).ToList();
    if (used.Count == 0) { Console.Error.WriteLine($"{path}: no map"); return 1; }
    int top = rows.FindIndex(r => r.Trim().Length > 0);
    int bot = rows.FindLastIndex(r => r.Trim().Length > 0);
    int left = used.Min(r => r.Length - r.TrimStart().Length);
    int right = used.Max(r => r.TrimEnd().Length) - 1;
    int w = right - left + 1, h = bot - top + 1;
    var body = rows.Skip(top).Take(h).Select(r => r.PadRight(right + 1).Substring(left, w)).ToList();
    var all = string.Concat(body);
    int boxes = all.Count(c => c == '$' || c == '*');
    int goals = all.Count(c => c == '.' || c == '*' || c == '+');
    int men = all.Count(c => c == '@' || c == '+');
    var odd = new string(all.Where(c => "#$.*@+ ".IndexOf(c) < 0).Distinct().ToArray());
    string trouble = (odd.Length > 0 ? " ODD:" + odd : "") + (boxes != goals ? " CRATES<>GOALS" : "") + (men != 1 ? " MEN:" + men : "");
    if (trouble.Length > 0) bad = true;
    Console.WriteLine($"L{i,2} {w,2}x{h,2} crates={boxes,2} goals={goals,2}{trouble}");
    var label = $"LEV{i:D2}";
    names.Add(label);
    sb.Append($"{label}:\tdb {w},{h}\r\n");
    foreach (var r in body) sb.Append($"\tdb '{r}'\r\n");
}
sb.Append($"NLEVELS = {names.Count}\r\n");
sb.Append("LEVTAB:");
for (int i = 0; i < names.Count; i++)
    sb.Append((i % 8 == 0 ? (i == 0 ? "\tdw " : "\r\n\tdw ") : ",") + names[i]);
sb.Append("\r\n");
File.WriteAllText(args[1], sb.ToString(), Encoding.ASCII);
Console.WriteLine($"{names.Count} levels, {new FileInfo(args[1]).Length} bytes{(bad ? " - CHECK THE MARKED ONES" : "")}");
return bad ? 2 : 0;
