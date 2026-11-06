"""Copy supplied alternate artwork and package it as power-of-two WoW textures."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[1]
MEDIA = ROOT / 'Media' / 'Celebrations'
FILES = {
    'OrcMale': 'orc_male_rare.png', 'OrcFemale': 'orc_female_rare.png',
    'TrollMale': 'troll_male_rare.png', 'TrollFemale': 'troll_female_rare.png',
    'TaurenMale': 'tauren_male_rare.png', 'TaurenFemale': 'tauren_female_rare.png',
    'UndeadMale': 'undead_male_rare.png', 'UndeadFemale': 'undead_female_rare.png',
    'SkyborneMale': 'skyborn_male_rare.png', 'SkyborneFemale': 'skyborn_female_rare.png',
    'ForTheHorde': 'for_the_horde_rare.png',
}

def main(directory):
    sources = {name: directory / file for name, file in FILES.items()}
    missing = [str(path) for path in sources.values() if not path.is_file()]
    if missing: raise FileNotFoundError('\n'.join(missing))
    MEDIA.mkdir(exist_ok=True)
    assets = []
    sheet = Image.new('RGBA', (1120, 960), '#160d0a')
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.truetype('C:/Windows/Fonts/seguisb.ttf', 16)
    for i, (name, source) in enumerate(sources.items()):
        png = MEDIA / f'{name}Rare.png'
        shutil.copy2(source, png)
        with Image.open(png) as original:
            mode, dimensions = original.mode, original.size
            image = original.convert('RGBA')
        size = 1024 if name == 'ForTheHorde' else 512
        scaled = ImageOps.contain(image, (size, size), Image.Resampling.LANCZOS)
        texture = Image.new('RGBA', (size, size))
        texture.alpha_composite(scaled, ((size-scaled.width)//2, (size-scaled.height)//2))
        texture.save(MEDIA / f'{name}Rare.tga', compression=None)
        assets.append(dict(character=name, png=png.name, texture=f'{name}Rare.tga', source=png.name,
                           sourceMode=mode, sourceDimensions=dimensions, textureSize=size,
                           sourceSHA256=hashlib.sha256(source.read_bytes()).hexdigest()))
        x, y = (i%4)*280, (i//4)*320
        draw.rounded_rectangle((x+7,y+7,x+272,y+311), radius=8, fill='#291510', outline='#a074c7')
        thumb = ImageOps.contain(image, (256, 276), Image.Resampling.LANCZOS)
        sheet.alpha_composite(thumb, (x+(280-thumb.width)//2, y+13+(276-thumb.height)//2))
        label = name.replace('Female', ' female').replace('Male', ' male').replace('ForTheHorde', 'Thrall & Sylvanas')
        draw.text((x+140,y+294), label+' [Rare]', font=font, fill='#dfb6ff', anchor='mm')
        print(f'{name}Rare: {size}x{size}, original {dimensions}, {mode}')
    manifest = dict(origin='User-supplied artwork', chancePerCelebration=0.05, assets=assets)
    (MEDIA / 'RareArtworkManifest.json').write_text(json.dumps(manifest, indent=2)+'\n', encoding='utf-8')
    output = ROOT / 'tests' / 'output'
    output.mkdir(exist_ok=True)
    sheet.convert('RGB').save(output / 'rare-portrait-gallery.png')

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('source_directory', type=Path)
    main(parser.parse_args().source_directory)
