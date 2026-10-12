#!/usr/bin/env python3
from pathlib import Path
import hashlib,json,re,struct,subprocess,zipfile
ROOT=Path(__file__).resolve().parents[2];BASE=ROOT/'docs/steam';P=BASE/'package'
DIMS={'header':(920,430),'small':(462,174),'main':(1232,706),'vertical':(748,896),'library_capsule':(600,900),'library_header':(920,430),'library_hero':(3840,1240),'library_logo':(1280,200)}
def dim(p):
 b=p.read_bytes();assert b[:8]==b'\x89PNG\r\n\x1a\n',p
 return struct.unpack('>II',b[16:24])
for name,sz in DIMS.items():assert dim(P/'artwork'/f'{name}.png')==sz,name
shots=list((P/'screenshots').glob('*.png'));assert len(shots)==5
for p in shots:assert dim(p)==(1920,1080),p
for p in BASE.glob('*.md'):
 for link in re.findall(r'\]\(([^)]+)\)',p.read_text()):
  if not link.startswith(('https:','http:','#')):assert (p.parent/link.split('#')[0]).exists(),(p,link)
rights=json.loads((P/'ASSET_RIGHTS_INVENTORY.json').read_text());loc=json.loads((P/'LOCALIZATION_INVENTORY.json').read_text())
assert rights['assets'] and loc['items']
video=P/'video/gameplay-review-cut.mp4'
probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration:stream=codec_type,width,height','-of','json',str(video)]))
assert 59<=float(probe['format']['duration'])<=61
assert all(s['codec_type']!='audio' for s in probe['streams'])
files=[]
for p in sorted(BASE.rglob('*')):
 if p.is_file() and p.name not in ('MANIFEST.json','steam-preparation.zip') and 'capture_save' not in p.parts:
  files.append(dict(path=str(p.relative_to(BASE)),bytes=p.stat().st_size,sha256=hashlib.sha256(p.read_bytes()).hexdigest()))
manifest=dict(prepared='2026-10-03',git_head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),status='Internal preparation candidates; account, rights, localization, demo and release QA pending',screenshots='Production scenes; staged camera/clock/ignition, native 1920x1080; no pixel retouch',video='Silent review cut, source 30-90s; original excluded due desktop/Discord footage',source_asset_count=len(rights['assets']),thai_candidate_count=len(loc['items']),files=files)
(P/'MANIFEST.json').write_text(json.dumps(manifest,indent=2)+'\n')
archive=BASE/'steam-preparation.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
 for item in files:z.write(BASE/item['path'],item['path'])
 z.write(P/'MANIFEST.json','package/MANIFEST.json')
 for p in sorted((ROOT/'tools/steam').glob('*')):
  if p.suffix in ('.py','.cjs','.gd'):z.write(p,'tools/'+p.name)
print(f'Validated 8 art sizes, 5 native screenshots, video duration/no audio, document links and inventories. Archived {len(files)} package files; excludes capture saves.')
