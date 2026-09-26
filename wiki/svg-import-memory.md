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
