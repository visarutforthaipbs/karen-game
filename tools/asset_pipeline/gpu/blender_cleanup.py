"""Satellite Shadow prop pipeline, stage 2 (runs inside headless Blender 4.5 on gpu01).

Raw high-resolution mesh -> normalized master -> budgeted static prop.
Preserve mode retains UVs and materials. Vertex mode requires vertex colours and
applies the legacy palette/flat-shading treatment. Small disconnected parts are
kept unless island removal is explicitly requested. Output is Y-up and grounded;
front orientation is controlled by the caller's yaw correction.

Usage:
  blender -b --factory-startup --python blender_cleanup.py -- \
      --in raw.glb --out final.glb --tris 300 --category hard --fit height --meters 0.9 \
      --palette palette.json --stats stats.json --views views_dir
"""
import argparse
import colorsys
import json
import math
import os
import sys

import bpy
import bmesh
import numpy as np
from mathutils import Matrix, Vector


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="inp", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--master", default="", help="Preserved detailed master before decimation")
    ap.add_argument("--material-mode", choices=["preserve", "vertex"], default="preserve")
    ap.add_argument("--tris", type=int, required=True)
    ap.add_argument("--category", choices=["organic", "hard"], default="organic")
    ap.add_argument("--fit", choices=["height", "width", "max"], default="height")
    ap.add_argument("--meters", type=float, required=True)
    ap.add_argument("--palette", default="")
    ap.add_argument("--palette-strength", type=float, default=0.35)
    ap.add_argument("--saturation", type=float, default=1.1)
    ap.add_argument("--input-colors", choices=["srgb", "linear"], default="srgb",
                    help="how the input mesh encodes COLOR_0: 'srgb' for trimesh/TripoSR and Godot exports "
                         "(sRGB numbers stored as-is), 'linear' for spec-correct files (Blender, most DCC / downloads)")
    ap.add_argument("--ref-image", default="", help="RGBA concept foreground; mesh colours are matched to it")
    ap.add_argument("--yaw", type=float, default=0.0, help="degrees about the up axis (45 = concept was a front-right 3/4 view)")
    ap.add_argument("--auto-square", action="store_true", help="fine-tune yaw (+-15 deg) to square the footprint (hard-surface)")
    ap.add_argument("--planar-angle", type=float, default=5.0, help="degrees, hard-surface only")
    ap.add_argument("--min-island", type=float, default=0.0, help="Opt-in loose-fragment removal; default keeps stilts, rungs and handles")
    ap.add_argument("--stats", default="")
    ap.add_argument("--views", default="", help="directory for turntable renders")
    args = ap.parse_args(argv)
    if args.tris < 4 or not math.isfinite(args.meters) or args.meters <= 0:
        ap.error('Positive size and triangle budget >= 4 required')
    return args


# ---------------------------------------------------------------------------
# Scene & import
# ---------------------------------------------------------------------------

def import_as_single_mesh(path: str) -> bpy.types.Object:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    ext = os.path.splitext(path)[1].lower()
    if ext in (".glb", ".gltf"):
        bpy.ops.import_scene.gltf(filepath=path)
    elif ext == ".obj":
        bpy.ops.wm.obj_import(filepath=path, up_axis="Y", forward_axis="NEGATIVE_Z")
    elif ext == ".fbx":
        bpy.ops.import_scene.fbx(filepath=path)
    else:
        raise SystemExit(f"unsupported input: {path}")

    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not meshes:
        raise SystemExit("input contains no mesh")
    # Keep world transforms before removing parents / helper objects
    for o in meshes:
        mw = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = mw
    for o in list(bpy.context.scene.objects):
        if o.type != "MESH":
            bpy.data.objects.remove(o, do_unlink=True)

    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return obj


def tri_count(obj) -> int:
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def apply_modifier(obj, mod) -> None:
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)


# ---------------------------------------------------------------------------
# Geometry
# ---------------------------------------------------------------------------

def remove_small_islands(obj, min_share: float) -> bpy.types.Object:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=1e-5)
    # Marching-cubes output can be wound inside-out; Godot would cull the outer faces
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.mesh.separate(type="LOOSE")
    bpy.ops.object.mode_set(mode="OBJECT")
    parts = [o for o in bpy.context.selected_objects if o.type == "MESH"]
    biggest = max(len(p.data.vertices) for p in parts)
    keep = []
    for p in parts:
        if len(p.data.vertices) < biggest * min_share:
            bpy.data.objects.remove(p, do_unlink=True)
        else:
            keep.append(p)
    bpy.ops.object.select_all(action="DESELECT")
    for p in keep:
        p.select_set(True)
    bpy.context.view_layer.objects.active = keep[0]
    if len(keep) > 1:
        bpy.ops.object.join()
    return bpy.context.view_layer.objects.active


def collapse_to(obj, target: int) -> None:
    for _ in range(4):
        t = tri_count(obj)
        if t <= target:
            return
        mod = obj.modifiers.new("collapse", "DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.use_collapse_triangulate = True
        mod.ratio = max(0.001, (target / t) * 0.98)
        apply_modifier(obj, mod)


def split_nonmanifold_junctions(obj) -> int:
    """Separate touching surface sheets that prevent Blender collapse.

    Keep every face and its loop UVs; do not delete small parts or fill openings.
    Run before decimation: a collapse attempt on these junctions can distort
    geometry, even if splitting them afterwards would satisfy the triangle cap.
    """
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    junctions = [e for e in bm.edges if len(e.link_faces) > 2]
    count = len(junctions)
    if junctions:
        bmesh.ops.split_edges(bm, edges=junctions)
        bm.to_mesh(obj.data)
    bm.free()
    return count


def planar_dissolve(obj, angle_deg: float) -> None:
    mod = obj.modifiers.new("planar", "DECIMATE")
    mod.decimate_type = "DISSOLVE"
    mod.angle_limit = math.radians(angle_deg)
    mod.delimit = {"NORMAL"}
    apply_modifier(obj, mod)
    tri = obj.modifiers.new("triangulate", "TRIANGULATE")
    apply_modifier(obj, tri)


# ---------------------------------------------------------------------------
# Colour: faceted per-face colours, saturation lift, palette nudge
# ---------------------------------------------------------------------------

def _srgb_to_lab(c):
    def lin(u):
        return u / 12.92 if u <= 0.04045 else ((u + 0.055) / 1.055) ** 2.4
    r, g, b = (lin(x) for x in c)
    x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883

    def f(t):
        return t ** (1 / 3) if t > 0.008856 else 7.787 * t + 16 / 116
    fx, fy, fz = f(x), f(y), f(z)
    return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))


def _lab_to_srgb(lab):
    L, a, b = lab
    fy = (L + 16) / 116
    fx = fy + a / 500
    fz = fy - b / 200

    def finv(t):
        return t ** 3 if t ** 3 > 0.008856 else (t - 16 / 116) / 7.787
    x, y, z = finv(fx) * 0.95047, finv(fy), finv(fz) * 1.08883
    r = 3.2406 * x - 1.5372 * y - 0.4986 * z
    g = -0.9689 * x + 1.8758 * y + 0.0415 * z
    bl = 0.0557 * x - 0.2040 * y + 1.0570 * z

    def enc(u):
        u = min(max(u, 0.0), 1.0)
        return 12.92 * u if u <= 0.0031308 else 1.055 * u ** (1 / 2.4) - 0.055
    return (enc(r), enc(g), enc(bl))


def reference_lab_stats(path: str):
    """Mean / std in Lab of the concept image's foreground pixels."""
    img = bpy.data.images.load(path)
    px = np.array(img.pixels[:]).reshape(-1, 4)
    fg = px[px[:, 3] > 0.5][:, :3]
    if len(fg) > 40000:
        fg = fg[np.random.default_rng(0).choice(len(fg), 40000, replace=False)]
    lab = np.array([_srgb_to_lab(c) for c in fg])
    return lab.mean(axis=0), lab.std(axis=0) + 1e-3


def match_reference(obj, face_rgb, ref_stats):
    """TripoSR colours come out washed: transfer the concept's Lab mean / contrast (area-weighted)."""
    areas = np.array([p.area for p in obj.data.polygons])
    w = areas / areas.sum()
    lab = np.array([_srgb_to_lab(c) for c in face_rgb])
    mu = (lab * w[:, None]).sum(axis=0)
    sd = np.sqrt(((lab - mu) ** 2 * w[:, None]).sum(axis=0)) + 1e-3
    ref_mu, ref_sd = ref_stats
    gain = np.clip(ref_sd / sd, 0.5, 3.0)
    out = (lab - mu) * gain + ref_mu
    return np.array([_lab_to_srgb(c) for c in out])


def rotate_yaw(obj, degrees: float) -> None:
    if abs(degrees) > 1e-3:
        obj.data.transform(Matrix.Rotation(math.radians(degrees), 4, "Z"))
        obj.data.update()


def auto_square(obj) -> float:
    """Small yaw that minimises the footprint's bounding-box area (squares walls / buildings to the grid)."""
    xy = np.array([v.co[:2] for v in obj.data.vertices])
    best, best_area = 0.0, None
    for deg in np.arange(-15.0, 15.5, 0.5):
        a = math.radians(deg)
        c, s = math.cos(a), math.sin(a)
        rx = xy[:, 0] * c - xy[:, 1] * s
        ry = xy[:, 0] * s + xy[:, 1] * c
        area = (rx.max() - rx.min()) * (ry.max() - ry.min())
        if best_area is None or area < best_area:
            best, best_area = float(deg), area
    rotate_yaw(obj, best)
    return best


def source_colors(obj, encoding: str = "srgb"):
    """Per-face sRGB colours averaged from whatever colour attribute the import produced.
    glTF says COLOR_0 is linear, but trimesh (TripoSR) and Godot write sRGB numbers into it;
    for those, the raw stored value already *is* sRGB and must not be converted again."""
    me = obj.data
    attr = me.color_attributes.active_color or (me.color_attributes[0] if len(me.color_attributes) else None)
    n_faces = len(me.polygons)
    if attr is None:
        return np.full((n_faces, 3), 0.6), False
    data = np.array([(d.color if encoding == "srgb" else d.color_srgb)[:3] for d in attr.data])
    faces = np.zeros((n_faces, 3))
    for i, poly in enumerate(me.polygons):
        if attr.domain == "CORNER":
            idx = list(poly.loop_indices)
        else:
            idx = list(poly.vertices)
        faces[i] = data[idx].mean(axis=0)
    return faces, True


def stylize_colors(face_rgb, palette, strength: float, saturation: float):
    pal_rgb = np.array(list(palette.values())) if palette else None
    pal_lab = np.array([_srgb_to_lab(c) for c in pal_rgb]) if palette else None
    names = list(palette.keys()) if palette else []
    usage = {}
    out = np.empty_like(face_rgb)
    for i, c in enumerate(face_rgb):
        h, s, v = colorsys.rgb_to_hsv(*np.clip(c, 0, 1))
        c2 = np.array(colorsys.hsv_to_rgb(h, min(1.0, s * saturation), v))
        if palette:
            lab = np.array(_srgb_to_lab(c2))
            k = int(np.argmin(((pal_lab - lab) ** 2).sum(axis=1)))
            usage[names[k]] = usage.get(names[k], 0) + 1
            c2 = c2 * (1.0 - strength) + pal_rgb[k] * strength
        out[i] = np.clip(c2, 0, 1)
    return out, usage


def write_face_colors(obj, face_rgb) -> None:
    me = obj.data
    for a in list(me.color_attributes):
        me.color_attributes.remove(a)
    attr = me.color_attributes.new(name="Col", type="BYTE_COLOR", domain="CORNER")
    for poly in me.polygons:
        c = face_rgb[poly.index]
        for li in poly.loop_indices:
            attr.data[li].color_srgb = (c[0], c[1], c[2], 1.0)
    me.color_attributes.active_color = attr
    me.color_attributes.render_color_index = me.color_attributes.find("Col")
    for poly in me.polygons:
        poly.use_smooth = False

    mat = bpy.data.materials.new("PropVertexColor")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    col = nodes.new("ShaderNodeVertexColor")
    col.layer_name = "Col"
    mat.node_tree.links.new(col.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.85
    me.materials.clear()
    me.materials.append(mat)
    for poly in me.polygons:
        poly.material_index = 0


# ---------------------------------------------------------------------------
# Size & placement (Blender is Z-up; glTF/Godot +Y up = Blender +Z, glTF +Z front = Blender -Y)
# ---------------------------------------------------------------------------

def normalize(obj, fit: str, meters: float):
    co = np.array([v.co[:] for v in obj.data.vertices])
    mn, mx = co.min(axis=0), co.max(axis=0)
    ext = mx - mn
    if fit == "height":
        cur = ext[2]
    elif fit == "width":
        cur = max(ext[0], ext[1])
    else:
        cur = ext.max()
    s = meters / max(cur, 1e-6)
    center = Vector(((mn[0] + mx[0]) * 0.5, (mn[1] + mx[1]) * 0.5, mn[2]))
    obj.data.transform(Matrix.Scale(s, 4) @ Matrix.Translation(-center))
    obj.data.update()
    co = np.array([v.co[:] for v in obj.data.vertices])
    mn, mx = co.min(axis=0), co.max(axis=0)
    # report in game axes: x, y (up), z (front)
    return {"x": float(mx[0] - mn[0]), "y": float(mx[2] - mn[2]), "z": float(mx[1] - mn[1])}


# ---------------------------------------------------------------------------
# Export & preview
# ---------------------------------------------------------------------------

def export_glb(obj, path: str) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    kw = dict(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
              export_yup=True, export_normals=True, export_texcoords=True, export_materials="EXPORT")
    try:
        bpy.ops.export_scene.gltf(**kw, export_vertex_color="ACTIVE")
    except TypeError:
        bpy.ops.export_scene.gltf(**kw, export_colors=True)


def render_views(obj, out_dir: str) -> None:
    os.makedirs(out_dir, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 32
    scene.cycles.use_denoising = True
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        prefs.compute_device_type = "CUDA"
        prefs.get_devices()
        for d in prefs.devices:
            d.use = True
        scene.cycles.device = "GPU"
    except Exception:
        scene.cycles.device = "CPU"
    scene.render.resolution_x = 384
    scene.render.resolution_y = 384
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.82, 0.82, 0.84, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
    scene.world = world
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(-35))
    scene.collection.objects.link(sun)

    co = np.array([v.co[:] for v in obj.data.vertices])
    mn, mx = co.min(axis=0), co.max(axis=0)
    size = float((mx - mn).max())
    target = Vector((0, 0, (mx[2] - mn[2]) * 0.5))
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = size * 1.35
    scene.collection.objects.link(cam)
    scene.camera = cam
    # front (+Z game = -Y Blender), three-quarter, right side, back
    for name, yaw in (("1_front", 0), ("2_three_quarter", 45), ("3_right", 90), ("4_back", 180)):
        a = math.radians(yaw)
        d = size * 3.0
        cam.location = target + Vector((math.sin(a) * d, -math.cos(a) * d, size * 0.6))
        cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(out_dir, name + ".png")
        bpy.ops.render.render(write_still=True)


def main() -> None:
    args = parse_args()
    palette = {}
    if args.palette:
        with open(args.palette) as f:
            palette = json.load(f)["colors"]

    obj = import_as_single_mesh(args.inp)
    raw_tris = tri_count(obj)
    obj = remove_small_islands(obj, args.min_island)
    rotate_yaw(obj, args.yaw)
    squared = auto_square(obj) if args.auto_square else 0.0

    if args.master:
        normalize(obj, args.fit, args.meters)
        export_glb(obj, args.master)

    split_junctions = split_nonmanifold_junctions(obj)
    if args.category == "hard" and args.material_mode == "vertex":
        collapse_to(obj, args.tris * 2)
        planar_dissolve(obj, args.planar_angle)
    collapse_to(obj, args.tris)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    degenerate = [f for f in bm.faces if f.calc_area() <= 1e-12]
    if degenerate:
        bmesh.ops.delete(bm, geom=degenerate, context='FACES')
    bm.to_mesh(obj.data); bm.free()
    if not 0 < tri_count(obj) <= args.tris:
        raise ValueError(f'Cannot satisfy strict triangle budget {args.tris}: {tri_count(obj)}')
    usage = {}
    had_color = bool(obj.data.color_attributes)
    if args.material_mode == 'vertex':
        face_rgb, had_color = source_colors(obj, args.input_colors)
        if not had_color:
            raise ValueError('Vertex route requires source vertex colours; textures must be preserved or explicitly baked first')
        if args.ref_image and os.path.exists(args.ref_image):
            face_rgb = match_reference(obj, face_rgb, reference_lab_stats(args.ref_image))
        face_rgb, usage = stylize_colors(face_rgb, palette, args.palette_strength, args.saturation)
        write_face_colors(obj, face_rgb)
    dims = normalize(obj, args.fit, args.meters)
    # All game props share the PRD's faceted low-poly shading, including textured ones.
    # Preserve the detailed master above, but do not inherit smooth/custom normals
    # from the neural mesh into the game export.
    if obj.data.has_custom_normals:
        bpy.context.view_layer.objects.active = obj
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    for poly in obj.data.polygons:
        poly.use_smooth = False
    export_glb(obj, args.out)

    stats = {
        "input": os.path.basename(args.inp),
        "raw_tris": raw_tris,
        "tris": tri_count(obj),
        "budget": args.tris,
        "category": args.category,
        "fit": args.fit,
        "meters": args.meters,
        "dims_m": dims,
        "had_vertex_colors": had_color,
        "material_mode": args.material_mode,
        "shading": "flat",
        "split_nonmanifold_junctions": split_junctions,
        "removed_zero_area_faces": len(degenerate),
        "colour_reference": bool(args.ref_image and os.path.exists(args.ref_image)),
        "yaw_deg": args.yaw + squared,
        "palette_usage": dict(sorted(usage.items(), key=lambda kv: -kv[1])[:8]),
    }
    if args.stats:
        with open(args.stats, "w") as f:
            json.dump(stats, f, indent=2)
    print("[blender_cleanup] " + json.dumps(stats))
    if args.views:
        render_views(obj, args.views)


if __name__ == "__main__":
    main()
