"""Deterministic, palette-matched low-poly source meshes; run in Blender.

Produces E1 a-c, E2 a-c, E3 a-d, S2 a, V1 a. Candidates still pass through
build_asset.py and visual review. All geometry is authored below its game budget.
Blender Z-up; export converts to Godot Y-up. No neural inference is required.
"""
import argparse
import json
import math
from pathlib import Path
import random
import sys
import bpy
from mathutils import Vector

TAU = math.tau


class Shape:
    def __init__(self, palette):
        self.palette = palette
        self.vertices, self.faces, self.colors = [], [], []

    def add(self, vertices, faces, colors):
        offset = len(self.vertices)
        self.vertices.extend(vertices)
        self.faces.extend(tuple(offset+i for i in face) for face in faces)
        self.colors.extend(colors)

    def tint(self, name, gain=1):
        base = self.palette[name] if isinstance(name, str) else name
        return tuple(min(1, max(0, c*gain)) for c in base)

    def lathe(self, center, profile, sides, color, phase=0, lean=(0, 0), ring_colors=None, aspect=(1, 1)):
        verts, faces, cols = [], [], []
        for radius, z in profile:
            for i in range(sides):
                a = TAU*i/sides+phase
                verts.append((center[0]+math.cos(a)*radius*aspect[0]+z*lean[0],
                              center[1]+math.sin(a)*radius*aspect[1]+z*lean[1], center[2]+z))
        for j in range(len(profile)-1):
            for i in range(sides):
                faces.append((j*sides+i,j*sides+(i+1)%sides,(j+1)*sides+(i+1)%sides,(j+1)*sides+i))
                cols.append(self.tint(ring_colors[j] if ring_colors else color, 1+(i%3-1)*.035))
        faces.extend([tuple(reversed(range(sides))),tuple((len(profile)-1)*sides+i for i in range(sides))])
        cols.extend([self.tint(color,.85),self.tint(color,1.06)])
        self.add(verts,faces,cols)

    def beam(self, start, end, radius, color, sides=4):
        start,end=Vector(start),Vector(end)
        direction=end-start
        rot=Vector((0,0,1)).rotation_difference(direction.normalized())
        verts=[]
        for z in [0,direction.length]:
            for i in range(sides):
                a=TAU*i/sides
                verts.append(tuple(start+rot@Vector((radius*math.cos(a),radius*math.sin(a),z))))
        faces=[(i,(i+1)%sides,(i+1)%sides+sides,i+sides) for i in range(sides)]
        faces.extend([tuple(reversed(range(sides))),tuple(range(sides,2*sides))])
        self.add(verts,faces,[self.tint(color)]*len(faces))

    def leaf(self, base, tip, width, color):
        base,tip=Vector(base),Vector(tip)
        axis=tip-base
        side=axis.cross(Vector((0,0,1))).normalized()*width
        mid=base+axis*.43
        # A solid four-face lance reads from both sides without alpha cutouts.
        verts=[tuple(base),tuple(tip),tuple(mid+side+Vector((0,0,width*.13))),tuple(mid-side)]
        self.add(verts,[(0,2,1),(0,1,3),(0,3,2),(1,2,3)],
                 [self.tint(color,g) for g in (1.06,.96,.90,1)])

    def ico(self, center, scale, color, angle=0):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1)
        obj=bpy.context.object
        c,s=math.cos(angle),math.sin(angle)
        verts=[]
        for v in obj.data.vertices:
            x,y,z=(v.co[k]*scale[k] for k in range(3))
            verts.append((center[0]+x*c-y*s,center[1]+x*s+y*c,center[2]+z))
        faces=[tuple(p.vertices) for p in obj.data.polygons]
        self.add(verts,faces,[self.tint(color,1+(i%3-1)*.025) for i in range(len(faces))])
        bpy.data.objects.remove(obj,do_unlink=True)

    def export(self, path):
        mesh=bpy.data.meshes.new(path.stem)
        mesh.from_pydata(self.vertices,[],self.faces);mesh.update()
        obj=bpy.data.objects.new(path.stem,mesh);bpy.context.collection.objects.link(obj)
        colors=mesh.color_attributes.new(name='Col',type='BYTE_COLOR',domain='CORNER')
        for face in mesh.polygons:
            face.use_smooth=False
            for loop in face.loop_indices: colors.data[loop].color_srgb=(*self.colors[face.index],1)
        mesh.color_attributes.active_color=colors
        mat=bpy.data.materials.new('SatelliteShadow_MattePalette');mat.use_nodes=True
        node=mat.node_tree.nodes.new('ShaderNodeVertexColor');node.layer_name='Col'
        bsdf=mat.node_tree.nodes.get('Principled BSDF')
        mat.node_tree.links.new(node.outputs['Color'],bsdf.inputs['Base Color'])
        bsdf.inputs['Roughness'].default_value=.88
        mesh.materials.append(mat)
        bpy.ops.object.select_all(action='DESELECT');obj.select_set(True)
        bpy.context.view_layer.objects.active=obj
        bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,
                                  export_normals=True,export_vertex_color='ACTIVE')
        triangles=sum(len(face.vertices)-2 for face in mesh.polygons)
        bpy.data.objects.remove(obj,do_unlink=True)
        return triangles


def pine(palette, variant):
    m=Shape(palette)
    rng=random.Random(140+variant)
    m.lathe((0,0,0),[(.15,0),(.11,1.6)],6,'bark')
    widths=[1.1,1.26,.95]
    lean=[(.02,0),(-.025,.015),(.05,-.02)][variant]
    for tier in range(4):
        z=.65+tier*.74
        radius=widths[variant]*(1-tier*.19)
        height=1.34 if tier<3 else 1.26
        color=['pine_dark','pine_mid','pine_mid','pine_light'][tier]
        phase=rng.uniform(0,.5)
        m.lathe((0,0,z),[(radius*.92,0),(radius,.14),(radius*.53,height*.53),(.018,height)],
                8,color,phase,lean,aspect=(1, .88+variant*.04))
    return m


def bamboo(palette, variant):
    m=Shape(palette)
    rng=random.Random(220+variant)
    for i in range(5):
        a=TAU*i/5+variant*.5
        center=(math.cos(a)*.19,math.sin(a)*.19,0)
        h=[3.15,2.80,2.48,2.96,2.35][(i+variant)%5]
        lean=(math.cos(a)*(.035+variant*.012),math.sin(a)*.045)
        r=.047 if i%2 else .060
        profile=[(r,0),(r,h*.32),(r*1.11,h*.333),(r*.92,h*.64),(r*1.03,h*.653),(r*.74,h)]
        culm='bamboo_dry' if (i+variant)%3==0 else 'bamboo'
        m.lathe(center,profile,5,culm,a,lean,
                [culm,'bamboo_wall',culm,'bamboo_wall',culm])
        for k in range(4):
            z=h*(.77+.065*k)
            branch=a+k*2.1+rng.uniform(-.25,.25)
            base=Vector((center[0]+z*lean[0],center[1]+z*lean[1],z))
            length=.48 if k<2 else .38
            tip=base+Vector((math.cos(branch)*length,math.sin(branch)*length,.14 if k%2 else -.12))
            m.leaf(base,tip,.105,'bamboo_leaf' if k%3 else 'brush_b')
    return m


def brush(palette, variant):
    m=Shape(palette)
    rng=random.Random(370+variant)
    palette_names=[['brush_a','brush_b','brush_dry'],['brush_dry','bamboo_dry','brush_b'],
                   ['brush_b','brush_a','bamboo_leaf'],['brush_dry','brush_b','thatch']][variant]
    m.beam((-.1,0,0),(-.15,.02,.45),.035,'bark',3)
    m.beam((.1,.1,0),(.18,.12,.52),.035,'bark',3)
    for i in range(5):
        a=TAU*i/5+variant*.7
        z=.30+rng.uniform(-.035,.16)
        center=(math.cos(a)*.24,math.sin(a)*.22,z)
        m.ico(center,(.29,.25,.25+(.07 if i==variant else 0)),palette_names[i%3],a)
    for i in range(5):
        a=TAU*i/5+.2
        base=(math.cos(a)*.28,math.sin(a)*.27,.38)
        tip=(math.cos(a)*.50,math.sin(a)*.49,.58+rng.uniform(-.12,.11))
        m.leaf(base,tip,.07,palette_names[(i+1)%3])
    return m


def barrels(palette):
    m=Shape(palette)
    for x,y,h,r in [(-.32,0,.9,.29),(.31,.12,.75,.255)]:
        profile=[(r*.9,0),(r,.05*h),(r,.23*h),(r*1.035,.25*h),(r,.28*h),
                 (r,.70*h),(r*1.035,.73*h),(r,.76*h),(r,.94*h),(r*.94,h)]
        bands=['barrel_blue','barrel_blue','indigo_cloth','indigo_cloth','barrel_blue',
               'indigo_cloth','indigo_cloth','barrel_blue','indigo_cloth']
        m.lathe((x,y,0),profile,8,'barrel_blue',ring_colors=bands)
        m.lathe((x+.09,y,h),[(.037,0),(.037,.022)],6,'charcoal')
    for x,y,h in [(.61,-.19,.60),(.68,.03,.68)]:
        m.lathe((x,y,0),[(.055,0),(.055,h*.50),(.063,h*.52),(.055,h*.54),(.052,h)],6,
                'bamboo_dry',ring_colors=['bamboo_dry','bamboo_wall','bamboo_wall','bamboo_dry'])
    return m


def drone(palette):
    m=Shape(palette)
    m.lathe((0,0,.16),[(.23,0),(.28,.035),(.26,.11),(.19,.14)],8,'white_plastic',math.pi/8,
            ring_colors=['steel','white_plastic','white_plastic'],aspect=(1,.79))
    for x,y in [(.48,.48),(-.48,.48),(.48,-.48),(-.48,-.48)]:
        m.beam((x*.26,y*.26,.235),(x,y,.275),.049,'steel')
        m.lathe((x,y,.265),[(.09,0),(.12,.055),(.105,.09)],8,'white_plastic',
                ring_colors=['charcoal','white_plastic'])
        # Visible dark hub below the separately animated rotor, never a baked propeller.
        m.lathe((x,y,.355),[(.035,0),(.035,.015)],6,'charcoal')
    m.beam((0,-.04,.17),(0,-.04,.09),.045,'steel')
    m.ico((0,-.085,.065),(.105,.09,.065),'charcoal')
    # Camera faces Godot +Z (Blender -Y).
    m.beam((0,-.12,.072),(0,-.18,.072),.044,'lens_red',6)
    m.beam((-.11,.01,.305),(.11,.01,.305),.018,'indigo_cloth')
    return m


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--out',type=Path,required=True)
    parser.add_argument('--palette',type=Path,required=True)
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
    if args.out.exists() and any(args.out.iterdir()):parser.error('Output must be empty')
    args.out.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    palette=json.loads(args.palette.read_text())['colors']
    entries=[]
    for asset,name,count,build in [('E1','pine',3,pine),('E2','bamboo',3,bamboo),('E3','brush',4,brush)]:
        for i in range(count):
            filename=f'{asset}_{name}_{chr(97+i)}.glb'
            tris=build(palette,i).export(args.out/filename)
            entries.append({'id':asset,'variant':chr(97+i),'file':filename,'source_triangles':tris,'profile':'standard'})
    for asset,name,build in [('S2','water_barrels',barrels),('V1','drone',drone)]:
        filename=f'{asset}_{name}_a.glb'
        tris=build(palette).export(args.out/filename)
        entries.append({'id':asset,'variant':'a','file':filename,'source_triangles':tris,'profile':'quality' if asset=='S2' else 'standard'})
    (args.out/'sources.json').write_text(json.dumps(entries,indent=2)+'\n')
    print('SOURCES',json.dumps(entries))


if __name__=='__main__':main()
