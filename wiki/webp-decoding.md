# WebP decoding in ImpGraph

`ImpWebP()` in `Library/Breadbox/ImpGraph/IMPBMP/impwebp.goc` calls
`WebPImportNext()` once per macroblock row and checks `MIME_STATUS_ABORT`
between calls. `WebPDecodeRow()` in `Library/WebpLib/webpvp8.c` advances
`decoderP->mbY` after decoding all `mb_w` macroblocks in a row. The normal
chroma filter `swebp__hfilter8_i()` in `Library/WebpLib/webpcore.inc` calls
`swebp__filterloop24()` with a fixed size of 8; its loop decrements that size.
`cache_uv_stride` is `8 * mb_w`, so a stride of 248 means 31 macroblocks,
corresponding to a source width from 481 through 496 pixels.

The VP8 Boolean reader accesses the 4 KB input buffer through the transient
`WebPDecoder.inputP` pointer. `WebPDecodeInit()` locks the buffer while parsing
the VP8 header, and `WebPDecodeRow()` locks it for one macroblock row;
`WebPBoolLoadByte()` uses the pointer for both 2 KB window refills and byte
access. Both decode entry points clear the pointer and unlock the buffer before
returning. In `WebPDecodeRow()`, the input block is unlocked immediately
after the final macroblock is decoded and before `swebp__vp8_process_row()`
filters or outputs the row. `swebp__vp8_process_row()` works from decoded
macroblock state and does not read compressed input. Earlier decode errors use
conditional cleanup to release the input block.

`WebPDecodeRow()` selects a token partition with
`mb_y & nparts_minus_1` and clears its `windowSize` on every row. With one
token partition, this invalidates the same 2 KB token window each row even
though no other token partition can overwrite that half of the input buffer.

`swebp__vp8_output_rows()` in `Library/WebpLib/webpcore.inc` converts each
completed scanline to RGB, PackBits encodes it, and calls `HugeArrayAppend()`.
It unlocks and rebinds the luma and chroma cache around each append. After
`WebPDecodeRow()` unlocks its input, context, luma, and chroma blocks, it updates
the bitmap directory height once by the number of lines appended. This also
accounts for scanlines appended before a later row-processing error.
The filter's many `swebp__abs()` calls are another potential performance cost
on 16-bit systems; a stack sample inside the filter alone does not establish a
loop.

`WebPParseContainer()` in `Library/WebpLib/webpriff.c` rejects zero dimensions
and dimensions above 2048 before decoding. `WebPImportBegin()` in
`Library/WebpLib/webpapi.c` enforces a supplied `maxPixels` limit after parsing
the dimensions and before allocating the work buffers.

`WebPDecodeInit()` in `Library/WebpLib/webpvp8.c` allocates rolling caches as
`mbWidth * 16 * (16 + delay)` luma bytes and
`mbWidth * 16 * (8 + delay / 2)` chroma bytes. With 2048-pixel width and the
complex filter's `delay` of 8 (`swebp__fextrarows` in `webpcore.inc`), the
single luma block is 49152 bytes and the single chroma block is 24576 bytes.
`WebPDecodeRow()` locks both cache blocks and the context during row filtering;
the input block is held only while decoding macroblocks. `WebPlan.md` states a
below-32-KB allocation goal but explicitly calculates this 49152-byte luma
cache later in its memory-layout section.

`ImpWebP()` reserves width * height * 3 units in BbxBrow's `AllocWatcher`
before decoding. When a decode error follows a published progress bitmap,
the progress cache owns that partial VM bitmap, but the importer returns no
bitmap to `ImportG`; therefore the importer itself must release the watcher
reservation. See `Library/Breadbox/ImpGraph/IMPBMP/impwebp.goc` and
`Appl/Breadbox/BbxBrow/htmlview/ImportG.goc`.
