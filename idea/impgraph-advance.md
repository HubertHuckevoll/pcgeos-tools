# ImpGraph resumable import plan

## Current checkpoint

- Status: not started.
- Next action: complete Phase 0 and record the baseline below.
- Completed phases: none.
- Blockers: none known.
- Last verification: none.

This file is the handoff record. Before starting, read this checkpoint and the
first incomplete phase. After each finished task or interrupted work session,
update the checkboxes, next action, verification result, and any blocker.
Record what actually happened; never mark a phase complete solely because code
was written. If the source tree changes, recheck the baseline before following
old assumptions.

## Goal and boundary

Give ImpGraph an internal Open/Advance/Close lifecycle. Convert PNG into the
first decoder that can pause after useful scanline updates. Keep existing MIME
graphic calls and browser behavior compatible. Do not change BBXBrow, HTTP,
cache, or the progressive-download stream in this project.

Keep the session contract private until a later phase has a real external
caller. Do not add it to CInclude/htmldrv.h during the internal work. Use a
private header only if more than one ImpGraph source file needs the types.
Keep state small and reuse pngIDATState rather than copying its fields.

## Compatibility contract

- Preserve ImpGraph's GP exports and ordinals: MIMEDRVGRAPHIC (0),
  MIMEDRVINFO (1), MIMEDRVTEXT (2), MIMEDRVGRAPHICEX (3), and
  MIMEDRVGRAPHICEX2 (4). Do not reorder them or change their signatures.
- Preserve extFlags, maxPixels, MIME_STATUS_DEFERRED, memory-limit handling,
  abort handling, usedMem, and ImageAdditionalData results.
- Preserve the existing MIME dispatch and fallback order for GIF, JPEG,
  PNG, and WebP, including image/jpg. Keep SVG's existing direct path.
  A deferred or memory-limited import must stop fallback.
- Keep JPEG, GIF, WebP, and SVG one-shot in this project. Preserve GIF
  animations and current JPEG/GIF progressive-download behavior.
- Preserve PNG's existing partial-image result on a progressive abort and
  its no-progress abort behavior. Do not treat every abort as a null result.
- Preserve the current final bitmap compaction and VM-chain ownership rules.
  Keep FreeViaProgress until browser ownership is redesigned separately.
- Preserve both PROGRESS_DISPLAY and non-PROGRESS_DISPLAY builds.

Evidence to recheck: Library/Breadbox/ImpGraph/impgraph.gp,
Library/Breadbox/ImpGraph/MAIN/impgraph.goc, CInclude/htmldrv.h,
Library/Breadbox/ImpGraph/IMPBMP/imppng.goc, and
Library/PngLib/pngimp.c.

## Phase 0: Baseline and invariants

- [ ] Record the current export list, dispatcher branches, and fallback order.
- [ ] Trace PNG success, malformed input, truncation, abort, progress callback,
      final compaction, and cleanup. Record who owns the VM chain in each case.
- [ ] Trace pngIDATState lock and pointer lifetimes across a scanline, plus
      its return values and inflate cleanup on error.
- [ ] Build ImpGraph EC and NC with aihelp.py. Record the result here.

Done when the existing behavior and resource owners are written down in a
short note under this phase. This is investigation only; no code change.

Baseline notes: pending.

## Phase 1: Private one-shot session dispatcher

- [ ] Define only the private state and results needed now: session handle,
      Open parameters, an update, and Advance outcomes. Do not reserve GIF
      frame or streaming-input states before they are implemented. Represent
      the VM chain and IAD type so animations and GStrings still work.
- [ ] Add private Open/Advance/Close. A first Advance may run a complete
      legacy import. Keep the current dispatcher and fallback semantics.
- [ ] Make all three graphic entry points call a single one-shot wrapper that
      opens, advances until terminal, closes, and returns the old result.
- [ ] Pass the existing caller-owned iad, usedMem, mimeStatus, and progress
      pointer through without changing their lifetime or output semantics.
- [ ] Keep WebP, SVG, JPEG, GIF, and PNG on their existing decoder paths.
- [ ] Build EC and NC. Check export order and compile a dependent caller if
      a header or linked interface changed.

Done when every format still completes in its first Advance and the wrapper
has no visible behavior change. Leave a small runnable check for non-trivial
dispatcher logic; do not run PC/GEOS itself.

## Phase 2: Define PNG pause safety

- [ ] Decide where PNG state lives and document which memory blocks are locked
      at entry, at a checkpoint return, on resume, and at cleanup.
- [ ] Resolve raw pointers in pngIDATState and z_stream before returning from
      Advance. Do not leave movable blocks locked between calls merely to keep
      stale pointers valid.
- [ ] If PngLib needs a suspend/resume or cleanup fix, change
      Library/PngLib/pngimp.c and CInclude/pnglib.h as narrowly as possible.
      Do not assume the original four-file scope is sufficient.
- [ ] Ensure inflateEnd has one owner on error and normal close. Check every
      partially initialized allocation and file handle.
- [ ] Add a tiny runnable state or cleanup check where feasible; build any
      changed library EC and NC.

Done when a PNG decoder can safely return after a row and later continue on
the same thread, including after memory movement and error cleanup.

## Phase 3: Resumable PNG decoding

- [ ] Open and validate the source, dimensions, and format. Apply maxPixels
      before bitmap or IDAT allocation and set MIME_STATUS_DEFERRED as today.
- [ ] Retain the file, pngIDATState, palette/output information, allocation
      accounting, bitmap, and current line for the session lifetime.
- [ ] Decode up to a private useful checkpoint per Advance. Return the
      bitmap, dirty scanline range, size, and completion state; use no public
      row-count or work-budget parameter.
- [ ] Distinguish end of image from truncated or invalid input. Preserve
      format fallback only when the file is actually an unknown format.
- [ ] Check MIME_STATUS_ABORT before further work and at safe row boundaries.
      Preserve the existing partial-output rule for progressive imports.
- [ ] Make Close release decoder resources exactly once. State explicitly
      whether the wrapper, progress receiver, or decoder owns each VM chain.
- [ ] Build EC and NC and run a small check for repeated Advance, completion,
      abort, malformed/truncated input, and two independent sessions.

Done when an ordinary PNG uses multiple Advance calls and final output matches
the old one-shot path. Keep Adam7 and streaming compressed input out of scope.

## Phase 4: Move PNG progress to the wrapper

- [ ] Remove direct progress callback calls from the PNG decoder.
- [ ] Have the one-shot wrapper translate PNG updates into the existing
      ImportProgressData fields and invoke its existing callback.
- [ ] Preserve callback ordering, firstLine/lastLine, bitmap identity,
      completeGraphic, and the distinction between partial and final output.
- [ ] Handle GrCompactBitmap replacement and FreeViaProgress so a published
      partial chain is neither leaked nor freed twice.
- [ ] Verify progressive abort with and without a published bitmap, plus
      decoding without a progress callback.
- [ ] Build EC and NC. Run the small checks and inspect the focused diff.

Done when PNG progress reaches current callers through Advance returns and
the wrapper, with no browser source changes.

## Phase 5: Final compatibility review

- [ ] Build ImpGraph and any changed PngLib, then build BbxBrow and one other
      MIME graphic caller where the build tree permits.
- [ ] Check both PROGRESS_DISPLAY configurations if available.
- [ ] Review all five entry signatures and ordinal positions.
- [ ] Check GIF, JPEG, WebP, SVG, PNG fallback, maxPixels, deferred status,
      memory accounting, abort, callback, compaction, and ownership paths.
- [ ] Run the project's small checks. Do not attempt to run PC/GEOS.
- [ ] Check git diff --ignore-space-at-eol for intentional changes only.
- [ ] Update this checkpoint with exact build results and any remaining risk.

Done when all listed checks pass or a specific limitation is documented.

## Later projects, not part of this implementation

- Convert JPEG, then GIF, to genuinely resumable decoders in separate work.
- Decide whether WebP or SVG benefits from the same lifecycle.
- Export a proven session API only when BBXBrow needs to call it directly;
  append exports after the existing GP entries and add the appropriate minor
  protocol tranche. Define public ownership and error semantics then.
- Change BBXBrow's importer to use the exported API, then retire its legacy
  callback ownership path when no caller needs it.
- Consider a streaming ImageSource only after the decoder lifecycle works.

The separate idea/streaming.md proposal is independent. Do not silently fold
its HTTP admission or cache changes into this plan.
