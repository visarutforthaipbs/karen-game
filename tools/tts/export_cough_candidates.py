"""Deterministic character cough cues, derived from AudioManager's stylized synth.
These are synthetic review candidates, not human recordings or cloned voices.
"""
import argparse,json,math,random,wave,struct
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('output',type=Path);a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
rate=24000;records=[]
for index,(name,pitch) in enumerate([('khanae',165),('tapoh',135),('munaw',215),('maelu',185),('ranger',155)]):
 rng=random.Random(451+index);data=[0.0]*int(rate*.8)
 for start in [0,.26,.5]:
  low=0
  for i in range(int(.22*rate)):
   t=i/rate;low=low*.75+rng.uniform(-1,1)*.25
   env=min(t/.015,1)*math.exp(-t*14)
   data[int(start*rate)+i]+=(low*2.5+math.sin(math.tau*pitch*t)*.3)*env
 peak=max(abs(v) for v in data);data=[v*.7/peak for v in data]
 filename=name+'_cough.wav'
 with wave.open(str(a.output/filename),'wb') as w:
  w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate);w.writeframes(b''.join(struct.pack('<h',round(v*32767)) for v in data))
 records.append(dict(file=filename,seconds=.8,peak=.7,pitch_hz=pitch,seed=451+index,status='candidate: listening review required'))
(a.output/'cough_manifest.json').write_text(json.dumps(dict(source='AudioManager._cough synthesis, distinct deterministic seeds and fundamental pitches',sample_rate=rate,records=records),indent=2)+'\n')
