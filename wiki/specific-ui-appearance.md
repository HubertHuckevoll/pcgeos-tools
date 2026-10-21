# Specific UI appearance paths

- ISUI 2000 is a separate specific UI (Library/SpecUI/ISUI2000): its
  local.mk defines raw ISUI2000 for ESP and UIC. CommonUI/cGeode.def and
  cGeode.uih derive _ISUI2000 and enable _ISUI for shared ISUI behaviour.
  New chrome and toolbar hover state/messages are guarded by _ISUI2000;
  original ISUI retains its old colours, drawing and instance layouts.
  ConfigUI/configuiAppearance.ui lists it separately, using the appended
  CUIC_ISUI2000 identifier and fourth uicombos entry in configui.asm.
- Original ISUI is selected by -DISUI in Library/SpecUI/ISUI/local.mk. CommonUI
  defines _ISUI and includes it in _CUA_STYLE (cGeode.def). CommonUI's
  CWin/cwinManager.asm and CView/cviewManager.asm include the specific
  UI's winDraw.asm and viewScrollbarDraw.asm; controls also have ISUI
  branches inside CommonUI, so appearance changes can span both trees.
- ISUI-family button edge colours are stored directly in NormalCBR, DefaultCBR,
  and ListBoxCBR in CommonUI/CButton/copenButtonData.asm, then consumed
  by DrawColorButtonBorderEtchLines in copenButtonColor.asm. They do not
  all follow moCS_dsLightColor/moCS_dsDarkColor. Normal/default outer
  shadows use C_GRAY_27 in ISUI 2000, from the standard grey ramp
  (Include/color.def).
  ISUI/Win/winDraw.asm's OpenWinDrawWindowBorder likewise uses explicit
  palette constants, with a separate colour-menu branch.
  ISUI 2000 normal/default button inner highlights use C_LIGHT_GRAY, leaving a
  single white outer highlight. CComp/copenMenuBar.asm's
  DrawColorOrBWMenuBar fills ISUI 2000 colour menu bars without a raised frame;
  its monochrome and Motif paths still use OpenDrawRect.
- ISUI's title background gradient is implemented in
  OpenWinDrawHeaderTitleBackground/DrawGradientTitle in ISUI/Win/winDraw.asm,
  despite GRADIENT_TITLE_BAR being FALSE in CommonUI/cConstant.def.
  The active gradient is selected when moCS_activeTitleBar differs from
  moCS_titleBar2. Original ISUI defaults both to C_BLUE. ISUI 2000 defaults
  them to C_R0_G1_B2 and C_R3_G4_B5 in CMain/cmainVariable.def, with
  C_GRAY_80 faces and a C_LIGHT_GRAY inactive gradient endpoint. Its
  monochrome table includes moCS_titleBar2 so B/W keeps a solid title.
  CMain/cmainCode.asm reads the endpoints from [motif options] keys
  "active title bar color" and "titleBarGradient"; setting the former
  also sets the latter endpoint before its separate override is read.
- CommonUI/cConstant.def sets DRAW_STYLES to FALSE. Button draw-style
  hint handlers in CButton/copenButtonBuild.asm are conditional on it;
  HINT_DRAW_STYLE_FLAT alone cannot enable that drawing path in this build.
- ISUI header height uses DS_pointSize plus CUAS_WIN_HEADER_Y_SPACING in
  ISUI/Win/winDraw.asm's OpenWinGetHeaderBounds. Caption icon dimensions
  and scrollbar widths are separately fixed in CommonUI/cConstant.def;
  changing the UI font does not scale all chrome together.
  Caption controls are sized by EnableDisableAndPosSysIcon in
  CWin/cwinClassCUAS.asm, not by CUAS_WIN_ICON_HEIGHT. Colour ISUI subtracts
  one pixel from the width slot and four from the header height. ISUI 2000
  uses CUAS_CAPTION_ICON_WIDTH=17 for 16-pixel right-hand controls; the system
  menu still uses CUAS_WIN_ICON_WIDTH. CWin/cwinGeometry.asm and
  cwinClassCommonLow.asm use the caption slot for min/max width and title
  bounds. CButton/copenButtonColor.asm uses native horizontal centering and
  zero inset for system-icon buttons with the compact caption width; wider
  system-menu buttons retain their original inset. Header height and artwork
  remain native. Introductory Done-button widths are recalculated by
  EnableDisableAndPosSysIcon using MSG_VIS_RECALC_SIZE. Title-space reservation
  is separate: OpenWinCalcWinHdrGeometry subtracts fixed caption slots from
  OLWI_titleBarBounds.R_right, and OpenWinPositionSysMenuIcons starts the
  right-hand controls at that reduced bound. Changing a caption-slot constant
  therefore also changes Done-button positioning unless the introductory path
  is explicitly excluded.
- Toolbar appearance spans DrawColorButton in CButton/copenButtonColor.asm
  and ItemDrawColorTool in CItem/citemItemColor.asm (OLIS_DRAW_AS_TOOLBOX).
  ISUI 2000 uses OLButtonIsFlatToolbox/OLButtonDrawToolboxFrame for actual colour
  toolbar buttons, excluding menus, caption buttons, reply buttons and popup
  list fields. Dialog items with OLIS_DRAW_AS_TOOLBOX but no actual toolbar
  use a single bevel in ItemDrawColorTool. TaskBarListClass parents retain
  the two-level shell edge; menus, tabs and monochrome use their old paths.
- Pointer motion reaches OLButtonPtr, OLMenuButtonHandleEvent and OLItemPtr
  through different handlers. ISUI 2000 reports toolbar hits to the containing
  OLWinClass; OpenWinPtr clears hover when no toolbar child claims the hit.
  OpenWinRawUnivLeave also clears it when the pointer leaves or a covering
  window appears. OLButtonVisClose removes references before unbuilding.
  This uses per-object state, not a mouse or keyboard grab.
- GrDrawHLine updates the graphics pen (SetDocPenPos in
  Library/Kernel/Graphics/graphicsLine.asm). OpenDrawRect calls line drawing;
  unlike drawing regions at the current position, it moves the pen.
  OLButtonDrawToolboxFrame saves/restores the pen so later moniker drawing
  still has the original origin.
- ColorScheme has four-bit edge colours (Include/Objects/visC.def), so
  ISUI's WinDrawBoxFrame cannot carry extended palette indices. The menu
  branch uses OpenDrawRect directly, whose BP holds two byte-sized indices.
- Menu separators originate in DrawBWMenuItemGroup despite that name being
  used for colour displays too (CComp/copenMenuItemGroup.asm). ISUI 2000 uses
  DrawISUIMenuSeparator for scheme-shadow/white pairs; monochrome keeps
  one black row. The generic DrawEtchedHLine in copenCtrlCommon.asm uses
  SetColorIfNotClearing to treat non-black ink as an erasing colour, so
  merely changing its caller's initial black to grey does not preserve
  the intended two-colour etch. ISUI 2000 group-box strokes use
  SetEtchedShadowColor for the first row/column, then restore the black
  sentinel before the white/clearing test. Non-black erase ink is preserved.
- GenView borders use OLPaneDraw in CView/cviewPaneWindow.asm. ISUI 2000's
  colour path draws two nested inset rectangles, with C_GRAY_27 for the
  inner top/left shadow. GetFrameWidth in cviewPaneGeometry.asm reserves
  two pixels, or zero for GVA_NO_WIN_FRAME; OLPaneDraw checks that same
  attribute before drawing and retains a separate black monochrome path.
- A browser content rim can also come from its GenDisplayGroup:
  Appl/Breadbox/BbxBrow/UI/mainWrapper.goh places HTMLDisplayGroup between
  the toolbar and status bar. OLDisplayGroupMoveResizeWin in
  CWin/cwinDisplayControl.asm insets the display-group portal by one pixel
  per side. OLDisplayGroupDraw paints the exposed surround independently
  of any GenView border. ISUI 2000 full-size colour mode (OLDGS_MAXIMIZED) uses
  the UI face colour there; overlapping and monochrome modes retain black.
- ObjSwapUnlock preserves flags (Library/Kernel/Object/objectUtils.asm).
  ItemDrawColorTool can therefore test a locked generic parent's class
  with ObjIsObjectInClass and retain the carry result across unlocking.
- DisplayScheme retains byte-sized DS_lightColor/DS_darkColor alongside the
  older four-bit DS_colorScheme (Include/Objects/visC.def). In ISUI 2000,
  AdjustForDisplayType in CMain/cmainCode.asm keeps extended indices in the
  byte fields and maps extended indices to standard grey shades for packed
  frame drawing, avoiding high-index bits corrupting the other nibble.
- ConfigUI's defaultColorLists, ConfigUIDefaultColorScheme and SchemeStrings
  must have matching order. New extended-palette presets are appended to
  preserve existing indices; ConfigUICInitSchemeList exposes only the first
  three presets on displays with 16 colours or fewer. Selecting a preset
  writes [motif options] colour keys via PrefUICDialogPostApply; saved keys
  override compiled UI defaults. ISUI 2000 Default is appended separately
  from the unchanged ISUI Default preset.
- UI startup loads [ui] specific via GeodeUseLibrary in
  Library/User/User/userMain.asm. Missing or unloadable libraries branch to
  useDefaultSpecific, which loads motif.geo/motifec.geo; preferences' font
  settings are independent. A correct specname or font therefore does not
  prove that the selected specific UI was loaded.
- Specific UI identifiers, not the visible order of UIList children, index
  ConfigUI's uicombos. ISUI 2000 is identifier 3 and the fourth table entry.
  Its EC selection uses the GEOS long name "EC ISUI 2000" because packaging
  Dosify in Tools/build/build/fileutil.pl maps isui2000ec.geo to isui200e.geo.
  Normal builds use isui2000.geo. The hand-maintained Installed/Makefile must
  list isui2000 in minimalLibrary as well as declaring its MAKELIB target;
  bbxensem.filetree alone only registers copying, not building.
- ConfigUI's UICombo table stores UIC_colorScheme and UIC_colorScheme16.
  PrefUICDialogSPUIChanged applies them only for a valid, determinate UI
  selection whose status DL has GIGSF_MODIFIED set. PrefItemGroup's
  MSG_META_LOAD_OPTIONS sends status with that bit clear
  (Library/Config/Pref/prefItemGroup.asm), so load/reset and redundant clicks
  preserve custom colours. B/W skips palette changes; other <=16-colour
  displays use the table fallback. SchemesList is set, marked modified and
  sent MSG_GEN_ITEM_GROUP_SEND_STATUS_MSG, reusing PrefUICSetDefaultColor.
  Scheme changes do not touch UIList. ConfigUIDialogApply calls SetUIOptions
  only if UIList is modified, preserving both theme-only changes and manual
  theme choices made after selecting a UI combo.
- OLButtonRerecalcSize obtains natural size from OpenGetMonikerSize and
  BWButtonRegionSetStruct moniker insets, then adds reply/default-ring space.
  OpenChooseNewGadgetSize consumes AX/BX parent suggestions and CX/DX natural
  size; OLButtonApplySizeHints runs before and after that choice. ISUI 2000
  applies font-based preferences before those existing decisions, preserving
  parent expansion/clipping and fixed/min/max/initial hints. Its temporary
  calculation GState is destroyed after native VisConvertSpecVisSize calls.
- MO_REPLY_BUTTON_INSET_X/Y also describe default-ring drawing. ISUI 2000
  separates its one-pixel ring from the content insets in the ISUI reply and
  default-reply BW region tables (CButton/copenButtonData.asm). Keeping both
  tables' content insets equal prevents default-state geometry changes and
  mismatches with coloured moniker drawing. Command centering is applied in
  both SetupMonikerArgs and OLButtonDrawMoniker.
- SetTextMargins in CGadget/copenTextBuild.asm sets VTI_tbMargin, which feeds
  VisText's height calculation. ISUI 2000 changes only unconstrained normal
  single-line defaults; CompSizeHintArgs.CSHA_height is checked in fixed/max
  hints so width-only hints do not suppress the new inset. Pen and CGA paths
  keep their existing margins. OLSpinGadgetBuild adjusts only an unset,
  framed, non-slider default desired height before scanning/applying hints;
  GetTextPosition already centers its text within the resulting bounds.
- Express menu construction in Library/User/UI/uiExpress.asm uses cached
  CheckIfRunningISUI detection independently of SpecUI compile flags. Both
  eight-character permanent names, "isui    " and "isui2000", must be recognized
  there for the ISUI menu restructuring in ExpressMenuControlGenerateUI and
  ExpressMenuControlTweakDuplicatedUI. GeodeFind matches permanent names for
  EC and NC alike (Library/Kernel/Geodes/geodesHandle.asm).
- The Express launcher cannot be classified solely by normal button menu flags:
  OLMenuButtonSetup clears OLBSS_MENU_DOWN_MARK for HINT_EXPRESS_MENU, and
  OLButtonHintExpressMenu omits OLBSS_SYS_ICON with the taskbar enabled
  (CommonUI/CButton/copenButtonBuild.asm). ISUI 2000 command-size/centering
  preferences therefore exclude that generic hint explicitly.
- ISUI-family menu radio items and checkboxes both call ItemDrawISUICheck in
  CItem/citemItemCommon.asm, from citemItemColor.asm and citemItemBW.asm.
  DH retains OLII_state, including OLIS_IS_CHECKBOX, at this shared entry;
  ISUI 2000 uses that bit to distinguish checks from radio bullets before
  GetCheckboxBounds overwrites DX. Classic ISUI uses checks for both;
  toolbox items bypass this routine. Both menu paths force full repaint on ordinary
  item-state changes, so the caller clears an old mark before drawing a new one.
- Dropdown and submenu marks have separate colour and monochrome tables in
  CButton/copenData.asm, consumed by DrawColorButtonMenuMark and
  DrawBWButtonMenuMark. ISUI's down glyphs occupy 7 by 4 pixels in a 16 by 8
  bitmap. Classic ISUI monochrome ink starts at x=9 and colour ink at x=8;
  ISUI 2000 uses x=8 for both.
  Right-arrow ink matches in both tables. OL_DOWN_MARK_WIDTH also controls
  popup-list frame regions and text reservation; it is not just glyph width.
- ISUI-family colour checkboxes use a fixed 13 by 13 four-bit border and
  GetDarkColor for their tick in classic ISUI, black in ISUI 2000. ISUI 2000
  menu and monochrome checkbox ticks match the colour tick's ink coordinates.
  Colour radios use a masked 12 by 12
  border and black bullet (CItem/citemItemColor.asm). Both position through
  GetCheckboxBounds; monochrome radios instead center using RADIO_HEIGHT.
  The radio wrapper's calculated bevel colours are not consumed by the
  bitmap renderer. These paths inherit disabled masks from ItemDrawColorItem.
- OLItemUpdateDrawState in CItem/citemItemCommon.asm suppresses selected
  emphasis for OLIS_INDETERMINATE and sets ISUI depressed emphasis only in
  menus. OLItemSetState redraws through OLItemDrawIfNewState, which compares
  cached drawing flags rather than the indeterminate bit. Adding a visible
  mixed checkbox state therefore also needs its redraw transitions handled;
  changing only the bitmap selection does not cover every transition.
- ISUI scrollbars and spinner arrows share ISUI/View/viewScrollbarDraw.asm.
  OLSA_TWISTED selects spinGadget; DrawSBPart sets an inherited stack frame
  containing attrs, selected? (zero means pressed), position and parameters.
  Arrow tables contain four eight-byte edge records and four six-byte bitmap
  descriptors; thumb tables contain the same edges and one eight-byte fill.
  ISUI 2000's DrawISUI2000SBFrame reads those existing bounds. Its colour
  HVUpDownArrow path skips the old outside bitmaps after filling the whole face,
  uses separate compact triangle descriptors for normal scrollbars and spinners,
  and embosses disabled ink. The old inside bitmap offsets identify the four
  normal directions; unmatched CGA bitmaps retain the old descriptor path.
  DrawPageUpDownArea selects the pressed page using OLSBI_state and table offsets.
  MO_SCROLLBAR_WIDTH in CommonUI/cConstant.def is 16 for ISUI 2000, while
  MO_ARROW_WIDTH remains the 12-pixel bitmap canvas. MO_ARROW_BITMAP_INSET
  centers that canvas in the wider monochrome frames. Colour normal arrows
  instead use the ISUI2000ArrowUp/Down/Left/Right descriptor pairs: compact
  6-by-3 ink (rotated horizontally), with only the coordinates shifted for a
  press. cviewScrollbar.asm sizes twisted
  spinners with MO_ARROW_WIDTH+3 to retain their 15-pixel width;
  DoScrollCriteria in cviewScrollbarSelect.asm uses the shaft width for normal
  hit testing and the separate original spinner width for OLSA_TWISTED.
- OpenDrawRect in CUtils/copenUtils.asm dereferences *ds:si to set disabled
  dithering; scrollbar DS:SI instead points to drawing tables. ISUI 2000's
  OpenDrawRectSolid shares the native DrawFrame strokes without that object
  access and sets a solid line mask. Both take exclusive bounds and BP low/high
  byte LT/RB colours; both move the graphics pen. Dropdown painting saves and
  restores that pen before moniker drawing. ClearSpinDisplay in
  CGadget/copenSpinGadget.asm uses the solid entry at the original field bounds.
- ISUI 2000 colour dropdown fields are selected in DrawColorButton by
  OLBSS_MENU_DOWN_MARK, excluding menu, menu-bar and system-icon objects.
  OLButtonDrawISUI2000DropDown retains OL_DOWN_MARK_WIDTH; its matching mark
  renderer preserves the caller's area mask and shifts only pressed glyph ink.
  Their bounds and hit handling remain in the existing geometry/event paths.
  DrawColorButton calls OLButtonSetDrawColors before the dropdown mark and
  draws the moniker afterward. OLButtonDrawISUI2000DropDownMark saves/restores
  the GState to preserve the moniker colour and full mask (including custom
  masks). Library/Color/Art/mkrAreaPattern.ui uses GSFillBitmapAtCP with BMF_MONO,
  which takes the current area colour; pattern/draw-mask samples in
  Library/Color/UI/uiColor.ui inherit that ink too.
- MakePopupListIfNeeded in CItem/citemItemGroupClass.asm synthesizes a popup
  GenInteraction and copies HINT_GADGET_TEXT_COLOR without modifying it. ISUI
  variants also copy HINT_GADGET_BACKGROUND_COLORS. CopyHintIfSpecified handles
  zero, two or four data bytes, saving both words before ObjVarAddData can
  relocate the source. ISUI 2000 field painting honours both normal background
  colours. OLButtonSetDrawColors uses the unselected text/area colour for
  standalone dropdowns; their background is likewise painted in normal colours.
- DrawColorButton applies MM_INVERT after OLButtonDrawMoniker for enabled,
  depressed standalone ISUI-family dropdowns. This covers the completed image,
  including fixed-colour GStrings and colour samples, rather than recolouring
  just monochrome ink. The rectangle starts two pixels inside the field and
  ends before the arrow: right bound minus OL_DOWN_MARK_WIDTH+2 in ISUI 2000,
  minus OL_DOWN_MARK_WIDTH+3 in classic ISUI, bottom bound minus three.
  Empty interiors are skipped. GrSaveState/GrRestoreState preserve masks and
  mix mode around the solid fill. Full normal repaint precedes inversion on
  every draw; native clipping handles partial exposure. No additional theme
  setting is involved. Menu/caption controls and Motif retain their old paths.
- Framed GenText backgrounds have two paint paths: OLTextDraw in
  CGadget/copenTextCommon.asm fills the full bounds via OpenDrawAndFillRect;
  VisText clears its interior with VTI_washColor, clipped inside VTI_tbMargin
  and VTI_lrMargin (Text/TextRegion/trSmallGState.asm, SmallSetClip).
  With DRAW_STYLES=FALSE, TextWhiteWashColor in copenTextBuild.asm sets white
  but does not set TDSS_COLOR_SET, unlike TextWashColor. OLTextDraw therefore
  uses OpenSetInsetRectColors' UI face fill for the margins even though the
  text interior is white. Larger text margins expose this colour mismatch.
  ISUI 2000's setNormalColors path now overrides only the fill with the full
  VTI_washColor ColorQuad after obtaining the normal bevel colours, so margins
  match the text interior without changing the border or classic UI builds.
  MSG_VIS_TEXT_SET_WASH_COLOR also changes only VisText's wash colour, without
  setting the specific UI flag (Text/Text/textMethodInstance.asm).
- GrSetMixMode(MM_INVERT) inverts existing destination pixels, ignoring source
  colour (Include/graphics.def, MixMode). A post-draw filled region can invert
  a completed moniker without an offscreen bitmap; ReDrawBWButton in
  CButton/copenButtonBW.asm already does this for menu focus when
  _MENU_BUTTONS_SHOW_FOCUS_BY_INVERTING is enabled. It saves/restores the mix
  mode around DrawBWRegionAtCP. This is not a contrast-selection operation:
  8-bit VidMem uses NOTtable in Driver/Video/Dumb/VidMem/Clr8/clr8Output.asm;
  24-bit ModeINVERT complements RGB in Clr24/clr24Output.asm. Graphical monikers
  are GStrings played by VisDrawMoniker (Library/User/Vis/visUtilsResident.asm)
  and can set their own colours or mix mode, so caller text/area colours do
  not universally recolour them.
