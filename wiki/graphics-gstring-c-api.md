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
