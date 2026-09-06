# Html4Par paragraph spacing

Html4Par defers paragraph boundaries in `EndParagraph()` and merges repeated
boundaries through `insertParagraphFlags`. `TAG_PAR_SPACING` is therefore an
idempotent request for one `INTER_PARAGRAPH_SPACING` addition when
`AddParaCond()` flushes the pending boundary. In contrast, calling `EndLine()`
while a boundary is pending adds spacing directly and accumulates once per
call. See `Library/Breadbox/Html4Par/htmlpars/htmlpars.goc` (`EndParagraph`,
`EndLine`, and `AddParaCond`) and `Library/Breadbox/Html4Par/internal.h`
(`TAG_PAR_SPACING` and `INTER_PARAGRAPH_SPACING`).

`TagStackElement.startPos` records `textpos` when a styled element opens. At
close time, equality with the current `textpos` means that the element emitted
no visible transfer text. See `OpenTag()` and `PopStyle()` in
`Library/Breadbox/Html4Par/htmlpars/parstags.goc`.
