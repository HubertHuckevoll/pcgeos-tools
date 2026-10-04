# BbxBrow parsed-page lifetime

The parsed page is an OCT_TEXTOBJ VM chain registered by
MSG_URL_FRAME_URL_FETCHED in Appl/Breadbox/BbxBrow/urlframe/FRFETCH.goc.
MSG_URL_FRAME_FLIP_PAGE in urlframe/URLFRAME.goc locks its cache token,
attaches the transfer item, and releases the previous token after detachment.
MSG_HTML_TEXT_ATTACH_TO_ITEM and MSG_HTML_TEXT_UPDATE_ITEM in
Library/Breadbox/Html4Par/htmlclas/htmlclas.goc copy the hypertext arrays into
and back out of the text object. Attachment resets image resolution/cache
handles, retaining parser source references.

ObjCacheRemoveEntry in BbxBrow/navigate/NAVCACHE.goc frees text pages through
FreeHTMLTransferItem; locked entries cannot be evicted. ObjCacheUnlockItem
removes an unlocked OCDF_NOCACHE entry immediately, while ordinary cacheable
entries remain available for restoration.

Object-cache files can persist, but ObjCacheCheckPersist explicitly rejects
OCT_TEXTOBJ at normal cache detachment. DetachFromObjCache removes unlocked
text entries before writing the index. AttachToObjCache rejects files without
a committed map or with a different cache protocol. A persistent object
cache is therefore not evidence that parsed text pages persist across normal
application restart. MSG_HTML_TEXT_STORE_CONTENTS is currently disabled;
its native-page serialization path returns zero.

## Per-view width lifetime

HTI_viewWidth in CInclude/html4par.goh belongs to each HTMLText instance.
MSG_HTML_TEXT_ATTACH_TO_ITEM retains it across navigation;
MSG_HTML_TEXT_INITIALIZE_LAYOUT in htmlclas/htmltpre.goc resets
HTI_formattedWidth, not HTI_viewWidth. MSG_URL_FRAME_CREATE_CHILD in
BbxBrow/urlframe/URLFRAME.goc duplicates URLText and ViewTemplate and connects
them through MSG_HTML_TEXT_SET_VIEW_OBJ, so each frame has its own width.

GenView's SendPaneSizeMethod in
Library/SpecUI/CommonUI/CView/cviewPaneWindow.asm supplies OLPI_pageWidth,
already in document coordinates (OLPaneSetNewPageSize in
cviewPaneGeometry.asm). VisContentViewWinOpened in
Library/User/Vis/visContentClass.asm forwards opening to
MSG_META_CONTENT_VIEW_SIZE_CHANGED and VisContentSubviewSizeChanged sends it
to the children. HTMLText's handler in htmlclas/htmltdrw.goc records a
positive supplied width before unsuspending/layout and clears
HTS_VIEW_NOT_OPENED; the initial class width of 400 is not a real viewport.
MSG_HTML_TEXT_LAYOUT_START in htmlclas/htmltcel.goc subsequently derives
HTI_viewWidth from HTI_formattedWidth and its scrollbar policy, then subtracts
HTI_pageLeftMargin and one right-edge pixel for the top-level cell.
ICalculateViewSize adds back an existing vertical scrollbar and subtracts
its zoom-adjusted pixel allowance before returning the width used for
HTI_formattedWidth.
