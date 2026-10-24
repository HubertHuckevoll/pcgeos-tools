# Graphics font handles across text callbacks

`GrTextObjCalc` keeps its locked font handle in `TMS_fontHandle`. Its
`DoCallback` path unlocks that font before invoking a graphic or hyphen
callback, then calls `NearLockFont` again. The returned BX is the handle that
must be stored in `TMS_fontHandle` for both SBCS and DBCS builds: `DoFontLock`
can invalidate and free an unreferenced font before choosing the replacement.
The next `CallStyleCallBack` unlocks `TMS_fontHandle`. Evidence:
`Library/Kernel/Graphics/graphicsTextObject.asm` (`DoCallback`,
`CallStyleCallBack`) and `Library/Kernel/Graphics/graphicsChars.asm`
(`NearLockFont`, `DoFontLock`).

`TrueTypeStrategy` reporting `RECURSIVE_CALL_TO_FONT_DRIVER` from
`RemoveGeodes` / `EndGeos` is a shutdown-time failure: `RemoveGeodes`
calls initialized drivers with `DR_EXIT`. An earlier fatal allocation or
handle error inside the driver can leave its EC `inDriverFlag` set. Catch
`FatalError` at entry to retain the original stack; `HANDLE_TABLE_FULL`
skips its normal debugger trap and enters `EndGeos` directly. Evidence:
`Driver/Font/TrueType/Main/mainManager.asm` (`TrueTypeStrategy`),
`Library/Kernel/Geodes/geodesUtils.asm` (`RemoveGeodes`), and
`Library/Kernel/Boot/bootBoot.asm` (`FatalError`, `EndGeos`).

TrueType kerning conversion:

`Driver/Font/TrueType/Adapter/ttwidths.c:ConvertKernPairs` compares the
converted count with `FontBuf.FB_kernCount` at exit. Its previous unnamed
`EC_ERROR_IF(..., -1)` appears as "Death due to nil" in Swat; this is not a
null-pointer diagnosis. The output bound check prevents writing more than
`FB_kernCount`, so this final mismatch means fewer pairs were converted.
`ttinit.c:InitConvertHeader` gets the expected `FH_kernCount` from
`GetKernCount` or a cached header, and `ttwidths.c:TrueType_Gen_Widths` copies
it into the font buffer. `ttacache.c:TrueType_Cache_ReadHeader` keys headers
by filename, size and magic word; `TrueType_Cache_Init` opens `TTF Cache`
in `SP_PRIVATE_DATA` with protocol 3.0. Conversion skips tables when
`TT_Load_Kerning_Table` fails. `FreeType/ftxkern.c` reads and allocates the
pairs again for conversion, separately from the initial count pass.

Static bitmap missing-glyph entries can use CTE_dataOffset=CHAR_NOT_EXIST
(0) with CTF_NO_DATA, plus a valid FB_defaultChar for fallback. Do not assume
all on-disk CTF_NO_DATA entries have zero offsets: FontData/Esquire.fnt has
36 per strike with nonzero offsets to empty CharData records, across all ten
strikes (also preserved in Installed/FontData/Esquire/Esquire.fnt and its ASM/DEF sources). Preserve these records when reconstructing source. CHAR_MISSING=3
is a comparison threshold, not an entry value. VGA-like video drivers accept
0 (use default) or 2 (CHAR_NOT_BUILT, invoke font driver) on the missing-char
path; other values cause FONT_BAD_CHAR_FLAG in EC builds. Evidence:
Include/Internal/fontDr.def and
Driver/Video/VGAlike/VGA16/vga16GenChar.asm (CLF_charMissing, CLF_useDefault).

Bitmap font size labels and raster metrics are independent. PointSizeEntry's
PSE_pointSize selects the strike; FontBuf's FB_baselinePos, FB_accent,
FB_mean, FB_height and FB_descent describe its pixels. GrFontMetrics returns
these stored fields (GFMI_ASCENT is baseline minus accent); it does not infer
them from CharData. Keep baseline/cap/x-height metadata consistent with the
raster, especially for mixed-font alignment and decorations. Evidence:
Include/Internal/fontDr.def, Library/Kernel/Graphics/graphicsTextMetrics.asm
(GFM_table, GrFontMetrics), and FontData/Esquire.fnt's regular 10 pt strike.

Bitmap font file construction uses ESP followed by Glue's -Of output mode,
not a geode/GP link. Tools/glue/main.c registers fontOps for output type f;
Tools/glue/font.c:FontPrepare lays segments out according to their alignment,
and FontWrite writes the image. Include/Win32/geos.mk selects -Of for .fnt
and provides .obj.fnt. Preserve segment order/alignment for byte identity.
SBCS PointSizeEntry is ten bytes, CharTableEntry eight bytes, and the FontBuf
character table starts at offset 71. In existing SBCS FontData/*.fnt, header
bitmap directory pointers at file offsets 33/35 need six added to give file
offsets; PSE_filePosLo/Hi store absolute strike positions. Evidence:
Include/Internal/fontDr.def (PointSizeEntry, FontInfo, FontBuf, CharTableEntry)
and FontData/Berkeley.fnt.

Product filetree paths such as FontData/Berkeley/Berkeley.fnt are relative to configured
source roots. Tools/build/build/fileutil.pl:FindInstalledFile searches those
roots in order. Tools/build/product/bbxensem/Scripts/buildbbx.pl initializes
SourceDir with bbxensem/Installed, Installed, then the source root, allowing
Installed/FontData outputs without adding Installed to logical filetree paths.

Esquire's historical SBCS BSWF header-size field includes the eight-byte
prefix: it is 141, equal to the first strike's file offset, rather than the
usual 133. Its zero-count kerning pointers are 1863 in all ten strikes,
inside the character table (which ends at 2119). These unused values are
preserved by FontData/Esquire/esquire.asm and FontData/Esquire/esquire_*.def; the original
binary is FontData/Esquire.fnt, rebuilt as Installed/FontData/Esquire/Esquire.fnt.

Tools/pmake/pmake/make.c:Make_OODate compares target/prerequisite timestamps
with strict less-than. A remade object's timestamp can equal an existing
output within one second. Installed/FontData/font.mk keeps source/header
prerequisites on both object and FNT targets so a newer input also invalidates
the link directly. Its normal tool path uses ESP then Glue -Of, with temporary
outputs published by native rename only after success.

Standalone cleanup uses explicit extension lists: bin/clean (find expression)
and bin/clean.cmd ($extns) exclude FNT, TTF and SFD. The standard geode clean
target in Include/Win32/geos.mk invokes this standalone command. Bitmap font
cleaning is different: Installed/FontData/Makefile lists generated families
explicitly, and font.mk removes each named FNT plus intermediates. Prebuilt
TTF/Nimbus assets outside that family list survive bitmap cleaning.

TrueType files are loaded directly from SP_FONT/TTF: TrueType_InitFonts and
ProcessFont in Driver/Font/TrueType/Adapter/ttinit.c enumerate the directory,
open each font and call TT_Open_Face. GEOS-tailored TTFs remain TTF binaries;
there is no required TTF-to-FNT packaging conversion.

DejaVuSC provides 9, 10, 12, 14 and 18 pt bitmap strikes. At 10 pt its H
bitmap is 5x8 pixels and x is 4x6; Berkeley has H=6x8 and x=7x6, while
Esquire has H=5x8 and x=5x6. Equal nominal sizes have equal H/x heights
here, but DejaVuSC is narrower. Bitmap fonts select a supported strike;
a larger requested size does not scale a smaller strike. Evidence:
FontData/DejaVuSC/dejavusc.asm and dejavusc_*.def;
FontData/Berkeley/berkeley_10.def; FontData/Esquire/esquire_10.def;
Library/Kernel/Graphics/graphicsFont.asm (FindNearestBitmap).

The original ISUI2000 DejaVuSC reference has only the 10 pt strike, SHA-256
799ec5dacdea01187b6da41198baaf2bf02c0420aaaffe8445e40be88717394e.
Evidence: ISUI2000:FontData/README-DejaVuSC.md and FontData/DejaVuSC.fnt.
Character Map requests a point size based on box size and display build,
not necessarily 10 pt: Appl/Charm/app.goh (CHARM_I_MAP_TEXT_POINT_SIZE),
Process.goc (CMUpdateMapBoxSize), Map.goc (CMMapClass MSG_VIS_DRAW).

FontData/README.md documents DejaVuSC raster regeneration with the original
make_DejaVuSC.py generator (fntpatch revision 3943247357cdfdf8aadf0da968f486e9656974c6).
Use DejaVu Sans Condensed 2.37, Pillow 12.3.0 / FreeType 2.14.3 and 80 dpi
for identical hinting and advances. FontData/tests/bitmap-fonts.pl protects
the original 10 pt strike separately from the complete font hash.
