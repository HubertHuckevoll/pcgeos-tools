#ifdef __WATCOMC__
#pragma code_seg("MP3ApiCode")
#endif
#include "mp3int.h"

static void _pascal
Mp3InitCore(Mp3Decoder *decoderP)
{
    memset(&decoderP->core, 0, sizeof(decoderP->core));
    memset(&decoderP->ext, 0, sizeof(decoderP->ext));
    pvmp3_InitDecoder(&decoderP->ext, &decoderP->core);
    decoderP->ext.halfRate = decoderP->halfRate;
    decoderP->core.mainDataStream.pBuffer = (void *)0;
}

Mp3DecResult _pascal _export
Mp3DecCreate(Mp3DecHandle *decoderHP)
{
    Mp3DecHandle decoderH;
    Mp3Decoder *decoderP;
    word failed;

    if (decoderHP == (void *)0) return MP3DEC_BAD_ARGUMENT;
    *decoderHP = NullHandle;
    decoderH = MemAlloc(sizeof(Mp3Decoder), HF_SWAPABLE, HAF_ZERO_INIT);
    if (decoderH == NullHandle) return MP3DEC_NO_MEMORY;
    decoderP = MemLock(decoderH);
    decoderP->inputH = MemAlloc(MP3_INPUT_SIZE, HF_SWAPABLE, HAF_ZERO_INIT);
    decoderP->pcmH = MemAlloc(MP3DEC_MAX_PCM_BYTES, HF_SWAPABLE, HAF_ZERO_INIT);
    failed = !decoderP->inputH || !decoderP->pcmH;
    if (!failed) Mp3InitCore(decoderP);
    MemUnlock(decoderH);
    if (failed) {
        Mp3DecDestroy(decoderH);
        return MP3DEC_NO_MEMORY;
    }
    *decoderHP = decoderH;
#ifdef DO_ERROR_CHECKING
    EC_WARNING(MP3DEC_DEBUG_CONTEXT_READY);
#endif
    return MP3DEC_PCM;
}

void _pascal _export
Mp3DecDestroy(Mp3DecHandle decoderH)
{
    Mp3Decoder *decoderP;

    if (decoderH == NullHandle) return;
    decoderP = MemLock(decoderH);
    if (decoderP->pcmH) MemFree(decoderP->pcmH);
    if (decoderP->inputH) MemFree(decoderP->inputH);
    MemUnlock(decoderH);
    MemFree(decoderH);
}

Mp3DecResult _pascal _export
Mp3DecReset(Mp3DecHandle decoderH)
{
    Mp3Decoder *decoderP;
    MemHandle inputH, pcmH;
    word halfRate;

    if (decoderH == NullHandle) return MP3DEC_BAD_ARGUMENT;
    decoderP = MemLock(decoderH);
    inputH = decoderP->inputH;
    pcmH = decoderP->pcmH;
    halfRate = decoderP->halfRate;
    memset(decoderP, 0, sizeof(*decoderP));
    decoderP->inputH = inputH;
    decoderP->pcmH = pcmH;
    decoderP->halfRate = halfRate;
    Mp3InitCore(decoderP);
    MemUnlock(decoderH);
    return MP3DEC_PCM;
}

Mp3DecResult _pascal _export
Mp3DecFeed(Mp3DecHandle decoderH, const byte *dataP, word size,
           word flags, word *acceptedP)
{
    Mp3Decoder *decoderP;
    byte *inputP;
    word accepted;
    Mp3DecResult result;

    if (acceptedP == (void *)0) return MP3DEC_BAD_ARGUMENT;
    *acceptedP = 0;
    if (decoderH == NullHandle || (size && dataP == (void *)0) ||
        (flags & ~MP3DEC_FEED_END)) return MP3DEC_BAD_ARGUMENT;
    decoderP = MemLock(decoderH);
    if (decoderP->ended || decoderP->terminal) {
        MemUnlock(decoderH);
        return MP3DEC_BAD_ARGUMENT;
    }
    accepted = MP3_INPUT_SIZE - decoderP->used;
    if (accepted > size) accepted = size;
    if (accepted) {
        inputP = MemLock(decoderP->inputH);
        memcpy(inputP + decoderP->used, dataP, accepted);
        MemUnlock(decoderP->inputH);
        decoderP->used += accepted;
    }
    *acceptedP = accepted;
    result = accepted < size ? MP3DEC_INPUT_FULL : MP3DEC_PCM;
    if (accepted == size && (flags & MP3DEC_FEED_END)) decoderP->ended = 1;
    MemUnlock(decoderH);
    return result;
}

Mp3DecResult _pascal _export
Mp3DecGetFormat(Mp3DecHandle decoderH, Mp3DecFormat *formatP)
{
    Mp3Decoder *decoderP;

    if (formatP == (void *)0) return MP3DEC_BAD_ARGUMENT;
    memset(formatP, 0, sizeof(*formatP));
    if (decoderH == NullHandle) return MP3DEC_BAD_ARGUMENT;
    decoderP = MemLock(decoderH);
    *formatP = decoderP->format;
    MemUnlock(decoderH);
    return formatP->channels ? MP3DEC_PCM : MP3DEC_NEED_INPUT;
}

/* Consume only bytes already owned by this instance. */
static void _pascal
Mp3Consume(Mp3Decoder *decoderP, byte *inputP, word count)
{
    decoderP->used -= count;
    memmove(inputP, inputP + count, decoderP->used);
}

static Mp3DecResult _pascal
Mp3Missing(Mp3Decoder *decoderP)
{
    if (!decoderP->ended) return MP3DEC_NEED_INPUT;
    if (decoderP->used || decoderP->skip) {
        decoderP->terminal = MP3DEC_TRUNCATED;
        return MP3DEC_TRUNCATED;
    }
    return MP3DEC_END;
}

/* One complete frame, or bounded metadata/sync progress. */
static Mp3DecResult _pascal
Mp3DecodeFrame(Mp3Decoder *decoderP, byte *inputP, sword *pcmP)
{
    static const word rates[3] = {44100, 48000, 32000};
    static const word br1[16] = {0,32,40,48,56,64,80,96,112,128,
                                 160,192,224,256,320,0};
    static const word br2[16] = {0,8,16,24,32,40,48,56,64,80,
                                 96,112,128,144,160,0};
    word version, index, frequency, rate, size, channels, count, changed;
    word outputRate;
    dword tagSize, apeVersion;
    ERROR_CODE error;

    if (!decoderP->started) {
        if (decoderP->used < 3) return Mp3Missing(decoderP);
        if (!memcmp(inputP, "ID3", 3)) {
            if (decoderP->used < 10) return Mp3Missing(decoderP);
            if (inputP[3] < 2 || inputP[3] > 4 || inputP[4] == 255 ||
                ((inputP[6] | inputP[7] | inputP[8] | inputP[9]) & 128)) {
                decoderP->terminal = MP3DEC_FATAL;
                return MP3DEC_FATAL;
            }
            tagSize = ((dword)inputP[6] << 21) | ((dword)inputP[7] << 14) |
                      ((dword)inputP[8] << 7) | inputP[9];
            if (inputP[3] == 4 && (inputP[5] & 16)) tagSize += 10;
            decoderP->skip = tagSize;
            Mp3Consume(decoderP, inputP, 10);
        }
        decoderP->started = 1;
    }
    if (!decoderP->skip && decoderP->format.channels && decoderP->used &&
        !memcmp(inputP, "APETAGEX", decoderP->used < 8 ? decoderP->used : 8)) {
        if (decoderP->used < 32) return Mp3Missing(decoderP);
        apeVersion = (dword)inputP[8] | ((dword)inputP[9] << 8) |
                     ((dword)inputP[10] << 16) | ((dword)inputP[11] << 24);
        tagSize = (dword)inputP[12] | ((dword)inputP[13] << 8) |
                  ((dword)inputP[14] << 16) | ((dword)inputP[15] << 24);
        if ((apeVersion != 1000 && apeVersion != 2000) ||
            tagSize < 32 || tagSize > 0x01000000UL) {
            decoderP->terminal = MP3DEC_FATAL;
            return MP3DEC_FATAL;
        }
        /* A header's size includes items/footer but excludes this header.
         * A footer encountered while scanning has only its own 32 bytes left.
         */
        if (inputP[23] & 32) decoderP->skip = tagSize;
        Mp3Consume(decoderP, inputP, 32);
    }
    if (decoderP->skip) {
        count = decoderP->used;
        if (decoderP->skip < count) count = (word)decoderP->skip;
        Mp3Consume(decoderP, inputP, count);
        decoderP->skip -= count;
        if (decoderP->skip) return Mp3Missing(decoderP);
    }
    if (decoderP->used >= 3 && !memcmp(inputP, "TAG", 3) &&
        decoderP->format.channels) {
        if (decoderP->used < 128) return Mp3Missing(decoderP);
        Mp3Consume(decoderP, inputP, 128);
    }
    count = 0;
    while (decoderP->used - count >= 4) {
        version = (inputP[count+1] >> 3) & 3;
        index = inputP[count+2] >> 4;
        frequency = (inputP[count+2] >> 2) & 3;
        if (inputP[count] == 255 && (inputP[count+1] & 0xe6) == 0xe2 &&
            version != 1 && index && index != 15 && frequency != 3) break;
        count++;
    }
    if (count) {
        Mp3Consume(decoderP, inputP, count);
        Mp3InitCore(decoderP);
        return MP3DEC_RECOVERABLE;
    }
    if (decoderP->used < 4) return Mp3Missing(decoderP);
    rate = rates[frequency] >> (version == 3 ? 0 : version == 2 ? 1 : 2);
    size = (word)((version == 3 ? 144000UL : 72000UL) *
                  (version == 3 ? br1[index] : br2[index]) / rate) +
                  ((inputP[2] >> 1) & 1);
    if (decoderP->used < size) return Mp3Missing(decoderP);
    channels = (inputP[3] >> 6) == 3 ? 1 : 2;
    /* Only MPEG-1 has the 32/44.1/48 kHz rates supported by this mode. */
    outputRate = decoderP->halfRate && version == 3 ? rate >> 1 : rate;
    changed = decoderP->format.channels &&
              (decoderP->format.channels != channels ||
               decoderP->sourceRate != rate);
    decoderP->core.mainDataStream.pBuffer = decoderP->core.mainDataBuffer;
    decoderP->ext.pInputBuffer = inputP;
    decoderP->ext.inputBufferCurrentLength = size;
    decoderP->ext.inputBufferUsedLength = 0;
    decoderP->ext.pOutputBuffer = pcmP;
    decoderP->ext.outputFrameSize = MP3DEC_MAX_PCM_BYTES / 2;
    decoderP->ext.crcEnabled = 1;
#ifdef DO_ERROR_CHECKING
    if (!decoderP->format.channels) {
        EC_WARNING(MP3DEC_DEBUG_FIRST_FRAME);
    }
#endif
    error = pvmp3_framedecoder(&decoderP->ext, &decoderP->core);
    decoderP->core.mainDataStream.pBuffer = (void *)0;
    decoderP->core.inputStream.pBuffer = (void *)0;
    decoderP->ext.pInputBuffer = (void *)0;
    decoderP->ext.pOutputBuffer = (void *)0;
    Mp3Consume(decoderP, inputP, size);
    if (decoderP->ext.inputBufferUsedLength &&
        decoderP->ext.outputFrameSize > 0 &&
        decoderP->ext.outputFrameSize <= MP3DEC_MAX_PCM_BYTES / 2 &&
        (error == NO_DECODING_ERROR || error == NO_ENOUGH_MAIN_DATA_ERROR)) {
        decoderP->pending = (word)decoderP->ext.outputFrameSize / channels;
        decoderP->pcmOffset = 0;
        decoderP->sourceRate = rate;
        decoderP->format.sampleRate = outputRate;
        decoderP->format.channels = channels;
        decoderP->damaged = error != NO_DECODING_ERROR;
        return changed ? MP3DEC_FORMAT_CHANGED : MP3DEC_PCM;
    }
    Mp3InitCore(decoderP);
    return MP3DEC_RECOVERABLE;

}

Mp3DecResult _pascal _export
Mp3DecReadPCM(Mp3DecHandle decoderH, sword *pcmP, word byteCapacity,
              word *framesP, Mp3DecFormat *formatP)
{
    Mp3Decoder *decoderP;
    byte *inputP;
    sword *bufferP;
    word count, bytes;
    Mp3DecResult result;

    if (framesP == (void *)0 || formatP == (void *)0)
        return MP3DEC_BAD_ARGUMENT;
    *framesP = 0;
    memset(formatP, 0, sizeof(*formatP));
    if (decoderH == NullHandle || (byteCapacity && pcmP == (void *)0))
        return MP3DEC_BAD_ARGUMENT;
    decoderP = MemLock(decoderH);
    result = decoderP->terminal;
    if (!result && !decoderP->pending) {
        inputP = MemLock(decoderP->inputH);
        bufferP = MemLock(decoderP->pcmH);
        result = Mp3DecodeFrame(decoderP, inputP, bufferP);
        MemUnlock(decoderP->pcmH);
        MemUnlock(decoderP->inputH);
    }
    *formatP = decoderP->format;
    if (result == MP3DEC_PCM && decoderP->pending) {
        count = byteCapacity / (decoderP->format.channels * 2);
        if (count > decoderP->pending) count = decoderP->pending;
        if (!count) {
            result = MP3DEC_OUTPUT_SMALL;
        } else {
            bytes = count * decoderP->format.channels * 2;
            bufferP = MemLock(decoderP->pcmH);
            memcpy(pcmP, (byte *)bufferP + decoderP->pcmOffset, bytes);
            MemUnlock(decoderP->pcmH);
            decoderP->pcmOffset += bytes;
            decoderP->pending -= count;
            *framesP = count;
            if (decoderP->damaged) result = MP3DEC_RECOVERABLE;
        }
    }
    MemUnlock(decoderH);
    return result;
}
