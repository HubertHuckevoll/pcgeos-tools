@echo off
setlocal
rem Build all geodes and the product. Keep a build log in the user folder.

if not defined ROOT_DIR (
    echo ROOT_DIR is not set. Run sdkvar.cmd first. >&2
    exit /b 1
)

copy /y "%~dp0AGENTS.md" "%ROOT_DIR%\AGENTS.md" >nul || exit /b 1
pushd "%ROOT_DIR%\Installed" || exit /b 1
call clean || goto failed

rem Merge stderr in cmd so PowerShell receives plain build output.
rem Return the pmake exit code after writing the log.
powershell.exe -NoLogo -NoProfile -Command "$ErrorActionPreference = 'Stop'; cmd.exe /d /c 'pmake -L 8 -J 8 2>&1' | Tee-Object -LiteralPath (Join-Path $env:USERPROFILE 'build.log'); exit $LASTEXITCODE" || goto failed

call "%~dp0shinyproduct.cmd"
set "shinyStatus=%errorlevel%"
popd
exit /b %shinyStatus%

:failed
popd
exit /b 1
