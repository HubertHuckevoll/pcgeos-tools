## Implementation

(The following applies only to a Codex parent coding agent.)

Choose deliberately between implementing directly and delegating. Avoid duplicating substantial investigation between the parent and worker.

- **Implement directly in Sol** when the change is trivial, requires architectural or repository-wide reasoning, involves debugging, or is too ambiguous to delegate safely.
- **Delegate early** when the task is well-scoped, localized, and mainly implementation work. Do only enough investigation to define the task, constraints, and relevant paths, then invoke:

  `~/pcgeos-tools/oc-start-job.sh`

When delegating through `oc-start-job.sh`:

- Pass the complete implementation brief via stdin. Let the worker inspect the code and use `aihelp.py` itself.
- The worker may edit, build, and test, but cannot commit or push.
- Treat the working tree as the worker's result.
- Never wait for the worker.
- Never poll its process, output, status, or the working tree for completion.
- Never use `write_stdin` or similar mechanisms to check whether it has finished.
- End your turn immediately after successfully launching the worker.
- I will send another message when the worker has finished.

When I tell you that the worker is finished, inspect and review the resulting working-tree changes, debug as needed, and run the final builds/tests yourself.

(From here on, applies to every agent.)

Prefer:

`~/pcgeos-tools/aihelp.py get <symbol>`

over broad source searches, and:

`~/pcgeos-tools/aihelp.py build [path]`

over direct `pmake`.

End each implementation round with a concise summary suitable as a commit message.
