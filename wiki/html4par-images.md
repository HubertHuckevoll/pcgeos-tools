# Html4Par images

Parser source tokens and runtime URL tokens have different owners.
`NamePoolVMLoad()` in `Library/Breadbox/Html4Par/wwwtools/namepool.goc`
creates an LMem hash index over the existing VM HugeArray; it does not clone
strings or acquire their token references. `NamePoolVMUnload()` frees only
that index. The image arrays copied by `MSG_HTML_TEXT_ATTACH_TO_ITEM` and
`MSG_HTML_TEXT_UPDATE_ITEM` in `htmlclas/htmlclas.goc` therefore borrow the
transfer item's parser tokens. Do not release those tokens merely because
an attached image switches runtime sources. BbxBrow's `HID_resolvedURL`
instead owns a reference in the browser's global NamePool, released by its
`MSG_HTML_TEXT_ATTACH_TO_ITEM` handler in `urltext/URLTEXT.goc`.

Inline `<svg>` is captured as raw bytes by `HandleInlineSVG()` in
`Library/Breadbox/Html4Par/htmlpars/htmlpars.goc`, using a 1024-byte buffer
and one temporary file per admitted SVG. `HTMLimageData.svgFile` owns a
local name token for that file. Cache restoration can import the file again;
`FreeHTMLTransferItem()` deletes it when the parsed page is freed.
`OBJ_CACHE_MINOR_VERSION` in `Appl/Breadbox/BbxBrow/htmlview.goh` is bumped
when the persistent image-record layout changes; `AttachToObjCache()` in
`navigate/NAVCACHE.goc` recreates cache files on a protocol mismatch.
Imported graphics are stored as `OCT_GSTRING` VM chains by
`MSG_IMPORT_THREAD_ENGINE_IMPORT_GRAPHIC` in `htmlview/ImportG.goc`.
`ObjCacheForceCachable()` retains completed graphics when object caching is
enabled. `ObjCacheCheckPersist()` in `navigate/NAVCACHE.goc` drops text items
at detach and may also drop small graphics; an image-cache entry is not a
guaranteed permanent copy of a page's image source.
`HandleTag()` in `htmlpars/htmlpars.goc` resolves HTML tag names through
`StyleNum()` and parses only listed HTML attributes; `HTMLgetc()` also
normalizes line endings/control characters and decodes UTF-8. Thus an inline
SVG source must be captured from the raw `HTMLgetcLow()` byte stream before
ordinary HTML parsing consumes or changes it. In contrast, external `.svg`
images already pass through BbxBrow's normal image path: `InitNavigation()`
associates SVG with `image/svg+xml`, `ImpSVG()` in
`Library/Breadbox/ImpGraph/MAIN/impgraph.goc` calls
`SvgImport(FileHandle, VMFileHandle, ...)`, and `URLTextClass` displays the
result as a GString. `FileCreateTempFile()` can supply the importer with a
file handle, but its caller owns explicit close and deletion; see
`TechDocs/Markdown/Concepts/cfile.md`.
`HandleInlineSVG()` closes its backing file before publishing its name token.
`ProcessSingleGraphic()` in `Appl/Breadbox/BbxBrow/urltext/URLTextImages.goc` queues
that absolute path with `temporary=FALSE` and a page cache owner.
`ImportThreadRequestImportGraphic()` retains that owner until
`MSG_IMPORT_THREAD_ENGINE_IMPORT_GRAPHIC` completes, so page detachment cannot
free the source while it is queued or importing. The page owns file deletion.
The Html4Par scanner records whether inline SVG contains a shape SvgLib can
draw and whether it contains `<use>`, `<text>`, `<image>`, `<script>`, or
`<foreignObject>`. Such unsupported or shape-less sources remain in the VM
array but carry `HTML_IDF_SVG_UNSUPPORTED`; BbxBrow leaves their image
records invisible without queuing a temporary-file import. SvgLib's dispatch
and unsupported-element behavior are in `Library/SvgLib/Import/svg.goc`.
`ProcessPendingInlineSVG()` in BbxBrow keeps at most two inline SVG imports
active per text object and refills the queue after each result. A campaign
holds one pending page reference through each eight-result batch and its
30-tick timer pause; individual imports hold their own references. Outstanding
import name tokens are tracked on the text object so cancellation can balance
the count after navigation replaces the image array. Ordinary URL images
already pass through the configured URL fetch children.
`IMarkAllImagesUnresolved()` in `htmlclas/htmlclas.goc` clears every
transferred image's resolved flag, cache token, VM file, and VM block when
loading a page. SVG source offsets and lengths are parser fields above this
reset, so the source remains available after transfer-item loading. For inline
SVG it also zeros both HID_size and the matching VisTextGraphic.VTG_size;
clearing only the drawing size would leave cached layout geometry visible.
The attach-time graphic reset uses one `ChunkArrayEnum()` over the graphic
array (`IResetSVGGraphic`), matching each live HTML image graphic through
`HIGV_imageIndex`. Image records are fixed-size (`ModifyHypertextArray`,
`HTA_IMAGE_ARRAY` in `htmlpars/htmlpars.goc`), so their indexed lookup does
not walk a variable-element offset table. Searching the graphic array once
per SVG instead costs O(S*G) in NC and O(S*G*G) in EC, where S is the SVG
count and G is the graphic-element count.
`MSG_URL_TEXT_PROCESS_GRAPHICS` does not create a resolved cache-name token
for unsupported or source-less inline SVGs. `MSG_URL_FRAME_FLIP_PAGE` calls
attach and process-graphics synchronously before `MSG_HTML_TEXT_SHOW_ITEM`,
so work in those paths delays the start of initial layout and drawing.

Graphic runs point to one chainified LMem element block through
`TextLargeRunArrayHeader.TLRAH_elementVMBlock`; its chunk array is at
`LMemBlockHeader.LMBH_offset`. Graphic element order is not the image index:
HTML variable graphics carry `HTMLimageGraphicVariable.HIGV_imageIndex` in
`VTGV_privateData`. `IFindGraphicForImage()` locks both VM blocks per lookup and uses
`ChunkArrayEnum()` / `IFindImageGraphic` to find a live HTML image graphic.
It leaves the element block locked on success and unlocks it on a miss.
Use one graphic enumeration for batch changes rather than one search per image.
Indexed `ChunkArrayElementToPtr()` is constant-time in NC, including variable
arrays (their header has an offset table), but EC validates the entire variable
array on every call. An indexed scan is therefore quadratic in EC, and repeated
searches can become cubic. `ChunkArrayEnum()` validates once at entry and walks
the offset table without revalidating it per element. Evidence:
`Library/Kernel/LMem/lmemChunkArray.asm:ChunkArrayElementToPtr`,
`ECCheckChunkArray`, and `ChunkArrayEnumCommon`. Free elements have
`VTG_meta.REH_refCount.WAAH_high == EA_FREE_ELEMENT` (0xff), and the existing
image lookup rejects every nonzero high byte before reading private data.
Evidence: `htmlclas/htmlclas.goc:IFindGraphicForImage`,
`htmlpars/opentags.goc:ParseImage`, `CInclude/Objects/vTextC.goh`, and
`Include/chunkarr.def:RefElementHeader`.

Inline image sizing has two stages. `ParseImage()` in
`Library/Breadbox/Html4Par/htmlpars/opentags.goc` stores authored pixel
`WIDTH`/`HEIGHT` in `HTMLimageData.size` and creates the initial
`VisTextGraphic.VTG_size`/`HID_size` placeholder, using 20-pixel defaults for
unspecified dimensions on ordinary images. Inline SVG instead starts with
zero graphic and image size, while keeping an insertion position. After
import, `URLTextInitializeImage()` in
`Appl/Breadbox/BbxBrow/urltext/URLTextImages.goc` combines those authored dimensions
with intrinsic dimensions into drawing scales and `HID_size`; resolution then
updates the variable graphic and layout through `MSG_HTML_TEXT_RESOLVE_IMAGE`
in `htmlclas/htmlclas.goc`. Inline SVG
uses `MSG_HTML_TEXT_RESOLVE_INLINE_SVG`, which fits its geometry before
forwarding to that existing resolver without changing the original ABI. BbxBrow parses
the page before `MSG_URL_FRAME_FLIP_PAGE` attaches it and calls
`MSG_URL_TEXT_PROCESS_GRAPHICS` (`urlframe/URLFRAME.goc`).
`DrawVarGraphic()` in `htmlclas/htmlfdrw.goc` draws nothing when either
`HID_size` dimension is below 1, while layout uses the separate
`VisTextGraphic.VTG_size` created by `ParseImage()`. Cached unresolved SVG
geometry must therefore be cleared in both records at attachment.

`ICalculateViewSize()` in `htmlclas/htmltcel.goc` derives layout width from
`MSG_GEN_VIEW_GET_VISIBLE_RECT` but adds back a vertical scrollbar's width;
it is therefore not the exact currently visible width. GenView's visible-rect
message returns document coordinates and zero dimensions for an off-screen
view (`TechDocs/Markdown/Objects/ogenvew.md`, section 9.4.2.4).

BbxBrow updates its stored visible rectangle when the view changes.
`MSG_HTML_TEXT_CLAMP_INLINE_SVG_TO_VIEWPORT` rechecks resolved inline SVG
when the rectangle first appears, shrinks, or an import batch completes.
It changes image records and graphic runs, then marks layout dirty and
requests a complete redraw once. Ordinary image sizes are unchanged.
These appended messages use the Html4Par `HTMLTextInlineSVG` protocol minor;
see `CInclude/html4par.goh`, `html4par.gp`, `urltext/URLTextImages.goc` and
`htmlclas/htmlclas.goc`.

The transfer header is a VM chain tree. `InitTransferItem()` in
`htmlpars/parsinit.goc` computes `HTBH_meta.VMCT_count` from the header size,
excluding the metadata and `HTBH_other`. Appending a VMChain field after
these therefore includes it in generic chain copying and freeing.
`FreeHTMLTransferItem()` in `htmlclas/htmlclas.goc` calls `VMFreeVMChain()`
on the page chain; separate SVG HugeArray destruction is unnecessary.

`HTMLimageData.imageALT` contains the authored `ALT` value, including an empty
one, or the literal fallback `Image` when the attribute is absent. There is no
separate flag in the current public structure that distinguishes the fallback.
See `ParseImage()` in
`Library/Breadbox/Html4Par/htmlpars/opentags.goc` and `HTMLimageData` in
`CInclude/html4par.goh`.

`ImageURLGetUnsupportedFormat()` in
`Appl/Breadbox/BbxBrow/urltext/URLTextImages.goc` returns true only when the final
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
If import returns no bitmap after publishing progress, ImportG releases the
request's cache reference before reporting failure or cancellation. A queued
`MSG_URL_TEXT_IMPORT_GRAPHIC_PROGRESS` still owns its separate reference and
must release it even after `HTI_imageArray` is cleared; the message's data
block must be unlocked before it is freed.
Evidence: `ImportLockCacheToken`, `MSG_IMPORT_THREAD_ENGINE_IMPORT_GRAPHIC`,
`MSG_URL_TEXT_INTERNAL_CANCEL_LIKE_GRAPHICS` in `urltext/URLTextImages.goc`, and
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

`MSG_URL_TEXT_IMPORT_GRAPHIC_PROGRESS` installs progress bitmaps through
`MSG_URL_TEXT_INTERNAL_REPLACE_LIKE_GRAPHICS` and `IReplaceGraphic`, using the
same image resolver as final replacement. `MSG_HTML_TEXT_RESOLVE_IMAGE` updates
`HID_size` and the corresponding `VisTextGraphic.VTG_size`; a geometry change
marks the owning cell and layout dirty and adds the image to the waiting list.
A shrinking width sets `HTS_LAYOUT_NEED_TO_BLAST_HARD_MIN_WIDTHS`. The resolver
updates `LS_currentMasterCellGotImage` / `LS_oneMorePass` inside its `!wasDirty`
branch when layout is active. Unchanged geometry avoids that dirtying path.

The waiting-image list has 200 entries (`MAX_WAITING_IMAGES` in
`htmlclas/htmlclas.goc`). When full, `MSG_HTML_TEXT_WAITING_IMAGE_ADD` calls
`MSG_HTML_TEXT_WAITING_IMAGES_RESOLVE`; that method queues
`MSG_HTML_TEXT_CALCULATE_LAYOUT` if dirty entries remain. The stored creation
and update times do not drive an image-layout timer. BbxBrow's
`MSG_URL_TEXT_DEC_PENDING` clamps inline SVG and calls calculate-layout when
its pending count reaches zero. At layout start,
`IBlastTableAndCellMinWidths` clears measured cell/table widths and dirties
them, while retaining authored pixel widths. This follows the preparatory
`CalculateCellArrayLongestLines` call in calculate-layout, so those freshly
measured widths can be discarded by the blast. Evidence:
`Library/Breadbox/Html4Par/htmlclas/htmlclas.goc`, `htmltcel.goc`,
`htmltpos.goc`, and `Appl/Breadbox/BbxBrow/urltext/URLTEXT.goc`.

`SelectSrcsetCandidate()` in `htmlpars/opentags.goc` selects the smallest
width at least as large as the parse-time viewport, or the largest when all
candidates are smaller. Unknown width retains the smallest choice. A single
bare URL is accepted; density sets retain the smallest density and implicit
`SRC` at 1x when all densities exceed 1x. Widths take priority over densities.
The opt-in `ParseAnyFileWithImageSources()` entry accepts an
`HTMLImageSourceContext` (view optr and MIME callback) without extending
`HTMLextra`. Its HTML core snapshots `MSG_GEN_VIEW_GET_VISIBLE_RECT` width;
legacy entries supply no context. BbxBrow's `ParseFrameHTML()` in
`urlframe/FRFETCH.goc` obtains the text object's `MSG_HTML_TEXT_GET_VIEW_OBJ`
and supplies `FrameImageMimeSupported()`, which checks `assocTypeDriver`.
`Open_SOURCE()` selects the first usable, media-matching, supported source
inside `PICTURE` and retains its URL in a name-pool token. `ParseImage()`
transfers that reference to the following ordinary IMG. Unconsumed tokens
must be released before `FinishTransferItem()` saves and disposes of the
name pool (`htmlpars/parsinit.goc`). Source selection does not establish an
intrinsic-pixel bound. WebP admission checks
`maxPixels` before decoder work-buffer allocation (`Library/WebpLib/webpapi.c`,
`WebPImportBegin`). External SVG receives the same Intelligent request limit,
but `ImpSVG()` checks GString bounds area only after `SvgImport()` has built
the vector graphic (`Library/Breadbox/ImpGraph/MAIN/impgraph.goc`). Inline SVG
imports pass zero for `maxPixels` (`ProcessInlineSVG` in BbxBrow's
`urltext/URLTextImages.goc`) and start with invisible zero-sized placeholders.

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
in `urltext/URLTextImages.goc` passes `LoadProgressData` to the fetch only in
streaming mode (plus the existing reserved-position and minimum-height
restrictions). `ImportThreadRequestImportGraphic()` in `htmlview/ImportG.goc`
installs `IPD_callback` for any mode above final, so completed-file import
progress is unconditional capability under `PROGRESS_DISPLAY`; the former
`COMPILE_OPTION_IMPORT_PROGRESS_LOCAL` switch is gone. Template
`[HTMLView] progressDisplay = 2` in
`Tools/build/product/bbxensem/Template/geos.ini` supplies the default without
changing `HTML_VIEW_INI_VERSION_NUMBER` or resetting the HTMLView category.
Without `PROGRESS_DISPLAY`, behavior is unchanged: no load or import progress
data and no mode global exists. Both streamed and completed-file import progress
use forced-queued delivery to the same `textObj`; the import thread does not wait
for HTML layout in the UI thread. The final full-image replacement is queued to
that object after decoding, while each progress notification owns a cache reference
until the receiver transfers it to `MSG_URL_TEXT_INTERNAL_REPLACE_LIKE_GRAPHICS`.

Evidence: `Appl/Breadbox/BbxBrow/htmlview/ImportG.goc`,
`htmlview/LoadURL.goc`, and `urltext/URLTextImages.goc` and `urltext/URLTextImageProgress.goc`; `CInclude/htmldrv.h`; and
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

`ImpWebP()` in `Library/Breadbox/ImpGraph/IMPBMP/impwebp.goc` calls the import
progress callback after each decoded macroblock row with output lines. In
BbxBrow, `ImportGraphicProgressCallback()` in `htmlview/ImportG.goc` coalesces
pending updates for the same bitmap; each delivered
`MSG_URL_TEXT_IMPORT_GRAPHIC_PROGRESS` in `urltext/URLTextImageProgress.goc` calls
`MSG_URL_TEXT_INTERNAL_REPLACE_LIKE_GRAPHICS`, which scans `HTI_imageArray`
for matching URLs. Changed geometry uses the resolver and waiting-image list
described above.
The callback also invokes `EnforceObjCacheHandleLimits()` before coalescing,
because an already-cached bitmap can add VM blocks throughout progressive
decoding. `ObjCacheAddURL()` invokes that routine only when the cache entry is
first created; its implementation in `navigate/NAVCACHE.goc` updates and
trims the cache VM files when global free handles drop below 500.

BbxBrow's active loading-progress stream uses `MemStream` because
`USE_MEM_STREAM` is defined in the private `urltext/MemStream.h`. Its buffer
implementation and limits are in `urltext/MemStream.c`; `G_stream` and callback
synchronization stay in `urltext/URLTextImageProgress.goc`. It allocates 8 KB blocks lazily in 200 slots for each fetch child. Its
absolute tail limit is `MEM_STREAM_BLOCK_SIZE * MEM_STREAM_INIT_BLKS`;
`MemStreamWrite` appends only while `tail + bufSize` is strictly below that
limit. Consuming reads free blocks but do not reset the absolute tail, and
there is no producer backpressure. The VM-backed HugeArray alternative
remains behind `#ifndef USE_MEM_STREAM`; it is not the active stream path.

The stream wait must atomically recheck both completion and byte availability
before joining the wait queue: `WakeUp()` drops a signal if no reader is
queued yet. Checking only `LPD_fileDone` misses data arriving between
`ThreadVSem(LPD_sem)` and `Block()`. See `LoadGraphicProgressCallback()`
in `urltext/URLTextImageProgress.goc`, `BLOCK`/`WAKEUP` in
`ASMTOOLS/asmtoolsManager.asm`, and `urltext/check_stream_wait.pl`.


The BbxBrow progress bar deliberately alternates its displayed value after
five seconds without a progress change (`htmlview/UIOften.goc`,
`MSG_HMLVA_UPDATE_PROGRESS_INDICATOR`, `PI_TIMER`/`progressDelay`). Both
`options.goh` and `prodbbx.goh` enable `UPDATE_ON_UI_THREAD`, so bar animation
does not establish that the browser process thread is advancing. The
`Loading Image.` status is posted by `MSG_IMPORT_THREAD_ENGINE_IMPORT_GRAPHIC`
before import and cleared by a separate queued `MsgBlank` status update after
it (`htmlview/ImportG.goc`, `htmlview.goh`, `navigate/NAVIGATE.goc`).

With `PROGRESS_DISPLAY`, BbxBrow normally creates `G_numFetchChildren + 1`
import threads (`htmlview/ImportG.goc`, `ImportThreadEngineStart`), while
`[HTMLView] forceSingleImportThread = true` creates one shared importer.
The setting is read only at engine startup. Import index 0 handles all
requests in shared mode; otherwise streamed requests use `LPD_loadThread + 1`
(`ImportThreadRequestImportGraphic`). `MAX_IMPORT_THREADS` is 3; `urlfetch/URLFETCH.goc` caps the configured fetch-child count at 2 and
reads it from `[HTMLView] numConn`, falling back to
`DEFAULT_FETCH_ENGINE_CHILDREN` (2). The Ensemble template
`Tools/build/product/bbxensem/Template/geos.ini` sets `numConn = 1`, yielding
one fetch child and two import threads. There is no `numImportThreads`
setting in the current startup or request-routing code. Without
`PROGRESS_DISPLAY`, there is a single import thread.

`fetchWhileImport` does not control thread creation. In
`urlfetch/URLFETCH.goc`, `URLFetchEngineChild` waits on `LPD_importSync`
after `LoadURLToFile` when that option is false, preventing the child from
handling further fetch requests until the associated import finishes.

Image import runs synchronously inside
`MSG_IMPORT_THREAD_ENGINE_IMPORT_GRAPHIC` (`htmlview/ImportG.goc`), through
`ToolsImportGraphicByDriver` / `ImportGraphicByNative` (`htmlview/LoadURL.goc`).
Streamed GIF reads in `ImpGraph/IMPBMP/impgifc.goc` and JPEG refills in
`Ijgjpeg/DECOMP/JDATASRC.c` invoke `LPCT_READ` on
`LoadGraphicProgressCallback` (`urltext/URLTextImageProgress.goc`). It waits for the requested
byte count or `LPD_fileDone` through `Block` / `ThreadBlockOnQueue`
(`ASMTOOLS/asmtoolsManager.asm`). HTTP writes and stream closure wake the
reader. A queued image request on that importer cannot start until the
current import returns; the separate file importer avoids that queue delay.

Streaming state is indexed by fetch child, independently of importer objects:
`G_stream[2]` in `urltext/URLTextImageProgress.goc`, and `G_importActive[]` /
`G_importLoadProgressData[]` in `urlfetch/URLFETCH.goc`. `LPCT_WRITE` buffers
input without waiting for the importer to consume it; a queued stream can
therefore retain its downloaded input. `fetchWhileImport = false` holds a
fetch child at `LPD_importSync` after download until its import finishes.

The read-side wait must atomically recheck `LPD_fileDone` and
`LPD_bytesAvail - LPD_preReadOffset >= needed` before `ThreadBlockOnQueue`:
`WAKEUP` drops signals when no thread is already queued, so checking only
`LPD_fileDone` can sleep after data arrived in the check-to-block gap. The
HugeArray byte stream also needs chunked deletes because `HugeArrayGetCount()`
returns a DWORD while `HugeArrayDelete()` accepts a WORD
(`CInclude/hugearr.h`, `URLTextImageProgress.goc`, `ASMTOOLS/asmtoolsManager.asm`).

In the default layout, importer 0 receives all requests with a null
load-progress pointer: `ProcessInlineSVG`, `MSG_URL_TEXT_GRAPHIC_FETCHED`,
and `MSG_URL_TEXT_GRAPHIC_PRELOADED` in `urltext/URLTextImages.goc`. This includes
inline SVG temporary files and file-based image imports; `ProcessSingleGraphic`
excludes reserved image positions and small authored heights from streaming,
and `LoadGraphicProgressCallback` streams only GIF/JPEG. Importer 0 can still
report progressive decoding through `IPD_callback`; absence of a live fetch
stream does not mean absence of import progress (`htmlview/ImportG.goc`,
`ImportThreadRequestImportGraphic`).

The active RAM stream is selected by the defined local `USE_MEM_STREAM`
switch. It allocates 8 KB blocks lazily, with 200 slots, has no producer
backpressure, and stops appending at an absolute tail ceiling while
`LPCT_WRITE` still increments `LPD_bytesAvail`. These limits apply to the
active stream; reducing its slot count also reduces input capacity.

The literal `Formatting Page.` status is posted by
`MSG_URL_FRAME_URL_FETCHED` in `urlframe/FRFETCH.goc` when the parsed page is
handed to `MSG_URL_FRAME_GOT_URL`; it is cleared by
`MSG_HMLVA_END_OPERATION` in `htmlview/UIRare.goc` at overall operation end.
It is not posted for each `MSG_HTML_TEXT_LAYOUT_START`. ImportG posts and
clears the higher-priority importing status around each image import, so the
retained formatting status can reappear without a new layout pass. Evidence:
`CInclude/htmlstat.goh`, `htmlview/UIOften.goc` (`G_statusIds`), and
`htmlview/StatText.goc` (`MSG_STATUS_TEXT_CREATE_MESSAGE`,
`MSG_STATUS_TEXT_UPDATE_TEXT`).

A dirty layout started from idle does page-wide preparatory work:
`MSG_HTML_TEXT_CALCULATE_LAYOUT` in `htmlclas/htmltpos.goc` calls
`ISetupRegionLinks`, `CalculateCellArrayLongestLines(..., 0, 0xFFFF)`, and
`IAdjustRegions(..., 0, 0xFFFF)` before layout starts. The longest-line routine
in `htmlclas/htmltpre.goc` traverses regions and their lines, without a
cell-layout-dirty filter. Dirty-cell reflow optimization therefore does not
make each geometry batch proportional only to that batch's changed cells.

The inline-SVG viewport clamp is shrink-only: `HTMLTextFitImageToViewport`
multiplies the existing `HID_size`, transform diagonal and draw offsets, and
can also reduce `hspace`/`vspace`. `MSG_URL_TEXT_CAPTURE_IMAGE_VIEWPORT` calls
it on first visibility or a smaller width/height, not on enlargement.
`HTMLimageData.size` retains authored dimensions, but that record has no
separate intrinsic size/origin. BbxBrow retains those in cached
`ImageAdditionalData` (`IAD_size`, `IAD_origin`); `IReplaceGraphic` obtains them
through `ObjCacheLockItem` and reconstructs geometry with
`URLTextInitializeImage`. See `CInclude/html4par.goh`, `CInclude/htmldrv.h`,
`htmlclas/htmlclas.goc`, and BbxBrow `urltext/URLTextImages.goc`.

VisText normally measures a graphic from its stored `VTG_size`.
`Library/Text/TextGraphic/tgGraphic.asm:TG_GraphicRunSize` invokes
`MSG_VIS_TEXT_GRAPHIC_VARIABLE_SIZE` only when both stored dimensions are
zero. Html4Par's handler in `htmlclas/htmlfsiz.goc` has special sizing for forms;
images use its default stored-size path. Resizing only during variable-graphic
drawing therefore cannot change prior text/table measurement.
For an image with both stored dimensions zero, the default size callback
still returns height `IMAGE_HEIGHT_FUDGE_FACTOR` (1); the embedded character
and its font can therefore retain a minimum text-line height. Zeroing image
geometry alone does not remove that character. See `htmlclas/htmlfsiz.goc`,
`MSG_VIS_TEXT_GRAPHIC_VARIABLE_SIZE`, and `ParseImage()` in `htmlpars/opentags.goc`.

BbxBrow's local-file loader does not strip URL queries: `ToolsParseURL()` in
`Library/Breadbox/Html4Par/wwwtools/wwwtools.goc` retains the query in its path,
and `LoadFILEURL()` in `Appl/Breadbox/BbxBrow/navigate/NAVIGATE.goc` decodes
and normalizes that path before filesystem access and MIME identification.
Use plain filenames in locally opened HTML image fixtures; HTTP image queries
still belong to the request URL.

Picture source selection is parse-time state, not image geometry.
`ParseFrameHTML()` in BbxBrow `urlframe/FRFETCH.goc` passes a
`HTMLImageSourceContext` to `ParseAnyFileWithImageSources()`. Its width comes
from `MSG_URL_TEXT_GET_IMAGE_SOURCE_WIDTH` in `urltext/URLTextImages.goc`, which
returns `HTI_viewWidth` only when `HTS_VIEW_NOT_OPENED` is clear. Html4Par
snapshots that word and the MIME callback in `ParseHTMLFileWithImageSources()`;
no GenView query is needed. `Open_SOURCE()` in `htmlpars/opentags.goc` keeps
the first supported, media-matching source. `SelectSrcsetCandidate()` uses
`HTML_IMAGE_SELECT_SMALLEST` in `internal.h` to choose the smallest declared
candidate (default 1) or a viewport-covering width (0). MEDIA always uses the
snapshot width. `TakePictureSource()` transfers one local name-pool reference
to `ParseImage()`, which consumes it even when image admission fails.
`PictureBeforeTag()` belongs in `HandleNamedTag()` so it also sees SVG recovery
tags; it must compare raw HTML tag names without case sensitivity. It does
not run for `Open_IMG()`'s synthetic alignment tables. Existing Fit to Window
controls drawing/layout geometry after import. Source selection is not rerun
on resize or cached-page attachment. See also
`TechDocs/Markdown/Concepts/html-image-sources.md` and `htmtest/check_image_sources.pl`.

Broken-image drawing is separate from failure classification. BbxBrow's
`MSG_URL_TEXT_INTERNAL_REPLACE_LIKE_GRAPHICS` in `urltext/URLTextImages.goc`
marks every matching `HID_resolvedURL` broken when passed `OCT_NULL`.
Fetch failures (`MSG_URL_TEXT_GRAPHIC_FETCHED`) and import failures
(`MSG_IMPORT_THREAD_ENGINE_IMPORT_GRAPHIC` in `htmlview/ImportG.goc`)
use this path. Html4Par's `MSG_HTML_TEXT_MARK_IMAGE_BROKEN` in
`htmlclas/htmlclas.goc` sets BROKEN and RESOLVED, clears RESOLVING and
SIZE_DIRTY, clears the graphic handles, and calls
`MSG_HTML_TEXT_INVALIDATE_IMAGE`. That handler can draw immediately through
`DrawVarGraphic`; normal `MSG_VIS_TEXT_GRAPHIC_VARIABLE_DRAW` uses the same
routine. `DrawVarGraphic` in `htmlclas/htmlfdrw.goc` draws the grey placeholder
and two red diagonal lines for BROKEN images only when both HID_size
dimensions are at least 20 pixels. The nested 4-pixel X check does not
lower that outer threshold. Stop/cancellation instead uses
`MSG_URL_TEXT_INTERNAL_CANCEL_LIKE_GRAPHICS`, retaining complete cached
images and resetting incomplete resolving images to UNRESOLVED.

BbxBrow's `MSG_URL_TEXT_DEC_PENDING` calls
`MSG_URL_TEXT_HIDE_BROKEN_IMAGES` before `MSG_HTML_TEXT_CALCULATE_LAYOUT`
when the pending count reaches zero and the text object is not doomed.
The hide handler in `urltext/URLTextImages.goc` collapses broken inline images;
it skips background and other reserved image positions at or above
`HTML_IMAGE_POS_RESERVED`. Evidence: `urltext/URLTEXT.goc`,
`MSG_URL_TEXT_DEC_PENDING`, and `CInclude/html4par.goh`.

`MSG_HTML_TEXT_RESOLVE_IMAGE` sets RESOLVED and clears BROKEN/RESOLVING,
even for zero-sized images. Its text-graphic size includes twice hspace and
vspace, so collapse requires zero spacing as well as zero HID_size.
`MSG_URL_FRAME_LOAD_GRAPHICS` in BbxBrow's `urlframe/URLFRAME.goc` resets
only broken/resolving images before retrying; resolved zero-sized records
are skipped. Attachment resets all image loading flags through
`IMarkAllImagesUnresolved` in `htmlclas/htmlclas.goc`, allowing reload retries.

Inline SVGs share `G_imageCount` / `G_imageLimit` with ordinary images.
The default is 200 (`internal.h:DEFAULT_IMAGE_LIMIT`), overridden by
`[HTMLView] imagelimit`. `CanParseImage()` in `htmlpars/opentags.goc`
checks that limit and `TAG_FLUSH_TEXT`. Both `ParseImage()` and
`HandleInlineSVG()` use it; rejected SVGs are still scanned to their end
but do not create or write backing files. `htmtest/check_inline_svg.pl`
checks admission, a zero configured limit, and following-HTML preservation.

`MSG_HTML_TEXT_SHOW_ITEM` unsuspends VisText before calling
`MSG_HTML_TEXT_CALCULATE_LAYOUT`. Unsuspension can synchronously recalculate
text when `VisTextSuspendData.VTSD_needsRecalc` is set:
`Library/Text/Text/textSuspend.asm:VisTextUnsuspend` calls
`ReflectChangeWithFlags`. A blank page at the formatting status can therefore
be stalled before Html4Par's layout preparation or incremental cell events.
The EC `WARNING_FIRST_LAYOUT_*` markers in `htmlclas/htmlclas.goc`,
`htmltpos.goc`, and `htmltcel.goc` distinguish unsuspension, region-link setup,
longest-line measurement, region adjustment, min/max preparation, and the first
cell step. They run before the named work and disappear from NC builds.

HTMLText attachment copies each hypertext chunk array into its own LMem block
(`htmlclas/htmlclas.goc:MSG_HTML_TEXT_ATTACH_TO_ITEM`, `GetArray`,
`LMemCopyToBlock`); the live `HTI_imageArray` is therefore separate from the
transfer item's combined array block. `MSG_HTML_TEXT_GET_IMAGE` copies one
`HTMLimageData` to caller storage under a short lock.
`MSG_HTML_TEXT_RESOLVE_IMAGE` synchronously copies caller data back under its
own lock, then uses that caller data for graphic/layout updates. The caller
buffer must remain valid through the entire call; it need not point into the
image array. Evidence: `Library/Breadbox/Html4Par/htmlclas/htmlclas.goc`,
those message handlers, and `CInclude/html4par.goh` message declarations.

PNG scanline processing and final compaction are separate phases.
ImpGraph's `IMPBMP/imppng.goc:PngImport` calls
`pngImportGetNextIDATScanline`; PngLib calls `unfilterRow` after accumulating
a complete inflated scanline (`Library/PngLib/pngimp.c`). Its Paeth path
calls C `paethPredictor` once per byte (`common.c`). ImpGraph's `ImpPNG`
returns `isCompacted = FALSE`, so `MimeDrvGraphicEx` subsequently calls
`GrCompactBitmap` for bitmap output when `locCompress` is true
(`Library/Breadbox/ImpGraph/MAIN/impgraph.goc`). Decoder timings must therefore
be distinguished from this later VM-backed bitmap compaction.
