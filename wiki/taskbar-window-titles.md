# Taskbar window titles

- The taskbar copies each window-list entry's visual moniker, rather than
  looking up an application name itself. See
  `WindowListListQueryTaskBarItemMoniker` in
  `Library/SpecUI/CommonUI/CWin/cwinFieldUncommon.asm`.
- In `Library/SpecUI/CommonUI/CWin/cwinBase.asm`,
  `OLBaseWinUpdateVisMoniker` handles `MSG_SPEC_UPDATE_VIS_MONIKER` and
  falls through to `OLBaseWinSetWindowEntryMoniker`. For primary windows,
  the latter selects a nonempty text `GPI_longTermMoniker`, then uses the
  window's text moniker or the application's text moniker as fallback.
  `OLBaseWinCreateCombinationMoniker` prefixes the selected title with
  the app name and " - ", or uses just the app name when the selected
  moniker is the app fallback, empty, or not text. Ordinary window captions
  whose text equals the app name are also suppressed; a selected primary
  `GPI_longTermMoniker` with that same text is still appended. Text is built
  in the existing temporary LMem block; the source monikers are unchanged.
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
