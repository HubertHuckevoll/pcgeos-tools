---
name: semantic-coding
description: >
  Semantic programming workflow for understanding, changing, and auditing existing
  code through stable functional blocks, structured natural-language pseudocode,
  semantic diffs, and post-implementation audits.
---

# Semantic Coding

## Purpose

Keep the human in control of concepts and behavior while the agent handles low-level
implementation mechanics.

The human primarily works with:

- functional blocks
- algorithms and control flow
- state and data flow
- responsibilities and invariants
- ownership and lifetime
- side effects and failure paths

The agent may handle syntax, pointers, declarations, APIs, calling conventions,
mechanical refactoring, and repetitive edits.

Do not turn the human into a spectator.

---

# Three models

Always distinguish:

1. **SOURCE MODEL** — what the current code actually does.
2. **INTENDED MODEL** — what the human wants it to do.
3. **IMPLEMENTED MODEL** — what the resulting patch actually does.

Before editing, derive SOURCE MODEL from the repository.

Before implementation, show the requested change as an INTENDED MODEL / semantic diff.

After implementation, reconstruct IMPLEMENTED MODEL from the actual diff and compare it
with INTENDED MODEL.

---

# Operations

Recognize these commands and natural-language equivalents:

- `MAP <topic>` — map existing behavior
- `EXPLAIN <block-id>` — show one block in more detail
- `TRACE <behavior-or-block>` — trace one execution path
- `ZOOM IN <block-id>`
- `ZOOM OUT <block-id>`
- `CHANGE <block-id>: <instruction>`
- `MOVE <source> -> <target>: <instruction>`
- `SPLIT <block-id>`
- `MERGE <block-id> <block-id>`
- `SHOW SOURCE <block-id>`
- `SHOW DIFF`
- `AUDIT`

---

# Default workflow

For non-trivial changes:

1. Inspect relevant code.
2. Build SOURCE MODEL.
3. Present semantic map.
4. Let the human modify referenced blocks.
5. Show semantic diff.
6. Implement only that change.
7. Build/test.
8. Reconstruct IMPLEMENTED MODEL from the actual diff.
9. Compare intended vs implemented behavior.
10. Report mismatches and uncertainty.

Do not jump from a broad request directly to implementation unless explicitly asked.

---

# Repository investigation

Investigate narrowly first.

Prefer symbol-aware lookup, callers, callees, and nearby code over broad searches.
Do not infer behavior from symbol names alone.

For PC/GEOS, when available, prefer:

```sh
~/pcgeos-tools/aihelp.py get <symbol>
~/pcgeos-tools/aihelp.py build [path]
```

Use broader searches only when targeted lookup is insufficient.

Inspect enough context to establish callers, downstream expectations, state, ownership,
side effects, error propagation, callbacks/messages, and duplicated behavior.

---

# Semantic block IDs

Give meaningful behavior stable, addressable IDs:

```text
<DOMAIN>.<AREA>.<FUNCTION>
```

Examples:

```text
IMG.LOAD.PREFLIGHT
IMG.LOAD.REQUEST
IMG.LOAD.PROBE
IMG.UI.PLACEHOLDER
```

Keep IDs stable during the task.

When splitting, extend IDs:

```text
IMG.LOAD.PROBE.TYPE
IMG.LOAD.PROBE.SIZE
```

Never silently reuse an ID for different semantics.

---

# Block format

Use this compact form:

```text
[BLOCK.ID] Short name

Purpose
  Responsibility of this block.

Receives
  - meaningful inputs/state

Flow
  1. meaningful step
  2. condition
       -> [OTHER.BLOCK]
  3. result

Produces
  - output/state change

Invariants
  - facts that must remain true

Side effects
  - allocation/free
  - lock/unlock
  - messages/callbacks
  - I/O/network
  - state mutation

Failure paths
  - condition -> result

Source
  - path/file.goc :: VerifiedSymbol
```

Include only sections that matter. Only cite source locations actually verified.

---

# Abstraction level

Default to a middle level: normally 3-10 semantic steps per block.

Describe decisions, transformations, state transitions, ownership, side effects,
failure paths, and important cross-component calls.

Hide routine syntax, temporary variables, pointer passing, registers, and boilerplate
unless they affect correctness.

Good:

```text
If the type is known and unsupported:
  -> stop before creating a network request
  -> continue at [IMG.UI.PLACEHOLDER]

Otherwise:
  -> continue at [IMG.LOAD.REQUEST]
```

Avoid both vague prose and line-by-line source transcription.

---

# Semantic zoom

Use four levels:

- **L0 System** — major components
- **L1 Functional** — responsibilities and branches
- **L2 Algorithm** — conditions, state, ownership, failures
- **L3 Implementation** — functions, messages, fields, pointers, registers, APIs

Default to L1/L2.

`ZOOM IN` exposes only the selected block in more detail.
`ZOOM OUT` collapses detail without changing its ID.

---

# Structured flow

Prefer compact Struktogramm-like text:

```text
[TYPE KNOWN?]
  YES -> [SUPPORTED?]
           YES -> [REQUEST]
           NO  -> [PLACEHOLDER]
  NO  -> [REQUEST]
```

For traces:

```text
DISCOVERED
   |
PREFLIGHT
   +-- unsupported --> PLACEHOLDER
   |
REQUEST --> IMPORT --> READY
```

Use diagrams only when they clarify the structure.

---

# CHANGE protocol

Before implementation, show:

```text
SEMANTIC DIFF

[BLOCK.ID]

BEFORE
  ...

AFTER
  ...

UNCHANGED
  - ...

Affected blocks
  - ...

Expected unaffected blocks
  - ...
```

Then implement the smallest patch that realizes the semantic diff.

Do not mix unrelated cleanup into the change.

If implementation reveals that the model is wrong or incomplete, update the semantic
model before expanding the patch.

---

# MOVE protocol

`MOVE` relocates responsibility, not merely source lines.

Before editing, identify:

- responsibility being moved
- required state
- side effects
- callers/dependencies
- ownership/lifetime changes
- error-path changes

Show the responsibility boundary before and after.

---

# TRACE protocol

Trace one concrete path through block IDs.

State:

- entered blocks
- important state transitions
- side effects
- exit/result
- relevant blocks that are deliberately not entered

---

# Never hide correctness-critical low-level details

Surface these whenever relevant:

## Memory / ownership
- allocation/free
- owner
- ownership transfer
- borrowed vs owned references
- lifetime across calls/messages
- cleanup on failure

## Handles / locks
- creation/destruction
- lock/unlock balance
- pointer validity while locked
- movable-memory assumptions
- handles retained across calls

## Object / message context
- receiver
- synchronous/asynchronous semantics
- instance state mutation
- callbacks/reentrancy
- return semantics

## Execution context
- segment assumptions
- thread context
- stack-sensitive state
- calling conventions
- near/far distinctions when relevant

## Resources / failures
- resource/file/network handles
- graphics state
- partial initialization
- early exits
- fallback behavior
- cleanup obligations

For PC/GEOS these details are part of the semantic model when they affect correctness.

---

# Legacy-code rule

Do not modernize code just because a newer style looks cleaner.

Preserve repository conventions unless the requested semantic change requires otherwise.

Treat possible compiler, memory-model, ABI, object-system, build, or compatibility
constraints as important. If unverified, mark them as uncertainty instead of rewriting
around them.

---

# Evidence

Distinguish:

```text
VERIFIED  Directly established from code/build/test.
INFERRED  Strongly suggested but not proven.
UNKNOWN   Could not be established.
```

Do not present inference as fact.

---

# Implementation discipline

- prefer the smallest correct patch
- preserve project style
- preserve unrelated behavior
- preserve ownership/lifetime unless intentionally changed
- preserve error handling unless intentionally changed
- avoid speculative abstractions
- build/test the narrowest relevant target first

Proceed without interruption for tiny mechanical details needed to complete an already
agreed semantic change.

---

# AUDIT

Audit from the actual resulting source and diff, not from the implementation rationale.

Reconstruct behavior as if reviewing another programmer's patch.

Check:

- new and removed execution paths
- changed state boundaries
- ownership/lifetime
- handle/lock balance
- failure cleanup
- supposedly unaffected behavior
- unexplained code

Use:

```text
IMPLEMENTATION AUDIT

Intended change
  ...

Implemented model
  [BLOCK.ID]
    VERIFIED
    - ...

Agreement
  MATCH | PARTIAL MATCH | MISMATCH | UNVERIFIED

Unexpected semantic changes
  ...

Ownership / lifetime
  ...

Error paths
  ...

Build/tests
  ...

Remaining uncertainty
  ...
```

A successful build does not imply `MATCH`.

Code whose purpose cannot be explained in the semantic model is not PR-ready.

---

# PR readiness

When asked whether a patch is ready, summarize:

```text
PR SEMANTIC SUMMARY

Problem
  ...

Behavior before
  ...

Behavior after
  ...

Changed blocks
  - ...

Preserved invariants
  - ...

Ownership / handles / locks
  ...

Error-path effects
  ...

User-visible effect
  ...

Verification
  ...

Reviewer attention / uncertainty
  ...
```

The human should be able to explain the patch without depending on hidden agent reasoning.

---

# Done

A task is complete when:

1. existing behavior has a SOURCE MODEL,
2. requested behavior has an INTENDED MODEL,
3. code implements it,
4. relevant build/tests ran,
5. IMPLEMENTED MODEL was reconstructed from the real patch,
6. differences are reported,
7. correctness-critical ownership/locking/context/failure details are understood or
   explicitly marked unknown.

Compilation alone is insufficient.

---

# Output style

Keep semantic output compact and manipulable.

Prefer block IDs, structured flows, before/after models, invariants, and short diagrams.

Avoid giant prose explanations, source dumps, line-by-line narration, and unnecessary
implementation detail at the default zoom level.
