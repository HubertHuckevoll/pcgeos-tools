# File manager delete confirmations

The Ensemble product file tree selects Appl/FileMgrs2/ISDesk and
Appl/FileMgrs2/GeoManager (Tools/build/product/bbxensem/bbxensem.filetree).
Their shared UI is Appl/FileMgrs2/CommonDesktop/CUI/cuiMain.ui.

Both use the fileManager INI category, but different confirmation keys:

- ISDesk: FileDeleteOptionsGroup saves warnings as OCDL_NONE (0),
  OCDL_SINGLE (1), or OCDL_FULL (2). The UI labels are None, Single, Full.
- GeoManager: OptionsDeleteWarnings saves deleteOptions as a bitmask.
  OMI_SINGLE_WARNING and OMI_MULTIPLE_WARNINGS are independent booleans;
  select Single Warning and clear Warning for Each Item for one prompt.
  Bit definitions are in CommonDesktop/cdesktopConstant.def.
- Empty-wastebasket confirmation is OMI_CONFIRM_EMPTY_WB, saved in ISDesk's
  options key and GeoManager's warningOptions key.

VerifyMenuDeleteThrowAway in CommonDesktop/CUtil/cutilFileOpHigh.asm handles
the group confirmation. DeleteWarningCommon in cutilFileOpMiddle.asm gates
ordinary per-item confirmations. cutilFileOpRedwood.asm has alternate
implementations selected by _VS150 in cutilManager.asm.

DesktopEmptyWastebasket in CommonDesktop/CMain/cmainFileOps.asm asks once
when OMI_CONFIRM_EMPTY_WB is selected, then calls FileDeleteAllDir directly.
That recursive path calls FileCheckAndDelete, without the ordinary
DeleteWarningCommon prompt. Application and read-only confirmations remain
separate, controlled by OMI_CONFIRM_EXECUTABLE and OMI_CONFIRM_READ_ONLY.
Deleting selected items inside the wastebasket uses the normal delete path.

Library/Pref/ConfigUI/configui.ui already provides a File Manager tab;
configuiFileMgr.ui uses the same fileManager category but currently contains
no delete-confirmation controls.
