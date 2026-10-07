# GOC message compatibility

GOC assigns every `@message` the class's next sequential message number in
source order. Existing message declarations must therefore not be inserted,
removed, or reordered when binary compatibility matters; append new messages
instead.

For conditional builds, keep a pre-existing message in its original slot for
the configuration where it already existed. A declaration needed only by a new
configuration belongs after that configuration's existing messages, so their
numbers stay unchanged.

Evidence: `Tools/goc/parse.y`, `messageLine` increments
`classBeingParsed->data.symClass.nextMessage` at lines 1712-1725; the generated
message list is emitted as an enum at lines 1167-1185. The GOC documentation
also describes messages as compile-time 16-bit enumerated values in
`TechDocs/html/Programming/GOCLanguage/combo.htm` around lines 1611 and
1890-1905.

For a library header using `@protominor`, wrap the public declarations in
`@deflib <library>` and `@endlib`. The defining library must suppress only
the `@protominor`/matching `@protoreset` pair with a private `XGOCFLAGS`
build macro; external clients keep those directives and emit the library
dependency. The library's normal `LIBNAME` handling already supplies its
`-L` option, so do not add a duplicate. Evidence: `CInclude/html4par.goh`
and `Library/Breadbox/Html4Par/local.mk`.

## Methods across source files and code resources

A class's defining file keeps its single `@classdecl` and uses
`@extern method Class, MSG_NAME;` to register externally implemented handlers.
The other file defines each handler with `@extern method Class, MSG_NAME`
followed by its body, without another `@classdecl`. Preserve conditional guards
on both sides. Existing examples: BbxBrow `urltext/URLTEXT.goc` /
`urltext/URLTextClipboard.goc` and `urlframe/URLFRAME.goc` / `urlframe/FRFETCH.goc`.

Source-file boundaries do not require separate code resources. BbxBrow
`urlframe/FRFETCH.goc` selects `FRFETCH2_TEXT` explicitly for
`MSG_URL_FRAME_URL_FETCHED` using Borland `#pragma codeseg` plus
`#pragma option -dc-`, and Watcom `#pragma code_seg("FRFETCH2_TEXT")`.
Check the actual original segment before extracting code; `bin/printobj`
reads linked `.sym` files and reports segment names and method symbols.
It does not read Watcom OMF `.obj` files.

Linux `mkmf` preserves directory enumeration order rather than sorting file
lists (`Tools/nmkmf/mkmf.c:MkmfScanDir`, `MkmfFindSubdirsCommon`). Regeneration
can therefore reorder `OBJS`, affecting numeric resource IDs. When numeric
resource order must be preserved, retain the previous object order; otherwise
compare resource names, attributes and resolved dispatch targets rather than
assuming identical resource IDs. `mkmf` can run over a temporary source mirror
with ordered entries to regenerate the same lists plus the new source, without
editing the generated Makefile by hand.

Runtime handle cost follows linked resources, not object-file count.
`Library/Kernel/Geodes/geodesLoad.asm:InitResources` iterates the resource table
and calls `AllocateResource` (or reuses another instance's read-only resource).
`AllocateResource` calls `MemAllocFar`; even a discarded resource receives a
handle before its bytes are loaded. Adding a source file to an existing code
resource therefore does not itself add a kernel handle; an extra linked code
resource normally does.

BbxBrow's `LOCAL` macro in `htmlview.goh` is `_near _pascal`.
`ProcessSingleGraphic` and all its callers (including the JavaScript
`MSG_URL_TEXT_CHANGE_GRAPHIC`) belong in `urltext/URLTextImages.goc` so a
source split does not require a new far helper API or a calling-convention
change. Existing shared request metadata is declared in
`urltext/URLTextInternal.h`. The fetch callback and per-child `G_stream` handles
remain in `urltext/URLTextImageProgress.goc`; byte-buffer operations, private
layout and limits are in `urltext/MemStream.c`, with declarations in
`MemStream.h`. The header shares `USE_MEM_STREAM` with both implementation and
caller. The plain C implementation reads `PROGRESS_DISPLAY` from `product.h`,
matching the existing GOC product-feature guard. The four functions retain
their original C calling convention and `URLTEXT_TEXT` placement.

GOC macros can require object declarations that are invisible in the method
text. With `UPDATE_ON_UI_THREAD`, `CallStatusUpdate`, `SendStatusUpdateOptr`,
`SendUpdateProgress` and `AbortOperation` in BbxBrow `htmlview.goh` reference
`HTMLVApp`. Implementing files need `@extern object HTMLVApp;` even when the
only references arise during macro expansion.

BbxBrow's script lookup methods use a legacy Borland
`#pragma codeseg URLTextJS`. There is no matching Watcom `code_seg` switch there: Watcom keeps
the four lookup methods in `URLTEXT_TEXT`. Preserve that compiler difference
in source-only moves (`urltext/URLTextScript.goc`), rather than treating a
missing pragma as an incidental cleanup.

Watcom can emit an empty filename-derived default code segment alongside a
source `#pragma code_seg` selection. Glue prints `*** Empty segment:` and
omits that zero-sized segment from resource output (`Tools/glue/geo.c`).
For a split file, setting Watcom's `-nt` default to the original resource
name as well as retaining the source pragma avoids this diagnostic without
adding a resource. BbxBrow `local.mk` applies `-nt=URLTEXT_TEXT` to its split
URLText implementations, including plain C `MemStream.c`, and
`-nt=URLTEXT2_TEXT` to the renamed clipboard file.
