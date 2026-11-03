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
