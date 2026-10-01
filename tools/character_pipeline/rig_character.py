"""Blender: calibrated chibi skeleton, skin weights and baked game animation clips.
This profile is specific to the approved Kha-nae surface, not a universal auto-rigger.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys
import bpy
import numpy as np
from mathutils import Vector, Quaternion


def smooth(lo, hi, x):
    t = max(0.0, min(1.0, (x-lo)/(hi-lo)))
    return t*t*(3-2*t)


def blender_point(p):
    return Vector((p[0], -p[2], p[1]))


def weights(x, y, z):
    # Anatomical regions prevent closest-bone weighting from pulling the hat
    # into a shoulder, joining short legs, or assigning the hip basket to a hand.
    # The generated basket is fused to clothing. Keep its core rigid and feather
    # the join, rather than abruptly pinning adjacent trouser vertices to the hip.
    bag = (smooth(.14, .18, x) * (1-smooth(.245, .275, x))
           * smooth(.205, .24, y) * (1-smooth(.39, .43, y)))
    head = smooth(.635, .705, y)
    arm = smooth(.13, .205, abs(x)) * smooth(.30, .365, y) * (1-head)
    crotch_support = 1-smooth(.22, .26, y)*(1-smooth(.005, .055, abs(x)))
    leg = (1-smooth(.27, .36, y)) * (1-head-arm) * crotch_support
    torso = max(0, 1-head-arm-leg)
    result = {'Head': head}
    chest = smooth(.44, .56, y)
    spine = smooth(.33, .45, y) * (1-chest)
    result.update(Chest=torso*chest, Spine=torso*spine, Hips=torso*(1-chest-spine))
    side = 'L' if x > 0 else 'R'
    hand = smooth(.303, .34, abs(x))
    forearm = smooth(.215, .268, abs(x)) * (1-hand)
    result.update({f'UpperArm.{side}': arm*(1-hand-forearm),
                   f'Forearm.{side}': arm*forearm, f'Hand.{side}': arm*hand})
    foot = 1-smooth(.045, .09, y)
    shin = (1-smooth(.155, .225, y))*(1-foot)
    result.update({f'Thigh.{side}': leg*(1-foot-shin), f'Shin.{side}': leg*shin,
                   f'Foot.{side}': leg*foot})
    result = {name: weight*(1-bag) for name, weight in result.items()}
    result['Bag'] = bag
    largest = sorted(((n, w) for n, w in result.items() if w > 1e-6), key=lambda p: -p[1])[:4]
    total = sum(w for _, w in largest)
    return {n: w/total for n, w in largest}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', type=Path, required=True)
    parser.add_argument('--profile', type=Path, required=True)
    parser.add_argument('--output-dir', type=Path, required=True)
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:])
    profile = json.loads(args.profile.read_text())
    source_hash = hashlib.sha256(args.input.read_bytes()).hexdigest()
    if source_hash not in profile['source_sha256']:
        raise ValueError('Mesh is not calibrated for this rig profile; review landmarks before adding its hash')
    out = args.output_dir
    if out.exists() and any(out.iterdir()):
        raise ValueError('Output folder must be empty')
    out.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(args.input.resolve()))
    objects = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    if len(objects) != 1:
        raise ValueError('Calibrated profile expects one mesh')
    mesh = objects[0]
    bpy.context.view_layer.objects.active = mesh
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    mesh.name = 'KhanaeMesh'
    original = [v.co.copy() for v in mesh.data.vertices]
    original_array = np.array(original)
    edges = np.array([tuple(edge.vertices) for edge in mesh.data.edges])
    edge_lengths = np.linalg.norm(original_array[edges[:, 0]] - original_array[edges[:, 1]], axis=1)
    long_edges = edge_lengths > .003
    armature = bpy.data.armatures.new('KhanaeSkeleton')
    rig = bpy.data.objects.new('KhanaeRig', armature)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    landmarks = profile['landmarks']

    def point(name, sign=1):
        p = list(landmarks[name]); p[0] *= sign
        return blender_point(p)

    def bone(name, head, tail, parent=None):
        b = armature.edit_bones.new(name)
        b.head, b.tail = head, tail
        if parent:
            b.parent = armature.edit_bones[parent]

    bone('Root', (0, 0, 0), (0, 0, .10))
    for name, start, end, parent in (
            ('Hips', 'hips', 'spine', 'Root'), ('Spine', 'spine', 'chest', 'Hips'),
            ('Chest', 'chest', 'neck', 'Spine'), ('Neck', 'neck', 'head', 'Chest'),
            ('Head', 'head', 'head_tip', 'Neck'), ('Bag', 'bag', 'bag_tip', 'Hips')):
        bone(name, point(start), point(end), parent)
    for side, sign in (('L', 1), ('R', -1)):
        for name, start, end, parent in (
                ('UpperArm', 'shoulder', 'elbow', 'Chest'), ('Forearm', 'elbow', 'wrist', f'UpperArm.{side}'),
                ('Hand', 'wrist', 'hand_tip', f'Forearm.{side}'), ('Thigh', 'hip', 'knee', 'Hips'),
                ('Shin', 'knee', 'ankle', f'Thigh.{side}'), ('Foot', 'ankle', 'toe', f'Shin.{side}')):
            bone(f'{name}.{side}', point(start, sign), point(end, sign), parent)
    bpy.ops.object.mode_set(mode='OBJECT')
    groups = {b.name: mesh.vertex_groups.new(name=b.name) for b in armature.bones}
    max_error = 0.0
    rigid_head_vertices = 0
    for v in mesh.data.vertices:
        x, z, y = v.co
        assigned = weights(x, y, -z)
        if abs(x) > .305 and .365 < y < .5:
            assert all(n.startswith(('Hand.', 'Forearm.', 'UpperArm.')) for n in assigned), 'Hand anchored to torso'
        max_error = max(max_error, abs(sum(assigned.values())-1))
        if y >= .705:
            assert assigned == {'Head': 1.0}, 'Head/hat must be rigid'
            rigid_head_vertices += 1
        for name, weight in assigned.items():
            groups[name].add([v.index], weight, 'REPLACE')
    modifier = mesh.modifiers.new('CharacterSkin', 'ARMATURE')
    modifier.object = rig
    mesh.parent = rig
    scene = bpy.context.scene
    scene.render.fps = 30
    rig.animation_data_create()
    clip_metrics = {}

    def rotate(name, axis, degrees):
        # Express a world-rest axis in this bone's local rest basis.
        basis = armature.bones[name].matrix_local.to_quaternion()
        q = Quaternion(blender_point(axis).normalized(), math.radians(degrees))
        rig.pose.bones[name].rotation_quaternion = basis.inverted() @ q @ basis

    for clip, duration in [('Idle', 2.4), ('Walk', .8), ('ToolUse', .7)]:
        frames = round(duration*30)
        action = bpy.data.actions.new(clip)
        rig.animation_data.action = action
        minimum, maximum = 1e9, -1e9
        max_displacement = 0.0
        max_edge_stretch = 0.0
        for frame in range(frames+1):
            scene.frame_set(frame)
            phase = 2*math.pi*frame/frames
            for b in rig.pose.bones:
                b.rotation_mode = 'QUATERNION'
                b.rotation_quaternion = Quaternion()
                b.location = (0, 0, 0)
            for side, sign in [('L', 1), ('R', -1)]:
                rotate(f'UpperArm.{side}', (0, 0, 1), -sign*22)
                if clip == 'Walk':
                    step = math.sin(phase)*sign
                    rotate(f'Thigh.{side}', (1, 0, 0), step*23)
                    bend = max(0, -step)*28
                    rotate(f'Shin.{side}', (1, 0, 0), bend)
                    rotate(f'Foot.{side}', (1, 0, 0), -step*23-bend)
                    base = rig.pose.bones[f'UpperArm.{side}'].rotation_quaternion.copy()
                    rotate(f'UpperArm.{side}', (1, 0, 0), -step*14)
                    rig.pose.bones[f'UpperArm.{side}'].rotation_quaternion @= base
                elif clip == 'ToolUse':
                    swing = math.sin(math.pi*frame/frames)**2
                    base = rig.pose.bones[f'UpperArm.{side}'].rotation_quaternion.copy()
                    rotate(f'UpperArm.{side}', (1, 0, 0), (-45 if side == 'R' else -15)*swing)
                    rig.pose.bones[f'UpperArm.{side}'].rotation_quaternion @= base
                    rotate(f'Forearm.{side}', (1, 0, 0), -18*swing)
            if clip == 'Idle':
                rotate('Chest', (1, 0, 0), math.sin(phase)*1.3)
                rotate('Head', (0, 1, 0), math.sin(phase)*2)
            elif clip == 'ToolUse':
                rotate('Spine', (1, 0, 0), -8*math.sin(math.pi*frame/frames)**2)
            # Ground the evaluated soles, instead of bouncing the entire body.
            bpy.context.view_layer.update()
            evaluated = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
            posed = np.array([tuple(v.co) for v in evaluated.data.vertices])
            lengths = np.linalg.norm(posed[edges[:, 0]] - posed[edges[:, 1]], axis=1)
            max_edge_stretch = max(max_edge_stretch, float(np.max(lengths[long_edges] / edge_lengths[long_edges])))
            floor = min(v.co.z for v in evaluated.data.vertices)
            rig.pose.bones['Root'].location = armature.bones['Root'].matrix_local.to_3x3().inverted() @ Vector((0, 0, -floor))
            bpy.context.view_layer.update()
            evaluated = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
            for index, v in enumerate(evaluated.data.vertices):
                if not all(math.isfinite(c) for c in v.co):
                    raise ValueError('Non-finite deformed vertex')
                minimum = min(minimum, v.co.z)
                maximum = max(maximum, v.co.z)
                max_displacement = max(max_displacement, (v.co-original[index]).length)
            for b in rig.pose.bones:
                b.keyframe_insert('rotation_quaternion', frame=frame, group=b.name)
                b.keyframe_insert('location', frame=frame, group=b.name)
        clip_metrics[clip] = {'seconds': duration, 'frames': frames+1,
                              'ground_min': minimum, 'height_max': maximum,
                              'max_vertex_displacement': max_displacement,
                              'max_edge_stretch_over_3mm': max_edge_stretch}
        if abs(minimum) > .001 or max_displacement > .4 or max_edge_stretch > 3.5:
            raise ValueError(f'{clip}: deformation/grounding outside calibrated limits')
        rig.animation_data.action = None
        track = rig.animation_data.nla_tracks.new()
        track.name = clip
        track.strips.new(clip, 0, action)
        track.mute = True
    # Export actions independently, not blended NLA strips.
    scene.frame_set(0)
    for b in rig.pose.bones:
        b.rotation_quaternion = Quaternion(); b.location = (0, 0, 0)
    bpy.ops.wm.save_as_mainfile(filepath=str(out / 'khanae_rig.blend'))
    bpy.ops.export_scene.gltf(filepath=str(out / 'khanae_rigged.glb'), export_format='GLB',
        export_animations=True, export_animation_mode='ACTIONS', export_skins=True,
        export_yup=True, export_force_sampling=True, export_anim_slide_to_zero=True)
    metrics = {'profile': profile, 'source_sha256': source_hash,
               'rig_script_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
               'bones': len(armature.bones),
               'vertices': len(mesh.data.vertices), 'weight_sum_max_error': max_error,
               'rigid_head_vertices': rigid_head_vertices, 'clips': clip_metrics,
               'rigged': True, 'visual_review': 'required', 'finger_rig': False}
    (out / 'rig_report.json').write_text(json.dumps(metrics, indent=2))
    print(json.dumps(metrics, indent=2))


if __name__ == '__main__':
    main()
