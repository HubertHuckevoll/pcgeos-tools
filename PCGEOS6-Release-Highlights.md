# PC/GEOS 6

Draft, 16 November 2026.

## User-facing highlights

### Run PC/GEOS with Basebox

Basebox supplies the DOS environment for PC/GEOS on current operating
systems. It simplifies installation and startup and improves host
compatibility. You can spend less time on setup and use the GEOS desktop
alongside your other applications.

PC/GEOS uses Basebox host services for networking and secure connections
through TLS. In supported Basebox display modes, resize the host window
and the GEOS desktop adjusts. Windows, desktop views, and the taskbar
follow the available space.

### Update the system and keep your files

Each release puts the system core in a read-only image. The split setup
keeps documents, personal settings, and other writable data separate.
Choose which supplied applications appear in your desktop folders
without changing the image.

Install a new system image and activate it in a separate step. You can
activate the update without repeating the initial user setup. Configuration
layers combine the supplied defaults with your settings, so you can keep
your choices when the distribution changes.

Install and start Basebox and PC/GEOS from one package. At startup,
the system coordinates Basebox launcher updates with activation of the
GEOS distribution. Linux and Windows use the same GEOS distribution.
Each host uses its own Basebox runtime and launcher.

### Use TrueType fonts in your documents

Choose from scalable fonts across PC/GEOS. The supplied fonts include
Nimbus families and other text and symbol fonts. Updates improve text
placement, kerning, underlines, rotated text, and printing. Font
substitution keeps text attributes in existing documents. Corrected
PostScript output works better with printing tools. These changes help
with new and existing documents.

### Check spelling and find the right word

OpenSpellGEOS checks spelling, suggests corrections, and supports personal
dictionaries, a thesaurus, and hyphenation. It replaces the incomplete
proprietary engine and supplies data that the early source release lacked.
The English and German builds use dictionary data for their languages.

### Use German menus, templates, and help

German translations cover applications, system libraries, drivers,
Preferences, desktop folders, and browser messages. They also cover
templates and sample content. As features change, translators update the
wording and help so users can learn the new functions in German.

Updated English and German help use more consistent names and instructions.
Editable help sources support further updates.

### Switch and manage windows from the taskbar

Switch windows with the Motif Redux taskbar and choose where it appears.
Right-click a taskbar entry or press **Shift+F10** to open its window menu.
The menu includes Restore, Move, Size, Minimize, Maximize, and Close. You
can use it for a minimized window while the window stays minimized.

Start applications from tray buttons. Use the tray clock to see the date
or open Calendar. You can also put menus in the title bars of maximized
windows.

### Open, organize, and convert files

Use **Open With** to choose a different application for a file and keep
its usual association. Set up the list and change the order of its
entries. Each entry has an icon and a label. Use Folder Edit to set
folder properties and choose icons. A separate tool converts GEOS 1.x
documents.

ISDesk improves selection and duplication, adds keyboard shortcuts, and
shows commands to create and edit DOS launchers. File selectors adjust
their height to show more files on larger screens.

### Scroll with the mouse wheel

Use the mouse wheel across the desktop and in applications. PC/GEOS 6
adds native wheel events and driver support for system-wide scrolling.
This support is new since Breadbox Ensemble 4. Reverse the wheel
direction in Preferences.

### Read more pages in WebMagick

WebMagick handles more HTML text and character entities. It maps UTF-8
input to the GEOS character set and sends form responses as UTF-8.
Updates improve paragraph, list, and table layout.

Use updated navigation, choose a font, and fit images to the window.
Image loading also improves. Stop and browser shutdown release loading
resources more reliably when browsing stops.

### Exchange pictures and drawings

Import and export PNG images with transparency. Convert between PNG
transparency and GEOS bitmap masks. Use SVG import and export to keep
supported shapes and paths as vectors when you exchange them with other
software.

Open static lossy WebP images in Graphics Viewer and WebMagick. Updates
improve JPEG handling and enable 24-bit BMP export.

### Build icon sets in the new Icon Editor

Manage icon sets and edit bitmaps and masks in the new Icon Editor. Import
graphics or icons from the token database. Change size and color depth,
preview the result, and generate icon source code.

Reduce palettes, dither colors, scale, rotate, and clip in the same
editor. Copy icon sets through the clipboard to reuse them.

### Zoom, save, and read with fewer interruptions

Zoom to 400% in GeoWrite and GeoCalc. The intermediate user level has
300% and 400% menu choices. GeoPoint handles the first save of an unnamed
presentation.

In Character Map, magnify characters, see their codes, and select several
characters to copy automatically. Book Reader refreshes pages and fits
them to the view more reliably. **Previous** and **Next** can move between
content files in a multi-file book.

### Play GeoLadder and familiar games

Card, puzzle, arcade, and learning games get updated controls, Quick Tips,
help, translations, and Open Watcom compatibility fixes. GeoLadder joins
the selection with help, a German translation, and fixes for sound and
resource handling. FreeCell is also in the current selection.

### Use a desktop with a refreshed look and less idle work

A new power driver halts the guest processor when PC/GEOS has no work.
Refreshed icons, familiar application names, updated backgrounds, and a
more compact Preferences layout make the desktop easier to navigate.

## Technical highlights

### Build with Open Watcom on Linux and Windows

The move to Open Watcom is one of the project's largest technical changes.
It adapts the target code and brings together the compiler, GOC, the linker,
the runtime, build tools, packaging, and launch scripts on Linux and Windows.
The changes cover calling conventions, object records, resource references,
and host paths. A common toolchain supports maintenance, new development,
and the builds for the other product changes.

### Debug GEOS with Swat on Linux and Windows

Swat communicates with the GEOS target and works with the launch scripts
on Linux and Windows. Debug at source level and inspect local variables.
Swat improves breakpoint and method lookup, terminal key handling, command
editing, and source scrolling. You can resize the console. Swat uses less
host CPU time while idle during long debugging sessions.

### Build translated editions with Resource Editor

Resource Editor and the prodLoc scripts integrate translations into
automated product builds. Batch processing and logs let teams repeat the
same translation workflow across applications and system components as
the source changes.

Fixes improve resource loading and resource counts. Translation updates
keep translators' notes. These tools, editable help sources, and localized
templates help teams maintain current language editions and work on
additional translations.

### Render TrueType in 16-bit movable memory

The font driver uses FreeType to render glyphs through the GEOS graphics
system. It handles kerning, simulated styles, transformed text, paths,
and regions.

The driver keeps font data in a cache between runs, delays header
processing, and manages the render pool differently. These changes reduce
repeated processing and the amount of locked memory the driver needs.
Scalable fonts work within the 16-bit memory model and use the existing
text and printing interfaces.

### Use Basebox services through GEOS interfaces

HostIf, HstTCPIP, and the HTTP and SSL libraries connect GEOS applications
to Basebox networking and TLS. Host events also send display size changes
to the video driver and user interface. Applications can use these host
services through GEOS networking, graphics, and window interfaces.

### Reuse image libraries and bitmap tools

Shared libraries, translators, browser integration, and thumbnail support
make PNG, SVG, and WebP available through GEOS. SVG support converts
between external vector data and GEOS GStrings. PNG support converts
between alpha transparency and bitmap masks. The WebP decoder builds a
native bitmap in steps. zlib storage uses GEOS memory management.
Applications can reuse the format support and image tools.

### Pass data correctly between C, GOC, and assembly

Fixes cover structure returns, object pointers, method alignment, resource
references, register preservation, and message declarations. Math fixes
cover arithmetic helpers and floating-point calling conventions and return
values. The build links Watcom support when it is necessary. Glue
supplies more complete CodeView types, symbols, and source-line data.
These changes correct program behavior and give the debugger a more
accurate view of the code.

### Protect common graphics, file, and browser operations

The replacement compression code uses correctly sized work buffers and
initializes them before use. Color-state queries for bitmaps lock the
HugeArray directory. The system frees a VM chain before it permits file
compression. Browser cancellation and shutdown handle resources for image
and fetch operations more reliably. These changes improve shared operations
that many applications use.

### Learn the SDK and automate build tasks

Search the SDK reference in Markdown. It includes driver development kit
(DDK) material and corrected C and GOC examples. The mkext utility
generates GOC extern declarations. Build scripts handle error-checking
(EC) and normal (NC) targets separately.
