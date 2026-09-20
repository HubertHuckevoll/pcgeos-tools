But why does ImpGraph carry so much browser state?

Because progressive rendering was implemented by passing a Browser context through the MIME-driver API. ImpGraph does not conceptually own most of that state—it transports and updates it so Browser can receive partial images.

The dependency exists in two directions:

- Wmg3Http produces bytes.
- ImpGraph consumes bytes and produces scanlines.
- Browser sits between them and owns both callback mechanisms.

`ImportProgressData` therefore contains three kinds of state that should ideally be separate:

- Decoder output state: bitmap, VM file, dimensions, changed scanlines.
- Browser identity state: text object, URL `NameToken`, cache token.
- Network-stream state: pointer to [`LoadProgressData`](/home/konstantinmeyer/pcgeos/CInclude/htmlprog.h:41).

ImpGraph actually needs only a subset:

- `IPD_loadProgressDataP` to read progressive input.
- `IPD_callback` to report decoded scanlines.
- `IPD_vmFile` and `IPD_bitmap` for its output.
- `IPD_iad`, `IPD_firstLine`, and `IPD_lastLine` to describe progress.

It does not interpret `IPD_textObj`, `IPD_nameT`, or `IPD_cacheItem`. It merely passes the structure to Browser’s [`ImportGraphicProgressCallback`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/htmlview/ImportG.goc:375), which uses those Browser-specific fields for UI messages and object-cache management.

The coupling probably arose for pragmatic PC/GEOS reasons:

- Avoid additional memory blocks and handles.
- Avoid copying state for every scanline update.
- Allow direct far-callback calls instead of another protocol.
- Reuse the same MIME-driver entry for file and streaming imports.
- Keep the decoder synchronous and unaware of threads.

So the effective design is:

`ImpGraph decoder`
→ mutates shared progress record
→ invokes Browser callback
→ Browser interprets its own fields

That is efficient, but it makes the public MIME-driver ABI Browser-specific. The clearest evidence is that [`ImportProgressData`](/home/konstantinmeyer/pcgeos/CInclude/htmldrv.h:107) contains `IPD_textObj`, `IPD_nameT`, and `IPD_cacheItem`, none of which are intrinsic image-decoding concepts.

A cleaner boundary would give ImpGraph only:

- A source interface: file or `read/peek/reset` callback.
- A destination VM file.
- A cancellation flag.
- A progress callback receiving bitmap, dimensions, and changed scanlines.

Browser would keep text objects, name tokens, cache tokens, pending counts, and fetch-thread identity in its own request/session object. In short: ImpGraph carries so much Browser state because `ImportProgressData` is a Browser continuation disguised as a generic decoder-progress structure.