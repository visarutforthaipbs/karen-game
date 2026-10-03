#!/usr/bin/env python3
"""Validate the shipped bilingual catalog against quoted game UI/source text.

This is a coverage gate, not a substitute for human translation/cultural review.
No dependencies. Comments are excluded; runtime-derived keys need runtime tests.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
THAI = re.compile(r'[\u0e00-\u0e7f]')
PRINTF = re.compile(r'%(?:[-+0#]*\d*(?:\.\d+)?[sdifoxXc]|%)')
# The switch must remain identifiable in either language.
BILINGUAL = {'ภาษา / Language', 'ไทย / English', 'ไทย'}


def quoted_strings(source):
    token = re.compile(r'#.*?$|"""[\s\S]*?"""|\'\'\'[\s\S]*?\'\'\'|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'', re.M)
    for match in token.finditer(source):
        raw = match.group()
        if raw.startswith('#'):
            continue
        triple = raw.startswith(('"""', "'''"))
        value = raw[3:-3] if triple else raw[1:-1]
        value = re.sub(r'\\([ntr"\'\\])', lambda m: {'n':'\n','t':'\t','r':'\r'}.get(m[1],m[1]), value)
        yield value, source.count('\n', 0, match.start()) + 1


def validate():
    entries = json.loads((ROOT / 'localization/messages.json').read_text())
    ids = set()
    phrases = {}
    failures = []
    for entry in entries:
        key, source, target = entry['id'], entry['th'], entry['en']
        if key in ids or source in phrases:
            failures.append(f'Duplicate ID/source: {key}')
        ids.add(key)
        phrases[source] = target
        if not source.strip() or not target.strip() or THAI.search(target):
            failures.append(f'Empty or mixed English translation: {key}')
        if PRINTF.findall(source) != PRINTF.findall(target):
            failures.append(f'Format arguments differ: {key}: {PRINTF.findall(source)} != {PRINTF.findall(target)}')
    voice_catalog = json.loads((ROOT / 'localization/voice_subtitles.json').read_text())
    voice_plan = json.loads((ROOT / 'tools/audio_pipeline/english_voice_plan.json').read_text())
    english_jobs = {job['source_caption']: job for job in voice_plan['jobs']}
    if len(english_jobs) != len(voice_plan['jobs']) or set(english_jobs) != set(voice_catalog):
        failures.append('English voice plan must contain exactly one job for every recorded subtitle')
    for filename, entry in voice_catalog.items():
        if not (ROOT / 'assets/audio' / filename).is_file():
            failures.append(f'Subtitle references missing recording: {filename}')
        if not (ROOT / 'assets/audio/en' / filename).is_file():
            failures.append(f'Missing English counterpart: {filename}')
        job = english_jobs.get(filename, {})
        if (job.get('arguments', {}).get('text') != entry.get('en')
                or job.get('install', {}).get('text') != entry.get('en')
                or job.get('install', {}).get('file') != 'en/' + filename):
            failures.append(f'English voice plan/subtitle differ: {filename}')
        for thai_key, english_key in [('th', 'en'), ('speaker', 'speaker_en')]:
            if not entry.get(thai_key, '').strip() or not entry.get(english_key, '').strip() or THAI.search(entry.get(english_key, '')):
                failures.append(f'Empty or mixed subtitle translation: {filename} {english_key}')
    scanned = 0
    for path in sorted(list((ROOT/'ui').glob('*.gd')) + list((ROOT/'scripts').glob('*.gd'))):
        for source, line in quoted_strings(path.read_text()):
            if not THAI.search(source) or source in BILINGUAL:
                continue
            scanned += 1
            if source not in phrases:
                failures.append(f'Missing translation {path.relative_to(ROOT)}:{line}: {source!r}')
    for failure in failures:
        print('FAIL', failure)
    print(f'{len(entries)} entries + {len(voice_catalog)} voice clips; {scanned} Thai source literals checked; {len(failures)} issues')
    return bool(failures)

if __name__ == '__main__':
    raise SystemExit(validate())
