## Role

Work in ~/pcgeos/. Write compact, correct code for PC/GEOS, a resource-constrained 16-bit DOS environment.

When writing or reviewing code, prefer the smallest correct change. The best code is often the
code not written. Always check:

1. Is this actually needed?
2. Does existing PC/GEOS code already do it?
3. Does a native GEOS/platform feature do it?
4. Does the standard library do it?
5. Does an already-installed dependency do it?
6. Can this be one line?
7. Otherwise, write the minimum code that works.

Avoid new abstractions, new dependencies, boilerplate, extra files, and one-use helpers unless explicitly requested or required for correctness.

Deletion over addition. Boring over clever. Fewest files possible.

Question complex requests: "Do you actually need X, or does Y cover it?"

Pick the edge-case-correct option when two approaches are the same size. Less code must not mean weaker code.

Mark intentional shortcuts with an ATTENTION: comment. Name the known ceiling and the upgrade path.

Do not be lazy about trust-boundary input validation, data-loss prevention, security, accessibility, or explicit user requirements.

Non-trivial logic leaves one small runnable check behind. Use an assert demo, self-check, or tiny test file. No frameworks. Trivial one-liners need no test.

## Scope

~/pcgeos/ contains the source, tools, and docs for the 16-bit PC/GEOS operating environment for DOS, also known as GeoWorks Ensemble, Breadbox Ensemble, and NewDeal Office.

Our product is called PC/GEOS Ensemble. Older Breadbox terminology in the source is outdated.

Main folders:

* Appl/ - GEOS applications
* Library/ - GEOS libraries, UI, graphics, VM/DB, Kernel/geos.geo
* Driver/ - DOS, video, mouse, printer, and other drivers
* Include/ - ESP assembler headers
* CInclude/ - GOC/C headers
* Tools/ - build/debug tools, pmake, Swat, TCL scripts
* Tools/build/product/bbxensem/ - PC/GEOS Ensemble product build files
* Loader/ - boot and loader code
* TechDocs/ - SDK docs; prefer TechDocs/Markdown
* Installed/ - build tree and build artifacts
* bin/ - built tools

Builds happen in Installed/. Source truth is outside Installed/ unless explicitly stated.

## GEOS knowledge base

Persistent knowledge about PC/GEOS that you discover while woking on / with it
is stored in `~/pcgeos-tools/wiki/`.

Before doing substantial repository research, check `~/pcgeos-tools/wiki/`.

When you discover a non-obvious, reusable fact about GEOS while working on
a task, update the appropriate document in `~/pcgeos-tools/wiki/`.

Only record facts that are supported by the source tree or authoritative
documentation. Include enough information to find the evidence again:
file paths, function/message names, structures, constants, or relevant
source locations.

Do not record:
- guesses or unresolved hypotheses
- task-specific implementation details
- temporary branch state
- facts obvious from a single local function

Prefer correcting an existing entry over adding a contradictory one.
Keep entries concise.

## General GEOS rules

Do not normalize or change line endings. Before editing a file, preserve its existing line ending style exactly:
- LF files must stay LF.
- CRLF files must stay CRLF.
- Mixed or legacy files must not be mass-rewritten.
Never make line-ending-only changes. Never run formatters on unrelated files. After editing, check `git diff --ignore-space-at-eol` and ensure the diff contains only intentional code changes. If a file shows as fully rewritten because of line endings, revert that file and redo the edit without changing line endings.

Use GOC by default for new applications and libraries. GOC transpiles to Watcom C 16-bit.

Use ESP for drivers.

Keep changes minimal and surgical.

Keep stacks small. No big local variables. Use MemHandles or LMemHeaps.

Use small buffers. Usually stay at or below 8 KB. Use 32 KB only when truly needed.

Use GEOS memory management, which basically follows the pattern of:

* MemAlloc (create a handle for a memory block)
* MemLock (lock the memory block and get a pointer to the locked block)
* MemUnlock (allow the system to move the memory block around)
* MemFree (free the memory block)

Do not use malloc or free.

Use HAF_ZERO_INIT as the last MemAlloc parameter unless there is a specific reason not to.

Handles are scarce. Do not waste memory handles or file handles.

Use pure ASCII only in code and comments.

For new system apps or APIs, propose docs only in TechDocs/Markdown.

Feature plans should be plain, spec'ed-down markdown: headings, paragraphs, lists. No tables, images, decorative markdown, or backtick-heavy formatting.

## GOC/C rules

Use C89.

Declare variables at the top of functions, not inside blocks.

Declare functions as _pascal by default.

Use (void*)0 for null pointer constants.

Indent with 4 spaces.

Function braces go on new lines.

Inside functions, block opening braces stay on the same line.

Name handles with trailing H.

Name pointers with trailing P.

Do not recreate HIGHC aliases.

Do not manually edit Makefile or dependencies.mk. They are generated by mkmf in Installed/ subdirectories.

For libraries, avoid globals. Pass a context structure instead.

Use WWFixed instead of float whenever applicable.

Prefer GOC objects, messages, and instance variables over standalone helpers.

CAUTION: the process class has no instance variables. Its variables are globals.

goto is allowed only for cleanup paths at the end of a function.

Use typedefs for callback functions instead of the PCM macro.

## ESP/ASM rules

push ds, dx requires pop ds, dx, not pop dx, ds.

Indent ASM/ESP like this:

* 1 tab for pure comment lines
* 2 tabs for actual code lines
* 1 tab between instruction and first parameter

Introduce ASM blocks with:

;
; Description
;

Procedure names and labels are never indented.

uses, .enter, and .leave are indented with 1 tab.

Comment every non-trivial or non-intuitive instruction.

Do not put semicolon comments inside macros like < EC >. Put comments behind the macro instead.

If ESP warns about double or triple jumps, fix with LONG.

## Implementation

If a coding task seems simple enough, use Luna for the actual implementation work. Delegate to Luna early, before extensive parent-agent investigation. Keep the delegated context minimal: pass only the task, relevant constraints, and needed repository paths. Let Luna inspect the repository and use aihelp.py directly. The parent agent should primarily orchestrate, review the resulting diff, and run builds/tests. Do not duplicate substantial analysis in both the parent agent and Luna.

Use ~/pcgeos-tools/aihelp.py to reduce repository-search and build output:

    ~/pcgeos-tools/aihelp.py get <symbol>
    ~/pcgeos-tools/aihelp.py build [path]

Prefer aihelp.py get before broad source searches. Prefer aihelp.py build over invoking pmake directly so normal build noise stays out of the model context.

End each implementation round with one extremely tight summary that could be used as a commit message.

## Building geodes

Always try to compile the geodes you changed through aihelp.py:

    ~/pcgeos-tools/aihelp.py build [source-or-module-path]

aihelp.py maps source paths to the matching Installed/ directory, runs pmake as a subprocess, builds EC first and NC second, and returns compact diagnostics instead of the full build log.

For a new geode, or when generated build files are missing, create them manually first in the matching Installed/ directory with mkmf and pmake depend, then use aihelp.py build.

Ignore generated Makefile and dependencies.mk changes.
