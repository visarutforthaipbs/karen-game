"""Blender: calibrated chibi skeleton, skin weights and baked game animation clips.
Profiles and anatomical envelopes are calibrated per approved character, not a universal auto-rigger.
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
    # The basket rim at X≈.21/Y≈.40 is clothing, not the inner arm.
    # Follow the sloping A-pose underside so two-hand work cannot drag the bag.
    reach = smooth(.20, .30, abs(x))
    arm_floor = smooth(.43-.13*reach, .54-.175*reach, y) if x > 0 else smooth(.30, .365, y)
    arm = smooth(.13, .205, abs(x)) * arm_floor * (1-head)
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


def companion_weights(x, y, z, profile):
    """Reviewed anatomical envelopes in metres; equipment stays on its carrier.

    Mu-naw is authored holding a fused wand with both hands. His arm chains are
    weighted, but locked in carry pose by the clips/runtime to preserve that grip.
    """
    youth = profile['weight_mode'] == 'munaw'
    head = smooth(.70, .755, y) if youth else smooth(.54, .66, y)
    # Elder beard projects forward below the neck; preserve its attachment.
    if not youth and z > .07:
        head = max(head, smooth(.50, .56, y) * smooth(.065, .105, z))
    leg = (1-smooth(.245 if youth else .23, .325 if youth else .30, y)) * (1-head)
    # Keep the joined tunic/fringe centre on pelvis rather than splitting it.
    leg *= 1-smooth(.17 if youth else .20, .24 if youth else .29, y)*(1-smooth(.015, .055, abs(x)))
    if youth:
        # The hanging hose reaches below the tunic hem, beside the right thigh.
        # Keep all projecting equipment on the chest with a feathered attachment.
        equipment = max(smooth(.10, .15, -z), smooth(.09, .14, z) * smooth(.12, .18, abs(x))) * smooth(.24, .29, y)
        leg *= 1-equipment
    else:
        equipment = 0.0
    arm = smooth(.125, .195, abs(x)) * smooth(.30, .365, y) * (1-head-leg)
    if youth:
        # Tank at the back and wand/hose in front move rigidly with the chest.
        arm *= (1-smooth(.09, .14, -z)) * (1-smooth(.11, .16, z))
    torso = max(0, 1-head-leg-arm)
    chest = max(smooth(.34, .45, y), equipment)
    side = 'L' if x > 0 else 'R'
    hand = smooth(.23, .265, abs(x))
    if not youth and x < -.23 and .30 < y < .49:
        hand = 1.0  # existing clearing blade follows the gripping hand
    forearm = smooth(.18, .23, abs(x))*(1-hand)
    foot = 1-smooth(.04, .085, y)
    shin = (1-smooth(.125, .19, y))*(1-foot)
    result = {'Head':head, 'Chest':torso*chest, 'Hips':torso*(1-chest),
              f'UpperArm.{side}':arm*(1-hand-forearm), f'Forearm.{side}':arm*forearm,
              f'Hand.{side}':arm*hand, f'Thigh.{side}':leg*(1-foot-shin),
              f'Shin.{side}':leg*shin, f'Foot.{side}':leg*foot}
    top = sorted(((n,w) for n,w in result.items() if w>1e-6), key=lambda p:-p[1])[:4]
    total = sum(w for _,w in top)
    return {n:w/total for n,w in top}


def v31_weights(x, y, z, profile, skirt_surface=False):
    """Mesh-specific anatomical envelopes; skirts never split onto opposing legs."""
    lm, env = profile['landmarks'], profile['envelopes']
    head = smooth(*env['head'], y)
    # Headwrap tails / tied hair follow the head behind the neckline.
    if z < -.075 and profile['name'] != 'ranger':
        head = max(head, smooth(lm['neck'][1]-.10, lm['neck'][1]-.02, y)
                   * smooth(.075, .12, -z))
    ax = abs(x)
    arm = smooth(*env['arm_x'], ax) * (1-head)
    # The underside of the sleeve slopes toward the wrist. Hip bags and
    # broad skirt hems below this line must not acquire hand influences.
    t = max(0, min(1, (ax-lm['shoulder'][0])/(lm['wrist'][0]-lm['shoulder'][0])))
    floor = lm['shoulder'][1]*(1-t)+lm['wrist'][1]*t-.085
    arm *= smooth(floor-.08, floor+.04, y)
    arm = max(arm, smooth(lm['shoulder'][0]+.035,lm['shoulder'][0]+.075,ax)
              * smooth(lm['knee'][1]+.04,lm['knee'][1]+.09,y)*(1-head))
    waist_width = .125 if profile['name'] == 'munaw' else .17
    body_edge = waist_width + (.11-waist_width)*smooth(lm['spine'][1]-.015,lm['chest'][1],y)
    arm *= smooth(body_edge,body_edge+.04,ax)
    arm *= smooth(lm['wrist'][1]-.15,lm['wrist'][1]-.075,y)
    arm = max(arm, smooth(.15,.20,ax)*smooth(.06,.095,z)*(1-head)
              *smooth(lm['wrist'][1]-.12,lm['wrist'][1]-.06,y))
    inner, outer = profile.get('arm_core_x', (.115,.175) if profile['name'] == 'munaw' else (.18,.235))
    arm = max(arm,smooth(inner,outer,ax)*smooth(.285,.335,y)
              *smooth(-.09,-.04,z)*(1-head))
    if profile['name'] == 'ranger':
        # The large lowered hands extend below the hip line, outside the trousers.
        body_edge = float(np.interp(y,[.3,.38,.445,.50,.55,.62,.69],[.245,.22,.19,.17,.14,.11,.12]))
        arm = smooth(body_edge,body_edge+.045+.045*smooth(.55,.62,y),ax)*smooth(.22,.26,y)*(1-head)
    skirt = profile.get('skirt')
    cloth = 0.0
    if skirt and y < skirt['top']+.02:
        if skirt['material'] is not None:
            cloth = float(skirt_surface)
        else:
            cloth = smooth(skirt['hem']-.11, skirt['hem']+.07, y)
            width = .20 - .035*smooth(skirt['hem'],skirt['top'],y)
            cloth *= 1-smooth(width,width+.045,ax)
        cloth *= 1-head
        arm *= 1-cloth
    leg = (1-smooth(*env['leg_y'], y)) * (1-head-arm-cloth)
    leg *= 1-smooth(lm['knee'][1]-.07,lm['knee'][1]+.015,y)*(1-smooth(.015,.075,ax))
    torso = max(0, 1-head-arm-leg-cloth)
    chest = smooth(lm['spine'][1]-.025, lm['chest'][1], y)
    spine = smooth(lm['hips'][1], lm['spine'][1], y)*(1-chest)
    result = dict(Head=head, Chest=torso*chest, Spine=torso*spine, Hips=torso*(1-chest-spine))
    if arm > 0 or profile['name'] == 'ranger':
        # Shoulder blend uses one torso carrier, keeping the transition within
        # four influences instead of discarding changing fifth/sixth weights.
        carrier = smooth(lm['hips'][1],lm['chest'][1]-.08,y)
        result['Chest'] = torso*carrier
        result['Spine'] = 0
        result['Hips'] = torso*(1-carrier)
    side = 'L' if x > 0 else 'R'
    # Project down the sloped arm, rather than using X alone for almost
    # vertical forearms and fingertips.
    shoulder = np.array(lm['shoulder'][:2]); wrist = np.array(lm['wrist'][:2])
    direction = wrist-shoulder
    progress = float(np.dot(np.array([ax,y])-shoulder,direction)/np.dot(direction,direction))
    hand = smooth(.89,1.08,progress)
    forearm = smooth(.36,.65,progress)*(1-hand)
    foot = 1-smooth(*profile.get('foot_weight_y',[lm['ankle'][1]-.015,lm['ankle'][1]+.045]),y)
    shin = (1-smooth(lm['knee'][1]-.035,lm['knee'][1]+.045,y))*(1-foot)
    result.update({f'UpperArm.{side}':arm*(1-hand-forearm),f'Forearm.{side}':arm*forearm,
                   f'Hand.{side}':arm*hand,f'Thigh.{side}':leg*(1-foot-shin),
                   f'Shin.{side}':leg*shin,f'Foot.{side}':leg*foot})
    if cloth:
        influence = (1-smooth(skirt['hem'],skirt['top'],y))*cloth
        front = smooth(-.22,.22,z)
        if profile['name'] == 'maelu':
            # The short wrap skirt has a single pelvis-carried cloth control.
            # A leg/hip plus opposing front/back controls would require five
            # influences and produce discontinuities when exported to four.
            front = 1.0
            result[f'Shin.{side}'] += result.pop(f'Thigh.{side}',0)
        result['Skirt.Front'] = influence*front
        result['Skirt.Back'] = influence*(1-front)
        result['Hips'] += (cloth-influence)*(1-chest-spine)
        result['Spine'] += (cloth-influence)*spine
        result['Chest'] += (cloth-influence)*chest
    if profile['name'] == 'khanae':
        bag = (smooth(.12,.18,x)*(1-smooth(.235,.275,x))*smooth(.22,.29,y)
               *(1-smooth(.415,.485,y))*(1-smooth(-.02,.05,z)))
        result = {n:w*(1-bag) for n,w in result.items()}
        result['Bag'] = bag
    return {n:w for n,w in result.items() if w > 1e-6}


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
    character_name = profile['name']
    mesh.name = character_name.title() + 'Mesh'
    removed_bridge_faces = 0
    original = [v.co.copy() for v in mesh.data.vertices]
    original_array = np.array(original)
    edges = np.array([tuple(edge.vertices) for edge in mesh.data.edges])
    edge_lengths = np.linalg.norm(original_array[edges[:, 0]] - original_array[edges[:, 1]], axis=1)
    long_edges = edge_lengths > .003
    armature = bpy.data.armatures.new(character_name.title() + 'Skeleton')
    rig = bpy.data.objects.new(character_name.title() + 'Rig', armature)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    landmarks = profile['landmarks']

    def point(name, sign=1):
        p = list(landmarks[name]); p[0] = p[0] * sign + profile.get("body_center_x", 0.0)
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
    if profile.get('skirt'):
        top, hem = profile['skirt']['top'], profile['skirt']['hem']
        for side, z in [('Front', .07), ('Back', -.07)]:
            bone('Skirt.'+side, blender_point((0,top,z)), blender_point((0,hem,z)), 'Hips')
    bpy.ops.object.mode_set(mode='OBJECT')
    groups = {b.name: mesh.vertex_groups.new(name=b.name) for b in armature.bones}
    names = list(groups)
    weights_array = np.zeros((len(mesh.data.vertices), len(names)))
    skirt_vertices = set()
    if profile.get('skirt', {}).get('material') is not None:
        for polygon in mesh.data.polygons:
            if polygon.material_index == profile['skirt']['material']:
                skirt_vertices.update(polygon.vertices)
    for v in mesh.data.vertices:
        x, z, y = v.co
        if profile.get('weight_mode') == 'v31':
            assigned = v31_weights(x-profile.get('body_center_x',0),y,-z,profile,v.index in skirt_vertices)
        else:
            assigned = companion_weights(x-profile.get("body_center_x", 0.0), y, -z, profile) if profile.get("weight_mode") else weights(x, y, -z)
        for name, weight in assigned.items():
            weights_array[v.index, names.index(name)] = weight
    # Smooth the fused left sleeve/basket attachment over surface neighbours.
    # This adjusts skin only: geometry, UVs and the rigid basket core stay intact.
    iterations = profile.get('sleeve_weight_smoothing', 0)
    if iterations:
        coords = original_array
        mask = np.array([smooth(.35,.40,v[2])*(1-smooth(.52,.58,v[2]))
                         *smooth(.13,.17,v[0])*(1-smooth(.285,.305,v[0])) for v in coords])
        first, second = edges[:,0], edges[:,1]
        degree = np.bincount(np.concatenate([first,second]), minlength=len(coords)) + 2
        for _ in range(iterations):
            total = weights_array * 2
            np.add.at(total, first, weights_array[second])
            np.add.at(total, second, weights_array[first])
            averaged = total / degree[:,None]
            weights_array = weights_array*(1-mask[:,None]) + averaged*mask[:,None]
    if profile.get('weight_smoothing'):
        # UV seams duplicate vertices. Average coincident positions for skinning
        # only, preserving every original facet, UV coordinate and triangle.
        _, welded = np.unique(np.round(original_array,5),axis=0,return_inverse=True)
        first,second = welded[edges[:,0]],welded[edges[:,1]]
        count = int(welded.max())+1
        degree = np.bincount(np.concatenate([first,second]),minlength=count)+2
        copies = np.bincount(welded,minlength=count)
        mask = np.array([(1-smooth(profile['envelopes']['head'][0],profile['head_rigid_y'],v[2]))
                         *smooth(profile['landmarks']['hips'][1]+.015,profile['landmarks']['hips'][1]+.09,v[2])
                         *smooth(.06,.14,abs(v[0])) for v in original_array])
        for _ in range(profile['weight_smoothing']):
            merged = np.zeros((count,len(names)))
            np.add.at(merged,welded,weights_array)
            merged /= copies[:,None]
            total = merged*2
            np.add.at(total,first,merged[second]); np.add.at(total,second,merged[first])
            weights_array = weights_array*(1-mask[:,None])+ (total/degree[:,None])[welded]*mask[:,None]
    if character_name == 'ranger':
        # Diffusion may spread neck/pelvis weights into the shoulders. Keep
        # those regions anatomical before the four-influence export prune.
        for i, vertex in enumerate(original_array):
            y = vertex[2]
            weights_array[i, names.index('Head')] = smooth(*profile['envelopes']['head'],y)
            weights_array[i, names.index('Hips')] *= 1-smooth(.48,.55,y)
            head_index = names.index('Head')
            head_weight = weights_array[i,head_index]
            weights_array[i,head_index] = 0
            body_total = float(weights_array[i].sum())
            if body_total > 1e-9:
                weights_array[i] *= (1-head_weight)/body_total
            else:
                weights_array[i,names.index('Chest')] = 1-head_weight
            weights_array[i,head_index] = head_weight
    max_error = 0.0
    rigid_head_vertices = 0
    for v in mesh.data.vertices:
        x, z, y = v.co
        row = weights_array[v.index]
        keep = np.argsort(row)[-4:]
        total = sum(row[i] for i in keep)
        assigned = {names[i]:float(row[i]/total) for i in keep if row[i] > 1e-6}
        # Normalize again after pruning negligible influences.
        total = sum(assigned.values())
        assigned = {name:weight/total for name,weight in assigned.items()}
        if not profile.get("weight_mode") and abs(x) > .305 and .365 < y < .5:
            assert all(n.startswith(('Hand.', 'Forearm.', 'UpperArm.')) for n in assigned), 'Hand anchored to torso'
        max_error = max(max_error, abs(sum(assigned.values())-1))
        if y >= profile.get('head_rigid_y', .755 if profile.get("weight_mode") == "munaw" else .705):
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

    clips = [('Idle', 2.4), ('Walk', .8), ('Run', .65), ('ToolUse', .7)]
    if character_name == 'maelu' and profile.get('weight_mode') == 'v31':
        clips += [('Talk',2.4),('Granary',2.0)]
    if character_name == 'ranger':
        clips = [('Idle',2.4),('Walk',.8),('Run',.65),('Scan',3.2),('Photograph',2.0),('Point',1.6),('RadioTalk',2.4),('Escort',.95)]
    for clip, duration in clips:
        frames = round(duration*30)
        action = bpy.data.actions.new(clip)
        rig.animation_data.action = action
        minimum, maximum = 1e9, -1e9
        max_displacement = 0.0
        max_edge_stretch = 0.0
        worst_edge = None
        for frame in range(frames+1):
            scene.frame_set(frame)
            phase = 2*math.pi*frame/frames
            for b in rig.pose.bones:
                b.rotation_mode = 'QUATERNION'
                b.rotation_quaternion = Quaternion()
                b.location = (0, 0, 0)
            for side, sign in [('L', 1), ('R', -1)]:
                rotate(f'UpperArm.{side}', (0, 0, 1), -sign*profile.get("arm_rest_degrees", 22))
                if clip in ('Walk', 'Run', 'Escort'):
                    step = math.sin(phase)*sign
                    rotate(f'Thigh.{side}', (1, 0, 0), step*(30 if clip == 'Run' else 23))
                    bend = max(0, -step)*(35 if clip == 'Run' else 28)
                    rotate(f'Shin.{side}', (1, 0, 0), bend)
                    rotate(f'Foot.{side}', (1, 0, 0), -step*(30 if clip == 'Run' else 23)-bend)
                    base = rig.pose.bones[f'UpperArm.{side}'].rotation_quaternion.copy()
                    rotate(f'UpperArm.{side}', (1, 0, 0), 0 if profile.get('locked_carry') else -step*10)
                    rig.pose.bones[f'UpperArm.{side}'].rotation_quaternion @= base
                elif clip == 'ToolUse':
                    swing = math.sin(math.pi*frame/frames)**2
                    base = rig.pose.bones[f'UpperArm.{side}'].rotation_quaternion.copy()
                    rotate(f'UpperArm.{side}', (1, 0, 0), 0 if profile.get('locked_carry') else (-30 if side == 'R' else -10)*swing)
                    rig.pose.bones[f'UpperArm.{side}'].rotation_quaternion @= base
                    rotate(f'Forearm.{side}', (1, 0, 0), 0 if profile.get('locked_carry') else -12*swing)
            if clip == 'Idle':
                rotate('Chest', (1, 0, 0), math.sin(phase)*1.3)
                rotate('Head', (0, 1, 0), math.sin(phase)*2)
            elif clip == 'ToolUse':
                rotate('Spine', (1, 0, 0), -8*math.sin(math.pi*frame/frames)**2)
            elif clip in ('Talk','Granary'):
                gesture = math.sin(math.pi*frame/frames)**2
                rotate('Head',(1,0,0),3*math.sin(phase))
                rotate('Forearm.R',(1,0,0),-25*gesture)
                rotate('UpperArm.R',(1,0,0),-18*gesture)
                if clip == 'Granary':
                    rotate('Forearm.L',(1,0,0),-20*gesture)
                    rotate('UpperArm.L',(1,0,0),-15*gesture)
            if character_name == 'ranger':
                gesture = math.sin(math.pi*frame/frames)**2
                if clip == 'Scan':
                    rotate('Head',(0,1,0),24*math.sin(phase))
                    rotate('Chest',(0,1,0),7*math.sin(phase))
                elif clip == 'Photograph':
                    for side in ('R',):
                        rotate('UpperArm.'+side,(1,0,0),-35*gesture)
                        rotate('Forearm.'+side,(1,0,0),-55*gesture)
                elif clip == 'Point':
                    rotate('UpperArm.R',(1,0,0),-48*gesture)
                    rotate('Forearm.R',(1,0,0),-12*gesture)
                    rotate('Head',(0,1,0),-10*gesture)
                elif clip == 'RadioTalk':
                    # The microphone is on the left shoulder; distinguish this
                    # from the right-handed tablet/ordering gestures.
                    rotate('UpperArm.L',(1,0,0),-28*gesture)
                    rotate('Forearm.L',(1,0,0),-60*gesture)
                    rotate('Head',(0,1,0),16*gesture)
                    base = rig.pose.bones['Head'].rotation_quaternion.copy()
                    rotate('Head',(1,0,0),8*gesture)
                    rig.pose.bones['Head'].rotation_quaternion @= base
                elif clip == 'Escort':
                    rotate('UpperArm.R',(1,0,0),-32)
                    rotate('Forearm.R',(1,0,0),-12)
            if profile.get('skirt') and character_name != 'maelu' and clip in ('Walk','Run'):
                # Broad front/back panels open around the stepping legs without
                # stretching a centre seam between left and right thighs.
                swing = abs(math.sin(phase))*(30 if clip == 'Run' else 23)
                rotate('Skirt.Front',(1,0,0),-swing*.9)
                rotate('Skirt.Back',(1,0,0),swing*.9)
            # Ground the evaluated soles, instead of bouncing the entire body.
            bpy.context.view_layer.update()
            evaluated = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
            posed = np.array([tuple(v.co) for v in evaluated.data.vertices])
            lengths = np.linalg.norm(posed[edges[:, 0]] - posed[edges[:, 1]], axis=1)
            ratios = lengths[long_edges] / edge_lengths[long_edges]
            if float(np.max(ratios)) > max_edge_stretch:
                max_edge_stretch = float(np.max(ratios))
                pair = edges[long_edges][int(np.argmax(ratios))]
                worst_edge = {'original': original_array[pair].tolist(), 'posed':posed[pair].tolist(),
                              'groups':[{mesh.vertex_groups[g.group].name:g.weight for g in mesh.data.vertices[int(i)].groups} for i in pair]}
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
                              'max_edge_stretch_over_3mm': max_edge_stretch, 'worst_edge': worst_edge}
        if abs(minimum) > .001 or max_displacement > profile.get('max_vertex_displacement', .4) or max_edge_stretch > 3.5:
            raise ValueError(f'{clip}: deformation/grounding outside calibrated limits: {clip_metrics[clip]}')
        rig.animation_data.action = None
        track = rig.animation_data.nla_tracks.new()
        track.name = clip
        track.strips.new(clip, 0, action)
        track.mute = True
    # Export actions independently, not blended NLA strips.
    scene.frame_set(0)
    for b in rig.pose.bones:
        b.rotation_quaternion = Quaternion(); b.location = (0, 0, 0)
    bpy.ops.wm.save_as_mainfile(filepath=str(out / f'{character_name}_rig.blend'))
    bpy.ops.export_scene.gltf(filepath=str(out / f'{character_name}_rigged.glb'), export_format='GLB',
        export_animations=True, export_animation_mode='ACTIONS', export_skins=True,
        export_yup=True, export_force_sampling=True, export_anim_slide_to_zero=True)
    metrics = {'profile': profile, 'source_sha256': source_hash,
               'rig_script_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
               'bones': len(armature.bones),
               'vertices': len(mesh.data.vertices), 'weight_sum_max_error': max_error,
               'rigid_head_vertices': rigid_head_vertices, 'clips': clip_metrics,
               'removed_bridge_faces': removed_bridge_faces, 'rigged': True, 'visual_review': 'required', 'finger_rig': False}
    (out / 'rig_report.json').write_text(json.dumps(metrics, indent=2))
    print(json.dumps(metrics, indent=2))


if __name__ == '__main__':
    main()
