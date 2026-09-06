# BbxBrow cancellation

When `G_stopped` is set and the frame text is empty,
`MSG_URL_FRAME_NOTIFY_FRAME_COMPLETE` synthesizes a `URL_RET_MESSAGE` whose
`URLFetchResult.htmlMsg` is `MsgAborted`; it does not return `URL_RET_ABORTED`.
The message is handled by `MSG_URL_FRAME_URL_FETCHED`, where
`HandleHTMLError` expands `<! error4.htm>` before `DialogError` sees it. With
`DIALOG_ERROR` enabled, `DialogError` displays text extracted from the expanded
HTML and `HandleHTMLError` does not parse the HTML into an error page.

Preserving the partial page can leave a formatter completion after Stop has
already reduced `URLTextInstance.UTI_numPendingRequests` to zero.
`MSG_HTML_TEXT_FORMATTING_ENDED` must not call `MSG_URL_TEXT_DEC_PENDING` when
the counter is already zero: that would wrap the word counter to `0xffff` and
also release an object in-use reference which the completion no longer owns.

When `MSG_URL_TEXT_LOAD_GRAPHIC_PROGRESS` handles Stop before it queues an
import, it clears `LoadProgressData.LPD_callback` and releases the fetch/import
barrier. It must leave the image request's name-token reference and pending
count to `MSG_URL_TEXT_GRAPHIC_FETCHED`: clearing the callback makes the fetch
finish with a non-progress result, whose acknowledgement performs that cleanup.
Cleaning up in both messages over-releases the name token while
`HTMLimageData.HID_resolvedURL` still holds it, causing the next page detach to
fail in `NamePoolReleaseToken`.

Evidence:

- `Appl/Breadbox/BbxBrow/urlframe/URLFRAME.goc`,
  `MSG_URL_FRAME_NOTIFY_FRAME_COMPLETE`
- `Appl/Breadbox/BbxBrow/urlframe/FRFETCH.goc`,
  `MSG_URL_FRAME_URL_FETCHED`, `HandleHTMLError`, and `DialogError`
- `Appl/Breadbox/BbxBrow/navigate/NAVIGATE.goc`, `MsgAborted`
- `Appl/Breadbox/BbxBrow/urltext/URLTEXT.goc`,
  `MSG_HTML_TEXT_FORMATTING_ENDED`, `MSG_URL_TEXT_LOAD_GRAPHIC_PROGRESS`,
  `MSG_URL_TEXT_GRAPHIC_FETCHED`, and `MSG_URL_TEXT_DEC_PENDING`
- `Library/Breadbox/UrlDrv/Wmg3Http/WMG3HTTP.goc`, loading-progress callback
  handling around `LPCT_OPEN` and final `URL_RET_PROGRESS`
