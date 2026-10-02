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

`TrueTypeStrategy` reporting `RECURSIVE_CALL_TO_FONT_DRIVER` from
`RemoveGeodes` / `EndGeos` is a shutdown-time failure: `RemoveGeodes`
calls initialized drivers with `DR_EXIT`. An earlier fatal allocation or
handle error inside the driver can leave its EC `inDriverFlag` set. Catch
`FatalError` at entry to retain the original stack; `HANDLE_TABLE_FULL`
skips its normal debugger trap and enters `EndGeos` directly. Evidence:
`Driver/Font/TrueType/Main/mainManager.asm` (`TrueTypeStrategy`),
`Library/Kernel/Geodes/geodesUtils.asm` (`RemoveGeodes`), and
`Library/Kernel/Boot/bootBoot.asm` (`FatalError`, `EndGeos`).
