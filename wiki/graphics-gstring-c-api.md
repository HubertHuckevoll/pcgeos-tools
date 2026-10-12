# GString C API output parameters

The C wrappers for `GrDrawGString` and `GrDrawGStringAtCP` require a valid
`word *lastElement`, even when the caller ignores the result. Both load the
far pointer and store CX unconditionally after playback. Passing a null
pointer writes to 0000:0000 in real mode. Use a small local word and pass its
address. Evidence: `Library/Kernel/Graphics/graphicsGStringC.asm`,
`GRDRAWGSTRING` and `GRDRAWGSTRINGATCP` (around lines 44-60 and 81-94).

The Boolean returned by the C `GrGetGStringBounds` wrapper is TRUE when the
bounds fit word coordinates, FALSE on coordinate overflow. This differs
from the assembly routine's carry flag, which is set on overflow. Evidence:
`graphicsGStringC.asm:GRGETGSTRINGBOUNDS` (around lines 469-492) and
`Library/Kernel/Graphics/graphicsString.asm:GrGetGStringBounds`.

When playback reaches `GSRT_COMPLETE`, `graphicsString.asm:GStringCleanup`
resets the current position to the beginning. Other stopping conditions can
leave a different current position; use `GrSetGStringPos` when a full replay
must be guaranteed.
