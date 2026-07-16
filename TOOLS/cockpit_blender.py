# ============================================================================
#  cockpit_blender.py - the 3-D cockpit you SIT IN (first-person view).
#
#  TWO objects: "ckpt" - the rigid tub (panel, consoles, stick, throttle,
#  sills, windshield arch) and "cnpy" - the canopy frame, a separate
#  object because the game swings it open on its rear hinge (key O).
#
#  THE ORIGIN IS THE PILOT'S EYE. Model in metres around it: the panel
#  ~0.65 m ahead, sills at your elbows. The game bakes it at 1 m = 120
#  units so the near plane never cuts it. Real colours via MTL.
#
#  Export each object ("Selection Only"): ckpt -> res\Ckpt1.obj,
#  cnpy -> res\Cnpy1.obj, then MAKE TRAINER.
# ============================================================================
import bpy

COLORS = {'panel': (0.16, 0.16, 0.18), 'console': (0.22, 0.22, 0.24), 'dark': (0.07, 0.07, 0.08), 'screen': (0.15, 0.3, 0.5), 'redk': (0.7, 0.1, 0.1), 'frame': (0.38, 0.39, 0.42)}

def build(name, verts, faces, cols):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], [f for f, _ in faces])
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    slot = {}
    for mname, (r, g, b) in cols.items():
        mat = bpy.data.materials.get(mname) or bpy.data.materials.new(mname)
        mat.diffuse_color = (r, g, b, 1.0)
        obj.data.materials.append(mat)
        slot[mname] = len(obj.data.materials) - 1
    for poly, (_, mname) in zip(mesh.polygons, faces):
        poly.material_index = slot[mname]
    return obj

def cockpit_geo():
    v, f = [], []
    def V(x, y, z):
        v.append((x, y, z)); return len(v) - 1
    def Q(a, b, c, d, m):
        f.append(((a, b, c, d), m))
    def quad(p1, p2, p3, p4, m):
        Q(V(*p1), V(*p2), V(*p3), V(*p4), m)
    # main panel
    quad((-0.42,0.65,-0.45),(0.42,0.65,-0.45),(0.42,0.65,-0.12),(-0.42,0.65,-0.12),"panel")
    # instruments (proud of the panel)
    quad((-0.09,0.64,-0.34),(0.09,0.64,-0.34),(0.09,0.64,-0.16),(-0.09,0.64,-0.16),"screen")
    quad((-0.38,0.64,-0.32),(-0.22,0.64,-0.32),(-0.22,0.64,-0.16),(-0.38,0.64,-0.16),"dark")
    quad((0.22,0.64,-0.32),(0.38,0.64,-0.32),(0.38,0.64,-0.16),(0.22,0.64,-0.16),"dark")
    # glareshield
    quad((-0.45,0.55,-0.08),(0.45,0.55,-0.08),(0.45,0.75,-0.14),(-0.45,0.75,-0.14),"dark")
    # side consoles
    quad((-0.55,-0.05,-0.34),(-0.28,-0.05,-0.34),(-0.28,0.55,-0.34),(-0.55,0.55,-0.34),"console")
    quad((0.28,-0.05,-0.34),(0.55,-0.05,-0.34),(0.55,0.55,-0.34),(0.28,0.55,-0.34),"console")
    # throttle on the left console
    quad((-0.43,0.10,-0.34),(-0.41,0.10,-0.34),(-0.41,0.16,-0.10),(-0.43,0.16,-0.10),"dark")
    quad((-0.46,0.10,-0.10),(-0.38,0.10,-0.10),(-0.38,0.19,-0.04),(-0.46,0.19,-0.04),"redk")
    # the stick: two crossed blades and a grip
    quad((-0.015,0.28,-0.55),(0.015,0.28,-0.55),(0.015,0.28,-0.16),(-0.015,0.28,-0.16),"dark")
    quad((0,0.262,-0.55),(0,0.298,-0.55),(0,0.298,-0.16),(0,0.262,-0.16),"dark")
    quad((-0.03,0.28,-0.16),(0.03,0.28,-0.16),(0.03,0.28,-0.06),(-0.03,0.28,-0.06),"redk")
    # canopy sills
    quad((-0.53,-0.30,0.02),(-0.47,-0.30,0.02),(-0.47,0.50,0.02),(-0.53,0.50,0.02),"frame")
    quad((0.47,-0.30,0.02),(0.53,-0.30,0.02),(0.53,0.50,0.02),(0.47,0.50,0.02),"frame")
    # windshield arch
    quad((-0.47,0.50,0.02),(-0.41,0.54,0.02),(-0.14,0.70,0.40),(-0.18,0.66,0.42),"frame")
    quad((0.41,0.54,0.02),(0.47,0.50,0.02),(0.18,0.66,0.42),(0.14,0.70,0.40),"frame")
    quad((-0.16,0.68,0.41),(0.16,0.68,0.41),(0.13,0.71,0.44),(-0.13,0.71,0.44),"frame")
    return v, f

def canopy_geo():
    v, f = [], []
    def V(x, y, z):
        v.append((x, y, z)); return len(v) - 1
    def quad(p1, p2, p3, p4, m):
        f.append(((V(*p1), V(*p2), V(*p3), V(*p4)), m))
    # rear-hinged bubble frame; the hinge line is X through (y=-0.35,z=0.05)
    quad((-0.50,0.48,0.04),(-0.44,0.50,0.06),(-0.16,0.20,0.54),(-0.20,0.16,0.50),"frame")
    quad((-0.20,0.16,0.50),(-0.16,0.20,0.54),(-0.28,-0.30,0.20),(-0.34,-0.32,0.14),"frame")
    quad((0.44,0.50,0.06),(0.50,0.48,0.04),(0.20,0.16,0.50),(0.16,0.20,0.54),"frame")
    quad((0.16,0.20,0.54),(0.20,0.16,0.50),(0.34,-0.32,0.14),(0.28,-0.30,0.20),"frame")
    quad((-0.03,0.46,0.30),(0.03,0.46,0.30),(0.03,-0.28,0.34),(-0.03,-0.28,0.34),"frame")
    quad((-0.30,-0.31,0.16),(0.30,-0.31,0.16),(0.16,-0.26,0.44),(-0.16,-0.26,0.44),"frame")
    return v, f


cv, cf = cockpit_geo()
build("ckpt", cv, cf, COLORS)
nv, nf = canopy_geo()
build("cnpy", nv, nf, {"frame": COLORS["frame"]})
print("ckpt: %d verts %d faces / cnpy: %d verts %d faces"
      % (len(cv), len(cf), len(nv), len(nf)))
