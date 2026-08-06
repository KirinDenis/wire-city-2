// ============================================================================
//  Snd2Dat - the game's sound bank, cut from ordinary WAV files.
//
//  Out: INSTALL\SFX.DAT   - a header, an index, and SIGNED 8-bit mono at
//                           11025 Hz, which is the rate the engine ring
//                           already spins at.
//       SRC\SFXIDX.INC    - the equates, so the assembly names its sounds
//                           instead of counting them.
//
//  SIGNED, not unsigned, and that is not a detail: the ring holds unsigned
//  bytes centred on 80h and SFXMB ADDS a signed value into it. Storing the
//  deltas means the player is load / sign-extend / add, with no per-sample
//  arithmetic to undo a format nobody wanted.
//
//  THE TAIL IS THE WHOLE REASON THIS TOOL EXISTS. A sound library file is
//  mastered with room around it - a beat of silence at the front and a long
//  fade to nothing at the back. On a machine where every sound has to fit
//  ahead of a DMA beam in a 32768-sample ring, that padding is the
//  difference between an effect that fits and one that laps itself. So both
//  ends are cut at the first and last sample that carries real signal, and
//  the cut end is faded over a few milliseconds - an abrupt cut is a click,
//  and a click is louder than the sound it ends.
//
//  Usage:
//    Snd2Dat -o <outdir> -src <incdir> NAME=file.wav,maxSeconds,gain ...
// ============================================================================

const int RATE = 11025;          // the ring's own rate: no resample at play time
const int RING = 32768;          // ...and its length. Nothing may reach this.
const double TRIMDB = -42.0;     // below this, relative to the peak, is silence
const int FADEMS = 6;            // the cut end is faded over this, or it clicks

string outDir = ".", srcDir = ".";
var specs = new List<(string name, string file, double maxSec, double gain)>();
for (int i = 0; i < args.Length; i++)
{
    if (args[i] == "-o") { outDir = args[++i]; continue; }
    if (args[i] == "-src") { srcDir = args[++i]; continue; }
    var eq = args[i].IndexOf('=');
    if (eq < 0) { Console.Error.WriteLine($"bad spec: {args[i]}"); return 1; }
    var name = args[i][..eq];
    var parts = args[i][(eq + 1)..].Split(',');
    specs.Add((name, parts[0],
               parts.Length > 1 ? double.Parse(parts[1]) : 2.0,
               parts.Length > 2 ? double.Parse(parts[2]) : 1.0));
}
if (specs.Count == 0) { Console.Error.WriteLine("nothing to do"); return 1; }

var blobs = new List<byte[]>();
Console.WriteLine("  name        source                      in     trimmed    out    peak");
foreach (var (name, file, maxSec, gain) in specs)
{
    var (mono, sr) = ReadWav(file);
    double inSec = mono.Length / (double)sr;

    // ---- resample to the ring's rate, linear. The sources are 44100 and we
    // are going to 11025 - a plain 4:1 decimation would alias the top end
    // into a whistle, so the input is boxcar-averaged over each output step
    // first. It is the cheapest anti-alias there is and it is enough.
    int n = (int)(mono.Length * (double)RATE / sr);
    var res = new double[n];
    double step = (double)sr / RATE;
    for (int i = 0; i < n; i++)
    {
        int a = (int)(i * step), b = (int)((i + 1) * step);
        if (b <= a) b = a + 1;
        if (b > mono.Length) b = mono.Length;
        double s = 0; int c = 0;
        for (int j = a; j < b; j++) { s += mono[j]; c++; }
        res[i] = c > 0 ? s / c : 0;
    }

    // ---- TRIM. The threshold is relative to this sound's own peak, so a
    // quiet source is not trimmed away entirely and a loud one is not left
    // with its padding.
    double peak = 0;
    foreach (var v in res) peak = Math.Max(peak, Math.Abs(v));
    if (peak <= 0) { Console.Error.WriteLine($"{name}: silent source"); return 1; }
    double thr = peak * Math.Pow(10.0, TRIMDB / 20.0);
    int lo = 0, hi = res.Length - 1;
    while (lo < res.Length && Math.Abs(res[lo]) < thr) lo++;
    while (hi > lo && Math.Abs(res[hi]) < thr) hi--;
    int len = hi - lo + 1;

    // ---- and the cap, which is a hard fact about the ring and not a taste.
    int cap = (int)(maxSec * RATE);
    bool capped = len > cap;
    if (capped) len = cap;
    if (len >= RING - 1024)
    {
        Console.Error.WriteLine($"{name}: {len} samples will not fit the ring");
        return 1;
    }

    // ---- normalise to full swing, then the caller's own gain on top. Every
    // sound leaves here at the SAME peak so the game can reason about
    // loudness in one place; gain is only for the ones that should sit back.
    //
    // THE PEAK IS MEASURED ON WHAT SHIPS, not on the source. A library file
    // is often loudest in a part that never leaves here - the rocket's peak
    // is four seconds into a ten-second burn and the game only takes the
    // first second, so normalising against the source sent it out at a peak
    // of 76 out of 127, half the swing it was entitled to, and it would have
    // been mixed against a full-scale explosion.
    double clipPeak = 0;
    for (int i = 0; i < len; i++) clipPeak = Math.Max(clipPeak, Math.Abs(res[lo + i]));
    var outb = new byte[len];
    int fade = Math.Min(FADEMS * RATE / 1000, len / 4);
    double scale = 127.0 / clipPeak * gain;
    int outPeak = 0;
    for (int i = 0; i < len; i++)
    {
        double v = res[lo + i] * scale;
        // fade the END always (it is either a cut or a natural decay - the
        // fade costs a natural one nothing), and the START only if the trim
        // actually bit into signal.
        if (i >= len - fade) v *= (len - i) / (double)fade;
        if (i < fade && lo > 0) v *= i / (double)fade;
        int s = (int)Math.Round(v);
        s = Math.Clamp(s, -128, 127);
        outPeak = Math.Max(outPeak, Math.Abs(s));
        outb[i] = (byte)(sbyte)s;
    }
    blobs.Add(outb);
    Console.WriteLine($"  {name,-11} {Path.GetFileName(file),-24} {inSec,6:F2}s  " +
                      $"{(hi - lo + 1) / (double)RATE,6:F2}s  {len / (double)RATE,6:F2}s" +
                      $"  {outPeak,4}{(capped ? "  (capped)" : "")}");
}

// ---- pack. Header: 'SF', count, then count x {offset, length} words.
int hdr = 4 + specs.Count * 4;
var dat = new List<byte>();
void W16(List<byte> d, int v) { d.Add((byte)(v & 255)); d.Add((byte)(v >> 8)); }
dat.Add((byte)'S'); dat.Add((byte)'F');
W16(dat, specs.Count);
int off = hdr;
foreach (var b in blobs) { W16(dat, off); W16(dat, b.Length); off += b.Length; }
foreach (var b in blobs) dat.AddRange(b);

if (dat.Count > 0xFFF0)
{
    Console.Error.WriteLine($"SFX.DAT is {dat.Count} bytes - it must fit one 64K segment");
    return 1;
}
Directory.CreateDirectory(outDir);
File.WriteAllBytes(Path.Combine(outDir, "SFX.DAT"), dat.ToArray());

var inc = new List<string>
{
    "; generated by Snd2Dat - do not edit by hand",
    $"SFXN    equ {specs.Count}                  ; sounds in the bank",
};
for (int i = 0; i < specs.Count; i++)
    inc.Add($"SFX_{specs[i].name,-6} equ {i}");
Directory.CreateDirectory(srcDir);
File.WriteAllLines(Path.Combine(srcDir, "SFXIDX.INC"), inc);

Console.WriteLine($"  wrote SFX.DAT: {dat.Count} bytes ({dat.Count * 100 / 0xFFF0}% of a segment), " +
                  $"{(dat.Count - hdr) / (double)RATE:F2}s of audio in {specs.Count} sounds");
return 0;

// ---------------------------------------------------------------- WAV
static (double[] mono, int rate) ReadWav(string path)
{
    var b = File.ReadAllBytes(path);
    if (b.Length < 12 || b[0] != 'R' || b[1] != 'I' || b[2] != 'F' || b[3] != 'F' ||
        b[8] != 'W' || b[9] != 'A' || b[10] != 'V' || b[11] != 'E')
        throw new Exception($"{path}: not a RIFF/WAVE file");
    int fmt = 0, ch = 0, rate = 0, bits = 0, dataOff = -1, dataLen = 0;
    for (int p = 12; p + 8 <= b.Length;)
    {
        string id = System.Text.Encoding.ASCII.GetString(b, p, 4);
        int sz = BitConverter.ToInt32(b, p + 4);
        int body = p + 8;
        if (sz < 0 || body + sz > b.Length) sz = b.Length - body;
        if (id == "fmt ")
        {
            fmt = BitConverter.ToUInt16(b, body);
            ch = BitConverter.ToUInt16(b, body + 2);
            rate = BitConverter.ToInt32(b, body + 4);
            bits = BitConverter.ToUInt16(b, body + 14);
            if (fmt == 0xFFFE && sz >= 26)          // WAVE_FORMAT_EXTENSIBLE
                fmt = BitConverter.ToUInt16(b, body + 24);
        }
        else if (id == "data") { dataOff = body; dataLen = sz; }
        p = body + sz + (sz & 1);
    }
    if (dataOff < 0 || ch == 0) throw new Exception($"{path}: no usable data chunk");
    if (fmt != 1 && fmt != 3) throw new Exception($"{path}: unsupported format {fmt}");

    int bytesPer = bits / 8, frame = bytesPer * ch;
    int frames = dataLen / frame;
    var mono = new double[frames];
    for (int i = 0; i < frames; i++)
    {
        double s = 0;
        for (int c = 0; c < ch; c++)
        {
            int o = dataOff + i * frame + c * bytesPer;
            s += (fmt, bits) switch
            {
                (1, 8) => (b[o] - 128) / 128.0,
                (1, 16) => BitConverter.ToInt16(b, o) / 32768.0,
                (1, 24) => ((b[o] | (b[o + 1] << 8) | ((sbyte)b[o + 2] << 16))) / 8388608.0,
                (1, 32) => BitConverter.ToInt32(b, o) / 2147483648.0,
                (3, 32) => BitConverter.ToSingle(b, o),
                (3, 64) => BitConverter.ToDouble(b, o),
                _ => throw new Exception($"{path}: {bits}-bit format {fmt} not handled")
            };
        }
        mono[i] = s / ch;
    }
    return (mono, rate);
}
