# dudu.mp3: remaining playback stutter

The target file is document/MUSIC/dudu.mp3 under gbuild/localpc/ensemble.
It is identical to Library/Audio/BSNWav/MUSIC/dudu.mp3.
SHA-256: 90ce3b7c9dfcce6aafcb2dcfc3fc496dab6ba8106b61531b05d2c57a4be1640e.

## Result

The later sections require substantially more decoder work. This supports
content-dependent CPU load as a cause of the remaining gaps. It does not
measure the exact GEOS session or exclude additional heap/IRQ delays.

The file is 57.983 seconds, MPEG-1 Layer III, 44,100 Hz, stereo, variable
bit rate, about 146 kbit/s average. FFmpeg decoded it without warnings.
The sample rate and channel count remain constant. Each audio frame supplies
1,152 samples/channel, or 26.122 ms. PCM consumption is always 176,400 bytes/s.
A change in music volume does not increase the DMA byte rate.

## Measurements

The actual NC assembler DSP and multiplier routines were extracted from the
built BSNWav geode by MP3Dec/Tests/watcom.pl with MP3_ASM=1. They were linked
with the current Watcom C core into a standalone DOS benchmark. The test used
Basebox core=normal, cputype=pentium_slow, cpu_cycles=15000, Watcom -ox, and
MP3_HUFF_LOCAL. It did not boot PC/GEOS or play sound.

The timer surrounds the core decoder call. Source-file reads, PCM-file
writes, and CSV output are outside the measured time. There are no GEOS
resource reloads, heap waits, thread scheduling, DMA ISR work, or PCM
conversion/copy costs in these numbers. This is a controlled decoder-only
scenario, not a measurement of the user's active Basebox configuration.

The DOS clock changes in roughly 55 ms steps. Individual-frame times are
therefore too coarse to use as latency measurements. The table averages
about 192 frames per five-second section. Decoder time is elapsed emulated
DOS clock time around decoder work, not a host performance-counter count.

| Track seconds | Mean decode ms/frame | Mean Huffman big-value pairs/frame |
| --- | ---: | ---: |
| 0-5 | 39.47 | 233 |
| 5-10 | 39.69 | 259 |
| 10-15 | 43.19 | 317 |
| 15-20 | 43.14 | 300 |
| 20-25 | 45.20 | 380 |
| 25-30 | 52.05 | 527 |
| 30-35 | 49.75 | 493 |
| 35-40 | 47.20 | 425 |
| 40-45 | 52.63 | 572 |
| 45-50 | 50.06 | 485 |
| 50-55 | 48.03 | 447 |
| 55-58 | 50.66 | 481 |

The total-only run took 103.590 seconds inside decoder calls for 2,222
frames, which represent 58.044 seconds including the metadata frame. The
stage-instrumented run took 105.127 seconds, only 1.5% more. The measured
rise is not caused by the extra stage clocks.

At this controlled CPU setting, even the opening exceeds the 26.122 ms/frame
sustained budget. The 40-45 second section needs about 33% more decode time
than the opening. More buffering can absorb short spikes, but cannot sustain
this average speed indefinitely. A faster effective CPU setting could cover
the opening yet fail on the later sections. Actual GEOS resource and heap
work can reduce the available margin further.

The compressed bit rate averages about 106 kbit/s at 0-5 seconds and
170 kbit/s at 40-45 seconds. Main-data bits rise from about 2,445 to 4,146
per frame, and big-value Huffman pairs rise from about 233 to 572. More
spectral bands also reach the IMDCT. Short-block use does not rise in the
heaviest section; a short-block switch alone does not explain this result.

In the stage run, approximate shares of total decoder time were synthesis
38%, Huffman 21%, dequantization 18%, IMDCT 13%, and other work 10%. These
shares use the coarse DOS clock and are estimates. Synthesis is the largest
base cost. Huffman work increases strongly with this track's later content.

Source evidence: MP3Dec/core/pvmp3_huffman_parsing.inc:huffman_decode_pairs,
pvmp3_dequantize_sample.inc loops bounded by used_freq_lines, and
pvmp3_imdct_synth.inc:bands2process. The stage run's IMDCT metric is the sum
of the last-used band indices passed to that function, after alias reduction;
it is not a count of raw spectral coefficients.

## Decode correctness

Both native runs produced PCM byte-for-byte equal to the current host C
core. Compared with FFmpeg, after aligning the 2,257-sample/channel
encoder/decoder delay, every compared sample differed by at most one LSB.
RMS difference was about 0.26 LSB in every five-second section. There is no
late-section rise in decode error. FFmpeg's decoded peak is about -6.7 dBFS,
so this file does not approach PCM clipping.

There are 2,221 audio packets reported by FFprobe. The low-level core harness
also decodes the initial metadata frame, giving 2,222 rows in each CSV.
The section boundaries can therefore differ by about one frame from a
player's displayed time. This does not change the workload comparison.

## Next checks and changes

A same-track 44.1 kHz stereo PCM WAV is the useful playback control: it keeps
the musical content and DMA rate while removing MP3 decoding. A controlled
CPU-cycle comparison is also useful. Keep the GEOS heap and application
setup unchanged while comparing settings.

For code work, profile/optimize the synthesis base cost and Huffman/
dequantization work before increasing buffers again. The remaining stutter
has a demonstrated decoder-load mechanism; another interrupt change is not
needed to explain the content correlation.

The reusable profiler now writes per-frame CSV data as well as the existing
stage totals. TOTAL_ONLY=1 removes the stage clocks to check their overhead.
MP3_ASM_OBJECT selects the extracted production assembler object. Both runs
still verify exact PCM against the uninstrumented host core.

Raw results: stages.csv and total.csv in this directory. The original MP3,
GEOS binaries, target settings, and playback code were not changed.
