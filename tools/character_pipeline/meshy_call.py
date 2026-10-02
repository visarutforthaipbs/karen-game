#!/usr/bin/env python3
"""Call the locally installed official Meshy MCP, keeping credentials out of jobs/logs.

Usage: meshy_call.py request.json result.json
Request: {"tool": "meshy_...", "arguments": {...}}
Never retries a submitted operation. Inspect saved results before resubmitting.
"""
import json
import os
from pathlib import Path
import subprocess
import sys
import tomllib

def main():
    request, output = map(lambda p: Path(p).resolve(), sys.argv[1:])
    if output.exists():
        raise SystemExit('Result already exists; inspect it before retrying.')
    config = tomllib.loads((Path.home()/'.codex/config.toml').read_text())['mcp_servers']['meshy']
    environment = dict(os.environ)
    environment.update(config.get('env', {}))
    environment['MESHY_REQUEST'] = str(request)
    environment['MESHY_OUTPUT'] = str(output)
    environment['MESHY_COMMAND'] = config['command']
    environment['MESHY_ARGS'] = json.dumps(config['args'])
    code = r'''
import fs from 'node:fs';
import {Client} from './node_modules/@modelcontextprotocol/sdk/dist/esm/client/index.js';
import {StdioClientTransport} from './node_modules/@modelcontextprotocol/sdk/dist/esm/client/stdio.js';
const req = JSON.parse(fs.readFileSync(process.env.MESHY_REQUEST,'utf8'));
const client = new Client({name:'satellite-shadow-character-pipeline',version:'1.0.0'});
const transport = new StdioClientTransport({command:process.env.MESHY_COMMAND,args:JSON.parse(process.env.MESHY_ARGS),env:{PATH:process.env.PATH,MESHY_API_KEY:process.env.MESHY_API_KEY,TRANSPORT:'stdio'},stderr:'pipe'});
try {
  await client.connect(transport);
  const result = await client.callTool({name:req.tool,arguments:req.arguments ?? {}},undefined,{timeout:180000});
  fs.writeFileSync(process.env.MESHY_OUTPUT,JSON.stringify(result,null,2));
  console.log(JSON.stringify({saved:process.env.MESHY_OUTPUT,isError:result.isError??false}));
  if(result.isError) process.exitCode=1;
} catch(e) {
  console.error('MCP call failed; inspect task history before resubmission. '+String(e.message).replaceAll(process.env.MESHY_API_KEY,'[REDACTED]'));
  process.exitCode=1;
} finally { await client.close(); }
'''
    result = subprocess.run([config['command'],'--input-type=module'],input=code,
                            text=True,cwd=config['cwd'],env=environment)
    raise SystemExit(result.returncode)

if __name__ == '__main__':
    main()
