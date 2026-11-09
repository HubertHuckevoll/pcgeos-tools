# GEOS library definition files during builds

A new library geode's normal build creates its `.ldf` in its own `Installed/` build directory. Dependent geodes look for library definitions in `Installed/Include/`. After building the library, run `pmake lib` in its Installed build directory to copy the `.ldf` there before building dependents. `CInclude/geode.mk` defines `LIBOBJ`, `LIB_DEST`, and the `lib` target that performs the copy (around lines 176-221). `pcgeos-tools/aihelp.py` builds EC and NC with plain `pmake` (functions `build_once` and `cmd_build`), so its successful build alone does not run that copy target.

The top-level `Installed/Makefile` is a hand-maintained product build graph, unlike the mkmf-generated Makefiles in `Installed/` module subdirectories. Its `MAKELIB` rule runs `pmake full lib` for dependencies, so a new library must have a named target and must be included in the dependency list of each consumer. The product file tree only selects geodes to copy into the assembled runtime; it does not build missing dependencies. The `full` target also builds each generated Makefile's `PRODUCTS` variants (`Include/sun.geode.mk`), so filetree paths such as `Library/Breadbox/ImpGraph/FJPEG/impgraph{ec}.geo` are covered by the parent module target. See `Installed/Makefile` (`MAKELIB`, `impgraph`, `graphvwr`) and `Tools/build/product/bbxensem/bbxensem.filetree` (ImpGraph and SvgLib entries).

Overriding `PRODUCTS` on the pmake command line does not add the product's dependency-file include to an existing generated Makefile. If that include is missing, assembler targets can invoke ESP without a manager source in `.ALLSRC`. Regenerate the Makefile with `mkmf` so it includes the discovered products' dependency files; regenerate dependencies with `pmake depend` when absent or stale. Evidence: `Tools/nmkmf/mkmf.c:MkmfPrintPRODUCTS` and product dependency includes around lines 2587-2597; `Include/sun.geos.mk:ASSEMBLE` selects `$(.ALLSRC:M*Manager.asm)`.

Glue's OMF local-symbol lookup uses the owning object filename and symbol ID,
independently of the first contributor to a merged public segment.
`Tools/glue/pass1ms.c:Pass1MS_ProcessObject` supplies `symObjectFile` while
CodeView/raw definitions are entered; LPUBDEF records retain local scope.
`Tools/glue/sym.c:Sym_Enter` indexes local definitions by object/name using
existing symbol block/offset references. The ordinary segment hash retains
global visibility when a global shares a name with a local.

`Sym_FindWithFile` resolves LEXTDEF against that object's local index first,
then falls back to globals. EXTDEF excludes locals, so another object's static
function cannot satisfy a missing definition. Symbol-file layout is unchanged.
The older filename comparison against `SegDesc.file` made C static lookup
object-order dependent and could select the wrong same-named local after
segment merging; BbxBrow and WebpLib no longer need their ordering workarounds.
`Tools/glue/tests/check_local_symbols.pl` exercises both link orders, duplicate
local functions/data, global fallback, and real Watcom CodeView procedures.

Conditional GP imports follow linker feature definitions independently of C/GOC
code guards. Wmg3Http enables `SSL_ENABLE` in CCOMFLAGS, GOCFLAGS, and LINKFLAGS
in `Library/Breadbox/UrlDrv/Wmg3Http/local.mk`; its `wmg3http.gp` imports `ssl`
under `ifdef SSL_ENABLE`. Commenting out only that GP import leaves compiled
SSL calls enabled. Build `Library/SSL`, then run `pmake lib` in
`Installed/Library/SSL` to publish `ssl.ldf` before linking Wmg3Http; regenerate
Wmg3Http dependencies with `pmake depend` after changing its GP imports.

The Linux pmake build can return exit status 0 after recipe failures with `-k`.
`Tools/pmake/pmake/make.c:Make_Run` stores `Job_End()`'s error count but returns
TRUE; `Tools/pmake/pmake/main.c:main` exits 0 after normal traversal.
`Installed/Makefile:MAKELIB` runs library sub-builds with `-k`, so the parent
can continue despite failed library outputs. The `shinygeodes.sh` and
`shinyall.sh` wrappers in pcgeos-tools also do not check stage success before
continuing. A successful wrapper exit alone does not prove a complete rebuild;
check logged errors and required artifacts. Unix `Include/sun.geode.mk` emits
library definitions during the EC link unless `NO_EC` is set, then `full`/`lib`
publishes them; its copy target is marked `.IGNORE`.

Watcom CodeView `$$TYPES` streams start with a four-byte signature (value 1).
Compiled-out files, such as SSL's host-service-only TLS units, can have a
signature-only stream and no type records. `Tools/glue/codeview32.c` collects
this stream in `CV32_Check`; `CV32LocateType` and
`CV32ProcessUnprocessedTypeRecords` must skip the signature before reading
length-prefixed records. Treating the signature as a record can read beyond
such empty streams and produce spurious scalar-type errors. The regression
cases in `Tools/glue/tests/check_local_symbols.pl` cover missing, empty,
unreferenced and truncated type data through the real linker.

`bin/geodump` can inspect built geode protocols and imported-library
requirements without running GEOS. `Tools/geodump/geodump.c:main` uppercases
the input basename and extension before opening it, so use an uppercase
temporary symlink on case-sensitive hosts. Its `void main` has no explicit
success exit; validate the decoded fields rather than its exit status.

Watcom -zc puts constant arrays into code segments as well as strings. A
cross-resource C data reference such as mov ax,seg HUFFTABLE_1 followed by a
memory read cannot use a movable code resource's virtual segment directly.
DoRelocation in Library/Kernel/Geodes/geodesResource.asm replaces GRT_SEGMENT
references to movable resources with handle-derived virtual segments; only
GRT_CALL and ProcCallFixedOrMovable paths lock/resolve code before execution.
BSNWav therefore omits -zc and declares dgroup fixed in bsnwav.gp.
Immutable decoder tables share this directly addressable segment with mutable
playback state. See Library/Audio/BSNWav/local.mk, bsnwav.gp and the Watcom
output for pvmp3_decode_huff_cw_tab1 in mp3huff.eobj. Moving such tables requires
explicit locking/rebinding or code/data placement that avoids cross-resource
data references, not merely a read-only shared resource flag.

The two ProcCallFixedOrMovable C trampolines place the callback differently:
ProcCallFixedOrMovable_pascal takes normal callback arguments first and the
callback pointer last; ProcCallFixedOrMovable_cdecl takes the callback first.
The far return address is removed by FOM_common, which then pops the callback
from the top of the argument stack. Match this order in any typed trampoline
cast; an ordinary typed cast does not rearrange arguments for the trampoline.
Evidence: Library/Kernel/Geodes/geodesResource.asm:FOM_common,
PROCCALLFIXEDORMOVABLE_PASCAL and _ProcCallFixedOrMovable_cdecl;
CInclude/hwr.h:CallHWRLibrary_OneArg/TwoArgs; and
Library/SvgLib/Export/svgExportWriter.goc:SvgExportPCFMSink.

## Calling callbacks within the active code resource

ResourceCallInt locks a movable code resource before entry and unlocks it on
return (Library/Kernel/Geodes/geodesResource.asm:ResourceCallIntProfiling,
FastLock1/FullLockNoReload and doUnlock). While that resource is active, its
current CS is a real segment. A callback proven to belong to the same resource
can be called with its stable offset and that CS, preserving its normal far
Pascal ABI and avoiding another kernel resource call. Do not overwrite the
stored virtual pointer or retain the reconstructed real pointer after return.
This substitution is unsafe for callbacks in a different resource.

Library/Audio/BSNWav/MP3Dec/mp3huff.c keeps table decoders and Huffman parsing together
in MP3HuffCode. core/pv_mp3_huffman.h:MP3_HUFF_CALL uses a Watcom pragma-aux
MOV AX,CS intrinsic. Tests/thunk.c exercises 1000 calls with a poisoned virtual
segment and checks pointer retention, return value and stack balance;
Tests/watcom.pl enables the same path for its EC/NC PCM comparisons.

Product integration can be checked without rebuilding the runtime tree: run
`gbuild Tools/build/product/bbxensem/pcbbx.build shipFiles=true syntaxtest=true
makeImages=false makeFloppyImages=false deleteDestTree=false` with explicit
`sourceDirs` and a temporary `desttree`; repeat with `ec=true` for EC geodes.
`Tools/build/build/build.pl` skips destination deletion in syntax mode, and
`filetree.pl`/`fileutil.pl` still resolve source files and report destinations.
Set `shipFiles=true` explicitly: without site defaults the tool can report
no errors while skipping the filetree entirely. Inspect its final error list;
its exit status alone does not establish that all artifacts were found.

## Assembly routines need code resources in protected mode

Do not put executable assembly routines in idata. Include/resource.def
defines idata with class DATA and groups it into dgroup. Tools/glue/geo.c
(GeoPrepare) gives dgroup RESF_FIXED without RESF_CODE. In protected mode,
Library/Kernel/Geodes/geodesLoad.asm converts loaded selectors to code only
when HAF_CODE is set; Loader32/gpmi.asm:GPMIConvertToCodeBlock sets the
executable descriptor type. A far call to a routine in ordinary dgroup
therefore faults at the call instruction before the routine runs.

Use a separate fixed, read-only, shared code resource for a nonlocal error
unwinder: a movable unwinder must not release its own active resource while
removing resource-call frames. Library/Breadbox/ImpGraph/impgraph.gp and
ASMIMP/asmimpManager.asm show the fixed ASM_FIXED code-resource pattern.

Glue GP files support ifdef, but the linker must receive the symbol through
-D; assembly definitions do not carry into the GP parser. The shared
Include/sun.geos.mk rules call Tools/scripts/perl/product_flags separately
for ESP and Glue. Both calls must return -DPROTECTED_MODE for matching
protected-mode guards. Evidence: Tools/glue/parse.y:HandleIFDEF and
Library/Breadbox/Ijgjpeg/ASMTOOLS/asmtoolsManager.asm / ijgjpeg.gp.

## Resource order and localization

Glue assigns resource IDs in Tools/glue/geo.c:GeoPrepare and normally sorts
resources by fixed/preload attributes (GeoCompareResources). GP resource
declaration order is used only with nosort; an appended declaration alone
does not guarantee an appended resource ID. Check the built .sym module
order with bin/printobj after adding resources.

GOC localization instructions describe chunks, not ordinary C string
literals. Place @localize after the chunk or inline UI field; @localize not
protects technical strings. Length limits are translator metadata and do not
resize a caller buffer. See TechDocs/Markdown/Concepts/clocal.md and
Tools/goc/parse.y:LocalizationLine. Generate .rsc records with goc -l to
check the target chunk, substitution instructions, and length limits.
