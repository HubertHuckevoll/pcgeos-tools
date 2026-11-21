# Test a GEOS geode with Swat

Read the SDK batch test guide at `~/pcgeos/TechDocs/Markdown/Tools/tswat_batch.md`. Check the syntax and effects of Swat commands in [the Swat command reference](commands.md) or the local source.

1. Identify the GEOS behavior that must stay the same or the bug that must be corrected. Select an observable result from the tested geode.
2. Write the Perl test in the geode's `Test` folder in the PC/GEOS checkout. Embed the Tcl after `__DATA__` and call `SwatTestRunner::run`. The last Tcl command must produce `1` for a pass or `0` for a failure. See the example in the SDK batch test guide.
3. Close the interactive target. Run `perl path/to/Test/test.pl` against the original geode. The runner opens a read-only transcript window when a terminal is available. Use `--no-window` to skip the window, `--timeout SECONDS` to change the 60-second limit, or `-n` to select the normal target.
4. Check that the intended code ran and that the assertion examined its result. For a bug fix, make sure the assertion fails for the reported behavior. For a refactor, make sure the checks pass before the change.
5. Make the change, build the geode, and put the new build on the target. Run the same Perl test again. Investigate changes in behavior before you report the result.

Use `protect` to release breakpoints, saved register states, and temporary resources when the test completes or Tcl reports an error. Call `flush-output` after a Tcl diagnostic if the next step can take time. Raise a Tcl error if the test cannot reach the condition it must check.

The Perl script reports `PASS` (`0`), `FAIL` (`1`), `ERROR` (`2`), or `TIMEOUT` (`124`). If the installed target is unavailable, report which checks you could run and which still need a target.

For a temporary Tcl check on Linux, you can also run `./swat/target-codex --batch FILE` from the tools checkout. The `test-begin`, `test-assert`, and `test-end` commands belong to that launcher.
