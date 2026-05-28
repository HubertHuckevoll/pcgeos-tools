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
