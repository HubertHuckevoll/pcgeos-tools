# WebP decoding in ImpGraph

`ImpWebP()` in `Library/Breadbox/ImpGraph/IMPBMP/impwebp.goc` calls
`WebPImportNext()` once per macroblock row and checks `MIME_STATUS_ABORT`
between calls. `WebPDecodeRow()` in `Library/WebpLib/webpvp8.c` advances
`decoderP->mbY` after decoding all `mb_w` macroblocks in a row. The normal
chroma filter `swebp__hfilter8_i()` in `Library/WebpLib/webpcore.inc` calls
`swebp__filterloop24()` with a fixed size of 8; its loop decrements that size.
`cache_uv_stride` is `8 * mb_w`, so a stride of 248 means 31 macroblocks,
corresponding to a source width from 481 through 496 pixels.

`swebp__vp8_output_rows()` in `Library/WebpLib/webpcore.inc` converts each
completed scanline to RGB, PackBits encodes it, calls `HugeArrayAppend()`, and
updates the bitmap header height through `HugeArrayLockDir()` and
`HugeArrayDirty()` for every line. These per-line VM operations and the
filter's many `swebp__abs()` calls are potential performance costs on 16-bit
systems; a stack sample inside the filter alone does not establish a loop.

`WebPParseContainer()` in `Library/WebpLib/webpriff.c` rejects zero dimensions
and dimensions above 2048 before decoding. `WebPImportBegin()` in
`Library/WebpLib/webpapi.c` enforces a supplied `maxPixels` limit after parsing
the dimensions and before allocating the work buffers.
