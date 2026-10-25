Explain the current state of debugging for this bug based on the actual repository state, previous investigation, test results, debugger observations, logs, and attempted fixes.

The goal is to reconstruct the debugging state accurately so I can understand what is known, what is still uncertain, and where investigation should continue.

Do not start the investigation over from scratch unless necessary.

## TL;DR

Summarize in 3-5 sentences:

- observed bug
- expected behavior
- current best explanation, if any
- what remains unresolved

Clearly distinguish facts from hypotheses.

## Current program flow

Show the relevant execution/data flow using real functions, methods, messages, and data structures.

Mark the point where actual behavior is known or suspected to diverge from expected behavior.

Example:

```text
UI action
  -> MSG_FOO
  -> ProcessFoo()
  -> UpdateState()
  -> RenderBar()
             ^
             |
        divergence?
```

## Confirmed facts

List only things supported by concrete evidence.

For each fact, briefly state the evidence:

- source code
- debugger observation
- log/output
- reproducible test
- build result
- experiment
- previous patch result

## Relevant code

Walk through the code that currently matters for the bug.

For each important location:

- give the real symbol and source link
- show the relevant actual code
- explain what the code proves or leaves uncertain
- connect it to the observed symptom

Do not narrate unrelated code.

## Hypotheses

For each current hypothesis show:

```text
[H1] Short descriptive name

Claim:
...

Evidence for:
...

Evidence against:
...

Status:
likely / plausible / weak / ruled out / untested
```

Do not preserve hypotheses that existing evidence has already disproved.

## What has already been tried

Summarize previous debugging actions and patches.

For each:

- what was changed or tested
- what result was expected
- what actually happened
- what was learned

A failed fix is evidence. Preserve that knowledge.

## Current debugging frontier

Identify the smallest unresolved question that currently blocks understanding.

Prefer something concrete such as:

> We know `ProcessFoo()` receives the correct value, but we do not yet know whether `UpdateBar()` overwrites it before rendering.

Avoid vague statements such as “more investigation is needed.”

## Next discriminating experiment

Propose the smallest experiment that best distinguishes between the remaining plausible explanations.

Prefer:

- breakpoint/watchpoint
- trace/log at one precise transition
- controlled input
- temporary assertion
- minimal code instrumentation
- comparison against known-good path

Explain what each possible result would tell us.

Do not make speculative code changes just to “try something.”

## Investigation rules

Inspect the current source before asserting how the code works.

For PC/GEOS work, prefer:

```text
~/pcgeos-tools/aihelp.py get <symbol>
```

before broad repository searches.

Reuse previous debugging evidence from the conversation whenever available.

Do not repeat experiments whose outcome is already known unless verification is necessary.

Distinguish explicitly between:

- confirmed fact
- inference
- hypothesis
- unresolved question

Do not modify files unless I explicitly ask you to continue debugging or implement a fix.