# IStartup question editor

SchoolView's IStartup opens the Question Information Dialog from the
keyboard monitor. Press Alt and `+`, or press a key with both Shift keys
held down. The monitor skips this check in the login field. The message
handler excludes generic and student accounts.

The dialog reads a selected `\q` line from the active large-text object.
Apply replaces the text selection with a `\q` line. It stores the label,
objective, question type, group number, time in minutes, difficulty index,
and use count. The question text is separate from this information line.

See `Appl/Startup/CommonStartup/CMain/cmainProcess.asm`,
`StartupHotKeyMonitor`, and `Appl/Startup/IStartup/Main/mainQuiz.asm`,
`StartupDoQuizDialog`. For the fields and text format, see
`Appl/Startup/IStartup/UI/uiQuiz.ui` and `uiQuiz.asm`,
`QuizDialogInitiate` and `QuizDialogApply`.
