/* File-backed pull API against the relocating heap and original core. */
#define MP3_HEAP_ONLY
#include "stream.c"
#include <bsnwav.h>
static FILE *files[3];
static word inputChunk, failRead;
static unsigned reads;
word FileRead(FileHandle file, void *destP, word size, word flags)
{
    (void)flags;
    assert(file && file < 3 && files[file]);
    assert(++reads < 10000000); /* Also allow one-byte reads of long tracks. */
    if (failRead) return 0xffff;
    if (size > inputChunk) size = inputChunk;
    return (word)fread(destP, 1, size, files[file]);
}
dword FilePos(FileHandle file, dword offset, word mode)
{
    assert(file && file < 3 && files[file] && mode == FILE_POS_START);
    return fseek(files[file], (long)offset, SEEK_SET) ? 0xffffffffUL : offset;
}
static void CheckFree(void)
{
    word h;
    for (h=1; h<16; h++) assert(!blocks[h].dataP);
}
int main(int argc, char **argv)
{
    BSNMP3Dec mp3, other;
    FILE *outputP;
    byte pcm[511], otherPCM[4];
    word count, second, i, expectError, options;
    unsigned long total;
    assert(argc == 4 || argc == 5);
    expectError = argc == 5 && strstr(argv[4], "error") != (void *)0;
    options = argc == 5 && strstr(argv[4], "half") ? BSN_MP3_HALF_RATE : 0;
    inputChunk = (word)atoi(argv[3]);
    files[1] = fopen(argv[1], "rb"); assert(files[1]);
    files[2] = fopen(argv[1], "rb"); assert(files[2]);
    for (i=1; i<=3; i++) {
        failAllocation = i; allocation = 0;
        assert(BSNMP3DecOpenEx(&mp3, 1, options) == BSNW_MEMORY_ERROR);
        BSNMP3DecClose(&mp3); CheckFree();
    }
    failAllocation = 0;
    failRead = 1;
    assert(BSNMP3DecOpenEx(&mp3, 1, options) == BSNW_SOURCE_ERROR);
    BSNMP3DecClose(&mp3); CheckFree();
    failRead = 0;
    assert(BSNMP3DecOpenEx(&mp3, 1, 2) == BSNW_SOURCE_ERROR);
    CheckFree();
    assert(BSNMP3DecOpenEx(&mp3, 1, options) == BSNW_STATUS_OK);
    assert(BSNMP3DecOpen(&other, 2) == BSNW_STATUS_OK);
    /* The option belongs to one context. The other keeps normal output. */
    assert(mp3.source.format.sampleRate ==
           (options && other.source.format.sampleRate >= 32000 ?
            other.source.format.sampleRate / 2 : other.source.format.sampleRate));
    assert(mp3.source.format.channels == other.source.format.channels);
    assert(mp3.source.pcmBytes == BSN_PCM_LENGTH_UNKNOWN);
    assert(mp3.source.format.bitsPerSample == 16);
    assert(mp3.source.format.channels == 1 || mp3.source.format.channels == 2);
    /* Too small retains the probed first frame for a later call. */
    assert(BSNMP3DecReadPCM(&mp3, pcm, 1) == BSN_PCM_READ_ERROR);
    outputP = fopen(argv[2], "wb"); assert(outputP);
    total = 0;
    while ((count = mp3.source.readP(&mp3, pcm, sizeof(pcm))) != 0) {
        if (count == BSN_PCM_READ_ERROR) break;
        assert(count <= sizeof(pcm));
        assert(!(count % mp3.source.format.blockAlign));
        assert(fwrite(pcm, 1, count, outputP) == count);
        total += count;
        /* Independent state, different pacing and capacity. */
        second = BSNMP3DecReadPCM(&other, otherPCM, sizeof(otherPCM));
        if (!expectError) assert(second != BSN_PCM_READ_ERROR);
    }
    assert(total);
    if (expectError) {
        assert(count == BSN_PCM_READ_ERROR);
        assert(mp3.status == BSNW_SOURCE_ERROR ||
               mp3.status == BSNW_UNKNOWN_WAVE_FORMAT);
    } else {
        assert(count == 0);
        assert(BSNMP3DecReadPCM(&mp3, pcm, sizeof(pcm)) == 0);
    }
    assert(fclose(outputP) == 0);
    BSNMP3DecClose(&mp3); BSNMP3DecClose(&mp3);
    BSNMP3DecClose(&other); CheckFree();
    /* A file error after probing/draining pending PCM remains an error. */
    assert(BSNMP3DecOpenEx(&mp3, 1, options) == BSNW_STATUS_OK);
    /* Reset keeps the output mode, although it clears buffered PCM/input. */
    assert(Mp3DecReset(mp3.decoderH) == MP3DEC_PCM);
    assert(FilePos(1, 0, FILE_POS_START) == 0);
    count = BSNMP3DecReadPCM(&mp3, pcm, sizeof(pcm));
    assert(count && count != BSN_PCM_READ_ERROR);
    failRead = 1;
    while ((count = BSNMP3DecReadPCM(&mp3, pcm, sizeof(pcm))) != BSN_PCM_READ_ERROR)
        assert(count);
    assert(mp3.status == BSNW_SOURCE_ERROR);
    failRead = 0;
    BSNMP3DecClose(&mp3); CheckFree();
    /* Both borrowed file handles remain usable. */
    assert(fseek(files[1], 0, SEEK_SET) == 0);
    assert(fseek(files[2], 0, SEEK_SET) == 0);
    fclose(files[1]); fclose(files[2]);
    puts("MP3 pull, retained first PCM, partial I/O, relocation, cleanup: PASS");
    return 0;
}
