# ============================================================================
#  radar_blender.py - builds the WIRE CITY radar station in Blender.
#
#  TWO objects, because the game spins the dish on the mast:
#      rbase - the lattice tower and platform (static)
#      rdish - the half-parabola antenna, feed boom, counterweight;
#              modelled AROUND THE ORIGIN: the origin IS the spin axis
#
#  Run from the Scripting tab, edit at will, then export EACH object:
#      select rbase -> File/Export/Wavefront OBJ, "Selection Only"
#                   -> GAMES\TRAINER\res\Rbase1.obj
#      select rdish -> same -> GAMES\TRAINER\res\Rdish1.obj
#  The build feeds both through \TOOLS\OBJ2DAT.COM at scale 4.
#
#  Conventions: metres, +Y is the dish's facing, +Z up, PALnn materials.
# ============================================================================
import bpy

PALETTE = {
    "PAL16": (42, 42, 47),   # structure / boom
    "PAL17": (52, 52, 56),   # platform roof
    "PAL18": (34, 34, 39),   # tower shade / counterweight
    "PAL19": (52, 56, 58),   # the dish face
}

def build(name, verts, faces):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], [f for f, _ in faces])
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    slot = {}
    for mname, (r, g, b) in PALETTE.items():
        mat = bpy.data.materials.get(mname) or bpy.data.materials.new(mname)
        mat.diffuse_color = (r / 63.0, g / 63.0, b / 63.0, 1.0)
        obj.data.materials.append(mat)
        slot[mname] = len(obj.data.materials) - 1
    for poly, (_, mname) in zip(mesh.polygons, faces):
        poly.material_index = slot[mname]
    return obj

# ---- rbase: a tapered tower shell and the platform on top ------------------
bv, bf = [], []
def BV(x, y, z):
    bv.append((x, y, z)); return len(bv) - 1
def BQ(a, b, c, d, m):
    bf.append(((a, b, c, d), m))

bot = [BV(-3, -3, 0), BV(3, -3, 0), BV(3, 3, 0), BV(-3, 3, 0)]
top = [BV(-1.2, -1.2, 18), BV(1.2, -1.2, 18), BV(1.2, 1.2, 18), BV(-1.2, 1.2, 18)]
for i in range(4):
    j = (i + 1) & 3
    BQ(bot[i], bot[j], top[j], top[i], "PAL18")
plo = [BV(-2, -2, 18), BV(2, -2, 18), BV(2, 2, 18), BV(-2, 2, 18)]
phi = [BV(-2, -2, 20), BV(2, -2, 20), BV(2, 2, 20), BV(-2, 2, 20)]
for i in range(4):
    j = (i + 1) & 3
    BQ(plo[i], plo[j], phi[j], phi[i], "PAL16")
BQ(phi[0], phi[1], phi[2], phi[3], "PAL17")
build("rbase", bv, bf)

# ---- rdish: the umbrella, x3 - a radial paraboloid ON TOP of the
# mast (heights are baked into the mesh: what you see is what flies).
# The spin axis is the vertical through the origin, so keep the dish
# centred on x=y=0.
dv, df = [], []
def DV(x, y, z):
    dv.append((x, y, z)); return len(dv) - 1
def DQ(a, b, c, d, m):
    df.append(((a, b, c, d), m))
def DT(a, b, c, m):
    df.append(((a, b, c), m))

import math
TOP = 21.0                      # the mast top + pedestal
apex = DV(0, 0, TOP)
mid, rim = [], []
for k in range(8):
    a = k * math.pi / 4.0
    cx, cz = math.cos(a), math.sin(a)
    mid.append(DV(4.5 * cx, 1.125, TOP + 4.5 * cz))
    rim.append(DV(9.0 * cx, 4.5, TOP + 9.0 * cz))
for k in range(8):
    j = (k + 1) & 7
    DT(apex, mid[k], mid[j], "PAL19")
    DQ(mid[k], rim[k], rim[j], mid[j], "PAL19")
a = DV(-0.18, 0.6, TOP); b = DV(0.18, 0.6, TOP)
c = DV(0.18, 5.7, TOP);  d = DV(-0.18, 5.7, TOP)
DQ(a, b, c, d, "PAL16")
a = DV(0, 0.6, TOP - 0.18); b = DV(0, 0.6, TOP + 0.18)
c = DV(0, 5.7, TOP + 0.18); d = DV(0, 5.7, TOP - 0.18)
DQ(a, b, c, d, "PAL16")
a = DV(-0.75, 4.5, TOP - 0.75); b = DV(0.75, 4.5, TOP - 0.75)
c = DV(0.75, 4.5, TOP + 0.75);  d = DV(-0.75, 4.5, TOP + 0.75)
DQ(a, b, c, d, "PAL18")
build("rdish", dv, df)

print("rbase: %d verts %d faces / rdish: %d verts %d faces"
      % (len(bv), len(bf), len(dv), len(df)))
