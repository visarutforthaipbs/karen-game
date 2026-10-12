#!/usr/bin/env python3
"""Generate SteamPipe files locally. Never logs in, uploads or sets a live branch."""
import argparse,json,re
from pathlib import Path

def vdf_string(value):
 return str(value).replace('\\','/').replace('"','\\"').replace('\n',' ')
def generate(config,output):
 product=config.get('product')
 if product not in ('base','demo'):raise ValueError('product must be base or demo')
 if not config.get('build_verified'):raise ValueError('build_verified must be true after product-specific QA')
 app=config.get('app_id')
 if not isinstance(app,int) or isinstance(app,bool) or app<=0:raise ValueError('real positive integer app_id required')
 depots=config.get('depots',[])
 if not depots:raise ValueError('at least one verified depot required')
 seen=set();rendered=[]
 for d in depots:
  ident=d.get('id')
  if not isinstance(ident,int) or isinstance(ident,bool) or ident<=0 or ident in seen:raise ValueError('unique positive depot IDs required')
  seen.add(ident)
  platform=d.get('platform')
  if platform not in ('windows','macos','linux'):raise ValueError('unsupported platform')
  content=Path(d.get('content_root','')).expanduser().resolve()
  if not content.is_dir():raise ValueError(f'missing content_root for {platform}')
  files=[p for p in content.rglob('*') if p.is_file()]
  if not files:raise ValueError('empty content directory')
  forbidden={'.env','.DS_Store','config.toml'}
  if any(p.name in forbidden or '.git' in p.parts or p.suffix in ('.zip','.vdf') for p in files):raise ValueError('content contains archive/config/private or upload files; stage only game payload')
  if platform=='windows' and not list(content.glob('*.exe')):raise ValueError('Windows executable missing')
  if platform=='linux' and not list(content.glob('*.x86_64')):raise ValueError('Linux executable missing')
  if platform=='macos' and not list(content.glob('*.app')):raise ValueError('macOS app missing')
  text=f'"DepotBuildConfig"\n{{\n "DepotID" "{ident}"\n "ContentRoot" "{vdf_string(content)}"\n "FileMapping"\n {{\n  "LocalPath" "*"\n  "DepotPath" "."\n  "recursive" "1"\n }}\n "FileExclusion" "*.pdb"\n}}\n'
  rendered.append((ident,text))
 output=Path(output).resolve();output.mkdir(parents=True,exist_ok=True)
 for ident,text in rendered:(output/f'depot_{ident}.vdf').write_text(text)
 maps='\n'.join(f'  "{ident}" "depot_{ident}.vdf"' for ident,_ in rendered)
 description=vdf_string(config.get('description','Under Two Skies reviewed build'))
 (output/'app_build.vdf').write_text(f'"AppBuild"\n{{\n "AppID" "{app}"\n "Desc" "{description}"\n "BuildOutput" "{vdf_string(output / "logs")}"\n "Preview" "1"\n "Depots"\n {{\n{maps}\n }}\n}}\n')
 return len(rendered)
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('config',type=Path);parser.add_argument('--out',required=True,type=Path);args=parser.parse_args()
 try: print(f'Generated {generate(json.loads(args.config.read_text()),args.out)} depot templates in Preview mode. No upload performed.')
 except (ValueError,OSError,KeyError) as e:parser.exit(1,f'Not generated: {e}\n')
