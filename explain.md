Explain the requested feature, function, code path, behavior, branch, commit, PR, or diff by following the actual current source code.

The goal is to help me understand the code itself, not to replace it with an abstract explanation.

Use the following structure.

## TL;DR

Start with a very short summary:

- what the mechanism or change does
- where it roughly lives
- the main idea in 3-5 sentences

Do not go into implementation detail yet.

## Program flow

Show a compact program-flow map using the real function, method, message, object, and data-structure names from the repository.

Example:

```text
UI action
  -> MSG_FOO_BAR
  -> HandleFoo()
  -> ProcessBar()
  -> SomeState.flags
  -> UpdateView()
```

Include important state or data transitions where useful.

This should serve as the map for the detailed walkthrough below.

If the request is about a branch, PR, commit, or diff relative to another revision, show a compact before/after flow where useful:

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

Do not reduce the explanation to a textual diff. Explain the resulting program behavior.

## Detailed walkthrough

Now follow the flow step by step through the actual source.

For each important step:

### Name and role

Give the real function, method, message, object, or data-structure name and link it to its actual source location.

Explain its role in the overall flow in 1-2 sentences.

### Relevant code

Show the actual current repository code that is important for understanding this step.

Use enough surrounding code to understand:

- control flow
- important conditions
- calls to the next stage
- state reads and writes
- relevant data structures
- ownership or lifetime when relevant
- message passing
- asynchronous continuation
- error and fallback paths

Prefer complete relevant branches or small complete functions over tiny isolated snippets.

Do not rewrite or simplify quoted code.
Do not convert existing code to pseudocode.
Mark omitted unrelated code explicitly with `...`.

Never silently omit code that changes the meaning of the shown control flow.

### What to notice

Immediately below the code, explain only the important semantics:

- what enters this code
- what decision is made
- what state or data changes
- what is called next
- why this step matters in the overall mechanism

Do not narrate obvious syntax line by line.

Then continue with the next step in the flow.

## Important data structures

If understanding the mechanism depends on structs, enums, flags, object variables, messages, globals, or shared state, show their actual relevant declarations.

Explain briefly:

- what each relevant field or value means
- where it is initialized
- where it changes
- which later code consumes it

Where useful, show the state flow explicitly:

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

## Alternative paths

Show important alternative paths where they materially affect understanding, for example:

- cache hits
- early returns
- failed lookups
- unsupported input
- failed imports
- cancellation
- fallback implementations
- asynchronous completion
- cleanup paths

Do not include unrelated edge cases merely for completeness.

## Branch / diff explanations

If the request is to explain a branch, commit, PR, or diff relative to another revision:

First understand the relevant mechanism in both revisions.

Do not merely narrate changed lines.

For each semantically important change:

1. Explain where it sits in the overall program flow.
2. Show enough unchanged surrounding code to understand the context.
3. Show the relevant base-revision code and current-revision code when the contrast matters.
4. Explain what changed in control flow, data flow, state, error handling, ownership, or observable behavior.
5. Follow the changed path into downstream functions when necessary.

Ignore mechanical changes unless they affect behavior.

The goal is to understand how the program works differently after the change, not simply what lines were edited.

## Mental model

Finish by compressing the mechanism again into a short explanation.

Then show one final compact flow diagram using the real names already explained above.

The final summary should make sense because the concrete code behind it has already been shown.

## Investigation rules

Inspect the actual current repository state.

For PC/GEOS work, prefer:

```text
~/pcgeos-tools/aihelp.py get <symbol>
```

before broad repository searches.

Start from a useful observable anchor when possible, such as:

- UI text
- message name
- menu action
- callback
- known symbol
- changed function
- visible behavior

Then follow the code naturally through:

```text
anchor
  -> messages / handlers
  -> functions
  -> data structures
  -> state changes
  -> downstream calls
  -> observable result
```

Follow the relevant path far enough that the explanation does not stop at an arbitrary function boundary.

Do not assume that the first matching function is the whole mechanism.

Distinguish clearly between:

- behavior verified from the current source
- reasonable inference
- remaining uncertainty

If I ask to explain a specific function, method, message, data structure, or point from a previous program-flow map, apply this same format recursively to that narrower scope.

Do not modify files unless I explicitly ask for implementation.