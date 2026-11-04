/* Pull-based PCM sources for PC/GEOS Ensemble (bsnwav.lib). */
#ifndef __BSNWAV_H
#define __BSNWAV_H

#include <geos.h>
#include <file.h>

#define BSN_PCM_LENGTH_UNKNOWN 0xFFFFFFFFUL
#define BSN_PCM_READ_ERROR     0xFFFF


/* Shared playback flags and legacy-compatible result codes. */
#define BSNW_SHOW_STATUS        0x01
#define BSNW_WAIT_FOR_FREE      0x02
#define BSNW_SHOW_ERROR_MSG     0x04
#define BSNW_PLAY_LOOP          0x08
#define	BSNW_TEST_ONLY		0x10
#define BSNW_PLAY_POS		0x20
#define BSNW_STATUS_OK          0
#define BSNW_ABORT              1
#define BSNW_TIMEOUT            2
#define BSNW_HARDWARE_NOT_READY 3
#define BSNW_MEMORY_ERROR       4
#define BSNW_NOT_FREE           5
#define BSNW_UNKNOWN_WAVE_FORMAT 6
#define BSNW_WRONG_DRIVER       7
#define BSNW_SOURCE_ERROR       8
#define BSNW_PLAY_FINISHED      255

typedef struct {
    dword sampleRate;
    word channels;
    word bitsPerSample;
    word blockAlign;
    dword avgBytesPerSecond;
} BSNPcmFormat;

/* Far Pascal callback, invoked through ProcCallFixedOrMovable_pascal.
 * Return complete interleaved PCM frames: unsigned 8-bit or signed 16-bit.
 * A positive count is at most maxBytes and 0xfffe; short reads are normal.
 * Zero means EOF; BSN_PCM_READ_ERROR means failure. Format is constant.
 * File I/O and decoding run synchronously on the calling playback thread.
 */
typedef word _pascal _export BSNPcmReadProc(void *contextP, void *destP,
                                          word maxBytes);

typedef struct {
    BSNPcmFormat format;
    dword pcmBytes;              /* Expected length, or LENGTH_UNKNOWN. */
    BSNPcmReadProc *readP;       /* GEOS virtual far code pointer. */
    void *contextP;
} BSNPcmSource;

/* Blocking; flags, parent and results use the legacy BSNWavePlayPCM rules.
 * The descriptor and context are borrowed and must remain valid/locked
 * throughout playback. Store handles in decoder contexts; never retain a
 * pointer into an unlocked movable block. No file handle is transferred.
 * Playback accounting supports less than 4 GiB of decoded PCM per session.
 * Independent readers may be used without playback or sound hardware.
 */
extern int _pascal _export BSNPcmPlay(BSNPcmSource *sourceP,
                                     word flags, optr parent);
/* Caller-owned reader context. Close never closes file. */
typedef struct {
    BSNPcmSource source;
    FileHandle file;
    dword dataOffset;
    dword remaining;
} BSNWav;

extern int _pascal _export BSNWavOpen(BSNWav *wavP, FileHandle file);
extern word _pascal _export BSNWavReadPCM(void *contextP, void *destP,
                                         word maxBytes);
extern void _pascal _export BSNWavClose(BSNWav *wavP);
/* Three movable decoder blocks; no extra input or playback buffer.
 * Open probes with zero PCM capacity and retains the first decoded frame.
 * Open/Read/Close are serialized per context. File is borrowed.
 * Close a live context before opening another file in it.
 * status records a terminal source error or unsupported format change.
 */
typedef struct {
    BSNPcmSource source;
    FileHandle file;
    MemHandle decoderH;
    word status;
    word damaged; /* Recovery occurred; strict converters may reject it. */
} BSNMP3Dec;
extern int _pascal _export BSNMP3DecOpen(BSNMP3Dec *mp3P, FileHandle file);
/* Optional lower CPU use. MPEG-1 outputs half rate; lower rates stay normal.
 * Set options at Open, before probing. Unknown option bits are rejected.
 * Existing Open selects normal decoding. The context layout is unchanged.
 */
#define BSN_MP3_HALF_RATE 0x0001
extern int _pascal _export BSNMP3DecOpenEx(BSNMP3Dec *mp3P, FileHandle file,
                                          word options);
extern word _pascal _export BSNMP3DecReadPCM(void *contextP, void *destP,
                                            word maxBytes);
extern void _pascal _export BSNMP3DecClose(BSNMP3Dec *mp3P);
#endif
