# Test a GEOS geode with Swat

Read [the Swat command contract](commands.md) before you use Swat.

1. Identify the GEOS behavior that must stay the same or the bug that must be corrected. Select an observable result from the tested geode.
2. Write a Tcl test before you change the geode. Call `test-begin NAME`, then call `test-assert BOOLEAN MESSAGE` for each condition. Supply `0` or `1` from the result of the check. Call `test-end` after the assertions and cleanup. See `Tests/swat-example.tcl` in the tools checkout.
3. Run `./prompts/swat/target-codex --batch FILE` from the tools checkout against the original geode. The runner starts a fresh target and opens a read-only tmux viewer when a desktop terminal is available. The viewer closes when the run ends. Use `--no-window` to skip the viewer. Close your interactive target before the run. Use `--timeout SECONDS` to change the 60-second deadline and `--log FILE` to keep a transcript. Use `-n` for the normal target when it is installed.
4. Check the assertion and the original result. For a bug fix, make sure the assertion fails for the reported behavior. For a refactor, make sure the checks pass before the change.
5. Make the change, build the geode, and put the new build on the target. Run the same Tcl file again. Investigate changes in behavior before you report the result. Keep the regression test as a `.tcl` file in `Tests` in the tools checkout so it can run again after later changes.

Use `protect` to release breakpoints, saved register states, and temporary resources on success and Tcl error. Use the installed target to exercise GEOS behavior. Check that the intended code ran and that the assertion examined its result.

Call `flush-output` after a Tcl diagnostic if the next step can take time. This sends the diagnostic to the live viewer at once.

- `PASS` (exit `0`) means all executed assertions passed and the script completed.
- `FAIL` (exit `1`) means at least one assertion was false and the script completed.
- `ERROR` (exit `2`) means a Tcl, debugger, startup, or test setup error prevented a valid result. If GEOS stops before the check can run, record the GEOS stop reason and raise an error.
- `TIMEOUT` (exit `124`) means startup or test execution exceeded the deadline. Check the transcript for the last action. The launcher closes this run's processes.

If the installed runtime is unavailable, report which checks you could run and which still need a runtime test.
