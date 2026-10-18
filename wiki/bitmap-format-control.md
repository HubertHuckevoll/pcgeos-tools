# Bitmap format selection and allocation

VisBitmapFormatControlClass offers mono, 4-bit, 8-bit and 24-bit formats.
Normally it follows the selected bitmap's format notifications and confirms
then applies format/resolution changes to that target. With
ATTR_VIS_BITMAP_FORMAT_CONTROL_FORMAT_ONLY it subscribes to no target
notifications and ignores Apply. Its generated UI starts at BMF_24BIT.
Use an enabled instance, require the color features and prohibit DPI features
with standard GenControl hints for a color-only picker. After confirmation,
MSG_VBFC_GET_FORMAT returns the selection in CX (GIGS_NONE if unavailable).
The UI must still exist when queried. Evidence: Include/bitmap.def,
Library/Bitmap/uiFormatControl.asm and uiFormatControl.ui.

The class is exported, but its UI chunks and near helpers are internal
(Include/bitmap.def, Include/bitmap.uih, Library/Bitmap/bitmap.gp).
GenControl duplicates the template and sets its block output to the controller
(Library/User/Gen/genControl.asm, DupTheBlock). A subclass can inherit the
UI but application code cannot directly call the private reading helpers.

MSG_VIS_BITMAP_SET_FORMAT_AND_RESOLUTION stores settings without remapping
when VBI_mainKit.VBK_bitmap is zero. Subsequent bitmap creation uses these
fields through CreateBitmapCommon. MSG_VIS_BITMAP_GET_MAIN_BITMAP returns
the allocated VM block handle in DX; it stays zero on size rejection.
The ward is obtained through MSG_GOVG_GET_VIS_WARD_OD. Evidence:
Library/Bitmap/bitmap.asm, VisBitmapSetFormatAndResolution,
VisBitmapCreateBitmap, VisBitmapGetMainBitmap; Library/GrObj/Guardian/
grobjVisGuardian.asm, GrObjVisGuardianGetVisWardOD.

GrObjBodyConvertSelectedGrObjsToBitmap uses the shared format controller
in a modal template (Library/GrObj/UI/uiConvertControl.ui). It prepares the
replacement at 72 dpi without undo actions, checks for its main bitmap,
then deletes the originals and registers creation undo. A failed preparation
frees the uninserted guardian and temporary GString, retaining the originals.
Evidence: Library/GrObj/Body/bodyImpex.asm, this method.

GrObjGlobalUndoIgnoreActions passes CX=0 to suppress new actions without
flushing existing undo data; balance it with GrObjGlobalUndoAcceptActions.
The process uses a nesting counter, and GrObjGenerateUndoUndoClearChain
skips registration while ignoring. Evidence: Library/GrObj/Main/globalUtils.asm;
Library/User/Proc/procUndo.asm, GenProcessUndoIgnoreActions,
GenProcessUndoAcceptActions, GenProcessUndoStartChain, GenProcessUndoEndChain;
Library/GrObj/GrObj/grobjUndo.asm, GrObjGenerateUndoUndoClearChain.

For an uninserted guardian with no undo references, MSG_META_OBJ_FREE also
frees its ward through native queued freeing. Final handlers release GrObj
transforms/attributes and any main bitmap. Evidence: Library/GrObj/Guardian/
grobjVisGuardian.asm, GrObjVisGuardianMetaObjFree, GrObjVisGuardianFinalObjFree;
Library/GrObj/GrObj/grobj.asm, GrObjFinalObjFree;
Library/Bitmap/bitmap.asm, VisBitmapFinalObjFree.

The 870-point GrObj conversion width ceiling remains in force at 72 dpi.
The bitmap size check accounts for three bytes per 24-bit pixel and rejects
arithmetic/16-bit-KB overflow. It still runs before the point-to-pixel DPI
conversion, so it is not a complete DPI-aware size validation for other
callers. Evidence: Library/Bitmap/bitmap.asm, VisBitmapCheckBitmapSize,
VisBitmapCreateBitmap; Library/Bitmap/bitmapUtils.asm, CreateNewBitmap,
ConvertVisPointToBitmapPoint. Library/Bitmap/tests/bitmap-size.pl checks the
source sizing instructions against independently calculated payload sizes.

MSG_VBFC_GET_FORMAT forwards MSG_GEN_ITEM_GROUP_GET_SELECTION, which may
clobber BP (GenItemGroupGetSelection explicitly uses Destroy cx, dx, bp in
EC builds). ASM callers with BP-based locals must save BP across the call
and restore it before accessing those locals. Evidence:
Library/Bitmap/uiFormatControl.asm, VisBitmapFormatControlGetFormat;
Library/User/Gen/genItemGroup.asm, GenItemGroupGetSelection;
Include/Objects/gItemGC.def, MSG_GEN_ITEM_GROUP_GET_SELECTION.
