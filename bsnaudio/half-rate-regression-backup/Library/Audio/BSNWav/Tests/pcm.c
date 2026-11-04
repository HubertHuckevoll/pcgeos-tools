/* Host regression for actual cache, conversion and playback-loop code. */
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <bsnwav.h>
#define BSNW_PCM_READ_ERROR BSN_PCM_READ_ERROR
#define BSNW_STATUS_PLAY_MEM 2
#define NullOptr 0
#define BSNW_TICKS_PER_SECOND 60
#define BSNW_MIN_TICKS_PER_HALF_BUFFER 2
#define HF_SWAPABLE 0
#define HAF_ZERO_INIT 0
#define BSCPT_REST_TIME 1
static word playCacheLen, cacheFree, cacheFull, cacheOffset, cacheKOffset;
static word secondKOffset, secondFree, secBufLen, secBufL2, playLen2, secondOffset;
static word peakLevel, peakLevel2, secondHandle, playCacheHandle;
static word pcmBlockAlign, statusGlyphOptr2, simFlags, playStatus;
static byte konvChanRed, konvBitsRed, konvRateRed, playBits;
static Boolean pcmUnknownLength, playStopFlag;
static dword bytesToPlay, fullLen, playedBytes, timeOutCounter;
static byte cache[32], dma[8], played[2048];
static byte *playCachePtr = cache, *secondPtr = dma;
static char playStatusText[80];
static BSNPcmSource *playSourceP;
static dword ticks, playedCount;
static word started, stopped, stopAtTick;
/* Insert IRQs during a source read, a DMA copy, or the first option call. */
static word delayRead, delayCopy, delayStart;
void BSNWaveStop(void);
static FILE *playOutputP;
#ifdef BSN_INTEGRATION_TEST
static MemHandle dmaH;
static word failCache, failDMA;
static word secBufLenSoll = 512, playSampleRate;
static byte playChannels, stereoToggle, stereoToggleIni;
static Boolean compatFlag = TRUE;
static optr statusBox, statusGlyphOptr1, statusRightBoxOptr;
extern MemHandle MemAlloc(word size, word flags, word action);
extern void *MemLock(MemHandle h);
extern void MemUnlock(MemHandle h);
extern void MemFree(MemHandle h);
static int BSNWPreCheck(word flags) { (void)flags; return BSNW_STATUS_OK; }
static void *BSNWAllocPlayCache(word size)
{
    if (failCache) { playCacheHandle = 0; return (void *)0; }
    playCacheHandle = MemAlloc(size, 0, 0);
    return playCacheHandle ? MemLock(playCacheHandle) : (void *)0;
}
word BSNWAllocSecBuffer(byte **ptrP, word size);
/* Use the real allocation wrapper. Replace only GEOS segment pointers
 * and the driver call with host memory, including the allocation failure.
 */
#define BSNW_FARPTR(type, ptr) (ptr)
#define MK_FP(seg, off) (dmaH ? MemLock(dmaH) : (void *)0)
static word BSNWAsmSecondAlloc(word size, word *offsetP, word *segmentP)
{
    *offsetP = *segmentP = 0;
    if (failDMA) { dmaH = 0; return 0; }
    dmaH = MemAlloc(size, 0, 0);
    return dmaH ? size : 0;
}
static int BSNWPrepKS(word rate, byte channels, byte bits)
{
    playSampleRate = rate; playChannels = channels; playBits = bits;
    konvRateRed = konvBitsRed = konvChanRed = 1;
    return BSNW_STATUS_OK;
}
static optr BSCNCreateStatusBox(optr parent) { (void)parent; return 0; }
void BSNWInsertSample(void *destP, byte bits);
#endif

static word ProcCallFixedOrMovable_pascal(void *contextP, void *destP,
                                         word capacity, BSNPcmReadProc *readP)
{
    return readP(contextP, destP, capacity);
}
#ifdef __WATCOMC__
void BSNWKonvert16To8(void *cacheP, void *secondP);
#else
static void BSNWKonvert16To8(void *cacheP, void *secondP)
{
    (void)cacheP; (void)secondP;
    assert(0); /* This check selects the byte-copy conversion path. */
}
#endif
static word BSNWAsmStartPlay(void) { started++; ticks = 0; return 0; }
/* One call plays a complete half, then clears it as the driver ISR does.
 * Normal state reads do not advance DMA; a read can occur between two IRQs.
 */
static void AdvanceDMA(void)
{
    word half;
    assert(ticks < 1000000);
    half = (ticks & 1) ? secBufL2 : 0;
    if (playOutputP) {
        assert(fwrite(secondPtr + half, 1, secBufL2, playOutputP) == secBufL2);
    } else {
        assert(playedCount + secBufL2 <= sizeof(played));
        memcpy(played + playedCount, dma + half, secBufL2);
    }
    memset(secondPtr + half, playBits == 16 ? 0 : 0x80, secBufL2);
    playedCount += secBufL2;
    ticks++;
    if (stopAtTick && ticks == stopAtTick) BSNWaveStop();
}
static word BSNWaveGetAIState(word options)
{
    if (options) {
        /* An IRQ can arrive before the first option call returns. */
        while (delayStart) { delayStart--; AdvanceDMA(); }
    }
    return (word)((ticks & 255) | ((ticks & 1) ? 0x100 : 0));
}
static void TimerSleep(word ticksToSleep)
{
    /* Model one half completing while the playback thread is asleep. */
    (void)ticksToSleep;
    AdvanceDMA();
}
static void *CopyRefill(void *destP, const void *sourceP, size_t count)
{
    void *resultP;
    resultP = memcpy(destP, sourceP, count);
    /* Complete an IRQ before the caller can check the copy result. */
    if (delayCopy) { delayCopy = 0; AdvanceDMA(); }
    return resultP;
}
static void BSNWaveStopRecOrPlay(void *bufferP)
{
    (void)bufferP; stopped++;
#ifdef BSN_INTEGRATION_TEST
    if (dmaH) { MemUnlock(dmaH); MemFree(dmaH); dmaH = 0; }
#endif
}
#ifndef BSN_INTEGRATION_TEST
/* The small PCM tests need one four-byte refill block, with no host heap. */
static byte refill[4];
static word failRefill;
static word MemAlloc(word size, word flags, word action)
{
    (void)flags; (void)action;
    assert(size == sizeof(refill));
    return failRefill ? 0 : 1;
}
static void *MemLock(word h) { assert(h == 1); return refill; }
static void MemUnlock(word h) { (void)h; }
static void MemFree(word h) { (void)h; }
#endif
static dword BSNWaveCalcPlaytimeText(char *textP, dword current, dword full,
                                    dword rate, word mode)
{
    (void)textP; (void)current; (void)full; (void)rate; (void)mode;
    return 0;
}
/* Replace only the copy in the extracted playback code. DMA output and
 * other test copies must not trigger the copy-delay hook.
 */
#define memcpy CopyRefill
#include "pcm.inc"
#undef memcpy

#ifndef BSN_INTEGRATION_TEST
typedef struct {
    word length, offset, chunk, failAt, invalid;
} Input;
static word ReadPCM(void *contextP, void *destP, word capacity)
{
    Input *inputP = contextP;
    word count, i;
    if (inputP->invalid) return inputP->invalid == 1 ? capacity+1 : 1;
    if (inputP->offset >= inputP->failAt) return BSN_PCM_READ_ERROR;
    if (started && delayRead) {
        /* DMA keeps playing while the source callback cannot return data. */
        while (delayRead) { delayRead--; AdvanceDMA(); }
    }
    count = inputP->length - inputP->offset;
    if (count > capacity) count = capacity;
    if (count > inputP->chunk) count = inputP->chunk;
    for (i=0; i<count; i++) ((byte *)destP)[i] = (byte)(inputP->offset+i);
    inputP->offset += count;
    return count;
}
static void Reset(BSNPcmSource *sourceP)
{
    playSourceP = sourceP;
    bytesToPlay = sourceP->pcmBytes;
    pcmUnknownLength = bytesToPlay == BSN_PCM_LENGTH_UNKNOWN;
    fullLen = pcmUnknownLength ? 0 : bytesToPlay;
    pcmBlockAlign = sourceP->format.blockAlign;
    playCacheLen = 32;
    cacheFree = playCacheLen;
    cacheFull = cacheOffset = cacheKOffset = 0;
    secBufLen = sizeof(dma);
    secBufL2 = secBufLen/2;
    secondFree = secBufLen;
    secondKOffset = secondOffset = 0;
    konvChanRed = konvRateRed = konvBitsRed = 1;
    playLen2 = secBufL2;
    playBits = 8;
    playedBytes = ticks = started = stopped = playedCount = 0;
    timeOutCounter = delayRead = delayCopy = delayStart = 0;
    playStopFlag = FALSE;
    memset(dma, 0xcc, sizeof(dma));
}
int main(void)
{
    BSNPcmSource source;
    Input input;
    word length, chunk, unknown, i, align, frame, channel, offset, output;
    BSNPcmFormat format;
    dword physical, actual, requested, minimum, tail;
#ifdef __WATCOMC__
    word channels, outputChannels, rate;
    long sample, right;
#endif
    source.format.avgBytesPerSecond = 8000;
    source.format.blockAlign = 1;
    source.readP = ReadPCM;
    source.contextP = &input;
    /* A ready refill must not wait for another source read. */
    input.length = 100; input.offset = 16; input.chunk = 8;
    input.failAt = 16; input.invalid = 0;
    source.pcmBytes = 100;
    Reset(&source);
    cacheFull = cacheFree = cacheOffset = 16;
    bytesToPlay = 84; secondFree = secBufL2;
    for (i=0; i<16; i++) cache[i] = (byte)i;
    assert(BSNWLoadData(cache, dma) == BSNW_STATUS_OK);
    assert(input.offset == 16 && cacheFull == 12);
    for (i=0; i<4; i++) assert(dma[i] == i);
    /* One source chunk already covers this half. Do not fill the cache. */
    input.offset = 0; input.failAt = 0xffff;
    Reset(&source); secondFree = secBufL2;
    assert(BSNWLoadData(cache, dma) == BSNW_STATUS_OK);
    assert(input.offset == 8 && cacheFull == 4);
    for (length=0; length<100; length++) {
        for (chunk=1; chunk<=13; chunk++) {
            for (unknown=0; unknown<2; unknown++) {
                input.length = length; input.offset = 0; input.chunk = chunk;
                input.failAt = 0xffff; input.invalid = 0;
                source.pcmBytes = unknown ? BSN_PCM_LENGTH_UNKNOWN : length+7;
                Reset(&source);
                assert(BSNWPlay(&source.format, 0, 0) == BSNW_STATUS_OK);
                assert(input.offset == length && fullLen == length);
                assert(playedBytes == length && stopped == 1);
                for (i=0; i<length; i++) assert(played[i] == (byte)i);
            }
        }
    }
    /* Decoder chunk sizes must not change integer rate reduction. */
    for (length=1; length<100; length++) {
        for (chunk=1; chunk<=13; chunk++) {
            input.length = length; input.offset = 0; input.chunk = chunk;
            input.failAt = 0xffff; input.invalid = 0;
            source.pcmBytes = BSN_PCM_LENGTH_UNKNOWN;
            Reset(&source);
            playCacheLen = cacheFree = 30;
            konvRateRed = 3; playLen2 = secBufL2 * 3;
            assert(BSNWPlay(&source.format, 0, 0) == BSNW_STATUS_OK);
            for (i=0; i<(length+2)/3; i++) assert(played[i] == (byte)(i*3));
        }
    }
    /* Native PCM copies reduce complete frames, retaining channel order. */
    for (align=1; align<=4; align*=2) {
        source.format.blockAlign = align;
        for (i=1; i<=3; i++) {
            for (length=0; length<70; length++) {
                for (chunk=1; chunk<=7; chunk++) {
                    for (unknown=0; unknown<2; unknown++) {
                        input.length = length * align;
                        input.offset = 0; input.chunk = chunk * align;
                        input.failAt = 0xffff; input.invalid = 0;
                        source.pcmBytes = unknown ? BSN_PCM_LENGTH_UNKNOWN : input.length+12;
                        Reset(&source);
                        playCacheLen -= playCacheLen % (align * i);
                        cacheFree = playCacheLen;
                        konvRateRed = (byte)i; playLen2 = secBufL2 * i;
                        assert(BSNWPlay(&source.format, 0, 0) == BSNW_STATUS_OK);
                        assert(input.offset == input.length && playedBytes == input.length);
                        output = 0;
                        for (frame=0; frame<length; frame+=i) {
                            for (channel=0; channel<align; channel++)
                                assert(played[output++] == (byte)(frame*align+channel));
                        }
                    }
                }
            }
        }
    }
    source.format.blockAlign = 1;
    /* Rate reduction and the channel-toggle byte split a source frame
     * across the DMA halves. The last byte must play before completion.
     */
    for (unknown=0; unknown<2; unknown++) {
        input.length = 6; input.offset = 0; input.chunk = 8;
        input.failAt = 0xffff; input.invalid = 0;
        source.format.blockAlign = 2;
        source.pcmBytes = unknown ? BSN_PCM_LENGTH_UNKNOWN : 6;
        Reset(&source);
        konvRateRed = 2; playLen2 = 8;
        secondOffset = secondKOffset = 1; secondFree--;
        dma[0] = 0x80;
        assert(BSNWPlay(&source.format, 0, 0) == BSNW_STATUS_OK);
        assert(playedBytes == 6 && playedCount >= 5);
        assert(played[0] == 0x80 && played[1] == 0 && played[2] == 1);
        assert(played[3] == 4 && played[4] == 5);
    }
    source.format.blockAlign = 1;
    /* Check the real size policy after the driver's 64K boundary split.
     * Test all paragraph addresses. Address 0xe910 caused the old failure.
     */
    for (i=0; i<3; i++) {
        format.sampleRate = 11025UL << i;
        for (align=1; align<=4; align*=2) {
            format.avgBytesPerSecond = format.sampleRate * align;
            minimum = (format.avgBytesPerSecond * 2 + 59) / 60;
            requested = BSNWDetermineSecondaryBufferLength(&format, 8192);
            for (physical=0; physical<65536UL; physical+=16) {
                actual = requested;
                if (physical + actual >= 65536UL) {
                    /* Match BSDMAGrenzen: keep the larger part. If it is
                     * after the boundary, skip one more 16-byte paragraph.
                     */
                    tail = physical + actual - 65536UL;
                    actual = (actual/2 < tail) ? tail-16 : actual-tail;
                }
                assert(actual / 2 >= minimum);
            }
        }
    }

    /* DMA continues while a reader blocks; retain every source byte. */
    for (unknown=0; unknown<2; unknown++) {
        for (i=1; i<=3; i++) {
            input.length = 96; input.offset = 0; input.chunk = 8;
            input.failAt = 0xffff; input.invalid = 0;
            source.pcmBytes = unknown ? BSN_PCM_LENGTH_UNKNOWN : input.length;
            Reset(&source); delayRead = i;
            assert(BSNWPlay(&source.format, 0, 0) == BSNW_STATUS_OK);
            assert(playedBytes == 96 && input.offset == 96 && timeOutCounter);
            output = 0;
            for (frame=0; frame<playedCount; frame++) {
                /* Input is 0..95. Only gaps can contain 8-bit silence. */
                if (played[frame] != 0x80)
                    assert(played[frame] == output++);
            }
            assert(output == 96);
        }
    }
    /* If an IRQ occurs during the copy, keep and retry the same refill. */
    input.length = 96; input.offset = 0; input.chunk = 8;
    source.pcmBytes = input.length;
    Reset(&source); delayCopy = 1;
    assert(BSNWPlay(&source.format, 0, 0) == BSNW_STATUS_OK);
    assert(playedBytes == 96 && timeOutCounter && input.offset == 96);
    assert(played[playedCount-1] == 95);

    /* Count IRQs which arrive before the first option call returns. */
    input.offset = 0;
    Reset(&source); delayStart = 3;
    assert(BSNWPlay(&source.format, 0, 0) == BSNW_STATUS_OK);
    assert(playedBytes == 96 && timeOutCounter && input.offset == 96);

    /* More than 256 halves test the normal byte-counter change 255 -> 0. */
    input.length = 1100; input.offset = 0;
    source.pcmBytes = input.length;
    Reset(&source);
    assert(BSNWPlay(&source.format, 0, 0) == BSNW_STATUS_OK);
    assert(playedBytes == 1100 && ticks > 256 && !timeOutCounter);
    for (i=0; i<1100; i++) assert(played[i] == (byte)i);

    input.offset = 0;
    /* Failure of the extra allocation must stop and free the DMA buffer. */
    Reset(&source); failRefill = 1;
    assert(BSNWPlay(&source.format, 0, 0) == BSNW_MEMORY_ERROR);
    assert(!started && stopped == 1);
    failRefill = 0;
#ifdef __WATCOMC__
    /* int must be native 16-bit for the production signed-sample converter. */
    assert(sizeof(int) == 2 && sizeof(long) == 4);
    for (channels=1; channels<=2; channels++) {
        for (outputChannels=1; outputChannels<=channels; outputChannels++) {
            source.format.blockAlign = channels * 2;
            for (rate=1; rate<=3; rate++) {
                for (length=0; length<70; length++) {
                    for (chunk=1; chunk<=7; chunk++) {
                        for (unknown=0; unknown<2; unknown++) {
                            input.length = length * source.format.blockAlign;
                            input.offset = 0; input.chunk = chunk * source.format.blockAlign;
                            input.failAt = 0xffff; input.invalid = 0;
                            source.pcmBytes = unknown ? BSN_PCM_LENGTH_UNKNOWN : input.length+12;
                            Reset(&source);
                            playCacheLen -= playCacheLen % (pcmBlockAlign * rate);
                            cacheFree = playCacheLen;
                            konvBitsRed = 2; konvChanRed = channels/outputChannels;
                            konvRateRed = (byte)rate;
                            playLen2 = secBufL2 * konvBitsRed * konvChanRed * rate;
                            assert(BSNWPlay(&source.format, 0, 0) == BSNW_STATUS_OK);
                            assert(input.offset == input.length && playedBytes == input.length);
                            output = 0;
                            for (frame=0; frame<length; frame+=rate) {
                                for (channel=0; channel<outputChannels; channel++) {
                                    offset = frame * pcmBlockAlign + channel * 2;
                                    sample = (sword)((word)(byte)offset |
                                                    ((word)(byte)(offset+1)<<8));
                                    if (konvChanRed > 1) {
                                        right = (sword)((word)(byte)(offset+2) |
                                                       ((word)(byte)(offset+3)<<8));
                                        sample = (sample + right) / 2;
                                    }
                                    if (played[output] != (byte)(128 + (sample>>8))) {
                                        printf("channels=%u out=%u rate=%u frames=%u chunk=%u unknown=%u output=%u actual=%u expected=%u\n",
                                            channels, outputChannels, rate, length, chunk, unknown,
                                            output, played[output], (byte)(128 + (sample>>8)));
                                        fflush(stdout);
                                    }
                                    assert(played[output++] == (byte)(128 + (sample>>8)));
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    source.format.blockAlign = 1;
#endif
    /* Stop from a different execution context, then reuse the playback loop. */
    input.length = 100; input.offset = 0; input.chunk = 8;
    input.failAt = 0xffff; input.invalid = 0;
    source.pcmBytes = BSN_PCM_LENGTH_UNKNOWN;
    Reset(&source); stopAtTick = 2;
    assert(BSNWPlay(&source.format, 0, 0) == BSNW_ABORT && stopped == 1);
    input.offset = 0; stopAtTick = 0;
    Reset(&source);
    assert(BSNWPlay(&source.format, 0, 0) == BSNW_STATUS_OK && stopped == 1);
    /* Error after playback starts must not turn into successful EOF. */
    input.length = 100; input.offset = 0; input.chunk = 8;
    /* Initial halves use eight bytes. Fail the first read after start. */
    input.failAt = 8; input.invalid = 0;
    source.pcmBytes = BSN_PCM_LENGTH_UNKNOWN;
    Reset(&source);
    assert(BSNWPlay(&source.format, 0, 0) == BSNW_SOURCE_ERROR);
    assert(started == 1 && stopped == 1);
    input.offset = 0; input.failAt = 0xffff;
    Reset(&source);
    fullLen = 0xfffffffeUL;
    assert(BSNWLoadCache(cache) == BSNW_SOURCE_ERROR);
    assert(fullLen == 0xfffffffeUL);
    input.offset = 0; input.invalid = 1;
    Reset(&source);
    assert(BSNWLoadCache(cache) == BSNW_SOURCE_ERROR);
    input.invalid = 2;
    source.format.blockAlign = 4;
    Reset(&source);
    assert(BSNWLoadCache(cache) == BSNW_SOURCE_ERROR);
    puts("PCM reads, conversion, drain, errors, DMA boundaries, late refills: PASS");
    return 0;
}

#else
static FILE *inputP;
dword FileSize(FileHandle file)
{
    long pos, end;
    (void)file;
    pos = ftell(inputP); assert(!fseek(inputP, 0, SEEK_END));
    end = ftell(inputP); assert(!fseek(inputP, pos, SEEK_SET));
    return (dword)end;
}
dword FilePos(FileHandle file, dword offset, word mode)
{
    (void)file; (void)mode;
    return fseek(inputP, (long)offset, SEEK_SET) ? 0xffffffffUL : offset;
}
word FileRead(FileHandle file, void *destP, word count, word flags)
{
    (void)file; (void)flags;
    return (word)fread(destP, 1, count, inputP);
}
int main(int argc, char **argv)
{
    BSNMP3Dec mp3;
    BSNWav wav;
    BSNPcmSource *sourceP;
    int result;

    assert(argc == 4);
    inputP = fopen(argv[2], "rb"); assert(inputP);
    playOutputP = fopen(argv[3], "wb"); assert(playOutputP);
    if (argv[1][0] == 'm') {
        assert(BSNMP3DecOpenEx(&mp3, 1,
               strstr(argv[1], "half") ? BSN_MP3_HALF_RATE : 0) == BSNW_STATUS_OK);
        sourceP = &mp3.source;
    } else {
        assert(BSNWavOpen(&wav, 1) == BSNW_STATUS_OK);
        sourceP = &wav.source;
    }
    playCacheLen = 8192;
    if (sourceP->format.sampleRate < 44200) {
        /* Failed preparation must not insert a stereo-toggle sample at NULL. */
        stereoToggle = 1;
        failCache = 1;
        assert(BSNPcmPlay(sourceP, 0, 0) == BSNW_MEMORY_ERROR);
        failCache = 0; failDMA = 1;
        assert(BSNPcmPlay(sourceP, 0, 0) == BSNW_MEMORY_ERROR);
        failDMA = 0; stereoToggle = strchr(argv[1], '-') != (void *)0;
        assert(!started);
    }
    result = BSNPcmPlay(sourceP, 0, 0);
    if (sourceP->format.sampleRate >= 44200) {
        assert(result == BSNW_UNKNOWN_WAVE_FORMAT && !started);
    } else {
        assert(result == BSNW_STATUS_OK && started && stopped);
        assert(playedBytes >= fullLen && playedBytes-fullLen < playLen2);
        assert(playCacheLen == 8192);
    }
    if (argv[1][0] == 'm') BSNMP3DecClose(&mp3);
    else BSNWavClose(&wav);
    assert(!fseek(inputP, 0, SEEK_SET));
    assert(!fclose(inputP) && !fclose(playOutputP));
    puts(result == BSNW_UNKNOWN_WAVE_FORMAT ? "Unsupported PCM output rate rejected: PASS" :
         "Public decoder -> BSNPcmPlay -> common DMA buffer path: PASS");
    return result == BSNW_UNKNOWN_WAVE_FORMAT ? 2 : 0;
}
#endif
