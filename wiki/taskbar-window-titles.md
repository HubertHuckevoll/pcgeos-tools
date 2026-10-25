# Taskbar window titles

- The taskbar copies each window-list entry's visual moniker, rather than
  looking up an application name itself. See
  `WindowListListQueryTaskBarItemMoniker` in
  `Library/SpecUI/CommonUI/CWin/cwinFieldUncommon.asm`.
- In `Library/SpecUI/CommonUI/CWin/cwinBase.asm`,
  `OLBaseWinUpdateVisMoniker` handles `MSG_SPEC_UPDATE_VIS_MONIKER` and
  falls through to `OLBaseWinSetWindowEntryMoniker`.
  `OLBaseWinSetWindowEntryMoniker` prefers a primary's nonempty text
  `GPI_longTermMoniker`, then the window moniker, then the app moniker.
  `OLBaseWinCreateCombinationMoniker` combines the selected text with an
  icon in a temporary LMem block; it does not prepend an app name or
  change the source monikers.
  The window-list entry is replaced and `UpdateTaskBarList` is called.
- App fallback monikers need not share a handle with the application's
  original moniker. `OLMenuedWinFindTitleMoniker` in
  `Library/SpecUI/CommonUI/CWin/cwinMenuedWin.asm` uses `VMSF_COPY_CHUNK`
  to copy the app moniker into a primary that lacks its own caption, then
  stores the copy in `GI_visMoniker`. Pointer identity alone cannot
  distinguish that caption from a document/window title.
- The browser uses this window-title mechanism: `URLDocumentClass` handles
  `MSG_URL_DOCUMENT_NOTIFY_TOP_CHANGE` in
  `Appl/Breadbox/BbxBrow/urldoc/URLDOC.goc` by sending
  `MSG_GEN_REPLACE_VIS_MONIKER_TEXT` to its display or primary window, using
  the page title or URL. With neither available, it uses `Untitled`.
- Title-bar drawing is separate from taskbar composition:
  `OpenWinDrawMoniker` in `CWin/cwinClassCommonLow.asm` draws
  `GI_visMoniker` and, for a primary with room, a separator and
  `GPI_longTermMoniker`. It does not independently prepend the app name.
  `OLMenuedWinFindTitleMoniker` in `CWin/cwinMenuedWin.asm` copies the app
  name into a primary only when its own moniker is missing. Thus replacing
  that primary's `GI_visMoniker` with a browser page title/URL replaces the
  app caption rather than automatically keeping it as a prefix.
- A primary's visible title can also include `GPI_longTermMoniker`, which
  is separate from `GI_visMoniker`. `GenDisplayControlUpdateUI` in
  `Library/User/UI/uiDispCtrl.asm` copies the active maximized display's
  name into that field through `MSG_GEN_PRIMARY_REPLACE_LONG_TERM_MONIKER`.
  GeoDraw delegates primary document-name display to this controller
  (`Appl/GeoDraw/UI/uiDocument.ui`, `DrawDocumentControlObj`).
  `OpenWinDrawMoniker` in `cwinClassCommonLow.asm` draws this extra text.
  `OLBaseWinUseLongTermMoniker` redraws the header and refreshes the
  window-list entry, including when the extra title is removed.
  Overlapping document windows clear the primary's extra title; the
  taskbar then uses the ordinary fallback.
- `MSG_GEN_PRIMARY_GET_LONG_TERM_MONIKER` provides public access to a
  primary's extra title: `Include/Objects/gPrimC.def` allows any sender
  and specifies a chunk handle returned in AX. The chunk is in the
  primary's object block, not the caller's block. Implementation:
  `GenPrimaryGetLongTermMoniker` in `Library/User/Gen/genPrimary.asm`.
- Minimized desktop icons use a separate caption path in
  `CWin/cwinMenuedWin.asm`: `FindIconMonikers` selects abbreviated text
  from the window or app into `OLMDWI_iconCaptionMoniker`; it does not
  inspect `GPI_longTermMoniker`.
  `HINT_DISPLAY_USE_APPLICATION_MONIKER_WHEN_MINIMIZED` forces app monikers.
  `OLMenuedWinSpecUpdateVisMoniker` calls `UpdateAllMonikers`, which finds
  the captions and sends `MSG_OL_WIN_ICON_UPDATE_MONIKER` through
  `OLMenuedWinSendIconMonikers`. `OLWinIconUpdateMoniker` in
  `CWin/cwinWinIcon.asm` copies the caption into the icon's object block
  and updates the separate `OLWinGlyphDisplay` caption object.
  `MSG_OL_MENUED_WIN_UPDATE_ICON_MONIKER` already exposes that refresh path.
  These `CWin` paths are under `Library/SpecUI/CommonUI/`.
- Taskbar entries use the shared toolbox-item moniker drawing path in
  `CommonUI/CItem/citemItemColor.asm`, `ItemDrawColorItem`. Ordinary items
  retain left justification and vertical centering; the tab-style test must
  not overwrite AL (DrawMonikerFlags) with `OLII_extraRecord`. The native
  `TOOLBOX_INSET_X/Y` values are two pixels (`CItem/citemConstant.def`),
  which only cover the taskbar's double border. For colour taskbar entries,
  `ItemDrawColorItem` checks for a `TaskBarListClass` parent and uses
  `TOOLBOX_INSET_X + 2` horizontally, leaving face padding inside that frame.
  `OLButtonDrawMoniker` supplies matching left/right insets and
  `CUtils/copenMoniker.asm:SetupMaxWidth` subtracts both before clipping.
- Taskbar buttons are a separate dynamic list backed by the field's window
  list. `OLFieldUpdateTaskBarList` sets their destination to
  `OLFI_windowListList`; `WindowListListSelectItem` resolves the button's
  positional identifier with `MSG_GEN_FIND_CHILD_AT_POSITION` and sends
  `MSG_META_NOTIFY_TASK_SELECTED` to the window-list item
  (`CommonUI/CWin/cwinFieldUncommon.asm`). The item stores the actual window
  optr in `OLWLI_windowObj`; `OLWindowListItemNotifyWindowSelected` raises
  its geode and queues the notification to that window.
  `OLWindowListItemCloseWindow` instead queues `MSG_GEN_DISPLAY_CLOSE`
  directly to that window (`CommonUI/CWin/cwinBase.asm`). Taskbar button
  identifiers are therefore positions, not window optrs.
- A window's existing system menu is not guaranteed to exist as a popup.
  `OpenWinEnsureSysMenu` in `CommonUI/CWin/cwinClassCUAS.asm` checks
  `OWA_HAS_SYS_MENU`; in non-ISUI builds, clearing `UIWO_WINDOW_MENU`
  creates only a close button and sets `OWA_SYS_MENU_IS_CLOSE_BUTTON`.
  This is a window-chrome construction choice, not a general popup ban:
  `OLMenuWinActivate` and `OLPopupGenInitiate` do not test
  `UIWO_WINDOW_MENU`. An independently created taskbar popup need not
  change that option. `OpenWinDuplicateBlock` in `CommonUI/CWin/cwinUtils.asm`
  sets the copied block's output to the owning window and its upward
  generic parent link; copying the resource alone does not establish these.
  Normal menu copies are referenced by `OLWI_sysMenu` and target the
  owning window. `OLMenuWinActivate` in `CommonUI/CWin/cwinMenu.asm`
  accepts a position through `MSG_OL_POPUP_ACTIVATE`, calls
  `VisSetPosition`, and requests native keep-visible/shrink-to-fit
  constraints. This differs from the OpenLook-only background-menu code
  in `CommonUI/CWin/cwinPtr.asm:OpenWinStartMenu`.
- A context-menu lookup must be distinguished from normal task selection:
  `OLBaseWinNotifyWindowSelected` in `CommonUI/CWin/cwinBase.asm` explicitly
  sends `MSG_GEN_DISPLAY_SET_NOT_MINIMIZED` and then `MSG_GEN_BRING_TO_TOP`.
  Default two/three-button input maps in `Library/User/User/userMain.asm`
  map unmodified `BUTTON_2` to `MSG_META_START_MOVE_COPY`, not
  `MSG_META_START_FEATURES`; `userFlowInput.asm:TranslateButton` uses the
  active mapping. `OLItemClass` inherits `OLButtonClass`; with `BUBBLE_HELP`,
  its inherited `OLButtonStartMoveCopy`/`OLButtonEndMoveCopy` handlers
  create/destroy bubble help and grab/release the mouse
  (`CommonUI/CButton/copenButtonCommon.asm`). These are existing behaviors
  to account for when adding a taskbar context-menu input path.
- Minimized-window popups need explicit visibility treatment.
  `OLMenuedWinGenSetMinimized` sets `SA_BRANCH_MINIMIZED` and clears
  `SA_REALIZABLE` on the window (`CommonUI/CWin/cwinMenuedWin.asm`).
  `Library/User/Vis/visComp.asm:VisCompUpdateWindow` hides window groups
  whose `VisGetGenBranchInfo` result includes `GBI_BRANCH_MINIMIZED`.
  `visSpecUtils.asm:VisContinueGenBranchCheck` provides a native exception:
  `VA_BRANCH_NOT_MINIMIZABLE` clears that result. Modal dialogs use this
  attribute (`CommonUI/CWin/cwinDialog.asm`); ordinary system-menu
  construction does not set it.
- System-menu action reuse does not by itself supply minimized-window
  semantics. `OLMenuedWinRestoreWin` checks `OLWSS_MINIMIZED` to choose
  unminimize versus unmaximize. `OLMenuedWinTranslateToGenMessage` maps
  Maximize only to `MSG_GEN_DISPLAY_SET_MAXIMIZED`; the existing
  `OLWinIconMaximizeFromIcon` in `CommonUI/CWin/cwinWinIcon.asm` sends that
  message and then falls through to explicitly unminimize the primary.
  `OpenWinPositionSysMenuIcons` in `cwinClassCUAS.asm` mixes title-bar
  layout, UI control policy and command enablement; its helper
  `EnableDisableSysMenuItem` targets `OLWI_sysMenu` and skips menu entries
  in Close-only mode. It is not an independent taskbar-menu state updater.
- Normal taskbar registration is per GenPrimary, not per application or
  document display. `CSpec/cspecPrimary.asm:OLBuildPrimary` normally chooses
  `OLBaseWinClass`; its spec-build/attach handlers call
  `CWin/cwinBase.asm:EnsureItemAddedToWindowList`. That routine requires
  `GS_USABLE`, skips an existing entry, custom bottom-layer windows
  (`OWMFA_CUSTOM_WINDOW` plus `ATTR_GEN_WINDOW_CUSTOM_LAYER_PRIORITY` equal
  to `LAYER_PRIO_ON_BOTTOM`), and either `HINT_AVOID_MENU_BAR` or
  `HINT_PRIMARY_AVOID_MENU_BAR_IF_EXTENDIBLE_SYSTRAY`. It does not require
  closable/minimizable/maximizable capability or non-minimized state.
  `OLDisplayWinClass` is a sibling of `OLBaseWinClass` under
  `OLMenuedWinClass`, so ordinary GenDisplays do not inherit registration.
  With window-icon support, `HINT_WIN_ICON` can resolve a GenPrimary to
  `OLWinIconClass` instead of `OLBaseWinClass`.
- Positioned popup activation and stay-up initiation are distinct:
  `CWin/cwinMenu.asm:OLMenuWinActivate` handles `MSG_OL_POPUP_ACTIVATE`,
  clears `OMWSS_IN_STAY_UP_MODE`, sets the position and starts grabs;
  `OLMenuWinInitiate` handles `MSG_GEN_INTERACTION_INITIATE` and explicitly
  sends `MSG_MO_MW_ENTER_STAY_UP_MODE`. Buttonless menu gadget/focus
  queries use the generic parent (`OLMenuWinGrabRemoteGadgetExcl`,
  `OLMenuWinCallButtonOrGenParent`). Positioning alone does not establish
  the desired click-release interaction.
- `CWin/cwinBase.asm:EnsureItemRemovedFromWindowList` destroys the backing
  item and requests taskbar list reinitialization. Positional button IDs
  must not be treated as stable identities across an open popup's lifetime.
  `CWin/cwinFieldUncommon.asm:OLWindowListItemDestroy` now invalidates the
  taskbar popup before the entry's chunk can be reused, rather than waiting
  for the subsequent list refresh.
- `CWin/cwinFieldUncommon.asm:ToolAreaAutoHide` postpones hiding while the
  first child's Express menu or the taskbar context menu is visible.
  Both lookups depend on the tool area's child order; the Express control
  is inserted ahead of the template children.
- A buttonless popup's generic parent need not supply a live native window
  for the remote gadget grab. `CWin/cwinMenu.asm:OLMenuWinCallButtonOrGenParent`
  sends to `GenCallParent`; `cwinClassCommonMiddle.asm:OpenWinVupQuery`
  translates the remote grab into `MSG_VIS_TAKE_GADGET_EXCL`.
  `Library/User/Vis/visComp.asm:VisCompTakeGadgetExcl` stores the object
  reference and stops propagation at a window group, without requiring
  `VCI_window` or visible state.
  The popup window's visual parent is separately selected through
  `CWin/cwinUtils.asm:GetVisParentForDialog`; `CUtils/copenAppCommon.asm:
  OLApplicationGupQueryVisParent` returns the application and its field
  window for `SQT_VIS_PARENT_FOR_POPUP`.
  `CWin/cwinClassCommonHigh.asm:OLWinGupQuery` passes `SGQT_WIN_GROUP`
  uphill if `VCI_window` is zero, so `cwinClassCommonLow.asm:
  OpenWinModifyWithNearestWinGroupPriority` does not use a minimized
  primary's absent window handle. Custom parent/priority inheritance
  from such a primary is therefore not established by this path.
- The first/global UI thread cannot synchronously call an application
  thread. `Library/Kernel/Geodes/geodesEvent.asm:ObjMessage` rejects
  cross-thread `MF_CALL` with `CANNOT_REMOTE_CALL_FROM_UI` in EC builds;
  the input-manager thread and secondary UI threads are exceptions.
  Use queued requests and replies when UI-owned controls need app-owned
  state. Ordinary messages to objects on the current thread are direct
  calls unless `MF_FORCE_QUEUE` is set (same routine's documented contract).
- Normal button activation queues `MSG_GEN_TRIGGER_SEND_ACTION` at the
  front of the owning thread's queue (`CButton/copenButtonCommon.asm:
  OLButtonActivate`). `GenProcessAction` and `GenOutputAction` then dispatch
  the recorded action to its destination; an action targeting the same UI
  thread does not require another queue round trip (`Library/User/Gen/
  genUtils.asm`, `genClassCommon.asm`). `ATTR_GEN_TRIGGER_IMMEDIATE_ACTION`
  instead invokes the trigger before normal menu completion; it is not
  required merely to deliver a command to another object on that thread.
