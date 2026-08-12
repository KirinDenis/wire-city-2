// ============================================================================
//  Tasm2Fasm - translate this project's TASM sources into FASM sources.
//
//  WHY A TOOL AND NOT A ONE-OFF SED. The two toolchains have to live side by
//  side until the FASM build is trusted, which means the TASM sources keep
//  changing and the translation has to be re-runnable. It also means the
//  translation must never touch the original: every output is a NEW file
//  with an F appended to the base name (CITY.ASM -> CITYF.ASM), which stays
//  inside DOS 8.3 for every name in this repository.
//
//  THE RULES, all of them found by porting GAMES\WIRECITY by hand:
//
//    CODE SEGMENT / ENDS / ASSUME / END x   ->  format binary as 'com'
//                                               org 100h
//    LOCALS / JUMPS                         ->  dropped; FASM needs none
//    .8086                                  ->  include '..\ENGINE\E_8086.INC'
//    word ptr / byte ptr                    ->  word / byte
//    ,offset LABEL                          ->  ,LABEL
//    @@name                                 ->  .name   (local labels)
//    es:[di]                                ->  [es:di]
//    INCLUDE ..\ENGINE\E_MATH.INC           ->  include '..\ENGINE\E_MATHF.INC'
//
//  WHAT IT REFUSES TO GUESS. FASM reserves words TASM did not - the register
//  names of processors far newer than the idiom this code is written in. It
//  has a variable called `rcx` and another called `di`. Renaming those is a
//  judgement (is that symbol even used?), so the tool REPORTS them and
//  translates nothing. In WIRECITY the answer turned out to be worth the
//  trip: `di` was never used at all, because the register name had shadowed
//  it from the start, and every [di] in that file is DS:[DI].
//
//  THE TRAP THAT COST THE MOST. TASM's .8086 restricts the instruction set.
//  FASM has NO equivalent - none - so translating a .8086 source and simply
//  dropping the directive lets FASM encode any out-of-range conditional jump
//  in the 386 long form, silently, in a program that says 8086 on its first
//  line. WIRECITY shipped ten of them before TOOLS\BinAccount found them.
//  That is why .8086 now translates to an include rather than to nothing.
//
//  ON VERIFYING THE RESULT. Do not expect byte-identical output. TASM's
//  JUMPS directive reserves room for a near jump and pads the leftovers with
//  NOPs, because a one-pass assembler cannot go back and shrink. FASM makes
//  several passes and needs no padding. WIRECITY came out 312 bytes smaller,
//  every one of them a NOP. Every byte of the difference must be accounted
//  for like that - an unexplained byte is a bug. Do not do it by eye:
//
//      dotnet run --project TOOLS\BinAccount -c Release -- <tasm.com> <fasm.com>
//
//      dotnet run --project TOOLS\Tasm2Fasm -c Release -- <file-or-dir> ...
//      dotnet run --project TOOLS\Tasm2Fasm -c Release -- GAMES\WIRECITY
// ============================================================================
using System.Text;
using System.Text.RegularExpressions;

static class Tasm2Fasm
{
    // Words FASM will not let you use as a label. The 64-bit register names
    // are the surprising ones: 8086 code cannot see them coming.
    static readonly HashSet<string> Reserved = new(StringComparer.OrdinalIgnoreCase)
    {
        "ax","bx","cx","dx","si","di","bp","sp","al","ah","bl","bh","cl","ch","dl","dh",
        "cs","ds","es","ss","fs","gs","ip",
        "eax","ebx","ecx","edx","esi","edi","ebp","esp","eip",
        "rax","rbx","rcx","rdx","rsi","rdi","rbp","rsp",
        // The byte halves x86-64 added to SI, DI, BP and SP. FLIGHT has a
        // variable called `spl` - span length - which is now the low byte of
        // RSP. Nothing warned about it until FASM refused the file, because
        // this list did not have them.
        "sil","dil","bpl","spl",
        "r8","r9","r10","r11","r12","r13","r14","r15",
        "r8b","r9b","r10b","r11b","r12b","r13b","r14b","r15b",
        "r8w","r9w","r10w","r11w","r12w","r13w","r14w","r15w",
        "r8d","r9d","r10d","r11d","r12d","r13d","r14d","r15d",
        "st","mm","xmm","ymm",
        // Instruction mnemonics. FASM will not take one as a name; TASM would,
        // and the TRAINER has a bank angle called `rol`. Only the ones short
        // enough or English enough to be picked as a variable are listed -
        // nobody calls a variable CMPSB - but the list is cheap and a missing
        // entry means FASM refuses the file with no warning from here first.
        "rol","ror","rcl","rcr","shl","shr","sal","sar",
        "not","and","or","xor","neg","test","cmp",
        "add","sub","adc","sbb","mul","imul","div","idiv","inc","dec",
        "in","out","int","into","iret","call","ret","retf","jmp",
        "push","pop","pushf","popf","mov","lea","les","lds","xchg","xlat",
        "loop","loope","loopz","loopne","loopnz","jcxz",
        "nop","hlt","wait","lock","rep","repe","repne",
        "movs","stos","lods","scas","cmps",
        "clc","cld","cli","cmc","stc","std","sti","sahf","lahf",
        "aaa","aad","aam","aas","daa","das","cbw","cwd",
        "rb","rw","rd","rq","rt","du","dt","dq",
        "at","as","if","else","end","while","repeat","times","break",
        "virtual","load","store","display","err","align","label","format","org",
        "use16","use32","section","entry","stack","heap","data","code",
        "extrn","public","purge","match","irp","rept","common","forward","reverse",
        "define","restore","struc","macro","fix","from","file","assert",
    };

    static int Main(string[] args)
    {
        if (args.Length == 0)
        {
            Console.Error.WriteLine("give me files or directories to translate");
            return 2;
        }

        List<string> files = new();
        foreach (string a in args)
        {
            if (Directory.Exists(a))
                files.AddRange(Directory.GetFiles(a, "*.ASM").Concat(
                               Directory.GetFiles(a, "*.INC")));
            else if (File.Exists(a)) files.Add(a);
            else Console.Error.WriteLine("no such path: " + a);
        }

        // Never translate our own output back again - but "ends with F" is not
        // the test. TKOFF.ASM ends with F and was silently skipped for it.
        // Ours is the one whose name without the trailing F also exists.
        files = files.Where(f => !IsOurOutput(f)).ToList();

        // Nor anything that was written for FASM in the first place. ENGINE
        // holds E_8086.INC, which is ours and is not a translation of
        // anything; run over it and every `macro` line comes back as a
        // reserved word. The naming rule above cannot see that, so ask the
        // file what it is.
        var native = files.Where(IsAlreadyFasm).ToList();
        foreach (string f in native)
            Console.WriteLine($"{Path.GetFileName(f),-16}    already FASM - left alone");
        files = files.Except(native).ToList();

        // Index the far procedures before translating anything: a file being
        // translated needs to know about procedures declared in files it has
        // never seen, because the call and the declaration are rarely in the
        // same one.
        // Only the segmented program, and only it. A folder holds more than
        // one top-level source - OWL FLY II keeps two resource blobs beside
        // the game - and they are separate programs that happen to share a
        // directory. Index them all into one table and a label called SBASE
        // in a blob quietly replaces the game's SBASE, which then loses its
        // segment and its cs: prefix. Found the hard way.
        foreach (string f in files.Where(IsSegmentedProgram)) IndexProgram(f);
        if (farProcs.Count > 0)
            Console.WriteLine($"{farProcs.Count} far procedures indexed across "
                              + $"{farProcs.Values.Distinct().Count()} segments");

        int done = 0, warned = 0;
        foreach (string f in files.OrderBy(x => x))
        {
            var report = Translate(f, out string outPath);
            done++;
            Console.WriteLine(outPath is null
                ? $"{Path.GetFileName(f),-16}    unchanged - nothing in it needed translating"
                : $"{Path.GetFileName(f),-16} -> {Path.GetFileName(outPath)}");
            foreach (string w in report)
            {
                Console.WriteLine("    " + w);
                warned++;
            }
        }
        Console.WriteLine();
        Console.WriteLine($"{done} files, {warned} things needing a human");
        return 0;
    }

    /// <summary>
    /// TASM's comparison words inside a conditional-assembly expression.
    /// Everything else - AND, OR, NOT, parentheses, $ - reads the same in
    /// both assemblers and is left alone.
    /// </summary>
    static string CondExpr(string tail) => Regex.Replace(
        tail, @"\b(EQ|NE|LT|LE|GT|GE)\b",
        m => m.Value.ToUpperInvariant() switch
        {
            "EQ" => "=", "NE" => "<>", "LT" => "<",
            "LE" => "<=", "GT" => ">", _ => ">=",
        }, RegexOptions.IgnoreCase);

    // The path to a file in ENGINE\, written relative to the source being
    // translated - because every path in this repository has to be relative
    // to the file that uses it, not to whatever the repository is mounted as.
    // The repository root is the folder that contains ENGINE.
    static string EngineInclude(string source, string name)
    {
        string dir = Path.GetDirectoryName(Path.GetFullPath(source));
        int up = 0;
        while (dir is not null && !Directory.Exists(Path.Combine(dir, "ENGINE")))
        { dir = Path.GetDirectoryName(dir); up++; }

        if (dir is null) return @"..\ENGINE\" + name;   // not in the repository
        return string.Concat(Enumerable.Repeat(@"..\", up)) + @"ENGINE\" + name;
    }

    /// <summary>
    /// Written for FASM already? Several constructs give it away and none can
    /// appear in a TASM source: a format declaration, a macro in FASM's
    /// syntax, an include with a quoted filename, a segment in lower case, and
    /// - the one that matters for an include file - a local label written the
    /// FASM way, `.name:` in column zero, where TASM writes `@@name:`.
    ///
    /// That last test was added because the others all missed SOLODBG.INC.
    /// It is an include, so it has no format line; it has no macros; and its
    /// only include is of nothing. Running the tool over a folder that had
    /// already been migrated therefore translated it a second time, into a
    /// SOLODBGF.INC nobody wanted, and the only sign was a stray file.
    /// </summary>
    static bool IsAlreadyFasm(string path)
    {
        foreach (string line in File.ReadLines(path))
        {
            string s = line.TrimStart();
            if (Regex.IsMatch(s, @"^format\s+binary\b", RegexOptions.IgnoreCase)) return true;
            if (Regex.IsMatch(s, @"^format\s+MZ\b", RegexOptions.IgnoreCase)) return true;
            if (Regex.IsMatch(s, @"^macro\s+\w", RegexOptions.IgnoreCase)) return true;
            if (Regex.IsMatch(s, @"^include\s+'", RegexOptions.IgnoreCase)) return true;
            if (Regex.IsMatch(line, @"^segment\s+\w")) return true;      // lower case: ours
            if (Regex.IsMatch(line, @"^\.[A-Za-z_][A-Za-z0-9_]*:")) return true;

            // The two forms that a file of PURE DATA can be recognised by,
            // and it needs them: a generated model table has no code in it at
            // all, so none of the tests above can fire. TASM writes
            //     F15NV equ 23        F15VT label word
            // and the translation writes
            //     F15NV = 23          label F15VT word
            if (Regex.IsMatch(line, @"^label\s+\w")) return true;
            if (Regex.IsMatch(line, @"^[A-Za-z_][A-Za-z0-9_]*\s+=\s")) return true;
        }
        return false;
    }

    /// <summary>
    /// Is this file something we produced? Only if dropping the trailing F
    /// names a source that exists beside it. TKOFF.ASM ends in F and is not
    /// ours; TKOFFF.ASM would be.
    /// </summary>
    static bool IsOurOutput(string path)
    {
        string b = Path.GetFileNameWithoutExtension(path);
        if (!b.EndsWith("F", StringComparison.Ordinal) || b.Length < 2) return false;
        string dir = Path.GetDirectoryName(path) ?? ".";
        string ext = Path.GetExtension(path);
        return File.Exists(Path.Combine(dir, b[..^1] + ext));
    }

    /// <summary>Name a translated file: CITY.ASM -> CITYF.ASM, and keep 8.3.</summary>
    static string FasmName(string path)
    {
        string dir = Path.GetDirectoryName(path) ?? ".";
        string b = Path.GetFileNameWithoutExtension(path);
        string e = Path.GetExtension(path);
        if (b.Length >= 8) b = b.Substring(0, 7);      // room for the F
        return Path.Combine(dir, b + "F" + e);
    }

    /// <summary>
    /// Renames the tool must not invent, read from renames.txt beside it.
    /// One line per file:
    ///     GAMES\WIRECITY\CITY.ASM   rcx=rc_x  rcz=rc_z  di@def=di_dead
    /// A plain old=new renames every whole word in that file. old@def=new
    /// renames ONLY the label definition in column 0 - which is what you want
    /// when the name also happens to be a register, because then every other
    /// occurrence is the register and must not be touched.
    /// </summary>
    static Dictionary<string, List<(string from, string to, bool defOnly)>> LoadRenames()
    {
        var map = new Dictionary<string, List<(string, string, bool)>>(StringComparer.OrdinalIgnoreCase);
        string file = Path.Combine(AppContext.BaseDirectory, "renames.txt");
        if (!File.Exists(file))
            file = Path.Combine("TOOLS", "Tasm2Fasm", "renames.txt");
        if (!File.Exists(file)) return map;

        foreach (string raw in File.ReadAllLines(file))
        {
            string line = raw.Trim();
            if (line.Length == 0 || line.StartsWith(";")) continue;
            string[] parts = line.Split((char[])null, StringSplitOptions.RemoveEmptyEntries);
            if (parts.Length < 2) continue;
            var list = new List<(string, string, bool)>();
            foreach (string p in parts.Skip(1))
            {
                int eq = p.IndexOf('=');
                if (eq <= 0) continue;
                string from = p[..eq], to = p[(eq + 1)..];
                bool defOnly = from.EndsWith("@def", StringComparison.OrdinalIgnoreCase);
                if (defOnly) from = from[..^4];
                list.Add((from, to, defOnly));
            }
            // Add to whatever that key already had, never replace it. A file
            // - and above all `*` - is allowed more than one line, because
            // the renames it collects come from different discoveries months
            // apart and each wants its own paragraph of reasoning above it.
            // Assigning here instead of appending silently threw away every
            // earlier line for the key, which is a bug you only notice as an
            // unrelated file mysteriously failing to assemble.
            string key = parts[0].Replace('/', '\\');
            if (map.TryGetValue(key, out var existing)) existing.AddRange(list);
            else map[key] = list;
        }
        return map;
    }

    static Dictionary<string, List<(string from, string to, bool defOnly)>> renames;

    /// <summary>
    /// Which segment each FAR procedure lives in, for the whole program.
    ///
    /// TASM knows this from PROC FAR and its own symbol table, and uses it
    /// twice: RET inside such a procedure assembles as RETF, and a CALL to it
    /// from anywhere assembles as a far call. FASM has no PROC at all, so both
    /// have to be written out - and neither can be decided from one file,
    /// because HUD.INC and PLANES.INC declare far procedures while sitting
    /// INSIDE the main segment (they are the far segments' way home), while
    /// UI.INC and SYM.INC declare theirs inside their own.
    ///
    /// So the index is built by walking the top-level source and following
    /// every INCLUDE, in order, keeping track of which SEGMENT is open.
    /// </summary>
    static readonly Dictionary<string, string> farProcs = new(StringComparer.OrdinalIgnoreCase);

    /// <summary>
    /// Files that RE-OPEN a segment another file already opened, mapped to
    /// the file that opened it first.
    ///
    /// TASM merges two blocks with the same segment name wherever they appear;
    /// FASM has no such notion and refuses the second `segment SKYSEG` as a
    /// symbol already defined. NET.INC is written as a continuation of
    /// SKY.INC and is included four files later, so the translation has to
    /// drop its segment line AND move its include up next to SKY's - or the
    /// bytes land in the wrong window.
    /// </summary>
    static readonly Dictionary<string, string> reopens = new(StringComparer.OrdinalIgnoreCase);

    /// <summary>
    /// Which segment every named address lives in, and which segment each
    /// file is being assembled into when it is included.
    ///
    /// This is what replaces ASSUME. TASM, told ASSUME CS:SKYSEG, DS:CODE,
    /// puts a 2E prefix on every reference to a symbol of SKYSEG's and leaves
    /// CODE's alone - silently, from its own symbol table. FASM has no such
    /// directive and will happily read a far segment's table through DS,
    /// which is a different program that assembles without complaint.
    ///
    /// The file map is needed because a file does not have to open a segment
    /// to be in one: PLANES.INC and HUD.INC are included inside CODE, and
    /// NET.INC continues SKYSEG.
    /// </summary>
    static readonly Dictionary<string, string> symSeg = new(StringComparer.OrdinalIgnoreCase);
    static readonly Dictionary<string, string> fileSeg = new(StringComparer.OrdinalIgnoreCase);
    static string dsSeg = "";

    /// <summary>
    /// A top-level source that declares segments and is not a COM. Only these
    /// need indexing, and mixing two of them corrupts both.
    /// </summary>
    static bool IsSegmentedProgram(string path)
    {
        if (!Path.GetExtension(path).Equals(".ASM", StringComparison.OrdinalIgnoreCase)) return false;
        bool seg = false;
        foreach (string l in File.ReadLines(path))
        {
            if (Regex.IsMatch(l, @"^\s*ORG\s+100h\s*$", RegexOptions.IgnoreCase)) return false;
            if (Regex.IsMatch(l, @"^\s*\w+\s+SEGMENT\b", RegexOptions.IgnoreCase)) seg = true;
        }
        return seg;
    }

    static void IndexProgram(string top)
    {
        string seg = "";
        var openedBy = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        Walk(top);

        void Walk(string file)
        {
            if (!File.Exists(file)) return;
            string dir = Path.GetDirectoryName(Path.GetFullPath(file)) ?? ".";
            string name = Path.GetFileName(file);
            foreach (string raw in File.ReadLines(file))
            {
                var s = Regex.Match(raw, @"^\s*(\w+)\s+SEGMENT\b", RegexOptions.IgnoreCase);
                if (s.Success)
                {
                    seg = s.Groups[1].Value;
                    if (dsSeg.Length == 0) dsSeg = seg;      // DS points at the first
                    if (openedBy.TryGetValue(seg, out string first))
                    {
                        if (!first.Equals(name, StringComparison.OrdinalIgnoreCase))
                            reopens[name] = first;
                    }
                    else openedBy[seg] = name;
                    continue;
                }
                if (Regex.IsMatch(raw, @"^\s*\w+\s+ENDS\b", RegexOptions.IgnoreCase)) continue;

                var p = Regex.Match(raw, @"^([A-Za-z_][A-Za-z0-9_]*)\s+PROC\s+FAR\b", RegexOptions.IgnoreCase);
                if (p.Success && seg.Length > 0) farProcs[p.Groups[1].Value] = seg;

                // Every named address, so a reference to one can be told from
                // a reference to a constant. EQU is deliberately not here: it
                // names a number, and a number needs no segment.
                if (seg.Length > 0)
                {
                    var d = Regex.Match(raw,
                        @"^([A-Za-z_][A-Za-z0-9_]*)\s*(:|(\s+(d[bwdqt]|label|PROC)\b))",
                        RegexOptions.IgnoreCase);
                    if (d.Success) symSeg[d.Groups[1].Value] = seg;
                }

                var inc = Regex.Match(raw, @"^\s*INCLUDE\s+(\S+)", RegexOptions.IgnoreCase);
                if (inc.Success)
                {
                    string child = Path.Combine(dir, inc.Groups[1].Value.Replace('/', '\\'));
                    fileSeg[Path.GetFileName(child)] = seg;
                    Walk(child);
                }
            }
        }
    }

    static List<string> Translate(string path, out string outPath)
    {
        outPath = FasmName(path);
        List<string> warnings = new();
        string[] lines = File.ReadAllLines(path);
        StringBuilder sb = new();

        renames ??= LoadRenames();
        // Renames for this file, plus the ones marked * for the whole
        // repository. A name shared between a program and an include it pulls
        // in has to be renamed in both or in neither - rcx is declared in five
        // different programs and used only inside ENGINE\E_M3D.INC, so a
        // per-file rule cannot express it without being wrong somewhere.
        renames.TryGetValue(path.Replace('/', '\\'), out var fileRenames);
        renames.TryGetValue("*", out var allRenames);
        if (allRenames != null)
            fileRenames = allRenames.Concat(fileRenames ?? new()).ToList();
        var applied = new HashSet<string>();

        bool isTopLevel = Path.GetExtension(path).Equals(".ASM", StringComparison.OrdinalIgnoreCase);
        bool wroteFormat = false;
        bool inFarProc = false;

        // Which segment this file's code is being assembled into. A file need
        // not open one to be inside it, so the answer comes from the index -
        // and is updated below wherever the file opens a segment of its own.
        string curSeg = fileSeg.GetValueOrDefault(Path.GetFileName(path), "");

        // COM or EXE, and the whole shape of the output turns on it. A COM
        // says ORG 100h and has one nameless stretch of code; an EXE names its
        // segments and ends with END <entry>. Only the top-level source can
        // tell - an .INC carrying a SEGMENT is part of an EXE by definition,
        // which is why the segment rule below applies to every file but the
        // header is written only here.
        bool isCom = lines.Any(l => Regex.IsMatch(l, @"^\s*ORG\s+100h\s*$", RegexOptions.IgnoreCase));
        bool isExe = isTopLevel && !isCom
                     && lines.Any(l => Regex.IsMatch(l, @"^\s*\w+\s+SEGMENT\b", RegexOptions.IgnoreCase));

        // The entry point, which TASM puts on the LAST line and FASM wants on
        // the first, and the segment it lives in - the first one declared.
        string entryLabel = lines
            .Select(l => Regex.Match(l, @"^\s*END\s+(\w+)\s*$", RegexOptions.IgnoreCase))
            .Where(m => m.Success).Select(m => m.Groups[1].Value).FirstOrDefault() ?? "START";
        string firstSeg = lines
            .Select(l => Regex.Match(l, @"^\s*(\w+)\s+SEGMENT\b", RegexOptions.IgnoreCase))
            .Where(m => m.Success).Select(m => m.Groups[1].Value).FirstOrDefault() ?? "CODE";

        // .8086 is the one directive that must NOT simply be dropped. It
        // restricts the instruction set, and FASM has nothing that does -
        // left alone, FASM encodes an out-of-range conditional jump in the
        // 386 long form and says nothing. E_8086.INC puts the restriction
        // back; see the file. Only the top-level source needs it.
        bool needs8086 = isTopLevel
            && lines.Any(l => Regex.IsMatch(l.TrimStart(), @"^\.8086\b"))
            && !lines.Any(l => Regex.IsMatch(l.TrimStart(), @"^\.(186|286|386|486|586)\b"));

        for (int i = 0; i < lines.Length; i++)
        {
            string line = lines[i];
            string trimmed = line.TrimStart();

            // ---- structure that FASM expresses in one line ------------------
            // In a COM there is nothing to say: one segment, no name, and the
            // format line at ORG 100h covers it. In an EXE each SEGMENT
            // becomes a FASM `segment`, in the same order, which is what puts
            // them at the paragraphs the game's own arithmetic depends on.
            var segd = Regex.Match(line, @"^\s*(\w+)\s+SEGMENT\b", RegexOptions.IgnoreCase);
            if (segd.Success)
            {
                curSeg = segd.Groups[1].Value;
                if (isCom || (!isExe && isTopLevel)) continue;

                // A continuation of somebody else's segment: say so and emit
                // nothing. The include that pulls this file in has been moved
                // up to sit right after the one that opened it, so these bytes
                // follow on directly - see the top-level source.
                if (reopens.TryGetValue(Path.GetFileName(path), out string opener))
                {
                    sb.AppendLine($"; continues segment {segd.Groups[1].Value}, opened in {opener}");
                    continue;
                }
                if (isExe && !wroteFormat)
                {
                    // TASM's linker made SS = the first segment and SP its
                    // 64K top, which wraps to zero. `stack CODE:0` is that,
                    // and it is what the built EXE actually carries.
                    sb.AppendLine("format MZ");
                    sb.AppendLine($"entry {firstSeg}:{entryLabel}");
                    sb.AppendLine($"stack {firstSeg}:0");
                    if (needs8086)
                    {
                        sb.AppendLine();
                        sb.AppendLine("; .8086 in the TASM source. FASM has no such directive - without this");
                        sb.AppendLine("; include it silently uses 386 jumps when a target is out of range.");
                        sb.AppendLine("; It goes before the first segment: the macros have to be defined");
                        sb.AppendLine("; before anything can use them.");
                        sb.AppendLine($"include '{EngineInclude(path, "E_8086.INC")}'");
                    }
                    sb.AppendLine();
                    wroteFormat = true;
                }
                sb.AppendLine($"segment {segd.Groups[1].Value}");
                continue;
            }
            if (Regex.IsMatch(line, @"^\s*\w+\s+ENDS\b", RegexOptions.IgnoreCase)) continue;
            if (Regex.IsMatch(trimmed, @"^ASSUME\b", RegexOptions.IgnoreCase)) continue;

            // PUBLIC exists to put a name in the LINKER MAP, and FASM has no
            // linker and no map - it writes the executable itself. Every one
            // of these marks the end of a segment's window so the developer
            // could read off how full it was; the number now comes from the
            // segment's own size instead.
            if (Regex.IsMatch(trimmed, @"^PUBLIC\b", RegexOptions.IgnoreCase)) continue;
            if (Regex.IsMatch(trimmed, @"^EXTRN\b|^EXTERN\b", RegexOptions.IgnoreCase))
            {
                warnings.Add($"line {i + 1}: {trimmed.Trim()} - an external symbol, which "
                             + "means this was meant to be linked with something. FASM "
                             + "assembles one program at a time; write it by hand.");
                continue;
            }
            // A trailing comment is allowed here, and it caught me out: the
            // rule wanted end-of-line and SIDEDAT.ASM writes
            //     END SBASE     ; TLINK /t wants the entry AT 100h, or it...
            // so the directive sailed through into the output.
            if (Regex.IsMatch(trimmed, @"^END\s+\w+\s*(;.*)?$", RegexOptions.IgnoreCase)) continue;
            if (Regex.IsMatch(trimmed, @"^\.\d+\b")) continue;                 // .8086, .286
            if (Regex.IsMatch(trimmed, @"^(LOCALS|JUMPS|SMART|NOSMART|MASM|IDEAL)\b",
                              RegexOptions.IgnoreCase)) continue;

            // ORG 100h is where a COM declares itself
            var org = Regex.Match(line, @"^(\s*)ORG\s+100h\s*$", RegexOptions.IgnoreCase);
            if (org.Success && isTopLevel && !wroteFormat)
            {
                sb.AppendLine("format binary as 'com'");
                sb.AppendLine(org.Groups[1].Value + "org 100h");
                if (needs8086)
                {
                    sb.AppendLine();
                    sb.AppendLine(org.Groups[1].Value + "; .8086 in the TASM source. FASM has no such directive - without this");
                    sb.AppendLine(org.Groups[1].Value + "; include it silently uses 386 jumps when a target is out of range.");
                    sb.AppendLine(org.Groups[1].Value + $"include '{EngineInclude(path, "E_8086.INC")}'");
                }
                wroteFormat = true;
                continue;
            }

            // Any OTHER ORG is a segment claiming its window, and it must be
            // translated to a RESERVATION rather than to FASM's own `org`.
            //
            // These programs end each far segment with ORG 1FF0h (3FF0h for
            // the sixteen-K one) so the segment really is that long and the
            // next one starts at the paragraph the game's arithmetic assumes.
            // FASM's `org` only moves the offset counter: it emits nothing,
            // so the segment stays as short as its last real byte and every
            // segment after it slides down. `rb X - $` fills the same span
            // and does extend the segment - measured, not guessed.
            var orgn = Regex.Match(line, @"^(\s*)ORG\s+([0-9A-Fa-f]+h?)\s*(;.*)?$",
                                   RegexOptions.IgnoreCase);
            if (orgn.Success)
            {
                line = orgn.Groups[1].Value + "rb " + orgn.Groups[2].Value + " - $";
                if (orgn.Groups[3].Success) line += "   " + orgn.Groups[3].Value;
                sb.AppendLine(line);
                continue;
            }

            // ---- conditional assembly ---------------------------------------
            // IF/ELSE/ENDIF are DIRECTIVES, not labels, and they sit in column
            // zero where a label goes - so without this the reserved-word
            // check reports every one of them as a name that needs deciding,
            // and NEWTON alone has seven. FASM spells the same thing with a
            // lower-case keyword, `end if` in two words, and the ordinary
            // comparison signs where TASM writes EQ, NE, LT, LE, GT, GE.
            // The word boundaries are load-bearing: without them IFOO: reads as
            // a conditional, and every EQ inside an identifier turns into an
            // equals sign. They also settle the order below, since IFE cannot
            // match IF followed by a boundary.
            bool isDirective = false;
            if (Regex.IsMatch(line, @"^\s*(IFE|IFDEF|IFNDEF|IFB|IFNB)\b", RegexOptions.IgnoreCase))
                warnings.Add($"line {i + 1}: {line.Trim()} - this form of conditional "
                             + "assembly has no rule yet; write it by hand");
            else if (Regex.IsMatch(line, @"^\s*(IF|ELSEIF)\b", RegexOptions.IgnoreCase))
            {
                isDirective = true;
                var c = Regex.Match(line, @"^(\s*)(IF|ELSEIF)\b(.*)$", RegexOptions.IgnoreCase);
                line = c.Groups[1].Value
                     + (c.Groups[2].Value.Equals("IF", StringComparison.OrdinalIgnoreCase)
                        ? "if" : "else if")
                     + CondExpr(c.Groups[3].Value);
            }
            else if (Regex.IsMatch(line, @"^\s*ENDIF\s*(;.*)?$", RegexOptions.IgnoreCase))
            {
                isDirective = true;
                line = Regex.Replace(line, @"^(\s*)ENDIF\b", "$1end if", RegexOptions.IgnoreCase);
            }
            else if (Regex.IsMatch(line, @"^\s*ELSE\s*(;.*)?$", RegexOptions.IgnoreCase))
            {
                isDirective = true;
                line = Regex.Replace(line, @"^(\s*)ELSE\b", "$1else", RegexOptions.IgnoreCase);
            }

            // ---- PROC FAR, which carries two meanings FASM cannot infer -----
            // A far procedure is just a label to FASM. What TASM took from the
            // declaration and FASM cannot is that RET inside it means RETF,
            // and that a CALL to it from anywhere is a far call. Both are
            // written out here; the segment comes from the index above.
            var proc = Regex.Match(line, @"^([A-Za-z_][A-Za-z0-9_]*)\s+PROC\s+(FAR|NEAR)?\s*(;.*)?$",
                                   RegexOptions.IgnoreCase);
            if (proc.Success)
            {
                inFarProc = proc.Groups[2].Value.Equals("FAR", StringComparison.OrdinalIgnoreCase);
                line = proc.Groups[1].Value + ":";
                if (proc.Groups[3].Success) line += "   " + proc.Groups[3].Value;
                sb.AppendLine(line);
                continue;
            }
            if (Regex.IsMatch(line, @"^[A-Za-z_][A-Za-z0-9_]*\s+ENDP\b", RegexOptions.IgnoreCase))
            { inFarProc = false; continue; }

            // Every RET in a far procedure - including one sharing its line
            // with a local label, which is how most of them are written.
            if (inFarProc)
                line = Regex.Replace(line, @"(^|:\s*|\s)ret\b(?!f)", "$1retf",
                                     RegexOptions.IgnoreCase);

            // A call to a far procedure. These sources say FAR PTR outright -
            // 428 times - so the destination is never in doubt; what is in
            // doubt is the SEGMENT, which TASM looked up and FASM must be
            // told. FASM writes the far form as SEGMENT:LABEL.
            //
            // Do NOT translate this as `call far ptr X`. FASM accepts that
            // line and assembles it to FF 1E - an INDIRECT far call through
            // memory - which is a different instruction that happens to look
            // like the right one.
            var callm = Regex.Match(
                line, @"^(.*?\b)(call|jmp)(\s+)FAR\s+PTR\s+([A-Za-z_][A-Za-z0-9_]*)\s*(;.*)?$",
                RegexOptions.IgnoreCase);
            if (callm.Success)
            {
                string target = callm.Groups[4].Value;
                if (!farProcs.TryGetValue(target, out string pseg))
                    warnings.Add($"line {i + 1}: {callm.Groups[2].Value} FAR PTR {target} - "
                                 + "no PROC FAR for that name was found, so its segment is "
                                 + "unknown; the call cannot be written without one");
                else
                {
                    line = callm.Groups[1].Value + callm.Groups[2].Value + callm.Groups[3].Value
                         + pseg + ":" + target;
                    if (callm.Groups[5].Success) line += "   " + callm.Groups[5].Value;
                }
            }

            // ---- EQU, which is not the same word in the two assemblers ------
            // TASM's EQU makes a NUMERIC constant the assembler resolves, so
            // it may be written after the code that uses it. FASM's `equ` is
            // a PREPROCESSOR text substitution and must come first, or the
            // symbol is simply undefined. FASM's numeric constant is `=`.
            //
            // OWLFLY is where this surfaced: FONTBUF is used on line 220 and
            // defined on line 477, which TASM never minded. Every equate in
            // this project is numeric - none uses TASM's <text> form - so the
            // translation is unconditional.
            // A TYPED equate is a third thing again. OWLFLY carves its whole
            // BSS out with them - HMAP equ byte ptr BSS - naming a place AND
            // the width to read it at, so [HMAP+si] needs no size on it. That
            // is not a number and `=` will not take it; FASM writes it
            //     label HMAP byte at BSS
            // which is the same statement with the words in another order.
            var tequ = Regex.Match(
                line, @"^([A-Za-z_][A-Za-z0-9_]*)\s+EQU\s+(byte|word|dword|fword|pword|qword)\s+ptr\s+(\S+)\s*(;.*)?$",
                RegexOptions.IgnoreCase);
            var equ = Regex.Match(line, @"^([A-Za-z_][A-Za-z0-9_]*)(\s+)EQU(\s+)(.*)$",
                                  RegexOptions.IgnoreCase);
            if (tequ.Success)
            {
                isDirective = true;
                line = $"label {tequ.Groups[1].Value} {tequ.Groups[2].Value.ToLowerInvariant()} "
                     + $"at {tequ.Groups[3].Value}";
                if (tequ.Groups[4].Success) line += "   " + tequ.Groups[4].Value;
            }
            else if (equ.Success)
                line = equ.Groups[1].Value + equ.Groups[2].Value + "="
                     + equ.Groups[3].Value + equ.Groups[4].Value;

            // ---- LABEL, which the two assemblers write back to front --------
            // TASM:  BSS  label byte      FASM:  label BSS byte
            // It names the current address with a type and allocates nothing,
            // which is how these programs put a name on the start of a table
            // and another on its end so a guard can measure the distance.
            var lbl = Regex.Match(line, @"^([A-Za-z_][A-Za-z0-9_]*)\s+LABEL\s+(\w+)\s*(;.*)?$",
                                  RegexOptions.IgnoreCase);
            if (lbl.Success)
            {
                isDirective = true;
                line = $"label {lbl.Groups[1].Value} {lbl.Groups[2].Value.ToLowerInvariant()}";
                if (lbl.Groups[3].Success) line += "   " + lbl.Groups[3].Value;
            }

            // ---- things that are only spelled differently -------------------
            // TASM says "word ptr", FASM just "word". Every size keyword, not
            // only the two the first port happened to use: BBS calls into the
            // IPX driver through `call dword ptr [ipxep]`, which FASM writes
            // `call dword [ipxep]` and assembles to the same FF 1E.
            line = Regex.Replace(line, @"\b(byte|word|dword|fword|pword|qword|tword)\s+ptr\b",
                                 "$1", RegexOptions.IgnoreCase);
            // FASM has no OFFSET operator, because it does not need one: a
            // label in an expression already IS its offset. TASM's word is
            // dropped wherever it appears, not only after a comma - a jump
            // table is written `dw offset a,b,c` and the first entry is the
            // one that carries it. Checked: nothing in this project is called
            // `offset`, so the whole word can go.
            line = Regex.Replace(line, @"\boffset\s+", "", RegexOptions.IgnoreCase);
            line = Regex.Replace(line, @"\b(cs|ds|es|ss):\[([^\]]*)\]", "[$1:$2]",
                                 RegexOptions.IgnoreCase);
            line = line.Replace("@@", ".");                       // local labels

            // ---- what ASSUME used to do -------------------------------------
            // Inside a far segment DS still points at the main one, so a
            // reference to something declared HERE has to say cs: or it reads
            // the wrong 64K. TASM inferred that from ASSUME and its symbol
            // table; FASM has neither, and gets it wrong without a word.
            //
            // Only bracketed references are touched. A bare symbol in an
            // instruction is a number - its offset - and needs no segment;
            // adding one there would be nonsense.
            if (curSeg.Length > 0)
                line = Regex.Replace(line, @"\[([^\]]*)\]", m =>
                {
                    string inner = m.Groups[1].Value;
                    bool hasCs = Regex.IsMatch(inner, @"^\s*cs\s*:", RegexOptions.IgnoreCase);
                    if (!hasCs && Regex.IsMatch(inner, @"^\s*(ds|es|ss)\s*:", RegexOptions.IgnoreCase))
                        return m.Value;                          // spoken for, and not by CS

                    foreach (Match id in Regex.Matches(inner, @"[A-Za-z_][A-Za-z0-9_]*"))
                    {
                        if (!symSeg.TryGetValue(id.Value, out string home)) continue;

                        // Its own segment: all it was missing is the prefix.
                        if (home.Equals(curSeg, StringComparison.OrdinalIgnoreCase))
                            return hasCs || curSeg.Equals(dsSeg, StringComparison.OrdinalIgnoreCase)
                                   ? m.Value : "[cs:" + inner + "]";

                        // SOMEBODY ELSE'S segment, reached through this one's
                        // CS. The windows sit end to end, so a segment can see
                        // past its own into the next - and TASM, told
                        // ASSUME CS:UISEG, worked the offset out from UISEG's
                        // base, not from the symbol's own. FASM gives the
                        // offset inside the segment the symbol belongs to, so
                        // the distance between the two bases has to be put
                        // back or the read lands 16K away.
                        //
                        // A difference of two segment names is a plain number
                        // to FASM - paragraphs - so times 16 is the byte gap.
                        if (!hasCs) return m.Value;              // DS-relative: not ours to fix
                        string adj = $"({home}-{curSeg})*16";
                        if (inner.Contains(adj)) return m.Value; // already carried
                        return "[" + Regex.Replace(inner, @"\b" + Regex.Escape(id.Value) + @"\b",
                                                   id.Value + "+" + adj, RegexOptions.None) + "]";
                    }
                    return m.Value;
                });

            // INCLUDE path -> include 'pathF'
            var inc = Regex.Match(line, @"^(\s*)INCLUDE\s+(\S+)\s*(;.*)?$", RegexOptions.IgnoreCase);
            if (inc.Success)
            {
                string incName = Path.GetFileName(inc.Groups[2].Value);

                // A file that continues somebody else's segment is pulled in
                // where that segment was opened, not where TASM had it. TASM
                // could merge two blocks of SKYSEG four files apart; FASM lays
                // segments down in source order, so NET.INC has to follow
                // SKY.INC directly or its bytes land in UISEG's window.
                if (reopens.ContainsKey(incName)) continue;

                string p = FasmName(inc.Groups[2].Value).Replace('/', '\\');
                line = $"{inc.Groups[1].Value}include '{p}'";
                if (inc.Groups[3].Success) line += "   " + inc.Groups[3].Value;
                sb.AppendLine(line);

                foreach (var (later, opener) in reopens)
                    if (opener.Equals(incName, StringComparison.OrdinalIgnoreCase))
                    {
                        sb.AppendLine($"{inc.Groups[1].Value}include '{FasmName(later)}'"
                                      + $"   ; moved up: continues the segment {incName} opened");
                    }
                continue;
            }

            // ---- renames a human decided on, applied reproducibly -----------
            if (fileRenames != null)
                foreach (var (from, to, defOnly) in fileRenames)
                {
                    if (defOnly)
                    {
                        var m = Regex.Match(line, @"^" + Regex.Escape(from) + @"\b");
                        if (!m.Success) continue;
                        line = to + line[from.Length..];
                    }
                    else
                    {
                        string before = line;
                        line = Regex.Replace(line, @"\b" + Regex.Escape(from) + @"\b", to);
                        if (line == before) continue;
                    }
                    applied.Add(from);
                }

            // ---- and the one thing a machine must not decide ----------------
            // Not on a line this pass has just turned INTO a directive: `if`,
            // `else` and `end if` all start in column zero, all three are in
            // the reserved list, and reporting them would be the tool warning
            // about its own output.
            var label = Regex.Match(line, @"^([A-Za-z_][A-Za-z0-9_]*)\b");
            if (!isDirective && label.Success && Reserved.Contains(label.Groups[1].Value))
                warnings.Add($"line {i + 1}: label '{label.Groups[1].Value}' is a reserved word "
                             + "in FASM - decide what it should be called and put it in "
                             + "renames.txt; check FIRST whether it was ever really used");

            sb.AppendLine(line);
        }

        if (isTopLevel && !wroteFormat)
            warnings.Add("no 'ORG 100h' found - this one is not a COM, "
                         + "so its format line has to be written by hand");

        // A translation that changed nothing was not a translation. A file of
        // pure data - a palette, a panel image, a generated model table - is
        // valid to both assemblers word for word, so it comes out identical
        // and there is nothing to write. Sniffing the contents for FASM-only
        // syntax cannot catch these, because they contain no syntax at all;
        // this does, and it does it for every such file there will ever be.
        var outLines = sb.ToString().Replace("\r\n", "\n").TrimEnd('\n').Split('\n');
        if (outLines.Length == lines.Length && !outLines.Where((l, k) => l != lines[k]).Any())
        {
            outPath = null;
            return warnings;
        }

        File.WriteAllText(outPath, sb.ToString());
        return warnings;
    }
}
