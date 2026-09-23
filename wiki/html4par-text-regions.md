# Html4Par text regions

`VisTextRange` uses a half-open interval: `VTR_end` is the position after the
last affected character. When `IRegionRepositionResizeAndReflow()` invalidates
a region, its end is therefore `VTR_start + VLTRAE_charCount`. This matches
`VisLargeTextRegionChanged` in `Library/Text/TextRegion/trLargeText.asm` and
the subtraction in `VisTextInvalidateRange` in
`Library/Text/Text/textCalc.asm`.

`TextCheckCanCalcWithRange` rejects a `VisTextRange` when the high word of
`VTR_start` exceeds `TEXT_ADDRESS_PAST_END_HIGH` (0x00ff). A stop at its first
`ERROR_A VIS_TEXT_MUST_PASS_QUALIFIED_RANGE` site therefore reports an
unqualified start address; it does not establish a malformed `VTR_end` or a
suspension error. The invalidation path copies and normalizes the caller's
range, then looks up the first line before `TextRecalc` checks it. Evidence:
`Library/Text/Text/textStuff.asm` (`TextCheckCanCalcWithRange`),
`Library/Text/Text/textCalc.asm` (`VisTextInvalidateRange`, `TextRecalc`), and
`Include/Objects/Text/tCommon.def`.

Text EC checks each region's `VLTRAE_calcHeight` against the sum of its
`LineInfo` heights. `CalculateRegions` invokes the full check on entry and
exit and validates the previous region during its line loop. Thus a stop at
`ECValidateSingleRegion` needs a backtrace to determine whether the bad height
pre-existed this recalculation or was produced during it. The legacy
`WARNING_SPECIAL_CASE_FOR_LARGE_DELETE_INVOKED` marks a backward ripple into
an empty region; it does not itself identify a corrupt region. Evidence:
`Library/Text/Text/textCalcObject.asm` (`CalculateRegions`,
`ECValidateRegionAndLineHeights`, `ECValidatePreviousRegion`,
`FigureNextRegionChangeAndComputeRippleHeight`).

In large text, `TR_RegionSetTopLine` can redistribute line counts across
multiple neighboring regions through `LargeRegionSetTopSomething`, while
`TR_RegionAdjustHeight` changes each region's `VLTRAE_calcHeight` separately.
Text's ripple code must keep those two updates paired. Evidence:
`Library/Text/TextRegion/trLargeSet.asm` (`LargeRegionSetTopLine`,
`LargeRegionSetTopSomething`), `trLargeClear.asm`
(`LargeRegionAdjustHeight`), and `Library/Text/Text/textCalcObject.asm`
(`RippleLinesToNextRegion`, `UpdateRegionHeight`).

`ILayoutCellRegions()` passes `IEdgeCreatePathInRegion()`'s `regionChanged`
result as `forcedRecalc` to `IRegionRepositionResizeAndReflow()`. A changed
region path therefore causes `MSG_VIS_TEXT_INVALIDATE_RANGE` even when the
owning cell's `HTML_CELL_DIRTY_LAYOUT_MASK` is clear and the old/new widths
are both sufficient for `HCD_longestLine`. Evidence:
`Library/Breadbox/Html4Par/htmlclas/htmltcel.goc` (`IEdgeCreatePathInRegion`,
`ILayoutCellRegions`, `IRegionRepositionResizeAndReflow`) and
`CInclude/html4par.goh` (`HTML_CELL_DIRTY_LAYOUT_MASK`).
