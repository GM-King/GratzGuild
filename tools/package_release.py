"""Build an installable release from the TOC and runtime asset references."""
from pathlib import Path
import re, zipfile, hashlib
ROOT = Path(__file__).resolve().parents[1]
def main():
    version = re.search(r"^## Version: (.+)$", (ROOT/'GratzGuild.toc').read_text(), re.M)[1].strip()
    files = {ROOT/'GratzGuild.toc', ROOT/'README.md'}
    for line in (ROOT/'GratzGuild.toc').read_text().splitlines():
        if line.strip() and not line.startswith('#'): files.add(ROOT/line.strip())
    files.add(ROOT/'sounds'/'ParryWoodHitWood.ogg')
    files.update((ROOT/'Media'/'GratzButton').glob('*.png'))
    files.add(ROOT/'Media'/'GratzButton'/'ArtworkManifest.json')
    files.update((ROOT/'Media').rglob('*.tga'))
    for sound in re.findall(r'file = "([^"]+)"', (ROOT/'SoundCatalog.lua').read_text()):
        files.add(ROOT/sound.replace(chr(92), '/'))
    out = ROOT/'releases'; out.mkdir(exist_ok=True)
    archive = out/f'GratzGuild-{version}.zip'
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for p in sorted(files):
            if not p.is_file(): raise FileNotFoundError(p)
            z.write(p, 'GratzGuild/'+p.relative_to(ROOT).as_posix())
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    (out/(archive.name+'.sha256')).write_text(digest+'  '+archive.name+'\n')
    print(archive, archive.stat().st_size, digest)
if __name__ == '__main__': main()
