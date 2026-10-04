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
