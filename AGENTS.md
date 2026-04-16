### Scope
The monorepo in ~/pcgeos/ contains the source code, tools and documentation for the 16-bit PC/GEOS operating environment for DOS from the late 80s, early 90, also known as GeoWorks Ensemble, Breadbox Ensemble, NewDeal Office. The repo also holds most of the applications that were ever written for the system.

### The layout of the repo is:
- Appl/ – GEOS apps (GeoWrite/GeoDraw-style code lives around here)
- Library/ – GEOS libraries (UI, graphics, VM/DB, Kernel aka geos.geo, etc.)
- Driver/ – DOS/video/mouse/printer/etc. drivers
- Include/ - headers for ESP, the PC/GEOS object oriented assembler
- CInclude/ – headers for GOC/C
- Tools/ – source of build/debug tools (pmake, the debugger Swat along with its TCL scripts, build scripts)
- Loader/ – boot/loader bits
- TechDocs/ – the SDK docs (use TechDocs/Markdown first, as it contains the latest version of the docs)
- Installed/ - this folder contains the build artifacts for "Appl", "Library" and "Driver" again. Code is ONLY being built there.
- bin/ – where the tools land once they have been built.

### General GEOS Coding Guidelines:
- By default, for new applications / libraries, generate code in **GOC language**, which transpiles to **Watcom C 16-bit** (using the `goc` tool). Drivers should use **ESP** (the PC/GEOS object oriented assembler).
- Keep stacks small: no big local variables (use MemHandles or LMemHeaps instead).
- Use early returns whenever possible.
- Use small buffers, usually not more than 8 kb, 32 kb at most.
- Memory management must follow the `MemAlloc` (always use `HAF_ZERO_INIT` as the last parameter), `MemLock/MemUnlock`, and `MemFree` pattern (in C/GOC never use "malloc" / "free").
- Try to implement patches in existing code as minimal as possible
- Don't exaggerate on checks and helpers. If a helper would only be used once, avoid it and implement inline.
- Keep in mind that handles are rare, don't waste them. This is also true for file handles, as DOS doesn't wllow too many open files at once.
- never use anything else but pure ASCII characters when creating code and comments
- if creating new system applications or APIs make sure to propose documentation in the markdown version of the TechDocs
- when creating plans for new features, make sure to output them as plain text, don't use markdown features like
backticks, lists, images, etc.

### Coding Behavior and Style rules for GOC/C:
- Generated code must follow the C89 standard: Variables must be declared at the **top of functions** (not blocks!), no new blocks are introduced solely for the purpose of introducing variables mid-function.
- Cast all void pointers like this: `(void*)0`.
- Declare functions as `_pascal` by default.
- Indent with 4 spaces
- Put curly braces always on a new line when creating functions, for blocks inside a function put the opening `{` on the same line and the closing `}` on a new line.
- Handles and pointers are always distinguished and named clearly with a trailing H for Handles and a trailing P for Pointers.
- Don't re-create aliases for the HIGHC compiler, even if you find them in the source code.
- Don't work on `Makefile` and `dependencies.mk` files. These are created by mkmf in the subdirectories of the Installed folder and never in the project folder itself.
- When creating librarys, don't use globals, but a context structure that is passed to functions.
- Use `WWFixed` math instead of `float` whenever applicable.
- Prefer objects / messages / instance variables over plain GOC/C helper functions.
- CAUTION: the process class does not have instance variables, these are globals instead.
- C/GOC: goto's are fine for cleanup jobs at the end of a function only
- Use typedef's for defining callback functions (instead of the PCM macro also found in the source code), like this:
`
...
typedef Boolean _pascal ProgressCallback(word percent);
typedef Boolean _pascal pcfm_ProgressCallback(word percent, void *pf);
...
int _export _pascal ReadCGM(FileHandle srcFile,word settings, ProgressCallback *callback)
{
...
}
...
if(((pcfm_ProgressCallback *)ProcCallFixedOrMovable_pascal)(pct,callback))
{
...
}
`

### Coding Behaviour and Styles rules for ASM (ESP):
- `push ds, dx` in ASM/ESP code requires `pop ds, dx` and not `pop dx, ds`.
- Always indent ASM (ESP) code with 1 tab for pure comment lines and 2 tabs for actual code lines. Put a tab between the asm instruction and the first parameter.
- carefully comment the ESP / ASM code that you create

### How to compile a geode

Always try to compile the geodes we are working on.
Sample: If we have an app called "Bounce" in the Appl folder,
we need to switch to the Installed/Appl/Bounce directory first:
cd ~/pcgeos/Installed/Appl/Bounce

Then run the following commands:
yes | clean
mkmf
pmake depend
pmake -L 4 full
