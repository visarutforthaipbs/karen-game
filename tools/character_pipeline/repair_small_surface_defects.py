"""Blender: remove tiny disconnected debris and cap only measured pinholes.

Preserves source UVs. Large boundaries (hands, garment openings) are untouched.
New caps sample one adjacent face's UV/material instead of uninitialized UV zero.
Always review the output; this cannot detect semantic defects or self intersections.
"""
import argparse, json, sys
from pathlib import Path
import bpy, bmesh
from mathutils import Vector


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--input',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--max-hole-perimeter',type=float,default=.035)
    p.add_argument('--max-debris-area',type=float,default=.00002)
    a=p.parse_args(sys.argv[sys.argv.index('--')+1:])
    if a.output.exists(): p.error('Preserve previous candidates')
    if a.max_hole_perimeter<=0 or a.max_debris_area<0: p.error('Invalid limits')
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(a.input.resolve()))
    reports=[]
    for obj in [o for o in bpy.context.scene.objects if o.type=='MESH']:
        bm=bmesh.new();bm.from_mesh(obj.data)
        bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.000001)
        uv=bm.loops.layers.uv.active
        if uv is None: raise ValueError('Expected source UVs')
        remaining=set(bm.faces);debris=[]
        while remaining:
            seed=remaining.pop();component={seed};stack=[seed]
            while stack:
                f=stack.pop()
                for edge in f.edges:
                    for adjacent in edge.link_faces:
                        if adjacent in remaining:
                            remaining.remove(adjacent);component.add(adjacent);stack.append(adjacent)
            if len(component)<24 and sum(f.calc_area() for f in component)<a.max_debris_area:
                debris.extend(component)
        if len(debris)>.01*len(bm.faces):
            raise ValueError('Debris removal exceeds 1%; inspect manually')
        removed=len(debris)
        bmesh.ops.delete(bm,geom=debris,context='FACES')
        boundary={e for e in bm.edges if e.is_boundary};caps=[];skipped=[]
        while boundary:
            edge=boundary.pop();edges={edge};stack=[edge]
            while stack:
                e=stack.pop()
                for v in e.verts:
                    for n in v.link_edges:
                        if n in boundary:
                            boundary.remove(n);edges.add(n);stack.append(n)
            vertices={v for e in edges for v in e.verts}
            perimeter=sum(e.calc_length() for e in edges)
            closed=all(sum(e in edges for e in v.link_edges)==2 for v in vertices)
            if not closed or perimeter>a.max_hole_perimeter:
                skipped.append({'edges':len(edges),'perimeter':perimeter});continue
            adjacent=next(iter(edges)).link_faces[0]
            material=adjacent.material_index
            color_uv=sum((loop[uv].uv.copy() for loop in adjacent.loops),Vector((0,0)))/len(adjacent.loops)
            new=bmesh.ops.holes_fill(bm,edges=list(edges),sides=0)['faces']
            for face in new:
                face.material_index=material
                face.smooth=False
                for loop in face.loops: loop[uv].uv=color_uv
            bmesh.ops.triangulate(bm,faces=new)
            caps.append({'edges':len(edges),'perimeter':perimeter})
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        bm.to_mesh(obj.data);bm.free();obj.data.update()
        reports.append({'mesh':obj.name,'removed_debris_faces':removed,'capped_holes':caps,
                        'untouched_boundaries':skipped,'visual_review':'required'})
    bpy.ops.export_scene.gltf(filepath=str(a.output.resolve()),export_format='GLB')
    a.output.with_suffix('.repair.json').write_text(json.dumps(reports,indent=2))
    print(json.dumps(reports))


if __name__=='__main__': main()
