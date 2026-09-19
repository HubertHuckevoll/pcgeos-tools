# Swat prompt and global key dispatch

In curses Swat, `CursesReadInput()` gives prompt-local handling precedence
over the global `keyBindings` table when `modernPromptKeys` is enabled and
`CursesInputState.inProc` is `CursesInputChar`. `CursesInputKey()` consumes
plain arrows, Home, End, and Delete, but deliberately leaves Page Up and Page
Down for global bindings.

`srcwin` installs global bindings in `Tools/swat/lib.new/curses.tcl`. Plain
Left and Right use `0xcb` and `0xcd` for legacy horizontal scrolling;
Ctrl+Left and Ctrl+Right use `0xf3` and `0xf4`, allowing them to bypass modern
prompt editing and reach `dslr`. Linux creates these values in
`CursesDecodeHorizontalArrow()`, Windows in `CursesControlArrowKey()`, and the
DOS BIOS path creates them from scan codes `0x73` and `0x74` through its
existing `0x80 + scan` conversion.

Evidence: `Tools/swat/curses.c` (`CursesReadInput`, `CursesInputKey`,
`CursesDecodeEscape`), `Tools/swat/cursesKeys.h`,
`Tools/swat/ntcurses/ntio.c` (`consoleConvertKeyToDos`), and
`Tools/swat/lib.new/curses.tcl` (`srcwin`, `dslr`).
