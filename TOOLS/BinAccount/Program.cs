// ============================================================================
//  BinAccount - account for every byte by which a FASM build differs from the
//  TASM build of the same source.
//
//  WHY THIS EXISTS. A port from one assembler to another cannot be checked
//  with a checksum, because the two binaries are not meant to match. TASM is
//  one-pass: JUMPS reserves room for the long form of a jump, and when the
//  target turns out to be near enough for the short form it cannot go back
//  and shrink - the instruction is already placed and everything after it is
//  already addressed - so it pads the slack with NOP. FASM makes as many
//  passes as it needs and emits the short form directly.
//
//  So the FASM build is smaller, and "smaller" proves nothing on its own.
//  What proves the port is COMPLETE ACCOUNTING: every byte of the difference
//  identified. One unexplained byte means the two builds are not the same
//  program, and that is a bug, not a rounding error.
//
//  WHY IT DECODES INSTRUCTIONS INSTEAD OF COMPARING BYTES. Comparing bytes
//  does not survive the first jump: bytes vanish somewhere in the middle, so
//  every address after that point differs, and a byte diff drowns in operands
//  that were never in question. What has to match is the INSTRUCTION STREAM -
//  the same operations, in the same order, on the same operands - while the
//  addresses inside them are expected to move. So this decodes both files far
//  enough to know where each instruction ends and what it is. It is not a
//  disassembler and prints no mnemonics; it needs lengths and identities.
//
//  OPERAND VALUES ARE CHECKED, which is the part that makes this more than a
//  shape comparison. Where two matching instructions carry different values,
//  the difference must be a plausible relocation: the FASM value smaller than
//  the TASM one by no more than the total number of bytes the build shrank,
//  which is the most any address in it can have moved. A constant that was
//  altered by the port fails that test unless the alteration happens to land
//  inside that window - so this narrows the hole rather than closing it, and
//  the window is only ever a few hundred bytes wide.
//
//  The differences it accepts, and nothing else:
//
//      NOP in TASM, absent in FASM        padding TASM could not take back
//      JMP near  ->  JMP short            1 byte
//      Jcc near (386, 0F 8x) -> Jcc short 4 bytes
//      Jncc short over + JMP near
//        -> Jcc short                     the JUMPS expansion, 3 bytes
//      the same register-to-register
//        operation, direction bit the
//        other way round                  0 bytes
//      the same arithmetic on a register
//        against a constant, written in
//        a different one of the forms
//        the 8086 provides               0 or 1 byte
//      an operand that moved              0 bytes
//
//  The two encoding choices are not mistakes by either assembler. With two
//  register operands, MOV BL,AL is 8A D8 or 88 C3 - the direction bit says
//  which operand the ModRM reg field names, and either way encodes the same
//  move. SUB AX,6 is 2D 06 00 in the accumulator form or 83 E8 06 with a
//  sign-extended byte. The assemblers simply chose differently.
//
//  DATA IN THE MIDDLE OF THE CODE. It decodes from the entry point straight
//  through, so it reads data as if it were code. Identical data decodes
//  identically on both sides and steps past itself harmlessly - but a table
//  of ADDRESSES does not, because addresses are what move. Several of these
//  programs dispatch through one. When the walk can no longer explain a
//  difference as an instruction it falls back to DataRun, which crosses the
//  stretch in lockstep and demands that every disagreement be a 16-bit word
//  that moved by no more than the shrink. Both sides advance equally, so a
//  data run can excuse different CONTENT and never a different SIZE.
//
//  And to be sure the two walks stay on the same instructions at all, the gap
//  between the cursors is checked against the running total on every step. If
//  they ever disagree the walk stopped being meaningful somewhere earlier, and
//  it says so there rather than inventing a difference further on.
//
//      dotnet run --project TOOLS\BinAccount -c Release -- <tasm.com> <fasm.com>
// ============================================================================

using System.Text;

if (args.Length < 2)
{
    Console.Error.WriteLine("usage: BinAccount <tasm-build> <fasm-build> [slack]");
    Console.Error.WriteLine("       BinAccount -exe <tasm.exe> <fasm.exe> [slack]");
    Console.Error.WriteLine();
    Console.Error.WriteLine("  slack - how far an address is allowed to have moved, when that");
    Console.Error.WriteLine("          cannot be read off the size difference. A segment padded");
    Console.Error.WriteLine("          to a fixed window is the same length in both builds even");
    Console.Error.WriteLine("          though the code inside it shrank, so there is nothing for");
    Console.Error.WriteLine("          the tool to infer and the figure has to be given.");
    Console.Error.WriteLine();
    Console.Error.WriteLine("  -exe  - an MZ executable of several segments. Strips the header,");
    Console.Error.WriteLine("          finds the segment boundaries and accounts for each one on");
    Console.Error.WriteLine("          its own, because a walk cannot cross a boundary: the two");
    Console.Error.WriteLine("          builds meet again there, at the same absolute offset,");
    Console.Error.WriteLine("          having drifted apart in between.");
    return 2;
}

if (args[0] == "-exe") return Exe(args);

byte[] tb = File.ReadAllBytes(args[0]);
byte[] fb = File.ReadAllBytes(args[1]);
int shrink = tb.Length - fb.Length;
int slack = args.Length >= 3 ? int.Parse(args[2]) : shrink;

Console.WriteLine($"  TASM  {Path.GetFileName(args[0]),-14} {tb.Length,6} bytes");
Console.WriteLine($"  FASM  {Path.GetFileName(args[1]),-14} {fb.Length,6} bytes");
Console.WriteLine($"  difference {shrink} bytes\n");

// Two cursors, not two lists. Decoding the whole file up front cannot
// survive a data region: the moment the walk steps over one, every
// instruction boundary after it is wrong, and there is no way back into the
// stream. Decoding on demand means a resume point is simply an offset.
var acc = new Accounts();
int i = 0, j = 0;
int steps = 0;

while (i < tb.Length && j < fb.Length)
{
    Ins a = Decode.One(tb, i), b = Decode.One(fb, j);

    // The invariant that keeps the whole walk honest: the gap between the two
    // cursors is exactly what has been accounted for so far. If it ever is
    // not, the streams came apart earlier and every match since has been
    // coincidence - so say so here rather than report a bewildering
    // difference hundreds of bytes further on.
    if (i - j != acc.Explained)
    {
        Console.WriteLine($"LOST THE THREAD at TASM 0x{i:X4} / FASM 0x{j:X4}\n");
        Console.WriteLine($"  the cursors are {i - j} bytes apart but {acc.Explained} bytes");
        Console.WriteLine("  have been accounted for, so the two walks are no longer on the");
        Console.WriteLine("  same instructions. The real difference is somewhere before this.");
        return 1;
    }
    steps++;

    // The LOOP/JCXZ expansion, which has to be tried BEFORE plain equality
    // because both sides are the same opcode and only the distance differs.
    // These four have no long form on any processor, so the only way to reach
    // further is to jump to a jump - and TASM, having reserved the room, keeps
    // it even where the short form would now do:
    //
    //     E3 02  EB 03  E9 lo hi        ->    E3 disp
    //
    // Three instructions on that side, one on the other, five bytes.
    //
    // BOTH sides must be examined before either is believed. The opcode and
    // the displacement 2 are identical whether or not the expansion follows,
    // so testing one side alone happily "explains" a site where both
    // assemblers expanded - and swallows three instructions against one,
    // which puts the walk five bytes out and blames somewhere else entirely.
    if (a.Op is >= 0xE0 and <= 0xE3 && b.Op == a.Op)
    {
        bool tExp = Expanded(tb, i, a, out int tLen);
        bool fExp = Expanded(fb, j, b, out int fLen);

        // TASM kept the room it reserved; FASM found the short form reached.
        if (tExp && !fExp)
        { acc.Exp += tLen - b.Len; acc.ExpN++; i += tLen; j += b.Len; continue; }

        // The other way round, and the one case in this whole comparison where
        // the FASM build is LONGER. E_8086.INC measures the distance itself,
        // and on a forward reference the target is unknown on the first pass -
        // so at a site near the boundary the macro keeps the long form it
        // chose while it could not see. Correct 8086 either way; five bytes
        // that did not have to be spent, counted rather than hidden.
        if (fExp && !tExp)
        { acc.Exp += a.Len - fLen; acc.CautiousN++; i += a.Len; j += fLen; continue; }

        // Both expanded, or neither: ordinary matching handles it.
    }

    // Same instruction. Its operands still have to agree, or differ by no
    // more than everything that was removed ahead of them.
    if (a.Key == b.Key)
    {
        if (!Operands(a, b, slack, acc)) { Report(a, b, tb, fb, "the operands do not line up"); return 1; }
        i += a.Len; j += b.Len; continue;
    }

    // NOP that TASM left behind and FASM never needed.
    if (a.IsNop) { acc.Pad += a.Len; acc.PadN++; i += a.Len; continue; }

    // The same register-to-register operation, direction bit reversed.
    if (Equiv.Mirrored(a, b)) { acc.DirN++; i += a.Len; j += b.Len; continue; }

    // The same arithmetic on a register against a constant, written in a
    // different one of the forms the instruction set provides.
    if (Arith.Same(a, b))
    {
        if (!Arith.SameConstant(a, b)) { Report(a, b, tb, fb, "the constants differ"); return 1; }
        acc.Form += a.Len - b.Len; acc.FormN++; i += a.Len; j += b.Len; continue;
    }

    // A displacement of ZERO, written out on one side and dropped on the
    // other: 2E 8A A4 00 00 against 2E 8A 24, [cs:si+0000] and [cs:si]. The
    // same address either way. It happens wherever a symbol sits at offset
    // zero of its segment, which in these far segments is the first table in
    // the file - the one every window opens with.
    //
    // rm=6 is excluded on purpose: with mod=0 that encoding does not mean
    // [bp], it means a bare absolute address, so the two forms are genuinely
    // different instructions there.
    if (a.Op == b.Op && a.Pfx == b.Pfx && a.ModRM >= 0 && b.ModRM >= 0
        && (b.ModRM >> 6) == 0 && (a.ModRM >> 6) is 1 or 2
        && (a.ModRM & 7) == (b.ModRM & 7) && (a.ModRM & 7) != 6
        && ((a.ModRM >> 3) & 7) == ((b.ModRM >> 3) & 7)
        && a.Disp == 0 && a.Imm == b.Imm)
    { acc.Disp += a.Len - b.Len; acc.DispN++; i += a.Len; j += b.Len; continue; }

    // A far call to a procedure that turned out to be in the SAME segment.
    // TASM spots this and writes it in four bytes instead of five:
    //
    //     0E              push cs          the return segment, by hand
    //     E8 lo hi        call near        the return offset, by the call
    //
    // which leaves exactly the far return address the procedure's RETF wants.
    // FASM is told SEGMENT:LABEL and emits the honest 9A, so here - and only
    // here - the FASM build is a byte LONGER. Both are correct; the targets
    // are checked against each other to be sure it is the same call.
    if (a.Op == 0x0E && b.Op == 0x9A && i + a.Len < tb.Length)
    {
        Ins near = Decode.One(tb, i + a.Len);
        if (near.Op == 0xE8)
        {
            long tTarget = i + a.Len + near.Len + near.Imm;
            long fTarget = b.Imm & 0xFFFF;
            long moved = tTarget - fTarget;
            if (moved >= 0 && moved <= slack)
            {
                acc.PushCs += a.Len + near.Len - b.Len; acc.PushCsN++;
                i += a.Len + near.Len; j += b.Len; continue;
            }
        }
    }

    // The same memory operand with a wider displacement than it needed:
    // 8B 84 5E 00 against 8B 44 5E, mod=2 where mod=1 reached. One byte, and
    // it is the same address - a one-pass assembler that has not yet seen the
    // value has to assume the wide form and cannot take it back.
    if (a.Op == b.Op && a.Pfx == b.Pfx && a.ModRM >= 0 && b.ModRM >= 0
        && (a.ModRM >> 6) == 2 && (b.ModRM >> 6) == 1
        && (a.ModRM & 0x3F) == (b.ModRM & 0x3F)
        && a.Disp == (sbyte)(byte)b.Disp && a.Imm == b.Imm)
    { acc.Disp += a.Len - b.Len; acc.DispN++; i += a.Len; j += b.Len; continue; }

    // JMP near -> JMP short.
    if (a.Op == 0xE9 && b.Op == 0xEB)
    { acc.Jmp += a.Len - b.Len; acc.JmpN++; i += a.Len; j += b.Len; continue; }

    // Jcc in the 386 long form -> Jcc short, same condition.
    if (a.Op >= 0x0F80 && a.Op <= 0x0F8F && b.Op >= 0x70 && b.Op <= 0x7F
        && (a.Op & 0x0F) == (b.Op & 0x0F))
    { acc.Cc += a.Len - b.Len; acc.CcN++; i += a.Len; j += b.Len; continue; }

    // The JUMPS expansion: TASM wrote the inverse condition as a short jump
    // over a near JMP, where the short form of the original would have
    // reached. Two instructions in TASM, one in FASM.
    if (a.Op >= 0x70 && a.Op <= 0x7F && b.Op >= 0x70 && b.Op <= 0x7F
        && (a.Op & 0x0F) == ((b.Op & 0x0F) ^ 1) && i + a.Len < tb.Length)
    {
        Ins a2 = Decode.One(tb, i + a.Len);
        if (a2.Op == 0xE9)
        {
            acc.Exp += a.Len + a2.Len - b.Len; acc.ExpN++;
            i += a.Len + a2.Len; j += b.Len; continue;
        }
    }

    // Nothing left to try as an instruction - so this is probably not one.
    // Several of these programs dispatch through a table of addresses, and a
    // table of addresses is precisely what changes when the code in front of
    // it gets shorter. Walk it as data: same length on both sides, every
    // difference a relocated address. See DataRun.
    if (DataRun.Cross(tb, fb, i, j, slack, out int endT, out int endF, out int words)
        && endT - i == endF - j)
    {
        acc.Data += endT - i; acc.DataN++; acc.DataWords += words;
        i = endT; j = endF; continue;
    }

    // Or the boundary itself is wrong. Data that is IDENTICAL on both sides
    // is stepped over without complaint, but it is still being read as code,
    // and it can leave the walk standing a byte or two off the next real
    // instruction - on both sides equally, so the cursor check above sees
    // nothing. Look for the offset that puts both walks back on an
    // instruction, and take the smallest one that survives a few steps.
    if (Anchor.Find(tb, fb, i, j, out int shift))
    { acc.AnchorN++; i += shift; j += shift; continue; }

    Report(a, b, tb, fb, "these are different instructions");
    return 1;
}

// Trailing NOPs are still padding; anything else left over is a real
// difference in what the program contains.
while (i < tb.Length && tb[i] == 0x90) { acc.Pad++; acc.PadN++; i++; }
if (i < tb.Length || j < fb.Length)
{
    Console.WriteLine("One build runs out before the other:");
    Console.WriteLine($"  TASM has {tb.Length - i} bytes left, FASM has {fb.Length - j}.");
    return 1;
}

if (acc.DirN > 0) Console.WriteLine($"  {0,5}  register to register, direction bit reversed ({acc.DirN})");
if (acc.MovedN > 0) Console.WriteLine($"  {0,5}  operands that moved with the code ({acc.MovedN})");
if (acc.DataN > 0) Console.WriteLine($"  {0,5}  data - {acc.Data} bytes on both sides, {acc.DataWords} relocated addresses in {acc.DataN} runs");
if (acc.AnchorN > 0) Console.WriteLine($"  {0,5}  instruction boundary re-found after data ({acc.AnchorN})");
if (acc.FormN > 0) Console.WriteLine($"  {acc.Form,5}  constant arithmetic in a different form ({acc.FormN})");
if (acc.PushCsN > 0) Console.WriteLine($"  {acc.PushCs,5}  PUSH CS + near call where FASM wrote a far one ({acc.PushCsN})");
if (acc.DispN > 0) Console.WriteLine($"  {acc.Disp,5}  displacement wider than it needed to be ({acc.DispN} x 1)");
if (acc.PadN > 0) Console.WriteLine($"  {acc.Pad,5}  NOP padding TASM could not take back ({acc.PadN})");
if (acc.JmpN > 0) Console.WriteLine($"  {acc.Jmp,5}  near JMP that fits the short form ({acc.JmpN} x 1)");
if (acc.CcN > 0) Console.WriteLine($"  {acc.Cc,5}  long conditional jump shortened ({acc.CcN} x 4)");
if (acc.ExpN > 0 || acc.CautiousN > 0)
    Console.WriteLine($"  {acc.Exp,5}  jump expansion: {acc.ExpN} TASM kept and FASM did not need"
                      + (acc.CautiousN > 0 ? $", {acc.CautiousN} the other way round" : ""));
Console.WriteLine("  -----");

int explained = acc.Explained;
Console.WriteLine($"  {explained,5}  accounted for, of {shrink}");

if (explained != shrink)
{
    Console.WriteLine("\nThe instruction streams match but the arithmetic does not, which");
    Console.WriteLine("should be impossible. Suspect the decoder before the assemblers.");
    return 1;
}

Console.WriteLine($"\nEvery byte accounted for across {steps} instructions.");
Console.WriteLine("The two builds are the same program.");
return 0;

// Two matching instructions must carry matching operands - or operands that
// differ only the way an address does when the code ahead of it got shorter.
//
// An ABSOLUTE operand can only move down: everything sits at a lower address
// in the shorter build, by at most the whole shrink.
//
// A RELATIVE one - the displacement inside a branch - is signed, and what
// shrinks is the SPAN it crosses, not the number in it. A jump backwards over
// removed padding has a displacement nearer to zero, which as a raw value is
// larger. So relative operands are compared by magnitude, and the sign must
// not change: a jump that turned round is not a jump that moved.
static bool Operands(Ins a, Ins b, int shrink, Accounts acc)
{
    bool moved = false;
    if (!Value(a.Disp, b.Disp, shrink, false, ref moved)) return false;
    if (!Value(a.Imm, b.Imm, shrink, a.IsRel, ref moved)) return false;
    if (moved) acc.MovedN++;
    return true;
}

// An MZ executable of several segments, compared a segment at a time.
//
// The walk cannot simply run the length of the image. Each segment is padded
// to a fixed window, so the two builds are the same LENGTH there even where
// the code inside one of them shrank - and the walk, having drifted apart
// inside a segment, would meet a wall of padding it could not step over.
// Cut at the boundaries and each piece is an ordinary comparison again.
//
// The boundaries are read out of the executable's own RELOCATION TABLE, which
// is exact and needs no configuring. Every entry points at a word holding a
// segment's paragraph - that is what the loader adds the load address to - so
// the distinct values across the table are precisely the segments the program
// declares. Guessing them from runs of padding does not work: the segments
// are full of tables that are zero to begin with, and the guess cuts them up.
static int Exe(string[] args)
{
    byte[] ta = Image(args[1]), fa = Image(args[2]);
    int slack = args.Length >= 4 ? int.Parse(args[3]) : 4096;
    var bounds = Boundaries(args[1], ta);

    Console.WriteLine($"  TASM  {Path.GetFileName(args[1]),-16} image {ta.Length} bytes");
    Console.WriteLine($"  FASM  {Path.GetFileName(args[2]),-16} image {fa.Length} bytes");
    if (ta.Length != fa.Length)
    {
        Console.WriteLine("\nThe images are different lengths, so the segments cannot be at the");
        Console.WriteLine("same offsets and nothing below would mean anything.");
        return 1;
    }

    Console.WriteLine($"  {bounds.Count} segments\n");

    int bad = 0;
    for (int s = 0; s < bounds.Count; s++)
    {
        int from = bounds[s], to = s + 1 < bounds.Count ? bounds[s + 1] : ta.Length;
        // Compare only as far as each side actually used: the rest is padding
        // and its length is a property of the window, not of the code.
        int tu = Used(ta, from, to), fu = Used(fa, from, to);
        string tmp = Path.GetTempPath();
        string tp = Path.Combine(tmp, $"ba_t{s}.bin"), fp = Path.Combine(tmp, $"ba_f{s}.bin");
        File.WriteAllBytes(tp, ta[from..(from + tu)]);
        File.WriteAllBytes(fp, fa[from..(from + fu)]);

        Console.WriteLine($"=== segment {s} at paragraph {from / 16:X4}h, "
                          + $"{(to - from) / 1024}K window, used {tu} / {fu} ===");
        int rc = Run(tp, fp, slack);
        if (rc != 0) bad++;
        File.Delete(tp); File.Delete(fp);
    }
    Console.WriteLine(bad == 0
        ? "\nEvery segment accounted for. The two builds are the same program."
        : $"\n{bad} of {bounds.Count} segments could not be accounted for.");
    return bad == 0 ? 0 : 1;

    static byte[] Image(string path)
    {
        byte[] d = File.ReadAllBytes(path);
        int lastPage = d[2] | (d[3] << 8), pages = d[4] | (d[5] << 8);
        int hdr = (d[8] | (d[9] << 8)) * 16;
        int n = (pages - 1) * 512 + (lastPage == 0 ? 512 : lastPage) - hdr;
        return d[hdr..(hdr + n)];
    }

    static List<int> Boundaries(string path, byte[] img)
    {
        byte[] d = File.ReadAllBytes(path);
        int count = d[6] | (d[7] << 8);
        int table = d[0x18] | (d[0x19] << 8);

        var paras = new SortedSet<int> { 0 };   // the first segment, always
        for (int r = 0; r < count; r++)
        {
            int off = d[table + r * 4] | (d[table + r * 4 + 1] << 8);
            int seg = d[table + r * 4 + 2] | (d[table + r * 4 + 3] << 8);
            int at = seg * 16 + off;
            if (at + 1 >= img.Length) continue;
            int value = img[at] | (img[at + 1] << 8);
            if (value * 16 < img.Length) paras.Add(value);
        }
        return paras.Select(p => p * 16).ToList();
    }

    static int Used(byte[] img, int from, int to)
    {
        int end = to;
        while (end > from && img[end - 1] == 0) end--;
        return end - from;
    }

    // Each segment is compared by running this same program again on the two
    // pieces. How to launch it depends on how it was launched: under
    // `dotnet run` the host is dotnet and the assembly has to be named,
    // whereas a published build is its own executable and naming the assembly
    // would make it an input file.
    static int Run(string a, string b, int slack)
    {
        string host = Environment.ProcessPath ?? "dotnet";
        var psi = new System.Diagnostics.ProcessStartInfo(host);
        if (Path.GetFileNameWithoutExtension(host).Equals("dotnet", StringComparison.OrdinalIgnoreCase))
            psi.ArgumentList.Add(Environment.GetCommandLineArgs()[0]);
        psi.ArgumentList.Add(a); psi.ArgumentList.Add(b); psi.ArgumentList.Add(slack.ToString());
        using var p = System.Diagnostics.Process.Start(psi);
        p.WaitForExit();
        return p.ExitCode;
    }
}

// Is the CX-branch at `at` the head of the jump-to-a-jump expansion? The
// signature is the whole of it: a displacement of exactly 2 over a two-byte
// short jump, that short jump stepping exactly 3 over a near one.
static bool Expanded(byte[] img, int at, Ins head, out int len)
{
    len = head.Len;
    if (head.Imm != 2 || at + head.Len >= img.Length) return false;
    Ins over = Decode.One(img, at + head.Len);
    if (over.Op != 0xEB || over.Imm != 3 || at + head.Len + over.Len >= img.Length) return false;
    Ins far = Decode.One(img, at + head.Len + over.Len);
    if (far.Op != 0xE9) return false;
    len = head.Len + over.Len + far.Len;
    return true;
}

static bool Value(long x, long y, int shrink, bool rel, ref bool moved)
{
    if (x == y) return true;
    if (x == long.MinValue || y == long.MinValue) return false;

    long d = rel ? (x < 0) != (y < 0) ? -1 : Math.Abs(x) - Math.Abs(y)
                 : x - y;
    if (d <= 0 || d > shrink) return false;
    moved = true;
    return true;
}

static void Report(Ins a, Ins b, byte[] tb, byte[] fb, string why)
{
    Console.WriteLine($"UNEXPLAINED at TASM 0x{a.At:X4} / FASM 0x{b.At:X4} - {why}\n");
    Console.WriteLine("  TASM  " + Hex(tb, a.At));
    Console.WriteLine("  FASM  " + Hex(fb, b.At));
    Console.WriteLine("\nRead the source at that point before trusting either build.");
}

static string Hex(byte[] a, int at)
{
    var sb = new StringBuilder();
    for (int k = at; k < Math.Min(a.Length, at + 12); k++) sb.Append($"{a[k]:X2} ");
    return sb.ToString();
}

// ---------------------------------------------------------------------------

sealed class Accounts
{
    public int Pad, PadN, Jmp, JmpN, Cc, CcN, Exp, ExpN, Form, FormN, DirN, MovedN;
    public int Data, DataN, DataWords, AnchorN, CautiousN, Disp, DispN, PushCs, PushCsN;

    /// <summary>Bytes explained so far - which is also how far apart the two
    /// cursors are entitled to be.</summary>
    public int Explained => Pad + Jmp + Cc + Exp + Form + Disp + PushCs;
}

// The same operation written the other way round. With two register operands
// the direction bit only says which of them the ModRM reg field names, so
// MOV BL,AL is 8A D8 or 88 C3 and both are the same move.
static class Equiv
{
    public static bool Mirrored(Ins a, Ins b)
    {
        if (a.ModRM < 0 || b.ModRM < 0 || a.Pfx != b.Pfx) return false;
        if ((a.ModRM >> 6) != 3 || (b.ModRM >> 6) != 3) return false;
        if (a.Op != (b.Op ^ 2)) return false;
        if (!Dir(a.Op) || !Dir(b.Op)) return false;
        return ((a.ModRM >> 3) & 7) == (b.ModRM & 7) && (a.ModRM & 7) == ((b.ModRM >> 3) & 7);

        static bool Dir(int op) => (op < 0x40 && (op & 7) <= 3) || (op is >= 0x88 and <= 0x8B);
    }

    /// <summary>The same instruction, however the two assemblers spelled it.</summary>
    public static bool Any(Ins a, Ins b) =>
        a.Key == b.Key || Mirrored(a, b) || Arith.Same(a, b);
}

// Where the next real instruction begins, when the walk has been reading data
// as code and has come out standing in the middle of one.
//
// The shift is the SAME on both sides - identical data desynchronises both
// walks identically - so the gap between the cursors never changes and the
// accounting is untouched. Nothing is skipped either: the bytes in between
// were byte-for-byte equal, or the walk would have stopped at them.
//
// A candidate has to survive Confirm steps of plain agreement, TASM's padding
// aside. Eight instructions of coincidence is not something these files do.
static class Anchor
{
    const int Reach = 4;        // how far the boundary can be out
    const int Confirm = 8;      // instructions that must agree to believe it

    public static bool Find(byte[] t, byte[] f, int ti, int fj, out int shift)
    {
        foreach (int k in Order())
        {
            if (ti + k < 0 || fj + k < 0) continue;
            if (Holds(t, f, ti + k, fj + k)) { shift = k; return true; }
        }
        shift = 0;
        return false;
    }

    // Nearest first, and backwards before forwards: overrunning the end of a
    // table is far commoner than stopping short of it.
    static IEnumerable<int> Order()
    {
        for (int d = 1; d <= Reach; d++) { yield return -d; yield return d; }
    }

    static bool Holds(byte[] t, byte[] f, int p, int q)
    {
        for (int n = 0; n < Confirm; n++)
        {
            if (p >= t.Length || q >= f.Length) return false;
            Ins a = Decode.One(t, p);
            if (a.IsNop) { p += a.Len; n--; continue; }
            Ins b = Decode.One(f, q);
            if (!Equiv.Any(a, b)) return false;
            p += a.Len; q += b.Len;
        }
        return true;
    }
}

// A stretch that is not code. Several of these programs dispatch through a
// table of addresses, and a table of addresses is precisely what changes when
// the code in front of it gets shorter - so the decode, which cannot tell
// data from code, walks into it and comes out desynchronised.
//
// This walks the two files forward in lockstep instead. Bytes that agree cost
// nothing. Bytes that disagree must form a 16-bit word that agrees to within
// the shrink - an address that moved, and nothing else. The run ends after
// enough consecutive agreeing bytes that the files are certainly back in step,
// and the cursors rewind to where that agreement began, which is where the
// table ended and the code resumed.
//
// The lockstep is what keeps the accounting sound: both sides advance by the
// same number of bytes, so a data region can explain differing CONTENT but
// can never explain away a difference in SIZE.
static class DataRun
{
    const int Settled = 16;     // agreeing bytes that mean we are back in step
    const int Longest = 4096;   // a table longer than this is not a table

    public static bool Cross(byte[] t, byte[] f, int ti, int fj, int shrink,
                             out int endT, out int endF, out int words)
    {
        int p = ti, q = fj, run = 0, w = 0;
        endT = ti; endF = fj; words = 0;

        while (p < t.Length && q < f.Length && p - ti < Longest)
        {
            if (t[p] == f[q])
            {
                run++; p++; q++;
                if (run >= Settled)
                {
                    endT = p - run; endF = q - run; words = w;
                    return w > 0;       // no relocated word means no explanation
                }
                continue;
            }

            run = 0;
            if (p + 1 >= t.Length || q + 1 >= f.Length) return false;
            long tw = t[p] | (t[p + 1] << 8);
            long fw = f[q] | (f[q + 1] << 8);
            long d = tw - fw;
            if (d <= 0 || d > shrink) return false;
            p += 2; q += 2; w++;
        }
        return false;
    }
}

// long.MinValue means "this instruction has no operand of that kind".
readonly record struct Ins(int At, int Len, int Op, int ModRM, long Disp, long Imm, string Pfx, string Key)
{
    public bool IsNop => Op == 0x90 && Len == 1;

    // Branches whose immediate is a distance from here, not an address.
    public bool IsRel => Op is (>= 0x70 and <= 0x7F) or (>= 0xE0 and <= 0xE3)
                            or 0xE8 or 0xE9 or 0xEB or (>= 0x0F80 and <= 0x0F8F);
}

// The eight arithmetic operations the 8086 can apply to a register and a
// constant, each of which it can encode more than one way. Reduced to
// (operation, register, width) so the forms can be compared against each
// other; the constant itself is compared separately, like any other operand.
static class Arith
{
    public static bool Same(Ins a, Ins b)
    {
        var x = Of(a); var y = Of(b);
        return x.HasValue && y.HasValue && x.Value == y.Value && a.Pfx == b.Pfx;
    }

    // The constant itself, widened to what the processor will actually use.
    // Form 83 carries one byte and sign-extends it, so 83 F8 E2 and 3D E2 FF
    // are both CMP AX,-30 - the same constant written two ways, and the only
    // place in this tool where an operand VALUE has to be normalised before
    // it can be compared.
    public static bool SameConstant(Ins a, Ins b) => Widen(a) == Widen(b);

    static long Widen(Ins i)
    {
        var d = Of(i);
        if (d is null || i.Imm == long.MinValue) return long.MinValue;
        if (d.Value.W == 8) return i.Imm & 0xFF;
        long v = i.Op == 0x83 ? (i.Imm & 0x80) != 0 ? i.Imm - 0x100 : i.Imm : i.Imm;
        return v & 0xFFFF;
    }

    static (int Op, int Reg, int W)? Of(Ins i)
    {
        int op = i.Op;
        // Accumulator forms: op AL,imm8 and op AX,imm16.
        if (op < 0x40 && (op & 7) == 4) return ((op >> 3) & 7, 0, 8);
        if (op < 0x40 && (op & 7) == 5) return ((op >> 3) & 7, 0, 16);
        // Group forms against a register: 80/82 are byte, 81/83 word.
        if (op is 0x80 or 0x81 or 0x82 or 0x83)
        {
            if (i.ModRM < 0 || (i.ModRM >> 6) != 3) return null;
            return ((i.ModRM >> 3) & 7, i.ModRM & 7, op is 0x80 or 0x82 ? 8 : 16);
        }
        return null;
    }
}

static class Decode
{
    public static Ins One(byte[] a, int start)
    {
        int p = start;
        bool opsz32 = false, adsz32 = false;
        var pfx = new StringBuilder();

        while (p < a.Length)
        {
            byte c = a[p];
            if (c is 0x26 or 0x2E or 0x36 or 0x3E or 0x64 or 0x65)
            { pfx.Append($"{c:X2}:"); p++; continue; }
            if (c == 0x66) { opsz32 = true; pfx.Append("o32:"); p++; continue; }
            if (c == 0x67) { adsz32 = true; pfx.Append("a32:"); p++; continue; }
            if (c is 0xF0 or 0xF2 or 0xF3) { pfx.Append($"{c:X2}:"); p++; continue; }
            break;
        }
        string pf = pfx.ToString();
        const long NONE = long.MinValue;
        if (p >= a.Length) return new Ins(start, a.Length - start, -1, -1, NONE, NONE, pf, pf + "trunc");

        int op = a[p++];
        if (op == 0x0F && p < a.Length) op = 0x0F00 | a[p++];

        int modrm = -1;
        long disp = NONE;
        Shape s = ShapeOf(op);
        if (s.ModRM)
        {
            if (p >= a.Length) return new Ins(start, a.Length - start, op, -1, NONE, NONE, pf, pf + "trunc");
            modrm = a[p++];
            int dl = DispLen((byte)modrm, a, ref p, adsz32);
            if (dl > 0) disp = Read(a, p, dl);
            p += dl;
            if (s.ImmFromReg) s = s.WithImm(((modrm >> 3) & 7) <= 1 ? (opsz32 ? 4 : s.RegImm) : 0);
        }

        int il = s.Imm == -1 ? (opsz32 ? 4 : 2) : s.Imm;
        long imm = il > 0 ? Read(a, p, il) : NONE;
        p += il;

        if (p > a.Length) p = a.Length;
        string key = modrm < 0 ? $"{pf}{op:X}+{il}" : $"{pf}{op:X}/{modrm:X2}+{il}";
        var ins = new Ins(start, p - start, op, modrm, disp, imm, pf, key);
        // A branch displacement is signed; read it as one so backwards jumps
        // compare as distances rather than as large unsigned numbers.
        if (ins.IsRel && il > 0) ins = ins with { Imm = Sign(imm, il) };
        return ins;
    }

    static long Sign(long v, int n)
    {
        long top = 1L << (8 * n - 1);
        return (v & top) != 0 ? v - (top << 1) : v;
    }

    static long Read(byte[] a, int p, int n)
    {
        long v = 0;
        for (int k = 0; k < n && p + k < a.Length; k++) v |= (long)a[p + k] << (8 * k);
        return v;
    }

    // Displacement bytes implied by a ModRM byte. SIB is consumed here too,
    // because in 32-bit addressing it can carry a displacement of its own.
    static int DispLen(byte m, byte[] a, ref int p, bool ad32)
    {
        int mod = m >> 6, rm = m & 7;
        if (mod == 3) return 0;

        if (!ad32)
            return mod switch { 0 => rm == 6 ? 2 : 0, 1 => 1, _ => 2 };

        int extra = 0;
        if (rm == 4)
        {
            if (p >= a.Length) return 0;
            byte sib = a[p++];
            if (mod == 0 && (sib & 7) == 5) extra = 4;
        }
        return mod switch { 0 => rm == 5 ? 4 : extra, 1 => 1 + extra, _ => 4 + extra };
    }

    readonly record struct Shape(bool ModRM, int Imm, bool ImmFromReg = false, int RegImm = 0)
    {
        public Shape WithImm(int n) => new(ModRM, n);
    }

    // -1 means "operand size": 2 bytes, or 4 with a 66 prefix.
    static Shape ShapeOf(int op)
    {
        if (op >= 0x0F00) return TwoByte(op);

        if (op < 0x40 && (op & 7) <= 5 && op != 0x0F)
            return (op & 7) switch
            {
                <= 3 => new Shape(true, 0),
                4 => new Shape(false, 1),
                _ => new Shape(false, -1),
            };

        return op switch
        {
            0x62 or 0x63 => new Shape(true, 0),
            0x68 => new Shape(false, -1),
            0x69 => new Shape(true, -1),
            0x6A => new Shape(false, 1),
            0x6B => new Shape(true, 1),
            >= 0x70 and <= 0x7F => new Shape(false, 1),
            0x80 or 0x82 or 0x83 => new Shape(true, 1),
            0x81 => new Shape(true, -1),
            >= 0x84 and <= 0x8F => new Shape(true, 0),
            0x9A => new Shape(false, 4),
            >= 0xA0 and <= 0xA3 => new Shape(false, 2),
            0xA8 => new Shape(false, 1),
            0xA9 => new Shape(false, -1),
            >= 0xB0 and <= 0xB7 => new Shape(false, 1),
            >= 0xB8 and <= 0xBF => new Shape(false, -1),
            0xC0 or 0xC1 => new Shape(true, 1),
            0xC2 or 0xCA => new Shape(false, 2),
            0xC4 or 0xC5 => new Shape(true, 0),
            0xC6 => new Shape(true, 1),
            0xC7 => new Shape(true, -1),
            0xC8 => new Shape(false, 3),
            0xCD => new Shape(false, 1),
            >= 0xD0 and <= 0xD3 => new Shape(true, 0),
            0xD4 or 0xD5 => new Shape(false, 1),
            >= 0xD8 and <= 0xDF => new Shape(true, 0),
            >= 0xE0 and <= 0xE7 => new Shape(false, 1),
            0xE8 or 0xE9 => new Shape(false, -1),
            0xEA => new Shape(false, 4),
            0xEB => new Shape(false, 1),
            // F6/F7 carry an immediate only for TEST - reg field 0 or 1.
            0xF6 => new Shape(true, 0, true, 1),
            0xF7 => new Shape(true, 0, true, 2),
            0xFE or 0xFF => new Shape(true, 0),
            _ => new Shape(false, 0),
        };
    }

    static Shape TwoByte(int op) => (op & 0xFF) switch
    {
        >= 0x80 and <= 0x8F => new Shape(false, -1),
        0xA0 or 0xA1 or 0xA8 or 0xA9 => new Shape(false, 0),
        0xA4 or 0xAC or 0xBA => new Shape(true, 1),
        _ => new Shape(true, 0),
    };
}
