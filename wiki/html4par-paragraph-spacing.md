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

For `</a><br><br>`, the anchor record is finalized before the breaks:
`CloseTag()` calls `PopStyle()` for `SPEC_A`, which calls `ParseHREF()`
and records `HTMLanchorData.len = textpos - pos`. `Open_BR()` then calls
`EndLine()` twice; the second call adds bottom spacing to the preceding
paragraph rather than another text character. `AddParaCond()` later
emits the pending CR with those paragraph attributes. Evidence:
`htmlpars/parstags.goc` (`CloseTag`, `PopStyle`, `ParseHREF`, `Open_BR`)
and `htmlpars/htmlpars.goc` (`EndLine`, `AddParaCond`).

Text includes paragraph bottom spacing in `LineInfo.LI_hgt`: see
`Library/Text/TextLine/tlCommonCalc.asm` (`AdjustParagraphEnd`,
`SaveNewLineValues`, `SaveNewLineHeight`). Html4Par mouse hit confirmation
in `htmlclas/htmlclrt.goc:MSG_HTML_TEXT_HIT_FROM_COORD` accepts the full
line height, including this spacing. Coordinate conversion also treats
the spacing as part of the preceding line (`TextSelect/tslMethodMouse.asm`,
`TSL_FigureNearestValidCoord`; `TextLine/tlSmallPosition.asm`,
`CommonLineFromPosCallback`). Link selection calls ordinary text selection;
`TextLine/tlCommonInvert.asm:LineInvertArea` uses the same `LI_hgt` via
`CommonLineGetHeight` to compute the highlight bottom. Thus correct link
character bounds can still produce clickable and inverted paragraph spacing.
