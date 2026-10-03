#!/usr/bin/env python3
"""Verify published installers by streaming every byte and checking HTTP behavior.

Requires curl. Reads a local final release-manifest.json and never uploads data.
"""
import argparse
import concurrent.futures
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
from urllib.parse import urlsplit


def request(url, directory, *options):
    headers = directory / 'headers.txt'
    result = subprocess.run(
        ['curl', '--silent', '--show-error', '--location', '--connect-timeout', '20',
         '--max-time', '300', '--dump-header', str(headers), *options, url],
        check=True, capture_output=True,
    )
    blocks = headers.read_text().replace('\r\n', '\n').strip().split('\n\n')
    lines = next(block for block in reversed(blocks) if block.startswith('HTTP/')).splitlines()
    status = int(lines[0].split()[1])
    fields = dict(line.split(':', 1) for line in lines[1:] if ':' in line)
    return status, {key.lower(): value.strip() for key, value in fields.items()}, result.stdout


def verify_file(item, base, prefix, build):
    name = item['download_name']
    assert name == Path(name).name and name.endswith('.zip'), 'unsafe archive name'
    url = f'{base}/{prefix}/{name}'
    with tempfile.TemporaryDirectory(prefix='undertwoskies-download-qa-') as scratch:
        directory = Path(scratch)
        status, headers, body = request(url, directory, '--head', '--fail')
        assert status == 200 and int(headers['content-length']) == item['bytes'], 'HEAD differs'
        assert name in headers.get('content-disposition', ''), 'attachment filename differs'
        status, ranged_headers, body = request(url, directory, '--range', '0-63', '--fail')
        assert status == 206 and ranged_headers['content-range'] == f"bytes 0-63/{item['bytes']}", 'Range differs'
        local_file = build / item['file']
        assert local_file.parent == build and len(body) == 64, 'unexpected range payload'
        with local_file.open('rb') as local:
            assert body == local.read(64), 'remote range bytes differ'
        status, _, body = request(url, directory, '--header', 'If-None-Match: ' + headers['etag'])
        assert status == 304 and not body, 'conditional request differs'
        process = subprocess.Popen(
            ['curl', '--fail', '--silent', '--show-error', '--location', '--connect-timeout',
             '20', '--max-time', '300', url], stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        )
        digest = hashlib.sha256()
        size = 0
        for chunk in iter(lambda: process.stdout.read(1024 * 1024), b''):
            size += len(chunk)
            digest.update(chunk)
        error = process.stderr.read().decode(errors='replace')
        assert process.wait() == 0, error
        assert size == item['bytes'] and digest.hexdigest() == item['sha256'], 'full download differs'
        return {'platform': item['platform'], 'download_name': name, 'bytes': size,
                'sha256': digest.hexdigest(), 'head': 200, 'range': 206, 'conditional': 304}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('manifest', type=Path)
    parser.add_argument('--origin', required=True)
    parser.add_argument('--prefix', default='beta3')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    base = args.origin.rstrip('/')
    assert urlsplit(base).scheme == 'https' and urlsplit(base).path in ['', '/'], 'expected HTTPS origin'
    assert args.prefix.isalnum(), 'unsafe prefix'
    manifest = json.loads(args.manifest.read_text())
    build = args.manifest.resolve().parent
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        results = list(pool.map(lambda item: verify_file(item, base, args.prefix, build), manifest['files']))
    with tempfile.TemporaryDirectory() as scratch:
        status, _, _ = request(base + '/beta2/UnderTwoSkies-macOS.zip', Path(scratch), '--head', '--fail')
        assert status == 200, 'previous release unavailable'
    report = {'origin': base, 'version': manifest['version'], 'commit': manifest['commit'],
              'files': results, 'previous_beta2_head': status}
    args.output.write_text(json.dumps(report, indent=2) + '\n')
    for result in results:
        print(f"PASS {result['platform']}: full SHA-256, byte count, HEAD, Range and ETag")
    print('PASS previous beta2 link preserved')


if __name__ == '__main__':
    main()
