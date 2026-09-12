# Html4Par text regions

`VisTextRange` uses a half-open interval: `VTR_end` is the position after the
last affected character. When `IRegionRepositionResizeAndReflow()` invalidates
a region, its end is therefore `VTR_start + VLTRAE_charCount`. This matches
`VisLargeTextRegionChanged` in `Library/Text/TextRegion/trLargeText.asm` and
the subtraction in `VisTextInvalidateRange` in
`Library/Text/Text/textCalc.asm`.
