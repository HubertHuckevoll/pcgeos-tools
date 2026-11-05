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

Decoder support and playback support are separate. PCM/pcm.goc:BSNPcmPlay
rejects sample rates <= 5000 or >= 44200 with BSNW_UNKNOWN_WAVE_FORMAT,
before the driver check. Thus a valid 48 kHz MP3 can open in the reader but
fail playback validation; BSN_MP3_HALF_RATE gives MPEG-1 48 kHz input a
24 kHz output. This result alone does not establish that a file is damaged.

MP3 tag skipping is not tag extraction. MP3Dec/mp3api.c:Mp3DecodeFrame
validates the leading ID3v2 header and skips its declared payload; it does
not return title or artist fields. The public BSNMP3Dec structure and
Open/Read/Close API in CInclude/bsnwav.h expose PCM source state and playback
diagnostics, not display metadata. Applications that need tag labels need
a separate reader.

Main/subcode.goc:BSNWPrepKS uses an integer sample reduction rounded up
to fit the driver's maximum rate, then programs sourceRate/reduction.
Programming the maximum rate instead would change pitch and duration when
the rates are not an integer multiple. Driver/Sound/BSD16/bsrecord.asm
defines BSD_MAX_RATE as 44100; BSD8ST/bsrecord.asm defines it as 22050.

MP3Dec/mp3reader.goc:BSNMP3Read preserves BSNW_FORMAT_CHANGED,
BSNW_TRUNCATED, BSNW_INVALID_DATA, and BSNW_READ_ERROR. An MP3DEC_TRUNCATED
result can also mean an invalid short suffix or non-audio input, so it does
not prove that the input is an incomplete valid MP3. BSNMP3DecOpenEx
separately preserves allocation failure as BSNW_MEMORY_ERROR. During
playback, PCM/pcm.goc:BSNWLoadCache maps the reader's BSN_PCM_READ_ERROR to
BSNW_SOURCE_ERROR; the caller must inspect BSNMP3Dec.status before closing
to retain the specific diagnosis. CInclude/bsnwav.h defines the result codes.

For application error text, UserStandardDialog builds, runs, and destroys
a standard dialog; CDT_ERROR with GIT_NOTIFICATION supplies an error icon
and an OK response. UserStandardDialogOptr accepts resource-chunk strings.
No custom dialog object is required. See CInclude/uDialog.h,
TechDocs/Markdown/Objects/ogenint.md section 7.4.5.2, and
Library/User/User/userDialog.asm:USERSTANDARDDIALOG. UserDoDialog supports
threads without an event queue through a semaphore, but the caller waits
for the response; application cleanup must account for that wait.

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
