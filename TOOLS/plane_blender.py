# ============================================================================
#  plane_blender.py - builds the WIRE CITY trainer aircraft in Blender.
#
#  Run it from Blender's Scripting tab (Open -> Run Script). It creates a
#  quad-dominant low-poly aircraft (~40 verts) with materials named PAL20..
#  PAL23 - those names carry the VGA palette index through the pipeline:
#
#      Blender -> (edit by hand) -> File/Export/Wavefront OBJ
#              -> TOOLS/obj2asm.py -> .INC tables for the engine
#
#  Conventions (agreed with the precompiler):
#    * the nose points along +Y, +Z is up, +X is the right wing
#    * model in metres; obj2asm scales to engine units (default x4)
#    * quads preferred, triangles allowed (the engine folds them for free)
#    * every face must carry a material named PALnn (nn = palette index)
# ============================================================================
import bpy

# VGA palette preview colours (6-bit VGA -> 0..1 float), FIELD.COM indices
PALETTE = {
    "PAL20": (46, 46, 50),   # fuselage
    "PAL21": (30, 30, 33),   # canopy / shade
    "PAL22": (40, 40, 43),   # fin / sides
    "PAL23": (55, 55, 58),   # wings / tailplane
}

verts = []
faces = []          # (indices..., material_name)

def V(x, y, z):
    verts.append((x, y, z))
    return len(verts) - 1

def Q(a, b, c, d, m):
    faces.append(((a, b, c, d), m))

# ---- fuselage: four quad rings, nose to tail --------------------------------
def ring(y, w, zlo, zhi):
    return (V(-w, y, zlo), V(w, y, zlo), V(w, y, zhi), V(-w, y, zhi))

r0 = ring( 4.8, 0.25, -0.10, 0.30)   # nose tip
r1 = ring( 2.0, 0.70, -0.50, 0.90)   # cockpit section
r2 = ring(-0.5, 0.70, -0.50, 0.90)   # mid
r3 = ring(-4.2, 0.25,  0.00, 0.50)   # tail cone

for a, b in ((r0, r1), (r1, r2), (r2, r3)):
    Q(a[0], a[1], b[1], b[0], "PAL21")   # belly (shade)
    Q(a[1], a[2], b[2], b[1], "PAL22")   # right side
    Q(a[2], a[3], b[3], b[2], "PAL20")   # top
    Q(a[3], a[0], b[0], b[3], "PAL22")   # left side
Q(r0[0], r0[1], r0[2], r0[3], "PAL20")   # nose cap
Q(r3[3], r3[2], r3[1], r3[0], "PAL21")   # tail cap

# ---- wings: one flat quad each side ----------------------------------------
for s in (1, -1):
    a = V(s * 0.70,  1.90, 0.00)
    b = V(s * 5.50,  1.20, 0.05)
    c = V(s * 5.50,  0.20, 0.05)
    d = V(s * 0.70, -0.20, 0.00)
    Q(a, b, c, d, "PAL23")

# ---- tailplane --------------------------------------------------------------
for s in (1, -1):
    a = V(s * 0.25, -3.40, 0.40)
    b = V(s * 2.20, -3.80, 0.42)
    c = V(s * 2.20, -4.40, 0.42)
    d = V(s * 0.25, -4.40, 0.40)
    Q(a, b, c, d, "PAL23")

# ---- vertical fin -----------------------------------------------------------
a = V(0.0, -3.40, 0.50)
b = V(0.0, -3.90, 1.60)
c = V(0.0, -4.50, 1.80)
d = V(0.0, -4.40, 0.50)
Q(a, b, c, d, "PAL22")

# ---- canopy: a quad floating on the cockpit roof ----------------------------
a = V(-0.45,  1.60, 0.92)
b = V( 0.45,  1.60, 0.92)
c = V( 0.45,  0.10, 0.96)
d = V(-0.45,  0.10, 0.96)
Q(a, b, c, d, "PAL21")

# ---- build the Blender object ----------------------------------------------
mesh = bpy.data.meshes.new("trainer")
mesh.from_pydata(verts, [], [f for f, _ in faces])
mesh.update()
obj = bpy.data.objects.new("trainer", mesh)
bpy.context.collection.objects.link(obj)

mat_slot = {}
for name, (r, g, b6) in PALETTE.items():
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.diffuse_color = (r / 63.0, g / 63.0, b6 / 63.0, 1.0)
    obj.data.materials.append(mat)
    mat_slot[name] = len(obj.data.materials) - 1

for poly, (_, mname) in zip(mesh.polygons, faces):
    poly.material_index = mat_slot[mname]

bpy.context.view_layer.objects.active = obj
obj.select_set(True)
print("trainer: %d verts, %d faces" % (len(verts), len(faces)))
