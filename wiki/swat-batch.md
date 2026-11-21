# Swat files and symbols in batch sessions

Swat can change its working directory to the directory of the current
patient. Use an absolute path for test input and output. In Tcl,
`file-init-dir` holds the directory where Swat started. See
`Tools/swat/cmdNZ.c` (`stream` help) and `Tools/swat/file.c` (`File_Init`).

When Swat cannot find matching symbols, `SWATIGNORE` can list patient names
whose missing symbols can be ignored. List only patients whose symbols
the test does not need. The target still loads or rejects those geodes as
usual. See `Tools/swat/lib.new/file-err.tcl` (`file-err`).

On Windows, Swat reads the startup file from `CUSTOM_TCL_LOCATION`.
The interactive UI opens `CONOUT$` directly, so redirecting standard
output alone does not capture the debugger transcript. See
`Tools/swat/lib.new/swat.tcl` (Windows startup), `Tools/swat/ui.c`
(`Ui_Init`), and `Tools/swat/ntcurses/initscr.c` (`Initscr_PrepConsole`).
