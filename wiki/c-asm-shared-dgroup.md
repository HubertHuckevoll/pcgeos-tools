# Shared C/ESP data and renamed geode build directories

ESP modules sharing the C library's DS must include resource.def (directly or
through stdapp.def) before using idata/udata. Include/resource.def declares
idata as DATA, udata as BSS, and groups both into dgroup. geos.def, geode.def
and library.def alone do not supply those declarations. Without them, an
unqualified udata segment can become an independent default code resource,
while DS-relative access still addresses the C dgroup. Verify the linked
resource flags, not just the source segment name. Evidence:
Library/Audio/BSNWav/Driver/driverManager.asm and Include/resource.def:30-39;
its linked driverInfo state belongs to writable dgroup, not a four-byte
read-only code resource.

mkmf derives generated GEODE from the source/build directory basename
(Tools/nmkmf/mkmf.c:MkmfAddVar("GEODE", ...)). A library whose directory and
permanent name differ needs a GEODE override in local.mk before including
SYSMAKEFILE, as existing Spreadsheet/FlatFile modules do. Unix geos.mk has
already selected _PROTO/_REL by then (Include/sun.geos.mk:315-357), so a renamed
module must also select its matching revision metadata explicitly; changing
GEODE alone can still link with protocol 0.0. BSNAudio/local.mk demonstrates
grev getproto/neweng against the permanent-name revision file. File-case
mismatches such as Bsnwav.rev vs bsnwav.rev also prevent Unix discovery.

The UI startup-sound dependency must remain UI -> Wav -> BSNWav -> geos.
Importing AnsiC from BSNWav creates UI -> Wav -> BSNWav -> AnsiC -> Math -> UI,
even when BSNWAV_NO_UI removes all direct UI calls. See Library/User/ui.gp,
Library/Wav/wav.gp, Library/Audio/BSNWav/bsnwav.gp,
Library/AnsiC/ansic.gp, Library/Math/math.gp and Installed/Makefile.
pmake -q -p 1 prints the parsed dependency graph without compiling; its exit
1 can simply mean outdated outputs.

Watcom generates external calls to __U4M/__U4D/__I4M/__I4D for 32-bit integer
arithmetic. AnsiC publishes these in ansic.gp and implements them in
wcc_rtl.asm. MP3 also calls MEMSET/MEMCPY/MEMMOVE/MEMCMP (MP3Dec/mp3api.c and
core/*.inc); memory_asm.asm supplies these. BSNWav's Runtime and Memory
managers include these existing sources in separate assembly modules:
ansicGeode.def's error constants cannot be included twice in one module.
WCC_TEXT and STRINGCODE are fixed/code/read-only/shared in bsnwav.gp.
No AnsiC import or new public entry points are needed. Removing C headers
alone cannot remove compiler arithmetic helpers.

For modular ESP builds, .PATH.asm/.PATH.def makes shared sources resolvable
by pmake and dependency generation, but the ASSEMBLE rule removes -I flags
from ASMFLAGS. Add assembler include directories to -IFLAGS as well. See
BSNWav/local.mk, CoProcessor/Intx87/local.mk and Include/sun.geos.mk:ASSEMBLE
(the equivalent rule also exists in Include/Win32/geos.mk).

UI's PLAY_STARTUP_SHUTDOWN_MUSIC is tested with ifdef, so even an equ FALSE
definition enables the hooks. User/userMain.asm calls WavPlayInitSound with
UI00's token and UIS_STARTUP/UIS_SHUTDOWN. Configuration is under [sound],
keys 85_73_48_48_0_0 and 85_73_48_48_0_1. WavReadInitKeyToPlay resolves
filenames in SP_PRIVATE_DATA/sounds, or SP_USER_DATA/sounds under
PRODUCT_NDO2000. The default product template maps the keys to sy001.wav
and sy002.wav; bbxensem.filetree ships the existing files into privdata/sounds.

PrefSndn's combined startup/shutdown checkbox saves the Boolean
[ui]/startupShutdownSounds. UserAttach/UserDetach read it at playback time;
missing or invalid keys leave sounds enabled. [ui]/sound remains the master
switch in Wav's PlaySoundFromFileLow. No restart is needed to apply it.
SoundEnableList uses ATTR_PREF_ITEM_GROUP_ENABLE with TRUE and flags 0 to
enable StartupShutdownSoundList only while the master Sound selection is on;
disabling the group preserves its checkbox selection. PrefDialogMMClass's
MSG_GEN_RESET handler sends the master's status message after superclass reset
to refresh that dependency. PrefItemGroupClass scans enable dependencies on
load/status messages, but its reset handler does not send a status message.
See Config/Pref/prefItemGroup.asm:PrefItemGroupMetaLoadOptions,
PrefItemGroupSendStatusMsg, PrefItemGroupReset and EnableOrDisableObjects.
A one-child PrefBooleanGroupClass with
ATTR_GEN_BOOLEAN_GROUP_INIT_FILE_BOOLEAN uses native Boolean load/save and
Pref's Apply/Reset behavior; GBGI_selectedBooleans supplies the absent-key
default. Its checkbox must use GBI_identifier = TRUE (0xffff), with TRUE
also used for an enabled default. InitFileReadBoolean returns 0xffff for
true, and GenBooleanGroupLoadOptions stores that entire word. Unchecking
an identifier of 1 clears only bit 0, leaving 0xfffe, which saves as true
again. Integer/bitmask groups without the Boolean INI attribute can still
use identifiers such as 1. See Prefsndn/prefsndn.goc,
Prefkbd/prefkbd.ui:KeyboardAltGrBoolean, CInclude/geos.h:TRUE,
Kernel/Initfile/initfileHigh.asm:InitFileReadBoolean and
User/Gen/genBooleanGroup.asm:GenBooleanGroupLoadOptions, SetBooleanState,
GenBooleanGroupSaveOptions. Config/Pref/prefBooleanGroup.asm provides the
Pref Apply/Reset behavior; Wav/Tests/completion.pl checks the Boolean
save/reopen mask round trip.

The shutdown hook waits using WavLockExclusive/WavUnlockExclusive.
WavPlayFile must reserve wavSem before ThreadCreate, not inside the worker:
a shutdown waiter can otherwise overtake a delayed worker. The worker
releases the reservation after WavPlayFromWavFilePathBlock closes the file
and frees the request; creation failure releases it in the caller. Direct
PlaySoundFromFile calls acquire the same semaphore around PlaySoundFromFileLow;
the worker calls Low under its existing reservation. Both BestSound and
legacy playback therefore run under one lock, with no nested fallback lock.
See Library/Wav/wav.asm and Tests/completion.pl for the delayed-worker,
direct/queued-playback and failure-cleanup checks.

GenFileSelector accepts one filename mask. For alternatives such as WAV or
MP3, subclass GenFileSelectorClass, set FSFC_FILE_FILTER | FSFC_FILTER_IS_C,
and implement MSG_GEN_FILE_SELECTOR_GET_FILTER_ROUTINE. C filters use Pascal
calling convention and return TRUE to reject; explicitly retain directories
when filtering extensions. Store the callback in a static pointer so it stays
a GEOS virtual code address instead of the active CS. Evidence:
TechDocs/Markdown/Objects/ogenfil.md sections 14.3.6/14.3.8,
Appl/SDK_C/FSFilter/fsfilter.goc and Appl/Audio/Bsqp/UI/uimain.goc.

BSNWPreCheck / BSNWaveCheckDriver require BestSound's MANUFACTURER_ID_BSW,
DACSF_MIXER_TEST handshake (test value 5), followed by NewWave DMA requests.
Driver/Sound/BSD16/bsdac.asm and BSD8ST implement that private interface;
Driver/Sound/SoundBlaster/soundblasterDAC.asm does not list BSW formats.
Selecting the ordinary sblaster driver therefore causes BSNW_WRONG_DRIVER
for valid PCM sources. Decoder-only operations do not require this handshake.

JPEG error recovery must execute from a code resource in protected mode.
`Ijgjpeg/ASMTOOLS/asmtoolsManager.asm:_jmp_to_error_handler` performs a
nonlocal return after unlocking movable resource-call frames. It must not
execute in idata/dgroup or in a movable resource it can unlock itself.
`Include/resource.def` groups idata into dgroup; `Tools/glue/geo.c:GeoPrepare`
sets dgroup to `RESF_FIXED` without `RESF_CODE`. The PM resource loader in
`Library/Kernel/Geodes/geodesLoad.asm:LoadResource` converts selectors to code
only for `HAF_CODE`. Use a separate fixed code resource, and check the linked
resource flags. The context saver in
`Library/Breadbox/ImpGraph/ASMIMP/asmimpManager.asm:_set_error_handler` already
uses the fixed ASM_FIXED code resource.

JPEG method slots use GEOS movable-code addresses stored as void pointers.
`CInclude/jmorecfg.h` defines `MPTR`, `MASSIGN` through `MASSIGN5`, and
`MCALL`: assignments store the function address, while calls go through
`ProcCallFixedOrMovable_pascal`. Keep the assignment destination as an
lvalue and put the void-pointer cast on the source. Watcom's segment and
offset relocations are unchanged by this form; a cast on the destination
instead produces W120. See `Ijgjpeg/DECOMP/JDATASRC.c:jpeg_stdio_src` for
the source-manager method assignments. Inspect OMF code and relocations
with `wdis -a -l=<listing> <object>`.
