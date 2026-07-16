# ============================================================================
#  obj2asm.py - the REFERENCE model precompiler: Wavefront OBJ -> engine
#  tables. The production tool is OBJ2DAT.COM (pure 8086, same folder);
#  this script exists to develop against and to cross-check the DOS tool
#  byte for byte, so both sides use the SAME integer arithmetic: the
#  fraction is truncated to 4 digits and scaled as
#  (frac * scale + den // 2) // den, rounding half away from zero.
#
#      python obj2asm.py trainer.obj -o TRAINER.INC [-n TRN] [-s 4]
#      python obj2asm.py trainer.obj --dat TRAINER.DAT [-s 4]
#
#  Quads pass through; triangles become quads with the last corner
#  doubled (the scanline filler draws them for free); anything above
#  4 corners is an error - subdivide it in Blender.
#
#  Axis map (Blender OBJ default: -Z forward, Y up):
#      engine X = obj X     (right wing)
#      engine Y = obj Y     (up)
#      engine Z = -obj Z    (nose)
#  Model in metres, scaled by -s into integer engine units (default 4).
#
#  Materials named PALnn carry the VGA palette index; any other material
#  falls back to PAL20 with a warning.
#
#  DAT layout (also the INC table order):
#      +0 db 'M','D'   +2 dw nverts   +4 dw nfaces
#      +6 dw x,y,z per vertex, then db i0,i1,i2,i3,colour per face
# ============================================================================
import argparse, re, struct, sys

def snum(s, scale):
    """Scale a decimal literal exactly as OBJ2DAT.COM does."""
    neg = s.startswith("-")
    if neg or s.startswith("+"):
        s = s[1:]
    if "e" in s or "E" in s:
        sys.exit("error: exponent notation unsupported: %s" % s)
    i, _, f = s.partition(".")
    f = f[:4]
    v = int(i or 0) * scale
    if f:
        den = 10 ** len(f)
        v += (int(f) * scale + den // 2) // den
    return -v if neg else v

def main():
    ap = argparse.ArgumentParser(description="OBJ -> WIRE CITY engine tables")
    ap.add_argument("obj")
    ap.add_argument("-o", "--out", help="output .INC/.ASM path")
    ap.add_argument("--dat", help="output binary .DAT path")
    ap.add_argument("-n", "--name", default="MDL", help="symbol prefix")
    ap.add_argument("-s", "--scale", type=int, default=4,
                    help="engine units per metre (integer)")
    args = ap.parse_args()
    if not args.out and not args.dat:
        sys.exit("error: give -o (INC) and/or --dat (binary)")

    verts, faces, colour = [], [], 20
    mtl_names, mtl_rgb = [], []
    import os
    for line in open(args.obj, encoding="ascii", errors="replace"):
        t = line.split()
        if not t:
            continue
        if t[0] == "mtllib":
            mp = os.path.join(os.path.dirname(args.obj), t[1])
            if os.path.exists(mp):
                cur = None
                for ml in open(mp, encoding="ascii", errors="replace"):
                    mt = ml.split()
                    if not mt:
                        continue
                    if mt[0] == "newmtl" and len(mtl_names) < 16:
                        mtl_names.append(mt[1][:15])
                        mtl_rgb.append([0, 0, 0])
                        cur = len(mtl_names) - 1
                    elif mt[0] == "Kd" and cur is not None:
                        mtl_rgb[cur] = [max(0, min(63, snum(w, 63)))
                                        for w in mt[1:4]]
        elif t[0] == "v":
            x, y, z = (snum(w, args.scale) for w in t[1:4])
            verts.append((x, y, -z))            # obj -Z forward -> engine +Z
        elif t[0] == "usemtl":
            m = re.fullmatch(r"PAL(\d+)", t[1])
            if m:
                colour = int(m.group(1))
            elif t[1][:15] in mtl_names:
                colour = 0x80 | mtl_names.index(t[1][:15])
            else:
                print("warning: unknown material %r, using PAL20" % t[1])
                colour = 20
        elif t[0] == "f":
            idx = [int(w.split("/")[0]) - 1 for w in t[1:]]
            if len(idx) == 3:
                idx.append(idx[2])              # triangle = folded quad
            if len(idx) != 4:
                sys.exit("error: %d-gon found - subdivide it in Blender"
                         % len(idx))
            faces.append((idx, colour))

    if len(verts) > 255:
        sys.exit("error: %d verts - face indices are bytes, max 255"
                 % len(verts))
    for v in verts:
        if any(abs(c) > 32000 for c in v):
            sys.exit("error: vertex %r overflows a word - lower -s" % (v,))

    if args.dat:
        with open(args.dat, "wb") as f:
            f.write(struct.pack("<2sHH", b"MD", len(verts), len(faces)))
            for v in verts:
                f.write(struct.pack("<3h", *v))
            for idx, col in faces:
                f.write(struct.pack("5B", *(idx + [col])))
            if mtl_names:
                f.write(struct.pack("2B", ord("P"), len(mtl_names)))
                for rgb in mtl_rgb:
                    f.write(struct.pack("3B", *rgb))
        print("%d verts, %d faces -> %s" % (len(verts), len(faces), args.dat))

    if args.out:
        n = args.name.upper()
        out = ["; generated by obj2asm.py from %s - do not edit by hand"
               % args.obj.replace("\\", "/"),
               "%sNV equ %d" % (n, len(verts)),
               "%sNF equ %d" % (n, len(faces)),
               "%sVT label word" % n]
        for x, y, z in verts:
            out.append("        dw %6d,%6d,%6d" % (x, y, z))
        out.append("%sFC label byte" % n)
        for idx, col in faces:
            out.append("        db %3d,%3d,%3d,%3d, %3d"
                       % (idx[0], idx[1], idx[2], idx[3], col))
        open(args.out, "w", newline="\r\n").write("\n".join(out) + "\n")
        print("%d verts, %d faces -> %s" % (len(verts), len(faces), args.out))

if __name__ == "__main__":
    main()
