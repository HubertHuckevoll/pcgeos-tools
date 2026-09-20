# "Mental Model Coding"

## Mental Model
Explain `<problem / feature / function / branch difference>`.

Start with a short description that helps me build a good **mental model** of the the central idea of the mechanism. Then describe the mechanism at a conceptual level so that I can mentally modify it and reason about the consequences of a change.

Focus on the complete relevant mechanism, not incidental implementation details. Clearly distinguish verified behavior from the source from assumptions or uncertainty.

If I ask about a branch, commit, PR, or diff, explain primarily **how the mental model of the program changes compared with the base revision**, rather than merely narrating the diff.

Use the real symbols, function and message names, data structures, fields, and states from the current source code. Link important symbols as precisely as possible to their exact source location.

## Variables, Data Structures, States
Then introduce the **most important variables, data structures, and states**. Briefly explain what role they play and where they are changed or consumed. Show decisive real code excerpts where useful.

## Program-flow diagram
Next, create a compact **program-flow diagram** of the complete relevant mechanism. Use real function/message names and briefly annotate important transitions with the data or state being read, created, or changed. Always link to the mentioned real functions / methods in the source code from this program-flow diagram.

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
Use as little markdown as possible, no tables, just lists.
No unicode, just ASCII.
Be concise and as brief as possible without omitting any relevant pieces: prefer a pareto version of the explanation: 80 percent of the information at 20 percent of the text length.
Do not modify any code.