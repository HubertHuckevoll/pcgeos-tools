@echo off
setlocal
rem Remove the old product output and run the interactive product builder.

if not defined ROOT_DIR (
    echo ROOT_DIR is not set. Run sdkvar.cmd first. >&2
    exit /b 1
)
if not defined USERPROFILE (
    echo USERPROFILE is not set. >&2
    exit /b 1
)

pushd "%ROOT_DIR%\Tools\build\product\bbxensem\Scripts" || exit /b 1
for %%D in (gfs image localpc\ensemble) do (
    if exist "%USERPROFILE%\gbuild\%%D\" (
        rmdir /s /q "%USERPROFILE%\gbuild\%%D" || goto failed
    )
)

perl -I. buildbbx.pl
set "shinyStatus=%errorlevel%"
popd
exit /b %shinyStatus%

:failed
popd
exit /b 1
