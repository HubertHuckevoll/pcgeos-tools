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

With `fetchWhileImport` enabled, the fetch thread does not wait for the UI to
handle `MSG_URL_TEXT_LOAD_GRAPHIC_PROGRESS`; it can choose a progress result
before the callback is cleared. `LoadProgressData.LPD_request` links that
notification to its `URLTextRequestGraphic`, whose `progressCanceled` flag lets
`MSG_URL_TEXT_GRAPHIC_FETCHED` perform the same cleanup for either a file or an
already-selected progress result. Successful handoffs leave the flag clear and
remain owned by the import thread. Keeping the pending request until one of
those owners completes also ensures `URLFetchExtraMemoryFree` runs before fetch
shutdown frees `G_allocBlock`.

Evidence:

- `Appl/Breadbox/BbxBrow/urlframe/URLFRAME.goc`,
  `MSG_URL_FRAME_NOTIFY_FRAME_COMPLETE`
- `Appl/Breadbox/BbxBrow/urlframe/FRFETCH.goc`,
  `MSG_URL_FRAME_URL_FETCHED`, `HandleHTMLError`, and `DialogError`
- `Appl/Breadbox/BbxBrow/navigate/NAVIGATE.goc`, `MsgAborted`
- `Appl/Breadbox/BbxBrow/urltext/URLTEXT.goc`,
  `MSG_HTML_TEXT_FORMATTING_ENDED`, `MSG_URL_TEXT_LOAD_GRAPHIC_PROGRESS`,
  `MSG_URL_TEXT_GRAPHIC_FETCHED`, and `MSG_URL_TEXT_DEC_PENDING`
- `Appl/Breadbox/BbxBrow/urlfetch/URLFETCH.goc`, `URLFetchEngineStop`,
  `URLFetchExtraMemoryAlloc`, and `URLFetchExtraMemoryFree`
- `CInclude/htmlprog.h`, `LoadProgressData.LPD_request`
- `Library/Breadbox/UrlDrv/Wmg3Http/WMG3HTTP.goc`, loading-progress callback
  handling around `LPCT_OPEN` and final `URL_RET_PROGRESS`

Loading-progress callback reads must use the same LPD_sem as asynchronous
cancellation writes. Wmg3Http captures the callback under that semaphore and
releases it before invocation: LoadGraphicProgressCallback itself acquires
LPD_sem for READ/WRITE/CLOSE. A captured callback may finish after cancellation;
the fetch child remains busy until LoadURLToFile returns, keeping its stream
state alive. See WMG3HTTP.goc LoadProgressCallbackSnapshot/HTTPGet and
BbxBrow/urlfetch/URLFETCH.goc URLFetchEngineChild.

`MSG_HMLVA_ABORT_OPERATION` calls `UserAbortStart` and then `ParseAbort`
before aborting the fetch/import engines. `WARNING_PARSE_ABORT_TIMED_OUT`
therefore captures the UI caller waiting for parser completion, not the
parser's own stack. Use Swat `btall` at that warning or at the abort request
in `htmlpars/parsinit.goc` to inspect the other threads. Normal fetched-page
parsing calls `ParseAnyFile` from `MSG_URL_FRAME_URL_FETCHED` in
`urlframe/FRFETCH.goc`; it is not part of the graphic import engine.

Inline SVG capture uses `FileCreateTempFile`. Its collision retry must keep
the basename offset independently of BX: `TimerGetCount` returns its high
word in BX, and `FileCreateCommon` may destroy BX. A retry that restores DI
from BX can write the next name outside the path buffer and repeatedly retry
the unchanged occupied name. Evidence: `Library/Kernel/File/fileOpenClose.asm`
(`FileCreateTempFile`, `FileCreateCommon`) and `Timer/timerMisc.asm`
(`TimerGetCount`). `File/check_temp_file.pl` checks the seed/retry instructions
with BX clobbered and forced collisions, including 32-bit counter wrap.

Queued graphic imports are drained through their normal handler during abort,
not simply removed from the event queue. `ImportThreadAbortAll` in
`htmlview/ImportG.goc` inserts START_ABORT at the front and END_ABORT at the
back. While `numAborts` is nonzero,
`MSG_IMPORT_THREAD_ENGINE_IMPORT_GRAPHIC` skips decoding but still sends
image cancellation and runs its common cleanup: clear
`G_importActive[LPD_loadThread]` when `fetchWhileImport` is true, otherwise
release `LPD_importSync`, then release temporary-file/page-owner resources
and decrement the pending request count. The cancellation receiver in
`urltext/URLTEXT.goc`, `MSG_URL_TEXT_INTERNAL_CANCEL_LIKE_GRAPHICS`, releases
the request's name token even after its image array has been detached.
These queued abort events run after any currently executing import returns.

## Fetch/import thread configuration

With PROGRESS_DISPLAY, numConn controls fetch children (range 1..2, default
1); numImportThreads independently controls import workers (range 1..3,
default 1). Invalid counts fall back to 1. MAX_FETCH_ENGINE_CHILDREN lives
in urlfetch.goh and MAX_IMPORT_THREADS in htmlview/ImportG.goc, under
Appl/Breadbox/BbxBrow/. ImportThreadRequestImportGraphic rotates all requests
through the configured import queues, selecting the work file and MIME
status with the same index. G_importActive remains indexed by fetch child,
not importer; its size follows MAX_FETCH_ENGINE_CHILDREN.

Fetch/import completion is associated with the request, not the import slot:
ImportG.goc releases IPD_loadProgressDataP->LPD_importSync, or clears
G_importActive[LPD_loadThread] when fetchWhileImport is enabled. In
urlfetch/URLFETCH.goc, URLFetchChildThread waits on LPD_importSync after
LoadURLToFile when fetchWhileImport is false. With fetchWhileImport true,
the fetch engine suppresses loading-progress callbacks for the
next request while that fetch child's prior import remains active.

Raster import progress and cancellation are separate channels. BbxBrow supplies
`ImportProgressData.IPD_callback` (`ImportGraphicProgressCallback`, returning
void) and a separate `MimeStatus *` per importer in `htmlview/ImportG.goc`.
PNG and both JPEG importers in `Library/Breadbox/ImpGraph/IMPBMP/` publish
scanline progress by passing the explicit `ImportProgressData *` to that
callback, but check `MS_mimeFlags & MIME_STATUS_ABORT` directly in their
scanline loops (`imppng.goc`, `impjpeg.goc`, `impfjpeg.goc`). GIF stores the
status pointer in `IGS_mimeStatus` and checks it at each `IUpdateGIFState`
step (`ASMIMP/impgif.asm`); its C wrapper publishes progress separately
(`IMPBMP/impgifc.goc:IGIFAnimGrabFrame`). These paths do not use thread-private
storage to bind the progress callback to its import.
