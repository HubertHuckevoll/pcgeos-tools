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
