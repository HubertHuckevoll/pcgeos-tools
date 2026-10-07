# GEOS library definition files during builds

A new library geode's normal build creates its `.ldf` in its own `Installed/` build directory. Dependent geodes look for library definitions in `Installed/Include/`. After building the library, run `pmake lib` in its Installed build directory to copy the `.ldf` there before building dependents. `CInclude/geode.mk` defines `LIBOBJ`, `LIB_DEST`, and the `lib` target that performs the copy (around lines 176-221). `pcgeos-tools/aihelp.py` builds EC and NC with plain `pmake` (functions `build_once` and `cmd_build`), so its successful build alone does not run that copy target.

The top-level `Installed/Makefile` is a hand-maintained product build graph, unlike the mkmf-generated Makefiles in `Installed/` module subdirectories. Its `MAKELIB` rule runs `pmake full lib` for dependencies, so a new library must have a named target and must be included in the dependency list of each consumer. The product file tree only selects geodes to copy into the assembled runtime; it does not build missing dependencies. See `Installed/Makefile` (`MAKELIB`, `impgraph`, `graphvwr`) and `Tools/build/product/bbxensem/bbxensem.filetree` (ImpGraph and SvgLib entries).

Overriding `PRODUCTS` on the pmake command line does not add the product's dependency-file include to an existing generated Makefile. If that include is missing, assembler targets can invoke ESP without a manager source in `.ALLSRC`. Regenerate the Makefile with `mkmf` so it includes the discovered products' dependency files; regenerate dependencies with `pmake depend` when absent or stale. Evidence: `Tools/nmkmf/mkmf.c:MkmfPrintPRODUCTS` and product dependency includes around lines 2587-2597; `Include/sun.geos.mk:ASSEMBLE` selects `$(.ALLSRC:M*Manager.asm)`.

Glue's file-local Watcom lookup compares an OMF local external's object name
with the containing segment's `SegDesc.file`. When several objects share a
public code segment, that field belongs to the first contributing object.
A later object's static function can therefore fail with `undefined2` even
though its body is present. Put the object owning the static helper first
among that segment's contributors, rather than changing helper visibility.
Order `OBJS`, `EOBJS` and `GOBJS` consistently in source `local.mk` because
`EOBJS` and `GOBJS` are already expanded by `geos.mk`.
Evidence: `Tools/glue/pass2ms.c` (`MO_LEXTDEF`),
`Tools/glue/sym.c:Sym_FindWithSegmentAndFile`,
`Tools/glue/segment.c:Seg_AddSegment`,
`Tools/glue/msobj.c:MSObjMapExternal`, and BbxBrow `local.mk`.
`Library/WebpLib/local.mk` also arranges C before ESP for this diagnostic.
