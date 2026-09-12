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
