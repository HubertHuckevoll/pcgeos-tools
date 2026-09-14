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

Intelligent image admission probes the completed source file in
`ImportThreadEngineClass::MSG_IMPORT_THREAD_ENGINE_IMPORT_GRAPHIC` before
decoding. A nonzero `T_importGraphicRequest.imageProbeMaxPixels` calls
`ToolsProbeGraphicByDriver(..., INTELLIGENT_IMAGE_PROBE_BYTES, ...)`; unknown,
zero-sized, or over-limit images are deferred, while memory-limit import
failures are also deferred. `Wmg3Http` performs no header or streaming
admission, so oversized images still download and may remain in the source
cache but avoid decoder/import work. The retained MIME probe entry accepts a
reserved `LoadProgressData *`, but BbxBrow always passes null.

`MSG_URL_TEXT_GRAPHIC_FETCHED` classifies unsupported `image/*` response MIME
types after download with `ImageMIMEGetUnsupportedFormat()` and marks document
images as compact unsupported placeholders without invoking an importer.
Extension preflight remains separate and installed MIME associations remain
authoritative. Streaming HTTP admission is a possible later optimization.

Evidence: `Appl/Breadbox/BbxBrow/htmlview/ImportG.goc`,
`htmlview/LoadURL.goc`, and `urltext/URLTEXT.goc`; `CInclude/htmldrv.h`; and
`Library/Breadbox/UrlDrv/Wmg3Http/WMG3HTTP.goc`.

Without `PROGRESS_DISPLAY`, MIME discovery in `LoadMimeTypes()` and
`LoadNewMimeDriver()` first requests protocol 4, then falls back to protocol
3 for legacy drivers. `ImportGraphicByNative()` reads the actual loaded
protocol and selects the old eight-argument graphic entry below major 4;
protocol-4 drivers receive the reserved ninth, null progress argument. The
public protocol declarations are in `CInclude/htmldrv.h`, and discovery and
dispatch are in `init/INIT.goc`, `navigate/NAVIGATE.goc`, and
`htmlview/LoadURL.goc`.
