# SvgLib SVG round trips

The exporter writes SVG tags through `SvgWriter` in
`Library/SvgLib/Export/svgWriter.c`. Before truncating the destination,
`SvgExport()` replays through `SvgExportCountingSink`, which calls the same
`SvgWriterCountTags()` used by the Linux test. The importer accepts at most
8191 bytes between `<` and `>` in a tag, including newlines inside the root
tag. Evidence: `Library/SvgLib/Export/svgExport.goc`,
`svgExportWriter.goc`, `svgWriter.c`, and
`Library/SvgLib/Import/svgParse.goc` (`SvgParserScanNextTag`).

SVG dash lengths are divided by the untransformed stroke width and rounded
to GEOS byte factors by `Library/SvgLib/Import/svgDash.c`; the importer calls
this core from `SvgStyleApplyDash` in `svgStyle.goc`. The C declaration of
`DashPairArray` uses words, but the kernel stores each dash element as a byte.
GEOS EC limits skip distance to a signed byte and rejects zero dash elements.
Evidence: `CInclude/graphics.h` (`DashPairArray`, `GrSetLineStyle`),
`Library/Kernel/Graphics/graphicsC.asm` (`GRSETLINESTYLE`), and
`graphicsState.asm` (`SetLineStyle`).

The Linux check `Library/SvgLib/Export/tests/svg_roundtrip_test.c` links the
actual writer, dash converter, and path/point syntax validator. It does not
execute the GEOS GString/VM adapters in `SvgImport()` or `SvgExport()`.
