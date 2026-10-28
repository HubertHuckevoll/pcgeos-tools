# Watcom fixed-point portability

Open Watcom 16-bit large model uses 16-bit int, 32-bit long and four-byte
ordinary data/function pointers. Small integer operands promote to int before
shifting: cast a signed 16-bit value to a 32-bit type before a shift such as
mp3_bitrate[...] << 20. See Library/MP3Dec/core/pvmp3_get_main_data_size.inc
and Library/MP3Dec/Tests/corecheck.c (target structure/pointer assertions).

Compile-time floating expressions can differ from a GCC binary32 reference
by low integer bits even with the same decimal source constants. MP3Dec keeps
reference Q constants as integer literals and compares target PCM against the
original microMP3 core. See Library/MP3Dec/Tests/check.pl and watcom.pl.

With Open Watcom 2.0 beta Dec 1 2020, -ox omitted two left shifts of the local
tmp in pvmp3_mdct_18. The unoptimized build and the C reference retained them.
Making that temporary volatile restored the expected history values. Keep the
workaround until Library/MP3Dec/Tests/dsp.c passes with the replacement compiler;
its history[6]/history[9] assertions reproduce the failure, and watcom.pl runs
it using the target compiler. This is an observed code-generation difference,
not a claim about all Watcom versions or all fixed-point routines.

A 32-bit Pascal C return in 16-bit mode is DX:AX, even when the ESP routine
uses EAX/EDX internally. Returning only EAX loses the high word at C call sites.
See Library/AnsiC/wcc_rtl.asm's DX:AX long-arithmetic ABI and
Library/MP3Dec/mp3dsp.asm:MP3MULSHIFT; Tests/target.c and Tests/watcom.pl compare
6486 signed/rounding products through the assembled entry against the C oracle.
