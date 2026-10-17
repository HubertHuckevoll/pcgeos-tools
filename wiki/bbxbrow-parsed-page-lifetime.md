# BbxBrow parsed-page lifetime

The parsed page is an OCT_TEXTOBJ VM chain registered by
MSG_URL_FRAME_URL_FETCHED in Appl/Breadbox/BbxBrow/urlframe/URLFrameFetch.goc.
MSG_URL_FRAME_FLIP_PAGE in urlframe/URLFrame.goc locks its cache token,
attaches the transfer item, and releases the previous token after detachment.
MSG_HTML_TEXT_ATTACH_TO_ITEM and MSG_HTML_TEXT_UPDATE_ITEM in
Library/Breadbox/Html4Par/htmlclas/htmlclas.goc copy the hypertext arrays into
and back out of the text object. Attachment resets image resolution/cache
handles, retaining parser source references.

ObjCacheRemoveEntry in BbxBrow/cache/ObjectCache.goc frees text pages through
FreeHTMLTransferItem; locked entries cannot be evicted. ObjCacheUnlockItem
removes an unlocked OCDF_NOCACHE entry immediately, while ordinary cacheable
entries remain available for restoration.

Object-cache files can persist, but ObjCacheCheckPersist explicitly rejects
OCT_TEXTOBJ at normal cache detachment. DetachFromObjCache removes unlocked
text entries before writing the index. AttachToObjCache rejects files without
a committed map or with a different cache protocol. A persistent object
cache is therefore not evidence that parsed text pages persist across normal
application restart. MSG_HTML_TEXT_STORE_CONTENTS is currently disabled;
its native-page serialization path returns zero.

## Shared cache lifetime

`cache/CacheLifetime.goc` owns `AddCacheFileReference` and
`RemoveCacheFileReference`. Navigation, documents and URLText storage each
hold a reference. `InitCacheLifetime`, called by `init/Init.goc:InitNavigation`,
creates the allocation watcher, reads VM-cache directory settings and acquires
navigation's reference. `DeInitNavigation` clears history before releasing it.

`urldoc/URLDocument.goc:MSG_GEN_DOCUMENT_PHYSICAL_CLOSE` holds its reference through
frame/text destruction, because system detach can close navigation first.
`urltext/URLText.goc` acquires before superclass `MSG_HTML_TEXT_INIT_STORAGE`
and releases after superclass `MSG_HTML_TEXT_DEINIT_STORAGE`. The final release
persists both caches before freeing the global name pool and closing VM files;
the allocation watcher and cache semaphores are destroyed afterward.

Text-object storage and the global name pool use the separate per-session
`TEXTOBJF.000` VM file (`htmlview.goh:TEXT_OBJ_FILE_NAME`,
`cache/CacheLifetime.goc:AddCacheFileReference`). `URLFrameTree.goc` initializes
text storage with `textObjFile`; `URLDocument.goc` also returns that file on physical
open. Object-cache and import-work files use the configured `vmCacheSP` and
`vmCacheDir`, while the source cache retains `HTML_VMCACHE_SP` /
`HTML_VMCACHE_DIR`. Preserve that directory switch when sharing cache lifetime.

## Alternate cache routing

ALT_SRC_CACHE is disabled in BbxBrow/options.goh. When enabled,
init/Init.goc reads altSrcCacheHosts and altSrcCacheExts. SourceCache.goc:
UseAltCache requires a configured host match; a configured extension list
further restricts eligible URLs. SrcCacheGenerateID marks selected source IDs
with CACHE_ALT_FLAG, and CreateTempName uses ALT-prefixed source directories.
ObjectCache.goc:ObjCacheGetVMFile independently applies the same URL classifier
to select the second bank of VM files. htmlview.goh doubles NUM_CACHE_FILES
from NUM_VMCACHE_FILES when the alternate mode is enabled (currently 5 to 10).

EnforceSrcCacheSizeLimits and EnforceObjCacheSizeLimits account bytes separately
for the regular/alternate partitions and skip the other partition's entries
when evicting for byte limits. Both partitions share each cache's index;
reaching SRC_CACHE_COUNT_LIMIT or OBJ_CACHE_COUNT_LIMIT permits eviction across
partitions. INI-only configurations can set altSrcCacheLimit/altObjCacheLimit;
configurations with cache-size UI use the same UI value for either partition.
Expiration and revalidation use the same policy for both partitions.
The bbxensem Template/Windemo/net.ini and Template/DBCS/net2.ini select
www.myturn.com through altSrcCacheHosts; Windemo also restricts extensions to
jpg gif wav. These templates document a concrete site-specific use.

## Cache-all mode

BbxBrow's demo-copy mode is controlled at runtime, without CACHE_ALL build
guards. SourceCache.goc initializes G_cacheAll to FALSE;
init/Init.goc:InitNavigation documents and reads HTMLView/cacheAll.
URLLoad.goc retains otherwise noncacheable source
entries when it is true; URLFrameFetch.goc, URLFramePage.goc and
URLTextImages.goc also override selected no-cache cleanup/cacheability paths.
SrcCacheIsExpired clears expired in this mode but does not clear tryModified,
so cache-all is not a guarantee that all revalidation/network access stops.
HTMLViewLifecycle.goc suppresses its startup OpenConnection call in this mode.

## Formatting-cache runtime policy

Formatting-cache controls have no separate build switch. UI/menuOptions.goh
provides objCacheOpt/objCacheLimit under the general settings/miscellaneous UI
conditions. options.goh includes HTMLV_OBJECT_CACHE in DEFAULT_VARIOUS_SETTINGS;
ObjectCache.goc:EnforceObjCacheSizeLimits uses the configured size limit.
Runtime page/image cache lookup tests HTMLV_OBJECT_CACHE
(urlframe/URLFrameFetch.goc, urltext/URLTextImages.goc).
Init.goc:AdaptUItoSystemConfiguration still marks objCacheOpt not usable when
COMPILE_OPTION_ENABLE_SETTINGS is enabled. Cache infrastructure also holds
live, noncacheable objects until their last in-use reference is released
(ObjectCache.goc:ObjCacheUnlockItem).

The historical COMPILE_OPTION_FORMATTING_CACHE_ON switch selected these
controls/defaults and used limit = 0 when disabled. Its introduction and
related default-bit fix are recorded in notes/WHATSNEW.TXT (08/23/98, 10/12/98).

## Embedded WAV playback

Embedded WAV support is unconditional in BbxBrow and Html4Par. The shared
HypertextTransferBlockHeader (CInclude/html4par.goh) contains
HTBH_other.HTBHO_embed; URLFrame retains its embed instance field and messages,
and the parser retains EMBED tag handling. These are the former enabled
EMBED_SUPPORT layouts; the build flag and guards are removed. Both geodes
must agree on the shared transfer-header layout.
Html4Par/htmlpars/opentags.goc:Open_EMBED records a nonempty SRC in the single
HTBHO_embed slot, releasing any previous token. BbxBrow/urlframe/URLFramePage.goc:
MSG_URL_FRAME_GOT_URL copies it to UFI_embed through MSG_URL_FRAME_SET_EMBED;
MSG_URL_FRAME_GOT_PAGE_NOFRAME fetches it only when the URL ends in .wav.
MSG_URL_FRAME_EMBED_FETCHED accepts WAV MIME types (or a .wav filename when
MIME is absent), calls WavPlayFile, and performs normal fetch cleanup.
BbxBrow/bbxbrow.gp imports wav. This traced path implements one WAV source
per parsed page and is not a general embedded-object/plugin interface.
Html4Par/htmlsty.goh marks EMBED TAG_NO_FORMATTING; Open_EMBED only reads SRC,
so this path creates no inline player or size reservation. Library/Wav/wav.asm:
WavPlayFile copies the path/name and creates WavPlaySoundAndDestroyThread;
WavPlayFromWavFilePathBlock opens the file and calls PlaySoundFromFile. The
browser's embed playback is asynchronous audio without an inline control UI.
The EMBED_FETCHED handler explicitly calls for eventual delegation to ImpDoc.
Library/Breadbox/ImpDoc/impdoc.goc:MimeDrvMain selects a configured MIME-to-app
token, copies the file to SP_PRIVATE_DATA/impdoc, and opens an IACP connection
to that application. BbxBrow/notes/gpc_changes.txt (8/24/99) explains that the
private copy avoids relying on the temporary cache file. This is helper-app
dispatch, not an implementation of inline object rendering.

## Status/progress dispatch threads

UPDATE_ON_UI_THREAD is enabled in options.goh. htmlview.goh routes status
update/query macros and SendUpdateProgress to HTMLVApp/MSG_HMLVA_* when set,
or process/MSG_HMLVP_* when unset. HTMLViewStatus.goc selects the corresponding
HTMLVApplicationClass or HTMLVProcessClass handlers while retaining their
bodies. The progress timer targets HTMLVApp or the process optr accordingly.
The handlers still update LinkStatus/ProgressIndicator through object messages;
AppResource and StatusResource are ui-object resources (bbxbrow.gp).
MSG_HMLVA_UPDATE_DOWNLOAD_PROGRESS_DIALOG remains an application-class method
in both configurations. UI-thread creation is unconditional in
HTMLViewLifecycle.goc:MSG_PROCESS_CREATE_UI_THREAD; the flag does not select
whether the UI, fetch or import threads exist.
HTMLView.goc has one unconditional @classdecl HTMLVApplicationClass and
registers MSG_HMLVA_UPDATE_DOWNLOAD_PROGRESS_DIALOG outside UPDATE_ON_UI_THREAD,
matching that handler's unconditional application-class implementation.
Switching this flag changes message numbering in htmlview.goh; rebuild all
BbxBrow object/resource outputs when switching to avoid linking mixed variants.

## Page-progress infrastructure

BbxBrow includes page-progress infrastructure unconditionally. The status bar
contains ProgressIndicatorBox/FastStatus (UI/statusIndicators.goh,
UI/mainWrapper.goh). htmlview.goh declares PI_* state constants; HTMLView.goc
owns G_progressStatus and transfer-dialog state. HTMLViewStatus.goc owns the
state/timer handlers. HTMLViewOperation.goc sends PI_START/PI_DONE;
URLText.goc sends PI_NEW_ITEM/PI_DONE_ITEM and PI_FORMATTING. The progress timer
also calls UpdateDownloadProgressDialogTimes. G_progressStatus selects
download-progress presentation; it is not a user preference enabling/disabling
the infrastructure. The historical COMPILE_OPTION_PROGRESS_INDICATOR flag and
guards are removed; runtime state, timers and calculations retain their behavior.

## Transfer-progress dialog

BbxBrow includes the transfer-progress dialog unconditionally. It uses the
shared page-progress state, timer and UI update handler. HTMLViewStatus.goc owns
DownloadProgressDialogResource, its modal dialog, progress calculations and
MSG_HMLVA_UPDATE_DOWNLOAD_PROGRESS_DIALOG; bbxbrow.gp declares the same resource.
HTMLView.goc owns the text templates and
G_fileDownload/G_fileUpload/G_allowFileDownloadStatus, initially FALSE.
URLLoad.goc:LoadURLCallback selects upload display for multipart/form-data and
download display for non-text/non-image MIME types (excluding external script
MIME in script/autobrowse builds). Byte-progress updates require both
G_fileDownload and G_allowFileDownloadStatus. Navigation sets the latter;
URLFramePage.goc clears it when a parsed HTML page is installed. These flags
are transfer state, not user preferences. Completion/abort dismisses the dialog
(HTMLViewStatus.goc, HTMLViewOperation.goc). UI/dialogDownload.goh is the separate
save-destination UI, not this transfer-progress dialog.

## Shared browsing services and content retrieval

Shared services are organized by ownership: cache/ holds source and object
caches, urlfetch/URLSupport.goc owns URL-driver lifetime, FILE handling,
redirects and connectivity checks, and mime/ContentHandling.goc owns MIME
associations, the shared import-driver cache and unknown-content handling.
Shared HTMLResource chunks remain together in htmlview/HTMLView.goc;
recent-history helpers live in HTMLViewNavigation.goc and home-page access in
HTMLViewOptions.goc. PortalEmail.goc holds optional portal account integration.
Document Back/Forward is implemented in `urldoc/URLDocumentHistory.goc`;
link targeting is in `urlframe/URLFrameNavigation.goc`.

`urlframe/URLFrameFetch.goc` first tries `ObjCacheFindURL(OCT_TEXTOBJ, ...)`.
On a miss it submits `URLFetchRequest`; fetch children in
`urlfetch/URLFetchEngine.goc` call `urlfetch/URLLoad.goc:LoadURLToFile`, which uses
source-cache lookup and the URLSupport URL-driver/file helpers. The frame's
`MSG_URL_FRAME_URL_FETCHED` parses HTML/plain text or calls
`mime/ContentHandling.goc:HandleUnknownType` for other types. That handler
selects native text import, an image-wrapper HTML message or the save dialog.
Graphic-import workers in `mime/GraphicImport.goc:ImportGraphicByNative`
share ContentHandling's MIME-driver cache and semaphore. These helpers serve
multiple caller/thread contexts; the folder does not own fetch-thread dispatch
or HTML rendering. Startup/shutdown integration is in `init/Init.goc`,
`InitNavigation` / `DeInitNavigation`.

MIME-driver shutdown crosses those file boundaries: `InitNavigation` allocates
`MimeDriverSemaphore`, while `DeInitNavigation` deliberately leaves it alive.
`mime/GraphicImport.goc:MSG_IMPORT_THREAD_ENGINE_KILL` acquires it to
release `lastMimeDriver`. Native text and graphic import both add a driver
reference under the semaphore, invoke the driver after releasing the semaphore,
and remove that reference afterwards (`ImportTextByNative`,
`ImportGraphicByNative`). Folder ownership does not imply that the semaphore
can be destroyed during general browsing-service teardown.

## Portal email-account commands

EMAIL_ACCT_CMD is browser integration for portal account management, not a
mailto handler. Wmg3Http/WMG3HTTP.goc captures the GPCemail response header
and returns its chunk through URLRequestBlock.URB_extraData;
BbxBrow/urlfetch/URLLoad.goc passes it to
htmlview/PortalEmail.goc:HandleEmailAcctCmd. That parser invokes MailHub account
APIs. Deletion can request that the email application quit, retaining
G_pendingEmailDelete until htmlview/PortalEmail.goc:
MSG_NOTIFY_APP_EXITED completes the deletion and removes the GCN subscription.
Evidence: those paths under Library/Breadbox/UrlDrv/ and Appl/Breadbox/;
PendingEmailDeleteAcctData is private to BbxBrow/htmlview/PortalEmail.goc.

EMAIL_ACCT_CMD is disabled by default. Enable -DEMAIL_ACCT_CMD through
COMPILE_OPTIONS in local.mk and rebuild; GOC, Watcom and Glue receive the
same flag. bbxbrow.gp imports MailHub only for that configuration. The shared
htmlview.goh no longer imports mailhub.goh; PortalEmail.goc owns that include.
URLLoad.goc explicitly includes socket.goh for SE_LINK_FAILED, and
URLSupport.goc includes socket.goh plus sockmisc.h for CheckConnected. These
replace the previous accidental networking-header dependency on MailHub.
The default EC/NC geodes omit the portal handler, its error chunk and the
MailHub import; enabling the flag builds the retained portal integration.
Ordinary mailto routing is separate: bbxensem/Template/geos.ini uses the
external URL driver and [extURL] account-independent application mapping.

## Per-view width lifetime

HTI_viewWidth in CInclude/html4par.goh belongs to each HTMLText instance.
MSG_HTML_TEXT_ATTACH_TO_ITEM retains it across navigation;
MSG_HTML_TEXT_INITIALIZE_LAYOUT in htmlclas/htmltpre.goc resets
HTI_formattedWidth, not HTI_viewWidth. MSG_URL_FRAME_CREATE_CHILD in
BbxBrow/urlframe/URLFrameTree.goc duplicates URLText and ViewTemplate and connects
them through MSG_HTML_TEXT_SET_VIEW_OBJ, so each frame has its own width.

GenView's SendPaneSizeMethod in
Library/SpecUI/CommonUI/CView/cviewPaneWindow.asm supplies OLPI_pageWidth,
already in document coordinates (OLPaneSetNewPageSize in
cviewPaneGeometry.asm). VisContentViewWinOpened in
Library/User/Vis/visContentClass.asm forwards opening to
MSG_META_CONTENT_VIEW_SIZE_CHANGED and VisContentSubviewSizeChanged sends it
to the children. HTMLText's handler in htmlclas/htmltdrw.goc records a
positive supplied width before unsuspending/layout and clears
HTS_VIEW_NOT_OPENED; the initial class width of 400 is not a real viewport.
MSG_HTML_TEXT_LAYOUT_START in htmlclas/htmltcel.goc subsequently derives
HTI_viewWidth from HTI_formattedWidth and its scrollbar policy, then subtracts
HTI_pageLeftMargin and one right-edge pixel for the top-level cell.
ICalculateViewSize adds back an existing vertical scrollbar and subtracts
its zoom-adjusted pixel allowance before returning the width used for
HTI_formattedWidth.

## Visited links and source-cache recency

`MSG_URL_FRAME_FLIP_PAGE` calls `MSG_URL_TEXT_MARK_VISITED_LINKS` after
attaching the cached text item and before starting graphics processing or
showing the item (`Appl/Breadbox/BbxBrow/urlframe/URLFrame.goc`). The scan
resolves anchor URLs through the frame and removes fragments before looking
them up in the source cache (`urltext/URLTextLinks.goc`).

This presentation operation also changes cache recency: `SrcCacheFindURL`
removes each found entry and appends it to the source-cache array under
`srcCacheSem`, making it most recently used. This occurs before any expiration
check. Evidence:
`Appl/Breadbox/BbxBrow/cache/SourceCache.goc`, `SrcCacheFindURL`,
`SrcCacheIsExpired`; semaphore macros in `htmlview.goh`.

Cache validation is unconditional in BbxBrow and Wmg3Http. Cache lookup/add
and URL loading declare their validation parameters explicitly in
BbxBrow/htmlview.goh, cache/SourceCache.goc and urlfetch/URLLoad.goc.
The source-cache record retains expiration and lastModDate; Wmg3Http's
WMG3HTTP.goc handles cache headers, conditional requests and not-modified
responses. Cache record formats and URLRequestBlock validation fields are
unchanged. Historical CACHE_VALIDATION guards and CACHE_VAL_* wrappers are
removed; before BrowserUI2024 (fc9c10a7d), the browser selected validation
under GLOBAL_INTERNET_BUILD for major products.

The runtime HTMLView/weakCacheExpiration setting remains
(SrcCacheIsExpired; init/Init.goc). With weakCacheExpiration true and no maxAge,
SrcCacheAddURL assigns DEFAULT_MAX_AGE (one day in htmlview.goh); false stores
zero expiration, which SrcCacheIsExpired marks for revalidation. Explicit
expiration is still checked in either mode. The bbxensem Template/geos.ini
sets this option true.

## Print ornament coordinate space and target routing

Html4Par calls `MSG_HTML_TEXT_PRINT_PAGE_ORNAMENTS` for each printed page
before saving the GState and applying the text body's clipping, translation
and fit-to-page scaling. Its `page` rectangle is constructed from printer
margins and printable paper dimensions. Ornaments therefore use paper
coordinates rather than the scaled document coordinates used by `MSG_VIS_DRAW`.
Evidence: `Library/Breadbox/Html4Par/htmlclas/htmlclas.goc`,
`MSG_PRINT_START_PRINTING`; message parameters in `CInclude/html4par.goh`.

BbxBrow's `URLDocumentClass::MSG_PRINT_GET_DOC_NAME` routes the request as a
classed event to `TO_TARGET` through the document display. If an HTML form's
in-place text entry holds that target, `InPlaceTextEntryClass` forwards the
print messages to `IPTEI_urlTextObj`. Evidence:
`Appl/Breadbox/BbxBrow/urldoc/URLDocument.goc` and
`Library/Breadbox/Html4Par/htmlclas/htmlfedi.goc`,
`MSG_PRINT_GET_DOC_NAME` and `MSG_PRINT_START_PRINTING`.

## Document history snapshot ownership

BbxBrow keeps two kinds of frame snapshots. Back/forward snapshots live in
LMem chunks in the document object block; recent-history snapshots live in
`frameCacheBlock`. `MSG_URL_DOCUMENT_NOTIFY_FRAME_CHANGE_PRE` creates both,
and `MSG_URL_DOCUMENT_NOTIFY_FRAME_CHANGE_POST` creates the recent-history
copy after a change. These handlers and stack cleanup are in
`Appl/Breadbox/BbxBrow/urldoc/URLDocumentHistory.goc`.

Back/forward replay duplicates the saved chunk with `LMemDup` before calling
`MSG_URL_DOCUMENT_LOAD_FRAME_SET` in `URLDocumentNavigation.goc`; that loader
locks the supplied block, fetches frames, frees the supplied chunk, then
unlocks. Stack eviction/drop releases frame-record name tokens before freeing
the saved chunks. `htmlview/HTMLViewNavigation.goc:HistoryUpdateLRU` owns the retained
recent-history snapshot and title token, releasing the previous entry on
replacement. `urldoc/URLDocument.goc` allocates the two stack-buffer chunks during
physical open/create and frees them during physical close, after dropping
saved snapshots and before frame destruction/cache-reference release.
