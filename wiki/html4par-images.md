# Html4Par images

`HTMLimageData.imageALT` may contain a generated filename or `Submit`
fallback. Code that needs authored, non-empty ALT text must also require
`HTML_IDF_ALT_EXPLICIT`. See `ParseImage()` and `TokenizeImageLabel()` in
`Library/Breadbox/Html4Par/htmlpars/opentags.goc`, and the flag definition in
`CInclude/html4par.goh`.

Compact placeholder format labels are seeded from the resolved URL extension
in `ImageURLGetUnsupportedFormat()` and may be replaced by a recognized HTTP
MIME type through `URLTextImageFormatFromMime()` in
`Appl/Breadbox/BbxBrow/urltext/URLTEXT.goc`. An unknown MIME type must not
erase an existing extension hint. `ImpGraphProbeDetect()` detects the actual
byte format in `Library/Breadbox/ImpGraph/IMPBMP/impprobe.goc`, but
`MimeGraphicProbeData` in `CInclude/htmldrv.h` exposes only dimensions, not
the detected format.
