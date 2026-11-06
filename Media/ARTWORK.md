# GratzGuild artwork

Generated using the **built-in image-generation tool**, with transparent backgrounds, on 14 October 2026. Original generated files were copied into this addon; the runtime textures preserve their alpha and use uncompressed 32-bit TGA encoding.

| Asset | Runtime file | Size |
| --- | --- | --- |
| Celebrating murloc | `Murloc.tga` | 512 × 512 |
| Horde group | `Horde.tga` | 1024 × 512 |
| Minimap murloc | `MurlocIcon.tga` | 64 × 64 |

Original artwork is preserved as `Murloc.png` and `Horde.png`. The minimap icon is a reduced version of the murloc.

## Celebration illustrations added in 1.1.0

The built-in image-generation tool created **eleven** additional transparent illustrations in the same painted Warcraft style. Each has an original PNG and a game texture under `Celebrations/`:

- `OrcMale`: sly cowboy orc tipping his hat.
- `OrcFemale`: exuberant orc heroine with red braids.
- `TrollMale`: cheeky male troll with a swept red mohawk.
- `TrollFemale`: playful winking troll with a tropical flower.
- `TaurenMale`: effeminate male tauren with blushed cheeks and a coy smile.
- `TaurenFemale`: welcoming tauren with flowers in her braids.
- `UndeadMale`: dapper Forsaken tipping his top hat.
- `UndeadFemale`: amused gothic Forsaken making a celebratory toast.
- `SkyborneMale`: blue elf with silver hair, gold eyes and arcane markings.
- `SkyborneFemale`: glamorous adult blue elf with a voluptuous figure, ornate ivory-and-gold bodice and crimson sash.
- `ForTheHorde`: full-body Thrall with one Doomhammer held overhead and Sylvanas posing beside his leg.

The ten individual portraits use **512 × 512**, uncompressed **32-bit TGA** textures; the finale uses **1024 × 1024**. Transparent alpha is retained. The original Horde and murloc illustrations were style references; the supplied blue-elf image defined the Skyborne appearance, and the supplied movie poster defined the finale's heroic pose. The finale's final edit corrected two generated hammers into one vertical Doomhammer held in both hands.

The complete prompt for each image, and the finale's final correction prompt, are preserved verbatim in [Celebrations/ArtworkManifest.json](Celebrations/ArtworkManifest.json). The selected original PNGs live alongside their TGA files in that folder. A labelled QA gallery is saved as `tests/output/portrait-gallery.png`.

## Rare celebration variants

The rare celebration variants added in **1.1.1** are user-supplied artwork, not newly generated illustrations. All eleven original PNGs are copied without changing their bytes and packaged as aspect-preserving TGA textures under `Celebrations/`, using the matching character name plus `Rare`. `Celebrations/RareArtworkManifest.json` records their source filenames and checksums. A labelled gallery is saved as `tests/output/rare-portrait-gallery.png`. Alpha is retained where provided; the male tauren's supplied RGB image retains its opaque background.

## Final murloc prompt

Use case: stylized-concept. Asset type: transparent mascot texture for a World of Warcraft addon called GratzGuild. Primary request: an adorable painted Warcraft murloc celebrating a level-up, huge expressive eyes, teal-green scales, orange dorsal fins, joyful grin, both arms raised, tiny crimson-and-gold Horde party pennant, a few golden confetti pieces. Style: polished hand-painted fantasy game illustration, cute but recognizably Warcraft, warm highlights, rich colours, clean silhouette. Composition: single full-body murloc centred, fills a square canvas, generous clear margin, no cropping of limbs or fins. Transparent background, no shadows beyond the character, no text, no watermark, no UI elements. Must remain readable at 160 pixels tall.

## Final Horde prompt

Use case: stylized-concept. Asset type: transparent wide character-group illustration for a Warcraft addon GratzGuild. Primary request: three adorable adult Horde adventurers cheering together: a green orc woman with tusks and dark braided hair in crimson leather armour, a cheerful blue troll man with tusks and swept-back red hair, and a fluffy friendly brown tauren with horns and gold-trimmed shoulder armour. Polished hand-painted Warcraft fantasy game art, cute warm expressive faces, celebratory pose, small golden confetti, coordinated crimson and gold outfits. Composition: horizontal tightly grouped waist-up ensemble with all heads horns and hands fully inside frame, character group fills a wide 2:1 canvas. Transparent background, no text, no watermark, no scenery or UI. High-quality brushwork and clean silhouettes readable at 300px wide.
