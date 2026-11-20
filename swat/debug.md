# Debug a GEOS geode with Swat

Read [the Swat command contract](commands.md) before you use Swat.

1. Write down the reported symptoms, target build, and actions that cause the problem. Reproduce it on the original geode. Check that the loaded geode and its symbols match the build you want to debug.
2. Find the functions, messages, and code paths that can cause the symptoms. Select a small number of breakpoints or existing diagnostics. Add a temporary EC warning only if you need more evidence.
3. Start `./swat/target-codex` from the tools checkout. It opens a viewer when a desktop terminal is available. Send commands through its tmux pane and collect evidence from the log. Put repeatable commands in a Tcl script. Record the stop reason, relevant values, and a short stack trace. Check where each error came from.
4. Use the runtime evidence to identify the cause. Make the smallest correction that addresses it. Build the affected geode and check that the target loads the new build.
5. Repeat the original steps in Swat. Check the behavior and the values that showed the fault. Remove temporary diagnostics and breakpoints. If you cannot run the target, report which behavior remains unverified.

For a named EC warning, you can load a Tcl procedure with the name `PATIENT::WARNING_NAME`. Print only the values you need and return `1` if Swat must stop. See [the Swat breakpoint and warning notes](../wiki/swat-source-breakpoints.md).
