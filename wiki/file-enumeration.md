# File enumeration and C path errors

- FileEnum's FEP_bufSize is an entry count, not a byte count. Keep
  FEP_bufSize times FEP_returnSize below the desired buffer size.
  Library/Kernel/File/fileEnum.asm:FEAllocReturnBuffer multiplies them.
- FileEnum's C callback returns nonzero to accept a file. This is opposite
  to the GenFileSelector final filter convention. Evidence:
  Library/Kernel/File/fileC.asm:FILEENUM, callback label, and
  TechDocs/Markdown/Objects/ogenfil.md, Code Display 14-10.
- Without FESF_REAL_SKIP, FEEnumCallback calls the callback before applying
  FEP_skipCount. It decrements that word and tests JNS. Batched scans can
  skip at most 32768 matching files. The callback can independently count
  matches to detect overflow of the native word-sized no-fit count.
  Evidence: Library/Kernel/File/fileEnum.asm:FEEnumCallback, match/addIt and
  bufferFull labels. Do not silently treat a wrapped count as scan completion.
- The C FILEENUM wrapper returns 0xffff on failure and records the error
  for ThreadGetError. A null result block alone can also mean an empty scan.
  Evidence: Library/Kernel/File/fileC.asm:FILEENUM, haveRetval label.
- Compiler assignment of a local callback address can use live CS. Static
  function-pointer initialization retains the virtual code pointer needed
  for resource locking. Evidence: TechDocs/Markdown/Objects/ogenfil.md,
  Code Display 14-10 and its filterRoutine example.
- FileSetCurrentPath's C return value is a disk handle on success and zero
  on failure, not an error code. ThreadGetError supplies the failure code.
  Evidence: CInclude/file.h, Library/Kernel/File/fileC.asm:FILESETCURRENTPATH,
  and TechDocs/Markdown/Routines/rroute_f.md:FileSetCurrentPath.
- FILECONSTRUCTFULLPATH discards FileConstructFullPath's carry/error flag.
  FILERESOLVESTANDARDPATH returns zero disk handle on error. For a checked
  directory path, save the thread directory, set it to the desired folder,
  call FileResolveStandardPath with an empty tail and FRSPF_ADD_DRIVE_NAME,
  then restore the directory. Evidence: Library/Kernel/File/fileC.asm,
  those two wrappers; Library/Kernel/File/filePath.asm:FileResolveStandardPath.
- VMO_TEMP_FILE takes a directory string with 13 additional zero bytes after
  its terminating null. VMOpen appends a generated filename to that string.
  Evidence: Library/Kernel/VMem/vmemHigh.asm:VMOpen interface comment.
- VMClose's C parameter is declared Boolean, but VMCLOSE passes its low
  byte directly to the assembler routine. Only 0 or FILE_NO_ERRORS (0x80)
  is valid; TRUE (~0) causes VM_CLOSE_BAD_PARAMETER_IN_AL in EC builds.
  FILE_NO_ERRORS permits closing even if the implicit VMUpdate fails;
  use it only when discarding the file is intended. Evidence:
  CInclude/vm.h:VMClose, CInclude/file.h:FILE_NO_ERRORS,
  Library/Kernel/VMem/vmemC.asm:VMCLOSE, and
  Library/Kernel/VMem/vmemHigh.asm:VMClose.

## Desktop links on a DOS drive

ISDesk creates Computer as a directory. It creates World, Documents, and
Wastebasket as links. `NDInitDriveLinks` creates the drive links inside
Computer from the GEOS drive table. See `DesktopItems`, `NDInitDesktop`,
and `NDInitDriveLinks` in `Appl/FileMgrs2/CommonDesktop/CMain/cmainInit.asm`.

The DOS file-system driver stores links after the 256-byte GEOS header in
each directory's `@DIRNAME.000`. Link records start with `LN00`. An ordinary
DOS directory listing shows the metadata file without its links.
`DOSFileEnum` calls `DOSLinkEnum` only if it finds a directory file with
a valid header. See `Driver/IFS/DOS/Common/dosEnum.asm` and `dosLink.asm`.

The kernel checks the DOSEMU BIOS signature before it checks the DOSBox
callback instruction at startup. Detection of either selects the OS/2
driver during automatic selection. This
driver includes the common DOS enumeration and link routines. See
`Library/Kernel/FSD/fsdInit.asm` and `Driver/IFS/DOS/OS2/os2Manager.asm`.

A valid directory header can exist without any links. At 256 bytes the
file contains the header alone. `DOSLinkCreateLink` requests read/write
access. It creates the metadata file only if the open reports
`ERROR_FILE_NOT_FOUND`. `NDCreateDriveLinks` skips a failed drive link.
`NDInitDesktop` continues with the next item after a failed link call.

BaseBox can accept a DOS read/write open on a read-only file and then
reject the write with DOS error 5. The default setting
`allow_write_protected_files` enables this behavior. See BaseBox
`src/dosbox.cpp`, `localDrive::FileOpen`, and `localFile::Write` in
`src/dos/drive_local.cpp` at revision `b37410dea65b`. In Swat, check the
carry flag and AX when `DOSLinkInitHeader` returns from the first write.

Preserve the metadata before another start when you investigate missing
links. In `Driver/IFS/DOS/Common/dosLink.asm`, `DOSLinkReadLinkHeader`
stops on a short read. If it reads a complete record header with a bad
signature, it tries to truncate the file to 256 bytes. `DOSLinkEnum`
treats the end of this scan as normal.
