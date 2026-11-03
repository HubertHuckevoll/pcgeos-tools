# cvtpcx image conversion

The host tool's source is Tools/misc/cvtpcx/cvtpcx.c. ConvertFormat
selects ReadPNGIcon for PNG input, or readega/readvga using bitsPerPCXPixel
for PCX input. Both PCX readers combine PCX
scanline decoding with cropping, mask generation, pixel packing and PackBits
compression. The resulting Icon is passed to the shared output routines
OutputHeader and BitmapSpew; those handle UIC, ESP and GOC output modes.

The 4-bit reader maps source palette colors to the first 16 entries of
GeosColorTable through MapPixelToGeosColorMap (or MapPixelToResponder with
-N). The 8-bit reader retains source indices and reads the trailing PCX
palette through Read256ColorPalette. OutputHeader emits a custom 256-entry
palette when IsSameAsGeosPalette reports a difference.

PCX mask presence is derived from maskout != 255; index 255 is the legacy
no-mask sentinel. PNG uses a separate pngMaskPixel and alpha threshold of 128,
so PNG -m255 works. ConvertFormat/ReadPNGIcon set bitmapHasMask for OutputHeader.
Masks have one bit per pixel, with zero for transparency, including PNG padding.

ReadPNG preserves native packed palette indices through LodePNG's
decoder.color_convert = 0; other PNG types decode to RGBA. ReadPNGIcon maps
ordinary 4-bit output to the fixed GEOS colors, preserves palettes for indexed 8-bit
output, and maps non-indexed 8-bit output to GeosColorTable. PNG -b/-B compare
RGB black/white rather than palette positions.

With -p, cvtpcx preserves source indices and emits a 16-entry custom palette
for 4-bit output. It accepts indexed PNGs with at most 16 palette entries
(including PNGs whose indices use 8 bits) and 4-bit PCX. Short PNG palettes
are padded to 16 entries. It implies -2, rejects -c8/-N and does no color
reduction. Monochrome grid entries remain monochrome. Evidence:
Tools/misc/cvtpcx/cvtpcx.c:main, ConvertFormat, readega, ReadPNGIcon,
OpenChunk and OutputHeader; Tests/png.pl covers palette data and headers.

GEOS also supports BMF_4BIT with BMT_PALETTE | BMT_COMPLEX. A CBitmap header
is 20 bytes; a word count of 16 and 16 RGBValue entries occupy another 50
bytes, giving CB_palette=20 and CB_data=70. BMT_MASK is independent. Evidence:
Include/graphics.def:BMType/CBitmap; CInclude/graphics.h:CBitmap;
Library/Pref/Prefvid/Art/mkrPrefVid.ui and
Library/Pref/Prefsndn/Art/moniker.goh use this layout.

These sample monikers declare color8 while their bitmap pixels remain
BMF_4BIT. The moniker color is a display-selection hint, not pixel storage
depth: Tools/goc/scan.c maps color8 to DC_COLOR_8, and
Library/User/Vis/visUtilsClass.asm scores VMLET_GS_COLOR against DT_DISP_CLASS.
Library/Kernel/Graphics/graphicsRaster.asm:InitBitmapPalette consumes the
bitmap palette, mapping RGB entries to device indices on 4-/8-bit devices
or copying RGB entries for 24-bit devices.

GEOS PackBits accepts control byte 128 as a 129-byte repetition, unlike TIFF's
NOP convention. Evidence: Tools/misc/cvtpcx/cvtpcx.c:CompactBytes caps a run
at 129 and emits 257-count; Library/Kernel/Graphics/graphicsRasterDraw.asm:
UncompactPackBits handles every negative signed control by NEG/INC and repeats
that many bytes. The host check Tools/misc/cvtpcx/Tests/png.pl covers this case.

Library/PngLib is a GEOS runtime library rather than a host decoder:
pngimp.c uses FileHandle, MemHandle and VM bitmap output. Its
pngImportProcessChunks rejects interlaced PNGs.
