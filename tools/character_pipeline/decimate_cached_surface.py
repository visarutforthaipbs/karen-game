"""Blender: smooth and reduce a closed .meshbin surface, preserving cache coordinates."""
import bpy, numpy as np, struct, sys
from pathlib import Path
args=sys.argv[sys.argv.index('--')+1:]
source, destination=map(Path,args[:2])
if destination.exists():
    raise ValueError('Destination already exists; preserve previous candidates')
with source.open('rb') as f:
    magic,nv,nf,flags,_=struct.unpack('<8sQQII',f.read(32))
    assert magic==b'TRLMESH1'
    v=np.fromfile(f,dtype='<f4',count=nv*3).reshape(-1,3)
    faces=np.fromfile(f,dtype='<i4',count=nf*3).reshape(-1,3)
if not np.isfinite(v).all() or faces.min() < 0 or faces.max() >= nv:
    raise ValueError('Invalid source mesh coordinates or indices')
bpy.ops.wm.read_factory_settings(use_empty=True)
mesh=bpy.data.meshes.new('Source')
mesh.vertices.add(nv); mesh.vertices.foreach_set('co',v.ravel())
mesh.loops.add(nf*3); mesh.loops.foreach_set('vertex_index',faces.ravel())
mesh.polygons.add(nf); mesh.polygons.foreach_set('loop_start',np.arange(nf,dtype=np.int32)*3)
mesh.polygons.foreach_set('loop_total',np.full(nf,3,dtype=np.int32))
mesh.update(); mesh.validate()
obj=bpy.data.objects.new('Surface',mesh); bpy.context.collection.objects.link(obj)
obj.select_set(True); bpy.context.view_layer.objects.active=obj
print('Raw vertices/faces',nv,nf,flush=True)
mod=obj.modifiers.new('RemoveSurfaceNoise','SMOOTH'); mod.factor=0.35; mod.iterations=2
bpy.ops.object.modifier_apply(modifier=mod.name)
obj.data.calc_loop_triangles()
mod=obj.modifiers.new('SurfaceBudget','DECIMATE'); mod.ratio=150000/len(obj.data.loop_triangles)
mod.use_collapse_triangulate=True
bpy.ops.object.modifier_apply(modifier=mod.name)
obj.data.calc_loop_triangles()
v=np.asarray([tuple(vertex.co) for vertex in obj.data.vertices], dtype='<f4').ravel()
f=np.asarray([tuple(triangle.vertices) for triangle in obj.data.loop_triangles], dtype='<i4').ravel()
assert np.isfinite(v).all(), 'Non-finite surface coordinates'
assert f.min() >= 0 and f.max() < len(v)//3, 'Invalid surface indices'
with destination.open('xb') as output:
    output.write(struct.pack('<8sQQII',b'TRLMESH1',len(v)//3,len(f)//3,0,0)); output.write(v.tobytes()); output.write(f.tobytes())
print('Output',len(v)//3,len(f)//3,flush=True)
