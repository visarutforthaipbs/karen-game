"""Asset-only v1.1 props. Run in Blender beside build_cohesive_set.py."""
import sys,json,math
from pathlib import Path
import bpy
sys.path.insert(0,str(Path(__file__).parent))
from build_cohesive_set import Shape

out=Path(sys.argv[sys.argv.index('--')+1]);out.mkdir(parents=True,exist_ok=True)
palette=json.loads(Path(sys.argv[sys.argv.index('--')+2]).read_text())['colors']
bpy.ops.wm.read_factory_settings(use_empty=True)
def box(m,c,s,color):
 x,y,z=c;a,b,d=[v/2 for v in s]
 v=[(x+sx*a,y+sy*b,z+sz*d) for sz in [-1,1] for sy in [-1,1] for sx in [-1,1]]
 m.add(v,[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)],[m.tint(color)]*6)
def knife():
 m=Shape(palette);m.lathe((0,0,0),[(.021,0),(.026,.035),(.023,.14)],6,'post_wood')
 outline=[(-.022,.135),(.027,.135),(.045,.38),(.015,.50),(-.022,.47)]
 verts=[(x,y,z) for y in [-.006,.006] for x,z in outline];n=len(outline)
 faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 m.add(verts,faces,[m.tint('steel',v) for v in [1.04,.88,1,1,1.1,1.1,1]])
 m.lathe((0,0,0),[(.031,.125),(.031,.145)],6,'charcoal');return m

def checkpoint():
 m=Shape(palette)
 for x in [-1.30,1.30]:
  box(m,(x,0,.06),(.38,.55,.12),'stone_dark');box(m,(x,0,.52),(.13,.13,.94),'charcoal')
 box(m,(0,0,1.02),(3,.12,.13),'white_plastic')
 for i in range(7):box(m,(-1.30+i*.42,-.062,1.02),(.20,.008,.13),'charcoal')
 for x in [-1.04,1.06]:
  for row in range(2):
   for j in range(2):m.ico((x+(j-.5)*.26,.36,.11+row*.17),(.22,.16,.105),'bamboo_wall',.1*row)
 box(m,(-1.30,-.085,.82),(.25,.025,.20),'white_plastic')
 return m

def truck():
 m=Shape(palette);olive=(.27,.31,.25)
 box(m,(0,0,.55),(1.6,3.35,.25),'charcoal');box(m,(0,-.87,.93),(1.65,1.45,.55),olive)
 box(m,(0,-.45,1.49),(1.52,.85,.80),olive)
 box(m,(0,-.885,1.60),(1.30,.015,.42),( .19,.27,.30))
 for x in [-.766,.766]:box(m,(x,-.45,1.60),(.014,.65,.42),(.19,.27,.30))
 box(m,(0,-1.58,.71),(1.7,.12,.16),'steel')
 for x in [-.59,.59]:box(m,(x,-1.663,.98),(.25,.025,.18),'white_plastic')
 box(m,(0,.93,.79),(1.65,1.80,.16),olive)
 for x in [-.76,.76]:box(m,(x,.94,1.06),(.12,1.80,.42),olive)
 box(m,(0,1.80,1.06),(1.65,.12,.42),olive)
 for x in [-.86,.86]:
  for y in [-1.0,1.10]:m.beam((x-.115,y,.38),(x+.115,y,.38),.38,'charcoal',8);m.beam((x-.12,y,.38),(x+.12,y,.38),.16,'steel',8)
 return m

def bundle():
 m=Shape(palette)
 # Solid gathered cloth, with a tied neck and overlapping fabric tails.
 m.lathe((0,0,0),[(.13,.025),(.235,.11),(.225,.25),(.06,.365)],8,'indigo_cloth',aspect=(1,.76))
 m.ico((0,0,.36),(.075,.06,.05),'indigo_cloth')
 m.beam((-.025,0,.375),(-.115,0,.45),.045,'indigo_cloth',3)
 m.beam((.025,0,.375),(.095,.025,.43),.045,'indigo_cloth',3)
 return m

def flashlight():
 m=Shape(palette)
 m.lathe((0,0,0),[(.023,0),(.027,.025),(.027,.16),(.043,.19),(.043,.22)],8,'charcoal')
 m.lathe((0,0,0),[(.034,.2201),(.034,.224)],8,'white_plastic')
 return m

def tablet():
 m=Shape(palette);box(m,(0,0,.07),(.20,.018,.14),'charcoal')
 box(m,(0,-.011,.072),(.174,.006,.112),(.35,.46,.50))
 return m

def granary():
 m=Shape(palette)
 for x in [-.8,.8]:
  for y in [-.65,.65]:box(m,(x,y,.63),(.14,.14,1.26),'post_wood');m.lathe((x,y,0),[(.23,.80),(.23,.84)],8,'stone_dark')
 box(m,(0,0,1.14),(1.96,1.63,.16),'post_wood')
 for i in range(10):
  x=-.85+i*.19
  box(m,(x,.72,1.88),(.18,.06,1.32),'bamboo_wall')
  if i not in [4,5]:box(m,(x,-.72,1.88),(.18,.06,1.32),'bamboo_wall')
 for x in [-.93,.93]:box(m,(x,0,1.88),(.08,1.42,1.32),'bamboo_wall')
 # Ridge thatch planes, thick enough to read from below; doorway stays open.
 v=[(-1.12,-.90,2.48),(1.12,-.90,2.48),(0,-.90,3),(-1.12,.90,2.48),(1.12,.90,2.48),(0,.90,3)]
 m.add(v,[(0,1,2),(3,5,4),(0,2,5,3),(2,1,4,5),(0,3,4,1)],[m.tint('thatch',g) for g in [.92,.92,1.04,.96,.8]])
 for y in [-.57,.57]:box(m,(0,y,1.87),(1.94,.05,.07),'post_wood')
 for i in range(4):
  z=.23+i*.24;y=-1.15+i*.105
  box(m,(0,y,z),(.53,.14,.055),'post_wood')
 for x in [-.29,.29]:m.beam((x,-1.24,.07),(x,-.70,1.23),.037,'post_wood',4)
 return m
records=[]
for ident,name,fn in [('T2','mida_knife',knife),('S5','checkpoint',checkpoint),('S6','ranger_truck',truck),('S7','travel_bundle',bundle),('S3','rice_granary',granary),('T6','ranger_flashlight',flashlight),('T7','ranger_tablet',tablet)]:
 path=out/f'{ident}_{name}_a.glb';tri=fn().export(path);records.append({'id':ident,'file':path.name,'triangles':tri})
(out/'sources.json').write_text(json.dumps(records,indent=2));print(json.dumps(records))
