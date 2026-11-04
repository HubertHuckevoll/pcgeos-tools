#!/usr/bin/env perl
# Exercise the actual PCM routines with a synchronous DMA/GEOS host shim.
use strict;
use warnings;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Temp qw(tempdir);
my $lib = abs_path(dirname(__FILE__).'/..');
my $tmp = tempdir('bsnpcm-XXXXXX', TMPDIR=>1, CLEANUP=>!$ENV{KEEP_TESTS});
open my $in, '<', "$lib/PCM/pcm.goc" or die $!;
my $source = do { local $/; <$in> };
$source =~ s/\@ifndef BSNWAV_NO_UI\b.*?\@endif\s*//sg;
open my $out, '>', "$tmp/pcm.inc" or die $!;
$source =~ /(typedef word _pascal BSNPcmReadCall\(.*?;)/s or die 'missing callback type';
print $out "$1\n";
# Extract the size policy too, so the boundary check uses the real code.
for my $name (qw(BSNWReadPCM BSNWDetermineSecondaryBufferLength BSNWLoadCache BSNWFillSilence BSNWKonvertData BSNWLoadData BSNWPlay)) {
    $source =~ /^([^\n;{}]*\b$name\([^;]*?\)\n\{.*?^\})/ms
        or die "missing $name";
    print $out "$1\n";
}
$source =~ /^(void _pascal BSNWKonvert16To8\([^;]*?\)\n\{.*?^\})/ms
    or die 'missing 16-bit converter';
print $out "#ifdef __WATCOMC__\n$1\n#endif\n";
open my $control_in, '<', "$lib/Main/library.goc" or die $!;
my $controls = do { local $/; <$control_in> };
$controls =~ /^(void _pascal _export BSNWaveStop\([^;]*?\)\n\{.*?^\})/ms
    or die 'missing stop control';
print $out "$1\n";
print $out "#ifdef BSN_INTEGRATION_TEST\n";
for my $name (qw(BSNWPrepare BSNWRunPCM BSNPcmPlay)) {
    my $definition = $source;
    $definition =~ /^([^\n;{}]*\b$name\([^;]*?\)\n\{.*?^\})/ms
        or die "missing $name";
    print $out "$1\n";
}
open my $helpers, '<', "$lib/Main/subcode.goc" or die $!;
my $helper_source = do { local $/; <$helpers> };
# Keep the real short-buffer rounding and channel-toggle sample insertion.
for my $name (qw(BSNWInsertSample BSNWAllocSecBuffer)) {
    $helper_source =~ /^([^\n;{}]*\b$name\([^;]*?\)\n\{.*?^\})/ms
        or die "missing $name";
    print $out "$1\n";
}
print $out "#endif\n";
close $out or die $!;
# geos.h is replaced only in this host check; production uses the real header.
open $out, '>', "$tmp/geos.h" or die $!;
print $out <<'HEADER';
#ifndef BSN_HOST_GEOS
#define BSN_HOST_GEOS
#include <stdint.h>
typedef uint8_t byte;
typedef uint16_t word;
typedef int16_t sword;
typedef uint32_t dword;
typedef int Boolean;
typedef word MemHandle;
typedef dword optr;
#define _pascal
#define _export
#define FALSE 0
#define TRUE 1
#endif
HEADER
close $out or die $!;
open $out, '>', "$tmp/file.h" or die $!;
print $out <<'HEADER';
#ifndef BSN_HOST_FILE
#define BSN_HOST_FILE
#include <geos.h>
typedef word FileHandle;
#define FILE_POS_START 0
extern dword FileSize(FileHandle file);
extern dword FilePos(FileHandle file, dword offset, word mode);
extern word FileRead(FileHandle file, void *destP, word count, word flags);
#endif
HEADER
close $out or die $!;
my @flags = qw(-std=gnu89 -Werror=declaration-after-statement -O2);
system('gcc', @flags, '-I', $tmp, '-I', "$lib/../../../CInclude",
       "$lib/Tests/pcm.c", '-o', "$tmp/pcm") == 0 or die 'compile failed';
system("$tmp/pcm") == 0 or die 'PCM checks failed';

system('gcc', @flags, '-I', $tmp, '-I', "$lib/../../../CInclude", '-x', 'c',
       "$lib/WAV/wav.goc", "$lib/Tests/wav.c", '-o', "$tmp/wav") == 0
    or die 'WAV compile failed';
system("$tmp/wav", "$tmp/input.wav") == 0 or die 'WAV checks failed';

# Optional decoder-to-playback integration using the same actual PCM routines.
if (@ARGV) {
    my ($up, $reference_dir) = @ARGV;
    my $mp3 = "$lib/MP3Dec";
    my @core = map { "$mp3/$_.c" } qw(mp3frame mp3huff mp3imdct mp3synth mp3quant mp3ster);
    system('gcc', @flags, '-fwrapv', '-I', $tmp, '-I', $mp3,
        '-I', "$lib/../../../CInclude", '-DMP3_HOST_TEST', '-DMP3_HEAP_ONLY',
        '-DBSN_INTEGRATION_TEST', '-x', 'c', "$lib/Tests/pcm.c",
        "$mp3/Tests/stream.c", "$mp3/mp3api.c", "$mp3/mp3reader.goc",
        "$lib/WAV/wav.goc", @core, '-o', "$tmp/play") == 0 or die 'integration compile failed';
    {
        # Decode without playback to get reference bytes for both modes.
        system('gcc', @flags, '-fwrapv', '-I', $tmp, '-I', $mp3,
            '-I', "$lib/../../../CInclude", '-DMP3_HOST_TEST', '-x', 'c',
            "$mp3/Tests/pull.c", "$mp3/mp3api.c", "$mp3/mp3reader.goc",
            @core, '-o', "$tmp/pull") == 0 or die 'reader compile failed';
    }
    for my $input (glob("$up/tests/data/*.mp3")) {
        (my $name = $input) =~ s|.*/||;
        my $reference = defined $reference_dir ? "$reference_dir/$name.pcm" : "$tmp/reference.pcm";
        if (!defined $reference_dir) {
            system("$tmp/pull", $input, $reference, '1536') == 0 or die 'reader failed';
        }
        system("$tmp/pull", $input, "$tmp/half-reference.pcm", '1536', 'half') == 0
            or die 'half-rate reader failed';
        for my $mode ('mp3', 'mp3-toggle', 'mp3half', 'mp3half-toggle') {
            my $status = system("$tmp/play", $mode, $input, "$tmp/play.pcm");
            next if $status == (2 << 8); # The C check verified rate rejection.
            $status == 0 or die "playback failed: $input ($mode)";
            {
                open my $ref, '<:raw', $mode =~ /half/ ? "$tmp/half-reference.pcm" : $reference or die $!;
                open my $played, '<:raw', "$tmp/play.pcm" or die $!;
                my $expected = do { local $/; <$ref> };
                my $actual = do { local $/; <$played> };
                # Skip the optional 16-bit toggle sample. Allow final silence
                # after EOF, but compare every source byte in the DMA output.
                my $skip = $mode =~ /-toggle$/ ? 2 : 0;
                die "playback PCM differs: $input ($mode)" unless substr($actual, $skip, length($expected)) eq $expected;
            }
        }
    }
    for my $bits (8, 16) {
        for my $channels (1, 2) {
          for my $frames (1, 2, 3, 64, 65) {
            # Very short files test the minimum size and rounding of halves.
            my $align = $channels * ($bits / 8);
            my $payload = pack('C*', map { $_ & 255 } 0..($frames * $align - 1));
            open my $wave, '>:raw', "$tmp/native.wav" or die $!;
            # RIFF includes the pad byte after odd data. The data size does not.
            print $wave pack('a4Va4a4VvvVVvva4V', 'RIFF', 36 + length($payload) + (length($payload) & 1), 'WAVE', 'fmt ', 16,
                            1, $channels, 44100, 44100*$align, $align, $bits,
                            'data', length($payload)), $payload, length($payload) & 1 ? "\0" : '';
            close $wave or die $!;
            system("$tmp/play", 'wav', "$tmp/native.wav", "$tmp/wavplay.pcm") == 0
                or die 'WAV playback failed';
            open my $played, '<:raw', "$tmp/wavplay.pcm" or die $!;
            read($played, my $actual, length($payload)) == length($payload) or die 'short WAV playback';
            die 'WAV playback PCM differs' unless $actual eq $payload;
          }
        }
    }
    open my $wav, '>:raw', "$tmp/rate.wav" or die $!;
    print $wav pack('a4Va4a4VvvVVvva4V', 'RIFF', 40, 'WAVE', 'fmt ', 16,
                    1, 1, 48000, 96000, 2, 16, 'data', 4), "\0" x 4;
    close $wav or die $!;
    system("$tmp/play", 'wav', "$tmp/rate.wav", "$tmp/wavplay.pcm") == 0
        or die '48kHz rejection failed';
}

# Optional native-int converter/control checks. Standalone DOS only; no GEOS.
if ($ENV{PCM_WATCOM}) {
    my $watcom = $ENV{WATCOM} // die "set WATCOM\n";
    for my $variant ('ec', 'nc') {
        system('wcl', qw(-q -bt=dos -ml -3 -zp1 -zu -s -ecp -of -of+ -ol -ol+ -ei -zdp -fpc),
            $variant eq 'nc' ? ('-ox') : (), "-i=$watcom/h", "-i=$tmp",
            "-i=$lib/../../../CInclude", "-fo=$tmp/", "-fe=$tmp/$variant.exe",
            "$lib/Tests/pcm.c") == 0 or die 'target PCM compile failed';
    }
    open my $batch, '>:raw', "$tmp/all.bat" or die $!;
    print $batch "ec.exe >ec.txt\r\nif errorlevel 1 goto fail\r\nnc.exe >nc.txt\r\n",
        "if errorlevel 1 goto fail\r\necho PASS>passed.txt\r\nexit\r\n",
        ":fail\r\necho FAIL>failed.txt\r\nexit\r\n";
    close $batch or die $!;
    {
        local $ENV{SDL_VIDEODRIVER} = 'offscreen';
        local $ENV{SDL_AUDIODRIVER} = 'dummy';
        my $pid = fork(); die $! unless defined $pid;
        if (!$pid) {
            open STDOUT, '>', "$tmp/basebox.log" or die $!;
            open STDERR, '>&', \*STDOUT or die $!;
            exec 'timeout', '180', 'basebox', '--noprimaryconf', '--nolocalconf', '--noautoexec',
                '--set', 'output=texture', '--set', 'texture_renderer=software',
                '--set', 'core=normal', '--set', 'cputype=386', '--set', 'cpu_cycles=max',
                '--set', 'nosound=true', '--exit', '-c', "mount c $tmp", '-c', 'c:',
                '-c', 'call all.bat';
            die $!;
        }
        waitpid($pid, 0); die "DOS PCM runner failed: $tmp/basebox.log\n" if $?;
    }
    die "DOS PCM checks failed: $tmp/basebox.log\n" unless -f "$tmp/PASSED.TXT";
    print "Watcom EC/NC PCM, 16-to-8 conversion, stop/restart: PASS ($tmp)\n";
}
