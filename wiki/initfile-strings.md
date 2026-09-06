# Init-file strings

`InitFileReadString()` returns the string length in characters, excluding the
terminating null. In DBCS builds it divides the byte count by two before
removing the null. The C `InitFileReadStringBlock()` wrapper exposes that value
through `dataSize`.

Evidence:

- `Library/Kernel/Initfile/initfileHigh.asm`, `InitFileReadString`
- `Library/Kernel/Initfile/initfileC.asm`, `INITFILEREADSTRINGBLOCK`
- `CInclude/initfile.h`, `InitFileReadStringBlock`
