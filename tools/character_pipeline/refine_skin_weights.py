"""Candidate neighbour smoothing, keeping geometry/materials and rigid carriers intact."""
import copy,json,struct,sys
from pathlib import Path
import numpy as np
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'project.godot').is_file())
sys.path.insert(0,str(ROOT/'tools/asset_pipeline'))
from validate_assets import read_glb,accessor
args=sys.argv[sys.argv.index('--')+1:]
source,output=map(Path,args[:2])
doc,binary=read_glb(source);old=copy.deepcopy(doc);names=[doc['nodes'][i]['name'] for i in doc['skins'][0]['joints']]
reference,reference_binary=read_glb(Path(args[2])) if len(args)>2 else (doc,binary)
assert reference['skins']==doc['skins'] and reference['nodes']==doc['nodes']
counts=[]
def append(array,kind,component):
    global binary
    binary+=b'\0'*((-len(binary))%4);start=len(binary);data=array.tobytes();binary+=data
    doc['bufferViews'].append({'buffer':0,'byteOffset':start,'byteLength':len(data)})
    doc['accessors'].append({'bufferView':len(doc['bufferViews'])-1,'componentType':component,'count':len(array),'type':kind})
    return len(doc['accessors'])-1
for mesh_index,mesh in enumerate(doc['meshes']):
 for primitive_index,primitive in enumerate(mesh['primitives']):
    at=primitive['attributes'];ref=reference['meshes'][mesh_index]['primitives'][primitive_index]['attributes']
    assert accessor(doc,binary,at['POSITION'])==accessor(reference,reference_binary,ref['POSITION']), 'Reference geometry differs'
    weights=np.array(accessor(reference,reference_binary,ref['WEIGHTS_0']));joint=np.array(accessor(reference,reference_binary,ref['JOINTS_0']),dtype=int)
    count=len(weights);full=np.zeros((count,len(names)))
    for k in range(4):np.add.at(full,(np.arange(count),joint[:,k]),weights[:,k])
    original=full.copy();dominant=full.argmax(axis=1);peak=full.max(axis=1)
    locked=np.array([names[i] in ['Head','Bag','Hand.L','Hand.R','Foot.L','Foot.R'] for i in dominant])&(peak>.90)
    # Never introduce new carrier bones. This protects dress panels, rigid ornaments and opposing legs.
    allowed=original>1e-6
    triangles=np.array([x[0] for x in accessor(doc,binary,primitive['indices'])]).reshape(-1,3)
    edges=np.concatenate([triangles[:,[0,1]],triangles[:,[1,2]],triangles[:,[2,0]]]);edges=np.unique(np.sort(edges,axis=1),axis=0)
    degree=np.bincount(edges.flatten(),minlength=count).astype(float);degree=np.maximum(degree,1)
    for iteration in range(8):
        sums=np.zeros_like(full)
        np.add.at(sums,edges[:,0],full[edges[:,1]]);np.add.at(sums,edges[:,1],full[edges[:,0]])
        candidate=full*.8+.2*sums/degree[:,None];candidate*=allowed
        totals=candidate.sum(axis=1);candidate/=np.maximum(totals,1e-12)[:,None]
        candidate[locked]=original[locked];full=candidate
    selected=np.argsort(full,axis=1)[:,-4:][:,::-1];values=np.take_along_axis(full,selected,axis=1);values/=values.sum(axis=1)[:,None]
    at['JOINTS_0']=append(selected.astype('<u2'),'VEC4',5123);at['WEIGHTS_0']=append(values.astype('<f4'),'VEC4',5126)
    counts.append({'vertices':count,'changed':int((abs(full-original).max(axis=1)>1e-5).sum()),'locked':int(locked.sum()),'maximum_weight_delta':float(abs(full-original).max())})
for key in ['nodes','skins','materials','textures','images','animations']:assert doc.get(key)==old.get(key)
for m,n in zip(doc['meshes'],old['meshes']):
 for p,q in zip(m['primitives'],n['primitives']):
    for key,value in q['attributes'].items():
        if key not in ['JOINTS_0','WEIGHTS_0']:assert p['attributes'][key]==value
doc['buffers'][0]['byteLength']=len(binary);data=json.dumps(doc,separators=(',',':')).encode();data+=b' '*((-len(data))%4);binary+=b'\0'*((-len(binary))%4)
output.parent.mkdir(parents=True,exist_ok=True)
output.write_bytes(struct.pack('<4sII',b'glTF',2,28+len(data)+len(binary))+struct.pack('<II',len(data),0x4e4f534a)+data+struct.pack('<II',len(binary),0x004e4942)+binary)
output.with_suffix('.json').write_text(json.dumps({'source':str(source),'review':'candidate only','primitives':counts},indent=2));print(json.dumps(counts))
