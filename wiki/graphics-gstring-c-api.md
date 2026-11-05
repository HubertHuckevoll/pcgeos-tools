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

## Icon and text button monikers

A GenTrigger moniker list with a text moniker and an icon GString can use
HINT_USE_ICON_TEXT_COMBINATION_MONIKER = {0, spacing} to place the icon left
of the text. GenFindMoniker honors this hint when VMSF_REPLACE_LIST and
VMSF_GSTRING are set; ReplaceMonikerListWithIconTextMoniker calls
UserCreateIconTextMoniker. Evidence: Library/User/Gen/genUtils.asm.

Dynamic MSG_GEN_REPLACE_VIS_MONIKER_OPTR updates take a different path:
GenReplaceVisMoniker -> UpdateMoniker -> MSG_SPEC_RESOLVE_MONIKER_LIST.
The default VisSpecResolveMonikerList calls VisFindMoniker directly and
therefore bypasses the combination hint. A trigger subclass can resolve
its current list with MSG_GEN_FIND_MONIKER(FALSE, VMSF_REPLACE_LIST |
VMSF_GSTRING | (VMS_ICON << VMSF_STYLE_OFFSET), 0) to preserve icon and text.
Evidence: Library/User/Gen/genClassCommon.asm, Library/User/Vis/visSpec.asm,
and Appl/Audio/Bsqp/UI/uimain.goc:BQPlayTriggerClass.

Keep reusable moniker lists, labels and icons that are copied across threads
in a shared read-only plain LMem data resource, not a ui-object resource.
ProcessCopyChunkOver locks both source and destination with ObjLockObjBlock;
ObjLockObjBlock checks ownership for LMEM_TYPE_OBJ_BLOCK but permits plain
LMem heaps on either thread. VisFindMoniker's replacement path sends the
copy to the current thread, so a source object block owned by another
thread causes OBJ_LOCK_OBJ_BLOCK_BY_WRONG_THREAD. The writable combined
moniker belongs in the target button's own object block.
Evidence: Library/User/Vis/visUtilsClass.asm:VisFindMoniker,
Library/Kernel/Object/objectProcess.asm:ProcessCopyChunkOver and
Library/Kernel/Object/objectClass.asm:ObjLockObjBlock.

UserCreateIconTextMoniker positions the icon with a MoveTo before playing
its GString. Use bitmap operations at the current position rather than
absolute shape coordinates. GSFillBitmapAtCP with BMF_MONO draws set bits
in the current area color and leaves clear bits transparent.
Evidence: Library/User/User/userUtils.asm:UserCreateIconTextMoniker
(drawText), TechDocs/Markdown/Concepts/cshapes.md (bitmap drawing).
