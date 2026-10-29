# Shared C/ESP data and renamed geode build directories

ESP modules sharing the C library's DS must include resource.def (directly or
through stdapp.def) before using idata/udata. Include/resource.def declares
idata as DATA, udata as BSS, and groups both into dgroup. geos.def, geode.def
and library.def alone do not supply those declarations. Without them, an
unqualified udata segment can become an independent default code resource,
while DS-relative access still addresses the C dgroup. Verify the linked
resource flags, not just the source segment name. Evidence:
Library/Audio/BSNAudio/Driver/driverManager.asm and Include/resource.def:30-39;
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

The top-level UI build dependencies must follow Library/User/ui.gp and
User/userManager.asm: Wav is commented out in both, so UI does not require
Wav to build. Adding UI -> Wav creates a cycle through Wav -> BSNAudio ->
AnsiC -> Math -> UI. See Installed/Makefile's User, Wav, BSNAudio, AnsiC and
Math targets and Library/AnsiC/ansic.gp / Library/Math/math.gp. pmake -q -p 1
prints the parsed dependency graph without executing compilation recipes;
validate cycles in that graph rather than treating -q's exit 1 (outdated
outputs) as a build failure.

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
