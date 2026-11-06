"""Package generated art as uncompressed, power-of-two, 32-bit TGA textures."""
from pathlib import Path
import argparse
import shutil
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]

def convert(source, name, size):
    source = Path(source)
    target = ROOT / "Media"
    target.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target / f"{name}.png")
    im = Image.open(source).convert("RGBA")
    im = im.resize(size, Image.Resampling.LANCZOS)
    im.save(target / f"{name}.tga", compression=None)
    return im

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("murloc")
    parser.add_argument("horde")
    args = parser.parse_args()
    murloc = convert(args.murloc, "Murloc", (512, 512))
    convert(args.horde, "Horde", (1024, 512))
    murloc.resize((64, 64), Image.Resampling.LANCZOS).save(ROOT / "Media" / "MurlocIcon.tga", compression=None)
    for name in ("Murloc", "Horde", "MurlocIcon"):
        with Image.open(ROOT / "Media" / f"{name}.tga") as image:
            print(f"{name}: {image.size}, {image.mode}, alpha range {image.getextrema()[3]}")
