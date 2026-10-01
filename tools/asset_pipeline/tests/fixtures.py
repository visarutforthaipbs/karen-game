import json
import struct
from pathlib import Path


def cube(path, height=.8, scale=1, indices=None, missing_color=False, nonfinite=False, instances=1):
    verts=[(x,y,z) for y in (0,height) for x in (-height/2,height/2) for z in (-height/2,height/2)]
    if nonfinite:verts[0]=(float('nan'),0,0)
    faces=indices if indices is not None else [0,1,2,1,3,2,4,6,5,5,6,7,0,4,1,1,4,5,2,3,6,3,7,6,0,2,4,2,6,4,1,5,3,3,5,7]
    blob=struct.pack('<24f',*(v for p in verts for v in p))+bytes([255,80,40,255]*8)+struct.pack('<'+'H'*len(faces),*faces)
    attrs={'POSITION':0}
    if not missing_color:attrs['COLOR_0']=1
    doc={'asset':{'version':'2.0'},'scene':0,'scenes':[{'nodes':list(range(instances))}],
         'nodes':[{'mesh':0,'scale':[scale]*3} for _ in range(instances)],
         'buffers':[{'byteLength':len(blob)}],
         'bufferViews':[{'buffer':0,'byteOffset':0,'byteLength':96},{'buffer':0,'byteOffset':96,'byteLength':32},{'buffer':0,'byteOffset':128,'byteLength':len(faces)*2}],
         'accessors':[{'bufferView':0,'componentType':5126,'count':8,'type':'VEC3'},
                      {'bufferView':1,'componentType':5121,'normalized':True,'count':8,'type':'VEC4'},
                      {'bufferView':2,'componentType':5123,'count':len(faces),'type':'SCALAR'}],
         'meshes':[{'primitives':[{'attributes':attrs,'indices':2,'mode':4}]}]}
    write(path,doc,blob)


def write(path,doc,blob):
    encoded=json.dumps(doc).encode();encoded+=b' '*((-len(encoded))%4)
    blob+=b'\0'*((-len(blob))%4)
    Path(path).write_bytes(struct.pack('<4sII',b'glTF',2,28+len(encoded)+len(blob))+
                          struct.pack('<II',len(encoded),0x4e4f534a)+encoded+
                          struct.pack('<II',len(blob),0x004e4942)+blob)
