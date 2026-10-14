# GEOS library definition files during builds

A new library geode's normal build creates its `.ldf` in its own `Installed/` build directory. Dependent geodes look for library definitions in `Installed/Include/`. After building the library, run `pmake lib` in its Installed build directory to copy the `.ldf` there before building dependents. `CInclude/geode.mk` defines `LIBOBJ`, `LIB_DEST`, and the `lib` target that performs the copy (around lines 176-221). `pcgeos-tools/aihelp.py` builds EC and NC with plain `pmake` (functions `build_once` and `cmd_build`), so its successful build alone does not run that copy target.

The top-level `Installed/Makefile` is a hand-maintained product build graph, unlike the mkmf-generated Makefiles in `Installed/` module subdirectories. Its `MAKELIB` rule runs `pmake full lib` for dependencies, so a new library must have a named target and must be included in the dependency list of each consumer. The product file tree only selects geodes to copy into the assembled runtime; it does not build missing dependencies. See `Installed/Makefile` (`MAKELIB`, `impgraph`, `graphvwr`) and `Tools/build/product/bbxensem/bbxensem.filetree` (ImpGraph and SvgLib entries).

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
