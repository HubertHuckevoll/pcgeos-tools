##############################################################################
#
# PROJECT:	PC GEOS
# MODULE:	Swat -- Codex helpers
# FILE: 	codex.tcl
#
# DESCRIPTION:
#	Small commands and prompt override for machine-driven Swat sessions.
#
###############################################################################

[defsubr prompt {args}
{
    echo -n {CODEXSWAT> }
    flush-output
}]

[defvar codexLastStopReason {} top.support
{Last FULLSTOP reason seen by the Codex Swat helper.}]

[defsubr codex-fullstop {why args}
{
    global codexLastStopReason

    var codexLastStopReason $why
    return EVENT_HANDLED
}]

event handle FULLSTOP codex-fullstop

[defcmd codex-ping {} top.support
{Usage:
    codex-ping

Synopsis:
    Prints a stable readiness token for Codex.
}
{
    echo {CODEX-SWAT-PONG}
}]

[defcmd codex-marker {token} top.support
{Usage:
    codex-marker <token>

Synopsis:
    Prints a stable marker token after a command batch.
}
{
    echo [format {CODEX-SWAT-MARKER:%s} $token]
}]

[defcmd codex-stop-summary {} top.support
{Usage:
    codex-stop-summary

Synopsis:
    Prints a compact stop summary using existing Swat commands.
}
{
    echo {CODEX-SWAT-STOP-SUMMARY-BEGIN}

    global codexLastStopReason

    if {![null $codexLastStopReason]} {
	echo [format {stop-reason: %s} $codexLastStopReason]
    } else {
	echo {stop-reason: unknown}
    }

    if {[catch {patient name} pname] == 0} {
	echo [format {patient: %s} $pname]
    } else {
	echo [format {patient-error: %s} $pname]
    }

    echo {registers:}
    if {[catch {regs} rerr] != 0} {
	echo [format {regs-error: %s} $rerr]
    }

    echo {top-frame:}
    if {[catch {backtrace 1} berr] != 0} {
	echo [format {backtrace-error: %s} $berr]
    }

    echo {CODEX-SWAT-STOP-SUMMARY-END}
}]

var codexTestPhase idle

[defsubr test-begin {name}
{
    global codexTestPhase codexTestCount codexTestFailures
    if {[string compare $codexTestPhase ready] != 0} {
        error {Call test-begin once at the start of a batch test.}
    }
    var codexTestPhase active codexTestCount 0 codexTestFailures 0
    echo [format {Test: %s} $name]
    flush-output
}]

[defsubr test-assert {condition message}
{
    global codexTestPhase codexTestCount codexTestFailures
    if {[string compare $codexTestPhase active] != 0} {
        error {Call test-assert between test-begin and test-end.}
    }
    if {[string compare $condition 0] != 0 && [string compare $condition 1] != 0} {
        error {A test assertion must be 0 or 1.}
    }
    var codexTestCount [expr $codexTestCount+1]
    if {$condition == 0} {
        var codexTestFailures [expr $codexTestFailures+1]
        echo [format {Assertion failed: %s} $message]
        flush-output
    }
}]

[defsubr test-end {}
{
    global codexTestPhase codexTestCount
    if {[string compare $codexTestPhase active] != 0} {
        error {Call test-end once after test-begin.}
    }
    if {$codexTestCount == 0} {
        error {The test executed no assertions.}
    }
    var codexTestPhase ended
}]

[defsubr codex-run-test {script token}
{
    global codexTestPhase codexTestCount codexTestFailures
    echo
    echo [format {CODEX-SWAT-TEST:%s:START} $token]
    flush-output
    var codexTestPhase ready
    if {[catch {
        ensure-swat-attached
        uplevel 0 source $script
        ensure-swat-attached
        if {[string compare $codexTestPhase ended] != 0} {
            error {The script did not complete the test.}
        }
    } detail] != 0} {
        var result ERROR
        echo [format {Test error: %s} $detail]
    } else {
        var result PASS
        if {$codexTestFailures != 0} {
            var result FAIL
        }
        echo [format {Assertions: %d. Failed: %d.} $codexTestCount $codexTestFailures]
    }
    var codexTestPhase idle
    echo
    echo [format {CODEX-SWAT-TEST:%s:%s} $token $result]
    flush-output
}]
