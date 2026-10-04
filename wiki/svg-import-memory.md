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

BbxBrow calls `SvgImport()` through ImpGraph's `ImpSVG()`. The SVG
`IBP_maxPixels` check occurs after import and GString bounds calculation;
`TE_OUT_OF_MEMORY` from `SvgImport()` sets `MIME_STATUS_MEMORY_LIMIT` and
returns `IBS_NO_MEMORY` from `ImpSVG()`. Evidence:
`Library/Breadbox/ImpGraph/MAIN/impgraph.goc` (`ImpSVG`) and
`Appl/Breadbox/BbxBrow/htmlview/ImportG.goc`
(`MSG_IMPORT_THREAD_ENGINE_IMPORT_GRAPHIC`).

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
