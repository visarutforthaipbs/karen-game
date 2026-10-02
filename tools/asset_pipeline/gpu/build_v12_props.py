"""Deterministic v1.2 source meshes. Blender Z up, front -Y -> glTF +Z.
Run: blender -b -P build_v12_props.py -- OUTPUT PALETTE_JSON
All sources still require build_asset.py, visual review and install_asset.py.
"""
import sys, json, math, random
from pathlib import Path
import bpy
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).parent))
from build_cohesive_set import Shape

out=Path(sys.argv[sys.argv.index('--')+1]);out.mkdir(parents=True,exist_ok=True)
palette=json.loads(Path(sys.argv[sys.argv.index('--')+2]).read_text())['colors']
bpy.ops.wm.read_factory_settings(use_empty=True)

def box(m,c,s,color):
 x,y,z=c;a,b,d=[v/2 for v in s]
 v=[(x+sx*a,y+sy*b,z+sz*d) for sz in [-1,1] for sy in [-1,1] for sx in [-1,1]]
 m.add(v,[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)],[m.tint(color,g) for g in [.9,1.04,.96,1,.93,1.03]])

def grass(v):
 m=Shape(palette);rng=random.Random(909+v)
 for i in range(10):
  a=i*math.tau/10+v*.43;r=.12+rng.random()*.09
  h=.30 if i==0 else rng.uniform(.16,.29)
  m.leaf((math.cos(a)*.018,math.sin(a)*.018,0),(math.cos(a)*r,math.sin(a)*r,h),.024+rng.random()*.014,['brush_dry','bamboo_dry','brush_b'][i%3])
 return m

def rock(v):
 m=Shape(palette);rng=random.Random(601+v)
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1)
 obj=bpy.context.object;verts=[]
 for p in obj.data.vertices:
  x,y,z=p.co;noise=rng.uniform(.90,1.09)
  verts.append((x*(.47+.04*v)*noise,y*(.35+.035*(v%2))*noise,max(-.25,z*.38)*noise))
 faces=[tuple(p.vertices) for p in obj.data.polygons]
 colors=[m.tint('stone' if i%7 else 'stone_light',rng.uniform(.92,1.06)) for i in range(len(faces))]
 # A few broad olive-grey lichen patches, not a noisy texture.
 for i,f in enumerate(faces):
  if sum(verts[j][2] for j in f)/3>.20 and i%3==v%3:colors[i]=(.43,.46,.34)
 m.add(verts,faces,colors);bpy.data.objects.remove(obj,do_unlink=True)
 return m

def wall(v):
 m=Shape(palette)
 # Three tight courses. End stones always terminate exactly at X = +/-0.75.
 for row in range(3):
  cuts=[-.75,-.27,.28,.75] if (row+v)%2 else [-.75,-.39,.14,.75]
  for j in range(3):
   left,right=cuts[j],cuts[j+1]
   gap=.008
   lo=left+(gap if j else 0);hi=right-(gap if j<2 else 0)
   depth=.40 if row==0 else .38-row*.018
   box(m,((lo+hi)/2,.012*row,row*.156+.076),(hi-lo,depth,.148),(.43+.025*((j+row+v)%3),.44+.024*((j+row+v)%3),.41+.025*((j+row+v)%3)))
   # Irregular quarried slab faces, while preserving both mating end planes.
   rng=random.Random(v*100+row*10+j)
   for k in range(len(m.vertices)-8,len(m.vertices)):
    x,y,z=m.vertices[k]
    if abs(x)<.749:
     x+=rng.uniform(-.034,.034);z+=rng.uniform(-.019,.019)
    if y<0:y+=rng.uniform(-.020,.020)
    m.vertices[k]=(x,y,z)
 for i in range(4):
  x=-.6+i*.39+v*.04
  m.leaf((x,.06,.455),(x+.08,.11,.52),.035,'brush_dry')
 return m

def log(v):
 m=Shape(palette)
 # Profile along X, broad bark strips and exposed end grain.
 temp=Shape(palette);temp.lathe((0,0,0),[(.15,0),(.19,.18),(.16,1.25),(.13,1.5)],8,'bark',phase=.2*v)
 m.add([(z-.75,y,x+.19) for x,y,z in temp.vertices],temp.faces,temp.colors)
 for side,x in [(-1,-.751),(1,.751)]:
  m.beam((x,0,.19),(x+side*.002,0,.19),.105,'bamboo_wall',8)
 for j in range(2):
  x=-.3+j*.57
  m.beam((x,0,.22),(x+.07,.17*(-1 if j else 1),.39+.03*v),.056,'bark',4)
 return m

def stump(v):
 m=Shape(palette)
 for i in range(3):
  a=i*math.tau/3+v*.6;x=math.cos(a)*.13;y=math.sin(a)*.13
  h=[.4,.25,.32][(i+v)%3]
  m.lathe((x,y,0),[(.058,0),(.052,h)],5,'charcoal')
  m.lathe((x,y,h),[(.035,.0002),(.035,.005)],3,'soot')
 return m

def roots(v):
 m=Shape(palette);m.lathe((0,0,0),[(.17,0),(.11,.28),(.09,.30)],5,'charcoal')
 for i in range(4):
  a=i*math.tau/4+v*.45
  m.beam((math.cos(a)*.06,math.sin(a)*.06,.16),(math.cos(a)*.33,math.sin(a)*.33,.018),.055,'charcoal',3)
 return m

def satellite(v):
 m=Shape(palette)
 # Z here is UP. Wings X, flight -Y, scanner -Z.
 m.lathe((0,0,0),[(.22,.105),(.26,.145),(.26,.49),(.22,.535)],8,'gold_foil',phase=math.pi/8,aspect=(1,1.10))
 for z in [.14,.49]:box(m,(0,0,z),(.445,.505,.035),'steel')
 # Broad foil facets carry depth without microtexture.
 for side in [-1,1]:
  for j in range(3):box(m,(side*.219,-.16+j*.16,.31),(.012,.145,.25),m.tint('gold_foil',.90+j*.06))
  m.beam((side*.21,0,.32),(side*.99,0,.32),.014,'steel',6)
  panel_start=len(m.vertices)
  for j in range(3):
   x=side*(.42+j*.23)
   box(m,(x,0,.32),(.218,.54,.026),'charcoal')
   for y in [-.137,.137]:
    for z in [.335,.305]:box(m,(x,y,z),(.204,.258,.002),(.13+.015*j,.22+.012*j,.39+.016*j))
   box(m,(x,0,.337),(.204,.008,.004),'steel')
  for k in range(panel_start,len(m.vertices)):
   x,y,z=m.vertices[k];a=math.radians(32);m.vertices[k]=(x,y*math.cos(a)-(z-.32)*math.sin(a),.32+y*math.sin(a)+(z-.32)*math.cos(a))
 # Visible down-looking radiometer: dark lens under a stepped white shroud.
 m.lathe((0,-.08,0),[(.105,.014),(.14,.05),(.14,.11),(.10,.14)],10,'white_plastic')
 m.lathe((0,-.08,0),[(.092,.01),(.092,.014)],12, (.065,.11,.15))
 m.lathe((0,-.08,0),[(.055,.008),(.055,.010)],10,(.19,.32,.38))
 # Open dish bowl, concave facing upward; feed is connected.
 m.beam((0,.14,.5),(0,.14,.66),.019,'steel',6)
 temp=Shape(palette);temp.lathe((0,.14,0),[(.035,.65),(.075,.68),(.15,.74)],12,'white_plastic')
 # Remove cap at the broad mouth so the bowl is open.
 temp.faces=temp.faces[:-1];temp.colors=temp.colors[:-1]
 m.add(temp.vertices,temp.faces,temp.colors)
 m.beam((0,.14,.67),(0,.14,.81),.014,'steel',5)
 return m

def torch(v):
 m=Shape(palette)
 # Handle at .22; can offset toward back so the hand has clear space.
 m.lathe((0,.095,0),[(.068,0),(.074,.035),(.074,.31),(.061,.35)],8,'sprayer_yellow')
 m.beam((0,0,.12),(0,0,.32),.018,'charcoal',6)
 for z in [.12,.32]:m.beam((0,0,z),(0,.095,z),.012,'steel',4)
 points=[(0,.095,.35),(0,.095,.61),(0,-.04,.69),(0,-.14,.62),(0,-.14,.85),(0,-.15,.90)]
 for a,b in zip(points,points[1:]):m.beam(a,b,.014,'steel',5)
 m.beam(points[-2],points[-1],.022,'charcoal',5)
 return m

def rake(v):
 m=Shape(palette);m.beam((0,0,0),(0,0,1.35),.019,'post_wood',6)
 m.beam((0,0,.14),(0,0,.30),.022,'bark',6)
 box(m,(0,0,1.36),(.35,.035,.055),'steel')
 for x in [-.14,-.07,0,.07,.14]:m.beam((x,0,1.36),(x,-.13,1.40),.012,'steel',4)
 box(m,(0,.075,1.36),(.28,.117,.03),'steel')
 return m

def wand(v):
 m=Shape(palette);m.lathe((0,0,0),[(.017,0),(.017,.30)],6,'charcoal')
 m.beam((0,0,.30),(0,0,.74),.008,'steel',6)
 m.beam((0,0,.74),(0,-.07,.8),.018,'gold_foil',6)
 m.beam((0,.025,.17),(0,.042,.26),.007,'steel',4)
 m.beam((0,0,.04),(0,.076,.025),.015,'gold_foil',6)
 return m

def tank(v):
 m=Shape(palette)
 m.lathe((0,0,0),[(.14,0),(.18,.05),(.18,.36),(.14,.42)],8,'sprayer_yellow',aspect=(1,.64))
 m.lathe((.06,0,.42),[(.037,0),(.037,.04)],8,'charcoal')
 # Straps lie at front (-Y in Blender = +Z in game).
 for x in [-.09,.09]:
  for a,b in zip([(x,-.09,.04),(x,-.145,.10),(x,-.145,.35),(x,-.085,.40)],[(x,-.145,.10),(x,-.145,.35),(x,-.085,.40),(x,-.07,.39)]):m.beam(a,b,.014,'charcoal',4)
 return m

def camera(v):
 m=Shape(palette)
 box(m,(0,0,.15),(.34,.36,.28),'stone_light')
 box(m,(0,-.20,.17),(.26,.075,.20),'charcoal')
 m.beam((0,-.242,.17),(0,-.25,.17),.071,(.26,.055,.04),10)
 box(m,(0,-.08,.31),(.42,.5,.025),'steel')
 for x in [-.15,.15]:box(m,(x,.05,.365),(.02,.02,.11),'steel')
 box(m,(0,.05,.425),(.48,.29,.02),'charcoal')
 box(m,(0,.05,.439),(.44,.25,.005),(.16,.24,.36))
 return m

def ellipsoid(m,c,s,color,segments=12,rings=8):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,radius=1)
 obj=bpy.context.object
 verts=[tuple(c[k]+p.co[k]*s[k] for k in range(3)) for p in obj.data.vertices]
 faces=[tuple(p.vertices) for p in obj.data.polygons]
 m.add(verts,faces,[m.tint(color,1+(i%5-2)*.012) for i in range(len(faces))]);bpy.data.objects.remove(obj,do_unlink=True)

def villager(v):
 m=Shape(palette)
 skin=[(.65,.43,.28),(.72,.49,.32),(.62,.42,.29),(.73,.50,.34)][v]
 cloth=[(.22,.28,.38),(.30,.28,.39),(.80,.74,.61),(.83,.79,.68)][v]
 red=(.53,.23,.22);dark=(.105,.095,.085)
 # A grounded stride with opposite arm swing. Feet are joined to lower legs.
 for side in [-1,1]:
  x=side*.092;forward=side*.105*(1 if v%2==0 else -1)
  foot=(x,forward,.045);knee=(x,forward*.30,.23);hip=(x,0,.43)
  m.beam(hip,knee,.065,'indigo_cloth',7);m.beam(knee,(x,forward,.09),.051,skin if v==1 else 'indigo_cloth',7)
  ellipsoid(m,(x,forward-.031,.053),(.075,.12,.053),'bark',10,5)
  box(m,(x,forward-.035,.018),(.134,.19,.03),'stone_dark')
 # Tunic taper and broad woven border, modest long skirt on woman.
 hem=.27 if v==1 else .43
 m.lathe((0,0,0),[(.175,hem),(.16,.53),(.14,.70),(.125,.76)],10,cloth,aspect=(1,.65))
 m.lathe((0,0,0),[(.176,hem+.008),(.176,hem+.032)],10,red,aspect=(1,.65))
 m.lathe((0,0,0),[(.164,.51),(.164,.54)],10,red,aspect=(1,.65))
 # Front neckline and two wide woven vertical bands, no noisy patterns.
 for x in [-.052,.052]:
  m.beam((x,-.090,.70),(0,-.100,.65),.009,red,4)
  box(m,(x,-.104,(hem+.62)/2),(.017,.006,.62-hem),red)
 m.lathe((0,0,.72),[(.063,0),(.063,.09)],8,skin)
 # Arms with elbows following the walking pose; sleeves cover upper arms.
 for side in [-1,1]:
  forward=-side*.105*(1 if v%2==0 else -1)
  shoulder=(side*.14,0,.70);elbow=(side*.205,forward*.4,.57);hand=(side*.20,forward,.43)
  m.beam(shoulder,elbow,.066,cloth,7)
  m.beam((side*.192,forward*.35,.585),(side*.21,forward*.55,.548),.068,red,7)
  m.beam(elbow,hand,.041,skin,7)
  ellipsoid(m,hand,(.044,.045,.057),skin,8,5)
  ellipsoid(m,(hand[0]-side*.03,hand[1]-.018,hand[2]+.009),(.023,.025,.032),skin,6,4)
 # Large but restrained chibi head; forward is -Y.
 head_start=len(m.vertices)
 ellipsoid(m,(0,-.008,.944),(.158,.126,.181),skin,16,10)
 for side in [-1,1]:ellipsoid(m,(side*.15,-.001,.948),(.027,.022,.043),skin,8,5)
 hair=(.27,.27,.25) if v==2 else dark
 # Fitted scalp cap, not a sphere overlay across the face.
 n=12;verts=[]
 for ring,(z,r) in enumerate([(1.014,1),(1.095,.72),(1.142,.18)]):
  for i in range(n):
   a=i*math.tau/n
   verts.append((math.cos(a)*.177*r,math.sin(a)*.150*r+.006,z))
 faces=[]
 for row in range(2):
  for i in range(n):faces.append((row*n+i,row*n+(i+1)%n,(row+1)*n+(i+1)%n,(row+1)*n+i))
 faces.append(tuple(range(2*n,3*n)))
 m.add(verts,faces,[m.tint(hair,1+(i%3-1)*.05) for i in range(len(faces))])
 if v in [0,2]:
  m.lathe((0,.006,0),[(.174,1.037),(.165,1.082)],12,red if v==0 else (.55,.48,.37),aspect=(1,.84))
  m.beam((.11,.083,1.06),(.14,.10,.91),.035,red if v==0 else (.55,.48,.37),4)
 elif v==1:
  ellipsoid(m,(0,.103,.96),(.115,.052,.11),hair,10,6)
  ellipsoid(m,(0,.134,.895),(.057,.047,.055),hair,10,6)
 else:
  # Side-swept chunky fringe.
  m.beam((-.12,-.095,1.062),(.01,-.145,1.025),.030,hair,4)
 # Eyes and brows sit on the face, with tiny warm highlights.
 for side in [-1,1]:
  x=side*.061
  ellipsoid(m,(x,-.123,.972),(.027,.009,.015),(.91,.86,.73),8,5)
  ellipsoid(m,(x,-.132,.972),(.012,.005,.014),dark,8,5)
  ellipsoid(m,(x-.003,-.136,.977),(.003,.002,.003),(.94,.9,.81),6,4)
  m.beam((x-side*.024,-.119,1.006),(x+side*.017,-.12,1.01),.007,hair,4)
 ellipsoid(m,(0,-.133,.94),(.025,.034,.025),skin,8,5)
 m.beam((-.026,-.127,.902),(.026,-.127,.902),.004,(.39,.23,.17),5)
 if v==2:
  for side in [-1,1]:m.beam((0,-.133,.917),(side*.035,-.125,.91),.01,(.72,.71,.65),5)
 for k in range(head_start,len(m.vertices)):
  x,y,z=m.vertices[k];m.vertices[k]=(x*1.16,y*1.16,.94+(z-.94)*1.18)
 if v==1:
  for z in [.30,.35,.40,.45]:m.lathe((0,0,0),[(.174-(z-.27)*.065,z),(.174-(z-.27)*.065,z+.018)],10,red,aspect=(1,.67))
 return m

records=[]
for ident,name,count,fn in [('E9','grass_tuft',3,grass),('E6','rock',4,rock),('E7','terrace_wall',2,wall),('E8','log',2,log),('V3','satellite',1,satellite),('C6','villager',4,villager),('E4','bamboo_stump',2,stump),('E5','root_collar',2,roots),('T1','drip_torch',1,torch),('T3','rake',1,rake),('T5','sprayer_wand',1,wand),('T4','sprayer_tank',1,tank),('V2','thermal_camera_housing',1,camera)]:
 for v in range(count):
  if len(sys.argv)>sys.argv.index('--')+3 and ident not in sys.argv[sys.argv.index('--')+3].split(','):continue
  path=out/f'{ident}_{name}_{chr(97+v)}.glb';tri=fn(v).export(path)
  records.append({'id':ident,'variant':chr(97+v),'file':path.name,'triangles':tri})
(out/'sources.json').write_text(json.dumps(records,indent=2)+'\n');print(json.dumps(records))
