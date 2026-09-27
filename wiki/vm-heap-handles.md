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
