# VM block memory handles in heap crashes

In the VMLock fast path, the VM block's `VMBH_memHandle` is passed to
`MemThreadGrab` when the block is resident. `FullLockNoReload` then calls
`CheckHeapHandleSW` in EC builds. A `CORRUPTED_HEAP` stop in that call chain
identifies a rejected memory handle; the later text or application frame only
identifies the caller that tried to lock the VM block. Evidence:
`Library/Kernel/VMem/vmemHigh.asm` (`VMLock`),
`Library/Kernel/Heap/heapLow.asm` (`FullLockNoReload`), and
`Library/Kernel/Heap/heapErrorCheck.asm` (`CheckHeapHandleSW`,
`CheckHeapHandle`).

The high byte of `HandleGen.HG_type` holds the handle signature.
`SIG_FREE` is `0xf3`, so an `HM_addr` value of `0xf300` means the handle is
free and must not be used as a resident VM memory handle. The address and
size fields printed by treating such a handle as `HandleMem` are not valid
heap-block metadata. Evidence: `Include/Internal/heapInt.def`
(`HandleType`, `HandleGen`, `HandleMem`).

The normal VM discard path clears `VMBH_memHandle` before freeing its memory
handle. A nonzero `VMBH_memHandle` that names a `SIG_FREE` handle therefore
requires tracing the earlier free or overwrite; the failing VMLock alone
does not identify it. Evidence: `Library/Kernel/VMem/vmemLow.asm`
(`VMDiscardMemBlk`) and `Library/Kernel/VMem/vmemKernelHigh.asm`
(`VMUpdateAndRidBlk`).

A bitmap redraw can allocate VM metadata even after import has finished.
The nonresident-block path in `VMLock` enforces the resident-handle limit,
temporarily adds two to `VMH_numExtraUnassigned`, then calls
`VMMaintainExtraBlkHans` before `VMReadBlk`
(`Library/Kernel/VMem/vmemHigh.asm`). The latter reserves
`2 * VMH_numResident + VMH_numExtraUnassigned + 1` unassigned VM block-table
entries; any shortfall goes to `VMExtendBlkTable`, which grows the VM
header with `MemReAlloc(HAF_NO_ERR | HAF_ZERO_INIT)`
(`vmemBlkManip.asm`). An allocation-retry stack at that call identifies
header growth, not allocation of new image content. Unassigned VM entries
are metadata within the header, distinct from global heap handles.

`VMBlockHandle` values are offsets into a VM file's header block table
(`Library/Kernel/VMem/vmemConstant.def`: `VMHeader`, `VMBlockHandle`). A Swat
argument rendered as `vmBlk = ^h.... (invalid)` by treating it as a global
heap handle is not by itself evidence of an invalid VM block.
