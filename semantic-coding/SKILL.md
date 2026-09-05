---
name: semantic-coding
description: >
  Understand, modify, and review existing code through a stable semantic model:
  structured natural-language pseudocode, addressable functional blocks,
  semantic zoom, semantic diffs, and post-implementation audits.
  Use when the human wants to stay in control of concepts, algorithms, data flow,
  state, ownership, and behavior while delegating syntax and low-level mechanics
  to the coding agent.
---

# Semantic Coding

## Goal

Keep the human programmer in control of the program model.

The human should primarily work with:

- responsibilities
- functional blocks
- algorithms
- control flow
- states and transitions
- data flow
- invariants
- ownership and lifetime
- side effects
- error paths
- interactions between subsystems

The agent may handle:

- syntax
- pointer plumbing
- declarations
- API details
- calling conventions
- mechanical refactoring
- repetitive edits
- compiler-specific details

Do not turn the human into a spectator.

The semantic representation is the main interface between the human and the source code.

---

# Three-model rule

Always distinguish these three things:

1. **SOURCE MODEL**  
   What the existing code actually does.

2. **INTENDED MODEL**  
   What the human wants the code to do.

3. **IMPLEMENTED MODEL**  
   What the resulting patch actually does.

Never silently assume that they are identical.

Before editing, derive SOURCE MODEL from the real repository.

Before implementation, make the change visible as an INTENDED MODEL or semantic diff.

After implementation, reconstruct IMPLEMENTED MODEL from the actual diff and compare it
with INTENDED MODEL.

---

# User-facing operations

Recognize these explicit commands and equivalent natural-language requests:

- `MAP <topic>`
- `EXPLAIN <block-id>`
- `TRACE <behavior-or-block>`
- `ZOOM IN <block-id>`
- `ZOOM OUT <block-id>`
- `CHANGE <block-id>: <instruction>`
- `MOVE <source-block> -> <target-block>: <instruction>`
- `SPLIT <block-id>`
- `MERGE <block-id> <block-id>`
- `SHOW SOURCE <block-id>`
- `SHOW DIFF`
- `AUDIT`

Examples:

```text
MAP intelligent image loading
```

```text
EXPLAIN IMG.LOAD.PREFLIGHT
```

```text
CHANGE IMG.LOAD.PREFLIGHT:
Known unsupported file extensions must stop here without starting a request.
```

```text
MOVE IMG.LOAD.PROBE.TYPE -> IMG.LOAD.PREFLIGHT:
Do the cheap extension check before network access.
```

```text
AUDIT
```

The human does not need to use exact command syntax. Interpret ordinary language in the
same way when the intent is clear.

---

# Default workflow

For non-trivial work:

1. Inspect the relevant repository code.
2. Construct SOURCE MODEL.
3. Present a compact semantic map.
4. Let the human inspect or manipulate semantic blocks.
5. Produce a semantic diff describing the requested change.
6. Implement that semantic diff.
7. Build and test.
8. Reconstruct IMPLEMENTED MODEL from the resulting source diff.
9. Compare IMPLEMENTED MODEL with INTENDED MODEL.
10. Report mismatches, uncertainty, and unverified assumptions explicitly.

Do not jump directly from a broad feature request to code changes unless the human
explicitly asks for direct implementation.

---

# Repository investigation

Investigate narrowly first.

Prefer symbol-aware lookup, callers, callees, and nearby code over broad repository
searches.

Do not infer semantics from function names alone.

Inspect enough surrounding code to determine:

- who calls the behavior
- what state exists before the call
- what state is expected afterward
- which component owns resources
- where errors propagate
- whether callbacks or messages change control flow
- whether behavior is duplicated elsewhere

For PC/GEOS work, when available, prefer:

```sh
~/pcgeos-tools/aihelp.py get <symbol>
```

before broad source searches when a useful symbol is already known.

For builds, when available, prefer:

```sh
~/pcgeos-tools/aihelp.py build [path]
```

instead of invoking `pmake` directly, so routine build noise stays out of the reasoning
context.

Use broader searches when targeted lookup is insufficient.

---

# Semantic blocks

Represent behavior as stable, addressable blocks.

Each block gets an ID that remains stable for the duration of the task.

Preferred form:

```text
<DOMAIN>.<AREA>.<FUNCTION>
```

Examples:

```text
IMG.LOAD.PREFLIGHT
IMG.LOAD.REQUEST
IMG.LOAD.PROBE
IMG.IMPORT.SELECT
IMG.UI.PLACEHOLDER
HTML.LAYOUT.BLOCK
MEM.IMAGE.OWNERSHIP
```

If a block is split, extend the name rather than replacing unrelated IDs:

```text
IMG.LOAD.PROBE.TYPE
IMG.LOAD.PROBE.SIZE
```

Do not renumber blocks merely because display order changes.

If an existing block moves to another component, preserve the old ID as an alias during
the current task and show the new canonical ID.

---

# Semantic block format

Use this structure when describing a block:

```text
[IMG.LOAD.PREFLIGHT] Reject obviously unsupported images early

Purpose
  Decide whether image loading may proceed before expensive work begins.

Receives
  - image URL
  - currently known image-type information
  - loading policy

Flow
  1. Determine whether the type is already known cheaply.
  2. If definitely unsupported:
       -> mark the image as not loadable
       -> continue at [IMG.UI.PLACEHOLDER]
  3. Otherwise:
       -> continue at [IMG.LOAD.REQUEST]

Produces
  - decision whether a request may start
  - possibly updated image state

Important state / invariants
  - no network request has started when this block is entered
  - unknown is different from unsupported

Side effects
  - may mutate image loading state
  - does not allocate imported image data
  - does not perform network I/O

Failure paths
  - malformed source information -> treat according to existing fallback policy

Source
  - path/file.goc :: ExactSymbolName
  - path/other.c :: OtherVerifiedSymbol
```

Only include source references that were actually verified.

If line numbers are available and useful, include them, but prefer stable symbol
references over brittle line-number-only references.

---

# Abstraction level

Default to a middle level between ELI5 prose and source-code transcription.

A good semantic block usually contains about 3-10 meaningful steps.

Describe:

- decisions
- transformations
- state transitions
- resource lifetime
- externally visible behavior
- important cross-component calls

Normally hide:

- temporary variables
- routine pointer passing
- syntax
- boilerplate
- register allocation
- mechanical setup and teardown

unless those details change program semantics.

Too abstract:

```text
The browser checks the image and loads it.
```

Too concrete:

```text
Increment SI, dereference ds:[si], compare AX with zero, and jump to label 42.
```

Preferred:

```text
Determine whether the image type is already known.

If it is known and unsupported:
  -> stop before creating a network request
  -> continue at [IMG.UI.PLACEHOLDER]

If it is supported or still unknown:
  -> continue at [IMG.LOAD.REQUEST]
```

---

# Semantic zoom

Support multiple levels without forcing the human to read all detail at once.

## Level 0: system view

Major components only.

```text
[HTML.PARSE]
    |
[IMG.DISCOVER]
    |
[IMG.LOAD]
    |
[IMG.IMPORT]
    |
[IMG.RENDER]
```

## Level 1: functional view

Responsibilities and important branches.

```text
[IMG.LOAD.PREFLIGHT]
        |
        +-- unsupported --> [IMG.UI.PLACEHOLDER]
        |
[IMG.LOAD.REQUEST]
        |
[IMG.LOAD.PROBE]
        |
[IMG.IMPORT.SELECT]
```

## Level 2: algorithm view

Conditions, state transitions, ownership, side effects, and failure paths.

## Level 3: implementation view

Relevant functions, messages, APIs, fields, handles, pointers, registers, or source
details.

Default to Level 1 or Level 2.

`ZOOM IN` reveals one level more detail for the selected block only.

`ZOOM OUT` collapses detail without losing the block ID.

---

# Structured flow notation

Prefer compact structured notation that resembles a Struktogramm/Nassi-Shneiderman
diagram in text.

Sequence:

```text
[A]
 |
[B]
 |
[C]
```

Decision:

```text
[TYPE KNOWN?]
  YES -> [SUPPORTED?]
           YES -> [REQUEST]
           NO  -> [PLACEHOLDER]
  NO  -> [REQUEST]
```

Loop:

```text
FOR EACH candidate importer
  |
  +-- accepts type? -- YES --> [TRY IMPORT]
  |                            |
  |                            +-- success --> DONE
  |
  +-- NO ---------------------> next candidate
```

State transition:

```text
DISCOVERED
   |
   v
PENDING_REQUEST
   |
   +-- unsupported --> PLACEHOLDER
   |
   +-- success ------> IMPORTING --> READY
   |
   +-- error --------> FAILED
```

Do not use decorative diagrams when a simpler structure communicates the same semantics
more clearly.

---

# Semantic references

The human must be able to refer back to prior explanations reliably.

When presenting a semantic map:

- give every meaningful block an ID
- use those IDs in later explanations
- preserve IDs across iterations
- explicitly announce renamed/split/merged blocks
- never silently reuse an ID for different semantics

The human may give instructions such as:

```text
Change IMG.LOAD.PREFLIGHT so unsupported extensions stop there.
```

Treat the referenced block as the primary target and investigate only enough neighboring
blocks to preserve correctness.

---

# CHANGE protocol

When the human requests a change to a semantic block:

## 1. Restate the requested semantic change

Keep it short.

## 2. Show semantic diff before implementation

Use:

```text
SEMANTIC DIFF

[IMG.LOAD.PREFLIGHT]

BEFORE
  Known or unknown type
    -> [IMG.LOAD.REQUEST]
    -> later probe may reject it

AFTER
  Known unsupported type
    -> [IMG.UI.PLACEHOLDER]

  Known supported or unknown type
    -> [IMG.LOAD.REQUEST]

UNCHANGED
  - placeholder rendering
  - importer selection
  - handling of genuinely unknown types
```

Also list:

```text
Affected blocks
  - IMG.LOAD.PREFLIGHT
  - IMG.LOAD.REQUEST

Expected unaffected blocks
  - IMG.UI.PLACEHOLDER
  - IMG.IMPORT.SELECT
```

## 3. Implement

Change only what is necessary for the semantic diff.

Prefer minimal, local patches.

Do not introduce unrelated cleanup unless required for correctness.

## 4. Verify

Build and run relevant tests.

## 5. Reconstruct from actual code

Do not merely repeat the intended design.

Read the resulting diff and derive IMPLEMENTED MODEL from it.

---

# MOVE protocol

`MOVE` means relocate responsibility, not merely move source lines.

Before implementation identify:

- which semantic responsibility is moving
- which state it requires
- which side effects it performs
- which callers currently depend on its location
- whether ownership/lifetime changes
- whether error handling changes

Show before/after responsibility boundaries.

Example:

```text
MOVE IMG.LOAD.PROBE.TYPE -> IMG.LOAD.PREFLIGHT

BEFORE
  PREFLIGHT:
    allows request

  PROBE.TYPE:
    rejects obvious unsupported extension after request

AFTER
  PREFLIGHT:
    rejects obvious unsupported extension before request

  PROBE.TYPE:
    handles only types that remain unknown after request
```

---

# TRACE protocol

Use `TRACE` when behavior crosses several blocks.

Trace one concrete path through the program.

Example:

```text
TRACE unsupported WebP URL

1. [IMG.DISCOVER]
   URL found.

2. [IMG.LOAD.PREFLIGHT]
   ".webp" is recognized as definitely unsupported.

3. [IMG.UI.PLACEHOLDER]
   Placeholder metadata is produced.

4. [IMG.LOAD.REQUEST]
   NOT ENTERED.

Observable result
  Placeholder shown; no image download started.
```

State explicitly which blocks are not entered when that matters.

---

# Details that must not be abstracted away

Hide low-level mechanics only when they are semantically irrelevant.

Always surface details when they affect correctness.

Especially for PC/GEOS and other legacy systems, explicitly show:

## Memory and ownership

- allocation
- deallocation
- owner of allocated memory
- transfer of ownership
- borrowed vs owned references
- lifetime across callbacks/messages
- failure cleanup

## Handles and locks

- handle creation/destruction
- lock/unlock balance
- whether a pointer is valid only while locked
- movable-memory assumptions
- handles stored across calls

## Object/message context

- object receiving a message
- synchronous vs asynchronous behavior when relevant
- instance data being mutated
- message return semantics
- callback/reentrancy implications

## Segments and execution context

- segment assumptions
- thread context
- stack-sensitive state
- calling convention when it affects correctness
- far/near pointer distinctions when semantically relevant

## Resource state

- resource loading/unloading
- reference counts
- file/network handles
- graphics state
- temporary objects

## Failure paths

- early returns
- partial initialization
- cleanup obligations
- fallback behavior
- propagated vs swallowed errors

These belong in the semantic model whenever they can alter behavior, stability, or review
safety.

---

# Legacy-code rule

Do not modernize code merely because a newer style appears cleaner.

Preserve repository conventions unless the requested change requires otherwise.

For old systems, apparently awkward code may encode constraints involving:

- compiler behavior
- memory model
- ABI
- object system
- build tooling
- binary compatibility
- historical platform bugs

If such a constraint is suspected but not verified, label it as uncertainty instead of
rewriting around it.

---

# Evidence levels

Distinguish facts from inference.

Use these markers when useful:

```text
VERIFIED
  Directly established from source, build, test, or documented repository behavior.

INFERRED
  Strongly suggested by surrounding code but not directly proven.

UNKNOWN
  Relevant behavior could not be established from inspected material.
```

Never present inference as verified behavior.

---

# Implementation discipline

When implementing an agreed semantic change:

- preserve established project style
- prefer the smallest correct patch
- avoid speculative abstractions
- avoid unrelated cleanup
- preserve error handling unless deliberately changed
- preserve ownership and lifetime unless deliberately changed
- preserve public behavior outside the semantic diff
- build/test the narrowest relevant target first
- expand testing when the change crosses subsystem boundaries

If implementation reveals that the agreed model was incomplete or wrong, stop expanding
the patch and update the semantic model first.

For tiny mechanical details needed to finish an already agreed block, proceed without
interrupting the human.

---

# Post-implementation audit

`AUDIT` must be based on the actual resulting source and diff.

Use this structure:

```text
IMPLEMENTATION AUDIT

Intended semantic change
  Known unsupported image types are rejected before network request creation.

Implemented model

[IMG.LOAD.PREFLIGHT]
  VERIFIED
  - recognizes known unsupported extension
  - routes directly to [IMG.UI.PLACEHOLDER]

[IMG.LOAD.REQUEST]
  VERIFIED
  - no longer receives those known unsupported cases

[IMG.LOAD.PROBE]
  VERIFIED
  - still handles unresolved/unknown types

Agreement with intended model
  MATCH

Unexpected semantic changes
  None found.

Ownership / lifetime changes
  None.

Error-path changes
  None.

Build
  EC: PASS
  NC: PASS

Tests
  <results>

Remaining uncertainty
  <none or explicit items>
```

Possible agreement states:

- `MATCH`
- `PARTIAL MATCH`
- `MISMATCH`
- `UNVERIFIED`

Do not declare `MATCH` merely because the build succeeds.

---

# Adversarial audit

When practical, audit as if reviewing another programmer's patch.

Do not rely on the implementation explanation.

Reconstruct behavior from:

- actual changed code
- unchanged surrounding code
- callers/callees
- tests
- build results

Ask:

- What does the patch really change?
- What new paths exist?
- What old paths disappeared?
- What state crosses the changed boundary?
- Who owns resources on every exit?
- Can locks or handles escape their valid lifetime?
- Do failures leave partially changed state?
- Did supposedly unaffected behavior actually change?
- Is any new code present whose purpose cannot be explained in the semantic model?

If code cannot be explained in the model, flag it.

Unexplained code is not PR-ready merely because it compiles.

---

# PR-readiness view

When asked whether a patch is ready for review, summarize it semantically.

Use:

```text
PR SEMANTIC SUMMARY

Problem
  <what was wrong>

Behavior before
  <short SOURCE MODEL>

Behavior after
  <short IMPLEMENTED MODEL>

Changed semantic blocks
  - BLOCK.ID
  - BLOCK.ID

Important invariants preserved
  - ...

Ownership / handle / lock effects
  - ...

Error-path effects
  - ...

User-visible effect
  - ...

Verification
  - builds
  - tests

Uncertainty / reviewer attention
  - ...
```

The goal is that the human can explain the patch to a maintainer without depending on the
agent's hidden reasoning.

---

# Definition of done

A semantic-coding task is complete only when:

1. the relevant existing behavior has a SOURCE MODEL,
2. the requested change has an explicit INTENDED MODEL,
3. the code implements that change,
4. the relevant build/tests have been run,
5. IMPLEMENTED MODEL has been reconstructed from the actual patch,
6. differences between intended and implemented behavior are reported,
7. important ownership, locking, object-context, lifetime, and failure-path effects are
   understood or explicitly marked unknown,
8. the human can identify the changed functional blocks and describe what each now does.

Compilation alone is not sufficient.

---

# Interaction style

Keep semantic output compact and manipulable.

Prefer:

- blocks
- short structured flows
- before/after models
- explicit references
- small diagrams
- clear invariants

Avoid:

- giant prose explanations
- full source dumps unless requested
- line-by-line narration
- excessive implementation detail at the default zoom level
- unexplained design choices

The purpose is not to explain programming to a beginner.

The purpose is to expose the program's meaningful machinery at a level where an
experienced human can reason about and modify it directly.
