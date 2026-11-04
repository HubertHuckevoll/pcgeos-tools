# Unified BSNWav implementation

## Optional reduced-rate MP3 output

Bsqp has an Options checkbox, Reduce MP3 Quality (Lower CPU Use). It is off
by default. Save Options stores bit 0x0008 in the existing QuickPlayer/options
integer. The setting applies when playback starts again. WAV files are not
affected.

BSNMP3DecOpenEx takes the existing context and borrowed file handle, plus
an options word. BSN_MP3_HALF_RATE selects reduced-rate output. Zero selects
normal output. Unknown option bits return BSNW_SOURCE_ERROR. The existing
BSNMP3DecOpen calls OpenEx with zero, so existing callers retain normal
output. The new export is appended under a new minor protocol; existing
export ordinals and the public BSNMP3Dec layout are unchanged.

The option is set before the first decoded frame is retained by the open
probe. It belongs to the decoder context and survives decoder reset and
error recovery. It cannot change during playback. Separate contexts can
use different modes. A change in the encoded source rate is still reported
as a format change, even if the two effective output rates would be equal.

The mode applies to MPEG-1 input rates:

- 32,000 Hz becomes 16,000 Hz.
- 44,100 Hz becomes 22,050 Hz.
- 48,000 Hz becomes 24,000 Hz.

Lower-rate MPEG-2 and MPEG-2.5 files retain their original output rate.
Channel count and signed 16-bit PCM remain unchanged. Each affected MPEG
frame returns half as many PCM frames at half the rate, preserving duration
and pitch. The source format and playback counters describe these actual
PCM bytes. Existing encoder-delay and padding behavior is unchanged.

The decoder retains the lowest 15 of 32 synthesis subbands. The next band
is a guard below the new Nyquist limit. Upper IMDCT bands keep zero overlap
from stream initialization. The synthesis window calculates only even
output positions, but all time slots and the circular history still advance.
This is filtering and reduced synthesis, not removal of alternate samples
after a full PCM decode. Huffman decoding and dequantization remain intact.
The option adds no memory handles or large tables.

High-frequency detail is reduced. The guard band makes the transition
start below 11 kHz for 44.1 kHz input. This option does not guarantee that
decoding will meet every playback deadline.

MP3Dec/Tests/half.pl compares reduced-rate output with every second PCM frame of
a filtered full-rate reference, checks partial reads, EOF, reset, independent
contexts, invalid options, and source-rate changes, and tests tone level,
pitch, stereo order, and suppression of frequencies above Nyquist. It takes
the micro-mp3 corpus path and optional extra MP3 files. FFmpeg is used only
to generate and inspect test inputs.

MP3Dec/Tests/watcom.pl accepts HALF_RATE=1 and MP3_ASM=1 to compare actual
ESP DSP output with the C reference in standalone DOS. Tests/profile.pl
also accepts HALF_RATE=1. With TOTAL_ONLY=1 and the extracted production
DSP object, dudu.mp3 took 89.803 seconds of measured decoder time instead
of 103.590 seconds in normal mode at the same controlled 15,000-cycle
Basebox setting. This is about 13% less decoder time, not a GEOS playback
latency measurement. These tests do not run PC/GEOS.

## Baseline (2026-10-29)

Implementation branch BSNAudio-unified starts at PCM-source-v2 commit
1d4ea7818cb95294145e65410d462d4fe27ccc90. The decoder import is pinned to
micromp3 commit c230523694bf8d84f86fa86c911974305b99ec28. Neither source
branch nor master is modified.

The PCM baseline fails EC and NC linking: BSNWPlay calls the undefined
BSNWStartPlay. The prerequisite fix calls the already declared and implemented
BSNWAsmStartPlay in ASMTOOLS/asmtoolsManager.asm. No driver or DMA changes.
After this fix aihelp.py build Library/Audio/BSNWav succeeds in EC and NC.
Existing warnings concern unused variables/parameters and unprototyped
ProcCallFixedOrMovable_pascal calls.

Baseline linker resource sizes (bytes, EC then NC):

- dgroup: 272 / 272, fixed; uninitialized data/stack: 152 / 152.
- udata: 4 / 4; ASMTOOLS_TEXT: 380 / 380.
- bsnwav_TEXT: 3404 / 2016; subcode_TEXT: 6777 / 3946.
- MONIKERRESOURCE: 1104 / 1104.

MP3Dec and MP3Wav both build with aihelp.py in EC and NC. The decoder's NC
linked resources contain fixed dgroup (10176 bytes) and MP3MathCode (67),
and movable shared code for MP3DspCode (10970), MP3FrameCode (10796),
MP3HuffCode (5359), MP3ImdctCode (237), MP3SynthCode (1238),
MP3QuantCode (2775), MP3SterCode (7342), and mp3api_TEXT (2601).
The existing decoder allocates three movable blocks per instance (context,
2048-byte compressed input, 4608-byte PCM); actual GEOS live handle counts
have not been measured.

The pinned upstream micro-mp3 checkout is
07c18fa2d045b89bcc19aa0c1dc5333ce69b39db. Existing host checks pass all
eight upstream inputs, including six feed sizes, byte-exact reference core
and WAV conversion, relocation, allocation failure, reset and malformed input.
Standalone Watcom DOS checks pass all eight inputs with EC/NC flags and the
actual linked ESP DSP resources, plus DSP regression, live-CS Huffman dispatch
and 6486 fixed-point products. This does not run PC/GEOS.

Reproduction and retained logs are under ~/pcgeos-tools/bsnaudio/. Tests use
TMPDIR=~/pcgeos-tools/bsnaudio/tmp and KEEP_TESTS=1. The baseline snapshot is
an archive of only the decoder, converter and headers, not a branch merge.

mkmf discovers source modules in Library/Audio/BSNWav and generates the
Installed module Makefile; aihelp.py builds in Installed. pmake lib publishes
the library definition to Installed/Include. The hand-maintained top-level
Installed/Makefile has the bsnwav target and Wav, MixLib, Bsqp and SndChk
consumer dependencies. Subdirectory Makefiles and dependencies are generated.

## Common source contract

CInclude/bsnwav.h defines format-independent BSNPcmFormat and BSNPcmSource.
The far Pascal reader returns complete PCM frames, zero at EOF and 0xffff
on error. Short positive reads are valid. The descriptor and opaque context
remain valid and locked throughout blocking playback; decoder-owned movable
state is referenced through handles inside that context. Callback pointers
are GEOS virtual code pointers and require ProcCallFixedOrMovable_pascal
with callback arguments first and the code pointer last.

BSNPcmPlay is appended after the existing exports with incminor. The geode
remains bsnwav.lib and retains its token. The PCM module now consumes that format and calls only the reader callback;
legacy file/callback entry points adapt their inputs outside PCM. Callback
invocation uses a typed Pascal trampoline with the code pointer last.

Run the PCM regression with:

    TMPDIR=~/pcgeos-tools/bsnaudio/tmp perl Library/Audio/BSNWav/Tests/check.pl

It compiles the actual cache, conversion and playback loop routines against
a synchronous DMA/GEOS host shim. Checks cover short reads, known/unknown
lengths, early EOF, buffered tail draining, source errors after playback starts,
invalid byte counts/frame alignment, and rate-reduction chunk independence.
The existing conversion and DMA implementations are retained; cache filling
now combines short reads before conversion, the cache boundary aligns with
reduction groups, and final reduction skips cannot underflow cacheFull.
An error from a refill is preserved instead of being overwritten by drain
accounting. EC and NC builds pass after this extraction.

The full pinned minimp3 corpus also passes the original decoder checks:
32 inputs through actual EC/NC ESP resources and all host core/streaming
comparisons, including the trusted PCM accuracy gates.

## Unverified runtime behavior

PC/GEOS was not started, as required by AGENTS.md. Audible playback, DMA
underruns, movable resource reloads, live handle counts and peak playback
stack use require later manual testing. Compilation and standalone DOS
checks do not establish those results.

## WAV reader

BSNWavOpen, BSNWavReadPCM and BSNWavClose operate on a caller-owned BSNWav
context without allocating handles or requiring playback. Open validates the
RIFF extent, chunk sizes/padding and PCM format, supports data before fmt,
and selects the first data chunk. Reads return only complete frames within
that chunk; a truncated read is an error. Close leaves the borrowed file open.
The reader accepts native PCM rates independently of hardware. Playback
explicitly rejects rates outside the existing 5001..44199 Hz setup range,
including 48 kHz, rather than playing at an incorrect rate.

BSNWavePlayFile adapts the reader to the common PCM engine. TEST_ONLY and
GetLastFormat retain format/length reporting, PLAY_POS seeks within the data
region with bounded arithmetic, and playback uses the existing single-active
session. Invalid container headers retain the legacy memory-error result;
unsupported PCM returns unknown-format. The separate Library/Wav is unchanged.
The host regression additionally compiles the actual WAV reader and checks
8/16-bit mono/stereo, empty/short data, odd chunk padding, chunk order,
every file truncation, malformed sizes/formats, read failures and borrowed
file ownership. EC and NC builds pass.

## Decoder transplant

MP3Dec is compiled directly into bsnwav.lib, with no mp3dec library import.
The pinned implementation, core, Apache LICENSE/NOTICE and regression suite
are preserved. Only private-header lookup, API code-resource placement and
test paths change; mkmf requires mp3dsp.asm to be named mp3decManager.asm in
its source module. The instruction bytes are unchanged. dgroup is fixed and
writable because it also contains mutable playback globals; the immutable
MP3 tables remain directly addressable. The 386 kernel-register requirement
is retained explicitly; no kernel configuration is changed.

The original MP3Wav sources are imported to retain conversion regressions;
their GEOS client migration to the combined pull interface follows separately.
The decoder's feed API/header is private to MP3Dec and is not exported by the
combined library. EC and NC combined-library builds pass.

## Pull-based MP3 reader

BSNMP3DecOpen, BSNMP3DecReadPCM and BSNMP3DecClose expose the same source
contract as WAV. Open probes with zero output capacity, retaining the first
PCM frame inside the existing decoder block. Read drains pending PCM and
performs file I/O only on NEED_INPUT. It reads directly into the decoder's
locked compressed-input block, bounded by its free capacity: all read bytes
are accepted, and no unaccepted suffix or additional buffer is possible.
The reader still owns only the decoder's original three handles. Close
releases these blocks and leaves the borrowed file open.

PCM accompanying RECOVERABLE is returned; other recoveries continue with an
explicit 64-recovery-per-call limit. Long damaged regions beyond that ceiling
need an incremental recovery API. The context's damaged flag lets strict
converters reject concealment/recovery while ordinary playback can proceed.
Fatal/truncated input and file errors return the PCM error sentinel and latch
status. Midstream format changes latch unknown-format and are rejected before
returning new-format PCM. EOF follows pending PCM drainage.

The pull checks compare all eight upstream files byte-for-byte with the
original core for compressed read chunks of 1, 3, 7, 127 and 2048 bytes and
511-byte PCM capacities. They also verify retained probing output, tiny output
capacity, interleaved instances, relocation on every unlock, all three initial
allocation failures, borrowed files, repeated close, file-read failures,
truncated final frames and format-change rejection. Both GEOS builds pass.

## Final source and resource organization

Library/Audio/BSNWav contains Main (library/legacy adapters), PCM, WAV,
MP3Dec and Driver. The permanent name and library definition remain bsnwav.
The top-level Installed/Makefile is a hand-maintained product graph; its
bsnwav target points at BSNWav. Module Makefiles/dependencies are
regenerated with mkmf and pmake depend.

mkmf derives GEODE=bsnwav from the BSNWav directory name. The matching
bsnwav.rev is read by the normal build rules; local.mk needs no geode or
revision overrides. Base protocol 1.6 is retained (the original GP export
tranche adds one minor, the new appended tranche adds another). Existing
export positions are retained. The public PCM/reader header is bsnwav.h;
bsnwav.goh supplies the legacy GOC declarations.

The compiled-out reference multiplier remains in the source and host/DOS
checks but is excluded from GEOS objects. Its empty Watcom CodeView type
stream triggers an existing glue parser error with the new module order.
The assembly math helper is still linked. The private legacy callback adapter
uses a global internal symbol because this glue cannot resolve a static
callback address when its merged resource's first contributor is another
object; no extra GP export is added.

The linked NC map confirms writable fixed dgroup (10432 bytes), fixed math
(67), and movable shared PCMCode (2801), WAVCode (1058), MP3ReaderCode (806)
and the original decoder resources. Every segment remains below 64 KB.
Only geos and ansic are imported; no ui or mp3dec import is introduced.

## MP3Wav migration

MP3Wav imports bsnwav protocol 1.8 and uses only the public bsnwav.h
pull reader. Its input/feed state is removed. Each queued step reads PCM,
writes complete frames with the existing WAV writer, updates progress from
the borrowed source's file position and force-queues continuation. The
existing generation check, cancel/close cleanup, exclusive output creation
and removal of incomplete files are retained. Strict conversion rejects the
reader's damaged flag as well as fatal/truncated input or format changes.
The application's single output buffer is now 2048 bytes instead of 4608.

The writer now accepts BSNPcmFormat and validates signed 16-bit PCM frame
alignment and average rate; it still supports all nine MP3 native rates,
including decoder-only 48 kHz conversion. Both application builds pass.
Host converter output is byte-exact against the original core for all eight
sample files, and the existing writer format/overflow/I/O failure regressions
pass. The full original host corpus continues to pass.

Cancellation is serviced between synchronous reader calls; Open and ReadPCM
may perform input/metadata I/O and decoding before returning. GEOS UI timing
and cancellation responsiveness still require manual testing.

## Playback integration and compatibility

The actual Open -> BSNPcmPlay -> Close paths run under host GEOS/DMA shims
for all eight MP3 samples and 8/16-bit mono/stereo WAV. The check compiles the
production prepare/cache/conversion/playback/controller routines with the
real readers and decoder. Simulated DMA output matches original-core PCM
byte-for-byte, and known/unknown-length tails drain before cleanup. This is
not an audible GEOS runtime test. A 48-kHz source is rejected before starting
the simulated driver. Target ABI checks assert the packed source/format
layouts and four-byte callback pointer.

Reproduce the basic checks with Tests/check.pl. Passing the pinned upstream
checkout as its first argument additionally exercises public playback. An
optional second argument names a directory containing original-core raw PCM
files named after each input with .pcm appended, for DMA-output comparison.
Reference outputs and the exact invocation are retained under
~/pcgeos-tools/bsnaudio/phase8-reference and phase8-integration.log.

Audio Quick Player (Appl/Audio/Bsqp) and Library/Wav compile and link EC/NC against
bsnwav 1.7 requirements, while the new MP3Wav requires 1.8. These compatibility builds preceded the Audio Quick Player migration below.
The legacy Wav source and DMA driver routines are unchanged. Driver/Sound/BSD16/bsrecord.asm advertises a
44100-Hz maximum through BSDRecGetMaxProperties; BSD8ST advertises 22050 Hz.
BSNWPrepKS retains the 5001..44199-Hz source setup range. No 48-kHz playback
or speculative resampler/buffer enlargement is introduced.

Audio Quick Player still creates its playback thread with a 3000-byte stack
(Appl/Audio/Bsqp/Main/subcode.goc). No claim is made that this is sufficient
for MP3: stack depth, worst decoder-call duration, active-resource paging,
underruns and audible output require manual GEOS measurements. No decoder
runs in an interrupt handler and no extra decoding thread is introduced.

## Application playback examples

Both entry paths use the same blocking engine and borrowed file ownership.
Check the Open result before playing, and always Close after a successful Open:

    BSNWav wav;
    if (BSNWavOpen(&wav, fh) == BSNW_STATUS_OK) {
        result = BSNPcmPlay(&wav.source, 0, 0);
        BSNWavClose(&wav);
    }

    BSNMP3Dec mp3;
    if (BSNMP3DecOpen(&mp3, fh) == BSNW_STATUS_OK) {
        result = BSNPcmPlay(&mp3.source, 0, 0);
        BSNMP3DecClose(&mp3);
    }

Applications doing conversion call ReadPCM directly instead of BSNPcmPlay;
they never supply compressed input to the decoder.

## Final validation and measurements

All 16 legacy exports retain their exact ordinal positions; seven new exports
are appended. The linked geode reports protocol 1.8, permanent name bsnwav,
token BSNW/16427 and 23 exports. Its only imports are geos and ansic. The
complete imported core and optimized assembly are byte-identical to the
pinned donor (the assembly filename differs). No other pre-existing branch
reference moved, including master.

Final linker resource sizes in bytes (EC / NC):

- dgroup: 10432 / 10432, writable fixed data.
- MP3MathCode: 67 / 67, fixed shared read-only code.
- ASMTOOLS_TEXT: 380 / 380, movable shared read-only code.
- AudioMainCode: 5607 / 3359.
- PCMCode: 4578 / 2801; WAVCode: 1690 / 1058.
- MP3ApiCode: 4366 / 2612; MP3ReaderCode: 1268 / 806.
- MP3DspCode: 10970 / 10970; MP3FrameCode: 21412 / 10796.
- MP3HuffCode: 16687 / 5359; MP3ImdctCode: 436 / 237.
- MP3QuantCode: 6068 / 2775; MP3SterCode: 10916 / 7342.
- MP3SynthCode: 1559 / 1238.

Except dgroup and MP3MathCode, every listed code resource is movable, shared,
read-only, discardable and swappable in the actual .geo. The linker reports
96436 / 60232 total resource bytes and 10499 fixed initialized/code bytes,
plus 132 bytes of uninitialized data/stack. Geodump records 120 additional
uninitialized bytes after the rounded initialized dgroup resource. Heap
rounding, resource/handle metadata, resident driver resources and live loaded
code are not runtime measurements here. The approximately 10-KB fixed decoder
table/data contribution is present even for WAV-only playback; moving those
tables requires locked-handle access and is deliberately deferred.

The resource audit found a pre-existing bridge-state error: Driver's udata
was not grouped with C dgroup and became a four-byte read-only code resource.
Including the native resource.def now puts driverInfo in writable dgroup;
all driver request/DMA instructions remain unchanged. The unused 1104-byte
moniker resource and its source asset are removed. Orphan parser/converter
comments and obsolete declarations are deleted.

Final PCM regressions additionally cover failed cache/DMA allocation followed
by retry with stereo toggling enabled. No toggle sample is written through
a null buffer. DMA accounting excludes the initial toggle sample and final
silence, so the last PCM sample is drained. The refill loop waits for space
for a complete source frame, including the partial cache space caused by
channel toggling. Unknown-stream accounting returns a source error before
4-GiB wrap; longer playback needs wider counters. A 65535-byte WAV read
request is capped at 65534 so a valid read cannot equal the error sentinel.
The host tests exercise that boundary with a 64-KB data chunk.

Source-based dynamic block/handle ownership, excluding all geode/resource,
thread and driver-loader handles:

- WAV reader alone: no owned memory handle; borrowed file remains open.
- MP3 reader alone: three movable blocks, unchanged from the original decoder:
  21730-byte target context, 2048-byte input, 4608-byte pending PCM.
- Common playback: one movable PCM cache, normally 8192 bytes.
- Existing BSD16/BSD8ST driver playback: one fixed DMA buffer plus one fixed
  1000-byte ISR stack (BSDRecAllocateBuffer and BSCreateStack).
- Thus source ownership predicts three playback blocks for WAV and six for
  MP3, in addition to library/driver resources. Actual GEOS live/peak handle
  counts, leaks and physical residency have not been measured.
- MP3Wav owns the three decoder blocks and one 2048-byte output block, plus
  its two file handles, application resources and process thread stack.

Final results:

- Audio library, MP3Wav, Audio Quick Player and legacy Wav: EC and NC build/link pass.
- Original host corpus, trusted PCM accuracy, streaming, malformed-input,
  relocation, allocation/reset, new pull checks and real WAV conversion: pass.
- Standalone Watcom DOS: 32 inputs with EC/NC settings and actual linked ESP
  bytes are byte-exact; DSP, live-CS dispatch, 6486 products and public source
  layout/far-pointer assertions pass.
- Public playback host integration: all eight MP3 inputs, with/without the
  initial channel-toggle sample, match original-core PCM. All four native
  WAV sample layouts match; the 48-kHz source is rejected before driver start.
- Optional ASan/UBSan could not link: this environment lacks the referenced
  libasan.so.8.0.0 and libubsan.so.1.0.0. Normal host checks were rerun and pass.

Retained evidence is under ~/pcgeos-tools/bsnaudio/: final-build.log,
final-geodump-ec.txt, final-geodump-nc.txt, final-host.log, final-watcom.log,
final-integration.log, final-mp3wav.log, final-quickplayer.log and
final-legacy-wav.log. swat.rc sends bsnwav, mp3wav, bsqp and wav and ends in c;
no GEOS session or audible playback was started.

Remaining runtime work is explicit: audible WAV/MP3 output, Stop/Pause/Resume,
repeated playback under GEOS memory pressure, code reloads, driver-specific
conversions, allocation failures in the actual sound driver, worst decoder
latency/underruns, peak 3000-byte Audio Quick Player stack use, and live handle/leak
counts. The host DMA shim does not replace those measurements. Midstream
format changes, 48-kHz playback, more than 64 recovery steps per reader call,
and playback sessions at or above 4 GiB of PCM are intentionally unsupported.

## Audio Quick Player WAV/MP3 client

Audio Quick Player now selects the WAV or MP3 reader by the file's RIFF signature,
then calls BSNPcmPlay and closes the reader on every exit. The existing
playback thread, sound controls and repeat option are retained. No compressed
feeding, second playback engine or extra thread is added. MP3Wav conversion
was confirmed working by the user before this client migration.

A native file-selector callback accepts .WAV and .MP3 case-insensitively and
retains directories. A semicolon-separated mask is not used: GEOS supports
one filename mask. The selector subclass follows the SDK FSFilter pattern,
including a statically stored virtual callback pointer. Audio Quick Player now
requires bsnwav protocol 1.8 and is labelled Audio Quick Player.

The source format and PCM length populate the existing display. Unknown MP3
lengths show elapsed time without a remaining-time estimate. Time calculation
uses 32-bit seconds and 3600 seconds/hour. A pending Stop prevents playback
from starting after a slow reader Open and prevents another repeat; Pause is
ignored until the driver is running. The existing 3000-byte playback stack
is retained; actual GEOS stack headroom remains a manual measurement.

Audio Quick Player builds in EC and NC. Its one focused host check compiles the
actual file filter, reader adapter and time formatter with platform shims:

    TMPDIR=~/pcgeos-tools/bsnaudio/tmp perl Appl/Audio/Bsqp/Tests/check.pl

It covers filename cases/directories, reader cleanup on success/failure,
probe versus play, cancellation before playback, and unknown/long durations.
No PC/GEOS runtime was started; audible output and UI controls await the
user's manual test.

A standalone Watcom PCM check also found a pre-existing rate-reduction bug:
the old converter skipped individual interleaved samples rather than whole
frames, discarding the right channel at half rate. Both conversion paths now
skip only after the final byte/sample of a frame. The targeted DOS EC/NC
check covers partial reads, known/unknown lengths, native frame copies,
16-to-8-bit mono/stereo reduction and stop/restart. Reproduce with PCM_WATCOM=1
on Library/Audio/BSNWav/Tests/check.pl; retained evidence is
~/pcgeos-tools/bsnaudio/audit-integration.log. DMA and MP3 DSP code are unchanged.

Playback requires a BestSound-compatible driver (BSD16 or BSD8ST). The
ordinary SoundBlaster driver does not implement the BSW format handshake or
NewWave DMA requests, so BSNWPreCheck returns BSNW_WRONG_DRIVER even for a
valid 44.1-kHz file. Audio Quick Player now reports that driver error separately
from unsupported format/rate and general read/memory errors. MP3Wav needs
no compatible playback driver because it only decodes and writes PCM.
