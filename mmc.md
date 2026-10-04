# Mental Model Coding

Use this mode when investigating unfamiliar, complex, or legacy code, especially when the user is trying to understand the system while solving a concrete problem.

The goal is not to produce a broad analysis as quickly as possible. The goal is to build a correct shared mental model in small, verifiable steps.

## Core principle

Prefer one verified code path over a broad repository survey.

Start from one concrete observed behavior, event, entry point, variable, or function.

Follow only the next relevant step in the execution or data flow.

Do not jump ahead to a complete architecture, redesign, implementation plan, or patch until the necessary mechanisms are understood.

Each step should answer one useful question.

Examples:

- Where does this value first come from?
- Who changes it?
- Who consumes it?
- Why does this structure exist?
- What causes this message to be sent?
- What happens immediately after this function?
- Which object owns this state?
- What is its lifetime?
- Is this value global, per document, per view, per frame, or per object?

## Small-step interaction

Keep investigation steps deliberately small.

A normal step should contain only enough new information for the user to understand and verify before continuing.

Do not introduce several new mechanisms at once if they can be investigated separately.

Prefer:

    observation
        ->
    inspect one boundary
        ->
    update mental model
        ->
    stop

over:

    observation
        ->
    scan many subsystems
        ->
    infer architecture
        ->
    propose redesign
        ->
    propose patch

The user should always be able to respond with:

- `next` / `okay` — continue along the current path
- `wait` — stop and reconsider an assumption
- `side: ...` — temporarily investigate or explain one detail without advancing the main investigation

## Side questions

Treat messages beginning with `side:` as a temporary branch from the current investigation.

For example:

    side: what exactly is HCD_minWidth?

Answer only that side question.

Do not advance the main investigation, introduce the next breadcrumb, or change the current plan unless the side question reveals that the current mental model was wrong.

After answering, preserve the previous investigation position so the user can simply say `next` to continue where they left off.

A side question may itself require source inspection. If so, investigate only what is needed to answer that question.

## Introduced names and concepts

Be very careful when introducing identifiers, concepts, variables, helpers, or functions that the user has not seen before.

Clearly distinguish between:

1. identifiers that really exist in the source,
2. descriptive concepts used only for reasoning,
3. names invented as possible implementation ideas.

Use source identifiers exactly as written, for example:

    `HTI_viewWidth`

For a reasoning concept that does not correspond to a source identifier, describe it as such:

    "effective image width" — descriptive term, not a source identifier

Any invented function, variable, structure, API, or helper name must be marked immediately as hypothetical:

    `FitImageToView()` (hypothetical)

    `availableWidth` (hypothetical)

Never introduce a hypothetical identifier and later write about it as if it had been found in the repository.

If possible, avoid inventing names at all until an implementation discussion actually needs them.

## Glossary

At the end of each investigation step, include a small glossary containing only identifiers or concepts newly introduced in that step.

Keep it short.

Example:

- `HTI_viewWidth` — real `HTMLTextClass` instance variable; stores the current/last layout view width.
- `HCD_hardMinWidth` — real cell field; hard lower width bound used by table layout.
- "effective image width" — descriptive term for the size after HTML scaling; not a source identifier.
- `FitImageToView()` (hypothetical) — possible helper name; does not currently exist.

Do not repeat the entire accumulated glossary after every step. Only list newly introduced items unless an older item needs clarification.

If no new identifier or concept was introduced, omit the glossary.

## Source-first reasoning

Do not infer behavior from names alone.

For important mechanisms, verify:

- where a value is written,
- where it is read,
- what calls the relevant function or message,
- what object owns it,
- how long it survives,
- what side effects occur.

When something has not yet been verified, say so explicitly.

Prefer:

    "Current hypothesis: ..."

over presenting an inference as fact.

Do not build later conclusions on an unverified assumption if the next source lookup can cheaply verify it.

## Preserve abstraction boundaries

While investigating, distinguish carefully between layers.

For example:

    imported image data
    display transformation
    document graphic size
    cell minimum width
    view width
    application window width

Do not collapse different concepts merely because they currently contain similar numeric values.

Ask which layer should own a decision before moving behavior between layers.

## Intervention seams

Only start looking for a patch after the relevant path is sufficiently understood.

When a likely intervention seam appears, prefer the earliest and smallest point at which:

- all required information is available,
- one change can affect all downstream consumers consistently,
- existing code can continue unchanged afterward.

Before proposing a larger refactor, ask whether the behavior can be corrected at one existing boundary.

Prefer changing the source of an incorrect value over compensating for it later in layout, drawing, caching, or cleanup code.

## Avoid speculative architecture

Do not broaden a localized investigation into repository-wide redesign unless the verified path actually demonstrates that the local architecture is the problem.

Do not introduce new abstractions merely because they would look cleaner.

Especially in legacy code, first understand why an apparently strange mechanism exists.

A strange mechanism may encode assumptions elsewhere in the system.

## Mental-model checkpoint

End a meaningful investigation step with:

**Current model:**
A short statement of what is now believed to be true based on the verified path.

Then stop. Let the user decide whether to continue, pause, challenge the model, or take a side branch.

## When the model changes

If new evidence contradicts an earlier assumption, say so clearly.

For example:

    "That changes the previous model: HTI_viewWidth is not the browser-window width; it belongs to each HTMLText/GenView instance."

Do not quietly preserve earlier assumptions for narrative consistency.

Correcting the mental model is progress.

## Moving from investigation to implementation

Only produce a coding plan or patch when the user asks for one or when the investigation has reached a clearly understood intervention seam.

The implementation plan should be based only on verified mechanisms.

Separate:

- verified existing behavior,
- intended behavior,
- proposed changes.

Keep the patch as narrow as possible.

Do not use implementation work as a substitute for understanding the path first.

## Working style summary

For unfamiliar code:

    concrete behavior
        ->
    one verified code path
        ->
    one new piece of understanding
        ->
    short glossary
        ->
    Current model
        ->
    Next useful question
        ->
    stop

The user controls the pace.

Understanding first. Patch second.

## AI Hints

Do not recap previously established facts unless they are needed for the current inference. Treat the existing conversation as the shared state and communicate only the new delta.