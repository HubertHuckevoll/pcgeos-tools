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
