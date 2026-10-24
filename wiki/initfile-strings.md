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
  matching key. An invalid Boolean in that file does not fall through to
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
