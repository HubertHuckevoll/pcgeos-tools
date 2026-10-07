# SvgLib import memory

`SvgImport()` writes a VM GString while `SvgImportParse()` scans the source
through a 1024-byte I/O block. `SVGScratch` owns separate tag, path-data,
WWFixed-point, and GEOS `Point` blocks. They grow by doubling and remain
allocated until parse cleanup. The configured ceilings permit
8192 + 8192 + 4096*8 + 4096*4 = 65536 bytes across those four blocks.
Evidence: `Library/SvgLib/Import/svg.h` (`SVGScratch` and `SVG_*` limits),
`svg.goc` (`SvgScratchEnsureCapacityCommon`, `SvgImportParse`),
`svgPath.goc` (`SvgPathHandle`, `SvgPathEmitSubpath`), and `svgShape.goc`
(`SvgShapeHandlePolyline`, `SvgShapeHandlePolygon`).

The SvgLib parser's source-file operations are concentrated at its input
boundary: `SvgImportParse()` seeks to find source length and resets to the
start, `SvgParserScanNextTag()` refills a 1024-byte buffer with `FileRead()`,
and progress/debug reporting queries `FilePos()`. Rendering writes a VM
GString independently of that source. Evidence: `Library/SvgLib/Import/svg.goc`
(`SvgImportParse`), `svgParse.goc` (`SvgParserScanNextTag`), and `svgApi.goc`
(`SvgImport`).

`SvgShapeHandleRect()` keeps zero-radius rectangles on the four-point stack
path. Rounded rectangles reuse the scratch `Point` block for a 48-point
outline, after defaulting and clamping `rx`/`ry`; every point goes through
the world matrix before `SvgRendererPolygon()`. Evidence:
`Library/SvgLib/Import/svgShape.goc` (`SvgShapeHandleRect`).

BbxBrow calls `SvgImport()` through ImpGraph's `ImpSVG()`. `ImpSVG()`
ignores the allocation watcher and import progress data, leaves `usedMem`
zero, and supplies a null SVG progress callback. It does not check
`IBP_maxPixels`; its post-import bounds validation checks coordinate range
and positive dimensions. `TE_OUT_OF_MEMORY` returns `IBS_NO_MEMORY` without
setting `MIME_STATUS_MEMORY_LIMIT`. Evidence:
`Library/Breadbox/ImpGraph/MAIN/impgraph.goc` (`ImpSVG`).

`SvgImport()` accepts an optional `const volatile Boolean *cancelP` after its
progress callback. `SvgImportParse()` polls for nonzero between tags
independently of progress reporting; callback true still cancels. Cancellation
returns `TE_ERROR`, frees partial output, and leaves the result chain zero.
`ImpSVG()` casts its `MS_mimeFlags` pointer at the boundary: GEOS `Boolean`
is `sword` (`CInclude/geos.h`), while `MimeStatusFlags` is `word` with only
`MIME_STATUS_ABORT` defined (`CInclude/htmldrv.h`). Other status flags would
require a separate live Boolean in the adapter. ImpGraph maps cancellation to
`IBS_IMPORT_STOPPED`. Graphvwr and the SVG translator pass a null cancellation
pointer, retaining callback cancellation. The flag storage must remain valid
and cancellation set until the call returns.
Evidence: `CInclude/svgLib.h`, `Import/svg.goc`, `Import/svgApi.goc`,
`Library/Breadbox/ImpGraph/MAIN/impgraph.goc`,
`Appl/Breadbox/Graphvwr/MAIN/bmpview.goc:BVImportGraphic`, and
`Library/Trans/Graphics/Vector/Svg/svgAdapter.goc:SvgAdapterImport`.

BbxBrow passes source filenames, not open handles, through
`ToolsImportGraphicByDriver()` and `ImportGraphicByNative()` in
`Appl/Breadbox/BbxBrow/htmlview/LoadURL.goc`. `ImpSVG()` opens its own local
`srcFile` with `FILE_ACCESS_R | FILE_DENY_W`, passes it to `SvgImport()`,
and closes it before returning. Separate SVG imports therefore do not share
one source handle's seek position, even when their filenames match.
Evidence: `Library/Breadbox/ImpGraph/MAIN/impgraph.goc` (`ImpSVG`) and
`Appl/Breadbox/BbxBrow/htmlview/ImportG.goc`
(`MSG_IMPORT_THREAD_ENGINE_IMPORT_GRAPHIC`). The MIME-driver semaphore in
`ImportGraphicByNative()` is released before calling the driver; it does not
serialize the import itself.

SvgLib import helpers keep writable working state in `SvgImportContext`,
`SVGScratch`, invocation-local variables, or their per-import heap blocks.
The static `nonRendering` and `unsupported` tag-name arrays in `svg.goc`
are only read by `SvgTagIsOneOf()`. `SvgStyleFindNamedColor()` in
`svgStyle.goc` only reads `SvgNamedColors`; `svglib.gp` marks its resource
`lmem read-only shared`. The EC-only logger in `dbglog.goc` has per-context
buffers and handles, but `SvgLogInit()` targets the same private-data
`dbglog.txt` with `FILE_CREATE_TRUNCATE | FILE_DENY_W`. Debug output is
therefore not independent per import. Logging failures do not determine
`SvgImportParse()`'s import status. NC logging macros are no-ops in
`dbglog.h`.

BbxBrow reads `[HTMLView] forceSingleImportThread` once in
`ImportThreadEngineStart()` (`htmlview/ImportG.goc`). With progress support
compiled in, true sets `G_numImportThreads` to one; otherwise the count is
`G_numFetchChildren + 1`. `ImportThreadRequestImportGraphic()` selects
`LPD_loadThread + 1` only when more than one importer exists, so streamed
JPEG and inline SVG requests both use importer zero in single-thread mode.
Requests use `forceQueue`; changing the INI while the engine is running
does not resize it. The existing `htmlview/check_import_threads.pl` checks
selection, routing, abort and cleanup with host shims, not GEOS scheduling.

`SvgImportParse()` unlocks tag, path-data and point scratch buffers between
tags, and unlocks the 1024-byte input buffer before dispatching a tag. A
path holds tag text, copied `d` text and both point arrays during conversion,
but releases the WWFixed array before subpath graphics calls.
`SvgImportContext` remains locked throughout import; scratch allocations
are freed before `SvgImport()` calculates GString bounds. Evidence:
`Import/svg.goc`, `svgPath.goc`, `svgApi.goc`.

Output is not allocation-free because it is VM-backed: kernel
`WriteVMemGString` buffers each element in an LMem chunk and inserts it into
a HugeArray (`Library/Kernel/Graphics/graphicsStringStore.asm`). GString
creation uses `INIT_GSTRING_FLAGS` with `HAF_NO_ERR`
(`graphicsStringUtils.asm`, `graphicsConstant.def`), and native VM memory
allocation also adds `HAF_NO_ERR` (`Library/Kernel/VMem/vmemLow.asm`,
`VMGetMemSpace`). These paths can enter the kernel allocation-retry warning
while SVG's own checked scratch allocation would return an error.

The tag-size ceiling is enforced by `SvgParserScanNextTag()` while collecting
quoted attributes, before shape dispatch (`Import/svgParse.goc`). An oversized
`d` therefore returns `SVG_SCAN_LIMIT_EXCEEDED`, becomes `TE_FILE_TOO_LARGE`
in `SvgImportParse()`, and follows cleanup; `ImpSVG()` maps it to
`IBS_UNKNOWN_FORMAT`. `HandleInlineSVG()` in
`Library/Breadbox/Html4Par/htmlpars/htmlpars.goc` first spools the whole inline
SVG to a temporary file using a 1024-byte buffer, independently of SvgLib's
tag limit. Large source size does not imply it is all held in the heap or
that its geometry reaches the renderer.

On an import error, `GrDestroyGString(..., GSKT_LEAVE_DATA)` and
`VMFreeVMChain()` release the partial output (`Import/svgApi.goc`). The SVG
branch of `MimeDrvGraphicEx()` has no raster-format fallback; failure
leaves `bmVMBlock` zero. BbxBrow's import method then sends
`MSG_URL_TEXT_INTERNAL_REPLACE_LIKE_GRAPHICS` with `OCT_NULL`, marks the image
broken and decrements the pending count (`Library/Breadbox/ImpGraph/MAIN/impgraph.goc`,
`Appl/Breadbox/BbxBrow/htmlview/ImportG.goc`, `urltext/URLTEXT.goc`).

Each non-null scratch pointer records one active lock.
`SvgScratchEnsureCapacityCommon()` reuses an existing pointer without
locking again. Early releases clear the pointer; `SvgPathHandle()`, the
next `SvgImportParse()` iteration and `SvgScratchFree()` check it before
unlocking, so they skip buffers already released.

Within a path, scratch locks span distinct phases. `SvgPathEmitSubpath()`
converts `ptsWWFP` to `ptsP`, then unlocks `ptsWWFH` and clears `ptsWWFP`
before style adjustment and rendering. `SvgPathAddPt()` reacquires the
current pointer through `SvgScratchEnsureWWPointCapacity()` when a later
subpath adds points. Renderer calls consume only the GEOS points, while
style adjustment still reads the tag. The caller
retains `sP` and `iterationP` into `dbP` across subpath emission. After the
final emission, `SvgPathHandle()` unlocks all active scratch pointers and
clears them before `SvgRendererEndPath()`. That renderer takes only the
context and fill/stroke flags. It calls `GrEndPath`, `GrFillPath`, and
`GrDrawPath`, without reading scratch data. Evidence:
`Import/svgPath.goc` (`SvgPathEmitSubpath`, `SvgPathHandle`) and
`Import/svgRenderer.goc` (`SvgRendererEndPath`).

Successful SVG output ownership crosses the SvgLib/ImpGraph boundary: `SvgImport()`
keeps the VM GString data after destroying its GState and returns its chain;
`ImpSVG()` frees that chain if bounds validation rejects it, otherwise returns
its head through `bmVMBlock` and `IBP_bitmap` as `IAD_TYPE_GSTRING`.
The successful output therefore intentionally survives both functions.
Evidence: `Library/SvgLib/Import/svgApi.goc:SvgImport` and
`Library/Breadbox/ImpGraph/MAIN/impgraph.goc:ImpSVG`.

`SvgShapeHandlePolyline()` and `SvgShapeHandlePolygon()` unlock copied
coordinate text after parsing and unlock the WWFixed array after conversion.
During renderer calls, only tag text and GEOS points remain locked in their
scratch storage. Their combined capacity ceiling is 24 KiB, compared with
32 KiB for path subpath emission, which retains copied `d` text for parsing.
Both figures exclude context and kernel/output storage, and describe the
rendering phase rather than the conversion peak. The VM GString writer
copies geometry into an LMem chunk and inserts it into a HugeArray.
Evidence: `Import/svgShape.goc:SvgShapeHandlePolyline/SvgShapeHandlePolygon`,
`Import/svgRenderer.goc:SvgRendererPolygon/SvgRendererPolyline`,
`Library/Kernel/Graphics/graphicsPolyline.asm:polylineGSCommon`, and
`graphicsStringStore.asm:WriteVMemGString`.

SvgLib fixed-point geometry already uses native assembly multiplication:
C `GrMulWWFixed` maps to `GRMULWWFIXED`, whose stack-argument wrapper loads
DX:CX and BX:AX and calls register-based `GrMulWWFixed`
(`Library/Kernel/Graphics/graphicsC.asm`). The latter calls
`GrRegMul32ToDDF` (`graphicsMath.asm`). SvgLib's `GrAddWWFixed` and
`GrSubWWFixed` are local C macros, not kernel calls (`Import/svg.h`).
Thus geometry-call overhead and the surrounding loops must be distinguished
from the implementation of the arithmetic primitive itself.
