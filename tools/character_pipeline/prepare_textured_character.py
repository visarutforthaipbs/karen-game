"""Blender: keep a textured master and derive budgeted game meshes without stripping UVs.
blender -b --python-exit-code 1 -P prepare_textured_character.py -- --input raw.glb --output-dir out --name tapoh --height 1.15
"""
import argparse
import json
import math
import sys
from pathlib import Path
import bpy
import bmesh
from mathutils import Vector


def triangles(obj):
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


def export(obj, path):
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', use_selection=True,
                              export_apply=True, export_yup=True, export_materials='EXPORT',
                              export_normals=True, export_texcoords=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--input', required=True)
    parser.add_argument('--output-dir', required=True)
    parser.add_argument('--name', required=True)
    parser.add_argument('--height', type=float, required=True)
    parser.add_argument('--faces', nargs='+', type=int, default=[12000])
    parser.add_argument('--yaw', type=float, default=0, help='Rotation about game Y in degrees')
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
    if args.height <= 0 or any(n < 4 for n in args.faces):
        raise ValueError('Positive height and face budgets >= 4 required')
    out = Path(args.output_dir)
    out.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(Path(args.input).resolve()))
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    if not meshes:
        raise ValueError('No mesh in GLB')
    bpy.ops.object.select_all(action='DESELECT')
    for obj in meshes:
        world = obj.matrix_world.copy()
        obj.parent = None
        obj.matrix_world = world
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    master = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    master.rotation_euler.z = math.radians(args.yaw)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    coords = [v.co for v in master.data.vertices]
    lo = Vector([min(v[k] for v in coords) for k in range(3)])
    hi = Vector([max(v[k] for v in coords) for k in range(3)])
    if hi.z - lo.z <= 0:
        raise ValueError('Degenerate height')
    factor = args.height / (hi.z - lo.z)
    center = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    for v in master.data.vertices:
        v.co = (v.co - center) * factor
    master.data.update()
    if not master.data.uv_layers:
        raise ValueError('Textured master must have UVs')
    images = [im for im in bpy.data.images if im.size[0] > 0 and im.name != 'Render Result']
    if not images:
        raise ValueError('Textured master must have image textures')
    records = []
    master_path = out / f'{args.name}_master.glb'
    export(master, master_path)
    records.append({'file': master_path.name, 'triangles': triangles(master), 'kind': 'master'})
    for budget in sorted(set(args.faces), reverse=True):
        obj = master.copy()
        obj.data = master.data.copy()
        bpy.context.collection.objects.link(obj)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        # GLB UV charts duplicate vertices. Weld coincident geometry while retaining
        # UVs on face corners, otherwise decimation stalls on thousands of islands.
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.mesh.remove_doubles(threshold=0.00001)
        bpy.ops.mesh.delete_loose()
        bpy.ops.object.mode_set(mode='OBJECT')
        # Neural remeshing can create edges shared by 4+ faces. Split those
        # intersections so Blender can collapse each surface independently.
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        intersections = [e for e in bm.edges if len(e.link_faces) > 2]
        if intersections:
            bmesh.ops.split_edges(bm, edges=intersections)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        bm.to_mesh(obj.data)
        bm.free()
        obj.data.validate(verbose=True)
        obj.data.update(calc_edges=True)
        for _ in range(5):
            count = triangles(obj)
            if count <= budget:
                break
            mod = obj.modifiers.new('GameBudget', 'DECIMATE')
            mod.ratio = (budget / count) * 0.995
            mod.use_collapse_triangulate = True
            bpy.ops.object.modifier_apply(modifier=mod.name)
        obj.data.validate(verbose=True)
        obj.data.update(calc_edges=True)
        count = triangles(obj)
        if count > budget or count == 0:
            raise ValueError(f'Cannot satisfy face budget {budget}: got {count}')
        path = out / f'{args.name}_{budget}tris.glb'
        export(obj, path)
        records.append({'file': path.name, 'triangles': count, 'budget': budget, 'kind': 'game'})
        bpy.data.objects.remove(obj, do_unlink=True)
    images = [im for im in bpy.data.images if im.size[0] > 0 and im.name != 'Render Result']
    metrics = {'height_m': args.height, 'front_yaw_degrees': args.yaw,
               'textures': [{'name': im.name, 'size': list(im.size)} for im in images],
               'outputs': records, 'rigged': False}
    (out / f'{args.name}_textured_metrics.json').write_text(json.dumps(metrics, indent=2))
    print(json.dumps(metrics))


if __name__ == '__main__':
    main()
