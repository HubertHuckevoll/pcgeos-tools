#ifndef MP3INT_H
#define MP3INT_H
#ifdef MP3_HOST_TEST
#include "Tests/host.h"
#else
#include <geos.h>
#include <heap.h>
#include <ec.h>
#include <Ansi/string.h>
#include "mp3dec.h"
#endif
#include "core/pvmp3_framedecoder.h"
#include "core/s_tmp3dec_file.h"
#ifdef DO_ERROR_CHECKING
typedef enum Warnings {
    MP3DEC_DEBUG_CONTEXT_READY,
    MP3DEC_DEBUG_FIRST_FRAME
} Warnings;
#endif
#define MP3_INPUT_SIZE 2048

/* ATTENTION: OpenCORE's contiguous state is 21652 bytes with Watcom -ml
 * -zp1. Splitting the channel arrays into handles requires algorithm access
 * changes; keep this single below-32-KB block until that work is justified.
 */
typedef struct {
    MemHandle inputH;
    MemHandle pcmH;
    word used;
    word pending;
    word pcmOffset;
    word ended;
    word started;
    word terminal;
    word damaged;
    word halfRate;
    word sourceRate;
    dword skip;
    Mp3DecFormat format;
    tPVMP3DecoderExternal ext;
    tmp3dec_file core;
} Mp3Decoder;
#ifdef __GEOS__
typedef char Mp3CoreSizeCheck[sizeof(tmp3dec_file) == 21652 ? 1 : -1];
typedef char Mp3StateSizeCheck[sizeof(Mp3Decoder) < 32768U ? 1 : -1];
#endif
#endif
