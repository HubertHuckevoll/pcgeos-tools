## Central idea

Wmg3Http, Browser, and ImpGraph have separate responsibilities:

- Wmg3Http downloads HTTP data and writes it to a Browser-selected file.
- Browser owns threads, caching, request state, cancellation, MIME-driver selection, and object lifetime.
- ImpGraph decodes GIF, JPEG, or PNG data into a GEOS VM bitmap or animation.
- Wmg3Http never calls ImpGraph directly.
- Normal downloads pass a completed filename to ImpGraph.
- Progressive GIF/JPEG downloads use a Browser-owned stream between the Wmg3Http fetch thread and an ImpGraph import thread.

This describes the current `split/05-wmg3http-download-size-checks` branch at commit `fcfa3de10d39`.

## Thread model

- The Browser object/UI thread starts image requests in [`MSG_URL_TEXT_PROCESS_GRAPHICS`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/urltext/URLTEXT.goc:1057).
- A Browser fetch-engine event thread receives queued requests through [`URLFetchRequest`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/urlfetch/URLFETCH.goc:386).
- Up to two raw fetch-child threads execute [`URLFetchChildThread`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/urlfetch/URLFETCH.goc:954).
- Wmg3Http runs synchronously on the selected fetch-child thread.
- Browser creates three import event threads in [`ImportThreadEngineStart`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/htmlview/ImportG.goc:157):

  - Import thread 0 handles completed files.
  - Import thread 1 is paired with fetch child 0.
  - Import thread 2 is paired with fetch child 1.

- ImpGraph runs synchronously on the selected import thread. It does not create another decoding thread.

## Normal completed-file flow

1. Browser resolves all image URLs and marks matching images as resolving in [`MSG_URL_TEXT_PROCESS_GRAPHICS`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/urltext/URLTEXT.goc:1057).

2. [`ProcessSingleGraphic`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/urltext/URLTEXT.goc:779):

   - Checks the object cache.
   - Creates a `URLTextRequestGraphic`.
   - Takes a reference on the URL `NameToken`.
   - Increments `UTI_numPendingRequests`.
   - Calls `URLFetchRequest`.
   - Requests `MSG_URL_TEXT_GRAPHIC_FETCHED` as the completion message.

3. [`URLFetchRequest`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/urlfetch/URLFETCH.goc:386) copies any progress state and queues `MSG_URL_FETCH_ENGINE_GET_URL`.

4. The fetch-engine thread selects a free `T_fetchEngineChild`, copies the request into that slot, sets `isBusy`, and wakes the child semaphore in [`MSG_URL_FETCH_ENGINE_GET_URL`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/urlfetch/URLFETCH.goc:702).

5. The fetch child calls [`LoadURLToFile`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/htmlview/LoadURL.goc:701).

6. `LoadURLToFile`:

   - Checks the source-file cache.
   - Generates an internal cache filename.
   - Allows up to ten redirects.
   - Calls [`LoadURLByDriver`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/htmlview/LoadURL.goc:451).

7. `LoadURLByDriver` constructs a [`URLRequestBlock`](/home/konstantinmeyer/pcgeos/CInclude/htmldrv.h:436), loads Wmg3Http, and invokes its `URL_ENTRY_MAIN`.

8. [`Wmg3Http::URLDrvMain`](/home/konstantinmeyer/pcgeos/Library/Breadbox/UrlDrv/Wmg3Http/WMG3HTTP.goc:2915):

   - Allocates a `T_HTTPConnection`.
   - Copies request fields into it.
   - Publishes connection state for cancellation.
   - Calls [`HTTPGet`](/home/konstantinmeyer/pcgeos/Library/Breadbox/UrlDrv/Wmg3Http/WMG3HTTP.goc:1494).

9. `HTTPGet`:

   - Parses the URL.
   - Resolves and opens the socket.
   - Sends the request.
   - Parses HTTP headers.
   - Opens the Browser-provided destination file.
   - Writes received blocks with `FileWrite`.
   - Returns `URL_RET_FILE` when the file is complete.

10. The fetch child creates a `URLFetchResult` and queues `MSG_URL_TEXT_GRAPHIC_FETCHED` back to the text object.

11. [`MSG_URL_TEXT_GRAPHIC_FETCHED`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/urltext/URLTEXT.goc:1249):

   - Copies and frees the fetch result.
   - Copies and frees the original `URLTextRequestGraphic`.
   - Normalizes the result MIME type.
   - Rejects unsupported image MIME types.
   - Queues a completed-file import on import thread 0.

12. [`MSG_IMPORT_THREAD_ENGINE_IMPORT_GRAPHIC`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/htmlview/ImportG.goc:660):

   - Optionally probes intrinsic dimensions.
   - Gets a destination object-cache VM file.
   - Calls `ToolsImportGraphicByDriver`.

13. [`ImportGraphicByNative`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/htmlview/LoadURL.goc:1028) loads ImpGraph and calls its graphic entry.

14. [`ImpGraph::MimeDrvGraphicEx`](/home/konstantinmeyer/pcgeos/Library/Breadbox/ImpGraph/MAIN/impgraph.goc:395):

   - Selects GIF, JPEG, or PNG from the MIME type.
   - Falls back to other decoders when the declared type does not match the bytes.
   - Writes the decoded bitmap or animation into the Browser-provided VM file.
   - Returns the VM block and `ImageAdditionalData`.

15. Browser wraps the VM chain in an object-cache token and sends `MSG_URL_TEXT_INTERNAL_REPLACE_LIKE_GRAPHICS`.

16. The UI installs the bitmap into every image with the same resolved URL, releases the URL reference, and decrements the pending count.

## Progressive GIF/JPEG flow

Progressive loading is only used for eligible GIF/JPEG requests. Intelligent-mode requests disable it because partial data must not bypass the transfer-size check.

1. Browser creates a [`LoadProgressData`](/home/konstantinmeyer/pcgeos/CInclude/htmlprog.h:41) containing:

   - The Browser callback.
   - The destination text object.
   - The image URL token.
   - Stream synchronization fields.
   - A pointer to the original image request.

2. The structure is copied into the selected fetch-child state.

3. When Wmg3Http receives the first body data, it calls the Browser callback with `LPCT_OPEN` in [`HTTPGet`](/home/konstantinmeyer/pcgeos/Library/Breadbox/UrlDrv/Wmg3Http/WMG3HTTP.goc:2527).

4. [`LoadGraphicProgressCallback`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/urltext/URLTEXT.goc:463):

   - Initializes the stream.
   - Determines whether the MIME type supports progressive decoding.
   - Acquires the fetch/import barrier.
   - Sends `MSG_URL_TEXT_LOAD_GRAPHIC_PROGRESS`.

5. [`MSG_URL_TEXT_LOAD_GRAPHIC_PROGRESS`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/urltext/URLTEXT.goc:228) queues an import on the thread paired with that fetch child.

6. Wmg3Http remains the producer:

   - It writes every network block to the source file.
   - It also invokes `LPCT_WRITE`.
   - Browser appends those bytes to a HugeArray stream.

7. ImpGraph is the consumer:

   - GIF and JPEG request bytes through `LPCT_READ`.
   - Browser blocks the importer on `LPD_emptyQueue` when no data is available.
   - Wmg3Http wakes it after writing more data.

8. When the HTTP body ends, Wmg3Http invokes `LPCT_CLOSE`.

9. Browser sets `LPD_fileDone` and wakes the import thread so it can consume the last bytes.

10. Wmg3Http returns `URL_RET_PROGRESS`.

11. `MSG_URL_TEXT_GRAPHIC_FETCHED` does nothing for `URL_RET_PROGRESS`, because the importer already owns final completion.

12. ImpGraph sends intermediate scanline notifications through `ImportGraphicProgressCallback`.

13. Browser converts those notifications into object-cache references and updates the visible image.

14. When decoding ends, the import thread performs the final replacement, releases the fetch/import barrier, releases the URL token, and decrements the pending count.

## Important state and ownership

- `URLTextRequestGraphic`

  - Browser request-specific state.
  - Contains image index, URL token, cache policy, pixel limit, and `progressCanceled`.
  - Allocated before fetching.
  - Freed by `MSG_URL_TEXT_GRAPHIC_FETCHED`.

- `T_fetchEngineChild`

  - Persistent global state for one fetch child.
  - Contains `isBusy`, `isAbort`, `action`, request parameters, `abortRoutine`, and progressive state.
  - The fetch-engine thread writes it.
  - The raw fetch child consumes it.

- `URLFetchResult`

  - Completion envelope from the fetch child to the Browser object.
  - Contains filename, MIME type, final URL, return code, message, and opaque request data.
  - The receiving acknowledgement method must free it.

- `URLRequestBlock`

  - Browser-owned input/output block passed to the URL driver.
  - Wmg3Http may update its URL, filename, MIME type, cache metadata, and error result.
  - Browser frees it after the synchronous driver call returns.

- `T_HTTPConnection`

  - Wmg3Http-owned state for one active request.
  - Its `socketState` transitions through:

    - `STATE_UNCONNECTED`
    - `STATE_PREPARING`
    - `STATE_RESOLVING`
    - `STATE_HTTP_REQUEST`
    - `STATE_UNCONNECTED`
    - `STATE_FREE`

  - Cancellation uses the request token to find this structure.

- `LoadProgressData`

  - Shared state between Wmg3Http, Browser, and ImpGraph.
  - `LPD_sem` protects the callback and stream counters.
  - `LPD_emptyQueue` blocks and wakes the importer.
  - `LPD_importSync` prevents fetch-child reuse until progressive import finishes.
  - `LPD_fileDone` tells the importer that no more bytes will arrive.
  - `LPD_callback == NULL` also acts as “progressive mode disabled.”

- `ImportProgressData`

  - Carries ImpGraph output progress back to Browser.
  - Contains the current VM bitmap, destination VM file, scanline range, image identity, and cache token.

- `MimeStatus`

  - One instance per import thread.
  - `MIME_STATUS_ABORT` requests cancellation.
  - `MIME_STATUS_MEMORY_LIMIT` distinguishes memory rejection from invalid format.

- Return codes also transfer ownership:

  - `URL_RET_FILE`: Browser must queue the importer.
  - `URL_RET_PROGRESS`: importer is already running and owns completion.
  - `URL_RET_TOO_LARGE`: Browser may defer an Intelligent-mode image.
  - `URL_RET_ABORTED` or `URL_RET_PROGRESS_ABORT`: cancellation cleanup applies.
  - `URL_RET_MESSAGE`: error message ownership applies.

## Weaknesses and sanitization opportunities

1. HTTP header-line overflow

   [`sock_getline`](/home/konstantinmeyer/pcgeos/Library/Breadbox/UrlDrv/Wmg3Http/WMG3HTTP.goc:708) allows the byte count to reach the full buffer size and then writes the terminating zero at `buffer[count]`.

   A maximum-length header line can therefore write one byte beyond the buffer.

2. Chunk-size parsing

   Wmg3Http's `htoi` does not report invalid digits or arithmetic overflow.

   [`SocketGetBlock`](/home/konstantinmeyer/pcgeos/Library/Breadbox/UrlDrv/Wmg3Http/WMG3HTTP.goc:426) stores the result in signed `chunkSize`. A wrapped negative value can be converted into a socket receive length.

   This boundary should reject:

   - Empty chunk sizes.
   - Non-hex input before an optional extension.
   - Arithmetic overflow.
   - Negative or otherwise unrepresentable sizes.

3. PNG validation

   [`pngImportProcessChunks`](/home/konstantinmeyer/pcgeos/Library/PngLib/pngimp.c:91) does not fully validate PNG structure.

   In particular:

   - It does not require the IHDR length to be exactly 13 before subtracting 13.
   - It does not enforce IHDR/IDAT/IEND ordering.
   - It does not reject duplicate mandatory chunks.
   - It skips CRC fields instead of validating them.
   - It can accept IEND without proving that usable IDAT state exists.

4. ImpGraph initialization race

   ImpGraph is a single shared library, but Browser can call it from several import threads.

   [`InitGlobals`](/home/konstantinmeyer/pcgeos/Library/Breadbox/ImpGraph/MAIN/impgraph.goc:28) sets `initGlobals = TRUE` before finishing initialization and uses no semaphore.

   Another thread can observe `TRUE` while `doCompress`, `useSysPal`, or other configuration is still being initialized.

5. Stale progress-notification cleanup

   [`MSG_URL_TEXT_IMPORT_GRAPHIC_PROGRESS`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/urltext/URLTEXT.goc:1791) removes and frees a notification only when `HTI_imageArray` still exists.

   If the image array has already disappeared, it does not:

   - Remove the handle from `G_importProgressDataQueue`.
   - Release the cache-token reference.
   - Free the notification block.

6. Automatic downloads have no transfer limit

   Browser sets `UFF_LIMIT_SIZE` only for Intelligent-mode requests in [`ProcessSingleGraphic`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/urltext/URLTEXT.goc:803).

   Automatic image loading can therefore download the entire response regardless of the configured image download limit.

   Wmg3Http's limit arithmetic itself is careful once the flag is enabled.

7. `LoadProgressData` has too many responsibilities

   It combines:

   - Request identity.
   - Function pointers.
   - UI object identity.
   - MIME state.
   - Producer/consumer synchronization.
   - Stream handles.
   - Stream counters.
   - Completion state.
   - An opaque request pointer.

   It is also copied into several different storage locations. This makes its exact owner and valid lifetime difficult to prove.

   A cleaner model would have:

   - One immutable request descriptor.
   - One heap-owned progressive-stream session.
   - An explicit session state.
   - Explicit fetch and import references.

8. Implicit state machines

   Current state is distributed across:

   - `isBusy`
   - `isAbort`
   - `action`
   - `G_abortPending`
   - `numAborts`
   - `progressCanceled`
   - `LPD_callback == NULL`
   - `LPD_fileDone`
   - `G_importActive`
   - `URL_RET_*`

   Several combinations represent the same conceptual state, and invalid combinations are possible.

9. Duplicate structure definition

   `T_fetchEngineChild` is defined in `URLFETCH.goc` and manually duplicated in [`LoadURL.goc`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/htmlview/LoadURL.goc:428) with a “must match” comment.

   It should have one shared definition—or the disabled code requiring the duplicate should be removed.

10. Apparently unused import work files

   Browser creates one `IMPORTWK.%03d` VM file per import thread and stores it in `IPD_vmFile`.

   ImpGraph immediately overwrites `IPD_vmFile` with the actual object-cache VM file in [`MimeDrvGraphicEx`](/home/konstantinmeyer/pcgeos/Library/Breadbox/ImpGraph/MAIN/impgraph.goc:423).

   The import work files appear to be leftover infrastructure and should be verified for removal.

11. MIME normalization differs by path

   Wmg3Http places the raw `Content-Type` value into `LPD_mimeType`.

   Progressive admission uses exact, case-sensitive comparisons against `image/jpeg` and `image/gif`.

   Normal completed-file handling later lowercases the value and strips parameters.

   Therefore values such as these disable progressive loading even though normal loading succeeds:

   - `Image/JPEG`
   - `image/jpeg; charset=binary`

   MIME normalization should happen once before either path makes decisions.

## Compact program flow

[`MSG_URL_TEXT_PROCESS_GRAPHICS`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/urltext/URLTEXT.goc:1057)
→ resolve image URL and choose load policy
→ [`ProcessSingleGraphic`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/urltext/URLTEXT.goc:779)
→ create request state and increment pending count
→ [`URLFetchRequest`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/urlfetch/URLFETCH.goc:386)
→ queue fetch-engine request
→ [`MSG_URL_FETCH_ENGINE_GET_URL`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/urlfetch/URLFETCH.goc:702)
→ reserve fetch child
→ [`URLFetchChildThread`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/urlfetch/URLFETCH.goc:954)
→ [`LoadURLToFile`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/htmlview/LoadURL.goc:701)
→ source-cache and redirect handling
→ [`LoadURLByDriver`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/htmlview/LoadURL.goc:451)
→ construct `URLRequestBlock`
→ [`Wmg3Http::URLDrvMain`](/home/konstantinmeyer/pcgeos/Library/Breadbox/UrlDrv/Wmg3Http/WMG3HTTP.goc:2915)
→ [`HTTPGet`](/home/konstantinmeyer/pcgeos/Library/Breadbox/UrlDrv/Wmg3Http/WMG3HTTP.goc:1494)

Completed-file branch:
→ write response file
→ return `URL_RET_FILE`
→ [`MSG_URL_TEXT_GRAPHIC_FETCHED`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/urltext/URLTEXT.goc:1249)
→ queue import thread 0

Progressive branch:
→ `LPCT_OPEN`
→ [`MSG_URL_TEXT_LOAD_GRAPHIC_PROGRESS`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/urltext/URLTEXT.goc:228)
→ queue paired import thread
→ Wmg3Http produces through `LPCT_WRITE`
→ ImpGraph consumes through `LPCT_READ`
→ Wmg3Http signals `LPCT_CLOSE`
→ return `URL_RET_PROGRESS`

Both branches then converge:
→ [`MSG_IMPORT_THREAD_ENGINE_IMPORT_GRAPHIC`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/htmlview/ImportG.goc:660)
→ optional dimension probe
→ [`ToolsImportGraphicByDriver`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/htmlview/LoadURL.goc:1070)
→ [`ImportGraphicByNative`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/htmlview/LoadURL.goc:1028)
→ [`ImpGraph::MimeDrvGraphicEx`](/home/konstantinmeyer/pcgeos/Library/Breadbox/ImpGraph/MAIN/impgraph.goc:395)
→ decode into VM bitmap
→ create object-cache token
→ [`MSG_URL_TEXT_INTERNAL_REPLACE_LIKE_GRAPHICS`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/urltext/URLTEXT.goc:1596)
→ install bitmap and release references
→ [`MSG_URL_TEXT_DEC_PENDING`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/urltext/URLTEXT.goc:1429).