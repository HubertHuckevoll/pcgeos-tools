# BestSound playback stutter: static analysis

Implementation update, 2026-11-04: BSNWav now reserves sufficient requested
space for the driver's possible DMA boundary split. Both driver getters
read the counter/half with one word load. Refills are staged outside DMA
memory, copied using a fresh state snapshot, and retained for retry if an
interrupt crosses the copy. Per-half source-byte counts handle missed
notifications and final drain. The findings below describe the code before
these changes. The interrupt-off clears now use REP STOSW with an odd-byte
tail, and BSD16's clear-option test is corrected. Clearing remains in the
ISR; its private stack does not support nested sound IRQs. Possible
resource/heap waits remain. Recovery can insert silence or repeat a partial refill after a
missed deadline. It does not provide hard real-time scheduling.

Scope: BSNWav PCM playback and BSD16/BSD8ST. Both WAV and MP3 stutter on
Basebox, and the fault predates the audio refactor. This analysis does not
claim that a particular fault occurred in an observed playback session.
The initial analysis used no PC/GEOS execution, Swat session, or
production-code change.

## Can GEOS play continuously?

Yes. DMA supplies samples independently of thread scheduling. Continuous
playback requires the producer to refill buffers before DMA consumes them.
The native sample-stream API also exists for this purpose; see
TechDocs/Markdown/Concepts/csound.md, section 13.8, and
Driver/Sound/SoundBlaster/soundblasterInt.asm:updateStream.

This implementation gives no hard upper bound for refill latency. High
thread priority cannot bound synchronous file I/O, resource reloads,
heap waits, interrupt-off sections elsewhere, or host-emulator scheduling.
The current Bsqp playback thread already uses PRIORITY_HIGH
(Appl/Audio/Bsqp/Main/subcode.goc, ThreadCreate call).

## 1. Heap address changes the usable DMA size

This is the strongest direct match for different behavior between runs.

Driver/Sound/BSD16/bswav.asm:BSSecondAlloc allocates a fixed block, then
calls BSDMAGrenzen. If the physical allocation crosses a 64 KiB boundary,
BSDMAGrenzen keeps one side and discards the other from the usable buffer.
It can reduce the usable length to approximately half the request.
ProgramDMADriver records the resulting length in bufferLen; bufferO2 and
the DSP interrupt interval are calculated from that reduced length.
BSD8ST contains the same boundary-selection policy.

Library/Audio/BSNWav/PCM/pcm.goc:BSNWDetermineSecondaryBufferLength requests
at least two timer ticks per half. BSNWPrepare accepts the driver's reduced
length without checking that this timing margin still holds.

For 44,100 Hz, 16-bit stereo with the default settings:

- The request is 11,760 bytes, or 33.333 ms per half.
- At physical low-16-bit address 0xe910, 5,872 bytes fit before the boundary
  and 5,888 after it. The rear-side branch skips another 16 bytes.
- The returned length is 5,872 bytes, or 16.644 ms per half.
- BSNWPlay polls using TimerSleep(1), nominally 16.667 ms, before accounting
  for source reading, decoding, copying, and scheduling delays.

A host-side arithmetic enumeration of all 4,096 paragraph offsets confirmed
that 5,872 is the minimum returned size for this request. An 8,192-byte
request can become 4,096 bytes. These are calculations of the source's
algorithm, not measurements of actual allocations or uniform probabilities.

The buffer address is fixed for one playback. Different fixed-heap placement
can therefore give a smooth session followed by a consistently bad session.
The stricter 64 KiB split is also applied to BSD16's word-DMA path, although
Driver/DMA/DOSReal/dosrealDMA.asm:adjustATPageOffset handles 128 KiB word-DMA
windows. Any correction must retain the actual DMA boundary constraints.

## 2. Interrupt-state reads can return a mixed snapshot

BSDNWGetAIState reads bsRecDataHalf into CH, then bsRecDataFlag into CL,
without excluding an interrupt between the two instructions. This exists
in both drivers. SoundStrategy does not protect these reads.

Example: the driver has half=0 and counter=6. The getter reads half=0.
An interrupt changes the counter to 7 and half to 1. The getter then reads
counter=7 and returns 0x0007 rather than the actual state 0x0107.

BSNWPlay uses the returned half to choose its destination. It can write the
half DMA is currently playing. A subsequent poll can return 0x0107 without
another interrupt. Since the loop compares the entire word, it treats that
correction as another completed half and consumes additional source data.

The fields are consecutive bytes in bsrecord.asm, flag first and half
second. One word load can obtain a coherent snapshot on the current x86
interrupt model; a layout assertion should preserve that relationship.
This is a definite race, but its frequency on Basebox is unmeasured.

## 3. Late refill recovery is incomplete

BSNWPlay detects skipped notification-counter values but always advances
playedBytes by one half and adds only one half to secondFree. It does not
recover the number of elapsed halves or restart/re-prime DMA.

An existing delay can therefore cause additional gaps, incorrect position
accounting, and repeated refill failures. Simply multiplying the half size
by the missed count is unsafe: DMA has already consumed some slots. Recovery
must respect which half is currently safe to write.

The loop also selects its destination before BSNWLoadData performs source
reads and conversion. It does not recheck whether that destination is still
safe after a blocking source read. A coherent initial snapshot alone does
not solve this deadline problem.

## 4. The interrupt handler performs a full clear with interrupts off

BSD16/bsint.asm:SBDDACEndOfDMATransfer disables interrupts. Its NewWave path
calls BSNWISR, which clears every byte of the completed half in a scalar
loop before publishing the counter/half change. BSD8ST does the same work.

This delays other interrupts and adds fixed cost to each refill interval.
The actual duration needs measurement; the source alone cannot establish
that it exceeds a deadline.

BSD16 also uses OR rather than TEST for the clear option, so the clear
cannot be disabled through that option. Current playback explicitly requests
clearing, so this separate defect does not explain the observed variation.
Removing clearing outright would risk repeating stale audio on underrun.

## 5. Heap pressure can delay the producer, but does not move active DMA

The DMA buffer and private ISR stack are fixed. The PCM cache is locked
from allocation to playback cleanup. PCMCode remains active for the whole
playback call, so it remains locked too. There is no evidence here that
normal compaction moves those active buffers.

Other resources are unlocked between uses: the driver's LoadableCode
contains BSDNWGetAIState; BSNWav's ASMTOOLS_TEXT trampoline and WAVCode
reader are movable. MP3's decoder resources and buffers are also unlocked
between uses. BSNWavePlayFile keeps AudioMainCode locked through its call;
that protection does not pin all of these other resources.

Kernel ResourceCallInt uses a resident fast-lock path when possible. When
a resource is moving, swapped, or discarded, it can enter FullLockNoReload
or LockDiscardedResource. Those paths can wait for the heap, swap data in,
allocate, or reload code from the geode file. See
Library/Kernel/Geodes/geodesResource.asm:ResourceCallInt,
Library/Kernel/Heap/heapLow.asm:FullLockNoReload/FullLockReload, and
Library/Audio/BSNWav/MP3Dec/mp3api.c:Mp3DecReadPCM.

CompactHeap explicitly enables interrupts during much of its traversal and
movement (Library/Kernel/Heap/heapCore.asm:CompactHeap). Thus heap pressure
can stall a producer without stopping DMA interrupts. A blanket claim that
compaction disables interrupts for its whole duration is incorrect.

BSNWLoadData also fills all available source-cache space before copying
cached data to DMA. This puts synchronous file reads or MP3 decoding before
the urgent output write, even when some useful PCM is already cached.

## Recommended correction order

1. Preserve the minimum usable DMA duration after boundary handling.
   Use an existing platform allocation/alignment mechanism if suitable.
2. Make the state snapshot coherent in both drivers.
3. Define explicit recovery for missed refill deadlines, including when a
   blocking reader returns after its chosen half becomes active.
4. Reduce interrupt-off work while retaining correct underrun silence.
5. Keep the required refill working set resident during playback, rather
   than marking the whole decoder permanently fixed.

Use small host checks for boundary addresses and interrupt interleavings.
The existing Tests/pcm.c mock advances one DMA half on each state read and
does not model a real interrupt between getter reads or during a refill.
Its current success cannot exclude these timing faults.
