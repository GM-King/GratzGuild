"""Index the supplied Horde sounds, deduplicate identical copies and measure clip lengths."""
from pathlib import Path
import hashlib
import json
import struct

ROOT = Path(__file__).resolve().parents[1]
KINDS = ('BloodElfFemale', 'BloodElfMale', 'OrcFemale', 'OrcMale', 'TaurenFemale', 'TaurenMale',
         'TrollFemale', 'TrollMale', 'UndeadFemale', 'UndeadMale')
LABELS = {'BloodElfFemale': 'Skyborne female', 'BloodElfMale': 'Skyborne male',
          **{k: k.replace('Female', ' female').replace('Male', ' male') for k in KINDS if not k.startswith('BloodElf')}}

def ogg_duration(raw):
    packet = raw.find(b'\x01vorbis')
    if packet < 0: raise ValueError('Missing Vorbis identification packet')
    rate = struct.unpack_from('<I', raw, packet + 12)[0]
    pos, last = 0, 0
    while pos < len(raw):
        if raw[pos:pos+4] != b'OggS': raise ValueError('Invalid Ogg page')
        granule = struct.unpack_from('<Q', raw, pos + 6)[0]
        if granule < 2**63: last = max(last, granule)
        count = raw[pos + 26]
        pos += 27 + count + sum(raw[pos+27:pos+27+count])
    return last / rate

def mp3_duration(raw):
    pos = 0
    if raw.startswith(b'ID3'):
        size = sum((value & 127) << (21 - 7*i) for i, value in enumerate(raw[6:10]))
        pos = 10 + size + (10 if raw[5] & 16 else 0)
    duration, frames = 0, 0
    while pos + 4 <= len(raw):
        header = int.from_bytes(raw[pos:pos+4], 'big')
        version, layer = (header >> 19) & 3, (header >> 17) & 3
        bitrate_index, rate_index = (header >> 12) & 15, (header >> 10) & 3
        if header & 0xFFE00000 != 0xFFE00000 or version == 1 or layer != 1 or bitrate_index in (0, 15) or rate_index == 3:
            pos += 1
            continue
        rates = [44100, 48000, 32000]
        rate = rates[rate_index] // (1 if version == 3 else 2 if version == 2 else 4)
        table = ([0,32,40,48,56,64,80,96,112,128,160,192,224,256,320,0] if version == 3
                 else [0,8,16,24,32,40,48,56,64,80,96,112,128,144,160,0])
        length = (144000 if version == 3 else 72000) * table[bitrate_index] // rate + ((header >> 9) & 1)
        if pos + length > len(raw): break
        duration += (1152 if version == 3 else 576) / rate
        frames += 1
        pos += length
    if not frames: raise ValueError('No MPEG Layer III frames found')
    return duration

def entry(path):
    raw = path.read_bytes()
    kind = next((kind for kind in KINDS if kind in path.name), None)
    if path.name in ('for_the_horde.mp3', 'for_the_horde_rare.mp3'): portrait, label = 'ForTheHorde', 'Thrall & Sylvanas'
    elif kind:
        portrait, label = kind.replace('BloodElf', 'Skyborne'), LABELS[kind]
    else: raise ValueError(f'Unrecognized Horde voice: {path.name}')
    duration = ogg_duration(raw) if path.suffix == '.ogg' else mp3_duration(raw)
    if not 0 < duration < 300: raise ValueError(f'Invalid duration for {path.name}: {duration}')
    return dict(file=str(path.relative_to(ROOT)).replace('/', '\\'), portrait=portrait, label=label,
                duration=round(duration, 3), sha256=hashlib.sha256(raw).hexdigest())

def lua_string(value): return json.dumps(value, ensure_ascii=False)

def main():
    catalog, duplicates = {}, []
    for group in ('cheer', 'congrats'):
        catalog[group], seen = [], {}
        # Prefer original filenames to the identical '(1)' copies.
        paths = sorted((ROOT / 'sounds' / group).glob('*.ogg'), key=lambda p: ('(1)' in p.name, p.name))
        for path in paths:
            sound = entry(path)
            if sound['sha256'] in seen:
                duplicates.append(dict(file=sound['file'], original=seen[sound['sha256']]))
                continue
            seen[sound['sha256']] = sound['file']
            catalog[group].append(sound)
    catalog['buttonHit'] = dict(file='sounds\\ParryWoodHitWood.ogg', portrait='', label='Gratz button impact', duration=round(ogg_duration((ROOT/'sounds'/'ParryWoodHitWood.ogg').read_bytes()),3))
    catalog['horde'] = entry(ROOT / 'sounds' / 'for_the_horde.mp3')
    catalog['hordeRare'] = entry(ROOT / 'sounds' / 'for_the_horde_rare.mp3')
    (ROOT / 'Media' / 'SoundCatalog.json').write_text(json.dumps(dict(catalog=catalog, duplicates=duplicates), indent=2), encoding='utf-8')
    lines = ['-- Generated from the supplied sounds by tools/build_sound_catalog.py.', 'local _, GG = ...', 'GG.Sounds = {']
    def row(sound):
        return '{ file = %s, portrait = %s, label = %s, duration = %s }' % tuple(
            lua_string(sound[key]) if key != 'duration' else str(sound[key]) for key in ('file', 'portrait', 'label', 'duration'))
    for group in ('cheer', 'congrats'):
        lines.append('    %s = {' % group)
        lines.extend('        ' + row(sound) + ',' for sound in catalog[group])
        lines.append('    },')
    lines.append('    buttonHit = ' + row(catalog['buttonHit']) + ',')
    lines.extend(['    horde = ' + row(catalog['horde']) + ',', '    hordeRare = ' + row(catalog['hordeRare']) + ',', '}'])
    (ROOT / 'SoundCatalog.lua').write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print(f"{len(catalog['cheer'])} cheer clips, {len(catalog['congrats'])} congratulations clips, {len(duplicates)} identical copies omitted")
    print(f"For the Horde duration: {catalog['horde']['duration']} seconds")
    print(f"Rare Horde duration: {catalog['hordeRare']['duration']} seconds")

if __name__ == '__main__': main()
