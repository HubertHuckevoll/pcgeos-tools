# Swat source-line breakpoints

`stop at file:line` parses the colon form correctly in
`Tools/swat/lib.new/ibrk.tcl`; failures with a bare GOC filename originate in
`src addr`. Watcom GOC objects carry the original `.goc` name in a special OMF
comment emitted by `Tools/goc/parse.c`, and current builds pass an absolute
source path. `Tools/glue/pass1ms.c` renames the source map from the generated
`.nc` name to that absolute `.goc` name.

On Linux, `Src_FindLine()` in `Tools/swat/src.c` uses exact string-table lookup.
It can fall back from a supplied path to its basename, but it cannot resolve a
supplied basename to an absolute source-map entry. Therefore
`stop at name.goc:line` fails while `stop at /absolute/path/name.goc:line` can
resolve. `stop at line` also avoids this name mismatch when the current frame
has source information, because `src line` supplies the recorded filename.

There is a separate latent Watcom defect: `Pass1MSReplaceFileName()` starts at
`sd->lineT` and processes only that block, so earlier 8 KB line blocks retain
the generated `.nc` filename. Current Installed GOC objects have fewer than
1,000 line records in any one segment and do not trigger this multi-block case.

Evidence: `Tools/swat/lib.new/ibrk.tcl` (`stop`), `Tools/swat/src.c`
(`Src_FindLine`, `SRC_ADDR`), `Tools/goc/parse.c` (Watcom `#pragma
comment(lib, "@...")`), `Tools/glue/pass1ms.c` (`Pass1MS_ProcessObject`,
`Pass1MSReplaceFileName`), and `Tools/glue/main.c`
(`RenameFileSrcMapEntry`).
