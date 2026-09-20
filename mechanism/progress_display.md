## Mental model

There are two distinct kinds of progress:

1. Download progress: decode/import starts while HTTP is still receiving bytes.
2. Import progress: the complete file already exists, but the decoder publishes the bitmap incrementally as scanlines are decoded.

A third mode disables both: download the file, decode it completely, then replace the placeholder once.

`PROGRESS_DISPLAY` is the compile-time capability switch. The INI values select runtime behavior within a build containing that capability.

Your hypothesis is correct: for a cache miss, `progressDisplay=false` downloads first, imports afterward, and shows the image only after the import finishes.

## The two progress mechanisms

The important state structures are:

- [`LoadProgressData`](/home/konstantinmeyer/pcgeos/CInclude/htmlprog.h:41): producer/consumer stream between the HTTP fetch thread and the image import thread. Non-null means "decode while downloading."
- [`ImportProgressData`](/home/konstantinmeyer/pcgeos/CInclude/htmldrv.h:108): partial bitmap state, including `IPD_bitmap`, `IPD_firstLine`, `IPD_lastLine`, and `IPD_callback`. A non-null callback means "publish decoded scanlines."

The complete flow is:

[ProcessSingleGraphic()](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/urltext/URLTEXT.goc:779)
`  | optionally creates LoadProgressData`
`  v`
[URLFetchRequest()](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/urlfetch/URLFETCH.goc:386)
`  | passes it to the URL driver`
`  v`
[HTTPGet()](/home/konstantinmeyer/pcgeos/Library/Breadbox/UrlDrv/Wmg3Http/WMG3HTTP.goc:1494)
`  | LPCT_OPEN starts importer`
`  | LPCT_WRITE supplies received bytes`
`  v`
[LoadGraphicProgressCallback()](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/urltext/URLTEXT.goc:463)
`  | importer reads bytes with LPCT_READ`
`  v`
[ImportThreadRequestImportGraphic()](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/htmlview/ImportG.goc:464)
`  | sets IPD_callback`
`  v`
[MSG_IMPORT_THREAD_ENGINE_IMPORT_GRAPHIC](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/htmlview/ImportG.goc:660)
`  | decoder produces scanline ranges`
`  v`
[ImportGraphicProgressCallback()](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/htmlview/ImportG.goc:375)
`  v`
[MSG_URL_TEXT_IMPORT_GRAPHIC_PROGRESS](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/urltext/URLTEXT.goc:1791)
`  v`
[IReplaceGraphic()](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/urltext/URLTEXT.goc:1574)
`  v`
[MSG_HTML_TEXT_RESOLVE_IMAGE](/home/konstantinmeyer/pcgeos/Library/Breadbox/Html4Par/htmlclas/htmlclas.goc:2496)
`  | updates the image and invalidates firstLine..lastLine`

In the streaming case, HTTP still writes the cache file, but also copies received blocks into the `LoadProgressData` memory stream. The importer reads from that stream and may block waiting for more bytes.

In the completed-file case, [`MSG_URL_TEXT_GRAPHIC_FETCHED`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/urltext/URLTEXT.goc:1249) receives `URL_RET_FILE` and starts the importer with `loadProgressDataP == NULL`. The importer reads the finished file normally. If `IPD_callback` is enabled, scanlines are nevertheless displayed progressively during decoding.

The final completed bitmap is always sent through [`MSG_URL_TEXT_INTERNAL_REPLACE_LIKE_GRAPHICS`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/urltext/URLTEXT.goc:1596), even when intermediate updates were disabled or coalesced.

## What the switches actually do

[`PROGRESS_DISPLAY`](/home/konstantinmeyer/pcgeos/Include/product.def:78) is currently enabled. At compile time it adds:

- `LoadProgressData` transport support.
- Multiple import threads associated with fetch threads.
- Import progress callbacks and partial-bitmap replacement.
- `URL_RET_PROGRESS` completion handling.
- The related runtime INI processing.

[`InitNavigation()`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/init/INIT.goc:614) reads the two booleans at [INIT.goc:782](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/init/INIT.goc:782).

Current behavior is:

- `progressDisplay=false`, regardless of `imagesWhileLoading`:
  - No download/import overlap.
  - No partial bitmap updates.
  - Download complete, then full import, then display once.

- `progressDisplay=true`, `imagesWhileLoading=false`:
  - Eligible images are still imported and displayed while downloading.
  - Completed-file imports are not displayed progressively.
  - Thus the result depends on whether streaming was available.

- `progressDisplay=true`, `imagesWhileLoading=true`:
  - Eligible images are imported and displayed while downloading.
  - Completed-file imports are also displayed progressively during decoding.

That behavior follows directly from the callback condition in [`ImportThreadRequestImportGraphic()`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/htmlview/ImportG.goc:524):

```c
progressDisplay &&
    (loadProgressDataP || imagesWhileLoading)
```

Therefore, the current `imagesWhileLoading` name is misleading. It does not enable or disable importing while downloading. `loadProgressDataP` does that. The setting enables progressive display when `loadProgressDataP` is null, meaning after the complete file is available.

This completed-file functionality exists because [`COMPILE_OPTION_IMPORT_PROGRESS_LOCAL`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/options.goh:354) is enabled.

## Streaming limitations

Even with both settings true, streaming is conditional:

- [`ProcessSingleGraphic()`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/urltext/URLTEXT.goc:878) deliberately disables it for Intelligent-mode requests.
- Reserved/background images and images below `progressMinHeight` do not receive `LoadProgressData`.
- HTTP disables streaming below the configured `contentLength` threshold at [WMG3HTTP.goc:2433](/home/konstantinmeyer/pcgeos/Library/Breadbox/UrlDrv/Wmg3Http/WMG3HTTP.goc:2433).
- [`LoadGraphicProgressCallback()`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/urltext/URLTEXT.goc:482) accepts streaming only for JPEG and GIF.
- PNG supports progressive decoding of a finished file, publishing every ten scanlines at [imppng.goc:103](/home/konstantinmeyer/pcgeos/Library/Breadbox/ImpGraph/IMPBMP/imppng.goc:103), but not network streaming.
- An object-cache hit is displayed immediately and needs neither process.

So "stream while downloading" must always have "progressively decode after download" as its fallback.

## Recommendation

The three-state mental model is correct:

- `final`: download, import fully, display once.
- `decode`: download fully, then import/display progressively.
- `stream`: import/display while downloading; fall back to `decode`.

But I would not change the existing `progressDisplay` boolean into a three-valued setting. The existing two booleans can already express the hierarchy cleanly with a smaller, backward-compatible change:

- `progressDisplay=false`: `final`
- `progressDisplay=true`, `imagesWhileLoading=false`: `decode`
- `progressDisplay=true`, `imagesWhileLoading=true`: `stream`, falling back to `decode`

To achieve that, the wiring should conceptually become:

- `ProcessSingleGraphic()` supplies `LoadProgressData` only when both `progressDisplay` and `imagesWhileLoading` are true.
- `ImportThreadRequestImportGraphic()` enables `IPD_callback` whenever `progressDisplay` is true, including completed-file imports.

That would make the existing key names match their behavior. If a single user-facing setting is strongly preferred, introduce a new `imageProgressMode = final|decode|stream` setting and retain the old booleans as compatibility fallback rather than changing the type of the historical `progressDisplay` key.