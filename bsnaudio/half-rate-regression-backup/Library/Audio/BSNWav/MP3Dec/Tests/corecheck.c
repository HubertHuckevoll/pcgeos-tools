/* Compile with either the unmodified C++ core or the adapted C core.
 * This deliberately bypasses both streaming wrappers to compare core PCM.
 */
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "pvmp3_framedecoder.h"
#include "s_tmp3dec_file.h"

static tmp3dec_file state;
static unsigned char input[2048];
static int16 output[2304];

int main(int argc, char **argvP)
{
    static const unsigned rates[3] = {44100,48000,32000};
    static const unsigned br1[16] = {0,32,40,48,56,64,80,96,112,128,
                                     160,192,224,256,320,0};
    static const unsigned br2[16] = {0,8,16,24,32,40,48,56,64,80,
                                     96,112,128,144,160,0};
    tPVMP3DecoderExternal ext;
    FILE *sourceP, *destP;
    long offset = 0;
    unsigned version, index, frequency, rate, size, channels;
    unsigned decoded = 0;
    size_t got;
    ERROR_CODE error;

    assert(argc == 3);
#ifdef __WATCOMC__
    assert(sizeof(state) == 21652 && sizeof(void *) == 4 && sizeof(int) == 2 && sizeof(Mp3HuffProc) == 4);
#endif
    sourceP = fopen(argvP[1], "rb");
    destP = fopen(argvP[2], "wb");
    assert(sourceP && destP);
    memset(&ext, 0, sizeof(ext));
    pvmp3_InitDecoder(&ext, &state);
#ifdef MP3_HALF_RATE_TEST
    ext.halfRate = 1;
#endif
    for (;;) {
        assert(fseek(sourceP, offset, SEEK_SET) == 0);
        got = fread(input, 1, 4, sourceP);
        if (got < 4) break;
        version = (input[1] >> 3) & 3;
        index = input[2] >> 4;
        frequency = (input[2] >> 2) & 3;
        if (input[0] != 255 || (input[1] & 0xe6) != 0xe2 ||
            version == 1 || !index || index == 15 || frequency == 3) {
            offset++;
            continue;
        }
        rate = rates[frequency] >> (version == 3 ? 0 :
                                   version == 2 ? 1 : 2);
        size = (unsigned)((version == 3 ? 144000UL : 72000UL) *
               (version == 3 ? br1[index] : br2[index]) / rate) +
               ((input[2] >> 1) & 1);
        channels = (input[3] >> 6) == 3 ? 1 : 2;
        assert(size >= 4 && size <= 1441);
        memset(input + 4, 0, sizeof(input) - 4);
        if (fread(input + 4, 1, size - 4, sourceP) != size - 4) break;
        ext.pInputBuffer = input;
        ext.inputBufferCurrentLength = size;
        ext.inputBufferUsedLength = 0;
        ext.pOutputBuffer = output;
        ext.outputFrameSize = 2304;
        ext.crcEnabled = 1;
        error = pvmp3_framedecoder(&ext, &state);
#ifdef MP3_HALF_RATE_TEST
        if (version == 3) rate >>= 1;
#endif
        if (error == NO_DECODING_ERROR ||
            (error == NO_ENOUGH_MAIN_DATA_ERROR && ext.inputBufferUsedLength)) {
            assert(ext.outputFrameSize > 0 && ext.outputFrameSize <= 2304);
            assert(ext.num_channels == channels && ext.samplingRate == rate);
            assert(fwrite(output, sizeof(int16), ext.outputFrameSize, destP) ==
                   (size_t)ext.outputFrameSize);
            decoded++;
        }
        offset += size;
    }
    assert(fclose(sourceP) == 0 && fclose(destP) == 0);
    if (!decoded) return 2;
    fprintf(stderr, "%u frames; state %lu bytes\n", decoded,
            (unsigned long)sizeof(state));
    return 0;
}
