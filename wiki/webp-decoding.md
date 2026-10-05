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
Host tests retain the C filter reference under `WEBP_HOST_TEST`; target
filter loops use ESP (`webpcore.inc`, `webpfilter.asm`). Passing the host
corpus therefore does not execute the target filters. A stack sample inside
a filter alone does not establish a loop.

`WebPParseContainer()` in `Library/WebpLib/webpriff.c` rejects zero dimensions
and dimensions above 2048 before decoding. The five-argument
`WebPImportBegin()` in `Library/WebpLib/webpapi.c` has no pixel-count admission
limit.

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
before row decoding, but after `WebPImportBegin()` initializes working buffers
and creates the output bitmap. The watcher is accounting, not a pixel-memory
allocation: `AllocWatcherAllocate()` compares/subtracts `dword AW_amount`
(`Library/Breadbox/ImpGraph/MAIN/awatcher.goc`). Refusal returns
`IBS_NO_MEMORY` through cleanup without entering the decode loop. BbxBrow's
`InitNavigation()` initializes the shared watcher to `0x400000` units by
default; the `HTMLVIEW_CATEGORY`/`memlimit` INI setting overrides this as
`Kavail * 1000` (`Appl/Breadbox/BbxBrow/init/INIT.goc`).
INI category/key comparison is case-insensitive
(`Library/Kernel/Initfile/initfileLow.asm:CmpString`), so `memLimit` matches
`memlimit`. `InitFileReadInteger()` returns false on success
(`Library/Kernel/Initfile/initfileC.asm:INITFILEREADINTEGER`).
`ImpWebP()` publishes no partial bitmap and frees both the bitmap
and reservation on error or cancellation. On success it clears
`ImportProgressData.IPD_callback`: the final update in BbxBrow's
`MSG_IMPORT_THREAD_ENGINE_IMPORT_GRAPHIC` chooses firstLine zero when that
callback is null, so a decoder that publishes only a complete image can use
the existing full-image replacement path. See
`Library/Breadbox/ImpGraph/IMPBMP/impwebp.goc` and
`Appl/Breadbox/BbxBrow/htmlview/ImportG.goc`.

All six decoder-owned blocks (decoder state, input, context, luma, chroma,
and RGB/PackBits output) use `HF_SWAPABLE`, without `HF_FIXED`
(`webpapi.c:WebPImportBegin`, `webpvp8.c:WebPDecodeInit`). The decoder state
is unlocked between public calls, but `WebPImportNext()` holds it locked
through `WebPDecodeRow()` and each output `HugeArrayAppend()`. Its embedded
`core` occupies 2728 bytes (`webpint.h:WEBP_CORE_WORDS`); the complete state
is slightly larger. During append, context and both pixel caches are
unlocked, while the RGB block remains locked as the append source
(`webpcore.inc:swebp__vp8_output_rows`). Moving decoder state inside an
active call also invalidates `coreP`/`vp8P`, Boolean-reader `decoderP`
pointers, probability-table pointers, and `mb_data`;
`webpvp8.c:WebPRebindCore` rebuilds these after the public entry-point lock.

Decoder completion is bounded by macroblock height, not compressed-file EOF.
`WebPDecodeRow()` returns DONE when `mbY >= mbHeight` and increments `mbY`
on every successful row; admitted height is at most 2048, giving at most
128 successful row calls. `WebPImportNext()` marks decode errors terminal,
and `ImpWebP()` breaks on any result other than OK (including DONE).
Unsupported container/frame features return from `WebPParseContainer()`
before `WebPDecodeInit()` allocates working buffers; `WebPImportBegin()`
frees the zero-initialized decoder on parser failure. `WebPMapResult()`
maps unsupported data to `IBS_WRONG_FILE`, so it does not trigger the
`IBS_UNKNOWN_FORMAT` raster fallback chain in `MAIN/impgraph.goc`.

BbxBrow's page progress indicator is not decoder-row telemetry. In
`Appl/Breadbox/BbxBrow/htmlview/UIOften.goc`,
`MSG_HMLVA_UPDATE_PROGRESS_INDICATOR` (or the process variant) deliberately
alternates the displayed value between `progressValue` and
`progressValue - PROGRESS_BLINK_WIDTH` after unchanged weighted page/formatting
progress for about five seconds. `PI_TIMER` ticks every half second; the
blink threshold is `progressDelay > 10`, and `PROGRESS_BLINK_WIDTH` is 4.
This animation does not establish whether `WebPDecoder.mbY` advances.

The actual MIME import destination is the object-cache VM file from
`ObjCacheGetVMFile(request.name)` (`htmlview/ImportG.goc`), not the
`G_importWorkFile` used for progressive staging. Appending a new HugeArray
data block calls `VMAllocLMem` -> `VMAttachNoEC` -> `VMEnforceHandleLimit`.
The latter triggers above 250 resident handles per file and attempts to
reduce the count to 150 (`Library/Kernel/VMem/vmemLow.asm`). Its
`WriteOutSwappedBlocks` pass writes dirty swapped blocks through `RidBlk`
and `VMUpdateAndRidBlk`. This limit is independent of the allocation watcher.
`HA_UPPER_LIMIT` is 6000 bytes (`vmemConstant.def`); `AllocHABlock` in
`vmemHugeArray.asm` combines an appended element with the preceding block
only when the combined used size stays within that limit.

EC VM writes can incur repeated full-header checks:
`VMFindFollowingUsedBlk` searches from the start of the block table via
`VMGetNextInUseBlk`; every call to the latter invokes `VMCheckDSHeader`
in EC builds (`vmemBlkManip.asm`). That check walks the entire block table
to recount resident handles (`vmemEC.asm`). Thus a search through N entries
can perform O(N squared) header-check work before accounting for repeated
writes or other validation. A sample in this path identifies VM output
work, but does not establish its fraction of total import time.

`VMCheckDSHeader` currently has no `ECF_VMEM` gate, including around its
full-table resident-handle recount. Swat `ec -vm` disables other costly
checks such as `VMCheckStrucs`, `VMVerifyWrite`, and `ECCheckHugeArray`, but
does not bypass the direct call from `VMGetNextInUseBlk`. See
`vmemEC.asm`, `vmemHugeArray.asm:ECCheckHugeArray`, and
`Tools/swat/lib.new/ec.tcl`. The 250/150 handle thresholds and the HugeArray
4000/6000-byte sizing thresholds are kernel constants, not per-file API
settings. For variable-sized HugeArrays, `HugeArrayAppend` appends exactly
one element of the supplied byte size (`vmemHugeArray.asm:HugeArrayAppend`);
combining multiple compressed bitmap scanlines into that one element would
change the one-element-per-scanline representation.

ImpGraph provides a C/ESP decoder integration reference:
`IMPBMP/impgif.h` declares `_pascal ImpGIFProcess`;
`IMPBMP/impgifc.goc:IGIFAnimGrabFrame` calls it. In
`ASMIMP/impgif.asm`, `IMPGIFPROCESS` is the far stack-argument C stub,
which loads registers and calls `ImpGIFProcess`. The core locks decoder
state into DS and uses near routines for state dispatch, dictionary/LZW
decoding, and pixel output. `ASMIMP/asmimpManager.asm` sets the GEOS
convention and includes that implementation. `IMPPACKBITS` in the same
file is a C-callable assembly scanline compressor declared as
`ImpPackBits` in `IMPBMP/ibcommon.h`. These routines belong to ImpGraph;
its GP file depends on WebpLib, and does not export `IMPPACKBITS`.

For ESP DSP code, `Include/product.def` defaults
`SUPPORT_32BIT_DATA_REGS` to TRUE; legacy product branches override it to
FALSE. `Library/AnsiC/memory_asm.asm` conditionally enables `.386` and
uses `rep movsd`. Kernel thread save/restore preserves register high words
and FS/GS under that same switch
(`Include/Internal/heapInt.def:ThreadBlockState`,
`Library/Kernel/Thread/threadSem.asm:WakeUpSI`,
`threadThread.asm:RecoverFromPartialBlock`). This is existing support for
32-bit data registers within the 16-bit GEOS environment.

ESP accepts `.386` but its mnemonic table omits `MOVZX` and `MOVSX`
(`Tools/esp/opcodes.h`, `parse.y`). These instructions require explicit
encoding when needed; `webpfilter.asm:WebPLoadPixel` documents
`0f b6 05` as `movzx ax, byte ptr ds:[di]` in a 16-bit code segment.
Use `.inst byte` for such opcode bytes inside a procedure; plain `byte`
produces the `Data declared in-line without .inst directive` warning.
See `Library/Kernel/FSD/fsdInit.asm` for another explicit opcode example.
