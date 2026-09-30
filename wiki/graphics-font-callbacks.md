# Graphics font handles across text callbacks

`GrTextObjCalc` keeps its locked font handle in `TMS_fontHandle`. Its
`DoCallback` path unlocks that font before invoking a graphic or hyphen
callback, then calls `NearLockFont` again. The returned BX is the handle that
must be stored in `TMS_fontHandle` for both SBCS and DBCS builds: `DoFontLock`
can invalidate and free an unreferenced font before choosing the replacement.
The next `CallStyleCallBack` unlocks `TMS_fontHandle`. Evidence:
`Library/Kernel/Graphics/graphicsTextObject.asm` (`DoCallback`,
`CallStyleCallBack`) and `Library/Kernel/Graphics/graphicsChars.asm`
(`NearLockFont`, `DoFontLock`).
