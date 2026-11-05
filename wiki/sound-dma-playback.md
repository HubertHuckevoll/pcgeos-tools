# Sound DMA playback diagnostics

The BestSound drivers have separate legacy stream and NewWave playback
interrupt paths. In Driver/Sound/BSD16/bsint.asm,
SBDDACEndOfDMATransfer calls BSNWISR when bsStatus is BSNW_PLAY_RUN (4),
and otherwise falls back to BSDACISR after the recording check.

BS_FILL_REST alone does not identify a playback underrun.
Driver/Sound/BSD16/bswav.asm:BSSecondAlloc calls BSFillRest to clear a newly
allocated DMA buffer. BSDACISR also calls it when ending auto-init output
with an unfilled buffer. Check the caller to distinguish these cases.
The NewWave ISR clears completed buffer halves directly in
Driver/Sound/BSD16/bsnwav.asm:BSNWISR.

BSNWISR increments the byte bsRecDataFlag and toggles bsRecDataHalf.
BSDNWGetAIState returns the counter in CL and the half in CH. The counter
wraps; it is not a count of outstanding refills. BSNWav's PCM playback
loop compares successive snapshots and records detected late refills in
timeOutCounter (Library/Audio/BSNWav/PCM/pcm.goc:BSNWPlay). Counter differences
must use byte arithmetic so that 255 -> 0 is an ordinary interrupt.

BSDMAGrenzen in both drivers can shorten a DMA allocation to approximately
half its requested length when it crosses a physical 64 KiB boundary.
BSSecondAlloc passes the selected segment/length to ProgramDMADriver,
which stores the actual length in bufferLen; bufferO2 and DSP block size
are based on this actual length. Requested size alone therefore does not
establish the playback refill interval. Fixed-heap placement can change
the interval between allocations. BSNWDetermineSecondaryBufferLength
reserves two times the required usable size plus a paragraph to cover this
split. BSNWAllocSecBuffer rounds short sources up to a multiple of eight
so both DMA halves remain nonempty and frame-aligned.

bsRecDataFlag and bsRecDataHalf are consecutive bytes in bsrecord.asm.
BSDNWGetAIState reads them with one word load, guarded by a CheckHack for
their layout. Two separate loads would allow an IRQ between them to return
an old half with a new counter. The word load preserves the
counter-in-CL/half-in-CH interface.

BSNWPlay prepares each refill in one locked half-sized staging block, then
selects the DMA destination from a fresh interrupt snapshot. If an IRQ
crosses the final copy, it retains that refill and retries in the latest
free half. Source reads and decoding must not write directly into a DMA
half selected before a potentially blocking call. Per-half source-byte
counts keep underrun silence out of playedBytes and preserve partial EOF
drain, including channel-toggle prefixes and rate reduction. This recovery
can insert silence or repeat a partial refill; it is not a hard latency
guarantee. The driver still clears completed halves in interrupt context.

Both BSNWISR implementations clear with REP STOSW and use STOSB for an odd
last byte. SHR saves the odd-byte count in CF; REP STOSW preserves CF.
The outer SBDDACEndOfDMATransfer clears DF before calling BSNWISR. Complete
the clear before updating the counter/half state. BSD16 uses 0x8080 for
unsigned 8-bit PCM and zero for signed 16-bit PCM; BSD8ST uses 0x8080.
Bit 0 of bsOptions controls clearing in both drivers.

Do not enable CPU interrupts in this clear without handling IRQ re-entry.
Both bsint.asm handlers use one private ISR stack and one CS-relative
oldSS/oldSP pair, and acknowledge the PIC before calling BSNWISR. A nested
sound IRQ can overwrite that saved state. SysEnterInterrupt prevents thread
switches; it is not an interrupt mask (Kernel/Sys/sysInterrupt.asm).
Library/Audio/BSNWav/Tests/isr.pl tests the actual ISR instruction bodies in
standalone DOS, including odd lengths, guard bytes, clear options, and
counter wrap. It does not start PC/GEOS or measure audio latency.

BSNMP3DecOpenEx in Library/Audio/BSNWav/MP3Dec/mp3reader.goc sets the
optional BSN_MP3_HALF_RATE flag before probing the first frame. Existing
BSNMP3DecOpen selects normal output. The option belongs to the private
decoder context and survives Mp3DecReset. MPEG-1 output uses half the PCM
rate and sample count; MPEG-2/2.5 output stays unchanged. The core limits
IMDCT bands and computes only even synthesis-window positions while keeping
all time slots and history (pvmp3_framedecoder.inc,
pvmp3_poly_phase_synthesis.inc, and mp3decManager.asm). Source-rate tracking
is separate from output rate so format changes remain visible. The public
BSNMP3Dec layout and old export ordinals stay unchanged. Tests/half.pl
checks filtering, duration, pitch, stereo order, reset, and partial reads.

MP3Dec/Tests/profile.pl measures decoder stages in standalone DOS and writes
per-frame timing/work counts to frames.csv. Use MP3_ASM_OBJECT with the
production DSP object extracted by MP3Dec/Tests/watcom.pl (MP3_ASM=1) to
measure the assembler path. TOTAL_ONLY=1 removes the stage clocks to check
their overhead. DOS clock values are coarse; average many frames rather
than treating each row as a precise latency measurement. Source reads,
PCM writes, and CSV writes are outside the measured decoder call. GEOS
heap/resource waits and driver work are absent, so this test cannot certify
the timing of complete GEOS playback. Both profiler modes compare the
native PCM with the uninstrumented host core.

Swat normally installs automatic breakpoints on WarningNotice and
CWARNINGNOTICE (Tools/swat/lib.new/swat.tcl:_check_fatal_error).
The why-warning handler prints the warning and returns 0 to resume
(Tools/swat/lib.new/fatalerr.tcl). Thus an automatically continued warning
still involves a debugger stop. Measure audio deadlines with memory
counters and report after DMA stops, rather than warning on each refill.
