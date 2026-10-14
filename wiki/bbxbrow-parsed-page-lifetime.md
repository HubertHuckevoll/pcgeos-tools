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
hold a reference. `InitCacheLifetime`, called by `init/INIT.goc:InitNavigation`,
creates the allocation watcher, reads VM-cache directory settings and acquires
navigation's reference. `DeInitNavigation` clears history before releasing it.

`urldoc/URLDOC.goc:MSG_GEN_DOCUMENT_PHYSICAL_CLOSE` holds its reference through
frame/text destruction, because system detach can close navigation first.
`urltext/URLText.goc` acquires before superclass `MSG_HTML_TEXT_INIT_STORAGE`
and releases after superclass `MSG_HTML_TEXT_DEINIT_STORAGE`. The final release
persists both caches before freeing the global name pool and closing VM files;
the allocation watcher and cache semaphores are destroyed afterward.

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
`urlfetch/URLFETCH.goc` call `urlfetch/URLLoad.goc:LoadURLToFile`, which uses
source-cache lookup and the URLSupport URL-driver/file helpers. The frame's
`MSG_URL_FRAME_URL_FETCHED` parses HTML/plain text or calls
`mime/ContentHandling.goc:HandleUnknownType` for other types. That handler
selects native text import, an image-wrapper HTML message or the save dialog.
Graphic-import workers in `mime/GraphicImport.goc:ImportGraphicByNative`
share ContentHandling's MIME-driver cache and semaphore. These helpers serve
multiple caller/thread contexts; the folder does not own fetch-thread dispatch
or HTML rendering. Startup/shutdown integration is in `init/INIT.goc`,
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
check when `CACHE_VALIDATION` is enabled. Evidence:
`Appl/Breadbox/BbxBrow/cache/SourceCache.goc`, `SrcCacheFindURL`,
`SrcCacheIsExpired`; semaphore macros in `htmlview.goh`.

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
`Appl/Breadbox/BbxBrow/urldoc/URLDOC.goc` and
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
replacement. `urldoc/URLDOC.goc` allocates the two stack-buffer chunks during
physical open/create and frees them during physical close, after dropping
saved snapshots and before frame destruction/cache-reference release.
