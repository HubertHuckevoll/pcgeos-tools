# Init-file strings

`InitFileReadString()` returns the string length in characters, excluding the
terminating null. In DBCS builds it divides the byte count by two before
removing the null. The C `InitFileReadStringBlock()` wrapper exposes that value
through `dataSize`.

Evidence:

- `Library/Kernel/Initfile/initfileHigh.asm`, `InitFileReadString`
- `Library/Kernel/Initfile/initfileC.asm`, `INITFILEREADSTRINGBLOCK`
- `CInclude/initfile.h`, `InitFileReadStringBlock`

INI lookup and live buffers:

- `Loader/ini.asm:OpenIniFiles` selects `geosec.ini` first in EC builds,
  falling back to `geos.ini`; it does not automatically merge both.
  `[paths] ini` (or the loader `/Pxxx` selection) loads additional files.
- `OpenIniFileAndRead` loads file contents into buffers at boot.
  `Library/Kernel/Initfile/initfileLow.asm:EnterInitfile` reads those buffers,
  so host edits are not reflected by restarting an application.
- `EnterInitfileAndFindKey` searches buffers in order and stops at the first
  matching key. A bare `@deleted` value is an inheritance barrier: reads
  report the key missing, while read-all retains earlier contributions.
  An invalid Boolean in that file does not fall through to
  later files: `initfileHigh.asm:InitFileReadBoolean` returns an error.
  The C wrapper (`initfileC.asm:CInitFileGetCommon`) preserves the caller's
  default for a missing category/key. Malformed Boolean values may overwrite
  it even on error; `InitFileReadBoolean` documents AX as destroyed then.
- Swat `pini HTMLView` shows that category in each live buffer;
  `pini -f 0 HTMLView` restricts it to the primary file. `iniwatch -r` logs
  reads and results. See `Tools/swat/lib.new/pini.tcl`.

`<initfile.h>` supplies both the `_pascal` prototypes and Watcom aliases
for the C InitFile API, including `InitFileReadBoolean` ->
`INITFILEREADBOOLEAN`. The native `InitFileReadBoolean` export takes
category/key in DS:SI and CX:DX and returns the value in AX; the C wrapper
takes stack arguments and writes through a Boolean pointer. An undeclared
C call can link to the native export with the wrong ABI. Evidence:
`CInclude/initfile.h`, `Library/Kernel/Initfile/initfileHigh.asm`,
`initfileC.asm:CInitFileGetCommon`, and both exports in `Library/Kernel/geos.gp`.

FontControl's fontmenu/fonttool keys contain concatenated four-digit hex
FontIDs, not FontEnumFlags. Library/Text/UI/uiFont.asm's
CreateCustomFontMenu checks the application's INI category, then [system],
and resolves each ID with GrGetFontName without filtering out bitmap fonts.
The [system] keys provide universal defaults; application keys override them.
These lists replace the menu/toolbar enumeration rather than adding to it;
include desired outline IDs too, or use More Fonts for other faces.
The normal short/toolbar lists enumerate useful outline fonts; More Fonts
enumerates all outlines.
ATTR_FONT_CONTROL_SHORT_LIST_FONT_TYPE and
ATTR_FONT_CONTROL_LONG_LIST_FONT_TYPE are object vardata, not INI flags.
Charmap's controller category is [charm], from its permanent name in
Appl/Charm/charm.gp and GenApplication's GAGetAttrCommon in
Library/User/Gen/genAppMisc.asm; its separate settings/fid keys use [CharMap]
explicitly (Appl/Charm/Process.goc). Custom [charm] lists can expose bitmap
fonts without altering other applications or the More Fonts list.

INI-only bitmap selection example, under [system]:

    fontmenu = 30000202022b022c
    fonttool = 30000202022b022c

These are four concatenated FontIDs: URW Roman (3000), Berkeley (0202),
Esquire (022b), and GEOS UI Sans (022c, FID_DEJAVUSC in this source tree).
Append the desired bitmap IDs to existing values to preserve their other
fonts. Only installed fonts are added. This configures the short menu and
toolbar popup; it does not change the automatic More Fonts list.

Evidence: TechDocs/Markdown/Tools/tini.md, system/fontmenu and system/fonttool;
Include/fontID.def (FID_BERKELEY, FID_ESQUIRE, FID_DEJAVUSC);
Library/Text/UI/uiFont.asm (CreateCustomFontMenu, GetValueFromHexString).
The published SDK documents the Roman/Berkeley example at
https://bluewaysw.github.io/pcgeos/Tools/tini.html#fontmenu .

Whole-key tombstones:

- The exact lowercase value `@deleted` outside a blob makes a key missing.
  Spaces and tabs can surround it. A semicolon can start a comment after it.
  Reads stop at the marker. Read-all keeps results from higher files.
- `initfileHigh.asm:InitFileDeleteEntry` writes a marker only if a lower value
  is available. Zero, false and an empty string count as values. An existing
  marker stays in place, even if the lower key is later removed. The lower check
  and primary change use the same INI lock (`initfileLow.asm:InitFileFindLowerKey`).
- `initfileLow.asm:FindKey` still finds physical entries, including markers.
  Logical readers call `InitFileIsDeletedValue` before value conversion.
  Internal raw deletion still removes entries without writing markers.
- `initfileConstruct.asm:BuildEntryFromString` puts a literal marker string in
  a blob. DBCS string writes use encoded data. `Loader/ini.asm:IsDeletedValue`
  uses the same raw marker rules as `InitFileIsDeletedString` in the kernel.
- List reads check the primary marker before a merge. Factory rewrite snapshots
  use `InitFileReadLowerString`. List append clears the whole-key marker before
  a match with a factory item can skip the local write. The `key.disabled` item format
  is unchanged. Whole-key markers do not depend on INI_STRING_SECTION_TOMBSTONES.
- See `TechDocs/Markdown/Tools/tini.md`, section 9.1.1, for INI examples, and
  `TechDocs/Markdown/Routines/rrouth_l.md:InitFileDeleteEntry` for the API rules.

Layered INI operation boundaries:

- Category deletion has two uses. `Library/User/Gen/genAppMisc.asm`,
  `GenApplicationMetaSaveOptions`, deletes the category for
  `MSG_META_RESET_OPTIONS`. `Appl/Preferences/PrefMgr/prefmgrModem.asm`,
  `PrefMgrModemApply`, deletes modem categories when the user selects none.
  Thus, a caller audit must distinguish reset from removal before changing
  the meaning of `InitFileDeleteCategory`.
- In `Library/Kernel/Initfile/initfileHigh.asm`, `InitFileDeleteEntry` captures
  a lower-list rewrite snapshot. `InitFileMaybeSkipRewriteSnapshotEntry`
  removes written factory items from it. `InitFileWriteStringSection` stores
  the remaining snapshot in key.disabled before either return path, including
  the factory-match path that skips a local write. It keeps the snapshot for
  later items. `InitFileReadMergedStringSection` reads the stored sidecar, so
  the new list is visible before commit.
- `InitFileCommit`, `InitFileSave`, `InitFileDeleteEntry`,
  `InitFileDeleteStringSection`, and `InitFileDeleteCategory` finish pending
  list work with `InitFileFlushPendingRewrite`. The INI module lock covers the
  flush and the following operation. Item indices are resolved after the flush.
  Category deletion stays physical and runs after the flush, so a later commit
  cannot recreate the category from an old snapshot. The INI module lock is
  recursive; see `Library/Kernel/kernelMacro.def`, `LockModule`, TL_nesting.
- `InitFileRevert` reads ini.bak into a separate block with recoverable read
  and allocation errors. It checks the final DOS EOF byte and calls
  `ValidateIniFile` before replacing the primary buffer. Failure preserves the
  active buffer, pending rewrite and caches. Success discards old pending
  state, clears parser and category positions, and rebuilds the optional hash
  table. `InitFileInitHashTable` releases the old table and rebuilds all active
  layers. Replacement buffers and tables have kernel ownership. Lower buffers
  and the active primary file handle stay in place.
- `InitFileGrab` replaces only the primary buffer, file handle and size.
  Lower buffers in `KLV_initFileBufHan` stay active. `InitFileRelease` calls
  `InitFileCommit` before it restores those three primary values. Neither
  function saves separate list rewrite state for the temporary file.
- `InitFilePushPrimaryFile` and `InitFilePopPrimaryFile` shift the active
  buffer chain. `InitFileSwitchLanguages` replaces only the primary buffer.
  Language switching is compiled for PRODUCT=MULTILANG; see
  `Include/Internal/prodFeatures.def`, `MULTI_LANGUAGE`.

INI error cleanup:

- `Library/Kernel/Initfile/initfileLow.asm:ExitInitfile` releases both the
  buffer lock and initFileSem. `CorruptedIniFileError` also releases
  initFileSem. A caller that transfers to that fatal handler must keep the
  module lock held and release any buffer lock separately. Releasing the
  module lock twice can hide the original failure behind
  UNLOCK_MODULE_BY_WRONG_THREAD.
- `initfileHigh.asm:INITFILECOMMIT` validates the buffer before writing it,
  but can first extend the disk file to reserve space. That extension starts
  with DOS EOF; bytes after that marker are not evidence of buffer corruption.
  `initfileLow.asm:ValidateIniFile` stops at the first DOS EOF byte.
