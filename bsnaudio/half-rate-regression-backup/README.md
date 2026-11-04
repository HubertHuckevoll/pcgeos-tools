# Half-rate regression investigation

The saved patch and source snapshots contain the optional-quality work and
a discarded cache-prefetch experiment. They are not the active source tree.
The user reported irregular MP3 playback in both modes after a cold restart,
with 44100 Hz displayed and normal pitch. WAV playback remained correct.
Standalone PCM comparisons passed, but did not establish GEOS runtime timing.
The active playback sources were restored to commit 0b4d47282, which retains
the earlier DMA, ISR-clear, refill, and thread-exit fixes. The per-frame
profiler remains separate. The exact quality-patch regression is unresolved.
