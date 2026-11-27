@echo off
setlocal
rem Build the current project from a clean state.

if not defined ROOT_DIR (
    echo ROOT_DIR is not set. Run sdkvar.cmd first. >&2
    exit /b 1
)

rem The SDK clean wrapper adds .cmd to its own name.
call clean || exit /b 1
mkmf || exit /b 1
pmake depend || exit /b 1
pmake -J 4 -L 4 || exit /b 1
pmake -n -J 4 -L 4
exit /b %errorlevel%
