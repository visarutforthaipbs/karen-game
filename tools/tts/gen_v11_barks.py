"""GPU candidate generator: designed Thai voices plus existing Ta-poh voice.
Does not install or change the audio manager. Outputs ASR-QC'd mono WAVs.
Run with the existing laos-reel-tts Python; no extra voice models downloaded.
"""
import argparse,json,sys
from pathlib import Path
import numpy as np
import soundfile as sf
import torch
from omnivoice import OmniVoice
from transformers import pipeline
sys.path.insert(0,'/home/visarut298/laos-reel-tts')
from omnivoice_voiceover import cer
p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
model=OmniVoice.from_pretrained('hotdogs/omnivoice-thai',device_map='cuda:0',dtype=torch.float16)
asr=pipeline('automatic-speech-recognition',model='openai/whisper-large-v3-turbo',torch_dtype=torch.float16,device='cuda:0')
pop=model.create_voice_clone_prompt('/home/visarut298/laos-reel-tts/voices/pop-voice.wav')
lines=[('munaw_spot_fire','ไฟตกในป่า!','female, young adult, moderate pitch'),('munaw_fire_out','ดับแล้ว','female, young adult, moderate pitch'),('tapoh_whistle_reply','ได้ยินแล้ว กำลังไป',None),('ranger_patrol_radio','พบไฟในแนวป่า ขอรายงานศูนย์','male, middle-aged, moderate pitch')]
records=[]
for i,(name,text,voice) in enumerate(lines):
 best=None
 for take in range(4):
  torch.manual_seed(870+i*100+take)
  kwargs={'instruct':voice} if voice else {'voice_clone_prompt':pop}
  w=model.generate(text=text,language='th',**kwargs)[0].astype(np.float32)
  heard=asr({'raw':w,'sampling_rate':24000},generate_kwargs={'language':'th','task':'transcribe'})['text']
  score=cer(text,heard)
  if len(w)/24000<.3 or len(w)/24000>6:score+=1
  if best is None or score<best[0]:best=(score,w,heard,take)
  if score<=.03:break
 score,w,heard,take=best
 peak=float(np.max(np.abs(w)));w*=.85/max(peak,1e-9)
 fade=min(240,len(w)//4);w[:fade]*=np.linspace(0,1,fade);w[-fade:]*=np.linspace(1,0,fade)
 sf.write(a.out/(name+'.wav'),w,24000,subtype='PCM_16')
 row=dict(id=name,text=text,heard=heard,cer=score,take=take+1,seconds=len(w)/24000,voice=voice or 'existing Pop voice, same as A1',file=name+'.wav',status='candidate: listening review required')
 records.append(row);print(json.dumps(row,ensure_ascii=False),flush=True)
 (a.out/'manifest.json').write_text(json.dumps(dict(engine='hotdogs/omnivoice-thai',sample_rate=24000,records=records),ensure_ascii=False,indent=2))
