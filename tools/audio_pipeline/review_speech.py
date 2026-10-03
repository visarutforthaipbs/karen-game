"""Check generated Thai wording with Scribe; keep performance review separate."""
import asyncio,json,os,re,tomllib,unicodedata,sys
from pathlib import Path
from mcp import ClientSession,StdioServerParameters
from mcp.client.stdio import stdio_client

def clean(s):return ''.join(c for c in unicodedata.normalize('NFC',s) if c.isalnum() or '\u0e00'<=c<='\u0e7f')
def distance(a,b):
    row=list(range(len(b)+1))
    for i,c in enumerate(a,1):
        new=[i]
        for j,d in enumerate(b,1):new.append(min(new[-1]+1,row[j]+1,row[j-1]+(c!=d)))
        row=new
    return row[-1]
async def main():
    plan=json.loads(Path(sys.argv[1] if len(sys.argv)>1 else 'tools/audio_pipeline/voice_plan.json').read_text());base=Path(plan['output_directory']);ledger=json.loads((base/'ledger.json').read_text());path=base/'speech_review.json';reviews=json.loads(path.read_text()) if path.exists() else {}
    cfg=tomllib.loads((Path.home()/'.codex/config.toml').read_text())['mcp_servers']['elevenlabs'];env=dict(os.environ);env.update(cfg['env']);env['ELEVENLABS_MCP_BASE_PATH']=str(Path.cwd().resolve())
    async with stdio_client(StdioServerParameters(command=cfg['command'],env=env)) as (r,w):
      async with ClientSession(r,w) as session:
        await session.initialize()
        for job in plan['jobs']:
            key=job['id'];spec=job['install'];record=ledger['jobs'].get(key,{})
            if not spec.get('speech') or key in reviews or record.get('status')!='complete':continue
            result=await session.call_tool('speech_to_text',{'input_file_path':record['files'][0],'language_code':'tha','save_transcript_to_file':False,'return_transcript_to_client_directly':True})
            heard=' '.join(c.text for c in result.content if c.type=='text')
            if result.isError:raise RuntimeError(heard)
            expected=spec['text'];cer=distance(clean(expected),clean(heard))/max(len(clean(expected)),1)
            reviews[key]={'expected':expected,'heard':heard,'cer':round(cer,4),'accepted':not result.isError and cer<=.10,'review':'ASR wording only; native listening/acting review remains open'}
            path.write_text(json.dumps(reviews,ensure_ascii=False,indent=2));print(key,round(cer,3),heard,flush=True)
asyncio.run(main())
