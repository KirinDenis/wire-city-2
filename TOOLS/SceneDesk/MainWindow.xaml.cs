// ============================================================================
//  SceneDesk - the production desk for a story told in scenes.
//
//      dotnet run --project TOOLS\SceneDesk -- LAB\OWLFLY4\STORY\NIGHT
//
//  A story is STORY.INI and a folder per scene with SCENE.INI in it (see
//  Model.cs). A scene is a list of SECTIONS that play in order - VIDEO,
//  PICKUP, QUIZ - and ends with a CODE that the next scene ENTERS on.
//
//  Built around the OPERATOR'S day, which has very few verbs:
//
//    add       files land in the warehouse - from Explorer, from a render,
//              by Ctrl+V. The desk watches the folder and shows them as ○.
//              Every scene has VIDEO\ and PICKUP\ folders there, made for it.
//    assign    drag footage onto a scene, or select the scene and
//              double-click the file: it becomes the scene's next VIDEO
//              section (or fills an empty one), and conversion starts.
//              Pictures go into the scene's PICKUP\ folder: empty.jpg,
//              full.jpg, layer-*.png - and "+ pickup" makes the section.
//    place     in a PICKUP, the desk finds each layer in full.jpg and puts
//              it there when it matches exactly; the rest you drag. Click a
//              thing on the empty room to see it go, the way the game does.
//    decide    a QUIZ is a question and numbered answers; the number is the
//              code the scene ends with, and "What is missing" says which
//              codes have nowhere to go.
//    undo      the last assign, one step.
//    navigate  click a scene or one of its sections: the name is at the top
//              right in letters you cannot miss, and its material lights up
//              on the left. Click a file: after a beat, its scene is selected.
//    watch     Play / Stop on a video section; a picture in the warehouse
//              shows on click. Raw footage opens in whatever player the
//              machine has.
//    progress  the top bar: how many scenes are green, yellow, red, and
//              whether the codes add up.
//
//  THE FOLDER IS THE SCENE. Footage assigned from anywhere else is MOVED into
//  the scene's VIDEO\ folder (copied, if another scene still uses it), so the
//  left tree can be read by position alone. Nothing is matched by file name.
//
//  The story is written after every change - at the same moment as the .INF
//  beside the product - so the files and the folders cannot disagree.
//
//  Converted material is drawn by OwvPlayer, our own decoder - what the game
//  draws. Nothing plays by itself.
// ============================================================================

using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;

namespace SceneDesk;

public partial class MainWindow : Window
{
    Story story = new();
    string repoRoot;
    Scene cur;
    Section curSec;
    bool filling;

    OwvPlayer owv;
    readonly DispatcherTimer owvTick = new() { Interval = TimeSpan.FromMilliseconds(15) };
    readonly Stopwatch clock = new();

    readonly Queue<Action> jobs = new();
    bool jobRunning;

    Point dragStart; string dragFile;

    FileSystemWatcher watch;
    readonly DispatcherTimer rescan = new() { Interval = TimeSpan.FromMilliseconds(600) };
    readonly DispatcherTimer hilite = new() { Interval = TimeSpan.FromMilliseconds(350) };
    bool syncing;

    // One step of undo: an assign. The section it filled (null OldSource =
    // it was made by the assign and goes away), and the file move to reverse.
    record UndoStep(Scene Scene, VideoSection Section, string OldSource, string OldFile, string MovedFrom = null, string MovedTo = null);
    UndoStep undo;

    static readonly string[] VideoExt = { ".mp4", ".mov", ".avi", ".mkv", ".webm" };
    static readonly string[] ImageExt = { ".png", ".jpg", ".jpeg", ".bmp" };

    static readonly Brush Green  = new SolidColorBrush(Color.FromRgb(0x1a, 0x7f, 0x37));
    static readonly Brush Yellow = new SolidColorBrush(Color.FromRgb(0xb0, 0x7a, 0x00));
    static readonly Brush Red    = new SolidColorBrush(Color.FromRgb(0xb3, 0x26, 0x1e));
    static readonly Brush Grey   = new SolidColorBrush(Color.FromRgb(0x55, 0x55, 0x60));

    const string DRAG = "SceneDeskFile";

    public MainWindow() : this(Environment.GetCommandLineArgs().Skip(1).ToArray()) { }

    public MainWindow(string[] args)
    {
        InitializeComponent();
        owvTick.Tick += (_, _) => OwvStep();
        rescan.Tick += (_, _) => { rescan.Stop(); BuildWarehouse(); BuildStory(cur); };
        hilite.Tick += (_, _) =>
        {
            hilite.Stop();
            var target = SceneOfWarehouseItem(TreeWare.SelectedItem as TreeViewItem);
            if (target != null && target != cur) { syncing = true; SelectScene(target); syncing = false; }
        };
        var where = args.Length > 0 ? Path.GetFullPath(args[0]) : FindDefaultStory();
        if (File.Exists(where)) where = Path.GetDirectoryName(where);      // STORY.INI or SCENARIO.JSON given: its folder
        LoadStory(where);
    }

    // ------------------------------------------------------------------------
    //  the script: the desk driven from a file, and photographed
    //
    //  One step per line. Blank lines and lines starting with # are skipped.
    //      scene S04                select that scene
    //      section 2                select that section of it (1-based)
    //      file S03\VIDEO\x.mp4     select that file in the warehouse (relative to <warehouse>\<NAME>\)
    //      folder S05\PICKUP        select that folder
    //      assign S03\VIDEO\x.mp4   give that file to the selected scene (as a double-click would)
    //      addpickup | addquiz      the buttons
    //      place                    "Place by matching" on the selected pickup
    //      showempty | showfull     the pickup's picture
    //      undo
    //      wait 500                 milliseconds
    //      shot name.png            render the window into the shots folder
    //      quit
    //  Every step is followed by a short settle so timers - the 350 ms
    //  cross-selection, the 600 ms rescan - get to fire the way they would
    //  under a hand. A script leaves no trace: nothing is saved.
    // ------------------------------------------------------------------------
    bool scripted;

    public void RunScript(string[] lines, string shotsDir)
    {
        scripted = true;
        Directory.CreateDirectory(shotsDir);
        var steps = new Queue<string>(lines.Select(l => l.Trim()).Where(l => l.Length > 0 && !l.StartsWith("#")));
        var t = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(500) };
        t.Tick += (_, _) =>
        {
            if (steps.Count == 0) { t.Stop(); Close(); return; }
            var line = steps.Dequeue();
            int sp = line.IndexOf(' ');
            string verb = sp < 0 ? line : line.Substring(0, sp), arg = sp < 0 ? "" : line.Substring(sp + 1).Trim();
            try
            {
                switch (verb.ToLowerInvariant())
                {
                    case "scene":   { var sc = story.ById().GetValueOrDefault(arg); if (sc != null) SelectScene(sc); else Status("script: no scene " + arg); break; }
                    case "section": { if (cur != null && int.TryParse(arg, out var n) && n >= 1 && n <= cur.Sections.Count) LstSections.SelectedIndex = n - 1; break; }
                    case "file":
                    case "folder":  { var want = Path.GetFullPath(Path.Combine(story.MatDir, arg));
                                      var it = AllItems(TreeWare.Items).FirstOrDefault(x => x.Tag is string p && p.Equals(want, StringComparison.OrdinalIgnoreCase));
                                      if (it != null) Reveal(it); else Status("script: not in the warehouse: " + arg); break; }
                    case "assign":  { if (cur != null) Assign(cur, Path.GetFullPath(Path.Combine(story.MatDir, arg))); break; }
                    case "addpickup": AddPickup_Click(null, null); break;
                    case "addquiz": AddQuiz_Click(null, null); break;
                    case "place":   AutoPlace_Click(null, null); break;
                    case "placeat": { // placeat NAME x,y - by hand, as a drag would (and converts when it was the last)
                                      if (curSec is PickupSection pk) { var a = arg.Split(' ', 2); var xy = a[1].Split(',');
                                        var it = pk.Items.FirstOrDefault(x => x.Name.Equals(a[0], StringComparison.OrdinalIgnoreCase));
                                        if (it != null) { it.X = int.Parse(xy[0]); it.Y = int.Parse(xy[1]); PickupPlacementChanged(pk); } }
                                      break; }
                    case "convert": if (cur != null && curSec != null) Convert(cur, curSec); break;
                    case "save":    story.Save(); Status("script: saved"); break;      // the one step that leaves a trace, on purpose
                    case "showempty": ShowEmpty_Click(null, null); break;
                    case "showfull": ShowFull_Click(null, null); break;
                    case "undo":    Undo_Click(null, null); break;
                    case "wait":    t.Interval = TimeSpan.FromMilliseconds(int.Parse(arg)); return;
                    case "shot":    Shot(Path.Combine(shotsDir, arg)); break;
                    case "quit":    steps.Clear(); break;
                    default:        Status("script: unknown step " + verb); break;
                }
            }
            catch (Exception ex) { Status($"script: {line} -> {ex.Message}"); }
            t.Interval = TimeSpan.FromMilliseconds(500);
        };
        t.Start();
    }

    void Shot(string path)
    {
        var root = (FrameworkElement)Content;
        root.UpdateLayout();
        int w = (int)Math.Ceiling(root.ActualWidth), h = (int)Math.Ceiling(root.ActualHeight);
        if (w == 0 || h == 0) { Status("script: nothing to shoot yet"); return; }
        var rtb = new RenderTargetBitmap(w, h, 96, 96, PixelFormats.Pbgra32);
        var dv = new DrawingVisual();
        using (var dc = dv.RenderOpen())
        {
            dc.DrawRectangle(Background, null, new Rect(0, 0, w, h));
            dc.DrawRectangle(new VisualBrush(root), null, new Rect(0, 0, w, h));
        }
        rtb.Render(dv);
        var enc = new PngBitmapEncoder();
        enc.Frames.Add(BitmapFrame.Create(rtb));
        using var fs = File.Create(path);
        enc.Save(fs);
        Status("shot: " + Path.GetFileName(path));
    }

    static string FindDefaultStory()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir != null)
        {
            var p = Path.Combine(dir.FullName, "LAB", "OWLFLY4", "STORY", "NIGHT");
            if (Directory.Exists(p)) return p;
            dir = dir.Parent;
        }
        return Environment.CurrentDirectory;
    }

    static string FindRepoRoot(string from)
    {
        var dir = new DirectoryInfo(from);
        while (dir != null)
        {
            if (Directory.Exists(Path.Combine(dir.FullName, "TOOLS", "Vid2Owv"))) return dir.FullName;
            dir = dir.Parent;
        }
        return null;
    }

    // ---- paths -----------------------------------------------------------------
    string SceneDir(Scene sc) => sc.Dir(story);
    string SceneMat(Scene sc) => sc.MatDir(story);
    string Rel(string abs) => Path.GetRelativePath(story.MatDir, abs);          // for messages

    // ------------------------------------------------------------------------
    //  load / save
    // ------------------------------------------------------------------------
    void LoadStory(string dir)
    {
        var json = Path.Combine(dir, "SCENARIO.JSON");
        if (!File.Exists(Path.Combine(dir, Story.FILE)) && File.Exists(json)) Migrate(json, dir);
        story = Story.Load(dir);
        repoRoot = FindRepoRoot(dir);
        Title = $"SceneDesk  —  {story.Title}  [{story.Name}]";
        BuildWarehouse();
        BuildStory(story.ById().GetValueOrDefault(story.Start) ?? story.Scenes.FirstOrDefault());
        WatchWarehouse();
        Status(migrated ?? (repoRoot == null
            ? "WARNING: TOOLS\\Vid2Owv not found above the story - conversions cannot run"
            : $"story: {dir}     warehouse: {story.Warehouse}"));
    }

    // The desk's first stories were one SCENARIO.JSON. Once, on first sight,
    // it becomes STORY.INI and a SCENE.INI per scene: the clip a VIDEO
    // section, Next a CODE and the target's ENTERS, a fork a QUIZ. Footage
    // had by then been moved into each scene's VIDEO\ folder by hand, so the
    // old path is mapped to the new one by POSITION, not searched by name.
    // The JSON is left where it is; the desk never reads it again.
    void Migrate(string json, string dir)
    {
        var old = System.Text.Json.JsonSerializer.Deserialize<OldScenario>(File.ReadAllText(json));
        if (old == null) return;
        var st = new Story { Dir = dir, Title = old.Title ?? "", Name = string.IsNullOrWhiteSpace(old.Name) ? Path.GetFileName(dir) : old.Name, Warehouse = old.Warehouse ?? "" };
        var scenes = old.Scenes ?? new();
        st.Start = scenes.FirstOrDefault()?.Id ?? "";
        var code = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
        for (int i = 0; i < scenes.Count; i++) code[scenes[i].Id] = i + 1;      // S01 -> 1, S02 -> 2 ...
        foreach (var o in scenes)
        {
            var sc = new Scene { Id = o.Id, Title = o.Title ?? "", Notes = o.Notes ?? "", Learn = o.Learn ?? "", Decide = o.Decide ?? "", Ending = o.Ending };
            if (!sc.Id.Equals(st.Start, StringComparison.OrdinalIgnoreCase)) sc.Enters.Add(code[sc.Id]);
            if (!string.IsNullOrWhiteSpace(o.ClipSource))
            {
                var v = new VideoSection { File = "CLIP.OWV", Source = Path.Combine("VIDEO", Path.GetFileName(o.ClipSource)) };
                sc.Sections.Add(v);
            }
            var next = (o.Next ?? new()).Where(code.ContainsKey).ToList();
            if (next.Count == 1) sc.Code = code[next[0]];
            else if (next.Count > 1)
            {
                var q = new QuizSection { Text = o.Condition ?? "" };
                foreach (var id in next) q.Options.Add(new Option { Code = code[id], Text = scenes.First(x => x.Id == id).Title ?? id });
                sc.Sections.Add(q);
            }
            st.Scenes.Add(sc);
        }
        st.Save();
        migrated = $"SCENARIO.JSON became STORY.INI and {st.Scenes.Count} SCENE.INI files; the JSON is not read any more and can be deleted";
    }
    string migrated;
    class OldScenario { public string Title { get; set; } public string Name { get; set; } public string Warehouse { get; set; } public List<OldScene> Scenes { get; set; } }
    class OldScene { public string Id { get; set; } public string Title { get; set; } public string Notes { get; set; } public string Learn { get; set; } public string Decide { get; set; }
                     public string ClipSource { get; set; } public string StillSource { get; set; } public List<string> Next { get; set; } public string Condition { get; set; } public bool Ending { get; set; } }

    void Save_Click(object s, RoutedEventArgs e) { CommitFields(); story.Save(); Status("saved"); }

    // Written whenever anything changes. A script leaves no trace.
    void AutoSave()
    {
        if (scripted) return;
        try { story.Save(); } catch (Exception ex) { Status("could not write the story: " + ex.Message); }
    }

    void WatchWarehouse()
    {
        watch?.Dispose(); watch = null;
        if (string.IsNullOrWhiteSpace(story.Warehouse) || !Directory.Exists(story.Warehouse)) return;
        watch = new FileSystemWatcher(story.Warehouse)
        {
            IncludeSubdirectories = true,
            NotifyFilter = NotifyFilters.FileName | NotifyFilters.DirectoryName | NotifyFilters.LastWrite | NotifyFilters.Size,
            EnableRaisingEvents = true,
        };
        FileSystemEventHandler kick = (_, e) =>
        {
            if (e.FullPath.Contains("\\frames\\", StringComparison.OrdinalIgnoreCase)) return;
            Dispatcher.BeginInvoke(() => { rescan.Stop(); rescan.Start(); });
        };
        watch.Created += kick; watch.Deleted += kick; watch.Changed += kick;
        watch.Renamed += (s, e) => kick(s, e);
    }

    // ------------------------------------------------------------------------
    //  1. the warehouse
    // ------------------------------------------------------------------------
    // absolute path -> the scene (and section) that uses it
    Dictionary<string, (Scene sc, Section sec)> Owners()
    {
        var d = new Dictionary<string, (Scene, Section)>(StringComparer.OrdinalIgnoreCase);
        foreach (var sc in story.Scenes)
            foreach (var sec in sc.Sections)
            {
                if (sec is VideoSection v && v.Source != "") d[v.SourceAbs(story, sc)] = (sc, sec);
                if (sec is PickupSection p && Directory.Exists(p.MatDir(story, sc)))
                    foreach (var f in Directory.GetFiles(p.MatDir(story, sc))) d[f] = (sc, sec);
            }
        return d;
    }

    List<string> allFiles = new();

    void BuildWarehouse()
    {
        var open = new HashSet<string>(AllItems(TreeWare.Items).Where(t => t.IsExpanded && t.Tag is string).Select(t => (string)t.Tag), StringComparer.OrdinalIgnoreCase);
        bool first = TreeWare.Items.Count == 0;
        var selected = (TreeWare.SelectedItem as TreeViewItem)?.Tag as string;

        TreeWare.Items.Clear();
        if (string.IsNullOrWhiteSpace(story.Warehouse) || !Directory.Exists(story.Warehouse)) { Progress(); return; }
        Directory.CreateDirectory(story.MatDir);
        foreach (var sc in story.Scenes)
        {
            Directory.CreateDirectory(Path.Combine(SceneMat(sc), "VIDEO"));
            Directory.CreateDirectory(Path.Combine(SceneMat(sc), "PICKUP"));
        }

        allFiles = Directory.EnumerateFiles(story.MatDir, "*", SearchOption.AllDirectories)
            .Where(f => !f.Contains("\\frames\\", StringComparison.OrdinalIgnoreCase))
            .Where(f => IsVideo(f) || IsImage(f)).ToList();

        var owners = Owners();
        var filter = FFilter?.Text?.Trim() ?? "";
        var root = FolderNode(new DirectoryInfo(story.MatDir), owners, filter, open, first);
        root.Header = story.Name + "\\";
        root.IsExpanded = true;
        TreeWare.Items.Add(root);

        if (selected != null)
        {
            syncing = true;
            foreach (var t in AllItems(TreeWare.Items)) if (t.Tag is string p && p.Equals(selected, StringComparison.OrdinalIgnoreCase)) { t.IsSelected = true; break; }
            syncing = false;
        }
        Progress();
    }

    TreeViewItem FolderNode(DirectoryInfo dir, Dictionary<string, (Scene sc, Section sec)> owners, string filter, HashSet<string> open, bool first)
    {
        var node = new TreeViewItem { Header = dir.Name + "\\", Tag = dir.FullName, IsExpanded = first || open.Contains(dir.FullName) };
        foreach (var sub in dir.GetDirectories().OrderBy(d => d.Name, StringComparer.OrdinalIgnoreCase))
        {
            if (sub.Name.Equals("frames", StringComparison.OrdinalIgnoreCase)) continue;
            node.Items.Add(FolderNode(sub, owners, filter, open, first));
        }
        foreach (var f in dir.GetFiles().OrderBy(f => f.Name, StringComparer.OrdinalIgnoreCase))
        {
            if (!IsVideo(f.FullName) && !IsImage(f.FullName)) continue;
            if (filter.Length > 0 && !f.Name.Contains(filter, StringComparison.OrdinalIgnoreCase)) continue;
            bool inUse = owners.TryGetValue(f.FullName, out var who);
            node.Items.Add(new TreeViewItem
            {
                Header = inUse ? $"● {f.Name}   ({who.sc.Id} {who.sec.Kind.ToLower()})" : "○ " + f.Name,
                Tag = f.FullName, Foreground = inUse ? Brushes.Black : Grey,
            });
        }
        return node;
    }

    static bool IsVideo(string f) => VideoExt.Contains(Path.GetExtension(f).ToLowerInvariant());
    static bool IsImage(string f) => ImageExt.Contains(Path.GetExtension(f).ToLowerInvariant());

    // The story selected a scene: the warehouse goes to its material - the
    // selected section's file or folder, else the scene's folder.
    void SelectWarehouseOf(Scene sc, Section sec)
    {
        string want = null;
        if (sec is VideoSection v && v.Source != "" && File.Exists(v.SourceAbs(story, sc))) want = v.SourceAbs(story, sc);
        else if (sec is PickupSection p) want = p.MatDir(story, sc);
        want ??= SceneMat(sc);
        foreach (var t in AllItems(TreeWare.Items))
            if (t.Tag is string path && path.Equals(want, StringComparison.OrdinalIgnoreCase)) { Reveal(t); return; }
    }

    // Which scene a warehouse item stands for: a file's owner, or the scene
    // whose folder it is in.
    Scene SceneOfWarehouseItem(TreeViewItem t)
    {
        if (t?.Tag is not string p) return null;
        if (File.Exists(p) && Owners().TryGetValue(p, out var o)) return o.sc;
        foreach (var sc in story.Scenes)
            if (p.StartsWith(SceneMat(sc), StringComparison.OrdinalIgnoreCase)) return sc;
        return null;
    }

    Scene SceneOfPath(string p)
    {
        foreach (var sc in story.Scenes)
            if (p.StartsWith(SceneMat(sc) + "\\", StringComparison.OrdinalIgnoreCase) || p.Equals(SceneMat(sc), StringComparison.OrdinalIgnoreCase)) return sc;
        return null;
    }

    static void Reveal(TreeViewItem t)
    {
        for (var up = ItemsControl.ItemsControlFromItemContainer(t); up is TreeViewItem tv; up = ItemsControl.ItemsControlFromItemContainer(tv))
            tv.IsExpanded = true;
        t.IsSelected = true;
        t.BringIntoView();
        // BringIntoView also scrolls sideways to the END of a long name, and
        // the folder names on the left go off the edge. Back to the left.
        t.Dispatcher.BeginInvoke(DispatcherPriority.Loaded, () =>
        {
            for (DependencyObject o = t; o != null; o = VisualTreeHelper.GetParent(o))
                if (o is ScrollViewer sv) { sv.ScrollToHorizontalOffset(0); break; }
        });
    }

    string SelectedWarehouseFile()
    {
        if (TreeWare.SelectedItem is TreeViewItem t && t.Tag is string p && File.Exists(p)) return p;
        Status("select a file in the warehouse first"); return null;
    }

    string FolderOf(TreeViewItem t)
    {
        if (t?.Tag is string p) return Directory.Exists(p) ? p : Path.GetDirectoryName(p);
        return story.MatDir;
    }

    void Filter_Changed(object s, TextChangedEventArgs e) { if (IsLoaded) BuildWarehouse(); }
    void Rescan_Click(object s, RoutedEventArgs e) { BuildWarehouse(); BuildStory(cur); }

    void Warehouse_Click(object s, RoutedEventArgs e)
    {
        var dlg = new Microsoft.Win32.OpenFolderDialog { Title = "The warehouse root" };
        if (Directory.Exists(story.Warehouse)) dlg.InitialDirectory = story.Warehouse;
        if (dlg.ShowDialog() != true) return;
        story.Warehouse = dlg.FolderName;
        AutoSave();
        BuildWarehouse(); BuildStory(cur); WatchWarehouse();
    }

    void PlayExternal_Click(object s, RoutedEventArgs e)
    {
        var f = SelectedWarehouseFile(); if (f == null) return;
        try { Process.Start(new ProcessStartInfo(f) { UseShellExecute = true }); }
        catch (Exception ex) { Status("cannot open: " + ex.Message); }
    }

    void Ware_Selected(object s, RoutedPropertyChangedEventArgs<object> e)
    {
        hilite.Stop();
        if (TreeWare.SelectedItem is TreeViewItem t && t.Tag is string p)
        {
            if (File.Exists(p) && IsImage(p)) ShowPicture(p);            // a picture shows on click
            if (!syncing) hilite.Start();
        }
    }

    void Ware_DoubleClick(object s, MouseButtonEventArgs e)
    {
        hilite.Stop();
        if (ItemUnder(e.OriginalSource as DependencyObject)?.Tag is not string abs) return;
        if (Directory.Exists(abs))
        {
            // a PICKUP folder: the section for it
            var sc = SceneOfPath(abs);
            if (sc != null && Path.GetFileName(abs).StartsWith("PICKUP", StringComparison.OrdinalIgnoreCase)) { SelectScene(sc); EnsurePickup(sc, Path.GetFileName(abs)); }
            return;
        }
        if (!File.Exists(abs)) return;
        if (cur == null) { Status("select a scene in the story first"); return; }
        Assign(cur, abs);
        e.Handled = true;
    }

    void Ware_MouseDown(object s, MouseButtonEventArgs e)
    {
        dragStart = e.GetPosition(null);
        dragFile = ItemUnder(e.OriginalSource as DependencyObject)?.Tag as string;
        if (dragFile != null && !File.Exists(dragFile)) dragFile = null;
    }

    void Ware_MouseMove(object s, MouseEventArgs e)
    {
        if (dragFile == null || e.LeftButton != MouseButtonState.Pressed) return;
        var d = e.GetPosition(null) - dragStart;
        if (Math.Abs(d.X) < SystemParameters.MinimumHorizontalDragDistance && Math.Abs(d.Y) < SystemParameters.MinimumVerticalDragDistance) return;
        var f = dragFile; dragFile = null;
        DragDrop.DoDragDrop(TreeWare, new DataObject(DRAG, f), DragDropEffects.Copy);
    }

    void Ware_DragOver(object s, DragEventArgs e)
    {
        e.Effects = e.Data.GetDataPresent(DataFormats.FileDrop) ? DragDropEffects.Copy : DragDropEffects.None;
        e.Handled = true;
    }

    void Ware_Drop(object s, DragEventArgs e)
    {
        if (!e.Data.GetDataPresent(DataFormats.FileDrop)) return;
        CopyIn((string[])e.Data.GetData(DataFormats.FileDrop), FolderOf(ItemUnder(e.OriginalSource as DependencyObject)));
        e.Handled = true;
    }

    void Ware_KeyDown(object s, KeyEventArgs e)
    {
        if (e.Key != Key.V || (Keyboard.Modifiers & ModifierKeys.Control) == 0) return;
        if (!Clipboard.ContainsFileDropList()) { Status("nothing on the clipboard to paste"); return; }
        CopyIn(Clipboard.GetFileDropList().Cast<string>().ToArray(), FolderOf(TreeWare.SelectedItem as TreeViewItem));
        e.Handled = true;
    }

    int CopyIn(IEnumerable<string> files, string folder)
    {
        Directory.CreateDirectory(folder);
        int n = 0;
        foreach (var f in files)
        {
            if (!File.Exists(f)) continue;
            var dest = Path.Combine(folder, Path.GetFileName(f));
            if (File.Exists(dest)) { Status($"already there, not overwritten: {Rel(dest)}"); continue; }
            try { File.Copy(f, dest); n++; } catch (Exception ex) { Status("copy failed: " + ex.Message); }
        }
        BuildWarehouse();
        if (n > 0) Status($"copied {n} file(s) into {Rel(folder)}\\");
        return n;
    }

    // ------------------------------------------------------------------------
    //  2. the story - scenes, their sections, and where the codes lead
    // ------------------------------------------------------------------------
    void BuildStory(Scene select)
    {
        var keepSec = curSec;
        TreeStory.Items.Clear();
        var visited = new HashSet<Scene>();
        var start = story.ById().GetValueOrDefault(story.Start);
        if (start != null) AddChain(TreeStory.Items, start, visited);
        var stray = story.Scenes.Where(x => !visited.Contains(x)).ToList();
        if (stray.Count > 0)
        {
            var g = new TreeViewItem { Header = "entered by nobody", IsExpanded = true, Foreground = Grey };
            foreach (var x in stray) { visited.Add(x); g.Items.Add(SceneNode(x)); }
            TreeStory.Items.Add(g);
        }
        if (select != null) SelectScene(select, keepSec);
        Progress();
        if (cur != null) ShowSceneHead();
    }

    void AddChain(ItemCollection items, Scene sc, HashSet<Scene> visited)
    {
        while (sc != null)
        {
            if (visited.Contains(sc)) { items.Add(new TreeViewItem { Header = "↺ back to " + sc.Id, Foreground = Grey }); return; }
            visited.Add(sc);
            var node = SceneNode(sc);
            items.Add(node);
            var exits = sc.Exits().ToList();
            if (exits.Count > 1) { foreach (var c in exits) AddBranch(node.Items, c, visited); return; }
            if (exits.Count == 1)
            {
                var to = story.EnteredBy(exits[0]);
                if (to.Count == 1) sc = to[0];
                else { items.Add(new TreeViewItem { Header = $"→ code {exits[0]}  ({(to.Count == 0 ? "nobody enters on it" : "entered by " + string.Join(", ", to.Select(x => x.Id)))})", Foreground = Red }); return; }
            }
            else sc = null;
        }
    }

    void AddBranch(ItemCollection items, int code, HashSet<Scene> visited)
    {
        var to = story.EnteredBy(code);
        if (to.Count != 1) { items.Add(new TreeViewItem { Header = $"→ code {code}  ({(to.Count == 0 ? "nobody enters on it" : "entered by " + string.Join(", ", to.Select(x => x.Id)))})", Foreground = Red }); return; }
        var t = to[0];
        if (visited.Contains(t)) { items.Add(new TreeViewItem { Header = $"{code} ↺ {t.Id}", Foreground = Grey }); return; }
        visited.Add(t);
        var bn = SceneNode(t, $"{code} → ");
        items.Add(bn);
        var exits = t.Exits().ToList();
        if (exits.Count > 1) foreach (var c in exits) AddBranch(bn.Items, c, visited);
        else if (exits.Count == 1)
        {
            var nx = story.EnteredBy(exits[0]);
            if (nx.Count == 1) AddChain(bn.Items, nx[0], visited);
            else bn.Items.Add(new TreeViewItem { Header = $"→ code {exits[0]}  ({(nx.Count == 0 ? "nobody enters on it" : "entered by " + string.Join(", ", nx.Select(x => x.Id)))})", Foreground = Red });
        }
    }

    Brush StateBrush(Scene sc, out List<string> gaps)
    {
        gaps = sc.Gaps(story).ToList();
        int done = sc.DoneCount;
        return gaps.Count == 0 ? Green : done > 0 ? Yellow : Red;
    }

    // A scene: a coloured dot, the id and title, the sections' marks, how
    // it ends. Under it, one row per section.
    TreeViewItem SceneNode(Scene sc, string prefix = "")
    {
        var brush = StateBrush(sc, out var gaps);
        var exits = sc.Exits().ToList();
        string end = sc.Ending ? "   ▣" : exits.Count > 1 ? "   ⑂ " + string.Join(" ", exits) : exits.Count == 1 ? $"   → {exits[0]}" : "   → ?";
        var tb = new TextBlock();
        if (prefix != "") tb.Inlines.Add(new Run(prefix) { Foreground = Grey });
        tb.Inlines.Add(new Run("● ") { Foreground = brush, FontWeight = FontWeights.Bold });
        tb.Inlines.Add(new Run($"{sc.Id}  {sc.Title}") { FontWeight = FontWeights.SemiBold });
        tb.Inlines.Add(new Run($"   {sc.Marks}{end}") { Foreground = Grey });
        var node = new TreeViewItem { Header = tb, Tag = sc, IsExpanded = true, ToolTip = gaps.Count == 0 ? "complete" : string.Join("\n", gaps) };
        for (int i = 0; i < sc.Sections.Count; i++)
        {
            var sec = sc.Sections[i];
            var st = new TextBlock();
            st.Inlines.Add(new Run($"{sec.Mark} {sec.Kind.ToLower()}") { Foreground = sec.Done ? Brushes.Black : Grey });
            string detail = sec switch
            {
                VideoSection v => v.Source == "" ? "  (no footage)" : "  " + Path.GetFileName(v.Source),
                PickupSection p => $"  {p.Items.Count(x => x.Placed)}/{p.Items.Count} placed",
                QuizSection q => $"  {q.Options.Count} answers",
                _ => "",
            };
            st.Inlines.Add(new Run(detail) { Foreground = Grey });
            node.Items.Add(new TreeViewItem { Header = st, Tag = (sc, sec) });
        }
        return node;
    }

    void SelectScene(Scene sc, Section sec = null)
    {
        foreach (var n in AllItems(TreeStory.Items))
        {
            if (sec != null && n.Tag is ValueTuple<Scene, Section> t && t.Item1 == sc && t.Item2 == sec) { Reveal(n); return; }
        }
        foreach (var n in AllItems(TreeStory.Items))
            if (n.Tag == sc) { Reveal(n); return; }
    }

    static IEnumerable<TreeViewItem> AllItems(ItemCollection items)
    {
        foreach (var o in items)
            if (o is TreeViewItem t) { yield return t; foreach (var c in AllItems(t.Items)) yield return c; }
    }

    void Story_Selected(object s, RoutedPropertyChangedEventArgs<object> e)
    {
        if (TreeStory.SelectedItem is not TreeViewItem t) return;
        Scene sc; Section sec;
        if (t.Tag is Scene x) { sc = x; sec = x.Sections.FirstOrDefault(); }
        else if (t.Tag is ValueTuple<Scene, Section> p) { sc = p.Item1; sec = p.Item2; }
        else return;
        if (sc == cur && sec == curSec) return;
        CommitFields();
        bool sceneChanged = sc != cur;
        cur = sc; curSec = sec;
        if (sceneChanged) FillFields(); else FillSectionList();
        ShowSection();
        if (!syncing) { syncing = true; SelectWarehouseOf(sc, sec); syncing = false; }
    }

    void Story_DoubleClick(object s, MouseButtonEventArgs e)
    {
        if (curSec is VideoSection) { ShowSection(); if (owv != null && owv.FrameCount > 1) StartOwv(); }
        e.Handled = true;
    }

    void Story_DragOver(object s, DragEventArgs e)
    {
        var t = ItemUnder(e.OriginalSource as DependencyObject);
        bool ok = (e.Data.GetDataPresent(DRAG) || e.Data.GetDataPresent(DataFormats.FileDrop)) && t != null && (t.Tag is Scene || t.Tag is ValueTuple<Scene, Section>);
        e.Effects = ok ? DragDropEffects.Copy : DragDropEffects.None;
        e.Handled = true;
    }

    void Story_Drop(object s, DragEventArgs e)
    {
        var t = ItemUnder(e.OriginalSource as DependencyObject);
        Scene target = t?.Tag as Scene ?? (t?.Tag is ValueTuple<Scene, Section> p ? p.Item1 : null);
        if (target == null) return;
        if (e.Data.GetDataPresent(DRAG))
        {
            SelectScene(target); Assign(target, (string)e.Data.GetData(DRAG));
        }
        else if (e.Data.GetDataPresent(DataFormats.FileDrop))
        {
            var files = (string[])e.Data.GetData(DataFormats.FileDrop);
            var vids = files.Where(IsVideo).ToList();
            var pics = files.Where(IsImage).ToList();
            if (vids.Count > 0) CopyIn(vids, Path.Combine(SceneMat(target), "VIDEO"));
            if (pics.Count > 0) CopyIn(pics, Path.Combine(SceneMat(target), "PICKUP"));
            SelectScene(target);
            foreach (var f in vids)
            {
                var dest = Path.Combine(SceneMat(target), "VIDEO", Path.GetFileName(f));
                if (File.Exists(dest)) Assign(target, dest);
            }
            if (pics.Count > 0) EnsurePickup(target, "PICKUP");
        }
        e.Handled = true;
    }

    // ---- the verbs: assign, sections, undo ---------------------------------------
    // Footage goes to the scene: into its VIDEO\ folder first (moved if free,
    // copied if another scene still uses it), then into a VIDEO section -
    // the selected one if it is empty, else the first empty one, else a new
    // one at the end - and the converter starts.
    void Assign(Scene sc, string abs)
    {
        if (IsImage(abs))
        {
            var sec = SceneOfPath(abs) == sc && Path.GetFileName(Path.GetDirectoryName(abs)).StartsWith("PICKUP", StringComparison.OrdinalIgnoreCase)
                ? EnsurePickup(sc, Path.GetFileName(Path.GetDirectoryName(abs)))
                : null;
            if (sec == null) Status($"pictures belong in the scene's PICKUP\\ folder - put {Path.GetFileName(abs)} there and press + pickup");
            return;
        }
        if (!IsVideo(abs)) { Status("not footage: " + Path.GetFileName(abs)); return; }

        string from = null, to = null;
        var home = Path.Combine(SceneMat(sc), "VIDEO");
        if (!string.Equals(Path.GetDirectoryName(abs), home, StringComparison.OrdinalIgnoreCase))
        {
            var dest = Path.Combine(home, Path.GetFileName(abs));
            if (File.Exists(dest)) { Status($"{sc.Id}\\VIDEO\\ already holds a {Path.GetFileName(abs)} - rename one of them first"); return; }
            bool shared = Owners().TryGetValue(abs, out var who) && who.sc != sc;
            try
            {
                Directory.CreateDirectory(home);
                if (shared) File.Copy(abs, dest); else File.Move(abs, dest);
            }
            catch (Exception ex) { Status($"could not {(shared ? "copy" : "move")} {Rel(abs)} into {sc.Id}\\VIDEO\\: {ex.Message}"); return; }
            Status($"{(shared ? "copied" : "moved")} {Rel(abs)} -> {Rel(dest)}");
            if (!shared) { from = abs; to = dest; }
            abs = dest;
        }
        var rel = Path.Combine("VIDEO", Path.GetFileName(abs));

        VideoSection v = curSec as VideoSection;
        if (v == null || v.Source != "" || cur != sc) v = sc.Sections.OfType<VideoSection>().FirstOrDefault(x => x.Source == "");
        string oldSource = null, oldFile = null;
        if (v == null) { v = new VideoSection { File = NextClipName(sc) }; sc.Sections.Add(v); }
        else { oldSource = v.Source; oldFile = v.File; if (v.File == "") v.File = NextClipName(sc); }
        if (to == null && string.Equals(v.Source, rel, StringComparison.OrdinalIgnoreCase) && v.Done) { Status($"{sc.Id} already has that clip"); return; }
        undo = new UndoStep(sc, v, oldSource, oldFile, from, to);
        v.Source = rel;
        BtnUndo.IsEnabled = true;
        curSec = v;
        AutoSave();
        Convert(sc, v);
        BuildWarehouse(); BuildStory(sc); FillSectionList(); ShowSection();
    }

    static string NextClipName(Scene sc)
    {
        var used = new HashSet<string>(sc.Sections.OfType<VideoSection>().Select(x => x.File), StringComparer.OrdinalIgnoreCase);
        if (!used.Contains("CLIP.OWV")) return "CLIP.OWV";
        for (int i = 2; ; i++) if (!used.Contains($"CLIP{i}.OWV")) return $"CLIP{i}.OWV";
    }

    PickupSection EnsurePickup(Scene sc, string folder)
    {
        var p = sc.Sections.OfType<PickupSection>().FirstOrDefault(x => x.Folder.Equals(folder, StringComparison.OrdinalIgnoreCase));
        if (p == null)
        {
            p = new PickupSection { Folder = folder };
            sc.Sections.Add(p);
            Status($"{sc.Id}: pickup section added for {folder}\\");
        }
        Directory.CreateDirectory(p.MatDir(story, sc));
        p.AdoptLayers(story, sc);
        curSec = p;
        AutoSave();
        BuildWarehouse(); BuildStory(sc); FillSectionList(); ShowSection();
        return p;
    }

    void AddVideo_Click(object s, RoutedEventArgs e)
    {
        if (cur == null) return;
        var v = new VideoSection { File = NextClipName(cur) };
        cur.Sections.Add(v); curSec = v;
        AutoSave(); BuildStory(cur); FillSectionList(); ShowSection();
        Status($"{cur.Id}: video section added - double-click footage in the warehouse to fill it");
    }

    void AddPickup_Click(object s, RoutedEventArgs e)
    {
        if (cur == null) return;
        string folder = "PICKUP";
        for (int i = 2; cur.Sections.OfType<PickupSection>().Any(x => x.Folder.Equals(folder, StringComparison.OrdinalIgnoreCase)); i++) folder = $"PICKUP{i}";
        EnsurePickup(cur, folder);
    }

    void AddQuiz_Click(object s, RoutedEventArgs e)
    {
        if (cur == null) return;
        var q = new QuizSection { Text = "" };
        int a = story.FreeCode(); q.Options.Add(new Option { Code = a, Text = "Yes" });
        cur.Sections.Add(q);                                   // so the second FreeCode sees the first
        int b = story.FreeCode(); q.Options.Add(new Option { Code = b, Text = "No" });
        curSec = q;
        AutoSave(); BuildStory(cur); FillSectionList(); ShowSection();
        Status($"{cur.Id}: quiz added with codes {a} and {b} - scenes must ENTER on them");
    }

    void RemoveSection_Click(object s, RoutedEventArgs e)
    {
        if (cur == null || curSec == null) return;
        if (MessageBox.Show($"Remove this {curSec.Kind.ToLower()} section from {cur.Id}?\n\nIts converted product is deleted; the warehouse is not touched.", "SceneDesk", MessageBoxButton.YesNo) != MessageBoxResult.Yes) return;
        StopOwv();
        DeleteProducts(cur, curSec);
        int i = cur.Sections.IndexOf(curSec);
        cur.Sections.Remove(curSec);
        curSec = cur.Sections.ElementAtOrDefault(Math.Min(i, cur.Sections.Count - 1));
        undo = null; BtnUndo.IsEnabled = false;
        AutoSave(); BuildWarehouse(); BuildStory(cur); FillSectionList(); ShowSection();
    }

    void DeleteProducts(Scene sc, Section sec)
    {
        if (sec is VideoSection v && v.File != "")
        {
            TryDelete(v.Product(story, sc)); TryDelete(v.InfPath(story, sc)); TryDelete(Path.ChangeExtension(v.Product(story, sc), ".LOG"));
        }
        if (sec is PickupSection p)
        {
            try { if (Directory.Exists(p.OutDir(story, sc))) Directory.Delete(p.OutDir(story, sc), true); } catch { }
        }
    }

    void SectionUp_Click(object s, RoutedEventArgs e) => MoveSection(-1);
    void SectionDown_Click(object s, RoutedEventArgs e) => MoveSection(+1);
    void MoveSection(int d)
    {
        if (cur == null || curSec == null) return;
        int i = cur.Sections.IndexOf(curSec), j = i + d;
        if (j < 0 || j >= cur.Sections.Count) return;
        (cur.Sections[i], cur.Sections[j]) = (cur.Sections[j], cur.Sections[i]);
        AutoSave(); BuildStory(cur); FillSectionList();
    }

    void Reconvert_Click(object s, RoutedEventArgs e)
    {
        if (cur == null || curSec == null) return;
        Convert(cur, curSec);
    }

    // The material folder of the selected section, in Explorer: the answer
    // to "where do I put the pictures for this pickup".
    void OpenFolder_Click(object s, RoutedEventArgs e)
    {
        if (cur == null) return;
        string dir = curSec is PickupSection p ? p.MatDir(story, cur) : Path.Combine(SceneMat(cur), "VIDEO");
        try
        {
            Directory.CreateDirectory(dir);
            Process.Start(new ProcessStartInfo("explorer.exe", $"\"{dir}\"") { UseShellExecute = true });
            Status($"opened {dir}");
        }
        catch (Exception ex) { Status("cannot open: " + ex.Message); }
    }

    void Undo_Click(object s, RoutedEventArgs e)
    {
        if (undo == null) return;
        var u = undo; undo = null; BtnUndo.IsEnabled = false;
        var sc = u.Scene; var v = u.Section;
        StopOwv();
        string moved = "";
        if (u.MovedTo != null && File.Exists(u.MovedTo) && !File.Exists(u.MovedFrom))
        {
            try { File.Move(u.MovedTo, u.MovedFrom); moved = $"; {Path.GetFileName(u.MovedTo)} went back to {Rel(Path.GetDirectoryName(u.MovedFrom))}\\"; }
            catch (Exception ex) { moved = "; could not move the file back: " + ex.Message; }
        }
        DeleteProducts(sc, v);
        if (u.OldSource == null) { sc.Sections.Remove(v); if (curSec == v) curSec = sc.Sections.FirstOrDefault(); Status($"undone: {sc.Id}'s video section is gone" + moved); }
        else
        {
            v.Source = u.OldSource; v.File = u.OldFile;
            if (v.Source != "" && File.Exists(v.SourceAbs(story, sc))) Convert(sc, v);
            Status($"undone: {sc.Id} video is back to {(u.OldSource == "" ? "nothing" : u.OldSource)}" + moved);
        }
        AutoSave();
        SelectScene(sc);
        BuildWarehouse(); BuildStory(sc); FillSectionList(); ShowSection();
    }

    static void TryDelete(string p) { try { if (File.Exists(p)) File.Delete(p); } catch { } }

    static TreeViewItem ItemUnder(DependencyObject o)
    {
        while (o != null && o is not TreeViewItem) o = VisualTreeHelper.GetParent(o);
        return o as TreeViewItem;
    }

    void Add_Click(object s, RoutedEventArgs e)
    {
        CommitFields();
        string id; for (int n = story.Scenes.Count + 1; ; n++) { id = $"S{n:00}"; if (!story.ById().ContainsKey(id)) break; }
        var sc = new Scene { Id = id, Title = "new scene" };
        int at = cur == null ? story.Scenes.Count : story.Scenes.IndexOf(cur) + 1;
        // spliced in after the current scene: the new one takes over where
        // the current one led, and the current one now leads to the new one
        sc.Enters.Add(story.FreeCode());
        if (cur != null && !cur.Ending && cur.Quiz == null) { sc.Code = cur.Code; cur.Code = sc.Enters[0]; }
        story.Scenes.Insert(at, sc);
        if (story.Scenes.Count == 1) { story.Start = sc.Id; sc.Enters.Clear(); }
        cur = sc; curSec = null;
        AutoSave(); BuildWarehouse(); BuildStory(sc); FillFields(); ShowSection();
    }

    // The WHOLE scene. The first time this was pressed the operator meant
    // one video of it, and the scene went - so the question now says what
    // goes with it, and SCENE.INI is renamed rather than deleted: renaming
    // SCENE.INI.REMOVED back brings the scene back, sections and all.
    void Remove_Click(object s, RoutedEventArgs e)
    {
        if (cur == null) return;
        var what = cur.Sections.Count == 0 ? "no sections" : string.Join(", ", cur.Sections.Select(x => x.Kind.ToLower()));
        if (MessageBox.Show($"Remove the WHOLE scene {cur.Id} \"{cur.Title}\" from the story?\n\n" +
                            $"It has {cur.Sections.Count} section(s): {what}. All of them go with it.\n" +
                            "To drop just one video or pickup, answer No and use × section instead.\n\n" +
                            "The folder and its products stay; SCENE.INI becomes SCENE.INI.REMOVED and can be renamed back.",
                            "SceneDesk - remove a scene", MessageBoxButton.YesNo, MessageBoxImage.Warning, MessageBoxResult.No) != MessageBoxResult.Yes) return;
        int i = story.Scenes.IndexOf(cur);
        // whoever led here now leads where this one led, when that is plain
        if (cur.Quiz == null && cur.Code.HasValue)
            foreach (var other in story.Scenes)
            {
                if (other.Code.HasValue && cur.Enters.Contains(other.Code.Value)) other.Code = cur.Code;
                foreach (var o in other.Sections.OfType<QuizSection>().SelectMany(q => q.Options)) if (cur.Enters.Contains(o.Code)) o.Code = cur.Code.Value;
            }
        try
        {
            var ini = Path.Combine(SceneDir(cur), Scene.FILE);
            var kept = ini + ".REMOVED";
            TryDelete(kept);
            if (File.Exists(ini)) File.Move(ini, kept);
        }
        catch (Exception ex) { Status("could not set the scene aside: " + ex.Message); return; }
        bool wasStart = story.Start.Equals(cur.Id, StringComparison.OrdinalIgnoreCase);
        story.Scenes.Remove(cur); cur = null; curSec = null;
        if (wasStart) story.Start = story.Scenes.FirstOrDefault()?.Id ?? "";     // START must name a scene that exists
        AutoSave();
        BuildStory(story.Scenes.ElementAtOrDefault(Math.Max(0, i - 1))); BuildWarehouse(); FillFields(); ShowSection();
    }

    void Up_Click(object s, RoutedEventArgs e) => Move(-1);
    void Down_Click(object s, RoutedEventArgs e) => Move(+1);
    void Move(int d)
    {
        if (cur == null) return;
        CommitFields();
        int i = story.Scenes.IndexOf(cur), j = i + d;
        if (j < 0 || j >= story.Scenes.Count) return;
        (story.Scenes[i], story.Scenes[j]) = (story.Scenes[j], story.Scenes[i]);
        AutoSave(); BuildStory(cur);
    }

    // ------------------------------------------------------------------------
    //  3. the scene, and the progress line
    // ------------------------------------------------------------------------
    void Progress()
    {
        int g = 0, y = 0, r = 0;
        foreach (var sc in story.Scenes)
        {
            var b = StateBrush(sc, out _);
            if (b == Green) g++; else if (b == Yellow) y++; else r++;
        }
        var owners = Owners();
        int free = allFiles.Count(f => !owners.ContainsKey(f));
        int problems = story.Problems().Count();
        TxtProgress.Inlines.Clear();
        TxtProgress.Inlines.Add(new Run($"{story.Scenes.Count} scenes:   "));
        TxtProgress.Inlines.Add(new Run($"● {g} done") { Foreground = Green });
        TxtProgress.Inlines.Add(new Run("   "));
        TxtProgress.Inlines.Add(new Run($"● {y} partly") { Foreground = Yellow });
        TxtProgress.Inlines.Add(new Run("   "));
        TxtProgress.Inlines.Add(new Run($"● {r} empty") { Foreground = Red });
        TxtProgress.Inlines.Add(new Run(problems == 0 ? "      codes add up" : $"      {problems} code problem(s)") { Foreground = problems == 0 ? Green : Red, FontWeight = FontWeights.SemiBold });
        TxtProgress.Inlines.Add(new Run($"      {free} file(s) used by no scene") { Foreground = Grey });
    }

    void ShowSceneHead()
    {
        if (cur == null) { TxtScene.Text = "—"; TxtSceneState.Text = ""; return; }
        var brush = StateBrush(cur, out var gaps);
        TxtScene.Text = $"{cur.Id}   {cur.Title}";
        TxtScene.Foreground = brush;
        TxtSceneState.Text = gaps.Count == 0 ? "complete" : "missing: " + string.Join(";  ", gaps);
    }

    void FillFields()
    {
        filling = true;
        var c = cur ?? new Scene();
        FId.Text = c.Id; FTitle.Text = c.Title; FNotes.Text = c.Notes;
        FLearn.Text = c.Learn; FDecide.Text = c.Decide;
        FEnters.Text = string.Join(" ", c.Enters); FCode.Text = c.Code?.ToString() ?? "";
        FEnding.IsChecked = c.Ending;
        FillSectionList(); ShowSceneHead();
        filling = false;
    }

    void FillSectionList()
    {
        filling = true;
        LstSections.Items.Clear();
        if (cur != null)
        {
            cur.Refresh(story);
            for (int i = 0; i < cur.Sections.Count; i++) LstSections.Items.Add($"{i + 1}. " + cur.Sections[i].Describe(story, cur));
            if (curSec != null && cur.Sections.Contains(curSec)) LstSections.SelectedIndex = cur.Sections.IndexOf(curSec);
        }
        ShowSceneHead();
        filling = false;
    }

    void Section_Selected(object s, SelectionChangedEventArgs e)
    {
        if (filling || cur == null) return;
        int i = LstSections.SelectedIndex;
        if (i < 0 || i >= cur.Sections.Count) return;
        if (cur.Sections[i] == curSec) return;
        CommitSection();
        curSec = cur.Sections[i];
        ShowSection();
        syncing = true; SelectScene(cur, curSec); SelectWarehouseOf(cur, curSec); syncing = false;
    }

    // The selected section: its editor above, its picture below.
    void ShowSection()
    {
        StopOwv(); Picture.Source = null; PickBox.Visibility = Visibility.Collapsed; TxtPreview.Text = ""; TxtPos.Text = "";
        PnlQuiz.Visibility = Visibility.Collapsed; PnlPickup.Visibility = Visibility.Collapsed;
        filling = true;
        switch (curSec)
        {
            case VideoSection v:
                {
                    var prod = v.Product(story, cur);
                    if (File.Exists(prod))
                    {
                        try { owv = new OwvPlayer(prod); owv.NextFrame(); Picture.Source = owv.Bitmap;
                              TxtPreview.Text = $"{v.File}   {owv.FrameCount} frame(s), {owv.Seconds:F1} s" + (owv.HasAudio ? $", {owv.AudioRate} Hz {owv.AudioBits}-bit" : ", silent") + (v.StaleProduct ? "   STALE" : ""); }
                        catch (Exception ex) { Status("cannot decode: " + ex.Message); }
                    }
                    else TxtPreview.Text = v.Source == "" ? "no footage yet" : "not converted yet";
                    break;
                }
            case PickupSection p:
                PnlPickup.Visibility = Visibility.Visible;
                FNeed.Text = string.Join(" ", p.Need);
                p.AdoptLayers(story, cur);
                LoadPick(p, showFull);
                break;
            case QuizSection q:
                PnlQuiz.Visibility = Visibility.Visible;
                FQuizText.Text = q.Text;
                FQuizOptions.Text = string.Join("\n", q.Options.Select(o => $"{o.Code} = {o.Text}"));
                TxtPreview.Text = "a quiz has no picture: the game asks over the last frame";
                break;
            default:
                TxtPreview.Text = cur == null ? "" : "no section selected";
                break;
        }
        filling = false;
    }

    void ShowPicture(string file)
    {
        StopOwv(); PickBox.Visibility = Visibility.Collapsed;
        try
        {
            var bi = new BitmapImage();
            bi.BeginInit(); bi.CacheOption = BitmapCacheOption.OnLoad; bi.UriSource = new Uri(file); bi.EndInit();
            Picture.Source = bi;
            TxtPreview.Text = $"{Path.GetFileName(file)}   {bi.PixelWidth}x{bi.PixelHeight}";
        }
        catch (Exception ex) { Status("cannot show: " + ex.Message); }
    }

    void Field_Changed(object s, RoutedEventArgs e) { if (!filling) CommitFields(); }

    void CommitFields()
    {
        if (cur == null || filling) return;
        CommitSection();
        var newId = FId.Text.Trim();
        bool changed = cur.Title != FTitle.Text.Trim() || cur.Ending != (FEnding.IsChecked == true)
                    || string.Join(" ", cur.Enters) != FEnters.Text.Trim() || (cur.Code?.ToString() ?? "") != FCode.Text.Trim()
                    || cur.Notes != FNotes.Text || cur.Learn != FLearn.Text.Trim() || cur.Decide != FDecide.Text.Trim() || cur.Id != newId;
        if (!changed) return;
        if (newId != cur.Id && newId.Length > 0 && !story.ById().ContainsKey(newId)) RenameScene(cur, newId);
        cur.Title = FTitle.Text.Trim(); cur.Notes = FNotes.Text;
        cur.Learn = FLearn.Text.Trim(); cur.Decide = FDecide.Text.Trim();
        cur.Enters = Story.Ints(FEnters.Text); cur.Code = int.TryParse(FCode.Text.Trim(), out var c) ? c : null;
        cur.Ending = FEnding.IsChecked == true;
        AutoSave();
        BuildStory(cur);
    }

    // A scene is its folder, twice. Both move; the old SCENE.INI goes with it.
    void RenameScene(Scene sc, string newId)
    {
        try
        {
            var a = SceneDir(sc); var am = SceneMat(sc);
            var b = Path.Combine(story.Dir, newId); var bm = Path.Combine(story.MatDir, newId);
            if (Directory.Exists(a)) Directory.Move(a, b);
            if (Directory.Exists(am)) Directory.Move(am, bm);
            if (story.Start.Equals(sc.Id, StringComparison.OrdinalIgnoreCase)) story.Start = newId;
            sc.Id = newId;
            Status($"renamed to {newId}");
        }
        catch (Exception ex) { Status("could not rename: " + ex.Message); FId.Text = sc.Id; }
    }

    void CommitSection()
    {
        if (cur == null || curSec == null || filling) return;
        if (curSec is QuizSection q)
        {
            var opts = new List<Option>();
            foreach (var raw in FQuizOptions.Text.Split('\n'))
            {
                var line = raw.Trim(); if (line.Length == 0) continue;
                int eq = line.IndexOf('=');
                if (eq > 0 && int.TryParse(line.Substring(0, eq).Trim(), out var code)) opts.Add(new Option { Code = code, Text = line.Substring(eq + 1).Trim() });
            }
            bool changed = q.Text != FQuizText.Text.Trim() || opts.Count != q.Options.Count || opts.Zip(q.Options).Any(z => z.First.Code != z.Second.Code || z.First.Text != z.Second.Text);
            if (!changed) return;
            q.Text = FQuizText.Text.Trim(); q.Options = opts;
            AutoSave(); BuildStory(cur); FillSectionList();
        }
        else if (curSec is PickupSection p)
        {
            var need = Story.Split(FNeed.Text).Select(x => x.ToUpperInvariant()).ToList();
            if (string.Join(" ", need) == string.Join(" ", p.Need)) return;
            p.Need = need;
            AutoSave(); BuildStory(cur); FillSectionList();
        }
    }

    void Quiz_Changed(object s, RoutedEventArgs e) { if (!filling) CommitSection(); }
    void Pickup_Changed(object s, RoutedEventArgs e) { if (!filling) CommitSection(); }

    const string M_HAPPENS = "--- WHAT HAPPENS ---", M_LEARN = "--- LEARN ---", M_DECIDE = "--- DECIDE ---";

    void CopyText_Click(object s, RoutedEventArgs e)
    {
        if (cur == null) return;
        CommitFields();
        Clipboard.SetText($"[{cur.Id}] {cur.Title}\n{M_HAPPENS}\n{cur.Notes}\n{M_LEARN}\n{cur.Learn}\n{M_DECIDE}\n{cur.Decide}\n");
        Status($"copied {cur.Id}");
    }

    void PasteText_Click(object s, RoutedEventArgs e)
    {
        if (cur == null || !Clipboard.ContainsText()) return;
        var text = Clipboard.GetText().Replace("\r\n", "\n").Replace("\r", "\n");
        int h = text.IndexOf(M_HAPPENS, StringComparison.Ordinal);
        if (h < 0) { cur.Notes = text.Trim(); FillFields(); AutoSave(); Status("pasted into 'what happens'"); return; }
        var head = text.Substring(0, h).Trim();
        if (head.StartsWith("[")) { int c = head.IndexOf(']'); if (c > 0) cur.Title = head.Substring(c + 1).Trim(); }
        else if (head.Length > 0) cur.Title = head;
        string Between(string from, string to)
        {
            int a = text.IndexOf(from, StringComparison.Ordinal); if (a < 0) return null;
            a += from.Length;
            int b = to == null ? text.Length : text.IndexOf(to, a, StringComparison.Ordinal);
            if (b < 0) b = text.Length;
            return text.Substring(a, b - a).Trim();
        }
        cur.Notes = Between(M_HAPPENS, M_LEARN) ?? cur.Notes;
        cur.Learn = Between(M_LEARN, M_DECIDE) ?? cur.Learn;
        cur.Decide = Between(M_DECIDE, null) ?? cur.Decide;
        FillFields(); AutoSave(); BuildStory(cur); Status($"pasted into {cur.Id}");
    }

    // ------------------------------------------------------------------------
    //  the pickup editor: the room at its own size, the things on it
    // ------------------------------------------------------------------------
    bool showFull = true;
    Image dragging; Point dragOff; Point dragFrom; bool dragMoved;

    void LoadPick(PickupSection p, bool full)
    {
        PickCanvas.Children.Clear();
        var bgPath = full ? (p.FullAbs(story, cur) ?? p.EmptyAbs(story, cur)) : (p.EmptyAbs(story, cur) ?? p.FullAbs(story, cur));
        if (bgPath == null)
        {
            TxtPreview.Text = $"no empty.jpg / full.jpg in {p.Folder}\\ yet"; TxtItems.Text = "";
            TxtPickState.Text = $"EMPTY: put empty.jpg, full.jpg and layer-*.png into {p.MatDir(story, cur)} - drop them on the {p.Folder}\\ folder in the warehouse, on this scene in the story, or press ⧉ Open folder";
            TxtPickState.Foreground = Red;
            return;
        }
        BitmapImage bg;
        try { bg = new BitmapImage(); bg.BeginInit(); bg.CacheOption = BitmapCacheOption.OnLoad; bg.UriSource = new Uri(bgPath); bg.EndInit(); }
        catch (Exception ex) { Status("cannot show: " + ex.Message); return; }
        PickBg.Source = bg;
        PickCanvas.Width = bg.PixelWidth; PickCanvas.Height = bg.PixelHeight;
        PickBox.Visibility = Visibility.Visible;
        int k = 0;
        foreach (var it in p.Items)
        {
            var path = Path.Combine(p.MatDir(story, cur), it.Layer);
            if (!File.Exists(path)) continue;
            BitmapImage li;
            try { li = new BitmapImage(); li.BeginInit(); li.CacheOption = BitmapCacheOption.OnLoad; li.UriSource = new Uri(path); li.EndInit(); }
            catch { continue; }
            var img = new Image { Source = li, Width = li.PixelWidth, Height = li.PixelHeight, Tag = it, Cursor = Cursors.Hand, Opacity = it.Placed ? 1 : 0.75 };
            // an unplaced thing waits in a column at the left edge
            double x = it.Placed ? it.X.Value : 8, y = it.Placed ? it.Y.Value : 8 + k++ * 60;
            Canvas.SetLeft(img, x); Canvas.SetTop(img, y);
            PickCanvas.Children.Add(img);
            if (!it.Placed)
            {
                var r = new System.Windows.Shapes.Rectangle { Width = li.PixelWidth, Height = li.PixelHeight, Stroke = Brushes.Red, StrokeThickness = 6, StrokeDashArray = new DoubleCollection { 4, 4 }, IsHitTestVisible = false };
                Canvas.SetLeft(r, x); Canvas.SetTop(r, y);
                PickCanvas.Children.Add(r);
            }
        }
        TxtPreview.Text = $"{Path.GetFileName(bgPath)}   {bg.PixelWidth}x{bg.PixelHeight}   " + (full ? "the reference; drag a thing to place it" : "what the game draws; click a thing to take it");
        TxtItems.Text = string.Join("\n", p.Items.Select(it => $"{it.Name,-8} {(it.Placed ? $"{it.X},{it.Y}" : "?      ")}  {it.Layer}"));
        // the state, in words and in colour - a □ against a ■ was not seen
        p.Refresh(story, cur);
        int left = p.Items.Count(i => !i.Placed);
        if (p.Done) { TxtPickState.Text = "CONVERTED: BG.OWV and the .SPR files are in the scene folder"; TxtPickState.Foreground = Green; }
        else if (p.StaleProduct) { TxtPickState.Text = "STALE: the products are from an earlier placement - ⟳ convert makes them again"; TxtPickState.Foreground = Yellow; }
        else if (p.Items.Count == 0) { TxtPickState.Text = $"EMPTY: put empty.jpg, full.jpg and layer-*.png into {p.MatDir(story, cur)} - drop them on the {p.Folder}\\ folder in the warehouse, on this scene in the story, or press ⧉ Open folder"; TxtPickState.Foreground = Red; }
        else if (left > 0) { TxtPickState.Text = $"{left} thing(s) still to place - drag them; conversion starts by itself when the last one lands"; TxtPickState.Foreground = Red; }
        else { TxtPickState.Text = jobRunning ? "converting…" : "NOT CONVERTED: press ⟳ convert to make BG.OWV and the .SPR files"; TxtPickState.Foreground = Red; }
    }

    // Every thing placed, and no product yet: the converter starts on its
    // own, the way a clip converts the moment it is assigned. Dragging a
    // placed thing again does the same - the product must match the placement.
    void PickupPlacementChanged(PickupSection p)
    {
        AutoSave();
        LoadPick(p, showFull); BuildStory(cur); FillSectionList();
        if (p.Items.Count > 0 && p.Items.All(i => i.Placed) && p.EmptyAbs(story, cur) != null)
        {
            Convert(cur, p);
            TxtPickState.Text = "converting…"; TxtPickState.Foreground = Yellow;
        }
    }

    void ShowFull_Click(object s, RoutedEventArgs e) { showFull = true; if (curSec is PickupSection p) LoadPick(p, true); }
    void ShowEmpty_Click(object s, RoutedEventArgs e) { showFull = false; if (curSec is PickupSection p) LoadPick(p, false); }
    void PutBack_Click(object s, RoutedEventArgs e) { foreach (var c in PickCanvas.Children.OfType<Image>()) c.Visibility = Visibility.Visible; }

    void Pick_MouseDown(object s, MouseButtonEventArgs e)
    {
        if (e.OriginalSource is not Image img || img.Tag is not Item) return;
        dragging = img; dragMoved = false;
        dragFrom = e.GetPosition(PickCanvas);
        dragOff = new Point(dragFrom.X - Canvas.GetLeft(img), dragFrom.Y - Canvas.GetTop(img));
        PickCanvas.CaptureMouse();
        e.Handled = true;
    }

    void Pick_MouseMove(object s, MouseEventArgs e)
    {
        if (dragging == null || e.LeftButton != MouseButtonState.Pressed) return;
        var p = e.GetPosition(PickCanvas);
        if (!dragMoved && (Math.Abs(p.X - dragFrom.X) > 3 || Math.Abs(p.Y - dragFrom.Y) > 3)) dragMoved = true;
        if (!dragMoved) return;
        Canvas.SetLeft(dragging, Math.Round(p.X - dragOff.X)); Canvas.SetTop(dragging, Math.Round(p.Y - dragOff.Y));
    }

    void Pick_MouseUp(object s, MouseButtonEventArgs e)
    {
        if (dragging == null) return;
        PickCanvas.ReleaseMouseCapture();
        var img = dragging; dragging = null;
        var it = (Item)img.Tag;
        if (dragMoved)
        {
            it.X = (int)Canvas.GetLeft(img); it.Y = (int)Canvas.GetTop(img);
            Status($"{it.Name} placed at {it.X},{it.Y}");
            if (curSec is PickupSection p) PickupPlacementChanged(p);
        }
        else if (!showFull && it.Placed)
        {
            img.Visibility = Visibility.Collapsed;                  // taken - the way the game does it
            Status($"{it.Name} taken; 'put all back' restores it");
        }
        e.Handled = true;
    }

    // Each layer is looked for in full.jpg by its opaque pixels: a coarse
    // scan across the whole picture, then a fine one around the best spot.
    // A layer that was cut from the picture matches to within a fraction of
    // a level per pixel and is placed; one that was drawn separately does
    // not, and is left for the hand - a wrong guess would look like a fact.
    void AutoPlace_Click(object s, RoutedEventArgs e)
    {
        if (cur == null || curSec is not PickupSection p) return;
        var fullPath = p.FullAbs(story, cur);
        if (fullPath == null) { Status("no full.jpg to match against"); return; }
        var f = Pixels(fullPath);
        int placed = 0; var left = new List<string>();
        foreach (var it in p.Items)
        {
            var lp = Path.Combine(p.MatDir(story, cur), it.Layer);
            if (!File.Exists(lp)) continue;
            var l = Pixels(lp);
            var op = new List<(int x, int y)>();
            for (int y = 0; y < l.h; y += 2) for (int x = 0; x < l.w; x += 2) if (l.px[(y * l.w + x) * 4 + 3] > 200) op.Add((x, y));
            if (op.Count == 0) { left.Add(it.Name); continue; }
            double Err(int ox, int oy, int step)
            {
                double sum = 0; int n = 0;
                for (int k = 0; k < op.Count; k += step)
                {
                    int x = ox + op[k].x, y = oy + op[k].y;
                    if (x < 0 || y < 0 || x >= f.w || y >= f.h) return 1e9;
                    int i = (y * f.w + x) * 4, j = (op[k].y * l.w + op[k].x) * 4;
                    sum += Math.Abs(f.px[i] - l.px[j]) + Math.Abs(f.px[i + 1] - l.px[j + 1]) + Math.Abs(f.px[i + 2] - l.px[j + 2]);
                    n++;
                }
                return sum / n;
            }
            int bx = 0, by = 0; double best = 1e9;
            for (int y = 0; y <= f.h - l.h; y += 8) for (int x = 0; x <= f.w - l.w; x += 8)
            { double v = Err(x, y, 7); if (v < best) { best = v; bx = x; by = y; } }
            int fx = bx, fy = by; best = 1e9;
            for (int y = by - 8; y <= by + 8; y++) for (int x = bx - 8; x <= bx + 8; x++)
            { double v = Err(x, y, 1); if (v < best) { best = v; fx = x; fy = y; } }
            if (best < 5) { it.X = fx; it.Y = fy; placed++; } else left.Add(it.Name);
        }
        Status($"placed {placed} by matching" + (left.Count > 0 ? $"; not found, drag them yourself: {string.Join(", ", left)}" : ""));
        PickupPlacementChanged(p);
    }

    static (int w, int h, byte[] px) Pixels(string path)
    {
        var bi = new BitmapImage();
        bi.BeginInit(); bi.CacheOption = BitmapCacheOption.OnLoad; bi.UriSource = new Uri(path); bi.EndInit();
        var conv = new FormatConvertedBitmap(bi, PixelFormats.Bgra32, null, 0);
        var px = new byte[conv.PixelWidth * conv.PixelHeight * 4];
        conv.CopyPixels(px, conv.PixelWidth * 4, 0);
        return (conv.PixelWidth, conv.PixelHeight, px);
    }

    // ------------------------------------------------------------------------
    //  playback of a video section's product
    // ------------------------------------------------------------------------
    void StartOwv()
    {
        if (owv == null) return;
        owv.Reset(); owv.NextFrame(); owv.StartSound();
        clock.Restart(); owvTick.Start(); TxtPos.Text = "playing";
    }

    void OwvStep()
    {
        if (owv == null) return;
        int due = (int)(clock.Elapsed.TotalSeconds * owv.Fps) + 1;
        if (owv.FrameNo >= due) return;
        bool more = true; int guard = 0;
        while (owv.FrameNo < due && guard++ < 12)
            if (!(more = owv.NextFrame(render: false))) break;
        owv.Present();
        if (!more) { owvTick.Stop(); clock.Stop(); TxtPos.Text = "ended"; }
    }

    void StopOwv() { owvTick.Stop(); clock.Stop(); if (owv != null) { owv.Dispose(); owv = null; } }

    void Play_Click(object s, RoutedEventArgs e)
    {
        if (owv == null && curSec is VideoSection) ShowSection();
        if (owv != null && owv.FrameCount > 1) StartOwv();
    }

    void Stop_Click(object s, RoutedEventArgs e)
    {
        if (owv == null) return;
        owvTick.Stop(); clock.Stop(); owv.StopSound();
        TxtPos.Text = $"stopped on frame {owv.FrameNo} of {owv.FrameCount}";
    }

    // ------------------------------------------------------------------------
    //  conversion, in the background, one at a time
    // ------------------------------------------------------------------------
    void Convert(Scene sc, Section sec)
    {
        if (repoRoot == null) { Status("cannot convert: TOOLS\\Vid2Owv not found above the story"); return; }
        string infPath, label, logPath;
        if (sec is VideoSection v)
        {
            if (v.Source == "") { Status("no footage to convert"); return; }
            var srcAbs = v.SourceAbs(story, sc);
            if (!File.Exists(srcAbs)) { Status("footage is missing: " + srcAbs); return; }
            var sceneDir = SceneDir(sc);
            Directory.CreateDirectory(sceneDir);
            // The product of the LAST source must not survive to pose as this
            // one's: let go of the file, and remove it, before the recipe is written.
            StopOwv();
            TryDelete(v.Product(story, sc));
            logPath = Path.ChangeExtension(v.Product(story, sc), ".LOG");
            TryDelete(logPath);
            infPath = v.InfPath(story, sc);
            var srcRel = Path.GetRelativePath(sceneDir, srcAbs);
            File.WriteAllText(infPath, string.Join("\r\n", new[]
            {
                $"; {v.Inf} - written by SceneDesk for scene {sc.Id}. The recipe is tracked;",
                $"; the {v.File} it makes is not, until the codec is frozen. The source is",
                $"; named relative to this folder: long, but it holds wherever the warehouse",
                $"; sits beside the repository.",
                "",
                $"SOURCE     = {srcRel}",
                $"OUTPUT     = {v.File}",
                "WIDTH      = 640",
                "HEIGHT     = 400",
                "FPS        = 12",
                "; 72 frames = six seconds, the unit the footage is generated in: every",
                "; six-second piece is its own keyframe group, so a clip can later be cut",
                "; at those boundaries without converting it again.",
                "KEYEVERY   = 72",
                "AUDIO      = 22050",
                "; sixteen bits: the Sound Blaster 16 plays them and eight bits hiss",
                "AUDIOBITS  = 16",
                "FIT        = crop",
                "DITHER     = bayer:bayer_scale=3",
                "DENOISE    = hqdn3d=4:3:12:9",
                "TOLERANCE  = 2",
                "SEARCH     = 24",
                "COPY       = on",
                "COPYSEARCH = 4",
                "AUDIOFILTER = highpass=f=50,acompressor=threshold=0.06:ratio=4:attack=5:release=200:makeup=2,alimiter=limit=0.97",
                ""
            }));
            label = $"{sc.Id}\\{v.File}";
        }
        else if (sec is PickupSection p)
        {
            var empty = p.EmptyAbs(story, sc);
            if (empty == null) { Status($"no empty.jpg in {p.Folder}\\ - nothing to draw the room from"); return; }
            if (p.Items.Any(i => !i.Placed)) { Status($"place every item first: {string.Join(", ", p.Items.Where(i => !i.Placed).Select(i => i.Name))}"); return; }
            var outDir = p.OutDir(story, sc);
            Directory.CreateDirectory(outDir);
            StopOwv();
            foreach (var f in Directory.GetFiles(outDir, "*.OWV").Concat(Directory.GetFiles(outDir, "*.SPR"))) TryDelete(f);
            infPath = Path.Combine(outDir, PickupSection.INF);
            logPath = Path.Combine(outDir, "PICKUP.LOG");
            TryDelete(logPath);
            var full = p.FullAbs(story, sc) ?? empty;
            var lines = new List<string>
            {
                $"; PICKUP.INF - written by SceneDesk for scene {sc.Id}: the room without its things,",
                $"; the things, and where each stands in the SOURCE picture. Vid2Owv makes BG.OWV",
                $"; and one .SPR per thing, in the room's palette, with the screen position inside.",
                "",
                "MODE       = PICKUP",
                $"EMPTY      = {Path.GetRelativePath(outDir, empty)}",
                $"FULL       = {Path.GetRelativePath(outDir, full)}",
                "OUTDIR     = .",
                "WIDTH      = 640",
                "HEIGHT     = 400",
                "FIT        = crop",
                "DITHER     = bayer:bayer_scale=3",
                "TOLERANCE  = 2",
                "",
            };
            foreach (var it in p.Items) lines.Add($"ITEM {it.Name,-8} = {it.X},{it.Y} {Path.GetRelativePath(outDir, Path.Combine(p.MatDir(story, sc), it.Layer))}");
            lines.Add("");
            File.WriteAllText(infPath, string.Join("\r\n", lines));
            label = $"{sc.Id}\\{p.Folder}\\";
        }
        else { Status("a quiz has nothing to convert"); return; }

        jobs.Enqueue(() =>
        {
            Dispatcher.Invoke(() => Status($"converting {label} …" + (jobs.Count > 0 ? $"  ({jobs.Count} more waiting)" : "")));
            string tail;
            try
            {
                var psi = new ProcessStartInfo("dotnet", $"run --project \"{Path.Combine(repoRoot, "TOOLS", "Vid2Owv")}\" -c Release -- \"{infPath}\"")
                { UseShellExecute = false, CreateNoWindow = true, RedirectStandardOutput = true, RedirectStandardError = true, WorkingDirectory = repoRoot };
                using var pr = Process.Start(psi);
                string outp = pr.StandardOutput.ReadToEnd(), err = pr.StandardError.ReadToEnd();
                pr.WaitForExit();
                var lines = (outp + "\n" + err).Split('\n').Select(l => l.Trim()).Where(l => l.Length > 0).ToList();
                try { File.WriteAllText(logPath, string.Join("\r\n", lines) + "\r\n"); } catch { }
                tail = pr.ExitCode == 0
                    ? $"done: {label}   {lines.FirstOrDefault(l => l.StartsWith("wrote")) ?? ""}   {lines.FirstOrDefault(l => l.StartsWith("duration")) ?? ""}"
                    : $"FAILED: {label} - {lines.LastOrDefault(l => l.Contains("FAILED") || l.Contains("rror")) ?? lines.LastOrDefault() ?? "no output"}";
            }
            catch (Exception ex) { tail = $"FAILED: {label} - {ex.Message}"; }
            Dispatcher.Invoke(() =>
            {
                Status(tail);
                BuildStory(cur); FillSectionList();
                if (cur == sc && curSec == sec) ShowSection();
            });
        });
        RunJobs();
    }

    void RunJobs()
    {
        if (jobRunning || jobs.Count == 0) return;
        jobRunning = true;
        var job = jobs.Dequeue();
        Task.Run(() => { try { job(); } finally { Dispatcher.Invoke(() => { jobRunning = false; RunJobs(); }); } });
    }

    static string FindFfmpeg()
    {
        var env = Environment.GetEnvironmentVariable("FFMPEG");
        if (!string.IsNullOrEmpty(env) && File.Exists(env)) return env;
        foreach (var dir in (Environment.GetEnvironmentVariable("PATH") ?? "").Split(';'))
        {
            var p = Path.Combine(dir.Trim(), "ffmpeg.exe");
            if (dir.Length > 0 && File.Exists(p)) return p;
        }
        foreach (var p in new[] { @"C:\ffmpeg\bin\ffmpeg.exe", @"C:\Program Files\ffmpeg\bin\ffmpeg.exe" })
            if (File.Exists(p)) return p;
        return null;
    }

    // ------------------------------------------------------------------------
    void Gaps_Click(object s, RoutedEventArgs e)
    {
        CommitFields();
        var lines = new List<string>();
        foreach (var pr in story.Problems()) lines.Add("STORY: " + pr);
        foreach (var sc in story.Scenes)
        {
            var g = sc.Gaps(story).ToList();
            if (g.Count > 0) lines.Add($"{sc.Id}  {sc.Title}\n    " + string.Join("\n    ", g));
        }
        MessageBox.Show(lines.Count == 0 ? "Nothing is missing. Every scene is made and every code has one place to go." : string.Join("\n\n", lines),
                        "What is missing", MessageBoxButton.OK);
    }

    protected override void OnClosing(System.ComponentModel.CancelEventArgs e)
    {
        StopOwv();
        watch?.Dispose(); watch = null;
        if (scripted) { base.OnClosing(e); return; }
        CommitFields();
        if (jobRunning && MessageBox.Show("A conversion is still running. Close anyway?", "SceneDesk", MessageBoxButton.YesNo) != MessageBoxResult.Yes) { e.Cancel = true; return; }
        AutoSave();
        base.OnClosing(e);
    }

    void Status(string text) => TxtStatus.Text = text;
}
