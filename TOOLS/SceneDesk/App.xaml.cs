using System.IO;
using System.Windows;
using System.Windows.Media.Imaging;

namespace SceneDesk;

public partial class App : Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        // A back door for checking the decoder without a window:
        //     SceneDesk --dump FILE.OWV N OUT.PNG
        if (e.Args.Length == 4 && e.Args[0] == "--dump")
        {
            try
            {
                using var p = new OwvPlayer(e.Args[1]);
                int n = int.Parse(e.Args[2]);
                for (int i = 0; i < n && p.NextFrame(); i++) { }
                var enc = new PngBitmapEncoder();
                enc.Frames.Add(BitmapFrame.Create(p.Bitmap));
                using var fs = File.Create(e.Args[3]);
                enc.Save(fs);
                Console.WriteLine($"dumped frame {p.FrameNo} of {p.FrameCount} -> {e.Args[3]}");
            }
            catch (Exception ex) { Console.Error.WriteLine("dump failed: " + ex.Message); }
            Shutdown();
            return;
        }

        // And one for checking a PICKUP's products the way the game will draw
        // them: the room, and one thing on it at the position in its header.
        //     SceneDesk --spr BG.OWV THING.SPR OUT.PNG
        if (e.Args.Length == 4 && e.Args[0] == "--spr")
        {
            try
            {
                var hdr = new byte[800];
                using (var f = File.OpenRead(e.Args[1])) f.ReadExactly(hdr, 0, 800);
                var pal = new int[256];
                for (int i = 0; i < 256; i++)
                    pal[i] = unchecked((int)0xFF000000) | (hdr[32 + i * 3] << 2) << 16 | (hdr[33 + i * 3] << 2) << 8 | (hdr[34 + i * 3] << 2);
                using var p = new OwvPlayer(e.Args[1]);
                p.NextFrame();
                int bw = p.Bitmap.PixelWidth, bh = p.Bitmap.PixelHeight;
                var px = new int[bw * bh];
                p.Bitmap.CopyPixels(px, bw * 4, 0);
                var spr = File.ReadAllBytes(e.Args[2]);
                int sw = spr[4] | spr[5] << 8, sh = spr[6] | spr[7] << 8;
                int sx = (short)(spr[8] | spr[9] << 8), sy = (short)(spr[10] | spr[11] << 8);
                byte tr = spr[12];
                int drawn = 0;
                for (int y = 0; y < sh; y++)
                    for (int x = 0; x < sw; x++)
                    {
                        byte ix = spr[16 + y * sw + x];
                        if (ix == tr) continue;
                        int X = sx + x, Y = sy + y;
                        if (X < 0 || Y < 0 || X >= bw || Y >= bh) continue;
                        px[Y * bw + X] = pal[ix]; drawn++;
                    }
                var bmp = new System.Windows.Media.Imaging.WriteableBitmap(bw, bh, 96, 96, System.Windows.Media.PixelFormats.Bgra32, null);
                bmp.WritePixels(new Int32Rect(0, 0, bw, bh), px, bw * 4, 0);
                var enc = new PngBitmapEncoder();
                enc.Frames.Add(BitmapFrame.Create(bmp));
                using var fs = File.Create(e.Args[3]);
                enc.Save(fs);
                Console.WriteLine($"{Path.GetFileName(e.Args[2])}: {sw}x{sh} at {sx},{sy}, transparent {tr}, {drawn} pixels drawn -> {e.Args[3]}");
            }
            catch (Exception ex) { Console.Error.WriteLine("spr failed: " + ex.Message); }
            Shutdown();
            return;
        }

        // And one for checking the DESK without a person at it:
        //     SceneDesk SCENARIO.JSON --script STEPS.TXT --shots DIR
        // The steps drive the same handlers a mouse would - select a scene,
        // select a file, wait for the timers, render the window to a PNG -
        // and the pictures can then be looked at. The window is put off the
        // screen and does not take the focus, so nothing on the desk the
        // person is actually using is touched. This exists because a UI
        // that has only ever been seen through someone else's screenshots
        // has not been seen.
        string script = null, shots = null;
        var rest = new List<string>();
        for (int i = 0; i < e.Args.Length; i++)
        {
            if (e.Args[i] == "--script" && i + 1 < e.Args.Length) script = e.Args[++i];
            else if (e.Args[i] == "--shots" && i + 1 < e.Args.Length) shots = e.Args[++i];
            else rest.Add(e.Args[i]);
        }

        var w = new MainWindow(rest.ToArray());
        if (script != null)
        {
            w.WindowStartupLocation = WindowStartupLocation.Manual;
            w.Left = -20000; w.Top = -20000;                 // off every screen
            w.ShowActivated = false; w.ShowInTaskbar = false;
            w.Width = 1560; w.Height = 920;
            w.Loaded += (_, _) => w.RunScript(File.ReadAllLines(script), shots ?? Path.GetDirectoryName(Path.GetFullPath(script)));
        }
        w.Show();
    }
}
