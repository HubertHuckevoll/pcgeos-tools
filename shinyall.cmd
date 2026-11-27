@echo off
setlocal
rem Build pmake, the SDK tools, the geodes, and the product.

if not defined ROOT_DIR (
    echo ROOT_DIR is not set. Run sdkvar.cmd first. >&2
    exit /b 1
)

pushd "%ROOT_DIR%\Tools\pmake\pmake" || exit /b 1
wmake install || goto failed
popd

pushd "%ROOT_DIR%\Installed\Tools" || exit /b 1
pmake install || goto failed
popd

call "%~dp0shinygeodes.cmd"
exit /b %errorlevel%

:failed
popd
exit /b 1
