# Batched image geometry layout

Status: Plan only. No implementation started as of 2026-09-30.

## Goal

Give each page at most two image-related layout episodes: its existing initial
layout and one batched geometry correction. Once geometry is committed, ordinary
image import, progressive display, and completion only replace or redraw pixels.
An unexpected difference between probed and final intrinsic dimensions retains
the existing reflow fallback.

## Resume instructions

1. Read this file, especially Progress log and Open decisions. Read
   ~/pcgeos/AGENTS.md and check ~/pcgeos-tools/wiki/html4par-images.md and
   ~/pcgeos-tools/wiki/bbxbrow-cancellation.md before repository research.
2. Inspect git status and the working-tree diff in ~/pcgeos. Do not assume a
   checkpoint is complete from this file alone; verify its code and builds.
3. Resume at the first unchecked checkpoint. Finish and verify that checkpoint
   before starting the next one. Update this file with what actually changed,
   exact build/check results, and the next action before stopping for any reason.
4. Keep this plan in ~/pcgeos-tools/idea. Source truth is in ~/pcgeos, outside
   Installed/. Do not commit generated Makefile or dependencies.mk changes.
5. Preserve line endings, keep changes minimal, use C89/GEOS conventions, and
   end each implementation round with a concise commit-message-style summary.

## Progress log

- [ ] Checkpoint 1: geometry state, collection, and one Html4Par commit path.
- [ ] Checkpoint 2: completed-file ImpGraph probe, starting with PNG.
- [ ] Checkpoint 3: replayable streamed JPEG/GIF probe on the same HTTP fetch.
- [ ] Checkpoint 4: redraw-only normal completion and removal of old image
      layout requests.
- [ ] Final audit, EC/NC builds, small runnable checks, and temporary tracing
      removed.

Current checkpoint: 1. No source edits have been made for this plan.

## Existing flow and relevant source

- ParseImage() creates the authored size, HID_size, and initial VTG_size in
  Library/Breadbox/Html4Par/htmlpars/opentags.goc.
- URLTextInitializeImageGeometry() computes a document size and transforms in
  Appl/Breadbox/BbxBrow/urltext/URLTEXT.goc.
- IReplaceGraphic() calls MSG_HTML_TEXT_RESOLVE_IMAGE. That message calls
  HTMLTextUpdateImageGeometry() in
  Library/Breadbox/Html4Par/htmlclas/htmlclas.goc. This helper changes
  VTG_size, dirties cells and tables, adds waiting images, and can schedule
  layout work.
- MSG_URL_TEXT_IMPORT_GRAPHIC_PROGRESS currently resolves waiting images and
  explicitly requests layout for live progress. MSG_URL_TEXT_DEC_PENDING
  currently captures the viewport, clamps images, and requests layout when
  all page requests finish. Both are in urltext/URLTEXT.goc.
- MSG_HTML_TEXT_CALCULATE_LAYOUT in htmlclas/htmltpos.goc starts work only for
  dirty layout or a changed view width; during active layout it may request a
  restart. Count layout episodes, not every internal pass.
- T_importGraphicRequest and MSG_IMPORT_THREAD_ENGINE_IMPORT_GRAPHIC are in
  Appl/Breadbox/BbxBrow/htmlview/ImportG.goc. URLTextRequestGraphic and
  LoadGraphicProgressCallback are in urltext/URLTEXT.goc.
- HTMLimageData and message declarations are in CInclude/html4par.goh;
  URLTextClass instances are in Appl/Breadbox/BbxBrow/htmlview.goh.
- The image record is persisted. If its layout changes, bump
  OBJ_CACHE_MINOR_VERSION in htmlview.goh and reset new transient fields in
  IMarkAllImagesUnresolved().

## Invariants and request state

Keep geometry knowledge separate from HTML_IDF_RESOLVED, which means content is
available. Add an explicit geometry-known indication and store the probed
intrinsic XYSize per image if needed for the final-size comparison. Both
authored WIDTH and HEIGHT make document geometry known without a probe; the
intrinsic size may remain unknown until import. One authored dimension needs
intrinsic dimensions to preserve aspect ratio. Failed probes keep placeholder
geometry and still count as finished.

URLTextClass needs pendingGeometryProbes, geometryScanComplete, and
geometryCommitted. Count distinct source/import requests, not each duplicate
image record. Register every probe before permitting the zero-count commit;
MSG_URL_TEXT_PROCESS_GRAPHICS has two passes and also starts inline SVG work.
Use an explicit probe request kind. Never infer probe mode from maxPixels == 1:
normal intelligent-mode rejection must continue to defer images. A probe
finishes exactly once on size discovery, failure, unsupported format, stop, or
no usable geometry. Page pending ownership lasts through the eventual normal
import, independently of probe completion.

The commit fires once when geometryScanComplete is true and
pendingGeometryProbes reaches zero. If there are no probes, mark committed
without a layout unless viewport fitting changed a rectangle. A late normal
import must not reopen ordinary geometry collection.

## Checkpoint 1: collect and commit geometry

Add a Html4Par collection entry point that computes/stores HID_size and
associated geometry information without updating VTG_size, dirtying cells, or
starting waiting-image timers. Apply one request's intrinsic size to every
matching image; authored dimensions can differ between duplicate URLs.

Add one commit entry point. Capture viewport dimensions, fit the collected
image records, then walk images once and update VTG_size only where it differs
from the final HID_size plus spacing and the existing height adjustment. Reuse
the cell/table/layout-stack dirtying logic in HTMLTextUpdateImageGeometry().
Suppress its per-image waiting-list, timer, and layout scheduling in batch
mode. Request one MSG_HTML_TEXT_CALCULATE_LAYOUT if any geometry changed, then
set geometryCommitted. Avoid holding the image-array lock across code that
locks it again. Preserve the current exceptional geometry-change path.

Viewport capture can return zero while a view is off-screen. Define a stable
fallback at commit, such as committing unfitted size and leaving it fixed until
an ordinary view resize. Do not allow first viewport appearance or later image
completion to create a second image-driven layout. Audit viewport-change and
inline-SVG clamp call sites, not just MSG_URL_TEXT_DEC_PENDING.

Build Html4Par and BbxBrow through aihelp.py before proceeding. Do not change
the loading pipeline in this checkpoint.

## Checkpoint 2: completed-file probe

Extend the existing BbxBrow import request with explicit probe mode. Run the
ordinary ImpGraph importer with maxPixels = 1 and zero-initialized
ImageAdditionalData. DEFERRED plus nonzero IAD_size in both dimensions is a
successful probe. A 1x1 image can complete import under this cap: take its
size and release or deliberately reuse its tiny VM result with correct cache
ownership. A failure or an older driver that defers without size completes
the probe without changing placeholder geometry. Keep installed MIME drivers
authoritative. Do not add format-specific parsers or change normal
intelligent-mode maxPixels and transport-size policy.

For completed files, retain the downloaded file and request ownership after
the probe. Collect its dimensions, commit when all probes have finished, then
queue the normal import with its original pixel policy. Handle cache hits as
already-known intrinsic dimensions when their ImageAdditionalData is valid.
Validate PNG first, then completed JPEG/GIF/WebP, duplicate URLs, failed and
unsupported files, authored sizes, and 1x1 images.

ImpSVG already obtains bounds and checks maxPixels, but it calls SvgImport()
before that check. Its probe can therefore do substantial work. Accept this
existing behavior for this plan; do not add an SVG header parser.

## Checkpoint 3: streamed replay

The current MemStream combines read position and earliest retained byte in
head, and MemStreamDelete() frees blocks before head. Separate retained start,
reader position, and download tail. During a probe, advance the reader but
keep blocks from byte zero. On successful size discovery, rewind to byte zero,
leave probe mode, and launch normal ImpGraph import on the same HTTP fetch.
Normal reads may then free consumed blocks. Preserve LPCT_PEEK,
LPCT_PRE_READ, LPCT_RESET_STREAM_STATE, and FJPEG retry semantics. Do not
assume the header fits in the first-packet preservation buffer.

In ImportG, deliberate probe DEFERRED plus valid size must not call
LPCT_DISCARD or send the intelligent-mode deferred UI. Genuine constrained
import rejection retains LPCT_DISCARD. Keep fetch/import synchronization and
stream ownership valid until normal import completes; the fetch thread must
not reuse a stream that is awaiting replay. If a malformed or huge header
exceeds a bounded retention limit, allow the same HTTP fetch to finish its
file and use the completed-file probe path. Never issue a second fetch.

Normal streaming may run before other sources finish probing. Until the global
commit, it may draw into the current rectangle but must not trigger geometry
layout. A final intrinsic mismatch discovered before commit replaces the
collected value; one discovered after commit uses the exceptional fallback.

## Checkpoint 4: redraw-only resolution

After geometryCommitted, IReplaceGraphic() and MSG_HTML_TEXT_RESOLVE_IMAGE
install content and compute drawing transforms from the committed document
rectangle. They preserve HID_size and VTG_size, invalidate the image area, and
do not add waiting images, dirty layout, or request layout. Images with both
authored dimensions follow the same rule even without a probe. Compare final
intrinsic size with stored probed size where one exists; emit an EC diagnostic
and use the old geometry-change/reflow path on a mismatch.

Remove ordinary WAITING_IMAGES_RESOLVE and CALCULATE_LAYOUT calls from
MSG_URL_TEXT_IMPORT_GRAPHIC_PROGRESS. Remove unconditional viewport fitting
and CALCULATE_LAYOUT from MSG_URL_TEXT_DEC_PENDING, retaining page-complete
notification and animations. Audit inline/external SVG, compact-image
activation, and view-change paths so they cannot silently resize committed
ordinary images. Preserve exceptional explicit user actions and mismatch
fallbacks as appropriate.

## Verification

Build each changed geode with ~/pcgeos-tools/aihelp.py build, EC first and NC
second. Leave one small runnable check for nontrivial probe classification and
MemStream rewind/free behavior. Check cancellations and Stop, duplicated URL
images, cache hits, unsupported and broken images, intelligent-mode oversized
images, and import failure. Name/cache references, temporary files, stream
buffers, and page pending counts must each have one clear owner at every
transition.

Temporarily instrument layout requests and actual layout starts with EC
diagnostics, then remove tracing. The target is initial page layout, at most
one geometry-commit layout, and no layout from matching image progress or
completion. Exercise many missing-size images, PNG with streamed JPEG/GIF,
WebP, inline/external SVG, WIDTH+HEIGHT, WIDTH only, HEIGHT only, nested
tables, broken and unsupported sources, intelligent-mode deferral, and 1x1.
Repository instructions say not to run PC/GEOS as an automated test; provide
Swat breakpoints/commands for runtime checking where execution is needed.

After each edit, check git diff --ignore-space-at-eol and ensure only intended
code changes appear. Update supported reusable findings in
~/pcgeos-tools/wiki/. Remove temporary tracing before finishing.

## Open decisions to resolve in code

- Exact image flag/field names and whether stored intrinsic dimensions are
  necessary for every image or only probed images. Prefer the smallest
  persistent record change that still permits the mismatch check.
- How to keep a completed file and its name token alive between probe and
  normal import without double release or deletion.
- Whether streamed normal import can publish pixels before global geometry
  commit. If so, it must preserve collected geometry and avoid layout; if not,
  bound the queued bitmap and stream memory cost.
- The bounded-stream fallback threshold and how it transitions to the
  completed-file path without deadlock or another network request.
- Stable behavior when the viewport is unavailable at geometry commit and
  when it later shrinks. Treat any image-induced post-commit resize as outside
  the normal path.
