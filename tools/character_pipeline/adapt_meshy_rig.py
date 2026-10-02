"""Blender: adapt reviewed Meshy models to the existing Under Two Skies contract.

Preserves Meshy geometry/UVs, rebuilds game joints from Meshy landmarks,
calibrates skin weights, normalizes metres/grounding and bakes named clips. Does not install assets.
"""
import argparse
import hashlib
import json
import sys
from pathlib import Path
import bpy
import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from rig_character import bake_gameplay_clips, smooth

# These anatomical weights were reviewed against this exact cast, not arbitrary
# future Meshy generations. Calibrate a new mesh before changing its hash.
REVIEWED_SOURCES = {'khanae': 'e1dd51c2f85fcaaef75e13a399d07d2b4e052ccca4aa9b2c518c6e403e55a60b', 'tapoh': 'ca3dfc69a4e666aeac92e5d54799fd31e33b773df413c1e4026920251416497b', 'munaw': '6d64e8c140826d9dda94703760a7c470724644322b427e036775c3cac78b9cba', 'maelu': '19e0992b6d5c30113a91f52c6fb11fcc4b20c24469d410b2affb51f84ceef871', 'ranger': '70d3e034c9be2d04291b5d233639bbb8a40a9a31414ca1157fec6f734a45aec5'}

def main():
    p=argparse.ArgumentParser()
    p.add_argument('--input',type=Path,required=True)
    p.add_argument('--output-dir',type=Path,required=True)
    p.add_argument('--name',required=True)
    p.add_argument('--height',type=float,required=True)
    args=p.parse_args(sys.argv[sys.argv.index('--')+1:])
    source_hash=hashlib.sha256(args.input.read_bytes()).hexdigest()
    if REVIEWED_SOURCES.get(args.name)!=source_hash:
        raise ValueError('Source differs from the reviewed cast; recalibrate landmarks and weights first')
    out=args.output_dir
    if out.exists() and any(out.iterdir()): raise ValueError('Use a new output directory')
    out.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(args.input.resolve()))
    rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
    mesh=next(o for o in bpy.context.scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' for m in o.modifiers))
    rig.animation_data_clear()
    for action in list(bpy.data.actions): bpy.data.actions.remove(action)
    for b in rig.pose.bones:
        b.matrix_basis=Matrix.Identity(4)
    coords=np.array([tuple(mesh.matrix_world@v.co) for v in mesh.data.vertices])
    lo,hi=coords.min(axis=0),coords.max(axis=0)
    factor=args.height/(hi[2]-lo[2])
    origin=Vector(((lo[0]+hi[0])/2,(lo[1]+hi[1])/2,lo[2]))
    transform=Matrix.Scale(factor,4)@Matrix.Translation(-origin)
    mesh_world=mesh.matrix_world.copy();rig_world=rig.matrix_world.copy()
    mesh.parent=None;mesh.matrix_world=Matrix.Identity(4)
    mesh.data.transform(transform@mesh_world)
    rig.parent=None;rig.data.transform(transform@rig_world);rig.matrix_world=Matrix.Identity(4)
    for obj in list(bpy.context.scene.objects):
        if obj not in [mesh,rig]: bpy.data.objects.remove(obj,do_unlink=True)
    original_heads={b.name:b.head_local.copy() for b in rig.data.bones}
    mesh.vertex_groups.clear()
    bpy.context.view_layer.objects.active=rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    for b in list(rig.data.edit_bones): rig.data.edit_bones.remove(b)
    def bone(name,head,tail,parent=None):
        b=rig.data.edit_bones.new(name);b.head=head;b.tail=tail
        if (b.tail-b.head).length<.001: b.tail=b.head+Vector((0,0,.03))
        if parent:b.parent=rig.data.edit_bones[parent]
    def h(name):return original_heads[name]
    bone('Root',(0,0,0),(0,0,.1))
    bone('Hips',h('Hips'),h('Spine02'),'Root')
    bone('Spine',h('Spine02'),h('Spine01'),'Hips')
    bone('Chest',h('Spine01'),h('neck'),'Spine')
    bone('Neck',h('neck'),h('Head'),'Chest')
    bone('Head',h('Head'),h('Head')+Vector((0,0,args.height*.2)),'Neck')
    bone('Bag',h('Hips')+Vector((0,.06,0)),h('Hips')+Vector((0,.06,.1)),'Hips')
    for prefix,side in [('Left','L'),('Right','R')]:
        bone('UpperArm.'+side,h(prefix+'Arm'),h(prefix+'ForeArm'),'Chest')
        bone('Forearm.'+side,h(prefix+'ForeArm'),h(prefix+'Hand'),'UpperArm.'+side)
        axis=(h(prefix+'Hand')-h(prefix+'ForeArm')).normalized()
        bone('Hand.'+side,h(prefix+'Hand'),h(prefix+'Hand')+axis*.07,'Forearm.'+side)
        bone('Thigh.'+side,h(prefix+'UpLeg'),h(prefix+'Leg'),'Hips')
        bone('Shin.'+side,h(prefix+'Leg'),h(prefix+'Foot'),'Thigh.'+side)
        bone('Foot.'+side,h(prefix+'Foot'),h(prefix+'ToeBase'),'Shin.'+side)
    skirt=args.name in ['munaw','maelu']
    if skirt:
        top=h('Hips').z+.035
        # Mae-Lu's Meshy wrap reaches 0.18 m at the centre-back. Keep the
        # entire closed hem on its cloth carrier, below the old mesh's hem.
        hem=.14 if args.name=='maelu' else .17
        for side,depth in [('Front',-.065),('Back',.065)]:
            bone('Skirt.'+side,(0,depth,top),(0,depth,hem),'Hips')
    bpy.ops.object.mode_set(mode='OBJECT')
    groups={b.name:mesh.vertex_groups.new(name=b.name) for b in rig.data.bones}
    # Analytic, source-joint-calibrated weights avoid auto-skin leakage between
    # a chibi head, short arms and fused clothing. At most four carriers exist
    # in each region, so export pruning cannot create seams.
    def mix(a,b,t):
        return {k:a.get(k,0)*(1-t)+b.get(k,0)*t for k in a.keys()|b.keys()}
    def torso(z):
        levels=[(h('Hips').z,'Hips'),(h('Spine02').z,'Spine'),
                (h('Spine01').z,'Chest'),(h('neck').z-.025,'Neck'),(h('neck').z+.025,'Head')]
        if z<=levels[0][0]:return {'Hips':1}
        for (a,na),(b,nb) in zip(levels,levels[1:]):
            if z<=b:return mix({na:1},{nb:1},smooth(a,b,z))
        return {'Head':1}
    for v in mesh.data.vertices:
        x,depth,z=v.co;side='L' if x>=0 else 'R';prefix='Left' if x>=0 else 'Right'
        ax=abs(x);sh=h(prefix+'Arm');el=h(prefix+'ForeArm');wr=h(prefix+'Hand')
        row=torso(z)
        # Arms lie in the source T-pose. Their centreline is measured from the
        # actual Meshy skeleton; sleeves blend only into Chest, never pelvis.
        centre_z=sh.z+(wr.z-sh.z)*min(1,max(0,(ax-abs(sh.x))/(abs(wr.x)-abs(sh.x))))
        along=min(1,max(0,(ax-abs(sh.x))/(abs(wr.x)-abs(sh.x))))
        centre_depth=sh.y+(wr.y-sh.y)*along
        distance=((z-centre_z)**2+(depth-centre_depth)**2)**.5
        radius=.07+.06*smooth(abs(sh.x),abs(sh.x)+.08,ax)
        arm=smooth(abs(sh.x)-.065,abs(sh.x)+.07,ax)*(1-smooth(radius,radius+.075,distance))
        if args.name=='khanae':
            # His sleeve/torso junction is stressed by the cross-body rake grip.
            arm=smooth(abs(sh.x)-.10,abs(sh.x)+.14,ax)*(1-smooth(.14,.22,distance))
            arm*=smooth(sh.z-.20,sh.z-.10,z)
        arm=max(arm,smooth(abs(el.x)-.01,abs(el.x)+.04,ax)*(1-smooth(.20,.28,distance)))
        if arm>0:
            fore=smooth(abs(el.x)-.045,abs(el.x)+.045,ax)
            hand=smooth(abs(wr.x)-.028,abs(wr.x)+.035,ax)
            aw={'UpperArm.'+side:(1-fore)*(1-hand),'Forearm.'+side:fore*(1-hand),'Hand.'+side:hand}
            row=mix(row,aw,arm)
        # Keep all of the head/hat rigid, with a continuous neck blend.
        head=smooth(h('neck').z-.075,h('neck').z+.04,z)
        head*=max(smooth(h('neck').z+.01,h('neck').z+.07,z),
                  1-smooth(abs(sh.x)+.04,abs(sh.x)+.14,ax))
        row=mix(row,{'Head':1},head)
        hip=h(prefix+'UpLeg');knee=h(prefix+'Leg');ankle=h(prefix+'Foot')
        if z<h('Hips').z+.045:
            shin=1-smooth(knee.z-.045,knee.z+.065,z)
            foot=1-smooth(ankle.z-.01,ankle.z+.055,z)
            legs={'Thigh.'+side:(1-shin)*(1-foot),'Shin.'+side:shin*(1-foot),'Foot.'+side:foot}
            leg=(1-smooth(h('Hips').z-.045,h('Hips').z+.045,z))*smooth(0,.105,ax)
            row=mix(row,legs,leg)
        if skirt and z<top+.065:
            garment=smooth(hem-.08,hem+.035,z)
            waist=smooth(top-.035,top+.065,z)
            front=1.0 if args.name=='maelu' else 1-smooth(-.12,.12,depth)
            cloth=mix({'Skirt.Front':front,'Skirt.Back':1-front},torso(z),waist)
            # Below the garment the exposed shin/boot follows its own leg.
            foot=1-smooth(ankle.z-.01,ankle.z+.055,z)
            lower={'Shin.'+side:1-foot,'Foot.'+side:foot}
            row=mix(lower,cloth,garment)
        row={k:w for k,w in row.items() if w>1e-7}
        row=dict(sorted(row.items(),key=lambda pair:pair[1],reverse=True)[:4])
        total=sum(row.values())
        if total<=0:raise ValueError('Unweighted vertex')
        for name,value in row.items():groups[name].add([v.index],value/total,'REPLACE')
    mesh.parent=rig;mesh.matrix_parent_inverse=Matrix.Identity(4)
    for m in mesh.modifiers:
        if m.type=='ARMATURE':m.object=rig
    for poly in mesh.data.polygons:poly.use_smooth=False
    for mat in mesh.data.materials:
        if mat and mat.use_nodes:
            for node in mat.node_tree.nodes:
                if node.type=='BSDF_PRINCIPLED':
                    node.inputs['Roughness'].default_value=1
                    node.inputs['Metallic'].default_value=0
                    for name,value in [('Emission Color',(0,0,0,1)),('Emission Strength',0),
                                       ('Specular IOR Level',.2),('Specular Tint',(1,1,1,1))]:
                        socket=node.inputs.get(name)
                        if socket:
                            for link in list(socket.links): mat.node_tree.links.remove(link)
                            socket.default_value=value
    profile={'name':args.name,'height':args.height,'weight_mode':'meshy',
             'tpose_source':True,'arm_rest_degrees':68,'locked_carry':False,'max_vertex_displacement':.9}
    # T-pose-to-lowered-arm displacement is intentionally larger than A-pose
    # assets; the original edge-stretch (3.5) and grounding gates stay unchanged.
    if skirt:profile.update(skirt={'top':top,'hem':hem},weight_mode='v31')
    mesh.name=args.name.title()+'Mesh';rig.name=args.name.title()+'Rig'
    bpy.context.view_layer.update()
    mesh.data.calc_loop_triangles()
    bpy.ops.wm.save_as_mainfile(filepath=str(out/'adapted_rest.blend'))
    metrics=bake_gameplay_clips(mesh,rig,profile)
    bpy.context.scene.frame_set(0)
    for b in rig.pose.bones:b.rotation_quaternion=(1,0,0,0);b.location=(0,0,0)
    bpy.ops.wm.save_as_mainfile(filepath=str(out/(args.name+'_rig.blend')))
    bpy.ops.export_scene.gltf(filepath=str(out/(args.name+'_rigged.glb')),export_format='GLB',
        export_animations=True,export_animation_mode='ACTIONS',export_skins=True,
        export_yup=True,export_force_sampling=True,export_anim_slide_to_zero=True)
    report={'name':args.name,'source_sha256':hashlib.sha256(args.input.read_bytes()).hexdigest(),
            'height':args.height,'triangles':len(mesh.data.loop_triangles),'bones':len(rig.data.bones),
            'profile':profile,'clips':metrics,'review':'required','provider':'Meshy mesh and joint landmarks; calibrated local skin and gameplay clips'}
    (out/'rig_report.json').write_text(json.dumps(report,indent=2))
    print(json.dumps({k:report[k] for k in ['name','height','triangles','bones']}))

if __name__=='__main__':main()
