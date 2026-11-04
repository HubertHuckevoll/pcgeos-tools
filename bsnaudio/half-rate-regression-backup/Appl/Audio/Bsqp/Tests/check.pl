#!/usr/bin/env perl
# Exercise the real selector, source lifecycle and timer code with host shims.
use strict;
use warnings;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Temp qw(tempdir);
my $app = abs_path(dirname(__FILE__).'/..');
my $tmp = tempdir('bsqp-XXXXXX', TMPDIR=>1, CLEANUP=>!$ENV{KEEP_TESTS});
sub read_file { open my $f, '<', $_[0] or die $!; local $/; return <$f>; }
my $audio = read_file("$app/Main/subcode.goc");
my $ui = read_file("$app/UI/uimain.goc");
$audio =~ s/\r\n/\n/g; $ui =~ s/\r\n/\n/g;
$audio =~ s{//([^\n]*)}{/*$1*/}g;
open my $out, '>', "$tmp/geos.h" or die $!;
print $out <<'HEADER';
#ifndef HOST_GEOS
#define HOST_GEOS
#include <stdint.h>
typedef uint8_t byte;
typedef uint16_t word;
typedef uint32_t dword;
typedef word MemHandle;
typedef dword optr;
typedef int Boolean;
#define _pascal
#define _export
#define TRUE 1
#define FALSE 0
#endif
HEADER
close $out or die $!;
open $out, '>', "$tmp/file.h" or die $!;
print $out "#include <geos.h>\ntypedef word FileHandle;\n#define FILE_POS_START 0\n";
print $out "dword FilePos(FileHandle, dword, word);\nword FileRead(FileHandle, void *, word, word);\n";
close $out or die $!;
open $out, '>', "$tmp/check.c" or die $!;
print $out <<'C';
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <bsnwav.h>
#define CODE_RIFF 0x46464952UL
#define FEA_FILE_ATTR 1
#define FEA_NAME 2
#define FA_SUBDIR 0x10
typedef byte FileAttrs;
typedef struct { FileAttrs attrs; const char *nameP; } FileEnumCallbackData;
static void *FileEnumLocateAttr(FileEnumCallbackData *dataP, word attr, void *unusedP)
{
    (void)unusedP;
    return attr == FEA_NAME ? (void *)dataP->nameP : (void *)&dataP->attrs;
}
static int LocalCmpStringsNoCase(const char *aP, const char *bP, word limit)
{
    (void)limit;
    while (*aP && tolower((unsigned char)*aP) == tolower((unsigned char)*bP)) {
        aP++; bP++;
    }
    return tolower((unsigned char)*aP) - tolower((unsigned char)*bP);
}
static dword bqSampleRate, bqAllBytes, bqSampleBytes;
static word bqChannels, bqBits;
static Boolean bqStopRequested;
#define BQ_OPTION_MP3_HALF_RATE 0x0008
static word bqOptions, expectedOptions;
static dword magic;
static int openResult, playResult, wavOpens, mp3Opens, wavCloses, mp3Closes, plays;
static word expectedFlags, readCount;
static Boolean failSeek;
static BSNPcmFormat format = { 44100, 2, 16, 4, 176400 };
dword FilePos(FileHandle fileH, dword offset, word mode)
{
    assert(fileH == 55 && !offset && mode == FILE_POS_START);
    return failSeek ? 0xffffffffUL : 0;
}
word FileRead(FileHandle fileH, void *destP, word count, word flags)
{
    assert(fileH == 55 && count == 4 && !flags);
    memcpy(destP, &magic, 4);
    return readCount;
}
int BSNWavOpen(BSNWav *wavP, FileHandle fileH)
{
    assert(fileH == 55); wavOpens++;
    wavP->source.format = format; wavP->source.pcmBytes = 176400;
    return openResult;
}
int BSNMP3DecOpenEx(BSNMP3Dec *mp3P, FileHandle fileH, word options)
{
    assert(fileH == 55 && options == expectedOptions); mp3Opens++;
    mp3P->source.format = format; mp3P->source.pcmBytes = BSN_PCM_LENGTH_UNKNOWN;
    if (options) mp3P->source.format.sampleRate /= 2;
    return openResult;
}
void BSNWavClose(BSNWav *wavP) { (void)wavP; wavCloses++; }
void BSNMP3DecClose(BSNMP3Dec *mp3P) { (void)mp3P; mp3Closes++; }
int BSNPcmPlay(BSNPcmSource *sourceP, word flags, optr parent)
{
    assert(sourceP->format.sampleRate ==
           (magic != CODE_RIFF && expectedOptions ? format.sampleRate/2 : format.sampleRate));
    assert(flags == expectedFlags && !parent);
    plays++; return playResult;
}
typedef word GStateHandle;
#define NullHandle 0
#define BQ_TIME_DISP_NORMAL 1
#define BQ_TIME_DISP_REMAIN 2
#define DISP_VIEW_X5 0
#define GrCreateState(a) 1
#define GrSetAreaColor(a,b,c,d,e) ((void)0)
#define GrFillRect(a,b,c,d,e) ((void)0)
#define GrSetFont(a,b,c) ((void)0)
#define GrSetTextColor(a,b,c,d,e) ((void)0)
#define GrTextWidth(a,b,c) 0
#define GrDrawText(a,b,c,d,e) strcpy(drawn,d)
#define GrDestroyState(a) ((void)0)
static word winHan = 1, bqDispStyle, playFlag;
static char globalText[80], drawn[80];
C
for my $name ('BQ_Audio', 'RedrawTime', 'BQ_FilterAudio') {
    my $source = $name eq 'BQ_FilterAudio' ? $ui : $audio;
    $source =~ /^((?:static )?[^\n;{}]*\b$name\s*\([^;]*?\)\n\{.*?^\})/ms
        or die "missing $name";
    print $out "$1\n";
}
print $out <<'C';
int main(void)
{
    static const char *accepted[] = {"a.WAV", "a.mp3", "many.dots.Mp3", ".wav"};
    static const char *rejected[] = {"a.mp3.exe", "wav", "a.wavx", "a.", "a.txt", ""};
    FileEnumCallbackData data;
    unsigned i, mp3, preview;
    data.attrs = 0;
    for (i=0; i<sizeof(accepted)/sizeof(accepted[0]); i++) {
        data.nameP = accepted[i]; assert(!BQ_FilterAudio(0, &data, 0));
    }
    for (i=0; i<sizeof(rejected)/sizeof(rejected[0]); i++) {
        data.nameP = rejected[i]; assert(BQ_FilterAudio(0, &data, 0));
    }
    data.nameP = (void *)0; assert(BQ_FilterAudio(0, &data, 0));
    data.attrs = FA_SUBDIR; assert(!BQ_FilterAudio(0, &data, 0));
    data.nameP = "music"; assert(!BQ_FilterAudio(0, &data, 0));
    readCount = 4;
    for (mp3=0; mp3<2; mp3++) {
        magic = mp3 ? 0x00334449UL : CODE_RIFF;
        for (preview=0; preview<2; preview++) {
            expectedFlags = preview ? BSNW_TEST_ONLY : BSNW_SHOW_ERROR_MSG;
            assert(BQ_Audio(55, preview) == BSNW_STATUS_OK);
            assert(bqAllBytes == (mp3 ? BSN_PCM_LENGTH_UNKNOWN : 176400));
            assert(bqSampleRate == 44100 && bqChannels == 2 && bqBits == 16);
            assert(bqSampleBytes == 0);
        }
        openResult = BSNW_SOURCE_ERROR; i = plays;
        assert(BQ_Audio(55, FALSE) == BSNW_SOURCE_ERROR && plays == (int)i);
        openResult = 0; playResult = BSNW_UNKNOWN_WAVE_FORMAT;
        expectedFlags = BSNW_TEST_ONLY;
        assert(BQ_Audio(55, TRUE) == BSNW_UNKNOWN_WAVE_FORMAT);
        playResult = 0; bqStopRequested = TRUE; i = plays;
        assert(BQ_Audio(55, FALSE) == BSNW_ABORT && plays == (int)i);
        assert(BQ_Audio(55, TRUE) == BSNW_STATUS_OK);
        bqStopRequested = FALSE;
    }
    assert(wavOpens == wavCloses && mp3Opens == mp3Closes);
    /* The saved option affects MP3 probe and playback, but not WAV. */
    bqOptions = BQ_OPTION_MP3_HALF_RATE; expectedOptions = BSN_MP3_HALF_RATE;
    for (mp3=0; mp3<2; mp3++) {
        magic = mp3 ? 0x00334449UL : CODE_RIFF;
        for (preview=0; preview<2; preview++) {
            expectedFlags = preview ? BSNW_TEST_ONLY : BSNW_SHOW_ERROR_MSG;
            assert(BQ_Audio(55, preview) == BSNW_STATUS_OK);
            assert(bqSampleRate == (mp3 ? 22050 : 44100));
        }
    }
    bqOptions = expectedOptions = 0;
    i = plays; failSeek = TRUE;
    assert(BQ_Audio(55, FALSE) == BSNW_SOURCE_ERROR && plays == (int)i);
    failSeek = FALSE; readCount = 3;
    assert(BQ_Audio(55, FALSE) == BSNW_SOURCE_ERROR && plays == (int)i);
    bqChannels = 1; bqSampleRate = 8000; bqBits = 16;
    bqAllBytes = BSN_PCM_LENGTH_UNKNOWN; bqSampleBytes = 16000*70000UL;
    bqDispStyle = BQ_TIME_DISP_REMAIN; playFlag = 1;
    RedrawTime(1); assert(!strcmp(drawn, "19:26:40"));
    bqAllBytes = 16000*100UL; bqSampleBytes = 16000*101UL;
    RedrawTime(1); assert(!strcmp(drawn, "-0:00:00"));
    bqSampleBytes = 16000*99UL;
    RedrawTime(1); assert(!strcmp(drawn, "-0:00:01"));
    bqDispStyle = BQ_TIME_DISP_NORMAL; bqAllBytes = BSN_PCM_LENGTH_UNKNOWN;
    bqSampleBytes = 16000*3600UL;
    RedrawTime(1); assert(!strcmp(drawn, "1:00:00"));
    puts("Audio Quick Player WAV/MP3 filter, shared playback lifecycle, cancel/probe and elapsed time: PASS");
    return 0;
}
C
close $out or die $!;
system('gcc', '-std=c89', '-pedantic-errors', '-Werror=declaration-after-statement',
       '-I', $tmp, '-I', "$app/../../../CInclude", "$tmp/check.c", '-o', "$tmp/check") == 0
    or die 'compile failed';
system("$tmp/check") == 0 or die 'Audio Quick Player checks failed';
