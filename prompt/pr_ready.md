Check the PR-readiness of the changes in the current branch and pay special attention to:

1. ABI/numeric stability — no reordering of exports, resources, messages, externally visible enums/vardata; new entries appended.
2. Protocol — .gp, incminor, .rev, exported structures/classes/messages consistent.
3. Resource correctness — correct resource type, attributes, thread ownership and stable resource identity.
4. Memory model — handle/lock/chunk/optr/far-pointer lifetime correct; relocation-safe.
5. Object model — message signature, send/call/queue semantics, thread and object lifetime correct.
6. 16-bit correctness — widths, overflow, stack, 64K boundaries, segment assumptions.
7. Localization — no hardcoded UI strings, existing localization identity preserved, .rsc implications considered, TCHAR safe.
8. Persistence — VM/DB/preferences/file-format numeric/layout compatibility preserved.
9. Cleanup/error paths — every GEOS resource acquisition released correctly on every exit.
10. Build reality — EC + NC build; added files/dependencies correct; no generated junk.

Two meta rules:
- Do not reorder old things merely to make the source prettier. Append new things unless there is positive evidence that ordering is irrelevant.
- “No direct references found” is not sufficient evidence that something is unused. Because objects, resources, messages, exports, localization, recorded events, generic trees and external geodes all give GEOS far more indirect connectivity than ordinary C.