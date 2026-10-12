#!/usr/bin/env python3
"""Read-only source inventory. Evidence is not a commercial licence clearance."""
from pathlib import Path
import hashlib,json,re
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/steam/package'
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 rows=[]
 for p in sorted((ROOT/'assets').rglob('*')):
  if not p.is_file() or p.suffix in ('.import','.uid') or p.name.startswith('.'): continue
  rel=p.relative_to(ROOT).as_posix()
  evidence=[];status='needs rights review';provider='unresolved'
  if rel.startswith('assets/fonts/'):
   provider='bundled font';evidence=['assets/fonts/OFL-Kanit.txt','assets/fonts/OFL-ChakraPetch.txt'];status='licence files present; verify family and attribution'
  elif rel.startswith('assets/audio/'):
   provider='mixed procedural / ElevenLabs; per-file confirmation needed';evidence=['tools/audio_pipeline/README.md','tools/audio_pipeline/production_plan.json','tools/audio_pipeline/voice_plan.json','tools/audio_pipeline/revision_plan.json']
  elif rel.startswith('assets/models/'):
   provider='Meshy / legacy pipeline; match registry';evidence=['tools/character_pipeline/installed_meshy_cast.json','SOP.md']
  elif rel.startswith(('assets/props/','assets/ui/logo/')):
   provider='procedural / Meshy / legacy pipeline; per-file confirmation needed';evidence=['tools/asset_pipeline/asset_manifest.json','HANDOFF.md']
  elif rel.startswith(('assets/concept_art/','assets/reference/')):
   provider='reference/concept source; verify creator and permissions';evidence=['ASSETS.md','SOP.md']
  rows.append(dict(path=rel,bytes=p.stat().st_size,sha256=digest(p),provider_hint=provider,status=status,evidence=evidence,commercial_rights_proof=None,shipped_in_release='audit export contents'))
 OUT.mkdir(parents=True,exist_ok=True)
 (OUT/'ASSET_RIGHTS_INVENTORY.json').write_text(json.dumps(dict(date='2026-10-03',scope='Source assets, not a verified exported-payload list',assets=rows),ensure_ascii=False,indent=2)+'\n')
 strings=[]
 for folder in ['scripts','ui']:
  for p in sorted((ROOT/folder).rglob('*.gd')):
   for n,line in enumerate(p.read_text().splitlines(),1):
    # Source candidates include non-player text/comments; human classification needed.
    for match in re.finditer(r'"(?:\\.|[^"\\])*"',line):
     if re.search('[\u0e00-\u0e7f]',match.group()): strings.append(dict(file=str(p.relative_to(ROOT)),line=n,thai_literal=match.group()[1:-1],english=None,status='needs classification and translation'))
 (OUT/'LOCALIZATION_INVENTORY.json').write_text(json.dumps(dict(scope='Quoted Thai source candidates; not exhaustive UI coverage',items=strings),ensure_ascii=False,indent=2)+'\n')
 print(f'{len(rows)} source assets hashed; {len(strings)} Thai string candidates indexed.')
if __name__=='__main__':main()
