# Html4Par images

`HTMLimageData.imageALT` contains the authored `ALT` value, including an empty
one, or the literal fallback `Image` when the attribute is absent. There is no
separate flag in the current public structure that distinguishes the fallback.
See `ParseImage()` in
`Library/Breadbox/Html4Par/htmlpars/opentags.goc` and `HTMLimageData` in
`CInclude/html4par.goh`.

`ImageURLGetUnsupportedFormat()` in
`Appl/Breadbox/BbxBrow/urltext/URLTEXT.goc` returns true only when the final
URL path extension maps to an image MIME type and no installed MIME driver
handles that type. Query strings and fragments are ignored; unknown and
extensionless URLs still reach the URL driver. `InitNavigation()` seeds known
unsupported-format associations before `LoadMimeTypes()`, so an installed
driver remains authoritative.

`ParseImage()` tokenizes a selected `SRCSET` URL in place with
`NamePoolTokenizeLenDOS()` and its explicit byte length. Avoid adding another
URL-sized local buffer there: the DBCS implementation of
`NamePoolTokenizeLenDOS()` already uses a 128-character stack conversion
buffer in `Library/Breadbox/Html4Par/wwwtools/namepool.goc`.

`ImportLockCacheToken()` in `Appl/Breadbox/BbxBrow/htmlview/ImportG.goc`
leaves one cache reference owned by the import request and acquires another
for the caller/notification. The normal final replacement drops the request
reference and transfers the other to
`MSG_URL_TEXT_INTERNAL_REPLACE_LIKE_GRAPHICS`, which releases it. A cancellation
message carries only a name token and cannot release either of those cache
references; it releases only references stored in matching image records.
`ObjCacheAddURL(..., TRUE, TRUE)` creates a locked non-cacheable entry, and
`ObjCacheUnlockItem()` destroys its VM chain when the last reference goes away.
Evidence: `ImportLockCacheToken`, `MSG_IMPORT_THREAD_ENGINE_IMPORT_GRAPHIC`,
`MSG_URL_TEXT_INTERNAL_CANCEL_LIKE_GRAPHICS` in `urltext/URLTEXT.goc`, and
`ObjCacheAddURL`/`ObjCacheUnlockItem` in `navigate/NAVCACHE.goc`.

Intelligent image admission happens at import time. BbxBrow passes
`T_importGraphicRequest.imageMaxPixels` (800L*600L for Intelligent-mode
inline images, 0 elsewhere) into the import and the MIME drivers:
`ToolsImportGraphicByDriver()` gains a `maxPixels` argument,
`ImportGraphicByNative()` reads the loaded driver protocol and calls MIME
entry 4 (`MimeDrvGraphicEx2`, protocol 4.3) with `extFlags` 0 and
`maxPixels`; older drivers set `MIME_STATUS_DEFERRED` (0x2000) and import
nothing. ImpGraph entries 0 and 3 forward `maxPixels` 0 to a common
dispatcher; entry 4 threads `maxPixels` through ImpGIF/ImpJPG/ImpPNG, which
reject images whose width exceeds `maxPixels / height` after reading the
format header and before any bitmap work, setting `MIME_STATUS_DEFERRED`
with no bitmap (zero dimensions are an ordinary format failure, not
deferred). `MSG_IMPORT_THREAD_ENGINE_IMPORT_GRAPHIC` always imports and
sends `MSG_URL_TEXT_INTERNAL_DEFER_LIKE_GRAPHICS` when the constrained
import reports DEFERRED or MEMORY_LIMIT; ordinary failures mark the image
broken. For the same Intelligent-mode inline requests,
BbxBrow passes `UFF_LIMIT_SIZE` through `URLFetchRequest()` and
`LoadURLToFile()` to `URB_RQ_LIMIT_SIZE`. Wmg3Http enforces the configured
`[http] downloadSizeLimitKB` before creating a file for known lengths and
before each write for unknown or chunked lengths. Compact-image activation
uses `UFF_IGNORE_SIZE_LIMIT` with `ULM_CACHE`, so transfer-size deferrals can
download on explicit activation while intrinsic-size deferrals reuse the
already cached source file. Backgrounds and Automatic mode pass no limit.

Constrained GIF/JPEG imports stream like unconstrained ones:
`ProcessSingleGraphic()` no longer suppresses `LoadProgressData` for
constrained requests (PNG stays download-first because
`LoadGraphicProgressCallback` only installs streaming for JPEG/GIF), and
`MSG_URL_TEXT_LOAD_GRAPHIC_PROGRESS` forwards `imageMaxPixels` from
`LPD_request` to `ImportThreadRequestImportGraphic()`. When such a streamed
import returns DEFERRED (or a constrained MEMORY_LIMIT with no bitmap),
`ImportG` invokes the appended `LPCT_DISCARD` load-progress callback before
sending the deferred UI: under `LPD_sem` it purges the buffered
HugeArray/MemStream bytes, resets the counters/state, sets
`LoadProgressData.LPD_discard` so later `LPCT_WRITE` callbacks ignore data,
and keeps `LPD_callback` installed so Wmg3Http completes the source file and
returns its normal progress acknowledgement. The HTTP transfer is never
cancelled and Wmg3Http knows nothing about image dimensions.

`MSG_URL_TEXT_IMPORT_GRAPHIC_PROGRESS` must call
`MSG_HTML_TEXT_WAITING_IMAGES_RESOLVE(FALSE)` after installing every progress
bitmap, including streamed ones. Restricting that layout step to completed-file
imports leaves streamed images as placeholders until final page layout.
When a live stream updates an image during an already-active page layout, it
must also call `MSG_HTML_TEXT_CALCULATE_LAYOUT()`; that method sets
`HTS_LAYOUT_RESTART_REQUESTED`, causing the next layout event to revisit and
draw the changed cell instead of waiting for the layout's final extra pass or
Stop. `LoadProgressData.LPD_layoutRestartRequested`, reset by `LPCT_OPEN`,
limits this to the first progress bitmap in each stream. Later scanline slices
use direct invalidation and do not repeatedly reformat the page.

When the separate Wmg3Http transfer-size cap is active, a known final
Content-Length that passed the pre-body cap may still stream. An unknown or
chunked length remains download-first because it can cross the byte cap only
after reception has begun; this prevents publishing a partial bitmap before
`URL_RET_TOO_LARGE`.

`MSG_URL_TEXT_GRAPHIC_FETCHED` classifies unsupported `image/*` response MIME
types after download with `ImageMIMEGetUnsupportedFormat()` and marks document
images as compact unsupported placeholders without invoking an importer.
Extension preflight remains separate and installed MIME associations remain
authoritative. Streaming HTTP admission is a possible later optimization.

Image progress is a three-state mode selected by the integer
`[HTMLView] progressDisplay` entry: `ImageProgressMode` with
`IMAGE_PROGRESS_FINAL` (0, final replacement only), `IMAGE_PROGRESS_IMPORT`
(1, progressive display only while importing completely downloaded files),
and `IMAGE_PROGRESS_STREAM` (2, the default; live streaming when eligible,
otherwise the same completed-file progressive import as mode 1). The type and
type lives in `Appl/Breadbox/BbxBrow/htmlview.goh`; the default is set in
`init/INIT.goc`, where `InitNavigation()` reads the entry with
`InitFileReadInteger()` and keeps the default on missing, malformed, or
out-of-range values. If integer parsing fails but `InitFileReadBoolean()`
recognizes a legacy Boolean value, initialization replaces it with integer
mode 2 before continuing. `ProcessSingleGraphic()`
in `urltext/URLTEXT.goc` passes `LoadProgressData` to the fetch only in
streaming mode (plus the existing reserved-position and minimum-height
restrictions). `ImportThreadRequestImportGraphic()` in `htmlview/ImportG.goc`
installs `IPD_callback` for any mode above final, so completed-file import
progress is unconditional capability under `PROGRESS_DISPLAY`; the former
`COMPILE_OPTION_IMPORT_PROGRESS_LOCAL` switch is gone. Template
`[HTMLView] progressDisplay = 2` in
`Tools/build/product/bbxensem/Template/geos.ini` supplies the default without
changing `HTML_VIEW_INI_VERSION_NUMBER` or resetting the HTMLView category.
Without `PROGRESS_DISPLAY`, behavior is unchanged: no load or import progress
data and no mode global exists.

Evidence: `Appl/Breadbox/BbxBrow/htmlview/ImportG.goc`,
`htmlview/LoadURL.goc`, and `urltext/URLTEXT.goc`; `CInclude/htmldrv.h`; and
`Library/Breadbox/UrlDrv/Wmg3Http/WMG3HTTP.goc`.

Without `PROGRESS_DISPLAY`, MIME discovery in `LoadMimeTypes()` and
`LoadNewMimeDriver()` first requests protocol 4, then falls back to protocol
3 for legacy drivers. `ImportGraphicByNative()` reads the actual loaded
protocol and selects the old eight-argument graphic entry below major 4;
protocol-4 drivers receive the reserved ninth, null progress argument, and
constrained requests (`maxPixels != 0`) additionally require protocol 4.3
for MIME entry 4, deferring on older drivers. The
public protocol declarations are in `CInclude/htmldrv.h`, and discovery and
dispatch are in `init/INIT.goc`, `navigate/NAVIGATE.goc`, and
`htmlview/LoadURL.goc`.
