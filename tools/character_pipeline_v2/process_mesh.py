import sys
import os
import bpy

def clean_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def process_mesh(input_path, output_path, ratio=0.15, target_faces=2500):
    print(f"=== Blender Headless Mesh Processing ===")
    print(f"Input: {input_path}")
    print(f"Output: {output_path}")
    print(f"Target Ratio: {ratio}, Target Faces: {target_faces}")

    clean_scene()

    # Import
    ext = os.path.splitext(input_path)[1].lower()
    if ext in ['.glb', '.gltf']:
        bpy.ops.import_scene.gltf(filepath=input_path)
    elif ext == '.obj':
        bpy.ops.wm.obj_import(filepath=input_path)
    else:
        raise ValueError(f"Unsupported input format: {ext}")

    # Find the imported mesh object
    mesh_objs = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
    if not mesh_objs:
        raise RuntimeError("No mesh objects found in imported file!")

    # If multiple mesh parts, join them into a single primary character mesh
    bpy.ops.object.select_all(action='DESELECT')
    for obj in mesh_objs:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = mesh_objs[0]
    if len(mesh_objs) > 1:
        bpy.ops.object.join()

    main_obj = bpy.context.view_layer.objects.active
    initial_poly_count = len(main_obj.data.polygons)
    print(f"Initial Polygon Count: {initial_poly_count}")

    # Switch to edit mode to clean up loose geometry & duplicate vertices
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    # Remove loose vertices / stray floating faces
    bpy.ops.mesh.delete_loose()
    # Merge doubles within micro threshold
    bpy.ops.mesh.remove_doubles(threshold=0.0005)
    # Recalculate normals facing outwards
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')

    cleaned_poly_count = len(main_obj.data.polygons)
    print(f"Post-Cleanup Polygon Count: {cleaned_poly_count}")

    # Determine decimation ratio
    if target_faces > 0 and cleaned_poly_count > target_faces:
        effective_ratio = min(1.0, float(target_faces) / float(cleaned_poly_count))
    else:
        effective_ratio = 1.0 if target_faces > 0 else float(ratio)

    print(f"Applying Decimate Modifier (Ratio: {effective_ratio:.4f})...")
    dec_mod = main_obj.modifiers.new(name="LowPolyDecimate", type='DECIMATE')
    dec_mod.decimate_type = 'COLLAPSE'
    dec_mod.ratio = effective_ratio
    dec_mod.use_collapse_triangulate = True

    # Apply modifier, then enforce the budget (Blender ratios can round up).
    bpy.ops.object.modifier_apply(modifier=dec_mod.name)
    for _ in range(4):
        count = sum(len(p.vertices) - 2 for p in main_obj.data.polygons)
        if count <= target_faces or target_faces <= 0:
            break
        mod = main_obj.modifiers.new(name="BudgetCorrection", type='DECIMATE')
        mod.ratio = (target_faces / count) * 0.995
        mod.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    final_poly_count = len(main_obj.data.polygons)
    print(f"Final Decimated Face Count: {final_poly_count} triangles")

    # Set Flat Shading for crisp, modern low-poly aesthetic
    for poly in main_obj.data.polygons:
        poly.use_smooth = False

    # Ensure output directory exists
    out_dir = os.path.dirname(os.path.abspath(output_path))
    os.makedirs(out_dir, exist_ok=True)

    # Export to GLB
    print(f"Exporting game-ready GLB: {output_path}")
    bpy.ops.export_scene.gltf(
        filepath=output_path,
        export_format='GLB',
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_materials='EXPORT',
        export_attributes=True
    )

    # Also export companion OBJ if requested
    obj_out = os.path.splitext(output_path)[0] + ".obj"
    bpy.ops.wm.obj_export(
        filepath=obj_out,
        export_selected_objects=True,
        export_materials=True,
        export_triangulated_mesh=True
    )
    print(f"Exported OBJ: {obj_out}")
    print("=== Processing Completed Successfully ===")

if __name__ == '__main__':
    # Parse args passed after '--'
    argv = sys.argv
    if '--' in argv:
        args = argv[argv.index('--') + 1:]
    else:
        args = []

    if len(args) < 2:
        print("Usage: blender -b -P process_mesh.py -- <input_mesh> <output_mesh> [ratio=0.15] [target_faces=2500]")
        sys.exit(1)

    in_path = args[0]
    out_path = args[1]
    r = float(args[2]) if len(args) > 2 else 0.15
    tf = int(args[3]) if len(args) > 3 else 2500

    process_mesh(in_path, out_path, ratio=r, target_faces=tf)
