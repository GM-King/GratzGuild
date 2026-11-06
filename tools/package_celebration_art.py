"""Package selected generated images as WoW textures and a labelled QA contact sheet."""
from pathlib import Path
import json
import shutil
from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[1]
MEDIA = ROOT / 'Media' / 'Celebrations'

def main():
    manifest = json.loads((MEDIA / 'ArtworkManifest.json').read_text(encoding='utf-8'))
    sheet = Image.new('RGBA', (1120, 960), '#160d0a')
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.truetype('C:/Windows/Fonts/seguisb.ttf', 16)
    for i, asset in enumerate(manifest['assets']):
        name = asset['name']
        if not name.isalpha(): raise ValueError('Unexpected asset name')
        target = MEDIA / f'{name}.png'
        source = Path(asset['source'])
        if not source.is_absolute(): source = MEDIA / source
        if source.exists() and source.resolve() != target.resolve(): shutil.copy2(source, target)
        original = Image.open(target).convert('RGBA')
        size = 1024 if name == 'ForTheHorde' else 512
        texture = Image.new('RGBA', (size, size))
        scaled = ImageOps.contain(original, (size, size), Image.Resampling.LANCZOS)
        texture.alpha_composite(scaled, ((size - scaled.width)//2, (size - scaled.height)//2))
        texture.save(MEDIA / f'{name}.tga', compression=None)
        x, y = (i % 4) * 280, (i // 4) * 320
        draw.rounded_rectangle((x+7, y+7, x+272, y+311), radius=8, fill='#291510', outline='#8c6136', width=1)
        thumb = ImageOps.contain(original, (256, 276), Image.Resampling.LANCZOS)
        sheet.alpha_composite(thumb, (x+(280-thumb.width)//2, y+13+(276-thumb.height)//2))
        label = name.replace('Female', ' female').replace('Male', ' male').replace('ForTheHorde', 'Thrall & Sylvanas')
        draw.text((x+140, y+294), label, font=font, fill='#ffd28a', anchor='mm')
        print(f'{name}: {size}x{size}, RGBA, transparent TGA')
    output = ROOT / 'tests' / 'output'
    output.mkdir(exist_ok=True)
    sheet.convert('RGB').save(output / 'portrait-gallery.png')

if __name__ == '__main__': main()
