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
