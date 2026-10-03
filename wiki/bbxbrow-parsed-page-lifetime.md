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
