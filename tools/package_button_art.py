from pathlib import Path
import sys, shutil,json
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'.art-runtime'))
from PIL import Image, ImageDraw, ImageChops
src=Path(sys.argv[1]); root=ROOT/'Media'/'GratzButton';root.mkdir(exist_ok=True)
shutil.copy2(src,root/'Composition.png')
im=Image.open(src).convert('RGBA'); print(im.size,im.getextrema()[3])
for name,seed in [('Button',(300,800)),('Hand',(1100,400))]:
    mask=im.getchannel('A').point(lambda v:255 if v>10 else 0)
    ImageDraw.floodfill(mask,seed,128)
    selected=mask.point(lambda v:255 if v==128 else 0)
    box=selected.getbbox(); print(name,box)
    layer=im.copy();layer.putalpha(ImageChops.multiply(im.getchannel('A'),selected));layer=layer.crop(box)
    canvas=Image.new('RGBA',(512,512));layer.thumbnail((512,512),Image.Resampling.LANCZOS);canvas.alpha_composite(layer,((512-layer.width)//2,(512-layer.height)//2))
    canvas.save(root/(name+'.png'));canvas.save(root/(name+'.tga'),compression=None)
(root/'ArtworkManifest.json').write_text(json.dumps({'generator':'built-in image_gen','source':src.name,'correction':'Palm-side fingers have no visible nails; thumbnail retained.','composition':'Reference button lower left, raised hand upper right.','runtime':'Separated alpha components, aspect preserved in 512px square textures.'},indent=2))
