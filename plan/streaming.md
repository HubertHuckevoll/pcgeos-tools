# Plan: Intelligent Streaming Admission and Import

## Goal

In Intelligent mode:

- Probe image dimensions from the incoming HTTP stream.
- Stop oversized downloads immediately.
- For accepted JPEG/GIF images, replay the probe bytes and continue importing while the download proceeds.
- For accepted PNG, WebP, SVG, and other supported formats, finish downloading and then import from the completed file.
- Preserve existing Automatic, cache, cancellation, and explicit-load behavior.

## Streaming state

Extend `LoadProgressData` with compact trailing fields:

- Maximum allowed pixel count.
- Admission/stream flags for:
  - probe pending
  - streaming import allowed
  - streaming import started
  - size-policy rejection

Add callback results for `CONTINUE` and `REJECT`. Existing read callbacks continue returning byte counts.

This remains conditional on `PROGRESS_DISPLAY`; builds without it retain completed-file admission.

## Admission flow

Update the image request path in `URLTEXT.goc`:

- Intelligent requests always receive a load callback.
- Set “streaming import allowed” only when:
  - `imageProgressMode == IMAGE_PROGRESS_STREAM`
  - the image position is eligible
  - its declared height does not exclude progressive display
- Normalize the response MIME type before probing:
  - lowercase it
  - remove parameters such as `; charset=...`
  - retain the existing GIF assumption when no image MIME type is available
- Initialize the replayable stream without starting an importer.

For each incoming block:

1. Retain bytes up to the 4096-byte probe ceiling.
2. Run ImpGraph’s probe outside the stream semaphore.
3. If dimensions are found:
   - Reject when zero or over the pixel limit.
   - Otherwise accept immediately.
4. If dimensions remain unknown:
   - Keep buffering below 4096 bytes.
   - Reject upon reaching 4096 bytes.
   - At EOF, reject using the available shorter prefix.

Probe-buffer allocation failure disables early admission and falls back to the existing completed-file probe.

## JPEG/GIF handoff

When an accepted image is JPEG or GIF and streaming import is allowed:

- Keep the probed prefix in the stream.
- Reset its read position to byte zero.
- Append any unbuffered remainder of the HTTP block that triggered acceptance.
- Mark streaming import as started.
- Start the existing import thread through `MSG_URL_TEXT_LOAD_GRAPHIC_PROGRESS`.
- Continue appending subsequent HTTP blocks normally.
- Do not run the completed-file dimension probe: the successful stream probe is authoritative.
- Still write the HTTP data to the source-cache file so a successful download remains cacheable.

The import request must separately remember that it belongs to Intelligent mode. Pass a zero pixel-probe value so `ImportG` does not attempt another probe against the live stream, but defer the image if the decoder reports `MIME_STATUS_MEMORY_LIMIT`.

For an accepted JPEG/GIF shorter than the initial probe window, do not start an importer at EOF; use the completed-file path because no progressive display benefit remains.

## Admission-only formats

For PNG, WebP, SVG, and other formats:

- Use the incoming stream only for dimension admission.
- On acceptance, clear the probe buffer and detach the load callback.
- Continue downloading normally.
- Run the existing completed-file probe before import.
- Preserve completed-file scanline progress where already supported.

No PNG decoder changes are included.

## HTTP behavior

Update Wmg3Http to distinguish admission from ordinary progress:

- Preserve the existing known-content-length transfer check before opening the stream.
- Do not disable callbacks merely because `URB_RQ_LIMIT_SIZE` is active when an Intelligent probe is pending.
- Only invoke image admission for final file responses, never redirect bodies.
- If admission rejects before import starts:
  - stop reading
  - disable socket reuse
  - delete the partial file
  - return `URL_RET_TOO_LARGE | URB_RF_NOCACHE`
- If admission succeeds without starting an importer, retain `URL_RET_FILE`.
- If a JPEG/GIF importer starts, retain the existing `URL_RET_PROGRESS` ownership model: the import thread owns the pending count and final replacement.

For unknown-length or chunked transfers that exceed the transfer limit after import has started:

- Mark the shared stream as size-rejected.
- Close and wake the importer.
- Return `URL_RET_PROGRESS_ABORT | URB_RF_NOCACHE` so the fetch acknowledgement does not complete the image separately.
- Prevent socket reuse and delete the partial source file.
- Have `ImportG` discard any partial or complete bitmap/cache token using the existing cancellation ownership rules, then send `MSG_URL_TEXT_INTERNAL_DEFER_LIKE_GRAPHICS`.
- Ensure the pending count and name token are completed exactly once by the import thread.

## API changes

- Append the new state fields to `LoadProgressData`; do not reorder existing fields.
- Allow `ToolsProbeGraphicByDriver()` to receive an optional `LoadProgressData *`.
  - Streaming admission passes the active stream.
  - Completed-file admission passes null.
- Reuse the existing `URL_RET_TOO_LARGE` path before import starts.
- Do not add a MIME-driver entry point, URL request field, or new URL result code.

## Cache and retry behavior

- Early rejection leaves no source-cache file.
- Activating the compact image performs a new unrestricted download and bypasses the pixel probe.
- Completed-file pixel rejection retains the existing cached source file; activation reuses it.
- Cache hits continue through completed-file admission.
- Automatic-mode JPEG/GIF streaming remains unchanged.
- Intelligent mode with Final or Import progress settings performs admission-only downloading and completed-file import.

## Tests

Add a small runnable admission/stream-state test covering:

- Small and oversized GIF, JPEG, and PNG headers.
- JPEG dimensions found after metadata but before 4096 bytes.
- Unknown or truncated input at EOF.
- Unknown dimensions at the 4096-byte ceiling.
- MIME parameters and absent MIME headers.
- No loss or duplication when acceptance occurs partway through an HTTP block.
- Replay beginning at byte zero for JPEG/GIF.
- Probe allocation failure falling back to completed-file admission.

Integration-test:

- Accepted JPEG and GIF display scanlines before their downloads finish.
- Oversized JPEG/GIF/PNG downloads stop early and become compact.
- Accepted PNG finishes downloading before import.
- Known-length transport rejection occurs before import starts.
- Chunked transfer rejection after import starts removes the partial graphic and becomes compact.
- User abort does not become a size deferral.
- Explicit compact-image activation downloads and imports without either limit.
- Cache hits retain completed-file checking.
- Automatic mode and all three progress-display settings retain their documented behavior.

Build EC and NC variants of BbxBrow, Wmg3Http, and ImpGraph with `aihelp.py`.

Commit summary: `Enable intelligent streaming admission and progressive JPEG/GIF import`