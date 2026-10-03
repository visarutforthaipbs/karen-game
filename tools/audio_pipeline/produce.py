"""Run an explicit ElevenLabs MCP job manifest, with a durable credit ledger.
No retries of ambiguous paid calls. Resume skips completed jobs and stops on
pending/uncertain calls rather than silently paying twice. Credentials are read
from the local Codex MCP config and are never written to the manifest.
"""
import argparse, asyncio, json, os, tomllib, time, subprocess, urllib.request, urllib.error
from pathlib import Path
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

async def run(args):
    plan=json.loads(Path(args.plan).read_text()); base=Path(plan['output_directory']).resolve(); base.mkdir(parents=True,exist_ok=True)
    ledger_path=base/'ledger.json'; ledger=json.loads(ledger_path.read_text()) if ledger_path.exists() else {'jobs':{},'initial_used':None}
    config=tomllib.loads((Path.home()/'.codex/config.toml').read_text())['mcp_servers']['elevenlabs']
    env=dict(os.environ); env.update(config['env'])
    def save():
        temp=ledger_path.with_suffix('.tmp'); temp.write_text(json.dumps(ledger,ensure_ascii=False,indent=2));temp.replace(ledger_path)
    async with stdio_client(StdioServerParameters(command=config['command'],env=env)) as (read,write):
      async with ClientSession(read,write) as session:
        await session.initialize()
        usage_cache={"value":ledger.get("final_used",ledger.get("initial_used")),"time":0.0}
        async def usage(force=False):
            if not force and usage_cache["value"] is not None and time.monotonic()-usage_cache["time"]<65:
                return usage_cache["value"]
            def read_usage():
                req=urllib.request.Request('https://api.elevenlabs.io/v1/user/subscription',headers={'xi-api-key':env['ELEVENLABS_API_KEY']})
                return json.load(urllib.request.urlopen(req,timeout=30))['character_count']
            for attempt in range(3):
                try:
                    value=await asyncio.to_thread(read_usage);usage_cache.update(value=value,time=time.monotonic());return value
                except urllib.error.HTTPError as e:
                    if e.code!=429:raise
                    await asyncio.sleep(5*(attempt+1))
            if usage_cache['value'] is not None:return usage_cache['value']
            raise RuntimeError('Subscription unavailable after read-only retries')
        start=await usage()
        if ledger['initial_used'] is None: ledger['initial_used']=start;save()
        for job in plan['jobs']:
            key=job['id'];previous=ledger['jobs'].get(key)
            if previous:
                if previous['status']=='complete':continue
                if previous['status'] in ['pending','uncertain']:
                    recovered=list((base/'raw'/key).glob('*.mp3'))
                    if len(recovered)==1 and subprocess.run(['ffprobe','-v','error',str(recovered[0])],capture_output=True).returncode==0:
                        previous.update(status='complete',files=[str(recovered[0])],recovered_existing_output=True);save();continue
                    raise RuntimeError(f'{key}: review uncertain request before resuming')
                if not args.retry_failed:continue
            before=await usage()
            if before-ledger['initial_used']>=plan['credit_cap']:raise RuntimeError('Credit cap reached')
            folder=base/'raw'/key;folder.mkdir(parents=True,exist_ok=True)
            params=dict(job['arguments']);params['output_directory']=str(folder)
            ledger['jobs'][key]={'status':'pending','tool':job['tool'],'arguments':params,'used_before':before};save()
            print(f'GENERATE {key}',flush=True)
            try:
                if job['tool']=='text_to_sound_effects':
                    body={k:v for k,v in params.items() if k not in ['output_directory','output_format']}
                    body['model_id']='eleven_text_to_sound_v2'
                    def generate():
                        req=urllib.request.Request('https://api.elevenlabs.io/v1/sound-generation?output_format=mp3_44100_128',data=json.dumps(body).encode(),headers={'xi-api-key':env['ELEVENLABS_API_KEY'],'Content-Type':'application/json'})
                        with urllib.request.urlopen(req,timeout=180) as response:
                            data=response.read();request_id=response.headers.get('request-id');charged=response.headers.get('character-cost')
                        (folder/(key+'.mp3')).write_bytes(data)
                        return request_id,charged
                    request_id,charged=await asyncio.to_thread(generate)
                    ledger['jobs'][key].update(transport='official REST v2 (MCP has obsolete 5-second validation)',request_id=request_id,reported_character_cost=charged)
                    messages=['Audio saved'];failed=False
                else:
                    result=await session.call_tool(job['tool'],params)
                    messages=[c.text for c in result.content if c.type=='text'];failed=result.isError
                if failed:
                    explicit_rejection=any('Duration must' in m or 'status_code: 400' in m or 'status_code: 401' in m or 'status_code: 403' in m or 'status_code: 429' in m for m in messages)
                    status='failed' if explicit_rejection else 'uncertain'
                    ledger['jobs'][key].update(status=status,messages=messages);save();print(f'{status.upper()} {key}: {messages}',flush=True)
                    if not explicit_rejection:raise RuntimeError('Ambiguous paid request: review before resuming')
                    continue
                paths=sorted(str(p) for p in folder.rglob('*') if p.suffix.lower() in ['.wav','.mp3','.flac'])
                if not paths:raise RuntimeError(f'No audio output: {messages}')
                await asyncio.sleep(1)
                after=await usage()
                ledger['jobs'][key].update(status='complete',files=paths,messages=messages,used_after=after,observed_account_delta=after-before);save()
                print(f'DONE {key}: observed account usage +{after-before}; since batch start +{after-ledger["initial_used"]}',flush=True)
            except Exception:
                ledger['jobs'][key]['status']='uncertain';save();raise
        ledger['final_used']=await usage(force=True);save()

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('plan');p.add_argument('--retry-failed',action='store_true');args=p.parse_args();asyncio.run(run(args))
