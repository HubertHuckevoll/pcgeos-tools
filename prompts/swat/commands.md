# Swat command contract

Before you use a Swat command or Tcl feature, check its implementation in the local PC/GEOS source. Use `Tools/swat/Doc/` to find commands. Check the exact syntax, arguments, result, and effects in `Tools/swat/lib.new/` or the native code in `Tools/swat/`. Use only features that this Swat interpreter supports. Add commands to this reference after you verify and use them.

The launcher and Tcl helper are in this folder. The link at the root of the tools checkout keeps `target-codex` available when that directory is on `PATH`.

## Tcl and startup

- `source FILE` evaluates the file and returns the last result or propagates a Tcl error. `uplevel 0 source $file` runs it in the global scope. See `Tools/swat/tcl/tclCmdIZ.c`, `Tcl_Source` and `Tcl_Uplevel`. Swat reads `swat.rc` after it tries to attach. See `Tools/swat/swat.c`, `main`, `Tools/swat/ui.c`, `Ui_TopLevel`, and `Tools/swat/lib.new/swat.tcl`.
- `var NAME VALUE` sets a variable. `var NAME` returns its value. Inside procedures, use `global NAME` for a shared variable. See `Tools/swat/tcl/tclProc.c`.
- `defsubr NAME {ARGS} {BODY}` defines a Tcl procedure. `getenv NAME` returns the environment value or an empty string. `format FORMAT ARGS` returns a formatted string. See `Tools/swat/tcl/tclProc.c`, `Tcl_Defsubr`, `Tools/swat/cmdAM.c`, `Getenv`, and `Tools/swat/tcl/tclCmdAH.c`, `Tcl_Format`.
- `expr {EXPRESSION}` evaluates one expression. Use braces around expressions that contain spaces. `string compare A B` returns zero when the strings match. `null VALUE` tests for an empty list or `nil`. See `Tools/swat/tcl/tclCmdAH.c`, `Tcl_Expr`, `Tools/swat/tcl/tclCmdIZ.c`, `Tcl_String`, and `Tools/swat/cmdNZ.c`, `Null`.
- `catch {BODY} RESULT` returns `0` on normal completion, `1` on Tcl error, and `2`, `3`, or `4` for `return`, `break`, or `continue`. `error MESSAGE` raises a Tcl error. See `Tools/swat/tcl/tclCmdAH.c`, `Tcl_Catch` and `Tcl_Error`.
- `protect {BODY} {CLEANUP}` runs cleanup after the body, including on Tcl errors and Swat interrupts. It keeps the body's result and discards the cleanup result. Catch cleanup errors inside the cleanup block. Print them and propagate them after `protect` if the body completed normally. See `Tools/swat/tcl/tclCmdIZ.c`, `Tcl_Protect`.
- `echo` writes a line in the shell interface. `echo -n` omits the newline. `flush-output` flushes output. See `Tools/swat/shell.c`, `ShellEcho`, and `Tools/swat/ui.c`, `UiFlush`.
- `sleep SECONDS` pauses Tcl execution while Swat handles target messages. It returns zero if interrupted or a nonzero value if the delay completes. See `Tools/swat/cmdNZ.c`, `Sleep`.

## Runtime control and inspection

- `ensure-swat-attached` raises a Tcl error when Swat has no target connection. `cont` resumes GEOS and usually waits for a stop. `cont -f` can resume from a fatal-error stop. See `Tools/swat/lib.new/swat.tcl`.
- `patient find NAME` returns a patient token or `nil`. `patient name [TOKEN]` returns the patient name, with the current patient as the default. `spawn NAME` resumes the target and waits for the geode to load or for another stop. It deletes its temporary event handler on return. Check the patient after `spawn`. See `Tools/swat/ibmCmd.c`, `IbmPatient`, and `Tools/swat/lib.new/process.tcl`, `spawn`.
- `stop in PROCEDURE` or `stop in CLASS::MESSAGE` sets a breakpoint after the prologue when Swat finds its end. `stop at FILE LINE` or `stop at FILE:LINE` sets a breakpoint at a source line. Both return a breakpoint token. See `Tools/swat/lib.new/ibrk.tcl`, `stop`.
- `brk aset ADDRESS` sets a breakpoint for all patients and returns its token. `brk address TOKEN` returns its address or raises an error if the token is invalid. `brk clear TOKEN` removes the specified breakpoint. A clear command without a token can clear other breakpoints. See `Tools/swat/break.c`, `Break`.
- `save-state` saves the current thread's registers. `restore-state` pops that record and restores the registers. `discard-state` pops it without restoration. The record contains registers only. See `Tools/swat/ibmCmd.c`, `IbmSaveState`, `IbmRestoreState`, and `IbmDiscardState`.
- `quit leave` exits Swat and leaves the target stopped. The host batch runner closes Basebox. See `Tools/swat/ibmCmd.c`, `IbmQuit` and `IbmDetachGuts`.

## Stop and error reports

- `codex-ping` prints the readiness token. `codex-marker TOKEN` prints a marker after an interactive command. `codex-stop-summary` prints the last `FULLSTOP` reason, patient, registers, and top frame. See `codex.tcl`. Swat's event mechanism is in `Tools/swat/event.c`.
- `read-reg REGISTER` returns the register value in decimal. `regs` and `backtrace 1` print registers and the top frame. `locals` prints the selected frame's local values when the symbols supply them. See `Tools/swat/lib.new/swat.tcl` and `Tools/swat/lib.new/stack.tcl`.
- Tcl evaluation errors and target connection failures belong to the debugger run. GEOS warnings and fatal errors come from the target. Keep the text from both. At a fatal-error stop, `why` prints the GEOS error and can select the caller's stack frame. Warning handlers can print a warning and continue. See `Tools/swat/lib.new/fatalerr.tcl`, `why`, `geterror`, and `why-warning`.

The batch commands `test-begin`, `test-assert`, and `test-end` are defined in `codex.tcl`.
