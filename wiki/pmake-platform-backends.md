# pmake platform backends

The active pmake sources are in Tools/pmake/pmake. The files under
Tools/pmake/src/src are historical copies. Active make.h includes
../src/customs/cust-cfg.h. This selects src/nt/nt-cfg.h for _WIN32 and
src/unix/unix-cfg.h for _LINUX or unix.

Tools/pmake/pmake/Makefile builds pmake.exe and pmake.e with 32-bit Watcom.
Use wmake -a for a complete tool rebuild; the rules do not list header
dependencies. The targets do not install binaries. wmake install copies them
to bin. Library sources are in Tools/pmake/lib; their headers also come from
Tools/pmake/src/lib. These paths explain why warnings can name src/lib while
the active C implementation is elsewhere.

main.c:MainParseArgs appends recursive options to .MAKEFLAGS. main exports
these options through the PMAKE environment variable. Recursive .PMAKE is the
invoked executable path. Windows J and L limits belong to each invocation;
there is no shared recursive pool. nt-cfg.h keeps the default at one job and
sets NT_MAX_JOBS to 63. job.c reserves wait slot zero for cancellation.

job.c defines _WIN32_WINNT before Windows headers so Watcom declares the job
object APIs. Its Windows job object is not inheritable and uses
JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE. Suspended shells join it before ResumeThread.
Windows 8 and later support nested job objects, and normal descendants remain
in the parent's job hierarchy. Evidence: job.c:JobExec and Job_Init; Microsoft
https://learn.microsoft.com/en-us/windows/win32/procthread/job-objects.

Windows command files use an inherited stdin handle with delete-on-close.
The console handler only signals the event. The main thread owns child waits,
job lists, target deletion, and handle cleanup. JobNTExit is registered with
atexit, including for failures in .BEGIN. main.c:DieHorribly must use exit,
rather than ExitProcess, to run this cleanup.

Windows Make_Run calls Finish if Job_End collected errors or numNodes remains
nonzero. Its query path returns before this check. Linux retains its older
return behavior. Job_End's .END wait has a unix branch and a _WIN32 branch,
but no _LINUX branch. Tools/pmake/Tests/windows-parallel.pl records Linux -k
exit-status assertions as TODO and skips native .END execution on Linux.

The product graph in Installed/Makefile builds LowMem, NetWare, and WinCom
Swat stubs through separate MAKESTUB recipes. Each recipe changes into the
same Installed/Tools/swat/Stub directory and selects a variant with SUBDIRS.
The variants share rpc.def. Tools/swat/Stub/local.mk generates this file
with sed from Tools/swat/rpc.h and redirects output directly to the target.
The object dependencies in Tools/swat/Stub/dependencies.mk include rpc.def;
these dependencies belong to each separate pmake process.

Tools/swat/Stub/stub.def includes rpc.def before RpcMessageBuf. RpcHeader,
RPC_MAX_DATA, and CBreakArgs are defined by the generated rpc.def. Missing
names at stub.def:RMB_header and cbreak.asm:CBD_criteria therefore require
checking which rpc.def was included and whether its contents are complete.

An empty rpc.def produces no missing-include error. In bsw.asm, it causes
four errors at stub.def lines 423-424: parse errors for RMB_header and
undefined RpcHeader and RPC_MAX_DATA. A host ESP build with the complete
header succeeds; the same command with an empty header gives these errors.
This test shows one possible cause only. The errors do not prove that
rpc.def is empty or that a process changed it. Check the include path
and runtime file access before assigning a cause. Tools/esp/main.c:
FindFile searches the -I directories in order when -I. is present.
Tools/esp/scan.c:ScanInclude opens the selected file with fopen.

JobPrintCommand converts Windows commands longer than 1000 characters to
response files. Its response-file reference must be compatible with the
called tool. Host Watcom wcc 2.0 (Dec 1 2020) accepts @args.tmp, but a
literal @"args.tmp" argument reports E1138 (Filename required on command
line), with the same valid response-file contents. This also occurs with
an absolute path and with or without a final newline. Evidence:
Tools/pmake/pmake/job.c:JobPrintCommand; host compiler
~/watcom/binl/wcc, with response text " -q -fo=probe.obj probe.c" and
probe.c containing "int probe(void) { return 0; }". Native Windows
validation is still required for a change to response-file quoting.

Response-file references must remain valid after recipe CD commands.
JobPrintCommand keeps the reference absolute and uses GetShortPathName
when the path has whitespace. If no unquoted path is available, TMP must
name a directory without spaces. The original path remains in
job->tempFiles for cleanup. The long Watcom commands test in
Tools/pmake/Tests/windows-parallel.pl covers this behavior.
