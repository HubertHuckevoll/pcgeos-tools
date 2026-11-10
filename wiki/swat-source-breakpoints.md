# Swat source-line breakpoints

Samples for swat.rc.
The app / lib must be called with run or spawn before setting the breakpoint in swat.rc:

run someapp
spawn somelib

## stop at
stop at /home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/urltext/URLTEXT.goc 82

## stop in
stop in HTMLVProcessClass::MSG_META_NOTIFY

## C locals

At a breakpoint inside a C function, `locals` prints local variables and
parameters for the selected frame. `locals FunctionName` only lists their
names and locations. Use `locals` at the post-read line in
`ImportThreadEngineStart` to inspect `forceSingleImportThread`. Evidence:
`Tools/swat/lib.new/stack.tcl:locals`, `locals-callback`.

## Backtrace interpretation

`btall` enumerates `thread all`, switches to each thread ID, and runs
`backtrace`; separate patient:number headings identify separate threads.
Evidence: `Tools/swat/lib.new/stack.tcl:btall`.

Swat's x86 unwinder scans stack words for plausible return addresses.
Indirect calls cannot always be verified, and calls to the
`ProcCallFixedOrMovable` family receive special handling. Treat implausible
C frames and decoded arguments as unverified until checked against source,
registers, and matching symbols. Evidence: `Tools/swat/ibm86.c`,
`Ibm86NextFrame` (stack scanning and indirect-call/PCFOM checks).
`ps -t patient` lists thread IDs and SS:SP independently of C argument
decoding (`Tools/swat/lib.new/ps.tcl:ps-t`).

`FullLockNoReload` calls `ThreadBorrowStackSpace(300)` before `MemSwapIn`.
If borrowing occurs, earlier stack contents move to a separate memory block
linked through `StackFooter.SL_savedStackBlock/SL_savedStackPointer`. Swat
follows these links during return-address scanning; `bt -sp 40` exposes
internal frames and stack usage without the usual method-call filtering.
Evidence: `Library/Kernel/Heap/heapLow.asm:FullLockNoReload`,
`Library/Kernel/Thread/threadThread.asm:ThreadBorrowStackSpace`,
`Include/Internal/threadIn.def`, `Tools/swat/ibm86.c:Ibm86NextFrame`, and
`Tools/swat/lib.new/stack.tcl:backtrace`.

## Swat send and EC DOS filenames

Tools/swat/lib.new/filexfer.tcl:get-send-dest now calls
file-mangle-for-dos-target in file-err.tcl. The target helper implements the
product EC naming rule, but its suffix match is case-sensitive (*EC).
get-send-dest uppercases source paths only on non-Unix hosts. Thus lowercase
Unix build names longer than nine characters ending in ec still get the wrong
DOS filename: prefsndnec.geo becomes prefsndn.geo instead of PREFSNDE.GEO;
html4parec.geo becomes html4par.geo instead of HTML4PAE.GEO.

Tools/build/build/fileutil.pl:Dosify uppercases the name first, then shortens
a basename longer than nine characters ending in EC to its first seven
characters plus E. An incorrect send destination can leave the old EC module
in place and create another geode with the same permanent name. Symptoms can
include a symbol version-mismatch prompt and old behavior after a rebuild.

Use send-file with an explicit product-compatible destination when needed:

    send-file /home/konstantinmeyer/pcgeos/Installed/Library/Pref/Prefsndn/prefsndnec.geo SYSTEM/PREF/PREFSNDE.GEO

Reload the module after replacement. Check for duplicate geodes before
assuming that accepting a symbol mismatch loaded the rebuilt file.

## Swat send and the split FreeGEOS layout

send resolves the host geode with find-geode, then selects the first matching
source-path rule in Tools/swat/lib.new/pcs.pat (filexfer.tcl:get-send-dest).
The send -p option selects a host source path, not a target destination.
Neither get-send-dest nor pcs.pat checks the active target's split layout.

Tools/swat/Stub/kernel.asm copies KLV_topLevelPath into topLevelPath.
Stub/rpc.asm:RpcSendFile calls RpcSavePathAndSwitchToTopLevelPath, creates
missing directories with RpcCreateDirectory, and creates/truncates the file
with DOS INT 21h. Stub32 has the same mechanism. Normal relative destinations
therefore go below the user's Ensemble root. This code does not modify the
GFS image or route files to the versioned BOOT directory.

This is suitable for local SYSTEM overrides with the correct DOS filename.
Loader/load.asm:FindAndOpenKernel explicitly tries local SYSTEM before the
configured paths, so a local SYSTEM/GEOSEC.GEO overrides the bootstrap kernel
on the next start. Kernel/File/filePath.asm:FindNextPathEntry and
BuildPathEntry implement local-first standard-path lookup for other modules.
GFSForgetBootstrapDir (Driver/IFS/GEOS/Common/gfsInitExit.asm) removes the
bootstrap directory from runtime SP_TOP after GFS initialization.

Distribution applications differ. Tools/build/product/bbxensem/fg.build
sets all layoutWorld variants to SYSTEM/DISTAPPL. FirstRunResolveDistApplLinkTarget
and FirstRunEnsureWorldLink (Appl/FirstRun/firstrun.goc) create WORLD links to
SP_SYSTEM plus DISTAPPL/<DOS filename>. pcs.pat still sends GeoWrite to
WORLD/HOME_OFF.000 and BbxBrow to WORLD. These create separate copies;
they do not replace the files selected by existing WORLD links. A local
SYSTEM/DISTAPPL/<correct DOS filename> is the matching override location for
these distribution applications. Keep separate rules for system applications.

run has another limitation: call.tcl:run invokes rpc-find-geode and assumes a
WORLD-relative result and SP_APPLICATION. Stub/rpc.asm:RpcFindGeode searches
only the physical DOS WORLD tree for *.GEO headers. It does not follow GEOS
links or search GFS/DISTAPPL. Correcting send destinations alone does not make
run or send -r find split distribution applications.

A newly created local standard directory can remain invisible in the current
session. Kernel/File/filePath.asm:BuildPathEntry skips directories marked
SPA_DOES_NOT_EXIST_LOCALLY. FileCreateLocalStdPath clears this flag for GEOS
creation; Swat's DOS directory creation does not. filexfer.tcl's src flush only
flushes Swat source information. A restart rebuilds the path state; reliable
live deployment needs GEOS path/cache handling as well as correct placement.

## Swat send and imported libraries

GP-imported libraries must be in SYSTEM. Kernel library loading uses SP_SYSTEM
(Library/Kernel/Geodes/geodesLibrary.asm:ProcessLibraryTable, PLT_loop).
Swat send selects the first matching rule in Tools/swat/lib.new/pcs.pat
(filexfer.tcl:get-send-dest). A library under Library/Trans that is imported
normally, rather than loaded as a translator, needs an exception before the
SYSTEM/IMPEX rule. The PDF backend is such a library; compare
Driver/Printer/PDF/pdf.gp and the SYSTEM entry in
Tools/build/product/bbxensem/bbxensem.filetree.

A missing imported library can prevent a printer driver from loading.
Library/Spool/UI/uiSpoolSummonsPrint.asm:SpoolLoadDriverLow maps load failures
to PCERR_PRINTER_NOT_KNOWN; GrabPrinterInfo leaves SSPI_VALID clear.
uiSpoolSummons.asm:SpoolSummonsInitialize reports SL-40
(PCERR_ALL_BAD_PRINTERS) when no installed printer remains valid. Check library
placement before deleting printer settings.

## Named C warnings and automatic diagnostics

CWarningNotice codes are resolved through the calling patient's Warnings type
(Tools/swat/lib.new/fatalerr.tcl:why-warning). A C enum with another type name
will not supply that mapping. A mixed C/ESP geode can declare the matching
numeric code with `enum Warnings` in an ESP module that includes ec.def.

why-warning selects the caller's frame and invokes a Tcl procedure named
`patient::WARNING_NAME` if it exists. That procedure can print locals and
return 1 to stop; the default warning handler prints the warning and returns 0,
so an ordinary warning does not itself stop execution. Evidence:
Include/ec.def:Warnings, Library/Kernel/Boot/bootBoot.asm:CWARNINGNOTICE,
Tools/swat/lib.new/fatalerr.tcl:why-warning.
The handler maps through the selected Warnings type; it does not search
standalone constants with the same value. Check that mapping when a geode
has more than one Warnings definition.

Use `_print` inside Tcl helpers when an address contains command substitutions,
for example `_print byte ^h[getvalue element]:0 #$dumpSize`. The interactive
`print` command uses `noeval`; `_print` evaluates its arguments first. An
explicit type and handle:offset also avoid an untyped address being displayed
as a scalar. Evidence: Tools/swat/lib.new/print.tcl:print and _print.

## Warnings on normal targets

CInclude/ec.h compiles EC_WARNING out when ERROR_CHECK is zero. Swat's
send command chooses the NC binary when the target kernel has the normal
permanent name (Tools/swat/lib.new/filexfer.tcl:send). A missing EC warning
therefore does not prove that its failure branch was not taken.
For a temporary report on both builds, pair EC_WARNING(code) with
NEC(Warning(code)); Warning calls CWarningNotice in either build.
Swat installs the CWARNINGNOTICE breakpoint for GEOS 2.x in
Tools/swat/lib.new/swat.tcl:_check_fatal_error. NC compiler options can omit
C locals, so automatic reports must also handle missing local symbols.
