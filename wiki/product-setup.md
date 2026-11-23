# Product setup and update markers

The host launcher update and DOS product activation are separate steps.
Both currently use the root `update.txt` marker.

- `~/pcgeos-packaging/templ/ensemble.sh` and `ensemble.cmd` promote the
  pending `BASEBOX/ensemble-run.*.update` files. These wrappers preserve
  `update.txt` for DOS setup when they start the run launcher.
- `~/pcgeos-packaging/templ/basebox.launch.templ.conf` calls `setup.bat`
  before `loader.exe`. The product `SETUP.BAT` selects the build-specific
  `GSETUP` launcher.
- `Tools/build/product/bbxensem/gsetup/gsetup.bat`, labels
  `CHECKDEFAULTINI` and `DEFAULTCHECK`, skips activation when a user INI
  and `GFS.INI` exist and `update.txt` is absent. It does not compare the
  build paths in `GFS.INI` with the selected distribution.
- The same batch file, labels `UPDATEMARKER` and `DOACTIVATE`, uses the
  marker to select activation. `GACT.BAT` ends with a native GFS.INI writer.
  `FINISH` and `CLEARMK` clear the marker after the copy phase, confirmed
  drive removal and the existing `GFS.INI` check. Mapping or cleanup errors
  preserve the marker. Explicit `ACTIVATE` leaves the marker unchanged.

Deleting the shared marker in a host wrapper prevents automatic
activation of an existing installation. A new Basebox build can run with
the old GEOS build. Launcher promotion must preserve the marker until DOS
setup has used it.

The host wrappers clear `ensemble.log` before launcher promotion. The run
launchers append their startup headers (`write_start_log` in
`ensemble-run.sh`, the startup redirection in `ensemble-run.cmd`). This
keeps promotion messages and runtime output in one log for each normal
launch. Direct calls to the internal run launchers append to the existing
log.

## Desktop directory at startup

The BaseBox autoexec calls `SETUP.BAT` and waits for it to return before
it runs `LOADER.EXE`. The autoexec does not check the setup exit status.
`Tools/gsetup/gsetup.c:execComspec` runs the setup batch through DOS EXEC
and reads its return code. The generated `GINST.BAT` creates the local
`DESKTOP` directory during installation. Activation copies bootstrap
files and writes `GFS.INI`. It does not rerun the install script.

ISDesk uses `SP_TOP` plus `DESKTOP`. `NDInitDriveLinks` tries to create
the local desktop and Computer directories if it cannot enter them.
A failed `FileSetCurrentPath` leaves the previous thread path active.
Check the retry before cleaning up drive links or creating Computer.
`NDInitDesktop` also tries to create the desktop directory before it
creates links. The directory can exist when the metadata write fails.
See `Appl/FileMgrs2/CommonIS/cNewDeskConstant.def`,
`Appl/FileMgrs2/CommonDesktop/CMain/cmainInit.asm`, and
`Library/Kernel/File/filePath.asm` (`SetCurPath`).

`Tools/build/build/fileutil.pl:MakeDir` generates `@DIRNAME.000` when
the supplied name differs from its lowercase DOS name. An uppercase
`INSTALL` in `layoutInstallRoot` creates a staging label that `GINST.BAT`
can copy to `SP_TOP`. The FreeGEOS `fg.build` uses lowercase for its
plain directory names, including `versionTag` and the paths under `FG`.
A clean build creates uppercase DOS directories without labels for these
names. Use lowercase when you override these settings. The generated
setup batches still copy labels from payload subdirectories.

## ISDesk folder state at SP_TOP

ISDesk builds with `SMARTFOLDERS` (`Appl/FileMgrs2/ISDesk/local.mk`).
`NDPrimaryClose` sends `MSG_FOLDER_CLOSE_AND_SAVE`. `FolderCloseAndSave`
sets the current directory to the folder and calls `ShellCreateDirInfo`.
On SBCS builds this creates the hidden VM file `@Directory Information`,
with the DOS name `@DIRECTO.000`. Its map block stores window geometry
and display options. `FolderSaveIconPositions` can also write icon
positions to this file. See `CommonIS/CDeskDisplay/cNDPrimaryClass.asm`,
`CommonIS/CFolder/cndfolderClass.asm`, and
`CommonDesktop/CFolder/cfolderPlacement.asm` under `Appl/FileMgrs2`.

`CommonDesktop/CUtil/cutilUtil.asm:UtilCheckDirInfoCommon` permits writes
to writable, fixed standard paths, including `SP_TOP`. The parser can
return `SP_TOP` for paths with an unmatched suffix. To identify only the
root, also check that the suffix is empty. See
`Library/Kernel/File/filePath.asm:FileParseStandardPathReal`.

## BaseBox startup paths

The package template uses `mount c ..` and then `cd` with the host name
of the Ensemble folder. The parent path does not appear in the DOS path.
The DOS `CD` receives the host name as written. Names that need a DOS
short-name alias can fail before `SETUP.BAT` runs. See `CMD_CHDIR` in
BaseBox `src/shell/shell_cmds.cpp` at `b37410dea65b`.

BaseBox supports `MOUNT -pr` to resolve a relative host path from the
last loaded configuration file. For a config in `ENSEMBLE/BASEBOX`,
`mount c .. -t dir -pr` maps the Ensemble folder to DOS `C:\` directly.
See `MOUNT::ApplyRelativePath` in `src/dos/programs/mount.cpp` at the
same revision. This also removes the need for a DOS `CD` to the host
folder name.

For a directory mount, BaseBox keeps the path spelling it received.
`MOUNT` can list `..\` without showing the resolved host directory.
Use the process working directory and a DOS file check to verify a
relative mount. See `MOUNT::MountLocal` and `localDrive::localDrive`
in `src/dos/programs/mount.cpp` and `src/dos/drive_local.cpp`.
The Windows wrapper logs the launch request. BaseBox writes its initial
`Current dir` diagnostic to standard error before applying `--working-dir`.
See `main` and `init_logger` in `src/main.cpp`.

## DOS setup drive mapping

`Tools/gsetup/gsetup.c` passes the distribution directory, a free drive
letter (or `-` when none is available), and then the user arguments to
`gsetup.bat`. The generated `GINST.BAT` and `GACT.BAT` already take the
source drive as their first argument. `GACT.BAT` also receives the original
absolute distribution directory as its second argument. No fixed drive
letter is required.

Drive selection scans C: through the DOS drive-table limit. INT 21h/AH=19h
gets the current drive; AH=0Eh reselects it and returns the limit. FreeDOS
returns `lastdrive` (`FDOS/kernel`, `kernel/dosfns.c:DosSelectDrv`);
DOSBox-staging returns `DOS_DRIVES` (`src/dos/dos.cpp`, case 0x0e).
INT 21h/AX=4409h checks assignment without reading media. Only error 15
means unassigned; other errors do not make a drive safe to use.
The internal `/CHECKDRIVE X:` launcher mode returns 0 for unassigned,
1 for assigned, and 2 for an unknown result or invalid argument.

The batch flow tries EMUDRV, SUBST and SWSUBST, then checks real setup
files through the mapped drive. A failed attempt must release its drive
before the next command runs. Cleanup uses the command which created the
mapping. DOSEMU's removal form is `emudrv -d X:`
(`dosemu2/dosemu2`, `src/dosext/builtins/lredir.c:emudrv_main`);
SUBST and SWSUBST use `X: /D`.

A DOS batch `>NUL` redirect covers standard output only. FreeCOM reports
missing commands through `error_bad_command` and `displayError`, which
writes to standard error. See `FDOS/freecom`, `shell/command.c`,
`lib/err_fcts.src` and `lib/msg_dps.c:displayError`. Suppression for both
DOSBox and FreeCOM must cover both output handles.

## GFS bootstrap path handling

`Tools/gsetup/gsetup.c:WriteGfsIni` generates `GFS.INI` during install and
activation. There is no staged INI template. The last command in the
generated `GACT.BAT` is `%2\GSETUP.EXE /WRITEGFS NET.INI` or `NETEC.INI`.
`Scripts/buildbbx.pl:GenerateFreeGEOSSetupCopyScript` selects the filename
from the build's EC flag, including trailing `ec=true/false` overrides.
A stale staged `GFS.INI` in a reused build tree is excluded from copies.
The writer result is checked before drive cleanup and marker deletion.

The writer normalizes the selected distribution path and the local current
directory with Watcom `_fullpath`. The four physical paths are relative
when BOOT is inside the local root, with a directory-boundary check.
Otherwise they are fully qualified, including the drive letter. DOS
INT 21h/AX=6522h uppercases both paths before comparison and output.
`MEGAFILE.GEO`, `NET.INI`, `NETEC.INI` and `GFS.IMG` are uppercase literals.

Output is written to a unique local file (DOS INT 21h/AH=5Ah) and closed
before replacement. The old GFS.INI is renamed to a backup; replacement
failure restores it. If restoration also fails, the backup is retained
and its name is reported. The writer clears an old GFS.INI's read-only
attribute just before replacement and restores its original attributes
on rollback, including when the backup must be retained.

Install and activation mark the selected BOOT INI and the new GFS.INI
read-only through DOS attribute calls. Other attributes are preserved.
Attribute failures produce warnings; file-operation failures still stop
activation. The normal startup check does not change file attributes.

Absolute DOS paths are already supported for all four physical values:
`[paths] top` (`Loader/path.asm:ExpandRelativeTopLevelPathElements`),
`[paths] ini` (`Loader/ini.asm:SearchForIniPath`), `[gfs] file`
(`Driver/IFS/GEOS/MegaFile/megafileDevSpec.asm:MFSStorePathFromIni`), and
`[gfs] bootstrapPath` (`Common/gfsInitExit.asm:GFSForgetBootstrapDir`).
`GFS:\FG` is the virtual standard-path root and remains unchanged.

Relative `top`, `file` and `bootstrapPath` values expand against
`KLV_topLevelPath`. Chained INI names use DOS open calls after
`Loader/locate.asm:LocateGeosDir` sets the current directory to that root.
The MegaFile `megaFile` buffer has `DOS_STD_PATH_LENGTH + 3` bytes (67),
so its full image path can contain at most 66 characters plus the null.

`Tools/gsetup/gsetup.c` resolves its distribution directory before it
starts the batch file. The batch receives this path as `%1`; `%2` is the
temporary source-drive mapping. Persistent paths must not use `%2`, since
setup removes that mapping before GEOS starts. `GSETUP.BAT` passes the
original path as `GACT.BAT`'s `%2` for the writer. If the first launcher
itself runs through an existing drive alias, `resolveOwnPath` preserves
that drive letter. An absolute path in `GFS.INI` then depends on that
alias. Default setup checks for `GFS.INI` existence only; it does not
regenerate or validate its paths.

## Primary filesystem selection

`Library/Kernel/FSD/fsdInit.asm:LoadFSDriver` selects the primary DOS FSD
before it loads the additional drivers from `[system] fs`. The
`[system] primaryFSD` key overrides automatic selection in every build.
`Library/Kernel/kernelConstant.def` sets `PRIMARY_FSD_FOUND_IN_INITFILE`
to true without a product condition. If the explicit driver cannot load,
the kernel continues with `[system] fs`; it does not try automatic selection.
The normal `bbxensem.filetree` packages `Library/Kernel/{dbcs}/geos{ec}.geo`
for its targets. The image target names nt, pc, and fg do not select a
separate kernel driver policy.

Automatic selection checks DOSBox and DOSEMU before DR-DOS and NT.
DOSBox and DOSEMU select OS/2. Supported DR-DOS selects DRI; detected NT
selects NT FAT. The DOS version table maps major version 3 to MS3, 4-8 to
MS4, and 9 to NT FAT. Major version 20 selects OS/2. Other versions above
the table select OS/2 in all builds, including GPC_ONLY. EC and NC use the
same selection rules with their corresponding filenames.
A primary DOS FSD override must preserve the split installation's
`[system] fs = MEGAFILE.GEO` entry, which loads the image driver.

The OS/2 FSD avoids direct SFT access: `DOSPointToSFTEntry` always
returns carry set (`Driver/IFS/DOS/OS2/os2Utils.asm`). Drive detection uses
DOS IOCTL calls (`os2InitExit.asm:OS2CreateDrive`, `OS2FetchDeviceParams`).
The NT FAT driver is based on the OS/2 driver but has separate drive
initialization (`Driver/IFS/DOS/NTFat/ntfatManager.asm`,
`ntfatInitExit.asm:OS2CreateDrive`). Keep this distinction when changing
the kernel's automatic selection.

DOSEMU 1.4.0 and DOSEMU 2 both place the eight-byte signature `$DOSEMU$`
at F000:FFE0, followed by a four-byte version value at F000:FFE8. Thus one
read-only signature check can identify both families. Evidence:
https://github.com/dosemu2/dosemu2/blob/dosemu-1.4.0/src/base/bios/bios.S
(`.org 0xffe0`) and
https://github.com/dosemu2/dosemu2/blob/devel/src/base/bios/x86/bios.S
(`_ORG(0xffe0)`, `DOSEMU_VERSION_CODE`).

## Access-point index in split installations

The Access Point library uses the kernel string-section APIs for
`[accpnt] contents`. FG chains the primary INI through `GFS.INI` to
`BOOT/NET.INI` or `BOOT/NETEC.INI`, which supplies the factory entries.
The kernel puts factory entries first. New access points append to the
local list. Deleting a factory entry records its row in the primary
`[accpnt] contents.disabled` key. The individual
`[accesspointNNNN]` properties can come from lower files.

Internet Dialup hides entry ID 1 and counts only the visible rows when
it selects an item. The hidden entry can precede local entries in the
merged list. See `Library/AccPnt/accpntUtils.asm` (`ReloadContents`,
`AllocateEntry`, `FreeEntry`) and `Appl/IDialup/IDialup.goc`
(`MSG_IDP_READ_ACCPNT_AND_ACCPNT_LIST`).

The install phase supplies the initial primary INI. Activation supplies
bootstrap files and regenerates `GFS.INI`. A change to the install
template does not repair an existing primary INI during activation.
See `Tools/build/product/bbxensem/bbxensem.filetree` (`setup/install`)
and `gsetup/gsetup.bat` (`CHECKDEFAULTINI`, `DOINSTALL`, `UPDATEMARKER`).

## Version metadata

`Tools/build/product/bbxensem/bbxensem.filetree` places the
`Images/VERSION.TXT` template in `SETUP/ACTIVATE` for FreeGEOS. Other
targets keep the system-core destination (`GFS LOCALPC`). The template
uses `VAR(buildnumber)`, set by `Tools/build/build/var.pl:SetVars` from
`ResolveEnvar("versionTag")` with the leading `BLD` removed. No Git lookup
or timestamp is generated for this file.
`Scripts/buildbbx.pl:GenerateFreeGEOSSetupCopyScripts` generates `GACT.BAT`
from the files under `SETUP/ACTIVATE`. A file added to that payload before
script generation therefore gets an activation copy command automatically.

`~/pcgeos-packaging/pack-ensemble.sh:add_basebox_version` appends
`Basebox Build <number>` to the staged activation file. The number comes
from the detected `BLD<number>` Basebox folder. Packaging requires exactly
one activation version file; older GEOS archives must be rebuilt first.
Plain DOS builds keep the PC/GEOS line without a Basebox line.

## Literal parentheses in INI templates

The legacy template processor in `Tools/build/build/template.pl`,
`ParseTemplateFileAndSend`, closes language macros at the first `)`.
Backslash-parenthesis does not escape that delimiter. Use `\[` and `\]`
for literal parentheses inside a macro. The processor converts these after
it processes the macros. See the languageName entries in
`Tools/build/product/bbxensem/Template/geos.ini` and the runnable check
`Tools/build/Tests/ini-language.pl`.

An inactive language entry with backslash-parentheses can leave a standalone
`)` line in the generated INI. The kernel rejects such a line during any
later commit, so Apply can fail in an unrelated preferences module.
Evidence: `Library/Kernel/Initfile/initfileLow.asm:ValidateIniFile`,
`VIF_LOOKING_FOR_EQUAL`, and `initfileHigh.asm:INITFILECOMMIT`.
