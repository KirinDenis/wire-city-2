// ============================================================================
//  OwvPlayer - the OWV format, decoded in C#, drawn into a WriteableBitmap.
//
//  A mirror of LAB\OWLFLY4\VIDEO\PLAYER.ASM, kept in step with it and with
//  FORMAT.md by hand. It exists for two reasons:
//
//  1. The desk previews CONVERTED material - the actual .OWV the game will
//     read - and shows exactly what the DOS player shows: the same palette,
//     the same dither, the same tolerance losses. What you approve here is
//     what ships. No emulator, and no Windows Media Player, which WPF's own
//     MediaElement quietly requires and which a machine may not have.
//
//  2. It is the reconstruction viewer the codec work wanted from the start:
//     the honest way to judge a TOLERANCE setting is to watch what it did
//     at twelve frames a second, not to read a number.
//
//  Sound is played too, loosely - the whole audio track is pulled out first
//  and handed to SoundPlayer when playback starts. A few frames of drift is
//  fine for a preview; the DOS player is the one that keeps real time.
// ============================================================================

using System.IO;
using System.Media;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace SceneDesk;

public sealed class OwvPlayer : IDisposable
{
    const byte CH_KEY = 1, CH_DELTA = 2, CH_AUDIO = 3, CH_PALETTE = 4, CH_END = 0xFF;
    const byte OP_FILL = 0x80, OP_LIT = 0x81, OP_COPY = 0x82, OP_RLE = 0x83, OP_END = 0xFF;
    const int BLOCK = 8;

    public int Width { get; private set; }
    public int Height { get; private set; }
    public int Fps { get; private set; }
    public int FrameCount { get; private set; }
    public int AudioRate { get; private set; }
    public int AudioBits { get; private set; } = 8;
    public int FrameNo { get; private set; }         // frames decoded so far
    public bool Ended { get; private set; }
    public bool HasAudio => wav != null;
    public double Seconds => (double)FrameCount / Math.Max(1, Fps);
    public WriteableBitmap Bitmap { get; private set; }

    readonly string path;
    FileStream fs;
    long firstChunk;
    readonly int[] pal = new int[256];               // BGRA, from 6-bit
    byte[] prev, cur, scratch = new byte[BLOCK * BLOCK];
    int[] pixels;
    SoundPlayer sound;
    byte[] wav;

    public OwvPlayer(string owvPath)
    {
        path = owvPath;
        // ReadWrite | Delete, not Read: the desk keeps this open while it
        // shows a scene, and the converter must still be able to replace the
        // file underneath it. With plain Read the converter died on "used by
        // another process", the old file stayed, and the desk called it
        // converted.
        fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete);
        var hdr = new byte[800];
        ReadExactly(hdr, 800);
        if (hdr[0] != 'O' || hdr[1] != 'W' || hdr[2] != 'V' || hdr[3] != '1') throw new InvalidDataException("not an OWV file");
        Width = hdr[4] | hdr[5] << 8; Height = hdr[6] | hdr[7] << 8;
        Fps = hdr[8]; FrameCount = hdr[10] | hdr[11] << 8;
        AudioRate = (hdr[9] & 1) != 0 ? (hdr[12] | hdr[13] << 8) : 0;
        AudioBits = (hdr[9] & 2) != 0 ? 16 : 8;      // signed 16-bit, or unsigned 8-bit
        for (int i = 0; i < 256; i++) SetPal(i, hdr[32 + i * 3], hdr[33 + i * 3], hdr[34 + i * 3]);
        firstChunk = 800;

        prev = new byte[Width * Height]; cur = new byte[Width * Height];
        pixels = new int[Width * Height];
        Bitmap = new WriteableBitmap(Width, Height, 96, 96, PixelFormats.Bgra32, null);
        if (AudioRate > 0) wav = PullAudio();
        Reset();
    }

    void SetPal(int i, int r, int g, int b) => pal[i] = unchecked((int)0xFF000000) | (r << 2) << 16 | (g << 2) << 8 | (b << 2);

    public void Reset()
    {
        fs.Seek(firstChunk, SeekOrigin.Begin);
        FrameNo = 0; Ended = false;
        Array.Clear(prev); Array.Clear(cur);
    }

    // Decode up to and including the next picture. False when the stream ends.
    //
    // `render` is false while catching up: when the clock says three frames
    // are due, the first two are decoded and thrown away and only the last
    // one is drawn. Decoding is cheap; drawing 256,000 pixels three times to
    // show one of them is what made the preview stutter.
    public bool NextFrame(bool render = true)
    {
        if (Ended) return false;
        var h = new byte[6];
        while (true)
        {
            if (fs.Read(h, 0, 6) != 6) { Ended = true; return false; }
            byte type = h[0];
            int len = h[2] | h[3] << 8 | h[4] << 16 | h[5] << 24;
            if (type == CH_END) { Ended = true; return false; }
            if (type == CH_AUDIO) { fs.Seek(len, SeekOrigin.Current); continue; }   // already pulled
            var payload = new byte[len];
            ReadExactly(payload, len);
            switch (type)
            {
                case CH_PALETTE: ApplyPalette(payload); continue;
                case CH_KEY: (prev, cur) = (cur, prev); Array.Clear(cur); int si = 0; Rle(payload, ref si, cur, 0, cur.Length); break;
                case CH_DELTA: (prev, cur) = (cur, prev); Delta(payload); break;
                default: continue;
            }
            FrameNo++;
            if (render) Render();
            return true;
        }
    }

    // Draw the last decoded picture, whenever it was decoded.
    public void Present() => Render();

    void ApplyPalette(byte[] p)
    {
        int first = p[0], count = p[1] + 1, si = 2;
        for (int i = 0; i < count && first + i < 256 && si + 2 < p.Length; i++, si += 3)
            SetPal(first + i, p[si], p[si + 1], p[si + 2]);
    }

    // The same RLE as the player: a lead under 80h is a literal run of n+1,
    // at or above it a repeat of (n - 7Fh). Never writes past `count`.
    static void Rle(byte[] src, ref int si, byte[] dst, int di, int count)
    {
        while (count > 0 && si < src.Length)
        {
            int b = src[si++];
            if (b < 0x80)
            {
                int n = Math.Min(b + 1, count);
                n = Math.Min(n, src.Length - si);
                Array.Copy(src, si, dst, di, n);
                si += n; di += n; count -= n;
            }
            else
            {
                int n = Math.Min(b - 0x7F, count);
                if (si >= src.Length) return;
                byte v = src[si++];
                for (int i = 0; i < n; i++) dst[di + i] = v;
                di += n; count -= n;
            }
        }
    }

    void Delta(byte[] p)
    {
        int si = 0;
        int gdx = (sbyte)p[si++], gdy = (sbyte)p[si++];
        Shift(gdx, gdy);

        int bw = Width / BLOCK, bh = Height / BLOCK, blk = 0, plane = Width * Height;
        while (si < p.Length)
        {
            int op = p[si++];
            if (op == OP_END) break;
            if (op < 0x80) { blk += op + 1; continue; }
            int bx = blk % bw, by = blk / bw;
            if (by >= bh) break;
            int at = by * BLOCK * Width + bx * BLOCK;
            switch (op)
            {
                case OP_FILL:
                {
                    if (si >= p.Length) return;
                    byte v = p[si++];
                    for (int r = 0; r < BLOCK; r++) for (int c = 0; c < BLOCK; c++) cur[at + r * Width + c] = v;
                    break;
                }
                case OP_LIT:
                {
                    if (si + 64 > p.Length) return;
                    for (int r = 0; r < BLOCK; r++, si += BLOCK) Array.Copy(p, si, cur, at + r * Width, BLOCK);
                    break;
                }
                case OP_COPY:
                {
                    if (si + 2 > p.Length) return;
                    int dx = (sbyte)p[si++], dy = (sbyte)p[si++];
                    int from = at + dy * Width + dx;
                    for (int r = 0; r < BLOCK; r++)
                    {
                        int s = from + r * Width, d = at + r * Width;
                        if (s < 0 || s + BLOCK > plane) continue;
                        Array.Copy(prev, s, cur, d, BLOCK);
                    }
                    break;
                }
                case OP_RLE:
                {
                    si += 2;                                  // the coded length; not needed
                    Rle(p, ref si, scratch, 0, BLOCK * BLOCK);
                    for (int r = 0; r < BLOCK; r++) Array.Copy(scratch, r * BLOCK, cur, at + r * Width, BLOCK);
                    break;
                }
                default: return;                              // nonsense: stop, do not scribble
            }
            blk++;
        }
    }

    // The previous picture moved by (gdx, gdy) is where this one starts.
    void Shift(int gdx, int gdy)
    {
        if (gdx == 0 && gdy == 0) { Array.Copy(prev, cur, prev.Length); return; }
        Array.Clear(cur);
        for (int y = 0; y < Height; y++)
        {
            int sy = y - gdy;
            if (sy < 0 || sy >= Height) continue;
            int x0 = Math.Max(0, gdx), x1 = Math.Min(Width, Width + gdx);
            if (x1 <= x0) continue;
            Array.Copy(prev, sy * Width + (x0 - gdx), cur, y * Width + x0, x1 - x0);
        }
    }

    void Render()
    {
        for (int i = 0; i < pixels.Length; i++) pixels[i] = pal[cur[i]];
        Bitmap.WritePixels(new Int32Rect(0, 0, Width, Height), pixels, Width * 4, 0);
    }

    // ---- sound: the whole track, pulled out ahead of time as a WAV --------
    byte[] PullAudio()
    {
        var keep = fs.Position;
        fs.Seek(firstChunk, SeekOrigin.Begin);
        var pcm = new MemoryStream();
        var h = new byte[6];
        while (fs.Read(h, 0, 6) == 6)
        {
            byte type = h[0];
            int len = h[2] | h[3] << 8 | h[4] << 16 | h[5] << 24;
            if (type == CH_END) break;
            if (type == CH_AUDIO) { var b = new byte[len]; ReadExactly(b, len); pcm.Write(b, 0, len); }
            else fs.Seek(len, SeekOrigin.Current);
        }
        fs.Seek(keep, SeekOrigin.Begin);
        var data = pcm.ToArray();
        var w = new MemoryStream();
        void U32(uint v) { w.WriteByte((byte)v); w.WriteByte((byte)(v >> 8)); w.WriteByte((byte)(v >> 16)); w.WriteByte((byte)(v >> 24)); }
        void U16(ushort v) { w.WriteByte((byte)v); w.WriteByte((byte)(v >> 8)); }
        w.Write("RIFF"u8); U32((uint)(36 + data.Length)); w.Write("WAVE"u8);
        int bps = AudioBits / 8;
        w.Write("fmt "u8); U32(16); U16(1); U16(1); U32((uint)AudioRate); U32((uint)(AudioRate * bps)); U16((ushort)bps); U16((ushort)AudioBits);
        w.Write("data"u8); U32((uint)data.Length); w.Write(data, 0, data.Length);
        return w.ToArray();
    }

    public void StartSound()
    {
        if (wav == null) return;
        StopSound();
        sound = new SoundPlayer(new MemoryStream(wav));
        sound.Play();
    }
    public void StopSound() { sound?.Stop(); sound?.Dispose(); sound = null; }

    void ReadExactly(byte[] buf, int count)
    {
        int done = 0;
        while (done < count)
        {
            int n = fs.Read(buf, done, count - done);
            if (n <= 0) throw new EndOfStreamException();
            done += n;
        }
    }

    public void Dispose() { StopSound(); fs?.Dispose(); fs = null; }
}
