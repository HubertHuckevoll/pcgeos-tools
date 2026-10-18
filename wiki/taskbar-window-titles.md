# Taskbar window titles

- The taskbar copies each window-list entry's visual moniker, rather than
  looking up an application name itself. See
  `WindowListListQueryTaskBarItemMoniker` in
  `Library/SpecUI/CommonUI/CWin/cwinFieldUncommon.asm`.
- In `Library/SpecUI/CommonUI/CWin/cwinBase.asm`,
  `OLBaseWinUpdateVisMoniker` handles `MSG_SPEC_UPDATE_VIS_MONIKER` and
  falls through to `OLBaseWinSetWindowEntryMoniker`.
  `OLBaseWinCreateCombinationMoniker` shares title selection with desktop
  icons: it prefers a primary's nonempty text `GPI_longTermMoniker`, using
  the supplied window/app moniker as fallback. It prefixes the title with
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
  window-list entry and desktop icon caption, including when the extra
  title is removed.
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
  `OLMenuedWinSendIconMonikers` uses the shared builder with a zero icon
  handle for text-only `App - Title` captions, unless the app-only hint
  is present. The temporary caption block is freed after synchronous
  delivery; `OLMDWI_iconCaptionMoniker` retains its original source optr,
  not a pointer into that temporary block. The builder is compiled when
  desktop icons are supported even if taskbar/window-list support is off.
  These `CWin` paths are under `Library/SpecUI/CommonUI/`.
