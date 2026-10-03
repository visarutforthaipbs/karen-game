"""Blender Python: append a retargeted clip without re-exporting mesh/skin bytes.

Candidate torso/head overlay on approved clip anatomy; source local first-frame
rotation and its bind axes define motion. Requires visual, full-clip deformation,
semantic runtime and equipment review before installation.
"""
import argparse, bisect, copy, hashlib, json, math, struct, sys
from pathlib import Path
from mathutils import Matrix, Quaternion, Vector

ROOT=next(p for p in Path(__file__).resolve().parents if (p/'project.godot').is_file())
sys.path.insert(0, str(ROOT/'tools/asset_pipeline'))
from validate_assets import read_glb, accessor, node_matrix

MAP={'Hips':'Hips','Spine':'Spine02','Chest':'Spine01','Neck':'neck','Head':'Head'}
for side,prefix in [('L','Left'),('R','Right')]:
    for dest,src in [('UpperArm','Arm'),('Forearm','ForeArm'),('Hand','Hand'),
                     ('Thigh','UpLeg'),('Shin','Leg'),('Foot','Foot')]:
        MAP[dest+'.'+side]=prefix+src

def matrix(values):
    return Matrix([[values[c*4+r] for c in range(4)] for r in range(4)])

def state(doc,binary):
    parents={c:i for i,n in enumerate(doc['nodes']) for c in n.get('children',[])}
    local=[matrix(node_matrix(n)) for n in doc['nodes']]
    def world(i,matrices):
        return world(parents[i],matrices)@matrices[i] if i in parents else matrices[i]
    mesh_index=next(i for i,n in enumerate(doc['nodes']) if n.get('skin')==0)
    skin=doc['skins'][0]
    binds=accessor(doc,binary,skin['inverseBindMatrices'])
    mw=world(mesh_index,local)
    rest={i:mw@matrix(v).inverted() for i,v in zip(skin['joints'],binds)}
    return parents,local,world,rest

def main():
    p=argparse.ArgumentParser()
    for arg in ['source','target','output']: p.add_argument('--'+arg,type=Path,required=True)
    p.add_argument('--clip',required=True)
    p.add_argument('--duration',type=float,required=True)
    args=p.parse_args(sys.argv[sys.argv.index('--')+1:])
    assert args.clip in ['Idle','Talk','Scan'], 'Only reviewed carry-compatible profiles are supported'
    assert not args.output.exists() and args.duration>0
    sd,sb=read_glb(args.source);td,tb=read_glb(args.target)
    original=copy.deepcopy(td);oldbytes=tb
    baseline=next(a for a in td['animations'] if a['name']==args.clip)
    sp,sl,sw,srest=state(sd,sb);tp,tl,tw,trest=state(td,tb)
    sn={n['name']:i for i,n in enumerate(sd['nodes']) if 'name' in n}
    tn={n['name']:i for i,n in enumerate(td['nodes']) if 'name' in n}
    assert set(MAP.values())<=set(sn) and set(MAP)<=set(tn)
    animation=sd['animations'][0]
    channels=[]
    for c in animation['channels']:
        s=animation['samplers'][c['sampler']]
        assert s.get('interpolation','LINEAR') in ['LINEAR','STEP']
        channels.append((c['target']['node'],c['target']['path'],
            [v[0] for v in accessor(sd,sb,s['input'])],accessor(sd,sb,s['output']),s.get('interpolation','LINEAR')))
    source_duration=max(c[2][-1] for c in channels)
    times=[args.duration*i/round(args.duration*30) for i in range(round(args.duration*30)+1)]
    rotations={i:[] for i in td['skins'][0]['joints']};translations={i:[] for i in rotations}
    source_rotation_reference={}
    max_provider_delta=0.0
    for t in times:
        st=t/args.duration*source_duration
        values={}
        for i,path,keys,rows,interp in channels:
            j=min(max(bisect.bisect_right(keys,st)-1,0),len(keys)-1)
            k=min(j+1,len(keys)-1);f=0 if keys[k]==keys[j] or interp=='STEP' else max(0,min(1,(st-keys[j])/(keys[k]-keys[j])))
            if path=='rotation':
                a=Quaternion((rows[j][3],*rows[j][:3]));b=Quaternion((rows[k][3],*rows[k][:3]))
                value=a.slerp(b,f).normalized()
            else:value=Vector(rows[j]).lerp(Vector(rows[k]),f)
            values.setdefault(i,{})[path]=value
        posed=[]
        for i,m in enumerate(sl):
            loc,q,scale=m.decompose();v=values.get(i,{})
            posed.append(Matrix.LocRotScale(v.get('translation',loc),v.get('rotation',q),v.get('scale',scale)))
        # Compatible idle profile retains all approved limb and root tracks.
        # Transfer only the provider's subtle Chest/Head movement, relative to
        # its first animated frame, over the existing anatomical carry stance.
        base_local=[m.copy() for m in tl]
        for c in baseline['channels']:
            sampler=baseline['samplers'][c['sampler']]
            keys=[v[0] for v in accessor(original,oldbytes,sampler['input'])]
            rows=accessor(original,oldbytes,sampler['output'])
            j=min(max(bisect.bisect_right(keys,t)-1,0),len(keys)-1);k=min(j+1,len(keys)-1)
            f=0 if keys[k]==keys[j] else max(0,min(1,(t-keys[j])/(keys[k]-keys[j])))
            i=c['target']['node'];loc,q,scale=base_local[i].decompose()
            path=c['target']['path']
            if path=='rotation':
                q=Quaternion((rows[j][3],*rows[j][:3])).slerp(Quaternion((rows[k][3],*rows[k][:3])),f)
            elif path=='translation':loc=Vector(rows[j]).lerp(Vector(rows[k]),f)
            elif path=='scale':scale=Vector(rows[j]).lerp(Vector(rows[k]),f)
            base_local[i]=Matrix.LocRotScale(loc,q,scale)
        desired={}
        for target_name,source_name in {'Chest':'Spine01','Head':'Head'}.items():
            i=tn[target_name];j=sn[source_name]
            source_q=posed[j].to_quaternion()
            source_rotation_reference.setdefault(j,source_q.copy())
            local_delta=source_q@source_rotation_reference[j].inverted()
            axis_basis=srest[sp[j]].to_quaternion()
            delta=axis_basis@local_delta@axis_basis.inverted()
            if delta.w<0:delta.negate()
            max_provider_delta=max(max_provider_delta,math.degrees(delta.angle))
            # Short chibi torso and carried tools call for a quiet idle gain.
            delta=Quaternion().slerp(delta,.15)
            assert delta.angle<math.radians(12), 'Overlay exceeds reviewed quiet-pose envelope'
            desired[i]=delta@tw(i,base_local).to_quaternion()
        cache={}
        def target_pose(i):
            if i in cache:return cache[i]
            parent=target_pose(tp[i]) if i in tp else Matrix.Identity(4)
            loc,q,scale=base_local[i].decompose()
            if i in desired:q=parent.to_quaternion().inverted()@desired[i]
            # Preserve approved Hips translation, including its grounded breath.
            local=Matrix.LocRotScale(loc,q,scale)
            cache[i]=parent@local
            if i in rotations:
                q.normalize()
                rows=rotations[i]
                if rows and sum(a*b for a,b in zip(rows[-1],(q.x,q.y,q.z,q.w)))<0:q.negate()
                rotations[i].append((q.x,q.y,q.z,q.w));translations[i].append(tuple(loc))
            return cache[i]
        for i in rotations:target_pose(i)
    # Force exact loop closure. Pilot reviews must still reject a noticeable wrap.
    seam={}
    for i,rows in rotations.items():
        a=Quaternion((rows[0][3],*rows[0][:3]));b=Quaternion((rows[-1][3],*rows[-1][:3]))
        seam[td['nodes'][i]['name']]=math.degrees(a.rotation_difference(b).angle)
        rows[-1]=rows[0];translations[i][-1]=translations[i][0]
    def append(rows,kind):
        nonlocal tb
        width={'SCALAR':1,'VEC3':3,'VEC4':4}[kind]
        payload=b''.join(struct.pack('<'+'f'*width,*row) for row in rows)
        tb+=b'\0'*((-len(tb))%4);offset=len(tb);tb+=payload
        td['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':len(payload)})
        acc={'bufferView':len(td['bufferViews'])-1,'componentType':5126,'count':len(rows),'type':kind}
        if kind=='SCALAR':acc.update(min=[rows[0][0]],max=[rows[-1][0]])
        td['accessors'].append(acc);return len(td['accessors'])-1
    time_acc=append([(t,) for t in times],'SCALAR')
    new={'name':args.clip,'samplers':[],'channels':[]}
    for i in rotations:
        for path,rows,kind in [('rotation',rotations[i],'VEC4'),('translation',translations[i],'VEC3')]:
            new['channels'].append({'sampler':len(new['samplers']),'target':{'node':i,'path':path}})
            new['samplers'].append({'input':time_acc,'output':append(rows,kind),'interpolation':'LINEAR'})
    assert any(a['name']==args.clip for a in td['animations'])
    td['animations']=[new if a['name']==args.clip else a for a in td['animations']]
    for key in ['nodes','meshes','skins','materials','textures','images']:
        assert td.get(key)==original.get(key),key
    assert tb[:len(oldbytes)]==oldbytes
    td['buffers'][0]['byteLength']=len(tb)
    encoded=json.dumps(td,separators=(',',':')).encode();encoded+=b' '*((-len(encoded))%4);tb+=b'\0'*((-len(tb))%4)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_bytes(struct.pack('<4sII',b'glTF',2,28+len(encoded)+len(tb))+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+struct.pack('<II',len(tb),0x004e4942)+tb)
    report={'source':str(args.source),'target':str(args.target),'output':str(args.output),'clip':args.clip,
            'source_duration':source_duration,'duration':args.duration,'hip_reference':'approved baseline preserved','profile':'carry-compatible '+args.clip+': approved limbs/root, relative local Chest/Head motion at 0.15 gain','max_provider_delta_degrees':max_provider_delta,'unclosed_seam_degrees':seam,
            'original_geometry_skin_material_and_other_animation_bytes':'preserved',
            'review':'required','sha256':hashlib.sha256(args.output.read_bytes()).hexdigest()}
    args.output.with_suffix('.json').write_text(json.dumps(report,indent=2))
    print(json.dumps(report))

if __name__=='__main__':main()
