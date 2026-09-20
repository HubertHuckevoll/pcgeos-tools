The central idea: these are two independent policy axes.

- `IMAGE_LOAD_AUTOMATIC` and `IMAGE_LOAD_INTELLIGENT` decide whether an image is admitted for loading.
- `PROGRESS_DISPLAY` enables progressive-image support at compile time.
- `[HTMLView] progressDisplay` chooses how an admitted image appears while loading/importing.

The overlapping numeric values are coincidental: `IMAGE_LOAD_INTELLIGENT == 2` does not imply `progressDisplay == 2`.

`IMAGE_LOAD_AUTOMATIC` requests every supported image without Intelligent's size limits. `IMAGE_LOAD_INTELLIGENT` adds a 480,000 decoded-pixel limit and, for HTTP, a compressed-download limit; rejected images remain compact clickable placeholders. See [`ImageLoadMode`](/home/konstantinmeyer/pcgeos/CInclude/html4par.goh:139).

When `PROGRESS_DISPLAY` is enabled, [`InitNavigation()`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/init/INIT.goc:613) reads `[HTMLView] progressDisplay` into [`imageProgressMode`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/htmlview.goh:453):

- `0`, `IMAGE_PROGRESS_FINAL`: only show the completed image.
- `1`, `IMAGE_PROGRESS_IMPORT`: download completely, then display progressively while decoding/importing.
- `2`, `IMAGE_PROGRESS_STREAM`: stream download data into the importer when eligible; otherwise fall back to mode 1.

The code and product template both default to `2`; missing, malformed, or out-of-range values retain that default. Legacy Boolean values are rewritten as integer `2`. See [`InitNavigation()` initialization](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/init/INIT.goc:785) and the [`geos.ini` template](/home/konstantinmeyer/pcgeos/Tools/build/product/bbxensem/Template/geos.ini:287).

The important coupling is in [`ProcessSingleGraphic()`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/urltext/URLTEXT.goc:779):

- Automatic gives `imageProbeMaxPixels == 0`. With `progressDisplay=2`, eligible inline images receive `LoadProgressData` and can begin importing before download completion.
- Intelligent inline images give `imageProbeMaxPixels == 480000`. They are deliberately fetched without `LoadProgressData`, regardless of `progressDisplay`, because the completed source file must first pass the intrinsic-size probe.
- Once an Intelligent image passes that probe, `progressDisplay=1` and `2` both provide progressive display during completed-file import. Only live download streaming is suppressed.
- `progressDisplay=0` provides no intermediate display in either image-load mode.

Thus the effective behavior is:

- Automatic + 0: final image only.
- Automatic + 1: progressive import after complete download.
- Automatic + 2: live streaming when eligible, otherwise progressive import after download.
- Intelligent + 0: complete download, probe, then final image.
- Intelligent + 1 or 2: complete download, probe, then progressive import. Mode 2 cannot stream ordinary Intelligent inline images.

Streaming has further eligibility checks: reserved-position images and known images below `progressMinHeight` do not receive load-progress data, and [`LoadGraphicProgressCallback()`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/urltext/URLTEXT.goc:463) currently starts streaming only for JPEG and GIF. Other formats, such as PNG, fall back to completed-file progressive import.

```text
MSG_URL_FRAME_SET_IMAGE_LOAD_MODE [1]
    |
    | Automatic or Intelligent starts processing
    v
MSG_URL_TEXT_PROCESS_GRAPHICS [2]
    |
    | Automatic:   imageProbeMaxPixels = 0
    | Intelligent: imageProbeMaxPixels = 480000 for inline images
    v
ProcessSingleGraphic [3]
    |
    +--> Intelligent limit active
    |       fetch without LoadProgressData
    |       complete download -> intrinsic-size probe
    |
    `--> No Intelligent limit
            progressDisplay == 2 and eligible?
                |
                +--> LoadGraphicProgressCallback [4]
                |       -> MSG_URL_TEXT_LOAD_GRAPHIC_PROGRESS [5]
                |
                `--> complete download
                         |
                         v
ImportThreadRequestImportGraphic [6]
    |
    | progressDisplay == 0: no import callback
    | progressDisplay == 1/2: ImportGraphicProgressCallback
    v
MSG_IMPORT_THREAD_ENGINE_IMPORT_GRAPHIC [7]
    |
    +--> Intelligent probe rejected -> compact placeholder
    `--> imported image -> intermediate updates, then final replacement
```

References: [1] [`MSG_URL_FRAME_SET_IMAGE_LOAD_MODE`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/urlframe/URLFRAME.goc:1115), [2] [`MSG_URL_TEXT_PROCESS_GRAPHICS`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/urltext/URLTEXT.goc:1058), [3] [`ProcessSingleGraphic()`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/urltext/URLTEXT.goc:779), [4] [`LoadGraphicProgressCallback()`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/urltext/URLTEXT.goc:463), [5] [`MSG_URL_TEXT_LOAD_GRAPHIC_PROGRESS`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/urltext/URLTEXT.goc:228), [6] [`ImportThreadRequestImportGraphic()`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/htmlview/ImportG.goc:464), [7] [`MSG_IMPORT_THREAD_ENGINE_IMPORT_GRAPHIC`](/home/konstantinmeyer/pcgeos/Appl/Breadbox/BbxBrow/htmlview/ImportG.goc:655).

Without `PROGRESS_DISPLAY`, the entire progress-mode machinery and INI read are compiled out. Automatic and Intelligent admission still work, including Intelligent's limits, but images are exposed only through final replacement. The current product headers enable `PROGRESS_DISPLAY` by default in [`product.h`](/home/konstantinmeyer/pcgeos/CInclude/product.h:70).