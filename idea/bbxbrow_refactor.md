We want a conservative source-organization cleanup of BbxBrow.

Target:
<Describe the class, source files, or source area to reorganize.>

Scope:
<Describe whether this is one extraction or a complete subsystem split.>

Work on the current branch. Treat the existing behavior as authoritative.

The goal is to make the architecture easier to understand without changing behavior, object structure, message semantics, threading, memory ownership, calling conventions, or GEOS code-resource placement.

Follow the repository's AGENTS.md instructions. Search for AGENTS.md first. Before substantial research, consult ~/pcgeos-tools/wiki/. Do not use skills unless explicitly requested.

## Organize by complete concerns

Choose coherent subsystem boundaries that help a reader understand the code.

Do not create a new file for every small method group. A file should represent a meaningful concern, including the existing helpers and state that belong with it.

A small initial extraction can establish an unfamiliar pattern. Once that pattern is understood and validated, proceed through the authorized scope in substantial, coherent groups.

Prefer expanding an existing subsystem file over creating another small file.

The primary class file may remain a compact, substantive core containing class registration, lifecycle, coordination, or other responsibilities that naturally belong together.

Use descriptive source filenames. Keep existing function, message, class, field, and global names unchanged.

## Source files and GEOS resources are separate concerns

A .goc or .c source-file boundary can affect code segments and resources. Resource placement must be preserved deliberately.

Do not create a new code resource merely because a new source file exists.

BbxBrow deliberately uses compiler-specific segment pragmas, for example:

    #ifdef __BORLANDC__
    #pragma codeseg FRFETCH2_TEXT
    #pragma option -dc-
    #endif

    #ifdef __WATCOMC__
    #pragma code_seg("FRFETCH2_TEXT")
    #endif

FRFETCH.goc isolates MSG_URL_FRAME_URL_FETCHED in FRFETCH2_TEXT because that code remains on the call stack during parsing. Preserve such resource designs.

Inspect the actual effective placement before moving code. Do not assume all code in a source file occupies one resource.

Preserve compiler-specific behavior. A legacy Borland pragma without a corresponding Watcom pragma may intentionally—or historically—produce different placements. A source-only refactor must not silently “correct” that difference.

Preserve relevant compiler options and string-placement behavior as well as segment names.

For Watcom, an explicit code_seg pragma can leave an empty filename-derived default segment in the object file. Apply a scoped -nt=ORIGINAL_RESOURCE compiler option when needed to avoid new empty-segment diagnostics, while retaining explicit source pragmas.

Do not suppress linker warnings globally.

## Preserve GOC class ownership and dispatch

GOC supports implementing one class across multiple object files using @extern method.

Keep one @classdecl in the class-owning file.

In that file, register moved methods using:

    @extern method SomeClass, MSG_SOME_MESSAGE;

In the implementation file, define them using:

    @extern method SomeClass, MSG_SOME_MESSAGE
    {
        ...
    }

Preserve conditional guards on both sides.

Keep method registrations at their original positions where practical. Do not insert, remove, rename, or reorder @message declarations. Message numbers depend on declaration order.

Preserve message parameters, return values, handler types, superclass calls, and queueing flags.

Check dependencies introduced by macro expansion, not just literal symbol references. For example, BbxBrow status, progress, and abort macros may reference HTMLVApp and require an @extern object declaration in the implementing file.

## Preserve helper boundaries and calling conventions

Move existing helpers with their callers when that forms a coherent concern.

Do not change a helper's calling convention or visibility merely to make a source split easier. In BbxBrow, LOCAL means _near _pascal; moving callers away from a near helper requires special care.

An existing, self-contained plain C concern may become a private .c/.h module when that improves the architecture. Keep its interface small and private, retaining existing names, signatures, behavior, and resource placement.

Do not invent new helper abstractions or public APIs.

Add a private shared header only where separate translation units genuinely need existing declarations or structures. Avoid duplicated structure definitions.

Keep integration state where it is conceptually owned. For example, MemStream.c owns buffering internals, while URLTextImageProgress.goc retains G_stream, callbacks, synchronization, and stream lifecycle responsibility.

Source movement must not transfer allocation, cleanup, reference-counting, or synchronization responsibility.

## Inspect and explain before editing

Inspect:

- The target sources and class/interface headers.
- Existing splits that demonstrate the relevant GOC pattern.
- Segment pragmas and relevant compiler flags.
- Source and generated build configuration.
- Conditional build paths.
- Callers, helpers, shared structures, macros, and ownership relationships.

Capture a successful baseline build and relevant linked output where available.

Before editing, report a short mental model:

- The proposed subsystem groups.
- Their current and target source files.
- Their effective original code resources.
- Their code resources after the move.
- Required external method/object declarations.
- Any necessary private declarations or build changes.
- Any important near/far, macro, or conditional-build constraints.

Then proceed without requesting routine confirmation.

## Make a source-only patch

Preserve implementations as literally as practical.

Do not combine the refactor with functional fixes, algorithm changes, buffer resizing, new validation policies, or changes to known shortcuts.

Do not rename messages, functions, globals, fields, or classes.

Do not introduce new classes, objects, dependencies, geodes, or code resources.

Add concise introductory comments to subsystem files and useful method/helper comments. Explain responsibility and ownership; avoid comments that merely repeat a method name.

Repair broken or mixed indentation in the files being reorganized. Keep those changes limited to formatting and comments.

Preserve every file's existing line-ending style exactly. Do not normalize LF, CRLF, or mixed files. Do not format unrelated files.

## Build-system rules

Do not manually edit Makefile or dependencies.mk. Regenerate them with mkmf and pmake depend in the matching Installed directory.

Normal mkmf object reordering is acceptable when resource names, attributes, dispatch, and build results remain correct. Numeric resource IDs do not have to remain identical unless explicitly required.

Object order can still matter for correctness. Glue's file-local Watcom symbol lookup can fail when an object containing a static helper is not the first contributor to its shared code segment. Resolve this through the minimum necessary source local.mk ordering change, consistently covering OBJS, EOBJS, and GOBJS. Do not remove static or widen visibility as a workaround.

Always try the normal EC and NC build through:

    ~/pcgeos-tools/aihelp.py build <source-or-module-path>

Update existing runnable checks when their source paths change.

Do not run PC/GEOS for testing.

## Validate the result

Verify that:

- Every method still belongs to the original class.
- Class structure and message declarations are unchanged.
- Dispatch resolves to the same handlers with the same handler types.
- All required new objects are linked.
- Moved methods and helpers retain their intended code resources.
- No code resource or resource-handle requirement was accidentally added.
- Calling conventions and exported symbols are preserved.
- Method/helper bodies are unchanged apart from explicitly authorized formatting and comments.
- Existing checks and the normal EC/NC builds pass.
- Relevant conditional paths remain valid.

Compare baseline and final linked symbols/resources by name and attributes. Use bin/printobj on .sym files, geode resource output, OMF inspection, or other reliable build evidence as appropriate.

Do not treat byte-for-byte binary equality as mandatory. Separate compilation can change instruction encoding or alignment padding. Investigate meaningful differences and report code-size changes accurately.

Distinguish new failures from failures already present in the baseline. Do not repair unrelated functional problems during this refactor.

Review git diff --ignore-space-at-eol and confirm that changes are intentional and line endings are preserved.

## Document and finish

Update the appropriate documents in ~/pcgeos-tools/wiki/ with supported, reusable findings. Correct stale source locations and contradictory entries rather than adding competing descriptions.

Record evidence paths, symbols, structures, constants, or relevant tool behavior. Do not record guesses, temporary branch state, or task-specific progress notes.

At the end, report:

- The resulting subsystem organization and files changed.
- What moved and what remains in the primary class file.
- How resource placement and calling conventions were preserved.
- Validation results and any baseline limitations.
- Material compiler/linker findings and generated code-size changes.
- Whether any work remains within the requested scope.

End with a concise, copy/pasteable commit-message-style summary.