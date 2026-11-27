@echo off
rem Set the SDK environment in the current Command Prompt session.
rem The SDK folders must be in your Windows user folder.
set "WATCOM=%USERPROFILE%\watcom"
set "ROOT_DIR=%USERPROFILE%\pcgeos"
set "LOCAL_ROOT=%USERPROFILE%\"
set "BASEBOX=basebox"
set "PATH=%PATH%;%WATCOM%\binnt;%ROOT_DIR%\bin;%USERPROFILE%\pcgeos-basebox\binnt;%USERPROFILE%\pcgeos-tools"
