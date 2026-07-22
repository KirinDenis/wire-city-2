// ============================================================================
//  FlyDbg - the debug harness for WIRE CITY games (first: GAMES\TRAINER).
//
//  Connects to DOSBox COM1 (nullmodem -> TCP, see serial.conf), reads the
//  telemetry stream ("T tick vel alt pit rol hdg thr wrn dead"), injects
//  key events back (bit7 = press, low 7 bits = scancode - straight into
//  the game's KEYS table, no window focus needed), logs everything into
//  one tick-stamped CSV, and captures DOSBox window screenshots so the
//  whole flight can be replayed as "what was pressed, what happened".
//
//  Build: BUILD.BAT (framework csc, no dependencies)
//  Run:   FlyDbg.exe scenarios\takeoff.txt   (or no args = REPL on stdin)
//
//  Scenario language, one command per line (';' comments):
//      wait N              let N ticks pass
//      press KEY           hold a key down     (UP DOWN LEFT RIGHT PLUS
//      release KEY         let a key go         MINUS F G B V R Z C ESC)
//      tap KEY N           press, N ticks, release
//      until VAR OP VALUE TIMEOUT   wait until e.g.: until vel >= 330 400
//                          VAR: tick vel alt pit rol hdg thr wrn dead
//      shot NAME           screenshot -> shots\NAME_t<tick>.png
//      say TEXT            note into the CSV
//      end                 finish the scenario (keys all released)
// ============================================================================
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Globalization;
using System.IO;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

static class FlyDbg
{
    static TcpClient tcp;
    static NetworkStream net;
    static readonly object gate = new object();
    static Dictionary<string, int> T = new Dictionary<string, int>();  // telemetry
    static StreamWriter csv;
    static string root;                      // repo root (parent of Debug)

    static readonly Dictionary<string, byte> KEY = new Dictionary<string, byte>(StringComparer.OrdinalIgnoreCase)
    {
        {"ESC",0x01},{"MINUS",0x0C},{"PLUS",0x0D},{"R",0x13},{"O",0x18},{"F",0x21},
        {"G",0x22},{"L",0x26},{"Z",0x2C},{"C",0x2E},{"V",0x2F},{"B",0x30},
        {"SPACE",0x39},{"UP",0x48},{"LEFT",0x4B},{"RIGHT",0x4D},{"DOWN",0x50}
    };
    static readonly string[] VARS = { "tick", "vel", "alt", "pit", "rol", "hdg", "thr", "wrn", "dead", "apx", "apz", "chf", "gpi", "rxn", "lst", "pkn" };
    static readonly string[] POKE = { "apx", "apy", "apz", "hdg", "pit", "rol", "vel", "thr", "chdgf", "wind", "slow" };
    static volatile bool alive = true;
    static List<byte> held = new List<byte>();

    static int Main(string[] args)
    {
        root = Path.GetFullPath(Path.Combine(AppDomain.CurrentDomain.BaseDirectory, ".."));
        string host = "127.0.0.1";
        int port = 5310;
        string script = null;
        bool record = false;
        foreach (string a in args)
        {
            if (a.StartsWith("--port=")) port = int.Parse(a.Substring(7));
            else if (a.StartsWith("--host=")) host = a.Substring(7);
            else if (a == "--record") record = true;
            else script = a;
        }
        foreach (string v in VARS) T[v] = 0;

        string logDir = Path.Combine(root, "Debug", "log");
        Directory.CreateDirectory(logDir);
        Directory.CreateDirectory(Path.Combine(root, "Debug", "shots"));
        string csvPath = Path.Combine(logDir,
            "flight-" + DateTime.Now.ToString("yyyyMMdd-HHmmss") + ".csv");
        csv = new StreamWriter(csvPath, false, Encoding.ASCII);
        csv.WriteLine("ms,tick,vel,alt,pit,rol,hdg,thr,wrn,dead,apx,apz,chf,gpi,rxn,lst,pkn,event");
        Console.WriteLine("log: " + csvPath);

        for (int i = 0; ; i++)                       // DOSBox may still be booting
        {
            try { tcp = new TcpClient(host, port); break; }
            catch (Exception)
            {
                if (i == 40) { Console.WriteLine("no DOSBox on " + host + ":" + port + " - run RUN.BAT first"); return 1; }
                Thread.Sleep(500);
            }
        }
        tcp.NoDelay = true;
        net = tcp.GetStream();
        Console.WriteLine("connected " + host + ":" + port);
        Thread rd = new Thread(Reader);
        rd.IsBackground = true;
        rd.Start();

        int rc = 0;
        try
        {
            if (record)
            {
                Console.WriteLine("RECORDING: fly in the DOSBox window; ESC in game ends it.");
                Console.WriteLine(@"Frames -> Debug\shots\recNNNN_t<tick>.png every 500 ms.");
                int n = 0;
                while (alive)
                {
                    Thread.Sleep(500);
                    if (!alive) break;
                    Shot("rec" + n.ToString("D4"));
                    n++;
                }
            }
            else if (script != null)
            {
                foreach (string raw in File.ReadAllLines(script))
                    if (!Run(raw)) break;
            }
            else
            {
                Console.WriteLine("REPL: wait/press/release/tap/until/shot/say/end");
                string line;
                while ((line = Console.ReadLine()) != null)
                    if (!Run(line)) break;
            }
        }
        catch (Exception ex) { Console.WriteLine("ERROR: " + ex.Message); rc = 2; }

        try { foreach (byte k in held.ToArray()) Send(k, false); } catch (Exception) { }
        Thread.Sleep(200);
        csv.Flush(); csv.Close();
        return rc;
    }

    // ---- one scenario line ------------------------------------------------
    static bool Run(string raw)
    {
        string line = raw;
        int sc = line.IndexOf(';');
        if (sc >= 0) line = line.Substring(0, sc);
        line = line.Trim();
        if (line.Length == 0) return true;
        string[] w = line.Split(new[] { ' ', '\t' }, StringSplitOptions.RemoveEmptyEntries);
        string cmd = w[0].ToLowerInvariant();
        Console.WriteLine(">> " + line);
        switch (cmd)
        {
            case "wait": WaitTicks(int.Parse(w[1])); break;
            case "press": Send(Key(w[1]), true); break;
            case "release": Send(Key(w[1]), false); break;
            case "tap":
                Send(Key(w[1]), true);
                WaitTicks(int.Parse(w[2]));
                Send(Key(w[1]), false);
                break;
            case "until":
                if (!Until(w[1], w[2], int.Parse(w[3]), int.Parse(w[4])))
                    Log("TIMEOUT " + line);
                break;
            case "shot": Shot(w[1]); break;
            case "poke":
                {
                    string pname = w[1].ToLowerInvariant();
                    int pi = Array.IndexOf(POKE, pname);
                    if (pi < 0) throw new Exception("unknown poke var " + w[1]);
                    short pv = short.Parse(w[2]);
                    int uv = pv & 0xFFFF;
                    byte[] pk = { 0x7F,
                        (byte)(0x40 | ((pi >> 4) & 15)), (byte)(0x40 | (pi & 15)),
                        (byte)(0x40 | ((uv >> 12) & 15)), (byte)(0x40 | ((uv >> 8) & 15)),
                        (byte)(0x40 | ((uv >> 4) & 15)), (byte)(0x40 | (uv & 15)) };
                    // the wire drops bytes on its own schedule: send, then
                    // VERIFY against telemetry and resend until it sticks
                    string vk = null;
                    if (pname == "apy") vk = "alt";
                    else if (pname == "chdgf") vk = "chf";
                    else if (Array.IndexOf(VARS, pname) >= 0) vk = pname;
                    bool ok = false;
                    for (int att = 0; att < 6 && !ok; att++)
                    {
                        foreach (byte pb in pk)
                        {
                            net.WriteByte(pb);
                            net.Flush();
                            Thread.Sleep(240);
                        }
                        if (vk == null) { ok = att > 0; continue; }
                        Thread.Sleep(400);
                        int got; lock (gate) got = T[vk];
                        ok = Math.Abs(got - pv) <= 40;
                    }
                    Log("POKE " + w[1] + "=" + pv + (ok ? "" : " UNVERIFIED"));
                }
                break;
            case "say": Log("SAY " + line.Substring(4)); break;
            case "end": return false;
            default: Console.WriteLine("?? " + line); break;
        }
        return true;
    }

    static byte Key(string name)
    {
        byte s;
        if (!KEY.TryGetValue(name, out s)) throw new Exception("unknown key " + name);
        return s;
    }

    static void Send(byte scan, bool down)
    {
        byte b = down ? (byte)(scan | 0x80) : scan;
        net.WriteByte(0);
        net.Flush();
        Thread.Sleep(300);
        net.WriteByte(b);
        net.Flush();
        Thread.Sleep(300);
        lock (gate)
        {
            if (down) { if (!held.Contains(scan)) held.Add(scan); }
            else held.Remove(scan);
        }
        Log((down ? "PRESS " : "RELEASE ") + Name(scan));
    }

    static string Name(byte scan)
    {
        foreach (KeyValuePair<string, byte> kv in KEY) if (kv.Value == scan) return kv.Key;
        return "0x" + scan.ToString("X2");
    }

    static int Tick() { lock (gate) return T["tick"]; }

    static void WaitTicks(int n)
    {
        int t0 = Tick();
        while (alive && Tick() - t0 < n) Thread.Sleep(10);
    }

    static bool Until(string v, string op, int val, int timeoutTicks)
    {
        v = v.ToLowerInvariant();
        int t0 = Tick();
        while (alive && Tick() - t0 < timeoutTicks)
        {
            int x; lock (gate) x = T[v];
            bool ok;
            switch (op)
            {
                case ">=": ok = x >= val; break;
                case "<=": ok = x <= val; break;
                case ">": ok = x > val; break;
                case "<": ok = x < val; break;
                case "==": case "=": ok = x == val; break;
                case "!=": ok = x != val; break;
                default: throw new Exception("bad op " + op);
            }
            if (ok) return true;
            Thread.Sleep(10);
        }
        return false;
    }

    // ---- telemetry reader --------------------------------------------------
    static void Reader()
    {
        StringBuilder sb = new StringBuilder();
        int b;
        try
        {
            while ((b = net.ReadByte()) >= 0)
            {
                char ch = (char)b;
                if (ch == '\n')
                {
                    Parse(sb.ToString().Trim());
                    sb.Length = 0;
                }
                else if (ch != '\r') sb.Append(ch);
            }
        }
        catch (Exception) { }
        alive = false;
        Console.WriteLine("stream closed");
    }

    static Stopwatch0 clock = new Stopwatch0();

    static void Parse(string line)
    {
        if (!line.StartsWith("T ")) return;
        string[] w = line.Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
        if (w.Length != VARS.Length + 1) return;
        lock (gate)
        {
            for (int i = 0; i < VARS.Length; i++)
            {
                int x;
                if (int.TryParse(w[i + 1], NumberStyles.Integer, CultureInfo.InvariantCulture, out x))
                    T[VARS[i]] = x;
            }
            csv.WriteLine(clock.Ms() + "," + T["tick"] + "," + T["vel"] + "," + T["alt"] + ","
                + T["pit"] + "," + T["rol"] + "," + T["hdg"] + "," + T["thr"] + ","
                + T["wrn"] + "," + T["dead"] + "," + T["apx"] + "," + T["apz"] + ","
                + T["chf"] + "," + T["gpi"] + "," + T["rxn"] + "," + T["lst"] + "," + T["pkn"] + ",");
        }
    }

    static void Log(string ev)
    {
        lock (gate)
        {
            csv.WriteLine(clock.Ms() + "," + T["tick"] + "," + T["vel"] + "," + T["alt"] + ","
                + T["pit"] + "," + T["rol"] + "," + T["hdg"] + "," + T["thr"] + ","
                + T["wrn"] + "," + T["dead"] + "," + T["apx"] + "," + T["apz"] + ","
                + T["chf"] + "," + T["gpi"] + "," + T["rxn"] + "," + T["lst"] + "," + T["pkn"] + ",\"" + ev + "\"");
            csv.Flush();
        }
        Console.WriteLine("   [" + T["tick"] + "] " + ev);
    }

    // ---- DOSBox window capture ----------------------------------------------
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb, IntPtr lp);
    [DllImport("user32.dll")] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] static extern bool GetClientRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] static extern bool ClientToScreen(IntPtr h, ref POINT p);
    [DllImport("user32.dll")] static extern bool PrintWindow(IntPtr h, IntPtr dc, uint flags);
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
    delegate bool EnumProc(IntPtr h, IntPtr lp);
    [StructLayout(LayoutKind.Sequential)] struct RECT { public int L, T, R, B; }
    [StructLayout(LayoutKind.Sequential)] struct POINT { public int X, Y; }

    static IntPtr FindDosbox()
    {
        IntPtr found = IntPtr.Zero;
        EnumWindows(delegate(IntPtr h, IntPtr lp)
        {
            if (!IsWindowVisible(h)) return true;
            StringBuilder s = new StringBuilder(256);
            GetWindowText(h, s, 256);
            if (s.ToString().IndexOf("DOSBox", StringComparison.OrdinalIgnoreCase) >= 0
                && s.ToString().IndexOf("Status", StringComparison.OrdinalIgnoreCase) < 0)
            { found = h; return false; }
            return true;
        }, IntPtr.Zero);
        return found;
    }

    static void Shot(string name)
    {
        IntPtr h = FindDosbox();
        if (h == IntPtr.Zero) { Log("SHOT " + name + " FAILED: no DOSBox window"); return; }
        RECT rc; GetClientRect(h, out rc);
        POINT tl = new POINT(); ClientToScreen(h, ref tl);
        int wdt = rc.R - rc.L, hgt = rc.B - rc.T;
        if (wdt < 16 || hgt < 16) { Log("SHOT " + name + " FAILED: window too small"); return; }
        string file = Path.Combine(root, "Debug", "shots",
            name + "_t" + Tick() + ".png");
        RECT wr; GetWindowRect(h, out wr);
        int fw = wr.R - wr.L, fh = wr.B - wr.T;
        using (Bitmap full = new Bitmap(fw, fh))
        {
            bool ok;
            using (Graphics g = Graphics.FromImage(full))
            {
                IntPtr dc = g.GetHdc();
                ok = PrintWindow(h, dc, 2);      // 2 = PW_RENDERFULLCONTENT
                g.ReleaseHdc(dc);
            }
            if (!ok || IsBlank(full))            // fallback: the visible screen
                using (Graphics g = Graphics.FromImage(full))
                    g.CopyFromScreen(wr.L, wr.T, 0, 0, new Size(fw, fh));
            int cx = tl.X - wr.L, cy = tl.Y - wr.T;   // cut the client area
            using (Bitmap bmp = full.Clone(new Rectangle(cx, cy, wdt, hgt), full.PixelFormat))
                bmp.Save(file, ImageFormat.Png);
        }
        Log("SHOT " + file);
    }

    static bool IsBlank(Bitmap b)
    {
        int dark = 0, n = 0;
        for (int y = b.Height / 4; y < b.Height; y += b.Height / 8)
            for (int x = 0; x < b.Width; x += b.Width / 16)
            {
                Color c = b.GetPixel(x, y); n++;
                if (c.R + c.G + c.B < 24) dark++;
            }
        return dark == n;
    }

    // small monotonic ms clock (avoid pulling in extra usings)
    class Stopwatch0
    {
        readonly DateTime t0 = DateTime.UtcNow;
        public long Ms() { return (long)(DateTime.UtcNow - t0).TotalMilliseconds; }
    }
}
