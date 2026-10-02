"""Blender CPU: derive a flat matte lower-poly candidate, then rebake source colour.

Do not reuse decimated UV interpolation: new UVs and selected-to-active emission
baking preserve painted detail independently of the new topology. Outputs are
review candidates, never automatic replacements.
"""
import argparse
import hashlib
import json
import sys
from pathlib import Path
import bpy
from mathutils import Vector


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', type=Path, required=True)
    parser.add_argument('--target-mesh', type=Path, help='Optional repaired geometry to receive source colour')
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--faces', type=int, default=12000)
    parser.add_argument('--texture-size', type=int, default=2048)
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
    if args.faces < 4 or args.texture_size < 256:
        parser.error('Invalid triangle/texture budget')
    if args.output_dir.exists() and any(args.output_dir.iterdir()):
        parser.error('Preserve candidates: output directory must be empty')
    args.output_dir.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(args.input.resolve()))
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    if len(meshes) != 1:
        raise ValueError('Expected one static character mesh')
    source = meshes[0]
    bpy.context.view_layer.objects.active = source
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    source.data.calc_loop_triangles()
    source_count = len(source.data.loop_triangles)
    if args.target_mesh:
        before = set(bpy.context.scene.objects)
        bpy.ops.import_scene.gltf(filepath=str(args.target_mesh.resolve()))
        imported = [o for o in bpy.context.scene.objects if o not in before and o.type == 'MESH']
        if len(imported) != 1:
            raise ValueError('Expected one repaired target mesh')
        target = imported[0]
        bpy.context.view_layer.objects.active = target
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    else:
        target = source.copy()
        target.data = source.data.copy()
        bpy.context.collection.objects.link(target)
    target.name = 'LowPolyCandidate'
    bpy.ops.object.select_all(action='DESELECT')
    target.select_set(True)
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.remove_doubles(threshold=0.00001)
    bpy.ops.mesh.delete_loose()
    bpy.ops.object.mode_set(mode='OBJECT')
    target.data.calc_loop_triangles()
    target_count = len(target.data.loop_triangles)
    if target_count > args.faces:
        mod = target.modifiers.new('GameTriangleBudget', 'DECIMATE')
        mod.ratio = args.faces / target_count * .995
        mod.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    for polygon in target.data.polygons:
        polygon.use_smooth = False
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=1.1519173, island_margin=.008)
    bpy.ops.object.mode_set(mode='OBJECT')
    image = bpy.data.images.new('RebakedBaseColour', width=args.texture_size,
                               height=args.texture_size, alpha=False)
    image.colorspace_settings.name = 'sRGB'
    mat = bpy.data.materials.new('MatteFacetedCharacter')
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Roughness'].default_value = 1.0
    bsdf.inputs['Metallic'].default_value = 0.0
    tex = mat.node_tree.nodes.new('ShaderNodeTexImage')
    tex.image = image
    mat.node_tree.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    mat.node_tree.nodes.active = tex
    target.data.materials.clear()
    target.data.materials.append(mat)
    for polygon in target.data.polygons:
        polygon.material_index = 0
    # Convert source albedo to emission so lighting/roughness never contaminate bake.
    for material in source.data.materials:
        tree = material.node_tree
        principled = next(n for n in tree.nodes if n.type == 'BSDF_PRINCIPLED')
        output = next(n for n in tree.nodes if n.type == 'OUTPUT_MATERIAL')
        emit = tree.nodes.new('ShaderNodeEmission')
        albedo = principled.inputs['Base Color']
        if albedo.links:
            tree.links.new(albedo.links[0].from_socket, emit.inputs['Color'])
        else:
            emit.inputs['Color'].default_value = albedo.default_value
        tree.links.new(emit.outputs[0], output.inputs['Surface'])
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.cycles.samples = 1
    scene.render.bake.use_selected_to_active = True
    scene.render.bake.cage_extrusion = .008
    scene.render.bake.max_ray_distance = .04
    scene.render.bake.margin = 12
    source.select_set(True)
    target.select_set(True)
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.bake(type='EMIT')
    image.filepath_raw = str(args.output_dir / 'basecolor.png')
    image.file_format = 'PNG'
    image.save()
    image.pack()
    bpy.ops.object.select_all(action='DESELECT')
    target.select_set(True)
    bpy.context.view_layer.objects.active = target
    # Restore exact original height and ground after decimation.
    lo = min(v.co.z for v in target.data.vertices)
    hi = max(v.co.z for v in target.data.vertices)
    source_lo = min(v.co.z for v in source.data.vertices)
    source_hi = max(v.co.z for v in source.data.vertices)
    factor = (source_hi - source_lo) / (hi - lo)
    for vertex in target.data.vertices:
        vertex.co.z = (vertex.co.z - lo) * factor + source_lo
    target.data.update()
    target.data.calc_loop_triangles()
    result = {'source_triangles': source_count,
              'target_input_triangles': target_count,
              'source_sha256': hashlib.sha256(args.input.read_bytes()).hexdigest(),
              'target_sha256': hashlib.sha256(args.target_mesh.read_bytes()).hexdigest() if args.target_mesh else None,
              'triangles': len(target.data.loop_triangles),
              'flat_shaded': all(not p.use_smooth for p in target.data.polygons),
              'texture_size': args.texture_size, 'rigged': False,
              'visual_review': 'required', 'bake_device': 'CPU'}
    if not 0 < result['triangles'] <= args.faces:
        raise ValueError('Triangle budget not satisfied')
    bpy.ops.export_scene.gltf(filepath=str(args.output_dir / 'candidate.glb'),
                              export_format='GLB', use_selection=True,
                              export_normals=True, export_materials='EXPORT')
    (args.output_dir / 'metrics.json').write_text(json.dumps(result, indent=2))
    print(json.dumps(result), flush=True)


if __name__ == '__main__':
    main()
