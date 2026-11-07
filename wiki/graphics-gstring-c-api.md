# GString C API output parameters

The C wrappers for `GrDrawGString` and `GrDrawGStringAtCP` require a valid
`word *lastElement`, even when the caller ignores the result. Both load the
far pointer and store CX unconditionally after playback. Passing a null
pointer writes to 0000:0000 in real mode. Use a small local word and pass its
address. Evidence: `Library/Kernel/Graphics/graphicsGStringC.asm`,
`GRDRAWGSTRING` and `GRDRAWGSTRINGATCP` (around lines 44-60 and 81-94).

The Boolean returned by the C `GrGetGStringBounds` wrapper is TRUE when the
bounds fit word coordinates, FALSE on coordinate overflow. This differs
from the assembly routine's carry flag, which is set on overflow. Evidence:
`graphicsGStringC.asm:GRGETGSTRINGBOUNDS` (around lines 469-492) and
`Library/Kernel/Graphics/graphicsString.asm:GrGetGStringBounds`.

When playback reaches `GSRT_COMPLETE`, `graphicsString.asm:GStringCleanup`
resets the current position to the beginning. Other stopping conditions can
leave a different current position; use `GrSetGStringPos` when a full replay
must be guaranteed.

## Text-field record padding

The SBCS GString layout is a 14-byte GDF_saved header followed by counted
TFStyleRun records. Each native TFStyleRun has a two-byte count and a 24-byte
TextAttr, including its final word-alignment byte. The packed C TextAttr in
CInclude/graphics.h is only 23 bytes. Skip all 26 native run-header bytes before
reading characters; the alignment byte need not be zero. Using the packed C
size reads padding as text and shifts later run headers.

GDFS_flags is a HyphenFlags byte whose only defined bit is HF_AUTO_HYPHEN
(mask 0x01). Ignore the remaining bits. TextLine's SetAutoHyphenFlag clears
only that bit in the no-hyphen case, so unused bits can reach saved text-field
records. GrDrawTextField and the EPS exporter test the named bit, not the
whole byte. Evidence: Include/text.def:HyphenFlags;
Library/Text/TextLine/tlCommonDraw.asm:SetAutoHyphenFlag;
Library/Kernel/Graphics/graphicsText.asm:GrDrawTextField (done);
Library/Trans/Graphics/Vector/EPS/Export/exportText.asm:CheckAutoHyphen.

Evidence: Include/text.def:GDF_saved, Include/graphics.def:TextAttr (align word),
Include/gstring.def:TFStyleRun, and
Library/Kernel/Graphics/graphicsStringStore.asm:StoreTextField (writes size
TFStyleRun before each run's characters).

## Solid pattern attributes

GR_SET_AREA_PATTERN (0x7b) and GR_SET_TEXT_PATTERN (0x8c) are three-byte
attribute records: opcode, PatternType, data byte. PT_SOLID is zero and ignores
the data byte; a pattern command therefore does not by itself mean a hatch or
bitmap fill. Evidence: Include/gstring.def:OpSetAreaPattern/OpSetTextPattern,
Include/graphics.def:GraphicPattern/PatternType, and
Library/Kernel/Graphics/graphicsPattern.asm:ECCheckPatternInfo.

## Empty drawing masks

SDM_0 means an invisible operation, not an unsupported partial screen.
The EPS exporter handles zero line/area masks with EmitNothing
(Library/Trans/Graphics/Vector/EPS/Export/exportGString.asm:
CheckZeroLineMask, CheckZeroAreaMask). GrObj can still send a foreground draw
message for a zero mask when GOMOF_DRAW_FG_LINE or GOMOF_DRAW_FG_AREA is set
(Library/GrObj/GrObj/grobjDraw.asm:GrObjDrawDrawForegroundLine/Area).
Text has its own mask in GS_textAttr, separate from GS_lineAttr and GS_areaAttr
(Include/Internal/gstate.def); text-field runs carry their own TextAttr,
including the text mask (Include/gstring.def:TFStyleRun).

## Icon and text button monikers

A GenTrigger moniker list with a text moniker and an icon GString can use
HINT_USE_ICON_TEXT_COMBINATION_MONIKER = {0, spacing} to place the icon left
of the text. GenFindMoniker honors this hint when VMSF_REPLACE_LIST and
VMSF_GSTRING are set; ReplaceMonikerListWithIconTextMoniker calls
UserCreateIconTextMoniker. Evidence: Library/User/Gen/genUtils.asm.

Dynamic MSG_GEN_REPLACE_VIS_MONIKER_OPTR updates take a different path:
GenReplaceVisMoniker -> UpdateMoniker -> MSG_SPEC_RESOLVE_MONIKER_LIST.
The default VisSpecResolveMonikerList calls VisFindMoniker directly and
therefore bypasses the combination hint. A trigger subclass can resolve
its current list with MSG_GEN_FIND_MONIKER(FALSE, VMSF_REPLACE_LIST |
VMSF_GSTRING | (VMS_ICON << VMSF_STYLE_OFFSET), 0) to preserve icon and text.
Evidence: Library/User/Gen/genClassCommon.asm, Library/User/Vis/visSpec.asm,
and Appl/Audio/Bsqp/UI/uimain.goc:BQPlayTriggerClass.

Keep reusable moniker lists, labels and icons that are copied across threads
in a shared read-only plain LMem data resource, not a ui-object resource.
ProcessCopyChunkOver locks both source and destination with ObjLockObjBlock;
ObjLockObjBlock checks ownership for LMEM_TYPE_OBJ_BLOCK but permits plain
LMem heaps on either thread. VisFindMoniker's replacement path sends the
copy to the current thread, so a source object block owned by another
thread causes OBJ_LOCK_OBJ_BLOCK_BY_WRONG_THREAD. The writable combined
moniker belongs in the target button's own object block.
Evidence: Library/User/Vis/visUtilsClass.asm:VisFindMoniker,
Library/Kernel/Object/objectProcess.asm:ProcessCopyChunkOver and
Library/Kernel/Object/objectClass.asm:ObjLockObjBlock.

UserCreateIconTextMoniker positions the icon with a MoveTo before playing
its GString. Use bitmap operations at the current position rather than
absolute shape coordinates. GSFillBitmapAtCP with BMF_MONO draws set bits
in the current area color and leaves clear bits transparent.
Evidence: Library/User/User/userUtils.asm:UserCreateIconTextMoniker
(drawText), TechDocs/Markdown/Concepts/cshapes.md (bitmap drawing).

## C text-mask getter dispatch

The C mask wrappers share CGetMaskCommon and CallLineMaskRoutine.
CX=0 selects line, CX=1 selects area, and CX=2 selects text. Keep
GRGETTEXTMASK at CX=2; using the area selector makes independent text
visibility follow unrelated area attributes. Null mask-buffer pointers are
permitted by this wrapper; it still returns the mask enum.
Evidence: Library/Kernel/Graphics/graphicsC.asm:GRGETTEXTMASK,
CallLineMaskRoutine, CGetMaskCommon; graphicsGetState.asm:GrGetTextMask.

GrGetTextPattern and GrGetAreaPattern differ: their C wrapper writes both
customPattern and customSize unconditionally, even for PT_SOLID. Pass valid
addresses for both outputs, rather than null pointers. Evidence:
graphicsC.asm:GetPatternCommonC.

## PDF MacRoman glyph coverage

PDF MacRomanEncoding does not contain every mathematical character from
the Macintosh Roman byte set. Do not pass through GEOS byte values solely
because the Mac Roman character has the same numeric code. The native
PDF viewer maps e.g. 0xad, 0xb0, 0xb2, 0xb3, 0xb9, 0xba, 0xbd, 0xc3,
0xc5, 0xc6 and 0xd7 to zero. The EPS exporter has existing Symbol-font
character mappings for these cases. Evidence: Appl/PDFViewer/gfxFont2.goh:
macRomanToGeosMap and macRomanEncodingNames; Library/Trans/Graphics/Vector/
EPS/Export/exportText.asm:greekCharTab, greekMapTab, ConquerTheGreeks.

## Native path and text metric APIs

GrGetPathPoints is exported but currently returns BX=0 without constructing
any points. Use GrGetPath for a copied path GString; it supports GPT_CURRENT,
GPT_CLIP and GPT_WIN_CLIP. The caller owns the returned memory block.
Evidence: Library/Kernel/Graphics/graphicsPath.asm:GrGetPathPoints (1262),
GrGetPath (793); CInclude/graphics.h:GetPathType.

VidCom KernChar applies pair and track kerning before painting a glyph,
including track kerning before the first glyph. GrTextWidthWBFixed includes
those adjustments in the resulting advance; GrCharWidth returns the bare
character width. Prefix width alone therefore does not locate a kerned glyph.
The assembly fractional width result is DX:AH (16.8); clear AL to return a
16.16 DX:AX value to C. Evidence: Driver/Video/VidCom/vidcomChars.asm:KernChar;
Library/Kernel/Graphics/graphicsTextMetrics.asm:GrTextWidthWBFixed;
graphicsFont.asm:GrCharWidth; graphicsC.asm:GRCHARWIDTH.

## Retained-path playback and cleanup

GrTestPath distinguishes an absent path from a GrGetPath allocation failure.
GrGetPath alone returns zero for both; an exporter must not treat an allocation
failure on an existing clip as unrestricted painting. Evidence:
Library/Kernel/Graphics/graphicsPath.asm:GrTestPath and GrGetPath.

GrGetPath rearranges each native section from BeginPath/SetTransform/MoveTo
to ApplyTransform/MoveTo/BeginPath. Its BeginPath header now retains the original
flags, including per-section fill rule and page/document coordinate information.
BPF_COMBINE in those flags reflects later clip combinations; OBP_combine can
still contain the original definition's combine argument. Evidence:
graphicsPath.asm:GrGetPath; graphicsPathLow.asm:CombineGStringOrPathWithPath,
SetClipPathCommon in graphicsPath.asm; Include/Internal/grWinInt.def:BeginPathFlags.

An exporter that skips BeginPath/EndPath during snapshot playback must preserve
and restore the playback state itself and reset each saved section's absolute
matrix. The original retained stream contains SetTransform per section; simply
accumulating the copied ApplyTransform records changes the geometry. Evidence:
graphicsPath.asm:GrBeginPath, GrGetPath; graphicsPathLow.asm:PathLoadGString;
graphicsTransformUtils.asm:GrSetTransformReal.

A retained path can contain recorded SaveState/RestoreState and attribute
commands, not only geometry and transforms. Replay these on the temporary
GState; GrRestoreState restores the pen as well as the matrix. Keep the
recorded save depth separate from a synthetic BeginPath section save, so an
unmatched restore cannot pop that section frame. GrDestroyState frees any
remaining saved-state chain. Evidence: graphicsState.asm:GrSaveState,
GrRestoreState, GrDestroyState (freeLoop); graphicsPath.asm:GrBeginPath and
GrEndPath (the path's own state save/restore).

An unfinished GrBeginPath owns a path GString through GS_gstring. GrDestroyState
requires GS_gstring to be zero (EC fatal otherwise); GrEndPath releases that
GString and restores the saved GState. Close the definition before destroying
its state on an export error. Evidence: graphicsState.asm:GrDestroyState;
graphicsPath.asm:GrBeginPath and GrEndPath.

## Watcom pattern getter return ABI

The kernel C entries GRGETTEXTPATTERN and GRGETAREAPATTERN return packed
PatternInfo directly in AX. CInclude declares a two-byte GraphicPattern
structure result, but Watcom's __pascal definition uses `value struct routine
[ax]`: the caller treats AX as a pointer to the result and dereferences it.
For these entries, use a word-return declaration for the uppercase kernel C
symbol, or an assembly adapter with a scalar result. Do not change the global
structure-return convention; other functions can depend on it.

Custom hatch/bitmap patterns return an owned snapshot handle that must be
freed. For predefined patterns, BX and CX do not describe such a snapshot;
only free the handle for PT_CUSTOM_HATCH or PT_CUSTOM_BITMAP. Evidence:
CInclude/geos.h (__WATCOMC__ __pascal pragma), CInclude/graphics.h
(GraphicPattern and getter declarations), Library/Kernel/Graphics/graphicsC.asm:
GetPatternCommonC, and graphicsPattern.asm:GetPatternCommon.

## Native text decoration metrics

Underline and strike-through positions are relative to the font top;
subtract GFMI_BASELINE when painting relative to a text baseline. Both use
GFMI_UNDER_THICKNESS. GDFS_limit caps the right edge of decorations while the
text pen retains the full run advance; 0xffff is the no-limit sentinel.
Decorations use GS_textAttr, including its mask/color, rather than line or
area attributes. Evidence: Library/Kernel/Graphics/graphicsText.asm:PreStyles,
DrawStyles; graphicsTextObscure.asm:LibDrawKernelStyles and DrawOneBar;
CInclude/font.h:GFM_info; graphicsFontC.asm:CMetricsCommon returns fractional
font metrics as 16.16 to C.

## Hyphens and effective dash state

SBCS C_OPTHYPHEN (0x1f) has zero advance when hidden. It becomes C_HYPHEN
only if TM_DRAW_OPTIONAL_HYPHENS is set and it is the last counted character
(or the next byte is NUL). One-character width queries therefore cannot
establish visibility for internal optional hyphens. Automatic field hyphens
are drawn separately with the final run's attributes. Evidence:
graphicsTextMetrics.asm:optHyphen; graphicsText.asm:GrDrawTextField (done);
Driver/Video/VidCom/vidcomChars.asm:PSL_startHyphen.

GrGetLineStyle returns only the enum. Effective native dash state starts at
GS_numOfDashPairs: one byte count, one byte skip, then byte factors at
GS_dashPairArray. Native save/restore preserves it. A locked GState snapshot
avoids duplicating dash-command state in an exporter. Despite the public
DashPairArray word declaration, only two bytes per pair are stored and used.
Evidence: Include/Internal/gstate.def; graphicsState.asm:SetLineStyle;
graphicsGetState.asm:GrGetLineStyle; graphicsLineStyles.asm:CreateDashArrayOfByteOffsets.

## Indexed bitmap slices and PDF lookup tables

A custom bitmap palette is a word count followed by packed RGB triples at
CB_palette. HugeBitmapToString writes the palette with a zero-row introductory
slice, then clears BMT_PALETTE on later slices. Preserve its color interpretation
across those slices. Evidence: Include/graphics.def:CBitmap;
Library/Kernel/Graphics/graphicsBitmapString.asm:HugeBitmapToString (writeHeader,
unlockHADir) and SliceToString (storePalette).

GrMapColorIndex(0,index) selects the kernel defaultPalette without allocating
a palette block. Its C scalar result packs red, green and blue in the low three
bytes. GrGetPalette instead allocates with HAF_NO_ERR, even for a default
palette request. Evidence: graphicsColor.asm:GrMapColorIndex, GrGetPalette;
graphicsC.asm:GRMAPCOLORINDEX.

The native PDF viewer precomputes all 2^bits image color lookups and calls
GfxColorSpaceGetColor for indices above indexHigh without clamping. Emit a full
16-/256-entry PDF Indexed lookup table, padding unused entries, even if the
source bitmap palette is shorter. Evidence: Appl/PDFViewer/main/gfxState.goc:
GfxImageColorMapInit and GfxColorSpaceGetColor. Indexed PDF 1.1 images also use
the ImageI ProcSet in their page resources.

## Compressed bitmap scanlines

BMC_PACKBITS uses unsigned controls 0..127 for 1..128 literals and 128..255
for 129..2 repetitions. Control 128 is a 129-byte run, not a TIFF NOP. Packets
must fit the current decoded row; native UncompactPackBits consumes a row by
its known byte count. Evidence: graphicsRasterDraw.asm:UncompactPackBits;
Tools/misc/cvtpcx/cvtpcx.c:CompactBytes.

Bitmap LZG streams are per scanline. Flags are MSB-first: one selects a single
literal; zero selects a token. Tokens support 3-byte short matches (bit 7,
7-bit distance), ordinary/extended matches (10-bit distance), short/extended
literal blocks (bit 6), and zero runs (bits 6 and 5). Token 0x60 ends the stream.
Matches can overlap, and distance is at most 1023. Decoder history resets for
each row. Evidence: Library/Kernel/Heap/heapCompress.asm:LZGUncompressLow,
LZGSourceSize and LZG_* constants; graphicsBitmapString.asm:SliceToString
(STS_lzged counts one LZGSourceSize per scanline).

## Stored bitmap masks

BMT_MASK prefixes each scanline with ceil(width/8) packed mask bytes, before
the pixel data. A clear mask bit skips the destination write. Mono pixels
remain a stencil: effective coverage is source AND stored mask. Compression
therefore includes the mask prefix in the decoded scanline length. Evidence:
Library/Kernel/Graphics/graphicsRaster.asm:CalcLineSize;
Library/Trans/Graphics/Vector/EPS/Export/exportBitmap.asm:withMask;
Driver/Video/Dumb/VidMem/Clr8/clr8Raster.asm:PutColor8ScanMask;
Driver/Video/Dumb/VidMem/Clr8/clr8Raster.asm:WriteMonoByte.

## Bounded arc angles and point attributes

GrDrawArc/GrFillArc use radial angles: the ray from the ellipse center has
that angle. This is not the ellipse parameter angle except on circles and
axes. Angles increase counterclockwise with document Y downward; normalization
is modulo 360. Open arcs leave the pen at angle2; chord/pie arcs leave it at
angle1. Evidence: Library/Kernel/Graphics/graphicsArcLow.asm:
CalcEllipsePointWithAng (ellipse/ray equation), NormalizeAngle, ArcSetCurPos.
Open retained arcs establish a subpath start at angle1. Evidence:
Library/Kernel/Graphics/graphicsPathLow.asm:StrokePathArc and
AddArcEllipsePointsLow (ACT_OPEN).

GrDrawPoint uses GS_areaAttr, not GS_lineAttr, after transforming the point.
It draws one device pixel. The EPS exporter represents it as a one-document-
unit filled rectangle, so that exporter convention differs under scaling.
Evidence: graphicsOutput.asm:GrDrawPoint; Library/Trans/Graphics/Vector/EPS/
Export/exportGString.asm:EmitFillRect (doPointCommon).

## Three-point arc pen state and null-window playback

Arc3PointSetCurPos selects point1 for ACT_OPEN and point3 for a closed arc.
Arc3PointToSetCurPos leaves ACT_OPEN unchanged and selects point3 for a closed
arc. GrDrawArc3PointToReal/GrFillArc3PointToReal call TrivialRejectFar before
SetupArc3PointToLow; a null-window drawing state therefore bypasses their pen
setter. An exporter using null-window playback must account for this state
change explicitly. Evidence: Library/Kernel/Graphics/graphicsArc.asm, named
procedures and arc3PointToToGSCommon.

The relative recording branch calls RelArc3PointToSetCurPos, then jumps to
arc3PointToToGSCommon, which calls the absolute Arc3PointToSetCurPos. Thus a
closed recorded relative arc leaves the raw delta3 values as the final pen,
not the summed relative endpoint. This is existing kernel behavior; it differs
from SetupRelArc3PointToLow's drawing path. Evidence: graphicsArc.asm:
drawRelArc3PointToGS and the two setters; graphicsArcLow.asm:
SetupRelArc3PointToLow. Do not assume that the geometric curve endpoint and
native recorded pen are identical.

## Rectangular brush polyline behavior

GrBrushPolyline takes byte brush width/height in device pixels. The video
implementation uses GS_lineAttr and a rectangular brush extending right/down
from each line pixel; line width, dash arrays and end-cap style do not define
that brush. VidPolyline subtracts packed 0x0101 from the brush word, then clamps
negative signed byte increments to zero. Evidence: graphicsPolyline.asm:
GrBrushPolylineReal; Driver/Video/VidCom/vidcomLine.asm:VidPolyline,
PolyRectDDA. DDA_X/DDA_Y coalesce horizontal/vertical runs. At an exact
half-way decision, they change the minor coordinate for a positive dominant
axis, but keep it for a negative dominant axis; reversed segments therefore
cover the same pixels. FillPathPolyline treats a captured brush as its centerline and
skips the two brush bytes (graphicsPathLow.asm).

The native PDF printer advertises 300x300 dpi in
Driver/Printer/PDF/pdfDriverInfo.asm:pdfGraphics. One physical device pixel is
therefore 0.24 PDF points. Apply the GString and page transformations to the
position before mapping to this grid; the rectangular brush dimensions are
already device pixels. PDL page transforms are supplied by
Library/Spool/Process/processPDL.asm:PrintPDLPage and CalcDocOrientation in
processThread.asm. One document unit per pixel is the EPS convention, not
device-exact sizing.

## Transforming copied paths for export

GrTransformDWFixed and GrUntransformDWFixed transform PointDWFixed in place,
retaining a signed 32-bit integer and 16-bit fraction for each coordinate.
Use a separate null-window GState for a page transform; do not overwrite a
playback state's path or matrix. For a captured path, transform the explicit
vertices/control points into the coordinate system used when painting. A
fill/clip can use physical page coordinates. A stroke can use the inverse
final painting transform, then apply that transform with its stroke attributes.
This retains affine line widths and changing definition matrices. Evidence:
CInclude/graphics.h:PointDWFixed and transform declarations;
Library/Kernel/Graphics/graphicsC.asm:GRTRANSFORMDWFIXED/CTransDWCommon;
graphicsUtils.asm:GrTransformDWFixed, GrUntransformDWFixed;
Appl/PDFViewer/main/gfx.goc:opMoveTo/opLineTo/opCurveTo/opConcat.

## C callbacks in movable resources

A C function pointer into movable code can contain a virtual segment. Do not
invoke it with a raw indirect far call. For Pascal callbacks, cast
ProcCallFixedOrMovable_pascal to a typed Pascal function pointer with the
callback pointer as its final argument; the kernel removes that argument,
locks the resource and calls the target. SvgLib already uses this pattern in
Library/SvgLib/Export/svgExportWriter.goc:SvgExportInvokeSink. Evidence:
CInclude/resource.h; Library/Kernel/Geodes/geodesResource.asm:
PROCCALLFIXEDORMOVABLE_PASCAL, FOM_common and ProcCallFixedOrMovable.
Check the generated rsc.rsc resource list and Watcom object disassembly when
checking a callback boundary; source code pragmas alone do not prove that
caller and callback share one code resource.

## Temporary paths used for object bounds

GrObjGetBoundingRectDWFixedFromPath draws MSG_GO_DRAW_FG_LINE into a path on
the parent GState, then queries its bounds. A recorded path definition can
therefore contain text even when it is never painted. Exporters should
validate captured records separately from rendering support, and defer an
unsupported glyph-outline error until the path is painted or used as a clip.
Evidence: Library/GrObj/GrObj/grobjBounds.asm:
GrObjGetBoundingRectDWFixedFromPath; Library/Kernel/Graphics/graphicsPathLow.asm:
FillPathTextField and StrokePathTextField (native paths accept text fields).

## Native font outlines for exported paths

DR_FONT_GEN_PATH writes glyph geometry through a supplied GState, including a
recording GST_CHUNK GString. Resolve the maker from FontInfo.FI_maker, not a
cached FontBuf.FB_maker: an outline font can currently have a bitmap buffer.
FontDrLockInfoBlock + FontDrFindFontInfo exposes FI_family/FA_OUTLINE and
FI_maker; GrCallFontDriverID invokes the outline generator. Evidence:
Library/Kernel/Graphics/graphicsPathLow.asm:PathOutputText;
Include/Internal/fontDr.def:FontInfo, FontGenPathFlags;
Library/Kernel/Graphics/graphicsFontDriver.asm:FontDrFindFontInfo.

FGPF_POSTSCRIPT suppresses the driver prologue's font-top translation and Y
flip. Supply baseline placement and Y inversion in the recording state's
matrix; leave its integer pen at zero to retain fractional placement.
Nimbus uses MoveTo, LineTo, HLineTo, VLineTo, relative lines and curves;
TrueType/Bitstream use moves, lines and curves. Generators also write comments
and transforms. DR_FONT_GEN_PATH defines no status result. Evidence:
Driver/Font/Nimbus/nimbusPath.asm:PathEmitPrologue, pathRoutines;
Driver/Font/TrueType/Adapter/ttpath.c:TrueType_Gen_Path;
Driver/Font/Bitstream/Main/mainOutline.asm;
Library/Trans/Graphics/Vector/EPS/Export/exportText.asm:EmitCharacter.

GrDestroyGString with GSKT_KILL_DATA deletes a GST_CHUNK data chunk, but not
its owning LMem block. With GSKT_LEAVE_DATA, both chunk and block survive.
The owner must release the LMem block after all recording/reading GString
states are destroyed. Evidence: Library/Kernel/Graphics/graphicsStringUtils.asm:
GrDestroyGString (LMemFree, freeGStringBlock, GrDestroyState).
