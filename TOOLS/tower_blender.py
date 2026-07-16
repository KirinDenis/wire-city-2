# ============================================================================
#  tower_blender.py - the control tower for WIRE CITY, in REAL COLOURS.
#
#  This one is painted through the MTL pipeline: name materials anything
#  you like and give them a diffuse colour - OBJ2DAT reads the .mtl,
#  quantises Kd to the VGA DAC and ships the palette inside the DAT.
#  (PALnn names still mean fixed engine palette indices, as before.)
#
#  Day marking per the obstruction rules (GOST / ICAO Annex 14):
#  alternating red-white bands, the END bands red - five bands here.
#
#  Run in the Scripting tab, edit, then export the object:
#      select twr -> File/Export/Wavefront OBJ, "Selection Only"
#          -> GAMES\TRAINER\res\Twr1.obj  (+ .mtl lands next to it)
#  Conventions: metres, +Z up, the origin is the tower's own axis.
# ============================================================================
import bpy
import math

COLORS = {
    "red":   (0.85, 0.08, 0.08),
    "white": (0.95, 0.95, 0.95),
    "glass": (0.25, 0.50, 0.85),
    "roof":  (0.22, 0.22, 0.25),
}

verts, faces = [], []

def V(x, y, z):
    verts.append((x, y, z)); return len(verts) - 1

def ring(r, z):
    out = []
    for k in range(6):
        a = k * math.pi / 3.0
        out.append(V(r * math.cos(a), r * math.sin(a), z))
    return out

# shaft: five 3.6 m bands, red at both ends
rings = [ring(3.0, i * 3.6) for i in range(6)]
for band in range(5):
    m = "red" if band % 2 == 0 else "white"
    lo, hi = rings[band], rings[band + 1]
    for k in range(6):
        j = (k + 1) % 6
        faces.append(((lo[k], lo[j], hi[j], hi[k]), m))

# the cab: a wider glass ring and a low roof cone
cab_lo = ring(4.5, 18.0)
cab_hi = ring(4.5, 20.5)
top = rings[5]
for k in range(6):
    j = (k + 1) % 6
    faces.append(((top[k], top[j], cab_lo[j], cab_lo[k]), "white"))
    faces.append(((cab_lo[k], cab_lo[j], cab_hi[j], cab_hi[k]), "glass"))
apex = V(0, 0, 22.0)
for k in range(6):
    j = (k + 1) % 6
    faces.append(((cab_hi[k], cab_hi[j], apex), "roof"))

mesh = bpy.data.meshes.new("twr")
mesh.from_pydata(verts, [], [f for f, _ in faces])
mesh.update()
obj = bpy.data.objects.new("twr", mesh)
bpy.context.collection.objects.link(obj)
slot = {}
for name, (r, g, b) in COLORS.items():
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.diffuse_color = (r, g, b, 1.0)
    obj.data.materials.append(mat)
    slot[name] = len(obj.data.materials) - 1
for poly, (_, mname) in zip(mesh.polygons, faces):
    poly.material_index = slot[mname]
print("twr: %d verts %d faces" % (len(verts), len(faces)))
