# PC/GEOS 6

Draft, 16 November 2026.

## User facing highlights

### Basebox: easier installation and everyday use

Basebox provides the host environment for running PC/GEOS on modern operating
systems. It simplifies installation and startup, handles the underlying DOS
environment, and improves compatibility with current hosts. This reduces
setup work and makes the GEOS desktop easier to use alongside current
software, with a more seamless experience from installation to daily use.

PC/GEOS also connects to Basebox host services for networking and TLS,
bringing secure connections through the host environment. Supported Basebox
display modes let the desktop respond when the host window changes size.
Windows, desktop views, and the taskbar follow the available space. These
connections make Basebox an important part of bringing the classic GEOS
system to current computers.

### Image-based distribution and simpler updates

The split-setup design puts the system core in an immutable, read-only image
and keeps documents, personal settings, and other writable data separate.
This gives each release a consistent system foundation while leaving room
for personal use and customization. Users can choose which supplied
applications appear in their desktop folders without changing the image.

Installation and update activation are separate steps. A new system image
can be activated without repeating the initial setup of the user environment.
Layered configuration combines supplied defaults with personal settings,
helping users keep their choices as the distribution changes. This provides
a practical foundation for updates that preserve the personal environment.

Basebox and PC/GEOS are packaged and launched together. Startup coordinates
Basebox launcher updates with activation of the GEOS distribution, bringing
the host environment and the GEOS system into one installation workflow.
Linux and Windows use the same GEOS distribution with the appropriate
Basebox runtime and launcher. This shared layout makes installation, updates,
and everyday use more consistent across platforms.

### TrueType fonts and better documents

TrueType support brings a wider choice of scalable fonts to PC/GEOS, including
bundled Nimbus families and other text and symbol fonts. Improvements to text
placement, kerning, underlines, rotated text, and printing help those fonts
work throughout the system. Better font substitution preserves text attributes
in existing documents, while corrected PostScript output improves exchange
with printing tools. The result benefits both new work and older documents.

### Spelling, suggestions, and help with words

OpenSpellGEOS restores useful writing functions: spelling
checks, suggestions, personal dictionaries, a thesaurus, and hyphenation.
It replaces the incomplete proprietary engine and missing data in the early
source release. English and German dictionary data give the corresponding
product builds a practical foundation for everyday writing.

### A coordinated translation and help effort

Localization is a major part of the product work. German translations reach
across applications, system libraries, drivers, Preferences, desktop folders,
and browser messages. Localized templates and sample content extend that
work into the documents and examples users encounter. Translators also
update wording and help as features change, so users can learn new functions
in their own language.

Revised English and German help, editable help sources, and more consistent
names and instructions support the same goal: a product that is easier to
understand throughout everyday use. This sustained work gives the translated
environment a level of care that extends well beyond individual dialogs.

### A desktop with more control

Motif Redux brings taskbar window switching and configurable taskbar placement
to the classic desktop. A right-click or Shift-F10 opens window commands
directly from a taskbar entry, including Restore, Move, Size, Minimize,
Maximize, and Close. Users can manage a minimized window without first
activating it. Tray launch buttons, a clock with date display and Calendar
access, and an option to place menus in maximized title bars put common
actions within easy reach.

### Easier work with files and folders

Open With lets users choose another application for a file while keeping its
normal association. Its configurable list uses icons and text and supports
application ordering. Folder Edit adds folder properties and icon selection,
and a conversion tool provides access to GEOS 1.x document conversion.
ISDesk adds better selection and duplication, useful keyboard shortcuts,
and visible commands to create and edit DOS launchers. File selectors also
adjust their height to show more files on larger screens.

### System-wide mouse-wheel support

PC/GEOS 6 introduces mouse-wheel support throughout the system, a capability
that Breadbox Ensemble 4 did not have. Native wheel events and driver support
bring convenient scrolling to the desktop and applications. A Preferences
option reverses the wheel direction to match the user's preferred scrolling
style. This makes a familiar mouse control useful across everyday work.

### A more useful WebMagick

WebMagick handles more HTML text and character entities, maps UTF-8 input to
the GEOS character set, and sends UTF-8 form responses. Better paragraph,
list, and table layout improves page presentation. Revised navigation,
font selection, image fitting, and image loading give users more control
over reading. Stop and shutdown handling also release loading resources
more consistently, making interrupted browsing more reliable.

### More ways to exchange graphics

PNG import and export add a useful route for bitmap exchange, including
conversion between transparency and GEOS bitmap masks. SVG import and export
keep supported shapes and paths as vector graphics when exchanged
with other software. Static lossy WebP import adds another image source for
Graphics Viewer and WebMagick. Better JPEG handling and working 24-bit BMP
export extend the choices for moving pictures into and out of PC/GEOS.

### A replacement Icon Editor

The new Icon Editor combines icon-set management with bitmap and mask editing.
Users can import graphics and token-database icons, change size and color
depth, preview results, and generate icon source code. Palette reduction,
dithering, scaling, rotation, and clipping bring the main preparation tools
into one workflow. Icon-set clipboard support makes it easier to reuse the
finished work.

### Useful improvements to document work

GeoWrite and GeoCalc now allow zoom up to 400%, with 300% and 400% menu choices
at the intermediate user level. GeoPoint correctly handles the first save
of an unnamed presentation. Character Map adds magnification, character-code
display, multiple-character selection, and automatic copying. Book Reader
improves page refresh and fitting, and Previous and Next can cross content-file
boundaries in multi-file books. These changes remove small interruptions
from common tasks.

### Polished games for the current product

The games in the current product receive substantial attention, including
interface improvements, Quick Tips, help, localization, and compatibility
repairs for the Open Watcom build. Work on card, puzzle, arcade, and learning
games makes this familiar part of Ensemble easier to use and enjoy.
GeoLadder adds another game, with help, German translation, and sound and
resource-handling fixes. FreeCell is also part of the current selection.

### More comfortable everyday use

A new idle power driver lets the guest processor halt while PC/GEOS has no
work. Refreshed icons, familiar application names, updated backgrounds, and
a more compact Preferences layout make the desktop easier to navigate.

## Technical highlights

### An Open Watcom development system on Linux and Windows

The compiler migration is one of the project's largest technical efforts.
It adapts the target code and connects Open Watcom, GOC, the linker, runtime,
build tools, packaging, and launch scripts into a usable development system
on Linux and Windows. Calling conventions, object records, resource references,
and host paths all needed careful work across tools and applications.
This gives maintenance and new development a common toolchain and provides
the build foundation for the product's other improvements.

### Swat restored as a practical debugging tool

Swat works on Linux and Windows with target communication, launch integration,
source debugging, and local-variable inspection. Better breakpoint and method
resolution, terminal key handling, command editing, source scrolling, and
resizable consoles improve daily use. Reduced idle CPU demand also makes
long debugging sessions less costly on the host. These changes restore a
central tool for understanding a running GEOS system.

### Localization as a repeatable product workflow

Resource Editor and the prodLoc scripts connect translation work to automated
product builds. Batch processing and logs make localization practical across
many applications and system components. This gives the translation effort
a shared workflow that can be repeated as the source changes.

Repairs to resource loading and resource-count handling strengthen that
process, while translation updates preserve the notes that translators need
for continued work. Alongside editable help sources and localized templates,
these tools provide a foundation for maintaining language editions over time.
The achievement combines extensive translation work with the engineering
needed to carry it into the product build and support further language work.

### TrueType adapted to a small, movable-memory system

The font driver brings FreeType-based rendering into the GEOS graphics model,
including glyphs, kerning, simulated styles, transformed text, paths, and
regions. Persistent font-data caching, delayed header work, and revised
render-pool handling reduce repeated processing and pressure on locked memory.
The technical achievement is making scalable fonts fit the resource model
of a 16-bit system while serving existing text and printing interfaces.

### Host services through native GEOS interfaces

HostIf, HstTCPIP, and the HTTP and SSL libraries connect GEOS applications to
Basebox host networking and TLS. Host events also carry display-size changes
into the video driver and UI. This extends the environment through defined
host services while keeping application work within GEOS networking,
graphics, and window interfaces.

### Image formats connected to native graphics and memory

PNG, SVG, and WebP support reaches beyond individual viewers. Libraries,
translators, browser integration, and thumbnail support make the formats
available through shared system paths. SVG bridges external vector data and
GEOS GStrings; PNG connects alpha transparency with bitmap masks; WebP decoding
builds a native bitmap incrementally. Related zlib work adapts storage to GEOS
memory handling. Applications gain reusable format support and image tools.

### Correct interfaces across C, GOC, and assembly

Repairs to structure returns, object pointers, method alignment, resource
references, register preservation, and message declarations strengthen the
boundaries between the languages used by GEOS. Math work repairs arithmetic
helpers and floating-point calling and return conventions, with Watcom
support linked when required. Glue gains more complete CodeView types,
symbols, and source-line information. Together, these changes improve both
execution and the debugger's view of the program.

### Reliability work in shared system code

A replacement compression implementation uses correctly sized, initialized
work buffers. Bitmap color-state queries correctly lock the HugeArray
directory, and VM-chain release prevents file compression until the chain
has been freed. Browser cancellation and shutdown repairs improve resource
lifetimes across image and fetch operations. These focused changes protect
shared paths used by many applications, where a small correction can have
a broad effect.

### Documentation and tools that support continued development

The SDK reference is available as searchable Markdown documentation, with
DDK material and repaired C/GOC examples. Utilities such as mkext automate
GOC extern declarations, while build scripts separate EC and NC targets.
Together, the reference material, working examples, and tools make it easier
to learn the system and maintain its code.
