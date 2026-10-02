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

An EC-only check after `RippleToNextRegion()` warns with
`WARNING_RIPPLED_REGION_HEIGHT_MISMATCH` when the just-completed region's
stored height differs from its line-height sum. At
`ECWarnCompletedRegionHeightMismatch`, `cx` is the completed region,
`bp.bl` the line-height sum, and `dx.al` the stored height. The existing
fatal validator still runs; this warning locates a divergence at the
ripple boundary. Evidence: `Library/Text/Text/textCalcObject.asm`
(`RippleLinesToNextRegion`, `ECWarnCompletedRegionHeight`).

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

Swat already provides `rwatch on|off` for ripple accounting: it traces
line calculation, old/new heights, inserted/deleted space, and ripple
height/count (`Tools/swat/lib.new/ptext.tcl`, `rwatch`, `rw-after-calc`,
`rw-update-region-height`). Break at
`text::ECWarnCompletedRegionHeightMismatch` to inspect the first detected
completed-region divergence before the fatal validator. The warning uses
`bp` for the line-height sum; select its caller frame before reading
`ss:bp.text::LICL_vars`. `ptext -rE *ds:si` prints region geometry/counts
without text; `ptreg <region>` prints that region's lines.

Html4Par queues `MSG_HTML_TEXT_INTERNAL_LAYOUT_UPDATE_EVENT` with
`forceQueue, checkDuplicate` both at layout start and after each incremental
step (`htmlclas/htmltcel.goc`). GEOS's default duplicate check matches the
message ID and destination object, ignoring arguments; it scans the whole
thread queue unless `MF_CHECK_LAST_ONLY` is set. `SendEvent` allocates the
new event before `CheckDuplicates` and frees it on a match, so this bounds
retained events rather than avoiding every temporary event allocation.
Evidence: `Library/Kernel/Geodes/geodesEvent.asm` (`SendEvent`,
`CheckDuplicates`) and `TechDocs/Markdown/Esp/erout.md`, section 3.3.2.3.
`MSG_HTML_TEXT_CALCULATE_LAYOUT` requests a restart when layout is active
and layout is dirty or view width changed; queue deduplication does not
suppress synchronous calls or requests delivered between incremental steps
(`htmlclas/htmltpos.goc`).

Html4Par's synthetic table 0 is initialized as 1x1 by
`htmlpars/parstags.goc:InitTagStacks`; layout starts directly with cell 0,
not by distributing columns for table 0. In `htmlclas/htmltpos.goc`,
`MSG_HTML_TEXT_CALCULATE_LAYOUT` records the normalized view-width input in
`HTI_formattedWidth`; it is a width-change/cache key, not the resulting
page width. `htmlclas/htmltcel.goc:ICalculateViewSize` adds back a detected
vertical scrollbar and subtracts one scaled pixel. `MSG_HTML_TEXT_LAYOUT_START`
subtracts scrollbar space when required, sets `HTI_viewWidth`, removes the
left margin plus one pixel, then promotes the master allocation to `topMin`.
`MSG_HTML_TEXT_INTERNAL_LAYOUT_UPDATE_EVENT` can promote that allocation again
after measured overflow or image changes.

Nested tables independently expand: `ILayoutTableStart` raises available
width to `HTD_minWidth`. `htmlclas/htmltpre.goc:ICalculateTableMinMax` includes
an authored pixel TABLE width in that hard minimum. Percentage tables instead
return content hard minima, and variable table targets are capped to available
width by `ITableLayoutDetermineWantedWidth`. `htmlclas/htmlcol.goc:SpreadAdd`
uses cell `HCD_hardMinWidth` as the column floor; `SpreadCalculateLayout`
shrinks preferences but never goes below it. That routine overwrites its
`totalWidth` argument with `wantedWidth`, so passing a smaller available width
alone cannot bound its allocation.

Cell allocation becomes `HCD_calcWidth` in `ILayoutCellStandardAction`.
`ILayoutCellRegions` passes allocation minus padding plus one pixel to
`IRegionRepositionResizeAndReflow`. `ICalculateRegionBoundries` in
`htmlclas/htmltpos.goc` takes the furthest formatted region right edge,
subtracting the extra pixel; `MSG_HTML_TEXT_CALCULATE_BOUNDARIES` publishes
that edge as `VLTI_displayModeWidth` and content document bounds. BbxBrow's
`urldoc/URLDOC.goc:ViewTemplate` enables horizontal scrolling; large-content
`MSG_VIS_CONTENT_SET_DOC_BOUNDS` forwards the extent to the view
(`Library/User/Vis/visContentClass.asm:VisContentSetDocBounds`).
