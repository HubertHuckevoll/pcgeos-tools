# GOC message compatibility

GOC assigns every `@message` the class's next sequential message number in
source order. Existing message declarations must therefore not be inserted,
removed, or reordered when binary compatibility matters; append new messages
instead.

For conditional builds, keep a pre-existing message in its original slot for
the configuration where it already existed. A declaration needed only by a new
configuration belongs after that configuration's existing messages, so their
numbers stay unchanged.

Evidence: `Tools/goc/parse.y`, `messageLine` increments
`classBeingParsed->data.symClass.nextMessage` at lines 1712-1725; the generated
message list is emitted as an enum at lines 1167-1185. The GOC documentation
also describes messages as compile-time 16-bit enumerated values in
`TechDocs/html/Programming/GOCLanguage/combo.htm` around lines 1611 and
1890-1905.

For a library header using `@protominor`, wrap the public declarations in
`@deflib <library>` and `@endlib`. The defining library must suppress only
the `@protominor`/matching `@protoreset` pair with a private `XGOCFLAGS`
build macro; external clients keep those directives and emit the library
dependency. The library's normal `LIBNAME` handling already supplies its
`-L` option, so do not add a duplicate. Evidence: `CInclude/html4par.goh`
and `Library/Breadbox/Html4Par/local.mk`.

## Methods across source files and code resources

A class's defining file keeps its single `@classdecl` and uses
`@extern method Class, MSG_NAME;` to register externally implemented handlers.
The other file defines each handler with `@extern method Class, MSG_NAME`
followed by its body, without another `@classdecl`. Preserve conditional guards
on both sides. Keep comma-separated message groups together in the external
registration: GOC derives the handler name from the first message and reuses
it for subsequent messages (`Tools/goc/parse.y`, `methodMessageList` and
`methodMessage`). BbxBrow's `MSG_URL_FRAME_RELOAD`, `MSG_URL_FRAME_SOURCE`
and `MSG_URL_FRAME_SAVE` therefore share one registration and handler.
Existing examples: BbxBrow `urltext/URLText.goc` /
`urltext/URLTextClipboard.goc` and `urlframe/URLFrame.goc` / `urlframe/URLFrameFetch.goc`.

Source-file boundaries do not require separate code resources. BbxBrow
`urlframe/URLFrameFetch.goc` selects `FRFETCH2_TEXT` explicitly for
`MSG_URL_FRAME_URL_FETCHED` using Borland `#pragma codeseg` plus
`#pragma option -dc-`, and Watcom `#pragma code_seg("FRFETCH2_TEXT")`.
Check the actual original segment before extracting code; `bin/printobj`
reads linked `.sym` files and reports segment names and method symbols.
It does not read Watcom OMF `.obj` files.

Linux `mkmf` preserves directory enumeration order rather than sorting file
lists (`Tools/nmkmf/mkmf.c:MkmfScanDir`, `MkmfFindSubdirsCommon`). Regeneration
can therefore reorder `OBJS`, affecting numeric resource IDs. When numeric
resource order must be preserved, retain the previous object order; otherwise
compare resource names, attributes and resolved dispatch targets rather than
assuming identical resource IDs. `mkmf` can run over a temporary source mirror
with ordered entries to regenerate the same lists plus the new source, without
editing the generated Makefile by hand.

Runtime handle cost follows linked resources, not object-file count.
`Library/Kernel/Geodes/geodesLoad.asm:InitResources` iterates the resource table
and calls `AllocateResource` (or reuses another instance's read-only resource).
`AllocateResource` calls `MemAllocFar`; even a discarded resource receives a
handle before its bytes are loaded. Adding a source file to an existing code
resource therefore does not itself add a kernel handle; an extra linked code
resource normally does.

BbxBrow's `LOCAL` macro in `htmlview.goh` is `_near _pascal`.
`ProcessSingleGraphic` and all its callers (including the JavaScript
`MSG_URL_TEXT_CHANGE_GRAPHIC`) belong in `urltext/URLTextImages.goc` so a
source split does not require a new far helper API or a calling-convention
change. Existing shared request metadata is declared in
`urltext/URLTextInternal.h`. The fetch callback and per-child `G_stream` handles
remain in `urltext/URLTextImageProgress.goc`; byte-buffer operations, private
layout and limits are in `urltext/MemStream.c`, with declarations in
`MemStream.h`. The header shares `USE_MEM_STREAM` with both implementation and
caller. The plain C implementation reads `PROGRESS_DISPLAY` from `product.h`,
matching the existing GOC product-feature guard. The four functions retain
their original C calling convention and `URLText_TEXT` placement.

GOC macros can require object declarations that are invisible in the method
text. With `UPDATE_ON_UI_THREAD`, `CallStatusUpdate`, `SendStatusUpdateOptr`,
`SendUpdateProgress` and `AbortOperation` in BbxBrow `htmlview.goh` reference
`HTMLVApp`. Implementing files need `@extern object HTMLVApp;` even when the
only references arise during macro expansion.

BbxBrow's script lookup methods use a legacy Borland
`#pragma codeseg URLTextJS`. There is no matching Watcom `code_seg` switch there: Watcom keeps
the four lookup methods in `URLText_TEXT`. Preserve that compiler difference
in source-only moves (`urltext/URLTextScript.goc`), rather than treating a
missing pragma as an incidental cleanup.

Watcom can emit an empty filename-derived default code segment alongside a
source `#pragma code_seg` selection. Glue prints `*** Empty segment:` and
omits that zero-sized segment from resource output (`Tools/glue/geo.c`).
For a split file, setting Watcom's `-nt` default to the exact source pragma
name, including case, avoids this diagnostic without adding a resource.
After a case-only rename, update all shared defaults too: BbxBrow
`urltext/URLTextImages.goc` and `urlframe/URLFrameTree.goc` select
`URLText_TEXT` and `URLFrame_TEXT`; uppercase `-nt` defaults create separate
empty segments. BbxBrow `local.mk` matches these names for the split files,
including plain C `MemStream.c`, and uses `-nt=URLTEXT2_TEXT` for the clipboard
file. Empty code segments also occur when a whole implementation is disabled,
as in `navigate/BookmarksDialog.goc`, `navigate/BookmarksStore.goc` and
`urldoc/URLDocumentLocalPage.goc`; a filename change is not required.

BbxBrow frame source ownership is separate from resource ownership:
`urlframe/URLFrame.goc` owns the class, lifecycle/state coordination, page
attachment and document notifications. `URLFrameTree.goc` owns creation,
frameset restoration/collection and traversal; `URLFrameNavigation.goc`
owns link targeting, URL completion and refresh requests. Both use
`URLFrame_TEXT`. `URLFrameFetch.goc` keeps fetch/cache requests, external-file
ownership, parser helpers/callbacks in `FRFETCH_TEXT`, and the acknowledgement
in `FRFETCH2_TEXT`. Its initial Borland/Watcom segment pragmas and scoped
Watcom `-nt=FRFETCH_TEXT` preserve the old filename-derived default after the
canonical rename, retaining the acknowledgement's Borland `-dc-` switch. `URLFramePage.goc` keeps embedded-audio request and
completion together, allowing their `.wav` literals to share one compiler
string pool without a new shared global. `MSG_URL_FRAME_EMBED_FETCHED`
retains `FRFETCH_TEXT` and its original string defaults before the file
switches to `FRFETCH3_TEXT` / Borland `-dc-` for received-page metadata,
presentation/completion and frame geometry.
`ReadFileIntoHA`, `DialogError` and their callers remain together in
`URLFrameFetch.goc`, retaining `LOCAL` (`_near _pascal`). Scoped `-nt` options for
the new frame sources are in `Appl/Breadbox/BbxBrow/local.mk`.

Frame scripting has another legacy compiler distinction:
`URLFrameScript.goc` retains the Borland `FRAME_JS_TEXT` / `-dc-` switch
without adding a Watcom equivalent; Watcom uses `URLFrame_TEXT`.
The conditional Borland switch also remains in `URLFrame.goc`, because it
continues to affect the later `MSG_URL_FRAME_CLEAR_OBJ_CACHE` implementation
when JavaScript is enabled. String-placement options must be preserved as
well as code segment names. Watcom's per-object `CONST` pools may duplicate
literals after a split even when all code-resource sizes remain unchanged.

For linked dispatch checks, `CInclude/object.h` defines `ClassStruct` and
`CMethodDef`; the latter is three bytes (word `methodParameterDef`, byte
`handlerTypeDef`). Compare message numbers, resolved method resource/name
pairs and all three descriptor bytes. `Tools/glue/geo.c:GeoWrite` describes
the geode resource table: word sizes, dword positions, word relocation sizes,
and word allocation flags. `Tools/include/geode.h` and `os90File.h` define
the headers and flags; GEOS 2 file positions are relative to the end of the
256-byte `GeosFileHeader2`. Match resources by name from `bin/printobj`
output, excluding library/absolute segments, rather than by numeric ID.

BbxBrow's document command split shares `URLDOC_TEXT`:
`urldoc/URLDOC.goc` owns the single class declaration, object/templates and
document lifecycle; `URLDocumentHistory.goc` and `URLDocumentNavigation.goc`
define externally registered handlers. `URLDocumentLocalPage.goc` keeps the
local-page persistence concern in its original `LOCALPAG_TEXT` segment using
explicit Borland/Watcom pragmas and scoped Watcom `-nt=LOCALPAG_TEXT`.
The segment is empty when `COMPILE_OPTION_LOCAL_PAGES` is disabled. URLDOC's
Watcom string pool contains the backslash and `.URL` strings from physical
open; retaining that handler intact avoids splitting its literal pool.
`local.mk` sets scoped Watcom `-nt=URLDOC_TEXT` for both new command sources;
their source pragmas preserve Borland and Watcom code placement without
changing string options.

BbxBrow `navigate/SourceCache.goc` owns source-cache state, persistence,
recency and URL/expiration policy; `ObjectCache.goc` owns object-cache state,
VM chains, item reference counts and eviction. Both retain `NAVCACHE_TEXT`.
`CacheInternal.h` shares the original `CacheFileMapBlock` persistence structure
and three existing `LOCAL` (`_near _pascal`) declarations: `CacheGetLocalToken`
serves `SrcCacheFindEntry`, `ObjCacheFindEntry` and `ObjCacheForceNocache`;
`UseAltCache` (under `ALT_SRC_CACHE`) serves `SrcCacheGenerateID` and
`ObjCacheGetVMFile`; `SrcCacheIsExpired` (under `CACHE_VALIDATION`) also serves
`ObjCacheFindURL`. Near calls across these translation units require both
implementations to remain in that same resource. `SrcCacheFindEntry` keeps its
original far C convention. The two compiler string pools can duplicate
`HTML_CACHE_NAME`, used in each cache's open/create paths.

BbxBrow `navigate/BookmarksDialog.goc` and `BookmarksStore.goc` retain
`BOOKCLAS_TEXT` and `BOOKMARK_TEXT`, including their empty segments when
`COMPILE_OPTION_BOOKMARKS` is disabled. `FavoritesDialog.goc` owns the four
favorite class declarations, list organization and UI helpers;
`FavoritesCreate.goc` implements the four externally registered favorite/group
creation and dialog-initialization handlers in `FAVORCLS_TEXT`.
`FavoritesStore.goc` retains `FAVORITE_TEXT` and private VM/IBMS tree/index
state. Its `FavoritesBuildUIList` directly traverses `G_favoritesIBMS` and
`G_favoritesTopTen` and calls `ILocateEntryByPos`, so it belongs with that
private state rather than being moved merely because it draws menu monikers.
Class/message interfaces remain in `bookclas.goh`, `bookmark.goh`,
`favorcls.goh` and `favorite.goh`.

BbxBrow's MIME-driver cache is shared by text and graphic imports:
`navigate/NavigationMime.goc:ImportTextByNative` and
`htmlview/GraphicImport.goc:ImportGraphicByNative` use `MimeDriverSemaphore`,
`lastMimeDriver`, `lastMimeName` and `LoadNewMimeDriver`. Each adds a geode
reference before releasing the semaphore, invokes the driver, then removes
the reference. `init/INIT.goc:InitNavigation` loads the association arrays
before creating the semaphore. `DeInitNavigation` deliberately leaves that
semaphore for automatic exit cleanup because
`htmlview/GraphicImport.goc:MSG_IMPORT_THREAD_ENGINE_KILL` still acquires it to free
and clear the cached driver. Keep this initialization/cleanup ordering intact.
The seven MIME/import/unknown-content functions and cache definitions share
`Navigation_TEXT`; `Navigation.goc` retains the HTMLResource chunks in declaration
order, and `NavigationMime.goc` declares the referenced chunks/objects,
including `HTMLVApp` for expanded progress macros. The existing interfaces
use plain C calling conventions.

A Watcom source split can grow code even without duplicate literals or a new
resource: a same-file call to a far C function can use four bytes (`push cs`
plus near call), while an external call uses five. Glue converts a far call
within the same linked resource to `push cs`, near call and a trailing NOP,
removing its runtime relocation without shrinking the call site. Evidence:
`Tools/glue/msobj.c`, same-segment call handling in `MSObj_PerformRelocations`,
and BbxBrow `navigate/Navigation.goc:LoadFILEURL` calling
`NavigationMime.goc:IdentifyMimeType`. `Tools/glue/geo.c:GeoPrepare` reserves
file space for relocation records before that conversion; `GeoWrite` emits
the reduced relocation count. Compare linked resource-table relocation sizes
as well as Glue's initial counts and total geode file sizes. Watcom switch
tables may also require an unreachable padding byte after a split; inspect
object disassembly to distinguish alignment from changed logic.

## BbxBrow application UI source and swapping boundaries

Under `Appl/Breadbox/BbxBrow/htmlview/`, `HTMLView.goc` owns process/application
registration, UI resources, shared integration globals, shutdown, local-page UI
and `URLEntryClass`. `HTMLViewLifecycle.goc` owns startup, launch/IACP requests
and UI-thread creation in `OpenClos_TEXT`.

`HTMLViewNavigation.goc` groups navigation/toolbar commands, title/URL updates,
history and editor/cache commands. `HTMLViewOptions.goc` groups rendering
preferences, parental-control notifications and view/search controls.
`HTMLViewOperation.goc` groups loading/abort, busy/input coordination,
connection errors and deferred detach. These source boundaries deliberately
cross the retained `UIAction_TEXT`, `UIRare_TEXT`, `UIOften_TEXT` and
`HTMLVIEW_TEXT` resources. Explicit compiler-specific segment switches retain
the old rare/often swapping boundaries without changing string options;
scoped Watcom defaults are in `local.mk`.

`HTMLViewStatus.goc` owns status IDs, the download progress dialog and page
progress in `UIOften_TEXT`; its file-transfer display helpers and static
bookkeeping retain `LoadURL_TEXT`. `URLLoad.goc` retains URL-driver callbacks,
fetch/cache/redirect coordination and `URLDriverSemaphore` in `LoadURL_TEXT`.
`GraphicImport.goc` keeps worker requests, progress, synchronization and cleanup
in `ImportG_TEXT`, together with native graphic-driver dispatch in
`LoadURL_TEXT`. `AutoBrowse.goc` and `Scrapbook.goc` separate automation state
from the clipboard/IACP protocol while sharing `scrapbk_TEXT`.

`EnabledOrNot` stays `LOCAL` (`_near _pascal`) with its original navigation
and Stop-button callers; `UsableOrNot` stays with its toolbar-option callers.
The local-page handlers remain in `HTMLView.goc`: their existing calls to
`EnabledOrNot` have no prototype in that translation unit. Putting them after
its near definition would change the compiler's call convention. Source-only
regrouping must preserve this boundary rather than silently repairing it.
Evidence: `HTMLView.goc:MSG_HMLVP_NOTIFY_LOCAL_PAGE_CHANGE`,
`MSG_HMLVP_DELETE_LOCAL_FILE`, `MSG_HMLVP_LOCAL_PAGE_UPDATE`,
`HTMLViewNavigation.goc:EnabledOrNot`, and `htmlview.goh:LOCAL`.

Watcom's optimized NC build can also change inlining after regrouping:
`HTMLViewOperation.goc:MSG_HMLVA_ABORT_OPERATION` can inline `UserAbortStart`,
while `HTMLViewStatus.goc:MSG_HMLVA_UPDATE_DOWNLOAD_PROGRESS_DIALOG` calls
`UserAbortCheck` across object files. The methods and helpers still retain
their original named resources and signatures. Separate `CONST` pools can
duplicate `HTMLVIEW_CATEGORY` (`"HTMLView"`) when operation and option handlers
are separated. Inspect OMF with Watcom `wdis`, then compare linked resource
sizes and relocation tables; source-token equality does not imply identical
instruction sizes or constant-pool padding.
