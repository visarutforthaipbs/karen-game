"""Asset polish sources. Blender Z-up; front -Y exports to Godot +Z.
Run beside build_cohesive_set.py: blender -b -P this.py -- OUTPUT PALETTE
All meshes still require build_asset.py, four-angle/game review and installation.
"""
import sys, json, math, random
from pathlib import Path
import bpy
from mathutils import Vector
sys.path.insert(0, str(Path(__file__).parent))
from build_cohesive_set import Shape


def box(m, c, s, color):
    x,y,z=c; a,b,d=[v/2 for v in s]
    vs=[(x+sx*a,y+sy*b,z+sz*d) for sz in [-1,1] for sy in [-1,1] for sx in [-1,1]]
    m.add(vs,[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)],
          [m.tint(color,g) for g in [.88,1.04,.96,1,.93,1.02]])


def crown(m, c, radius, height, sides, color, seed):
    # Jagged lower skirt and off-centre crown; 3 rings + one tip, no degenerate apex.
    rng=random.Random(seed); vs=[]
    for j,(r,z) in enumerate([(radius*.75,0),(radius,.16*height),(radius*.43,.56*height)]):
        for i in range(sides):
            a=math.tau*i/sides; f=rng.uniform(.82,1.13)
            vs.append((c[0]+math.cos(a)*r*f+j*.025,c[1]+math.sin(a)*r*f*.85,c[2]+z+rng.uniform(-.06,.06)*height))
    vs.append((c[0]+.12*radius,c[1]-.07*radius,c[2]+height))
    faces=[tuple(reversed(range(sides)))]; cols=[m.tint(color,.83)]
    for j in range(2):
        for i in range(sides):
            faces.append((j*sides+i,j*sides+(i+1)%sides,(j+1)*sides+(i+1)%sides,(j+1)*sides+i))
            cols.append(m.tint(color,.94+.045*(i%3)))
    for i in range(sides):
        faces.append((2*sides+i,2*sides+(i+1)%sides,3*sides)); cols.append(m.tint(color,1.01+.035*(i%3)))
    m.add(vs,faces,cols)


def pine(p,v):
    m=Shape(p); lean=[(.06,0),(-.04,.06),(.12,-.04)][v]
    m.lathe((0,0,0),[(.17,0),(.10,2.8),(.04,3.55)],6,'bark',lean=lean)
    tiers=[[(0,0,.65,1.07,1.8),(.10,.03,1.58,.83,1.7),(.18,0,2.60,.61,1.6)],
           [(-.20,.05,.62,1.22,1.7),(.15,.13,1.55,.96,1.6),(-.10,.15,2.63,.60,1.57)],
           [(.17,-.04,.92,.85,1.65),(.05,-.12,1.80,.75,1.55),(.35,-.14,2.65,.50,1.55)]][v]
    for k,(x,y,z,r,h) in enumerate(tiers):
        crown(m,(x,y,z),r,h,8,['pine_dark','pine_mid','pine_light'][k],600+v*30+k)
    # Exposed low branch and separate foliage mass create a real silhouette break.
    side=-1 if v==1 else 1
    m.beam((lean[0],0,1.05),(side*.90,-.16,1.34),.055,'bark',4)
    crown(m,(side*.80,-.16,1.26),.42,.65,5,'pine_dark',701+v)
    return m


def bamboo(p,v):
    m=Shape(p); rng=random.Random(800+v)
    for i in range(5):
        a=math.tau*i/5+v*.6; x=math.cos(a)*.19; y=math.sin(a)*.19
        h=[3.08,2.71,2.40,2.95,2.20][(i+v)%5]
        lean=(math.cos(a)*(.045+v*.014),math.sin(a)*.06); r=.048 if i%2 else .061
        col='bamboo_dry' if (i+v)%3==0 else 'bamboo'
        m.lathe((x,y,0),[(r,0),(r,h*.40),(r*1.1,h*.415),(r*.76,h)],5,col,a,lean,
                [col,'bamboo_wall',col])
        # Eleven broad lances per culm, spread into an umbrella instead of tiny sparse tips.
        for j in range(11):
            ang=a+j*2.40+v*.31; z=h*(.65+.031*j)
            base=Vector((x+z*lean[0],y+z*lean[1],z))
            length=rng.uniform(.60,.85)*(1 if j<7 else .82)
            tip=base+Vector((math.cos(ang)*length,math.sin(ang)*length, .15 if j%2 else -.14))
            m.leaf(base,tip,.19 if j<7 else .145,'bamboo_leaf' if j%3 else 'brush_b')
    return m


def brush(p,v):
    m=Shape(p)
    cols=[['brush_a','brush_b','brush_dry'],['brush_dry','bamboo_dry','brush_b'],
          ['brush_b','brush_a','bamboo_leaf'],['brush_dry','brush_b','thatch']][v]
    shapes=[[(0,0,.42,.34,.26,.32),(-.29,.04,.27,.26,.31,.20),(.31,.1,.33,.29,.24,.24),(.09,-.26,.27,.28,.23,.19)],
            [(-.14,0,.45,.22,.26,.36),(.17,.12,.40,.24,.20,.29),(.33,-.03,.22,.27,.26,.17),(-.28,-.18,.22,.24,.22,.17)],
            [(-.32,.06,.29,.31,.23,.21),(.04,0,.38,.38,.28,.28),(.38,.02,.28,.26,.24,.20),(.02,-.25,.25,.28,.24,.21)],
            [(-.21,-.04,.48,.23,.23,.33),(.17,.04,.30,.27,.32,.21),(.37,.14,.17,.20,.21,.14),(-.24,.24,.23,.24,.22,.16)]][v]
    for i,(x,y,z,sx,sy,sz) in enumerate(shapes): m.ico((x,y,z),(sx,sy,sz),cols[i%3],v*.5+i)
    for side in [-1,1]:m.beam((side*.07,0,0),(side*.19,.04,.48),.030,'bark',3)
    for j in range(10):
        a=math.tau*j/10+v*.42; base=(math.cos(a)*.20,math.sin(a)*.18,.27)
        m.leaf(base,(math.cos(a)*(.44+.05*(j%3)),math.sin(a)*.43,.47+.07*((j+v)%4)),.065,cols[j%3])
    return m


def log(p,v):
    m=Shape(p); sides=7; vs=[]
    rings=[(-.75,0,.17,.14),(-.22,.035 if v else -.02,.20,.19),(.38,-.045 if v else .04,.17,.15),(.75,-.025,.19,.12)]
    for j,(x,y,z,r) in enumerate(rings):
        for i in range(sides):
            a=math.tau*i/sides+.2*v
            vs.append((x+(0.018*(i%3-1) if j in [0,3] else 0),y+math.cos(a)*r,z+math.sin(a)*r))
    faces=[];cols=[]
    for j in range(3):
        for i in range(sides):
            faces.append((j*sides+i,(j+1)*sides+i,(j+1)*sides+(i+1)%sides,j*sides+(i+1)%sides))
            cols.append(m.tint('bark',.85+.065*(i%4)))
    faces.extend([tuple(range(sides)),tuple(reversed(range(3*sides,4*sides)))])
    cols.extend([m.tint('bamboo_wall',.9),m.tint('bamboo_wall')]);m.add(vs,faces,cols)
    for j in range(2):
        x=-.25+j*.56; sy=(-1 if (j+v)%2 else 1)
        m.beam((x,0,.21),(x+.08,sy*(.19+.08*v),.39),.054,'bark',5)
        m.beam((x+.08,sy*(.19+.08*v),.39),(x+.081,sy*(.193+.08*v),.394),.038,'bamboo_wall',5)
    return m


def torch(p,v):
    m=Shape(p)
    m.lathe((0,.095,0),[(.065,0),(.08,.045),(.08,.27),(.060,.35)],7,'sprayer_yellow',ring_colors=['charcoal','sprayer_yellow','sprayer_yellow'])
    # Grip axis stays X/Z zero at .22 m after centered bounds; front/back reach balanced.
    m.beam((0,0,.12),(0,0,.32),.023,'charcoal',5)
    for z in [.12,.32]:m.beam((0,0,z),(0,.095,z),.013,'steel',4)
    pts=[(0,.095,.35),(0,.095,.61),(0,-.04,.69),(0,-.14,.62),(0,-.15,.90)]
    for a,b in zip(pts,pts[1:]):m.beam(a,b,.017,'steel',5)
    m.beam((0,-.148,.85),pts[-1],.026,'charcoal',5)
    return m


def rake(p,v):
    m=Shape(p);m.beam((0,0,0),(0,0,1.35),.023,'post_wood',6)
    m.beam((0,0,.13),(0,0,.31),.030,'bark',6)
    m.beam((0,0,1.20),(0,0,1.36),.031,'steel',6)
    box(m,(0,0,1.355),(.39,.055,.07),'steel')
    for x in [-.16,-.08,0,.08,.16]:m.beam((x,0,1.35),(x,-.14,1.40),.017,'steel',4)
    box(m,(0,.067,1.34),(.30,.133,.025),'steel')
    return m


def tank(p,v):
    m=Shape(p)
    m.lathe((0,0,0),[(.14,0),(.18,.05),(.18,.34),(.14,.42)],8,'sprayer_yellow',aspect=(1,.64),ring_colors=['charcoal','sprayer_yellow','sprayer_yellow'])
    m.lathe((.06,0,.42),[(.040,0),(.040,.04)],8,'charcoal')
    # Exterior inset and lower rail: broad readable construction, no noisy labels.
    box(m,(0,.116,.205),(.21,.013,.19),(.57,.54,.22))
    box(m,(0,.127,.09),(.26,.021,.025),'charcoal')
    for x in [-.09,.09]:
        pts=[(x,-.085,.04),(x,-.14,.10),(x,-.14,.34),(x,-.075,.40)]
        for a,b in zip(pts,pts[1:]):m.beam(a,b,.018,'charcoal',4)
        box(m,(x,-.153,.16),(.045,.016,.038),'steel')
    m.beam((.10,.07,.055),(.15,.085,.055),.021,'gold_foil',6)
    return m


def wand(p,v):
    m=Shape(p);m.lathe((0,0,0),[(.023,0),(.023,.30)],6,'charcoal')
    m.lathe((0,0,.29),[(.026,0),(.026,.033)],6,'gold_foil')
    m.beam((0,0,.32),(0,0,.735),.011,'steel',6)
    m.beam((0,0,.735),(0,-.07,.80),.024,'gold_foil',6)
    m.beam((0,.028,.17),(0,.045,.26),.009,'steel',4)
    m.beam((0,0,.04),(0,.074,.025),.019,'gold_foil',6)
    return m


def granary(p,v):
    m=Shape(p)
    for x in [-.8,.8]:
        for y in [-.65,.65]:
            box(m,(x,y,.63),(.15,.15,1.26),'post_wood')
            m.lathe((x,y,0),[(.24,.80),(.24,.84)],8,'stone_dark')
    box(m,(0,0,1.14),(1.96,1.63,.16),'post_wood')
    for i in range(10):
        x=-.85+i*.19; col=m.tint('bamboo_wall',.93+.023*(i%4))
        box(m,(x,.72,1.85),(.18,.07,1.28),col)
        if i not in [4,5]: box(m,(x,-.72,1.85),(.18,.07,1.28),col)
    for x in [-.93,.93]:box(m,(x,0,1.85),(.08,1.42,1.28),'bamboo_wall')
    for x in [-.91,.91]:
        for y in [-.75,.75]:box(m,(x,y,1.85),(.095,.095,1.29),'post_wood')
    for z in [1.32,2.30]:
        for y in [-.77,.77]:box(m,(0,y,z),(1.96,.045,.055),'post_wood')
        for x in [-.975,.975]:box(m,(x,0,z),(.045,1.48,.055),'post_wood')
    for x in [-.977,.977]:m.beam((x,-.65,1.36),(x,.65,2.28),.030,'post_wood',4)
    # Four overlapping broad thatch courses per slope, with varied eaves.
    for side in [-1,1]:
        for j in range(4):
            a=j*.29; b=(j+1)*.29+.04; za=3-a*.46; zb=3-b*.46
            vs=[(side*a,-.94,za),(side*b,-.96-(.025 if j%2 else 0),zb),(side*b,.94,zb),(side*a,.94,za)]
            # Closed slab; surface normal corrected by cleanup.
            lower=[(x,y,z-.055) for x,y,z in vs]
            fs=[(0,1,2,3),(7,6,5,4),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)]
            m.add(vs+lower,fs,[m.tint('thatch',.90+j*.033)]*6)
    m.beam((0,-.98,3),(0,.98,3),.060,'thatch',5)
    for y in [-.83,.83]:
        m.beam((-1.10,y,2.47),(0,y,2.97),.035,'bark',4)
        m.beam((0,y,2.97),(1.10,y,2.47),.035,'bark',4)
    for i in range(4): box(m,(0,-1.15+i*.105,.23+i*.24),(.53,.15,.06),'post_wood')
    for x in [-.29,.29]:m.beam((x,-1.24,.07),(x,-.70,1.23),.040,'post_wood',4)
    return m


def truck(p,v):
    m=Shape(p);olive=(.27,.31,.25); glass=(.19,.27,.30)
    box(m,(0,0,.53),(1.60,3.35,.23),'charcoal')
    # Sloped bonnet and raked windscreen, instead of stacked square blocks.
    def prism(profile,width,color):
        vs=[(x,y,z) for x in [-width/2,width/2] for y,z in profile];n=len(profile)
        fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
        m.add(vs,fs,[m.tint(color,.94+.022*(j%4)) for j in range(len(fs))])
    prism([(-1.59,.67),(-1.59,1.02),(-.80,1.14),(-.65,.67)],1.64,olive)
    prism([(-.83,.73),(-.83,1.21),(-.56,1.87),(.28,1.87),(.42,.73)],1.52,olive)
    # Windscreen follows the cab rake; opaque flat dark blue-grey glass.
    vs=[(-.65,-.814,1.27),(.65,-.814,1.27),(.65,-.590,1.79),(-.65,-.590,1.79)]
    m.add(vs,[(0,1,2,3)],[glass])
    for x in [-.767,.767]:
        vs=[(x,-.49,1.79),(x,.20,1.79),(x,.22,1.30),(x,-.69,1.30)]
        m.add(vs,[(0,1,2,3)],[glass])
        box(m,(x,.07,1.15),(.026,.17,.025),'steel')
        box(m,(x*1.09,-.61,1.42),(.12,.15,.10),'charcoal')
    box(m,(0,-1.64,.72),(1.76,.13,.14),'steel')
    box(m,(0,-1.65,.93),(.74,.025,.19),'charcoal')
    for j in range(3):box(m,(0,-1.669,.865+j*.055),(.67,.015,.016),'steel')
    for x in [-.61,.61]:box(m,(x,-1.655,.96),(.24,.023,.16),'white_plastic')
    box(m,(0,.98,.79),(1.65,1.78,.16),olive)
    for x in [-.77,.77]:
        box(m,(x,.99,1.02),(.11,1.78,.36),olive)
        box(m,(x,.99,1.22),(.14,1.82,.06),m.tint(olive,1.12))
    box(m,(0,1.85,1.02),(1.65,.11,.36),olive)
    box(m,(0,1.92,.72),(1.73,.14,.12),'steel')
    for x in [-.66,.66]:box(m,(x,1.916,.98),(.15,.02,.10),'karen_red')
    for x in [-.86,.86]:
        for y in [-1.02,1.13]:
            m.beam((x-.115,y,.38),(x+.115,y,.38),.38,'charcoal',10)
            outer=x+(.119 if x>0 else -.119)
            m.beam((outer,y,.38),(outer+(.012 if x>0 else -.012),y,.38),.17,'steel',8)
            box(m,(x,y,.83),(.24,.89,.075),olive)
            box(m,(x,y+.43,.45),(.21,.035,.28),'charcoal')
    return m


def bundle(p,v):
    m=Shape(p)
    m.lathe((0,0,0),[(.13,.015),(.235,.11),(.21,.26),(.055,.365)],8,'indigo_cloth',aspect=(1,.76),
            ring_colors=['indigo_cloth','indigo_cloth','indigo_cloth'])
    m.ico((0,0,.36),(.077,.062,.05),'karen_red')
    m.beam((-.025,0,.375),(-.115,0,.46),.045,'indigo_cloth',3)
    m.beam((.025,0,.375),(.095,.025,.44),.045,'indigo_cloth',3)
    # Two broad woven bands following the cloth contour, open at the tied neck.
    for x in [-.08,.08]:
        pts=[(x,-.089,.034),(x,-.181,.11),(x,-.160,.25),(x*.45,-.045,.35)]
        for a,b in zip(pts,pts[1:]):m.beam(a,b,.018,'karen_red',3)
    return m


def main():
    args=sys.argv[sys.argv.index('--')+1:];out=Path(args[0]);out.mkdir(parents=True,exist_ok=True)
    p=json.loads(Path(args[1]).read_text())['colors'];bpy.ops.wm.read_factory_settings(use_empty=True)
    specs=[('E1','pine',3,pine,300),('E2','bamboo',3,bamboo,400),('E3','brush',4,brush,150),
           ('E8','log',2,log,150),('T1','drip_torch',1,torch,200),('T3','rake',1,rake,200),
           ('T4','sprayer_tank',1,tank,300),('T5','sprayer_wand',1,wand,150),
           ('S3','granary',1,granary,1500),('S6','ranger_truck',1,truck,1500),('S7','travel_bundle',1,bundle,150)]
    records=[]
    for ident,name,count,fn,budget in specs:
        for v in range(count):
            path=out/f'{ident}_{name}_{chr(97+v)}.glb';shape=fn(p,v)
            tris=sum(len(f)-2 for f in shape.faces)
            if tris>budget:raise ValueError(f'{path.name}: {tris} > {budget}')
            shape.export(path)
            records.append({'id':ident,'variant':chr(97+v),'file':path.name,'triangles':tris,'budget':budget,'profile':'standard'})
    (out/'sources.json').write_text(json.dumps(records,indent=2)+'\n');print(json.dumps(records))

if __name__=='__main__':main()
