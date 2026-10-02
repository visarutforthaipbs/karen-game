"""Transfer a reviewed baked albedo into the original rig container losslessly.
Blender re-import/export may resample animation times. Only append the baked PNG
and redirect its image bufferView; original mesh, skin and animation bytes stay.
"""
import argparse,copy,hashlib,json,struct
from pathlib import Path

def read_glb(path):
 data=Path(path).read_bytes();magic,version,total=struct.unpack_from('<4sII',data)
 assert magic==b'glTF' and version==2 and total==len(data)
 size,kind=struct.unpack_from('<II',data,12);assert kind==0x4e4f534a
 document=json.loads(data[20:20+size]);offset=20+size
 length,kind=struct.unpack_from('<II',data,offset);assert kind==0x004e4942
 return document,data[offset+8:offset+8+length]

def transfer(source,baked,output):
 output=Path(output);assert not output.exists()
 doc,binary=read_glb(source);variant,other=read_glb(baked)
 assert len(doc['images'])==len(variant['images'])==1
 image=variant['images'][0];view=variant['bufferViews'][image['bufferView']]
 assert view.get('buffer',0)==0 and image['mimeType']=='image/png'
 png=other[view.get('byteOffset',0):view.get('byteOffset',0)+view['byteLength']]
 assert png.startswith(b'\x89PNG\r\n\x1a\n')
 original=copy.deepcopy(doc)
 padding=(-len(binary))%4;offset=len(binary)+padding
 binary+=b'\0'*padding+png
 doc['bufferViews'].append(dict(buffer=0,byteOffset=offset,byteLength=len(png)))
 doc['images'][0]['bufferView']=len(doc['bufferViews'])-1
 doc['images'][0]['mimeType']='image/png'
 doc['buffers'][0]['byteLength']=len(binary)
 for key in ['animations','skins','meshes','nodes','accessors']:
  assert doc.get(key)==original.get(key)
 assert binary[:len(read_glb(source)[1])]==read_glb(source)[1]
 encoded=json.dumps(doc,separators=(',',':')).encode();encoded+=b' '*((-len(encoded))%4)
 binary+=b'\0'*((-len(binary))%4)
 output.write_bytes(struct.pack('<4sII',b'glTF',2,28+len(encoded)+len(binary))+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+struct.pack('<II',len(binary),0x004e4942)+binary)
 output.with_suffix('.json').write_text(json.dumps(dict(source_sha256=hashlib.sha256(Path(source).read_bytes()).hexdigest(),baked_sha256=hashlib.sha256(Path(baked).read_bytes()).hexdigest(),output_sha256=hashlib.sha256(output.read_bytes()).hexdigest(),geometry_skin_animation_bytes='unchanged',variant_image_bytes=len(png)),indent=2)+'\n')

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('source');p.add_argument('baked');p.add_argument('output');a=p.parse_args();transfer(a.source,a.baked,a.output)
