"""Blender material bake: cold grey-green C5 uniform variant, preserving skin/rig.
Only olive cloth texels are tinted; this is not a blanket character colour cast.
"""
import argparse,sys,json,hashlib
from pathlib import Path
import bpy
p=argparse.ArgumentParser();p.add_argument('--input',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);assert not a.output.exists()
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(a.input.resolve()))
mesh=next(o for o in bpy.context.scene.objects if o.type=='MESH');bpy.context.view_layer.objects.active=mesh
bpy.ops.object.select_all(action='DESELECT');mesh.select_set(True)
mat=mesh.data.materials[0];tree=mat.node_tree;nodes=tree.nodes;links=tree.links
bsdf=next(n for n in nodes if n.type=='BSDF_PRINCIPLED');out=next(n for n in nodes if n.type=='OUTPUT_MATERIAL')
source=bsdf.inputs['Base Color'].links[0].from_socket
sep=nodes.new('ShaderNodeSeparateColor');sep.mode='RGB';links.new(source,sep.inputs[0])
def math(op,a,b):
 n=nodes.new('ShaderNodeMath');n.operation=op
 for idx,val in enumerate([a,b]):
  if isinstance(val,(float,int)):n.inputs[idx].default_value=val
  else:links.new(val,n.inputs[idx])
 return n.outputs[0]
green=math('SUBTRACT',sep.outputs['Green'],math('MULTIPLY',sep.outputs['Red'],.86))
chroma=math('SUBTRACT',sep.outputs['Green'],sep.outputs['Blue'])
mask=math('MULTIPLY',math('GREATER_THAN',green,.009),math('GREATER_THAN',chroma,.006))
mix=nodes.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';links.new(mask,mix.inputs[0]);links.new(source,mix.inputs[1]);mix.inputs[2].default_value=(.68,.94,1.25,1)
emit=nodes.new('ShaderNodeEmission');links.new(mix.outputs[0],emit.inputs['Color']);links.new(emit.outputs[0],out.inputs['Surface'])
image=bpy.data.images.new('RangerColdUniform',width=2048,height=2048,alpha=False);image.colorspace_settings.name='sRGB'
tex=nodes.new('ShaderNodeTexImage');tex.image=image;nodes.active=tex
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=1;scene.render.bake.margin=12
bpy.ops.object.bake(type='EMIT');image.pack()
links.new(tex.outputs['Color'],bsdf.inputs['Base Color']);links.new(bsdf.outputs[0],out.inputs['Surface'])
bsdf.inputs['Roughness'].default_value=1;bsdf.inputs['Metallic'].default_value=0
bpy.ops.export_scene.gltf(filepath=str(a.output.resolve()),export_format='GLB',export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,export_skins=True)
a.output.with_suffix('.json').write_text(json.dumps(dict(input_sha256=hashlib.sha256(a.input.read_bytes()).hexdigest(),tint=[.68,.94,1.25],method='UV emission bake of olive-only material mask',visual_review='required'),indent=2))
