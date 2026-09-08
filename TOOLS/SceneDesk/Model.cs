// ============================================================================
//  The story, as files the GAME reads - and the desk edits.
//
//      <story>\STORY.INI            title, the folder name, where to start
//      <story>\<scene>\SCENE.INI    one scene: its text, its codes, and its
//                                   SECTIONS in the order they play
//      <story>\<scene>\CLIP1.OWV    the products of the sections, beside
//      <story>\<scene>\PICKUP\...   the .INF recipes that made them
//
//  and the raw material in the same shape outside the repository:
//
//      <warehouse>\<NAME>\<scene>\VIDEO\    footage
//      <warehouse>\<NAME>\<scene>\PICKUP\   empty.jpg full.jpg layer-*.png
//
//  INI, not JSON and not a binary: a DOS game reads a line, finds the '=',
//  and is done, and a person can read it in a text editor on the machine it
//  runs on. A section header is a stage of the scene:
//
//      [VIDEO]    a clip plays
//      [PICKUP]   a still with things in it; click them until NEED is met
//      [QUIZ]     a question with numbered answers
//
//  in any order, any number, any of them absent. A scene ends with a CODE -
//  a number. A QUIZ sets it to the number of the answer chosen; otherwise
//  the scene's own CODE line does. The scene that plays next is whichever
//  scene declares that number in its ENTERS line. The scene that ends does
//  not know its successors by name, and the desk checks at build time that
//  every code a scene can end with is entered by exactly one scene - so a
//  quiz answer with nowhere to go is an error in the desk, not a black
//  screen in the game.
//
//  Whether a section HAS its product is not recorded here. It is asked of
//  the disk, every time - so the answer cannot be stale, and so the game can
//  do the same thing and say "scene missing" on screen rather than crash.
// ============================================================================

using System.IO;
using System.Text;

namespace SceneDesk;

// ---- the INI file, as lines ------------------------------------------------
//  KEY = value               a plain key
//  KEY SUB = value           a keyed key: ITEM KEYS = ..., OPTION 1 = ...
//  [NAME]                    a section header; NAME may repeat
public record IniLine(string Section, string Key, string Sub, string Value);

public static class Ini
{
    public static List<IniLine> Read(string path)
    {
        var lines = new List<IniLine>();
        string section = null;
        foreach (var raw in File.ReadAllLines(path))
        {
            var line = raw.Trim();
            if (line.Length == 0 || line[0] == ';' || line[0] == '#') continue;
            if (line[0] == '[') { section = line.Trim('[', ']').Trim().ToUpperInvariant(); lines.Add(new IniLine(section, null, null, null)); continue; }
            int eq = line.IndexOf('=');
            if (eq < 0) continue;
            var head = line.Substring(0, eq).Trim();
            var value = line.Substring(eq + 1).Trim();
            int sp = head.IndexOf(' ');
            string key = (sp < 0 ? head : head.Substring(0, sp)).ToUpperInvariant();
            string sub = sp < 0 ? null : head.Substring(sp + 1).Trim();
            lines.Add(new IniLine(section, key, sub, value));
        }
        return lines;
    }

    // Written the way the .INF recipes are: aligned, commented, CRLF, ASCII -
    // for the DOS side and for a person reading it there.
    public sealed class Writer
    {
        readonly StringBuilder sb = new();
        public Writer Comment(string text) { foreach (var l in text.Split('\n')) sb.Append("; ").Append(l.TrimEnd()).Append("\r\n"); return this; }
        public Writer Blank() { sb.Append("\r\n"); return this; }
        public Writer Section(string name) { sb.Append('[').Append(name).Append("]\r\n"); return this; }
        public Writer Key(string key, string value) { sb.Append(key.PadRight(8)).Append(" = ").Append(value ?? "").Append("\r\n"); return this; }
        public Writer Key(string key, string sub, string value) { sb.Append((key + " " + sub).PadRight(8)).Append(" = ").Append(value ?? "").Append("\r\n"); return this; }
        public void Save(string path) => File.WriteAllText(path, sb.ToString(), Encoding.ASCII);
    }

    // Free text lives on one line in an INI; a line break becomes " | ".
    public static string One(string text) => (text ?? "").Replace("\r\n", "\n").Replace("\r", "\n").Replace("\n", " | ").Trim();
    public static string Many(string text) => (text ?? "").Replace(" | ", "\n");
}

// ============================================================================
public class Story
{
    public const string FILE = "STORY.INI";

    public string Dir;                              // <story>, the folder holding STORY.INI
    public string Title = "", Name = "", Warehouse = "", Start = "";
    public List<Scene> Scenes = new();

    public string MatDir => Path.Combine(Warehouse, Name);
    public string IniPath => Path.Combine(Dir, FILE);

    public static Story Load(string dir)
    {
        var s = new Story { Dir = dir, Name = Path.GetFileName(dir) };
        var order = new List<string>();
        if (File.Exists(s.IniPath))
            foreach (var l in Ini.Read(s.IniPath))
                switch (l.Key)
                {
                    case "TITLE": s.Title = l.Value; break;
                    case "NAME": s.Name = l.Value; break;
                    case "WAREHOUSE": s.Warehouse = l.Value; break;
                    case "START": s.Start = l.Value; break;
                    case "ORDER": order = Split(l.Value); break;
                }
        // every folder with a SCENE.INI is a scene; ORDER says how the desk lists them
        var found = new Dictionary<string, Scene>(StringComparer.OrdinalIgnoreCase);
        foreach (var d in Directory.GetDirectories(dir))
            if (File.Exists(Path.Combine(d, Scene.FILE))) found[Path.GetFileName(d)] = Scene.Load(d);
        foreach (var id in order) if (found.Remove(id, out var sc)) s.Scenes.Add(sc);
        foreach (var sc in found.Values.OrderBy(x => x.Id, StringComparer.OrdinalIgnoreCase)) s.Scenes.Add(sc);
        if (s.Start == "" && s.Scenes.Count > 0) s.Start = s.Scenes[0].Id;
        return s;
    }

    public void Save()
    {
        Directory.CreateDirectory(Dir);
        new Ini.Writer()
            .Comment("STORY.INI - the story, as the game reads it. Written by SceneDesk.")
            .Comment("Every folder beside this file that holds a SCENE.INI is a scene; START")
            .Comment("names the first. ORDER is how the desk lists them, nothing more. The")
            .Comment("game follows the scenes' CODE and ENTERS lines, not this list.")
            .Blank()
            .Key("TITLE", Title)
            .Key("NAME", Name)
            .Key("START", Start)
            .Key("ORDER", string.Join(" ", Scenes.Select(x => x.Id)))
            .Blank()
            .Comment("desk only: where the raw material is, outside the repository")
            .Key("WAREHOUSE", Warehouse)
            .Save(IniPath);
        foreach (var sc in Scenes) sc.Save(this);
    }

    public Dictionary<string, Scene> ById() =>
        Scenes.GroupBy(x => x.Id, StringComparer.OrdinalIgnoreCase).ToDictionary(g => g.Key, g => g.First(), StringComparer.OrdinalIgnoreCase);

    // The scenes a code leads to. One is right; none or several is an error
    // the story-level check reports.
    public List<Scene> EnteredBy(int code) => Scenes.Where(x => x.Enters.Contains(code)).ToList();

    // Story-level problems: codes with nowhere to go, codes with two places
    // to go, scenes nothing leads to.
    public IEnumerable<string> Problems()
    {
        var byId = ById();
        if (!byId.ContainsKey(Start)) yield return $"START names {Start}, which does not exist";
        foreach (var sc in Scenes)
            foreach (var code in sc.Exits())
            {
                var to = EnteredBy(code);
                if (to.Count == 0) yield return $"{sc.Id} can end with code {code}, and no scene ENTERS on {code}";
                else if (to.Count > 1) yield return $"code {code} is entered by {string.Join(", ", to.Select(x => x.Id))} - it must be one scene";
            }
        var reached = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var sc in Scenes) foreach (var code in sc.Exits()) foreach (var to in EnteredBy(code)) reached.Add(to.Id);
        foreach (var sc in Scenes)
            if (!sc.Id.Equals(Start, StringComparison.OrdinalIgnoreCase) && !reached.Contains(sc.Id))
                yield return $"{sc.Id} is entered by nobody (ENTERS = {string.Join(" ", sc.Enters)})";
        for (int i = 0; i < Scenes.Count; i++)
            for (int j = i + 1; j < Scenes.Count; j++)
                foreach (var c in Scenes[i].Enters.Intersect(Scenes[j].Enters))
                    yield return $"{Scenes[i].Id} and {Scenes[j].Id} both ENTER on {c}";
    }

    // A code no scene uses yet - for a new scene, or a new quiz answer.
    public int FreeCode()
    {
        var used = new HashSet<int>(Scenes.SelectMany(x => x.Enters).Concat(Scenes.SelectMany(x => x.Exits())));
        int c = 1; while (used.Contains(c)) c++; return c;
    }

    public static List<string> Split(string t) =>
        (t ?? "").Split(new[] { ' ', ',', ';' }, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries).ToList();
    public static List<int> Ints(string t) { var l = new List<int>(); foreach (var s in Split(t)) if (int.TryParse(s, out var v)) l.Add(v); return l; }
}

// ============================================================================
public class Scene
{
    public const string FILE = "SCENE.INI";

    public string Id = "";                          // S03, END_STAY - also the folder name
    public string Title = "", Notes = "", Learn = "", Decide = "";
    public bool Ending;
    public List<int> Enters = new();                // the codes that start this scene
    public int? Code;                               // how it ends, when no quiz decides
    public List<Section> Sections = new();

    public string Dir(Story s) => Path.Combine(s.Dir, Id);
    public string MatDir(Story s) => Path.Combine(s.MatDir, Id);

    public QuizSection Quiz => Sections.OfType<QuizSection>().LastOrDefault();

    // The codes this scene can end with: the quiz's answers if it has a
    // quiz, else its own CODE. An ending ends with nothing.
    public IEnumerable<int> Exits()
    {
        if (Ending) yield break;
        var q = Quiz;
        if (q != null) { foreach (var o in q.Options) yield return o.Code; yield break; }
        if (Code.HasValue) yield return Code.Value;
    }

    public static Scene Load(string dir)
    {
        var sc = new Scene { Id = Path.GetFileName(dir) };
        Section cur = null;
        foreach (var l in Ini.Read(Path.Combine(dir, FILE)))
        {
            if (l.Key == null)                      // a section header
            {
                cur = l.Section switch
                {
                    "VIDEO" => new VideoSection(),
                    "PICKUP" => new PickupSection(),
                    "QUIZ" => new QuizSection(),
                    _ => null,
                };
                if (cur != null) sc.Sections.Add(cur);
                continue;
            }
            if (cur == null)
                switch (l.Key)
                {
                    case "TITLE": sc.Title = l.Value; break;
                    case "NOTES": sc.Notes = Ini.Many(l.Value); break;
                    case "LEARN": sc.Learn = l.Value; break;
                    case "DECIDE": sc.Decide = l.Value; break;
                    case "ENDING": sc.Ending = l.Value.Equals("yes", StringComparison.OrdinalIgnoreCase); break;
                    case "ENTERS": sc.Enters = Story.Ints(l.Value); break;
                    case "CODE": sc.Code = int.TryParse(l.Value, out var c) ? c : null; break;
                }
            else cur.Read(l);
        }
        return sc;
    }

    public void Save(Story s)
    {
        var d = Dir(s);
        Directory.CreateDirectory(d);
        var w = new Ini.Writer()
            .Comment($"SCENE.INI - scene {Id} of {s.Name}. Written by SceneDesk; the game reads it.")
            .Comment("The sections play in the order written. The scene ends with a CODE: the")
            .Comment("QUIZ's chosen answer if there is one, else the CODE line. The next scene")
            .Comment("is the one whose ENTERS holds that number.")
            .Blank()
            .Key("TITLE", Title)
            .Key("ENTERS", string.Join(" ", Enters))
            .Key("CODE", Code?.ToString() ?? "")
            .Key("ENDING", Ending ? "yes" : "no")
            .Key("NOTES", Ini.One(Notes))
            .Key("LEARN", Ini.One(Learn))
            .Key("DECIDE", Ini.One(Decide));
        foreach (var sec in Sections) { w.Blank().Section(sec.Kind); sec.Write(w); }
        w.Save(Path.Combine(d, FILE));
    }

    // Every section's state, asked of the disk now.
    public void Refresh(Story s) { foreach (var sec in Sections) sec.Refresh(s, this); }

    // What is missing. Empty = complete.
    public IEnumerable<string> Gaps(Story s)
    {
        Refresh(s);
        if (Sections.Count == 0) yield return "no sections - nothing plays";
        for (int i = 0; i < Sections.Count; i++)
            foreach (var g in Sections[i].Gaps(s, this)) yield return $"{Sections[i].Kind.ToLower()} {i + 1}: {g}";
        if (!Ending && !Exits().Any()) yield return "no CODE and no quiz - the story stops here, and it is not an ending";
        if (Enters.Count == 0 && !Id.Equals(s.Start, StringComparison.OrdinalIgnoreCase)) yield return "no ENTERS - nothing can lead here";
    }

    // Done / partly / nothing, for the colours.
    public int DoneCount => Sections.Count(x => x.Done);
    public string Marks => string.Concat(Sections.Select(x => x.Mark));
    public override string ToString() => $"{Id}  {Title}";
}

// ============================================================================
public abstract class Section
{
    public abstract string Kind { get; }
    public bool Done;                               // the product is there and current
    public abstract string Mark { get; }            // one glyph for the tree
    public abstract void Read(IniLine l);
    public abstract void Write(Ini.Writer w);
    public abstract void Refresh(Story s, Scene sc);
    public abstract IEnumerable<string> Gaps(Story s, Scene sc);
    public abstract string Describe(Story s, Scene sc);

    // The converter writes the .INF first and the product last. A product
    // OLDER than its recipe was made from an EARLIER recipe: that run
    // failed and the old file stayed. Shown, but not counted.
    protected static bool Fresh(string product, string inf)
        => File.Exists(product) && (!File.Exists(inf) || File.GetLastWriteTimeUtc(product) >= File.GetLastWriteTimeUtc(inf));
    protected static bool Stale(string product, string inf)
        => File.Exists(product) && File.Exists(inf) && File.GetLastWriteTimeUtc(product) < File.GetLastWriteTimeUtc(inf);
}

// ---- [VIDEO] ---------------------------------------------------------------
//  FILE   = CLIP1.OWV          the product, in the scene folder
//  SOURCE = VIDEO\take3.mp4    the footage, relative to the scene's warehouse folder
public class VideoSection : Section
{
    public override string Kind => "VIDEO";
    public string File = "", Source = "";
    public bool StaleProduct;
    public override string Mark => Done ? "▶" : StaleProduct ? "▷" : Source == "" ? "·" : "▷";

    public string Inf => Path.ChangeExtension(File, ".INF");
    public string Product(Story s, Scene sc) => Path.Combine(sc.Dir(s), File);
    public string InfPath(Story s, Scene sc) => Path.Combine(sc.Dir(s), Inf);
    public string SourceAbs(Story s, Scene sc) => Source == "" ? null : Path.Combine(sc.MatDir(s), Source);

    public override void Read(IniLine l) { if (l.Key == "FILE") File = l.Value; else if (l.Key == "SOURCE") Source = l.Value; }
    public override void Write(Ini.Writer w) { w.Key("FILE", File); w.Key("SOURCE", Source); }
    public override void Refresh(Story s, Scene sc)
    {
        Done = File != "" && Fresh(Product(s, sc), InfPath(s, sc));
        StaleProduct = File != "" && Stale(Product(s, sc), InfPath(s, sc));
    }
    public override IEnumerable<string> Gaps(Story s, Scene sc)
    {
        if (Source == "") { yield return "no footage chosen"; yield break; }
        if (!System.IO.File.Exists(SourceAbs(s, sc))) yield return $"footage missing: {Source}";
        if (StaleProduct) yield return $"{File} is from an EARLIER source - convert again";
        else if (!Done) yield return $"{Source} not converted";
    }
    public override string Describe(Story s, Scene sc)
        => Done ? $"▶ video   {File}  ← {Source}"
         : StaleProduct ? $"▷ video   {File} STALE, made from an earlier source. ⟳ makes it from {Source}"
         : Source != "" ? $"▷ video   NOT converted ← {Source}" + (System.IO.File.Exists(SourceAbs(s, sc)) ? "" : "   (footage missing)")
         : "· video   no footage";
}

// ---- [PICKUP] --------------------------------------------------------------
//  FOLDER = PICKUP             the material folder in the warehouse, and the
//                              product folder in the scene: BG.OWV, <ITEM>.SPR
//  NEED   = KEYS CASSETTE      what must be collected for the scene to go on
//  ITEM KEYS = 640,240 layer-keys.png     where it sits in the SOURCE picture
//                                          (the .SPR knows where on screen)
//  In the warehouse folder: empty.jpg (the room without the things), full.jpg
//  (with them - the reference the desk places against), layer-*.png (each
//  thing, cut out, with alpha).
public class PickupSection : Section
{
    public override string Kind => "PICKUP";
    public string Folder = "PICKUP";
    public List<string> Need = new();
    public List<Item> Items = new();
    public bool StaleProduct;
    public override string Mark => Done ? "■" : Items.Count > 0 && Items.All(i => i.Placed) ? "□" : "·";

    public const string EMPTY = "empty.jpg", FULL = "full.jpg", BG = "BG.OWV", INF = "PICKUP.INF";
    public string MatDir(Story s, Scene sc) => Path.Combine(sc.MatDir(s), Folder);
    public string OutDir(Story s, Scene sc) => Path.Combine(sc.Dir(s), Folder);
    public string EmptyAbs(Story s, Scene sc) => FindPicture(MatDir(s, sc), "empty");
    public string FullAbs(Story s, Scene sc) => FindPicture(MatDir(s, sc), "full");
    static string FindPicture(string dir, string stem)
    {
        if (!Directory.Exists(dir)) return null;
        foreach (var ext in new[] { ".png", ".jpg", ".jpeg", ".bmp" })
        { var p = Path.Combine(dir, stem + ext); if (File.Exists(p)) return p; }
        return null;
    }
    // every layer-*.png in the folder is an item, whether the INI knows it yet or not
    public IEnumerable<string> LayersOnDisk(Story s, Scene sc)
        => Directory.Exists(MatDir(s, sc)) ? Directory.GetFiles(MatDir(s, sc), "layer-*.png").Select(Path.GetFileName).OrderBy(x => x) : Enumerable.Empty<string>();
    public static string NameOf(string layer)
    {
        var n = Path.GetFileNameWithoutExtension(layer);
        if (n.StartsWith("layer-", StringComparison.OrdinalIgnoreCase)) n = n.Substring(6);
        n = new string(n.Where(char.IsLetterOrDigit).ToArray()).ToUpperInvariant();
        return n.Length > 8 ? n.Substring(0, 8) : n;                        // 8.3 for the .SPR
    }
    public void AdoptLayers(Story s, Scene sc)
    {
        foreach (var layer in LayersOnDisk(s, sc))
            if (!Items.Any(i => i.Layer.Equals(layer, StringComparison.OrdinalIgnoreCase)))
                Items.Add(new Item { Name = NameOf(layer), Layer = layer });
    }

    public override void Read(IniLine l)
    {
        switch (l.Key)
        {
            case "FOLDER": Folder = l.Value; break;
            case "NEED": Need = Story.Split(l.Value); break;
            case "ITEM":
                {
                    var it = new Item { Name = (l.Sub ?? "").ToUpperInvariant() };
                    var parts = l.Value.Split(' ', 2, StringSplitOptions.RemoveEmptyEntries);
                    if (parts.Length > 0)
                    {
                        var xy = parts[0].Split(',');
                        if (xy.Length == 2 && int.TryParse(xy[0], out var x) && int.TryParse(xy[1], out var y)) { it.X = x; it.Y = y; }
                        else if (parts[0] == "?") { }
                        else if (parts.Length == 1) { it.Layer = parts[0]; }
                    }
                    if (parts.Length > 1) it.Layer = parts[1].Trim();
                    Items.Add(it);
                    break;
                }
        }
    }
    public override void Write(Ini.Writer w)
    {
        w.Key("FOLDER", Folder);
        w.Key("NEED", string.Join(" ", Need));
        foreach (var it in Items) w.Key("ITEM", it.Name, (it.Placed ? $"{it.X},{it.Y}" : "?") + " " + it.Layer);
    }
    public override void Refresh(Story s, Scene sc)
    {
        var inf = Path.Combine(OutDir(s, sc), INF);
        var bg = Path.Combine(OutDir(s, sc), BG);
        bool all = Fresh(bg, inf) && Items.All(i => Fresh(Path.Combine(OutDir(s, sc), i.Name + ".SPR"), inf));
        Done = Items.Count > 0 && Items.All(i => i.Placed) && all;
        StaleProduct = Stale(bg, inf);
    }
    public override IEnumerable<string> Gaps(Story s, Scene sc)
    {
        if (EmptyAbs(s, sc) == null) yield return $"no {EMPTY} in {Folder}\\";
        if (Items.Count == 0) yield return "no layer-*.png - nothing to pick up";
        foreach (var it in Items) if (!it.Placed) yield return $"{it.Name} not placed";
        foreach (var n in Need) if (!Items.Any(i => i.Name.Equals(n, StringComparison.OrdinalIgnoreCase))) yield return $"NEED names {n}, which is not an item";
        if (Items.Count > 0 && Items.All(i => i.Placed) && !Done) yield return StaleProduct ? "products are from an EARLIER placement - convert again" : "not converted";
    }
    public override string Describe(Story s, Scene sc)
    {
        int placed = Items.Count(i => i.Placed);
        string state = Done ? "converted" : StaleProduct ? "STALE - convert again" : placed == Items.Count && Items.Count > 0 ? "NOT CONVERTED" : $"{Items.Count - placed} to place";
        return (Done ? "■" : "□") + $" pickup  {Folder}\\  {Items.Count} item(s), {placed} placed, {state}" + (Need.Count > 0 ? $"   need: {string.Join(" ", Need)}" : "   need: all");
    }
}

public class Item
{
    public string Name = "", Layer = "";
    public int? X, Y;
    public bool Placed => X.HasValue && Y.HasValue;
}

// ---- [QUIZ] ----------------------------------------------------------------
//  TEXT     = You'll come with me?
//  OPTION 1 = Yes            the number is the CODE the scene ends with
//  OPTION 2 = No
public class QuizSection : Section
{
    public override string Kind => "QUIZ";
    public string Text = "";
    public List<Option> Options = new();
    public override string Mark => Done ? "?" : "¿";

    public override void Read(IniLine l)
    {
        if (l.Key == "TEXT") Text = l.Value;
        else if (l.Key == "OPTION" && int.TryParse(l.Sub, out var c)) Options.Add(new Option { Code = c, Text = l.Value });
    }
    public override void Write(Ini.Writer w)
    {
        w.Key("TEXT", Text);
        foreach (var o in Options) w.Key("OPTION", o.Code.ToString(), o.Text);
    }
    public override void Refresh(Story s, Scene sc) => Done = Text.Trim().Length > 0 && Options.Count >= 2;
    public override IEnumerable<string> Gaps(Story s, Scene sc)
    {
        if (Text.Trim().Length == 0) yield return "no question";
        if (Options.Count < 2) yield return "fewer than two answers";
        foreach (var g in Options.GroupBy(o => o.Code).Where(g => g.Count() > 1)) yield return $"two answers share code {g.Key}";
    }
    public override string Describe(Story s, Scene sc)
        => (Done ? "?" : "¿") + $" quiz    \"{Text}\"   " + string.Join("   ", Options.Select(o => $"{o.Code}: {o.Text}"));
}

public class Option { public int Code; public string Text = ""; }
