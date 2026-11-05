# Window geometry diagnostics

- `VisCompRecalcSize` in `Library/User/Vis/visCompGeometry.asm` rejects a
  negative size suggestion unless it is exactly `mask RSA_CHOOSE_OWN_SIZE`.
  Other combinations of the high bit and low bits cause
  `UI_BAD_CHOOSE_OWN_SIZE` in EC builds.
- In `Library/User/Vis/visGeometry.asm`, `VisUpdateGeometry` normally uses
  the object's current size as the starting suggestion; it requests the
  desired size if both dimensions are zero. `VisGetSize` in
  `Library/User/Vis/visUtilsResident.asm` computes those current dimensions
  from `VI_bounds` (right minus left, bottom minus top). Thus a bad size
  suggestion on this path can originate in the cached bounds; inspect them
  before assuming the caller explicitly requested that size.
- `OpenWinPrepForReOpen` in `CWin/cwinClassOther.asm` sends
  `MSG_OL_WIN_PREPARE_FIELD_SIZE_CHANGE` when closing a window.
  `OLWinPrepareFieldSizeChange` in `CWin/cwinClassMisc.asm` can replace
  live `VI_bounds` size/position fields with `SpecWinSizeSpec` ratios and
  set `WPSS_VIS_*_IS_SPEC_PAIR*` flags. A minimized parent's document
  windows reopen through window-list `MSG_META_UPDATE_WINDOW` delivery;
  this does not require a direct `MSG_SPEC_SET_ATTRS` on each child.
  `OpenWinUpdateGeometry` in `CWin/cwinGeometry.asm` therefore calls
  `ConvertSpecWinSizePairsToPixels` before reading cached dimensions.
  These `CWin` paths are under `Library/SpecUI/CommonUI/`.
- `MSG_SPEC_SET_ATTRS` carries its set mask in CL and clear mask in CH;
  AX contains the message number (`Include/Objects/visC.def`).
  `OLWinSpecSetAttrs` tests CL for `SA_REALIZABLE` before preparing bounds
  for reopening, not AX.
- For compact generic layouts, HINT_DONT_FULL_JUSTIFY_CHILDREN prevents
  a specific UI from distributing surplus space between children;
  HINT_CUSTOM_CHILD_SPACING sets the normal gap. Wrapping has a separate
  HINT_CUSTOM_CHILD_WRAP_SPACING (CInclude/Objects/genC.goh).
  Evidence: TechDocs/Markdown/Concepts/cgeom.md, sections 12.2.3.4 and
  12.2.7 (child spacing).
- HINT_DIVIDE_WIDTH_EQUALLY belongs on the containing GenInteraction,
  not a GenValue. Children must accept expansion, for example through
  HINT_EXPAND_WIDTH_TO_FIT_PARENT on their interaction wrappers.
  Evidence: TechDocs/Markdown/Concepts/cgeom.md, section 12.2.4.2.
- A GenView with both GVDA_NO_LARGER_THAN_CONTENT and
  GVDA_NO_SMALLER_THAN_CONTENT stays at its document-bounds size. Expanding
  its containing interaction does not remove that limit. To fill a wider
  parent, remove GVDA_NO_LARGER_THAN_CONTENT in that dimension and give the
  view HINT_EXPAND_WIDTH_TO_FIT_PARENT. Evidence:
  TechDocs/Markdown/Objects/ogenvew.md, dimension attributes and size hints.
- GenGlyph's fixed-size hint does not by itself allow a long moniker to
  shrink. HINT_CAN_CLIP_MONIKER_WIDTH enables width clipping in
  CGadget/copenGlyphDisplay.asm:OpenChooseNewGadgetSize and OLGlyphDisplayDraw.
  The resulting DMF_CLIP_TO_MAX_WIDTH only sets a clip rectangle; it does
  not add an ellipsis (Library/User/Vis/visUtilsResident.asm:VisDrawMoniker).
- A glyph's MSG_VIS_VUP_CREATE_GSTATE uses VupCreateGState/ViewCreateGState
  in CUtils/copenUtils.asm to set its specific UI font through
  SpecGetDisplayScheme. Use that state for matching moniker text measurements.
- Scrolling list size hints are forwarded to its generated GenView
  (CItem/citemScrollList.asm:CopySizeToViewIfSpecified). Without a fixed
  width, HINT_EXPAND_WIDTH_TO_FIT_PARENT lets the pane use its parent's
  suggestion, reserving scroll areas before calculating viewport width
  (CView/cviewPaneGeometry.asm:CalcWinSize and CalcTotalSize).
- A GenInteraction's pixel size hint is not an outer-size cap.
  CComp/copenCtrlGeometry.asm:CalcDesiredCtrlSize adds control margins to
  nonzero dimensions, including SST_PIXELS. CalcExtraSize also accounts for
  child extras when a child count is supplied. Avoid a redundant fixed-width
  wrapper when its children already supply the required width; it introduces
  another converted minimum. These paths are in Library/SpecUI/CommonUI.
- MSG_GEN_RESET_TO_INITIAL_SIZE requests fresh window geometry rather than
  retaining cached dimensions. For a non-maximized window,
  CWin/cwinGeometry.asm:OLWinResetToInitialSize sets both dimensions to
  RSA_CHOOSE_OWN_SIZE, marks size/position invalid, and calls UpdateWinPosSize.
  The existing content and sizing hints then determine the size; no fixed
  outer width is required. Evidence: Library/SpecUI/CommonUI/CWin/cwinGeometry.asm.
