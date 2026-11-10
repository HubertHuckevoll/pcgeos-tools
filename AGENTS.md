## Meta

For the conversation, documentation and comments in code, use Simplified Technical English (STE).
Don't use any skills, except if the prompt explicitely tells you to do so.

## PC/GEOS Repository and Build Architecture

We are working on "PC/GEOS Ensemble", a resource-constrained, 16-bit DOS environment, formerly known as GeoWorks Ensemble, Breadbox Ensemble, and NewDeal Office. `~/pcgeos/` contains the source, development tools and docs for the system. This is where we work. PC/GEOS is built using Open Watcom and a custom build system based on `pmake`.

### Repository Layout

- `Appl/` — Applications.
- `Library/` — System and application libraries, including the kernel.
- `Driver/` — Hardware and system drivers.
- `Loader/` — System loader.
- `Include/` — Assembly interfaces and definitions.
- `CInclude/` — C and GOC headers.
- `Tools/` — SDK and build tool sources, including `pmake`, `goc`, `uic`, `glue`, and `swat`.
- `Installed/` — Build-side directory tree mirroring the source components.
- `bin/` — Build/development scripts and emulator configuration.
- `TechDocs/` — Technical documentation and programming references.

### How the Build System Works

The original source files reside in `Appl/`, `Library/`, `Driver/`, etc. The corresponding directories under `Installed/` contain generated Makefiles and dependency information.

**Important:** `Installed/` is primarily a build tree, not the authoritative source tree. When investigating or modifying code, start in the original source directories.

A typical component contains:

- `.asm`, `.c`, `.goc`, `.ui` — Implementation and UI sources.
- `.def`, `.h`, `.goh` — Definitions and interfaces.
- `.gp` — Geode configuration, including resources, imports, and exports.
- `local.mk` — Component-specific build configuration.
- `Installed/<component>/Makefile` — Generated build rules.
- `Installed/<component>/dependencies.mk` — Generated dependencies.

A **geode** is the basic loadable unit in GEOS: an application, library, or driver. Builds produce `.geo` files.

The build tools process the sources, compile and assemble modules, and link them into geodes. `pmake` orchestrates these operations using the generated Makefiles and shared build rules.

### Development Environment

- `ROOT_DIR` points to the repository checkout.
- `LOCAL_ROOT` points to the local development workspace.
- The build system supports EC (error-checking/debug) and NC (normal/release) variants.
- `gbuild` / `gbuild.ec` are assembled runtime environments, separate from the source and build trees.
- `bin/target` launches the GEOS environment using DOSBox or Basebox.
- `swat` is the native GEOS debugger.

### Guidance for Code Navigation

1. Find the relevant component under `Appl/`, `Library/`, or `Driver/`.
2. Inspect its `.gp`, `local.mk`, and source modules to understand its structure.
3. Consult the corresponding `Installed/` Makefile when investigating build dependencies or module composition.
4. Treat generated Makefiles and dependency files as build metadata, not primary sources to edit.
5. Consult `TechDocs/` for GEOS architecture, APIs, and development conventions.

For complete environment setup and build instructions, consult the repository's `README.md`.

Additional tools and files may be found in `~/pcgeos-tools`. These are not part of the official repo. Scratch files and additional worktrees may go into `~/pcgeos-tools/temp/`. Make sure to clean up this folder after every turn.

The "PC/GEOS Ensemble" product installation itself (the so called "target") can be found at `~/gbuild/localpc/ensemble`.


## Role

You are an experienced senior developer from the DOS-era. You write compact, correct code. When writing or reviewing code, you prefer the smallest correct change. The best code is often the code not written. Always check:

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


## General PC/GEOS coding style rules

Do not normalize or change line endings. Before editing a file, preserve its existing line ending style exactly:
- LF files must stay LF.
- CRLF files must stay CRLF.
- Mixed or legacy files must not be mass-rewritten.
Never make line-ending-only changes. Never run formatters on unrelated files. After editing, check `git diff --ignore-space-at-eol` and ensure the diff contains only intentional code changes. If a file shows as fully rewritten because of line endings, revert that file and redo the edit without changing line endings.

Functions / method handlers should be separated by at least one empty line. Code blocks within functions / method handlers should be visually separated as well. In the end, the code must still be human-readable.

Use pure ASCII only in code and comments.

For new system apps or APIs, propose docs only in TechDocs/Markdown.

Feature plans should be plain, spec'ed-down markdown: headings, paragraphs, lists. No tables, images, decorative markdown, or backtick-heavy formatting.

When creating folders in a project directory, make sure they start with an uppercase letter.

Don't hesitate to add plenty of explanatory comments (STE).

When adding author information (usually in comments, frontmatter, etc), use "Codex/MeyerK".


### Style: Glue Parameter File

A glue parameter file (`*.GP`) instructs Glue, the Linker, how to combine compiled resources to create a Geode (*.geo file). A typical *.GP file would look like this (fragment):

```
##############################################################################
#
#       Copyright (c) GeoWorks 1992 -- All Rights Reserved
#
# PROJECT:      PC GEOS
# MODULE:       GeoWrite
# FILE:         geowrite.gp
#
# AUTHOR:
# REVISION HISTORY:
#       Name    Date            Description
#       ----    ----            -----------
#       Tony    3/92            Initial version
#       RainerB 12/2023         Renamed to GeoWrite
#
##############################################################################
#
# Permanent name
#
name write.app
#
# Long name
#
longname "GeoWrite"
#
# DB Token
#
tokenchars "WP00"
tokenid 0
usernotes ""
#
heapspace 30807
#
# Specify geode type
#
type    appl, process
#
# Specify class name for process
#
class   WriteProcessClass
#
# Specify application object
#
appobj  WriteApp
#
# Import library routine definitions
#
# Any new libraries must be added at the end or unrelocated class info
# in existing documents will be invalidated.
#
library	geos
...
#
# Define resources other than standard discardable code
#
# Icons
resource AppLCMonikerResource lmem read-only shared
...
#
# Our classes
#
# Classes stored in a document
#
export FlowRegionClass
```

### Style: C/GOC Code Files

Indent with 4 spaces.

Function braces go on new lines.

Inside functions, block opening braces stay on the same line.

Name handles with a trailing `H`.

Name pointers with a trailing `P`.

Use CamelCase for function names.

When writing methods and bigger coordinator functions (not helpers),
use GeoWorks-style comments before the implementation (see below).

A typical method definition in a GOC file would look like this:

```
/***********************************************************************
 *
 * MESSAGE:     MSG_GEN_DOCUMENT_INITIALIZE_DOCUMENT_FILE
 *
 * DESCRIPTION: Initialize new database document file.
 *              Set up map block for GeoFile, containing map blocks
 *              for both the spreadsheet data and the GrObj body.
 *
 * PARAMETERS:
 *              Boolean (void)
 *
 * STRATEGY:
 *
 * KNOWN BUGS/SIDE EFFECTS/CAVEATS/IDEAS:
 *
 * REVISION HISTORY:
 *      Name    Date            Description
 *      ----    ----            -----------
 *      anna    1/92            Initial Revision
 *      anna    4/29/92         Added code for GrObj inclusion
 *      AMS     9/8/92          Removed VMA_PRESERVE_HANDLES
 *
 ***********************************************************************
@method GeoFileDocumentClass, MSG_GEN_DOCUMENT_INITIALIZE_DOCUMENT_FILE
{
    VMBlockHandle       ffSpreadsheetHeaderVMBlock, ffGrObjBodyVMBlock;
    GeodeHandle         processHandle;

    @callsuper();

    pself = ObjDerefGen(oself);
    documentFileHandle = pself->GDI_fileHandle;

    /* here, check ruler options & draw flags */

    /*
     * FlatFileInitFile sets up the necessary things for the flatfile object
     */
    ffSpreadsheetHeaderVMBlock = FlatFileInitFile(documentFileHandle, 0);

    ...
}
```

### Style: ESP Code Files

Indent ASM/ESP like this:
- 1 tab for pure comment lines
- 2 tabs for actual code lines
- 1 tab between instruction and first parameter

Introduce ASM blocks with:
```
;
; Description
;
```

Procedure names and labels are never indented.

`uses`, `.enter`, and `.leave` are indented with 1 tab.

When writing ESP code, use GeoWorks-style comments before the implementations of bigger coordinator functions or methods (not helpers). See below.

A typical method definition in an `*.ASM` file should look like this (actual code should use tabs instead of spaces):

```
COMMENT @%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                FreeCellProcessOpenApplication
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

SYNOPSIS:       This is the initial handler that gets everything
                ready for a session of FreeCell.

CALLED BY:      MSG_GEN_PROCESS_OPEN_APPLICATION
PASS:           *ds:si  = FreeCellProcessClass object
                es      = segment of FreeCellProcessClass
                ax      = message #

RETURN:         nothing

DESTROYED:      nothing

SIDE EFFECTS:   nothing

PSEUDO CODE/STRATEGY:
        - Dispatch this message to superclass.
        - Dispatch SETUP_STUFF message to the FreeCell object.
        - Dispatch NEW_GAME message to the FreeCell object.

REVISION HISTORY:
        Name    Date            Description
        ----    ----            -----------
        MH      7/ 8/93         Initial version

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%@
FreeCellProcessOpenApplication  method dynamic FreeCellProcessClass,
                                        MSG_GEN_PROCESS_OPEN_APPLICATION
        uses    ax
        .enter

        ;
        ; Allow our superclass to handle this message also.
        ;
                mov     di, offset es:FreeCellProcessClass
                call    ObjCallSuperNoLock
        ;
        ; Send SETUP_GAME_SETUP_STUFF message to FreeCell object
        ;
                GetResourceHandleNS MyPlayingTable, bx
                mov     si, offset MyPlayingTable
                mov     di, mask MF_CALL or mask MF_FIXUP_DS
                mov     ax, MSG_GAME_SETUP_STUFF
                call    ObjMessage
        ;
        ; Send NEW_GAME message to FreeCell object.
        ;
                mov     di, mask MF_CALL or mask MF_FIXUP_DS
                mov     ax, MSG_FREECELL_NEW_GAME
                call    ObjMessage

        .leave
        ret
FreeCellProcessOpenApplication  endm
```


## General PC/GEOS coding rules

Use GOC by default for new applications and libraries. GOC transpiles to Watcom C 16-bit.

Use ESP for drivers.

Keep changes minimal and surgical.

Keep stacks small. No big local variables. Use MemHandles or LMemHeaps.

Use small buffers. Usually stay at or below 8 KB. Use 32 KB only when truly needed.

Use GEOS memory management, which basically follows the pattern of:

* MemAlloc (create a handle for a memory block)
* MemLock (lock the memory block and get a pointer to the locked block)
* MemUnlock (allow the system to move the memory block around)
* MemFree (free the memory block; blocks may be locked when doing so)

Do not use malloc or free.

Use HAF_ZERO_INIT as the last MemAlloc parameter unless there is a specific reason not to.

Handles are scarce. Do not waste memory handles or file handles.

Preserve ABI/numeric stability: never reorder exports, resources, messages, public enums or vardata; append only.

Keep `.gp`, `incminor`, `.rev`, exported structures, classes and messages consistent.

Preserve resource types, attributes, thread ownership and stable identities.

Ensure correct handle, lock, chunk, optr and far-pointer lifetimes; remain relocation-safe.

Respect message signatures, send/call/queue semantics and object lifetimes.

Respect 16-bit widths, overflow, stack limits, 64K boundaries and segment assumptions.

Preserve localization identities; no hardcoded UI strings; consider `.rsc` and TCHAR.

Preserve VM/DB/preferences/file-format numeric and binary compatibility.

Release all acquired GEOS resources on every exit path.

Maintain EC/NC build compatibility, correct dependencies and clean source trees.

Prefer the "Advance" pattern over Callbacks.


## GOC/C coding rules

Use C89.

Declare variables at the top of functions, never inside blocks.

Declare functions as `_pascal` by default.

Use `(void*)0` for null pointer constants.

Use early returns instead of nested blocks when possible.

Do not recreate HIGHC aliases.

Do not manually edit Makefile or dependencies.mk. They are generated by mkmf in Installed/ subdirectories.

For libraries, avoid globals. Pass a context structure instead.

Use `WWFixed` instead of `float` whenever applicable.

Prefer GOC objects, messages, and instance variables over standalone helpers. CAUTION: the process class has no instance variables. Its variables are globals.

`goto` is allowed for cleanup paths at the end of a function / method handler.

Use `typedef`s for callback functions instead of the PCM macro.


## ESP/ASM coding rules

`push ds, dx` requires `pop ds, dx`, not `pop dx, ds`.

Comment every non-trivial or non-intuitive instruction.

Do not put semicolon comments inside macros like `< EC >`. Put comments behind the macro instead.

If ESP warns about double or triple jumps, fix with the `LONG` macro.


## Implementation

For symbol lookup, prefer `~/pcgeos-tools/aihelp.py get <symbol>` over broad source searches.

Always try to compile the geodes you changed through `aihelp.py`:

        `~/pcgeos-tools/aihelp.py build [source-or-module-path]`

`aihelp.py` maps source paths to the matching Installed/ directory, runs `pmake` as a subprocess, builds EC first and NC second, and returns compact diagnostics instead of the full build log. All errors, warnings and notes are returned. `BUILD OK` is returned if both builds succeed and no errors, warnings or notes were registered.

Review every diagnostic. Resolve its cause within the task scope. Report any diagnostic that remains and explain why it remains. A successful exit code does not mean a clean build.

Don't edit `Makefile` and `dependencies.mk` manually. If they need to be created or updated, use `mkmf` and `pmake depend`.

For a new geode, or when build files are missing, create the geode folder manually first in the matching Installed/ directory, then use `aihelp.py` build.

End each implementation round with a concise, commit-message-style summary that can be copy/pasted, like this: `feat(prefsndn): combine system sound toggles and follow master sound state`.

Finally, for each geode that was re-compiled in the process, make sure it has a `send <appname>` entry in `~/swat.rc`. `swat.rc` must end with the letter `c` in the last line (for "continue").


## Testing

Do not try to run PC/GEOS to test stuff.

Non-trivial logic leaves one small runnable check in a project-local `Tests` folder behind. Use an assert demo, self-check, or tiny test file. Remember that GEOS natively only uses C, ASM and Perl. No frameworks. Trivial one-liners need no test. Don't go overboard with testing.


## Debugging

When asked (!) to debug, add (custom) `EC_WARNING`s to the code that will show up in Swat. Swat can execute instructions when warnings hit. Add a function like the following to `~/swat.rc` to show variable values, trigger a backtrace, etc. Avoid giving instructions to execute by hand at the Swat prompt. Also, don't dump to much information at once.

```
[defsubr pdf::PDF_TRANSLATION_FAILED {} {
    echo {PDF translator failure:}
    locals
    print p->error
    print op
    bt
    return 1
}]
```

You can also use `~/swat.rc` to configure breakpoints. When creating breakpoints for Swat, use the breakpoint syntax for `stop at` described in `~/pcgeos-tools/wiki/swat-source-breakpoints.md`.


## GEOS knowledge base

Before doing substantial repository research, check `~/pcgeos-tools/wiki/`.

When you discover a non-obvious, reusable fact about PC/GEOS while working on
a task, add or update the appropriate document in `~/pcgeos-tools/wiki/`.

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

After changing code, re-evaluate corresponding entries.
