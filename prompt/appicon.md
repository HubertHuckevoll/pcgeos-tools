## Application icon creation / update

Create / Update and integrate the PC/GEOS application icons for the application
mentioned in the prompt. Use the two supplied images:

- Big image: source for every file/application icon, including color,
  monochrome, VGA, MCGA, EGA, HGC, CGA and any additional file-icon sizes.
- Small image: source for every tool icon. Do not derive tool icons from
  the big image.

### Composition and transparency

The big-image composition must retain the displayed proportions of a
48 by 30 image, or 8:5. This is a visual aspect-ratio requirement, not a
requirement that every output bitmap contain exactly 48 by 30 pixels.
Use the documented GEOS raster dimensions for each format, including
48 by 14 for CGA, and compensate for the target display's pixel shape.
Preserve the subject's proportions, placement and intended margins. Do not
trim the artwork to its foreground bounding box and then stretch it to fit.
If the input needs padding to establish an 8:5 composition, use magenta.

The background and transparency key are always pure magenta, RGB 255,0,255
or #FF00FF. Build the mask before resampling or palette reduction, so
magenta cannot bleed into visible edges. Reserve one source palette index
for the key and pass that actual index to the converter. Do not assume a
fixed palette index. Keep intentional pink details opaque; if a visible
detail also uses the key color, change that detail to the nearest suitable
non-key pink before constructing the mask. Magenta background areas,
including gaps inside the silhouette, must remain transparent.

Preserve the supplied designs. Use deterministic conversion for scaling,
palette mapping and encoding. Do not redraw or regenerate the artwork
unless explicitly requested. Keep pixel edges crisp and inspect thin
outlines after reduction. Use the small image's own composition for tool
icons; the big image's 8:5 requirement does not apply to tool icons.

### Output formats

Derive the icon formats from the SDK documentation and cvtpcx source.
Use GEOS display size, color class and aspect metadata, rather than
creating duplicate bitmaps for adapter names that share the same format.

Create these application/file monikers from the big image:

- VGA color: 48 by 30, standard, icon, normal, color4.
- VGA/MCGA monochrome: 48 by 30, standard, icon, normal, gray1.
- EGA color: standard, icon, squished, color4.
- HGC/monochrome EGA: standard, icon, squished, gray1.
- CGA monochrome: 48 by 14, tiny, icon, verySquished, gray1.

Use the standard 48 by 30 canvas for the EGA/HGC variants and adapt the
artwork for their display aspect. Verify the displayed proportions against
the target driver. The aspectRatio field describes the target display;
changing that field alone does not resample or correct the artwork.

Create these tool monikers from the small image:

- Color tool: 15 by 15, tiny, tool, normal, color4.
- Monochrome tool: 15 by 15, tiny, tool, normal, gray1.
- CGA tool: 15 by 10, tiny, tool, verySquished, gray1.

When the application requires additional file-icon sizes, derive them from
the big image: 32 by 20 color and mono, 64 by 40 color and mono, and
64 by 18 CGA mono. Keep the same displayed composition throughout.
Do not confuse the source image called "big" with the GEOS size value
"large": standard application icons still use size = standard.

Use masked BMF_4BIT bitmaps with the fixed GEOS 16-color palette for color
monikers. Prepare monochrome artwork with readable black outlines and
interior detail, not a filled silhouette or a blind luminance threshold.
Use BMF_MONO and GSFillBitmapAtCP so unpainted areas retain the destination
background. Check that gray objects and their outlines remain recognizable.

### Conversion and integration

Use existing tools where practical; cvtpcx is optional. If using it, use
GOC output, GEOS 2.0 constants and token-relative positioning (-G -2 -t).
Prepare the exact raster size first: -w and -h crop or pad, not scale.
Four-plane, one-bit-per-plane PCX input is needed for BMF_4BIT output;
a 16-color image saved as eight-bit indexed PCX is not equivalent.

Keep the changes small. Save editable raster sources and the exact
conversion commands. Generate token.goh, include it in the application's
moniker resource, and register the graphics with the existing text moniker
in GI_visMoniker. Follow the application's existing resource conventions.
Preserve source line endings and leave generated Makefiles untouched.

If adding an include, run pmake depend in the matching Installed directory.
Build EC and NC through ~/pcgeos-tools/aihelp.py build APP_PATH. Follow the
repository's swat.rc requirements. Do not launch PC/GEOS for testing.

### Verification and result

Show the final icons at actual size and with nearest-neighbor enlargement,
on light and dark backgrounds. Also show a display-aspect-corrected preview
for non-square-pixel formats; a raw CGA bitmap on a modern screen is not
its final displayed shape.

Verify bitmap dimensions, metadata, mask coverage, visible pink details,
GString payload lengths and decompressed row sizes. Check that the editable
source regenerates the committed monikers. Preserve a small runnable check
in the application's Tests directory when conversion logic is non-trivial.

Report the generated formats, source and output paths, build results and
any remaining visual limitations. End with a concise commit-message-style
summary. Record reusable findings in ~/pcgeos-tools/wiki/application-icons.md.

## Default sizes and display metadata: source evidence

TechDocs/Markdown/Tools/ticoned.md, sections 7.1 and 7.3, documents the
standard file-icon formats: 48 by 30 color, 48 by 30 mono, 48 by 14 CGA,
and optional 32 by 20 color/mono. It documents 15 by 15 and 15 by 10 tools,
and 64 by 40 SVGA file icons. The three default display targets are VGA,
MCGA (monochrome VGA) and CGA.

Tools/misc/cvtpcx/cvtpcx.c, the artwork-size constants and IconFormat
initializers, additionally defines 64 by 18 CGA. Its normal-aspect file
sizes 64 by 40, 48 by 30 and 32 by 20 all have an 8:5 raster ratio. Its
CGA sizes deliberately use fewer raster rows. There is no separate EGA
raster-size preset in the converter; the reusable prompt uses the standard
canvas with target-specific artwork and squished metadata.

TechDocs/Markdown/Objects/ogen.md, GString visual moniker fields, explains
that size identifies the display-size category, cachedSize gives actual
pixel dimensions, and aspectRatio identifies the target display. Normal is
used for VGA/MCGA; squished is for EGA/HGC, although normal is commonly used there;
verySquished is for CGA. Include/win.def defines the corresponding
EGA_DISPLAY_TYPE, MEGA_DISPLAY_TYPE, HGC_DISPLAY_TYPE and CGA_DISPLAY_TYPE.

The 8:5 displayed-composition rule and the always-magenta source key are
requirements of this workflow. The legacy raster dimensions and metadata
above are documented platform conventions.

## Pixel-aspect compensation

Use the target driver's DI_hRes and DI_vRes, not a presumed modern 4:3
screen shape. A raster pixel's displayed width-to-height ratio is
DI_vRes / DI_hRes. For an 8:5 composition of raster width W, use an artwork
frame height rounded from W * DI_vRes / DI_hRes / (8/5). Pad the remaining
canvas rows with the mask color. Apply this to the full source frame,
including its margins; foreground cropping changes the composition.

Driver/Video/VGAlike/VGA/vgaDevInfo.asm declares 64 horizontal and 64 vertical
dpi. Driver/Video/VGAlike/EGA/egaDevInfo.asm declares 64 and 47. The shared
Driver/Video/Dumb/DumbCom/dumbcomDevInfo.asm derives resolution by integer
division of screen dimensions by physical dimensions. With hgcConstant.def
and cgaConstant.def this gives HGC 72/49 and CGA 64/28 horizontal/vertical
dpi. At width 48 the resulting artwork frames are 30, 22, 20 and 13 rows.
A 13-row frame fits inside the conventional 14-row CGA canvas.

Whole-scanline rounding gives approximate displayed proportions. Also,
Include/win.def groups HGC and monochrome EGA under the same display-size,
color and squished-aspect metadata despite their different dpi values.
A static mono variant cannot be independently selected for each of those
adapters using that metadata alone. Choose the intended target driver and
state it in conversion notes; exact adaptation to both needs runtime dpi
handling.

## Converter constraints

Tools/misc/cvtpcx/cvtpcx.c documents the converter options in usage():

- -G emits GOC monikers; -2 selects GEOS 2.0 constants.
- -t positions optimized token graphics relative to the current pen.
  The converter help explicitly requires it for token database monikers.
- -m takes the source palette index to mask, not an RGB value.
- -w and -h trim or extend; they do not rescale artwork.
- -s, -S and -a select size, style and aspect independently.
- -b produces monochrome from black source pixels; -B instead fills all
  non-white, non-mask pixels. -f uses GSFillBitmapAtCP for monochrome.
- A four-plane, one-bit-per-plane PCX produces BMF_4BIT output. An ordinary
  indexed eight-bit PCX produces BMF_8BIT, even if it uses only 16 colors.
- The four-plane reader maps source palette colors to the fixed GEOS
  palette. Do not assume arbitrary 16-color palettes survive unchanged.

Evidence: main, readega, read256, MapPixelToGeosColorMap and GeosColorTable
in Tools/misc/cvtpcx/cvtpcx.c. The optional local helper
~/pcgeos-tools/img2moniker.sh uses ppmtopcx -planes=4; check that Netpbm
utility is installed before relying on that workflow.

## Preparing input and reviewing output

Request artwork with clear black outlines, flat colors, a known background
key, and distinct large and small designs. A 15 by 15 icon needs its own
simplified design. Preserve the big image's intended 8:5 composition and
margins when fitting to the target display format. Review at actual size
and with nearest-neighbor enlargement.

A background key can also occur inside the subject. Blanket removal can
make intentional interior details transparent. Preserve such details by
assigning them a non-key color before masking.

Large reference images are not necessarily pixel-aligned masters. Thin
outlines can disappear when reduced by nearest-neighbor sampling; area
sampling can introduce shades that change again during palette mapping.
Inspect the final fixed-palette bitmap, including the monochrome variants.
Keep a small editable raster source alongside generated moniker bytes so
future edits do not require reverse-engineering the GString.

## Regeneration and verification

Keep editable raster sources and the exact conversion commands. Verify
that regeneration reproduces token.goh, and validate the encoded GString
length and decompressed bitmap size.
The generated bitmap length is six header bytes plus the stored pixel data,
including mask bytes when present. PackBits data is stored compressed;
validate both the stored length and the expanded row count.

After introducing a new token.goh include, run pmake depend in the matching
Installed directory before rebuilding. Otherwise, an existing dependencies.mk
can miss later icon edits even though an incremental build reports success.
Verify that the generated dependencies.mk lists the new include for both
EC and NC object targets.
