IMPLEMENTATION PLAN EVALUATION
Evaluate an implementation plan I’ll paste after this.
Output requirements:
- Return the original plan as plain text (no Markdown). Reflow line breaks to 80
characters.
- Otherwise do not rewrite, reorder, delete, or add anything except TODO lines.
- Insert TODO lines only where ambiguity would genuinely block implementation.
- Use the exact format: TODO: Clarify <issue> (keep it short and specific and
make exactly one suggestion how to clarify this issue).
- Keep TODOs to the absolute minimum. If you can reasonably infer/decide something
while implementing, do not add a TODO.
- Do not ask questions outside the plan text. No preface, no explanation, no
extra commentary.
Plan:

CODE CLEANUP
You are a senior engineer doing a ruthless code audit.
Task: Review the AI-generated code in XXX and judge whether it is implementation-clean, minimal, maintainable (not micro-optimized).

What to look for (be strict):
1. Bloat / overengineering
* Unnecessary abstractions, layers, helpers, patterns, generic frameworks, “future-proofing”.
* Excessive configurability or indirection without a real need.
* Too many options/flags/types for a narrow problem.

2. Leftovers / iteration debris
* Dead code, unused variables/imports, redundant helpers, commented-out blocks, TODOs that are no longer relevant.
* Duplicate logic from earlier attempts, half-migrated approaches, compatibility shims that aren’t needed.
* Debug logging, temporary hacks, test scaffolding accidentally shipped.

3. Algorithmic sanity
* Algorithm complexity vs the actual requirements (time/memory).
* Any “clever” algorithm that misses the core or is unjustified.
* Data structures that don’t match access patterns.
* Hidden worst cases (quadratic loops, unbounded recursion, unnecessary full scans, extra passes).

4. Clarity and correctness risks
* Ambiguous naming, unclear invariants, leaky abstractions.
* Error handling that is either missing or overly complex.
* Concurrency/async pitfalls if applicable.
* Edge cases likely to break in production.

Output format (follow exactly):
A) Verdict: one of [SHIP / NEEDS TRIM / REWRITE]
B) 5 bullet points of findings, grouped under:
* Bloat
* Leftovers
* Algorithm / Complexity
* Clarity / Risks
C) Minimal patch plan: the smallest set of changes to reach SHIP quality.
* Must be concrete (what to delete/merge/rename/simplify).
* Prefer deletion over refactor.
D) If you mark REWRITE, provide:
* A simpler approach.
* The key data flow and the minimal API surface.

Rules:
* Do NOT ask questions unless absolutely blocking. Infer what you reasonably can from the code and context.
* Do NOT propose new features.
* Optimize for simplicity, not cleverness.
* If something is acceptable, say so briefly; otherwise be blunt.