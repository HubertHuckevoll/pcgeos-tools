Mental model

Wmg3Http is a synchronous HTTP-to-file driver with two optional side channels:

```text
HTTP socket -> 2 KB receive buffer -> destination file
                                  +-> transfer-status callback
                                  `-> progressive image-data callback
```

The transfer-status callback reports messages and byte counts. The progressive callback is effectively a client-owned producer/consumer stream: Wmg3Http writes body blocks into it while an image decoder reads them on another thread.

Wmg3Http never returns the network socket or a stream handle. It always downloads through its internal socket and normally creates a file, even when progressive decoding is active.

Everything below is verified from the current source.

API entry point

The library exports `URLDRVMAIN`, `URLDRVABORT`, `URLDRVINFO`, and `URLDRVFLUSH` in [wmg3http.gp](/home/konstantinmeyer/pcgeos/Library/Breadbox/UrlDrv/Wmg3Http/wmg3http.gp:33).

The main call is:

```c
word URLDrvMain(MemHandle request, HTMLFormDataHandle postData);
```

The caller supplies an LMem block containing a [URLRequestBlock](/home/konstantinmeyer/pcgeos/CInclude/htmldrv.h:436). Important fields are:

- `URB_url`: URL chunk in the request LMem heap.
- `URB_file`: destination filename chunk.
- `URB_token`: request identity, also used for aborting.
- `URB_reqFlags`: cache and transfer-size policy.
- `URB_progress`: ordinary status/byte-count callback.
- `URB_loadProgressDataP`: optional progressive-data stream.
- `URB_mimeType`, `URB_message`, and related fields: outputs.

[URLDrvMain()](/home/konstantinmeyer/pcgeos/Library/Breadbox/UrlDrv/Wmg3Http/WMG3HTTP.goc:2915) copies these values into an internal [T_HTTPConnection](/home/konstantinmeyer/pcgeos/Library/Breadbox/UrlDrv/Wmg3Http/wmg3con.goh:23), calls [HTTPGet()](/home/konstantinmeyer/pcgeos/Library/Breadbox/UrlDrv/Wmg3Http/WMG3HTTP.goc:1494), writes results back to the request block, and returns a `URL_RET_*` value.

The call is synchronous: `URLDrvMain()` does not return until the HTTP transfer finishes. Progressive image importing can nevertheless run concurrently on a separate import thread.

Three different meanings of "progress"

1. Transfer status: `URB_progress`

[proc_URLDrvCallback](/home/konstantinmeyer/pcgeos/CInclude/htmldrv.h:411) receives:

```c
(msg, progress, total, token)
```

Wmg3Http uses it for:

- Phase messages such as locating, contacting, requesting, waiting, and closing. These pass `progress = total = -1`.
- MIME notification. The MIME string is sent as `msg`, also with `-1, -1`.
- Download byte counts after each received block.
- Multipart upload byte counts.

For downloads, `progress` is the accumulated entity-body byte count. `total` is `Content-Length`, or `-1` when unknown. Resumed requests include the retained prefix in both values. See the receive callback in [HTTPGet()](/home/konstantinmeyer/pcgeos/Library/Breadbox/UrlDrv/Wmg3Http/WMG3HTTP.goc:2613).

This callback returns `void`; it cannot cancel the request. Cancellation uses `URLDrvAbort(token, state)`.

2. Progressive loading: `URB_loadProgressDataP`

This is not a percentage callback. It is a byte-stream protocol defined by [LoadProgressData and LoadProgressCallbackType](/home/konstantinmeyer/pcgeos/CInclude/htmlprog.h:17).

Wmg3Http uses only:

- `LPCT_OPEN`: start a new entity stream.
- `LPCT_WRITE`: deliver another body block.
- `LPCT_CLOSE`: mark end-of-stream.

The importer uses the other direction:

- `LPCT_READ`: consume bytes.
- `LPCT_PEEK`: read without consuming.
- `LPCT_PRE_READ`: read while retaining rewind information.
- `LPCT_FLUSH_FIRST`: discard retained initial data.
- `LPCT_RESET_STREAM_STATE`: rewind/reset sniffing state.

Thus the same callback implements both producer and consumer operations.

3. Graphic import progress

After the progressive stream starts an importer, the decoder can publish partially decoded scanlines through `ImportGraphicProgressCallback`. That is downstream rendering progress, separate from both HTTP byte counts and the byte stream itself.

Stream lifecycle

After parsing the headers, [header()](/home/konstantinmeyer/pcgeos/Library/Breadbox/UrlDrv/Wmg3Http/WMG3HTTP.goc:883) stores `Content-Type` in both the request and `LPD_mimeType`, and extracts `Content-Length`. Chunked responses retain an unknown logical length and are decoded by [SocketGetBlock()](/home/konstantinmeyer/pcgeos/Library/Breadbox/UrlDrv/Wmg3Http/WMG3HTTP.goc:426).

Before reading the body, Wmg3Http disables progressive streaming when:

- `Content-Length` is below `progressMinCL`, whose default is 4 KB.
- A requested download-size limit is active, so rejected downloads cannot expose partial image data.

This gate is in [HTTPGet()](/home/konstantinmeyer/pcgeos/Library/Breadbox/UrlDrv/Wmg3Http/WMG3HTTP.goc:2433). Unknown-length and chunked responses are not considered small.

For the first nonempty body block, Wmg3Http calls `LPCT_OPEN`. For every block it then performs this ordering:

```text
validate size
FileWrite()
length += blockSize
LPCT_WRITE(block)
URB_progress(length, total)
```

See the decisive receive loop in [HTTPGet()](/home/konstantinmeyer/pcgeos/Library/Breadbox/UrlDrv/Wmg3Http/WMG3HTTP.goc:2516).

`LPCT_WRITE` is synchronous, so the callback must copy the buffer before returning; Wmg3Http immediately reuses its receive buffer.

At EOF, Wmg3Http closes the destination file and calls `LPCT_CLOSE`, which means "the producer is finished", not necessarily "the HTTP transfer was error-free." If a live progressive stream received any data, the return code becomes:

- `URL_RET_PROGRESS` normally.
- `URL_RET_PROGRESS_ABORT` if aborted.

`URL_RET_PROGRESS` does not mean a progress percentage. It means that completion ownership has moved to the progressive importer. This conversion happens in [HTTPGet()](/home/konstantinmeyer/pcgeos/Library/Breadbox/UrlDrv/Wmg3Http/WMG3HTTP.goc:2672).

Browser-side stream implementation

BbxBrow's [LoadGraphicProgressCallback()](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/urltext/URLTEXT.goc:463) supplies the actual stream:

- `LPCT_OPEN` initializes a memory stream and starts an import request.
- It permits network-progressive importing only for JPEG and GIF; otherwise it clears `LPD_callback`, causing Wmg3Http to finish as a normal file request.
- `LPCT_WRITE` copies bytes into the memory stream and increments `LPD_bytesAvail`.
- `LPCT_READ` waits until the requested byte count is available or `LPD_fileDone` becomes true.
- `LPCT_CLOSE` sets `LPD_fileDone` and wakes a blocked decoder.

JPEG reads through `LPCT_PRE_READ` or `LPCT_READ` in [fill_input_buffer_i()](/home/konstantinmeyer/pcgeos/Library/Breadbox/Fjpeg/code/init.c:70). GIF uses `LPCT_READ` and the first-packet rewind operations in [impgifc.goc](/home/konstantinmeyer/pcgeos/Library/Breadbox/ImpGraph/IMPBMP/impgifc.goc:544).

Important stream state

[LoadProgressData](/home/konstantinmeyer/pcgeos/CInclude/htmlprog.h:41) carries:

- `LPD_callback`: enables or cancels progressive operation.
- `LPD_mimeType`: response MIME type.
- `LPD_sem`: protects the callback pointer and stream counters.
- `LPD_emptyQueue`: blocks readers awaiting data.
- `LPD_bytesAvail`: unread byte count.
- `LPD_preReadOffset`: bytes tentatively read during format probing.
- `LPD_fileDone`: producer has closed.
- `LPD_streamState`: `LPSS_EMPTY`, `LPSS_FIRST_PACKET`, or `LPSS_MORE_DATA`.
- `LPD_importSync`: keeps fetch-side state alive until importing finishes.
- `LPD_request`: associated browser request, used during cancellation.

The unusual first-packet state lets the browser inspect initial bytes and retry another decoder without having already destroyed those bytes.

Concurrency and cancellation

Wmg3Http reads `LPD_callback` through [LoadProgressCallbackSnapshot()](/home/konstantinmeyer/pcgeos/Library/Breadbox/UrlDrv/Wmg3Http/WMG3HTTP.goc:1449):

1. Acquire `LPD_sem`.
2. Copy the callback pointer.
3. Release `LPD_sem`.
4. Invoke the callback.

It must release the semaphore before invocation because `LoadGraphicProgressCallback()` itself acquires `LPD_sem`.

Stop clears `LPD_callback` under the same semaphore. This prevents future callbacks, but one callback already captured by Wmg3Http may still finish. BbxBrow keeps the fetch-child stream state alive until `LoadURLToFile()` returns and uses an import synchronization barrier before reusing it. See [URLFetchChildThread()](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/urlfetch/URLFETCH.goc:991).

Network cancellation is separate. [URLDrvAbort()](/home/konstantinmeyer/pcgeos/Library/Breadbox/UrlDrv/Wmg3Http/WMG3HTTP.goc:3034) finds the connection by `URB_token`, sets `aborted`, and interrupts either DNS resolution or the active socket.

Program flow

[ProcessSingleGraphic()](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/urltext/URLTEXT.goc:779)
`    | creates LoadProgressData with LoadGraphicProgressCallback`
`    v`
[URLFetchRequest()](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/urlfetch/URLFETCH.goc:386)
`    | copies state into an asynchronous fetch child`
`    v`
[LoadURLByDriver()](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/htmlview/LoadURL.goc:451)
`    | builds URLRequestBlock; sets both progress callbacks`
`    v`
[URLDrvMain()](/home/konstantinmeyer/pcgeos/Library/Breadbox/UrlDrv/Wmg3Http/WMG3HTTP.goc:2915)
`    | creates T_HTTPConnection`
`    v`
[HTTPGet()](/home/konstantinmeyer/pcgeos/Library/Breadbox/UrlDrv/Wmg3Http/WMG3HTTP.goc:1494)
`    | header(): MIME, Content-Length, chunked state`
`    | LPCT_OPEN`
`    v`
[LoadGraphicProgressCallback()](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/urltext/URLTEXT.goc:463)
`    | creates stream; queues MSG_URL_TEXT_LOAD_GRAPHIC_PROGRESS`
`    v`
[MSG_URL_TEXT_LOAD_GRAPHIC_PROGRESS](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/urltext/URLTEXT.goc:228)
`    | starts progressive import thread`
`    v`
[MSG_IMPORT_THREAD_ENGINE_IMPORT_GRAPHIC](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/htmlview/ImportG.goc:660)
`    | decoder calls LPCT_READ while HTTPGet calls LPCT_WRITE`
`    v`
[HTTPGet()](/home/konstantinmeyer/pcgeos/Library/Breadbox/UrlDrv/Wmg3Http/WMG3HTTP.goc:2672)
`    | LPCT_CLOSE; returns URL_RET_PROGRESS`
`    v`
[MSG_URL_TEXT_GRAPHIC_FETCHED](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/urltext/URLTEXT.goc:1249)
`    | leaves completion to the already-running importer`
`    v`
[Import completion](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/htmlview/ImportG.goc:856)
`    `-> releases fetch/import synchronization and pending request`