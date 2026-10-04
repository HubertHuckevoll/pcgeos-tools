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

TrueType kerning conversion:

`Driver/Font/TrueType/Adapter/ttwidths.c:ConvertKernPairs` compares the
converted count with `FontBuf.FB_kernCount` at exit. Its previous unnamed
`EC_ERROR_IF(..., -1)` appears as "Death due to nil" in Swat; this is not a
null-pointer diagnosis. The output bound check prevents writing more than
`FB_kernCount`, so this final mismatch means fewer pairs were converted.
`ttinit.c:InitConvertHeader` gets the expected `FH_kernCount` from
`GetKernCount` or a cached header, and `ttwidths.c:TrueType_Gen_Widths` copies
it into the font buffer. `ttacache.c:TrueType_Cache_ReadHeader` keys headers
by filename, size and magic word; `TrueType_Cache_Init` opens `TTF Cache`
in `SP_PRIVATE_DATA` with protocol 3.0. Conversion skips tables when
`TT_Load_Kerning_Table` fails. `FreeType/ftxkern.c` reads and allocates the
pairs again for conversion, separately from the initial count pass.
