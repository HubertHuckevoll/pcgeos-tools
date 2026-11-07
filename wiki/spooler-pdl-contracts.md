# Spooler PDL completion and error handling

PrintPDLPage checks StartPage, SetPageTransform, PrintGString and EndPage
errors. PrintGString conversion faults should return GSRT_FAULT with carry
clear if the spooler must still destroy the loaded GString; a carry-set
return jumps past that cleanup. Evidence: Library/Spool/Process/
processPDL.asm:PrintPDLPage, loadGString, exitErr, checkFault.

ExitPrinterDriver checks DR_PRINT_END_JOB carry before copying job data.
On a new failure it calls StoppedByError and reports SERROR_CANNOT_CONVERT_PAGE;
CheckForErrors first preserves prior cancellation or an existing error.
Finalization errors matter even if all EndPage calls succeeded, because a PDL
backend can write required document metadata at EndJob. Evidence:
Library/Spool/Process/processThread.asm:ExitPrinterDriver, PrintFile,
StoppedByError, CheckForErrors.
