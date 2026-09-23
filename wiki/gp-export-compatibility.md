# GP export compatibility

`export` and `publish` directives form an ordered entry-point ABI. Glue gives
each exported symbol the current `numEPs` value and then increments it; a
`skip` reserves one or more of those slots. Do not reorder or reuse these
directives in a released library or driver GP file.

For a compatible post-release public API addition, put `incminor [name]`
before the appended export/publish tranche. It increments the geode minor
protocol and makes clients that use a following entry point require that newer
minor level. Consecutive additions may intentionally share one unreleased
tranche, so inspect the GP and REV history rather than adding `incminor`
automatically. Reordered old entry points require a major protocol decision.

Evidence: `Tools/glue/library.c`, `Library_ExportAs` assigns
`lsym->u.addrSym.address = numEPs++` around lines 582-597;
`Library_Skip` reserves export-table entries around lines 1344-1370; and
`Library_IncMinor` records a new minor level and increments the geode header
at lines 1926-2012. `TechDocs/html/LRef/GPKey/index.htm` documents `incminor`
at lines 243-268, and `TechDocs/html/Kernel/Geodes/Geodes_9.htm` explains that
relocated entry points need a major protocol change at lines 95-113.

For a newly built library, run `pmake lib` in its `Installed/Library/...`
directory after building it. The default build can leave its `.ldf` only in
that directory; `pmake lib` copies it to `Installed/Include`, where dependent
geodes find it. Evidence: the `LIBOBJ` and `lib` rules in
`CInclude/geode.mk` around lines 178-221; `aihelp.py`'s `build_once` runs the
default `pmake` target in `~/pcgeos-tools/aihelp.py`.
