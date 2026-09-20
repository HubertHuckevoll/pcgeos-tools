# Mental Model Coding

## Mental Model

Explain `<problem / feature / function / branch difference>`.

Start with a short description of the central idea that gives me a useful mental model of the mechanism.

Then explain the mechanism conceptually, with enough detail that I can:
- reason about its behavior,
- mentally modify it,
- predict the consequences of a change.

Describe the complete relevant mechanism, but omit incidental implementation details that do not materially affect that model.

Clearly distinguish:
- behavior verified from the source,
- reasonable inference,
- uncertainty or missing information.

For a branch, commit, PR, or diff, focus primarily on how the program's mental model changes relative to the base revision. Do not merely narrate changed lines.

Use the real symbols from the analyzed source: functions, methods, messages, variables, data structures, fields, flags, enums, and states.

Whenever an important real symbol is mentioned, link as precisely as possible to its definition or most relevant source location.

## Variables, Data Structures, States

Identify only the variables, data structures, fields, flags, and states that are essential to understanding the mechanism.

For each, briefly explain:
- what it represents,
- who creates or changes it,
- who consumes or reacts to it,
- why it matters to the mechanism.

Show short excerpts of real source code only when they clarify a decisive detail better than prose.

## Program Flow

Create a compact program-flow diagram covering the complete relevant mechanism.

Use real function, method, and message names.

Annotate important transitions with the relevant data or state being:
- read,
- created,
- changed,
- passed,
- tested.

Link every real function or method shown in the diagram to its source location.

Example:

```text
MSG_FOO_START
    |
    | reads: FooData
    v
ProcessFoo()
    |
    | creates: FooState
    | sets: FOO_PENDING
    v
FooCallback()
    |
    | updates: bytesRead
    v
DecideFoo()
    |
    +--> FOO_ACCEPTED
    `--> FOO_REJECTED
```

## Rules

- Use as little Markdown as practical.
- No tables; use prose and simple lists.
- ASCII only; no Unicode.
- Be concise. Prefer the Pareto version: roughly 80 percent of the useful understanding in 20 percent of the text.
- Do not omit any part that is necessary for correctly understanding or reasoning about the mechanism.
- Do not modify code.