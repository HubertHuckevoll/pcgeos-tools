# Swat prompt and global key dispatch

In curses Swat, `CursesReadInput()` gives prompt-local handling precedence
over the global `keyBindings` table when `modernPromptKeys` is enabled and
`CursesInputState.inProc` is `CursesInputChar`. `CursesInputKey()` consumes
plain arrows, Home, End, and Delete, but deliberately leaves Page Up and Page
Down for global bindings.

`srcwin` installs global bindings in `Tools/swat/lib.new/curses.tcl`. Plain
arrows use `0xc8`, `0xd0`, `0xcb`, and `0xcd` for legacy scrolling. Ctrl+Up,
Ctrl+Down, Ctrl+Left, and Ctrl+Right use `0xf1` through `0xf4`, allowing them
to bypass modern prompt editing and reach `dss` or `dslr`. Linux creates
these values in `CursesDecodeArrow()`, and Windows uses
`CursesControlArrowKey()`.

The DOS BIOS path normally converts an extended scan code with
`0x80 + scan`. Ctrl+Left (`0x73`) and Ctrl+Right (`0x74`) therefore naturally
produce `0xf3` and `0xf4`. Enhanced BIOS Ctrl+Up (`0x8d`) and Ctrl+Down
(`0x91`) would wrap to carriage return and Ctrl-Q in an 8-bit key value, so
`CursesDecodeDosExtendedKey()` explicitly maps them to `0xf1` and `0xf2`.

Evidence: `Tools/swat/curses.c` (`CursesReadInput`, `CursesInputKey`,
`CursesDecodeEscape`), `Tools/swat/cursesKeys.h`,
`Tools/swat/ntcurses/ntio.c` (`consoleConvertKeyToDos`), and
`Tools/swat/lib.new/curses.tcl` (`srcwin`, `dslr`).
