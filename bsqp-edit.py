from pathlib import Path
base=Path('/home/konstantinmeyer/pcgeos/Appl/Audio/Bsqp')
def edit(name, fn):
 p=base/name; b=p.read_bytes(); s=b.decode('latin1'); crlf=b'\r\n' in b
 if crlf: s=s.replace('\r\n','\n')
 s=fn(s)
 if crlf: s=s.replace('\n','\r\n')
 p.write_bytes(s.encode('latin1'))

def globals_h(s):
 s=s.replace('// QuickMode\n#define BQ_QUICK_OFF    0\n#define BQ_QUICK_START  1\n#define BQ_QUICK_END    2\n', '''#define BQ_OPTION_CONTINUE      0x0010
#define BQ_OPTION_SHUFFLE       0x0020

#define BQ_FULL_PATH_SIZE      256
#define BQ_LABEL_SIZE          164
#define BQ_NO_TRACK            0xffff
/* GDLI_NO_CHANGE reserves 0xffff for list initialization. */
#define BQ_MAX_TRACKS          0xfffe

#include <file.h>
#include <vm.h>

typedef struct {
    DiskHandle disk;
    PathName path;
    FileLongName file;
} BQFolderRequest;

typedef struct {
    FileLongName name;
    char label[BQ_LABEL_SIZE];
    Boolean visited;
    Boolean tagged;
} BQTrack;

Boolean _pascal BQ_IsAudio(const char *nameP);
MemHandle _pascal BQ_CopyLaunch(MemHandle launchH);
void _pascal BQ_PlaySelected(void);
void _pascal BQ_StopPlayback(void);
void _pascal BQ_PollPending(void);
Boolean _pascal BQ_FinishPlayback(int result, dword serial);
void _pascal BQ_CloseFolder(void);
void _pascal BQ_ResetShuffle(void);
void _pascal BQ_ReadTags(FileHandle fileH, char *labelP);
''')
 s=s.replace('#define BQ_ERROR_THREAD 0x101', '#define BQ_ERROR_THREAD 0x101\n#define BQ_ERROR_FOLDER 0x102\n#define BQ_ERROR_LIMIT  0x103\n#define BQ_ERROR_PATH   0x104')
 s=s.replace('extern  char        fullPath[];', 'extern  char        fullPath[BQ_FULL_PATH_SIZE];')
 s=s.replace('extern  char        WCI_soundName[];\nextern  char        WCI_soundPath[];\n','')
 s=s.replace('extern  word        quickMode;  // Quickplaymodus\n','extern  dword       bqPlaySerial;\nextern  dword       bqWorkerSerial;\n')
 return s
edit('Main/bsqp.goh', globals_h)
edit('Main/bsqp.goc', lambda s: s.replace('@include <stdapp.goh>','@include <stdapp.goh>\n@include "Main/bsqp.goh"').replace('char            fullPath[250];\nchar            WCI_soundName[33];\nchar            WCI_soundPath[222];','char            fullPath[BQ_FULL_PATH_SIZE];').replace('word            quickMode = 0;      // Quickplaymode','dword           bqPlaySerial = 0;\ndword           bqWorkerSerial = 0;'))
edit('Main/process.goh', lambda s: s.replace('MSG_PROCESS_BSQP_FINISHED(int result, Boolean closeAfter)', 'MSG_PROCESS_BSQP_FINISHED(int result, dword serial)').replace('    @message (GEN_FILE_SELECTOR_NOTIFICATION_MSG) MSG_BSQP_FILE_SELECTED;', '''    @message (GEN_FILE_SELECTOR_NOTIFICATION_MSG) MSG_BSQP_FILE_SELECTED;
    @message void MSG_BSQP_LOAD_FOLDER(MemHandle requestH);
    @message void MSG_BSQP_SCAN_FOLDER(dword generation);
    @message void MSG_BSQP_READ_TAGS(dword generation);
    @message (GEN_DYNAMIC_LIST_QUERY_MSG) MSG_BSQP_TRACK_MONIKER;
    @message (GEN_ITEM_GROUP_APPLY_MSG) MSG_BSQP_TRACK_ACTIVATE;'''))

def process(s):
 s=s.replace('@classdecl  BSQPProcessClass, neverSaved;', '''@classdecl  BSQPProcessClass, neverSaved;
@extern method BSQPProcessClass, MSG_BSQP_LOAD_FOLDER;
@extern method BSQPProcessClass, MSG_BSQP_SCAN_FOLDER;
@extern method BSQPProcessClass, MSG_BSQP_READ_TAGS;
@extern method BSQPProcessClass, MSG_BSQP_TRACK_MONIKER;
@extern method BSQPProcessClass, MSG_BSQP_TRACK_ACTIVATE;''')
 s=s.replace('@chunk char BQPlaybackError[]', '''@chunk char BQFolderError[] = "Cannot read this folder or create the temporary track list.";
@chunk char BQLimitError[] = "This folder has too many audio files for the track list.";
@chunk char BQPathError[] = "The audio folder or filename is invalid or too long.";
@chunk char BQPlaybackError[]''')
 s=s.replace('result = playback/open result; closeAfter = quick-mode exit.', 'result = playback/open result; serial = playback request.')
 s=s.replace('Show one standard dialog, then close quick mode if requested.', 'Ignore stale results and advance only after a natural end.')
 s=s.replace('    if (!playFlag) {\n        @send PLAYTrigger', '    if (!BQ_FinishPlayback(result, serial)) return;\n    if (!playFlag) {\n        @send PLAYTrigger', 1)
 s=s.replace('    case BQ_ERROR_THREAD: text = @BQThreadError; break;', '''    case BQ_ERROR_THREAD: text = @BQThreadError; break;
    case BQ_ERROR_FOLDER: text = @BQFolderError; break;
    case BQ_ERROR_LIMIT: text = @BQLimitError; break;
    case BQ_ERROR_PATH: text = @BQPathError; break;''')
 s=s.replace('    if (closeAfter)\n        @send BSQPApp::MSG_META_QUIT();\n','')
 start=s.index('    // GeodeHandle gh;',s.index('@method BSQPProcessClass, MSG_GEN_PROCESS_OPEN_APPLICATION'))
 end=s.index('    @callsuper();',start)
 s=s[:start]+'''    MemHandle requestH;
    char *cat;
    DisplayScheme displayScheme;

'''+s[end:]
 start=s.index('    // detect Datafile'); end=s.index('    // Backgroundcolor',start)
 s=s[:start]+'''    if (launchBlock) {
        requestH = BQ_CopyLaunch(launchBlock);
        @send, forceQueue process::MSG_BSQP_LOAD_FOLDER(requestH);
    }

'''+s[end:]
 start=s.index('    // disable endless playing',s.index('@method BSQPProcessClass, MSG_GEN_PROCESS_CLOSE_APPLICATION'))
 end=s.index('    // wait until playing finished',start)
 s=s[:start]+'''    BQ_CloseFolder();
    BQ_StopPlayback();

'''+s[end:]
 # Keep existing wait for shutdown: worker releases playFlag before completion.
 start=s.index('    BSWavPlayStates states;', s.index('@method BSQPProcessClass, MSG_PROCESS_TIMER_EVENT'))
 s=s[:start]+s[start:].replace('    // request data about playing from library','    BQ_PollPending();\n\n    // request data about playing from library',1)
 start=s.index('@method BSQPProcessClass, MSG_PROCESS_BSQP_STOP'); end=s.index('\n/**********************************************',start)
 s=s[:start]+'''@method BSQPProcessClass, MSG_PROCESS_BSQP_STOP
{
    BQ_StopPlayback();
}
'''+s[end:]
 s=s.replace('        BQ_StartPlay();\n    };\n}', '        BQ_PlaySelected();\n    };\n}',1)
 start=s.index('@method BSQPProcessClass, MSG_PROCESS_BSQP_OPEN'); end=s.index('/**********************************************\n\n    MSG_BSQP_TIME_DISP_LIST_APPLY',start)
 s=s[:start]+'''@method BSQPProcessClass, MSG_PROCESS_BSQP_OPEN
{
    MemHandle requestH;
    BQFolderRequest *requestP;

    requestH = MemAlloc(sizeof(BQFolderRequest), HF_DYNAMIC, HAF_ZERO_INIT);
    if (!requestH) {
        @send process::MSG_PROCESS_BSQP_FINISHED(BSNW_MEMORY_ERROR, bqPlaySerial);
        return;
    }
    requestP = MemLock(requestH);
    if (@call WavFileSelector::MSG_GEN_PATH_GET(requestP->path,
                                              sizeof(requestP->path))) {
        MemUnlock(requestH);
        MemFree(requestH);
        @send process::MSG_PROCESS_BSQP_FINISHED(BQ_ERROR_PATH, bqPlaySerial);
        return;
    }
    requestP->disk = @call WavFileSelector::MSG_GEN_PATH_GET_DISK_HANDLE();
    MemUnlock(requestH);
    @call FileSelectorBox::MSG_GEN_GUP_INTERACTION_COMMAND(IC_DISMISS);
    @send, forceQueue process::MSG_BSQP_LOAD_FOLDER(requestH);
}

'''+s[end:]
 s=s.replace('    bqOptions = selectedBooleans;', '''    word oldOptions;

    oldOptions = bqOptions;
    bqOptions = selectedBooleans;
    if ((bqOptions & BQ_OPTION_SHUFFLE) && !(oldOptions & BQ_OPTION_SHUFFLE))
        BQ_ResetShuffle();''')
 return s
edit('Main/process.goc',process)

def audio(s):
 start=s.index('    if (quickMode == BQ_QUICK_START)'); end=s.index('    fileH = FileOpen',start)
 s=s[:start]+'''    if (playFlag) return;
    bqWorkerSerial = bqPlaySerial;
'''+s[end:]
 s=s.replace('    word timeout;\n','')
 s=s.replace('quickMode == BQ_QUICK_END', 'bqWorkerSerial')
 s=s.replace('Stop old playback, probe, then transfer the file to the worker.', 'The process stops old playback before it calls this routine.')
 start=s.index('word    BQ_PlayThread('); end=s.index('\n/**************************************************************',start)
 s=s[:start]+'''word BQ_PlayThread(word wavFile)
{
    int result;
    dword serial;

    serial = bqWorkerSerial;
    result = BQ_Audio((FileHandle)wavFile, FALSE);
    FileClose((FileHandle)wavFile, TRUE);
    /* Release playback before queuing the result. The serial is local:
     * a replacement may start before this message reaches the process.
     */
    playFlag = 0;
    @send process::MSG_PROCESS_BSQP_FINISHED(result, serial);
    return 0;
}
'''+s[end:]
 return s
edit('Main/subcode.goc',audio)

def ui(s):
 s=s.replace('@classdecl  BQAudioFileSelectorClass;', '@classdecl  BQTrackListClass;')
 s=s.replace('GI_comp = @DisplayGroup, @OptionsMenu, @TriggerGroup;', 'GI_comp = @DisplayGroup, @FolderGroup, @OptionsMenu, @TriggerGroup;\n    HINT_ORIENT_CHILDREN_VERTICALLY;')
 pos=s.index('/****************\n * TriggerGroup')
 s=s[:pos]+'''@object GenInteractionClass FolderGroup = {
    GI_comp = @FolderGlyph, @TrackList;
    GII_visibility = GIV_SUB_GROUP;
    GI_attrs = @default | GA_KBD_SEARCH_PATH;
    HINT_ORIENT_CHILDREN_VERTICALLY;
    HINT_EXPAND_WIDTH_TO_FIT_PARENT;
}

@object GenGlyphClass FolderGlyph = {
    GI_visMoniker = "Open a folder to list its MP3 and WAV files.";
    HINT_FIXED_SIZE = { SST_PIXELS | 250, SST_LINES_OF_TEXT | 2, 2 };
}

@object BQTrackListClass TrackList = {
    GIGI_destination = process;
    GIGI_behaviorType = GIGBT_EXCLUSIVE;
    GDLI_queryMsg = MSG_BSQP_TRACK_MONIKER;
    GDLI_numItems = 0;
    GIGI_selection = GIGS_NONE;
    GIGI_numSelections = 0;
    ATTR_GEN_ITEM_GROUP_CUSTOM_DOUBLE_PRESS = MSG_BSQP_TRACK_ACTIVATE;
    HINT_ITEM_GROUP_SCROLLABLE;
    HINT_ITEM_GROUP_SHOW_SELECTION_EVEN_WHEN_NOT_FOCUS;
    HINT_FIXED_SIZE = { SST_PIXELS | 250, SST_LINES_OF_TEXT | 8, 8 };
}

'''+s[pos:]
 s=s.replace('    GI_visMoniker   = "PLAY";', '    GI_visMoniker   = "PLAY";\n    GI_states = @default & ~GS_ENABLED;')
 s=s.replace('"Select a file to play..."', '"Open the folder shown below:"')
 s=s.replace('GI_visMoniker = \'p\',"Open";', 'GI_visMoniker = \'O\',"Open Folder...";\n    GI_kbdAccelerator = ctrl \'o\';')
 s=s.replace('GII_type = GIT_COMMAND;\n    GI_comp =   @FileSelectorGlyph', 'GII_type = GIT_COMMAND;\n    GI_comp =   @FileSelectorGlyph')
 s=s.replace('@object BQAudioFileSelectorClass WavFileSelector', '@object GenFileSelectorClass WavFileSelector')
 s=s.replace('    GFSI_destination = process;\n    GFSI_notificationMsg = MSG_BSQP_FILE_SELECTED;\n    GFSI_fileCriteria = @default | FSFC_FILE_FILTER | FSFC_FILTER_IS_C;', '    GFSI_fileCriteria = FSFC_DIRS;')
 s=s.replace('    GI_states = @default & ~GS_USABLE;\n    GTI_actionMsg = MSG_PROCESS_BSQP_OPEN;', '    GTI_actionMsg = MSG_PROCESS_BSQP_OPEN;')
 s=s.replace('    GI_comp =   @OptionsBoolItem1,\n    @OptionsBoolItem2,\n    @OptionsBoolItem3,\n    @OptionsBoolItem4;', '    GI_comp = @OptionsBoolItem2, @OptionsBoolItem3, @OptionsBoolItem4,\n              @ContinueOption, @ShuffleOption;')
 start=s.index('@object GenBooleanClass OptionsBoolItem1'); end=s.index('@object GenBooleanClass OptionsBoolItem2',start)
 s=s[:start]+s[end:]
 s=s.replace('GI_visMoniker = \'M\',"Repeat Mode";', 'GI_visMoniker = \'T\',"Repeat Current Track";')
 pos=s.index('/***************\n * SaveTrigger')
 s=s[:pos]+'''@object GenBooleanClass ContinueOption = {
    GI_visMoniker = 'C',"Continue Playing";
    GBI_identifier = BQ_OPTION_CONTINUE;
}

@object GenBooleanClass ShuffleOption = {
    GI_visMoniker = 'S',"Shuffle";
    GBI_identifier = BQ_OPTION_SHUFFLE;
}

'''+s[pos:]
 s=s.replace("GI_kbdAccelerator = ctrl 's';\n    GTI_destination = process;\n    GTI_actionMsg = MSG_META_SAVE_OPTIONS;", "GTI_destination = process;\n    GTI_actionMsg = MSG_META_SAVE_OPTIONS;")
 start=s.index('@method BSQPApplicationClass, MSG_META_IACP_NEW_CONNECTION')
 s=s[:start]+'''@method BSQPApplicationClass, MSG_META_IACP_NEW_CONNECTION
{
    MemHandle requestH;

    /* Super may release the launch block. Copy it first. */
    requestH = appLaunchBlock ? BQ_CopyLaunch(appLaunchBlock) : 0;
    @callsuper();
    if (appLaunchBlock)
        @send, forceQueue process::MSG_BSQP_LOAD_FOLDER(requestH);
}

/* Enter activates the selected row even while another row is playing. */
@method BQTrackListClass, MSG_META_KBD_CHAR
{
    if (character == ((CS_CONTROL << 8) | VC_ENTER)) {
        if (flags & CF_FIRST_PRESS)
            @send process::MSG_BSQP_TRACK_ACTIVATE(0, 0, 0);
        return;
    }
    @callsuper();
}
'''
 return s
edit('UI/uimain.goc',ui)
edit('UI/uimain.goh', lambda s: s.replace('@class BQAudioFileSelectorClass, GenFileSelectorClass;', '@extern object TrackList;\n@extern object FolderGlyph;\n\n@class BQTrackListClass, GenDynamicListClass;'))
# Retain the retired selector class export slot for binary export stability.
edit('bsqp.gp', lambda s: s.replace('export BQAudioFileSelectorClass','export BQTrackListClass'))
