"""Render recorded Lua layout for visual QA. This is an approximation, not live WoW."""
from pathlib import Path
from functools import lru_cache
import json
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "tests" / "output"

def rgb(values, fallback=(220, 210, 193)):
    return tuple(int(max(0, min(1, c)) * 255) for c in values[:3]) if values else fallback

@lru_cache(None)
def font(size, title=False):
    path = Path('C:/Windows/Fonts/georgiab.ttf' if title else 'C:/Windows/Fonts/segoeui.ttf')
    return ImageFont.truetype(str(path), max(8, int(size)))

def render(tab):
    records = json.loads((OUT / f'{tab}-layout.json').read_text(encoding='utf-8'))
    by_id = {r['id']: r for r in records}
    root_name = 'GratzGuildCelebrationFrame' if tab == 'popup' else 'GratzGuildFrame'
    root = next(r for r in records if r.get('name') == root_name)

    @lru_cache(None)
    def visible(i):
        r = by_id[i]
        return r.get('shown', True) and (not r.get('parent') or visible(r['parent']))

    @lru_cache(None)
    def rect(i):
        r = by_id[i]
        w, h = r.get('width', 100), r.get('height', 30)
        if i == root['id']: return 0, 0, w, h
        if not r.get('parent'): return -470, -170, w, h
        if not r['points']:
            x, y, _, _ = rect(r['parent'])
            return x, y, w, h
        def anchor(point, relative, relpoint, dx, dy):
            x, y, rw, rh = rect(relative or r['parent'])
            if 'RIGHT' in relpoint: x += rw
            elif 'LEFT' not in relpoint: x += rw / 2
            if 'BOTTOM' in relpoint: y += rh
            elif 'TOP' not in relpoint: y += rh / 2
            return x + dx, y - dy
        point, relative, relpoint, dx, dy = r['points'][0]
        x, y = anchor(point, relative, relpoint, dx, dy)
        if len(r['points']) > 1 and point == 'TOPLEFT' and r['points'][1][0] == 'BOTTOMRIGHT':
            bx, by = anchor(*r['points'][1])
            w, h = bx - x, by - y
        else:
            if 'RIGHT' in point: x -= w
            elif 'LEFT' not in point: x -= w / 2
            if 'BOTTOM' in point: y -= h
            elif 'TOP' not in point: y -= h / 2
        return x, y, w, h

    image = Image.new('RGBA', (int(root['width']), int(root['height'])), '#110b09')
    draw = ImageDraw.Draw(image)
    for r in records:
        if not visible(r['id']): continue
        if r['kind'] in ('Animation', 'AnimationGroup', 'Root'): continue
        x, y, w, h = rect(r['id'])
        x, y, w, h = map(lambda v: int(round(v)), (x, y, w, h))
        if x + w <= 0 or y + h <= 0 or x >= image.width or y >= image.height: continue
        if r.get('background'):
            draw.rectangle((x, y, x + w - 1, y + h - 1), fill=rgb(r['background']), outline=rgb(r.get('border'), (70, 50, 28)))
        if r['kind'] == 'CheckButton':
            draw.rounded_rectangle((x + 3, y + 3, x + 20, y + 20), 2, fill='#21150e', outline='#aa7c3c')
            if r.get('checked'): draw.line([(x + 6, y + 11), (x + 10, y + 15), (x + 17, y + 7)], fill='#f3cc7d', width=2)
        if r['kind'] == 'Slider':
            if h > w:
                draw.rectangle((x + 6, y, x + 9, y + h), fill='#35251b')
                draw.rectangle((x + 2, y, x + 13, y + 28), fill='#956c36')
            else:
                draw.rectangle((x, y + 7, x + w, y + 10), fill='#68462a')
                draw.rectangle((x + int(w * .58) - 5, y + 1, x + int(w * .58) + 5, y + 16), fill='#ce9c4e')
        tex = r.get('texture')
        if tex and 'GratzGuild' in tex:
            name = tex.split('Media\\')[-1].replace('\\', '/')
            path = ROOT / 'Media' / f'{name}.tga'
            with Image.open(path) as source:
                art = source.convert('RGBA').resize((max(w, 1), max(h, 1)), Image.Resampling.LANCZOS)
                image.alpha_composite(art, (x, y))
        if r['kind'] not in ('FontString', 'EditBox') or not r.get('text'): continue
        size = r.get('fontSize', 12)
        face = font(size, size >= 23)
        color = rgb(r.get('textColor'))
        lines = []
        for paragraph in r['text'].split('\n'):
            line = ''
            for word in paragraph.split(' '):
                candidate = word if not line else line + ' ' + word
                if draw.textlength(candidate, font=face) > w and line:
                    lines.append(line); line = word
                else: line = candidate
            lines.append(line)
        text_layer = Image.new('RGBA', (max(w, 1), max(h, 1)))
        td = ImageDraw.Draw(text_layer)
        for n, line in enumerate(lines):
            tx = (w - td.textlength(line, font=face)) / 2 if r.get('justifyH') == 'CENTER' else 0
            td.text((tx, n * (size + 3) - 2), line, font=face, fill=color)
        image.alpha_composite(text_layer, (x, y))
    path = OUT / f'{tab}-preview.png'
    image.convert('RGB').save(path)
    print(path)

if __name__ == '__main__':
    for tab in ('ledger', 'announcements', 'celebrations', 'collection', 'settings', 'popup'): render(tab)
