Explain the requested feature, function, code path, behavior, branch, commit, PR, or diff by following the actual current source code.

The goal is to help me understand the program itself. The explanation is intended to establish a stable mental model of the
current implementation. When explaining code after an implementation, reconstruct the mental model from the actual resulting source rather than repeating the previous plan. If a previous target design was discussed, explicitly point out meaningful differences between the intended mental model and the implementation that actually exists.

Use two explanation levels:

- `LIGHT` is the default.
- `FULL` means: first produce the complete LIGHT explanation, then append a detailed annotated source-code walkthrough.

Treat requests such as `full`, `detailed`, `deep`, `walk me through the code`, or equivalent as FULL mode.

Do not modify files unless I explicitly ask for implementation.

---

# LIGHT

## TL;DR

Start with a very short summary of 3-5 sentences:

- what the mechanism or change does
- where it roughly lives
- the central implementation idea
- what differs from the base revision, if this is a branch/diff explanation

Keep this concrete but compact.

---

## Important data structures

Show the actual relevant structs, enums, flags, object variables, messages, globals, or shared state.

Include small real source excerpts where useful.

Explain briefly:

- what the important fields or values mean
- where they are initialized
- where they change
- which later code consumes them

Show important state transitions visually when useful:

```text
STATE_NONE
   |
   v
STATE_PENDING
   |
   +--> STATE_ACCEPTED
   |
   `--> STATE_DEFERRED
```

Do not list data structures that do not materially contribute to understanding the mechanism.

---

## Program flow

Show the complete relevant program flow using the real function, method, message, object, and data-structure names from the repository.

Example:

```text
UI action
  -> MSG_FOO_BAR
  -> HandleFoo()
  -> ProcessBar()
       -> SomeState.flags
  -> UpdateView()
```

Include important state/data transitions where useful.

For branch, PR, commit, or diff explanations, show a compact before/after flow when this helps:

```text
BASE

A()
  -> B()
  -> C()

CURRENT

A()
  -> B()
       -> NewDecision()
       -> C()
```

The flow should be complete enough to act as a map for the mechanism, but compact enough to understand at a glance.

Link important symbols to their actual source locations whenever possible.

---

## Mental model

Finish the LIGHT explanation with a concise description of the complete mechanism using the real names already introduced.

Then show one final compact flow diagram.

The mental model should make it possible to explain the mechanism to another programmer without reading the full implementation.

For branch/diff explanations, emphasize how the resulting program behaves differently from the base revision, not merely which lines changed.

---

# FULL

If FULL mode was requested, continue after the complete LIGHT explanation.

Visually separate this section clearly.

# Detailed annotated code walkthrough

Follow the program flow from the LIGHT section step by step through the actual source.

Use the same order as the program-flow map whenever practical.

For every important stage, use this structure:

---

## `<real symbol name>`
`path/to/source:line`

**Role:** One short sentence explaining why this function, method, message, or data structure matters in the overall flow.

### Annotated source

Show the actual relevant source code from the current repository.

Keep the repository code itself unchanged.

Add explanatory comments directly above or beside the relevant statements so the code can largely explain itself.

Example:

```c
/* Read the image-loading mode selected by the user. */
imageMode = @call NavigateLoadGraphics::
    MSG_GEN_ITEM_GROUP_GET_SELECTION();

/* A non-zero probe limit activates intelligent probing.
 * Zero preserves the normal image-loading path. */
imageProbeMaxPixels =
    imageMode == IMAGE_LOAD_INTELLIGENT
        ? INTELLIGENT_IMAGE_MAX_PIXELS
        : 0;

/* The normal loader receives the additional constraint.
 * Intelligent loading is therefore a mode of the normal path,
 * not a separate loader. */
ProcessSingleGraphic(..., imageProbeMaxPixels);
```

Annotate semantics rather than obvious syntax.

Useful comments explain:

- why this statement matters
- what information enters here
- what decision is being made
- what state or data changes
- what invariant is being maintained
- what downstream code relies on this value
- ownership or lifetime implications
- message passing
- asynchronous continuation
- error or fallback behavior

Avoid comments such as:

```c
i++;    /* increment i */
```

Prefer complete relevant branches or small complete functions over tiny disconnected snippets.

Show enough surrounding code to preserve the actual control flow.

If unrelated code is omitted, mark it explicitly:

```c
/* ... unrelated code omitted ... */
```

Never omit code that changes the semantic meaning of the shown path.

### Transition

After the annotated code, add only a short transition to the next stage, for example:

**Next:** `ProcessSingleGraphic()` receives `imageProbeMaxPixels` and stores it in request state used by the asynchronous fetch callback.

Do not repeat in prose what the inline annotations already explain.

---

Repeat for each important stage.

## Relevant alternative paths

Include important alternatives only where they affect the requested mechanism, for example:

- cache hits
- early returns
- failed lookups
- unsupported inputs
- importer failures
- cancellation
- fallback paths
- asynchronous completion
- cleanup or ownership paths

Prefer integrating them into the relevant annotated code block rather than creating long separate prose sections.

---

# Branch / diff rules

If the request is to explain a branch, commit, PR, or diff relative to another revision:

First understand the relevant mechanism in both revisions.

Do not merely narrate the textual diff.

In LIGHT mode:

- summarize the behavioral difference
- show before/after program flow
- show changed or newly relevant data/state
- explain the resulting mental model

In FULL mode:

For each semantically important change:

1. Show enough unchanged context to understand where the change sits.
2. Show BASE and CURRENT code separately when direct comparison helps.
3. Annotate the code itself.
4. Explain changes in:
   - control flow
   - data flow
   - state
   - ownership/lifetime
   - error/fallback behavior
   - observable behavior
5. Follow downstream consequences when necessary.

Ignore mechanical changes unless they affect behavior.

The goal is to understand how the program works differently after the change, not simply what lines were edited.

---

# Investigation rules

Inspect the actual current repository state.

For PC/GEOS work, prefer:

```text
~/pcgeos-tools/aihelp.py get <symbol>
```

before broad repository searches.

Start from a useful observable anchor when possible, such as:

- UI text
- menu item
- message name
- callback
- known symbol
- visible behavior
- changed function
- diff hunk

Then follow the code naturally through:

```text
anchor
  -> message / handler
  -> function
  -> data structure
  -> state change
  -> downstream calls
  -> observable result
```

Do not stop at the first matching symbol.

Follow the relevant path far enough that the explanation covers the complete mechanism rather than an arbitrary function boundary.

If I ask to explain a specific function, method, message, data structure, or point from a previous program-flow map, apply the same LIGHT/FULL structure recursively to that narrower scope.

Clearly distinguish between:

- verified behavior from the current source
- reasonable inference
- remaining uncertainty