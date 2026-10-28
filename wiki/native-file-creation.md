# Creating exchange files without a GEOS header

Use FCF_NATIVE with FileCreate when another DOS/host application must read the
file bytes directly (for example RIFF/WAVE). Without it, the DOS filesystem
can create a GEOS data file with a header that FileRead/FileWrite hide from
the GEOS caller. The name passed with FCF_NATIVE must be valid for the native
filesystem; ordinary DOS requires 8.3 names. FILE_CREATE_ONLY refuses existing
files and is useful for protecting an input or an unrelated existing output.

FCF_NATIVE_WITH_EXT_ATTRS is not a substitute for a header-free exchange file:
Driver/IFS/DOS/Common/dosPath.asm:handleGeosCreate checks that flag to validate
the long name as a native name, then createGeosUsingNativeName calls
DOSInitGeosFile with GFT_DATA. Evidence: Library/Kernel/File/fileOpenClose.asm:
FileCreate contract; TechDocs/Markdown/Routines/rroute_f.md:FileCreate;
TechDocs/Markdown/Asmref/asmstrdf.md:FileCreateFlags.
