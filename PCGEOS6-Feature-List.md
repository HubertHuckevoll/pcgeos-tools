# What's new in PC/GEOS 6

Run the Ensemble desktop on Linux and Windows with Basebox. Write with TrueType fonts and restored spelling tools. Switch windows from the taskbar, scroll with the mouse wheel, and exchange graphics in PNG and SVG. These are some of the changes since the PC/GEOS source became public in November 2018.

## Desktop and applications

### Run PC/GEOS with Basebox

- **Start on Linux or Windows.** Basebox supplies the DOS environment and starts PC/GEOS from the host. This reduces setup work and lets you use Ensemble alongside your other applications.
- **Connect through the host.** A compatible Basebox installation supplies networking and TLS for supported GEOS connections. The product configuration includes a host access point.
- **Resize the desktop with the host window.** Basebox display modes support 72, 96, and 120 DPI. Windows, desktop views, the taskbar, and screen savers adapt when the host reports a change in window size.

### Update the system and keep your files

- **Keep your work in a separate location.** The split setup puts the system in a read-only image. Documents, personal settings, and other writable files stay outside that image. You can choose which supplied applications appear in your desktop folders.
- **Activate a new system image.** Installation and activation are separate steps. You can activate an update without repeating the initial user setup. Configuration layers combine release defaults with your own settings.
- **Use one installation workflow.** The package contains Basebox and PC/GEOS. Startup coordinates Basebox launcher updates with activation of the GEOS distribution. Linux and Windows use the same GEOS distribution with a Basebox runtime and launcher for each host.

### Use TrueType fonts in your documents

- **Choose from more scalable fonts.** Ensemble supplies Nimbus TrueType families and other text and symbol fonts. Updates to the fonts and GEOS font mappings correct missing or misplaced characters. The product retires the old Nimbus outline driver.
- **Get better text placement on screen and in print.** Updates improve character mapping, baselines, kerning, underlines, zoom, rotated and skewed text, subscripts, superscripts, and text converted to paths or regions. The TrueType configuration uses monochrome glyph rendering.
- **Keep text attributes when a font changes.** Font substitution can find the same font from a different manufacturer and keep the text attributes. PostScript export handles mapped fonts and styles more accurately.

### Check spelling and find the right word

- **Use the writing tools again.** OpenSpellGEOS replaces the incomplete proprietary spelling engine and fills the gap left by the missing dictionary files. It checks spelling, suggests corrections, supports personal dictionaries, looks up words in a thesaurus, and adds hyphenation.
- **Use English or German word data.** The source includes US English, British English, and German data. The English product configuration selects US English. The German configuration selects German. The dictionary name also selects the thesaurus and hyphenation files. Updates correct the data paths and configuration. Hyphenation uses exact matches in the supplied data. Word length, suggestion counts, and personal dictionaries have fixed limits.

### Read German menus, templates, and help

- **Work in German across the desktop.** Translation work covers applications, system libraries, drivers, Preferences, desktop folders, and browser error messages. It also covers templates and sample documents.
- **Find updated help in English and German.** Help uses more consistent application names and instructions. Common exit instructions are in one place. Updates cover ISDesk, Preferences, and German GeoWrite help. The former operating-system panel in Preferences is now called **System**. Editable help sources support further updates.

### Switch and manage windows from the taskbar

- **Choose Motif Redux.** Switch applications or windows from the taskbar and choose where it appears. The Express menu and window placement work with the taskbar. The product configuration enables it by default. Other interface choices remain available.
- **Manage a window from its taskbar entry.** Right-click the entry or press **Shift+F10** for Restore, Move, Size, Minimize, Maximize, and Close. The available commands depend on the window state and interface settings. You can open the menu for a minimized window while it stays minimized.
- **Start applications from the tray.** TrayApps creates launch buttons from a designated folder. It updates the buttons when files change and supports tool icons and pop-up help. The Express menu also follows changes to the Desk Accessories folder more reliably.
- **See the date or open Calendar from the clock.** The tray clock displays the date and has a Calendar command.
- **Put menus in maximized title bars.** Enable this option in Preferences. Layout and redraw fixes keep menus and window controls visible and aligned in Motif and ISUI.

### Open, organize, and convert files

- **Choose an application with Open With.** Open a file with a different application and keep its usual association. The product supplies the initial list. You can configure and reorder choices up to a fixed limit. Buttons show an icon and a name. Updates also improve error handling.
- **Set folder properties and icons.** Use Folder Edit to select an icon or clear a custom icon. A separate File Manager tool converts GEOS 1.x documents with the GEOS conversion library.
- **Select and duplicate items in ISDesk.** Use improved Select All and Duplicate commands and keyboard shortcuts. Copy names get a suffix. Hold **Ctrl** when you open a folder to switch temporarily between single-window and multiple-window behavior. Opening a folder again can bring its window forward.
- **Find folders and file details in ISDesk.** Desktop windows adjust to the available space. Standard folders have clearer titles. A folder gets a standard icon if its icon token is missing. GPC builds show the **Attr** column again in Names and Details views. The Sort/View menu appears under the correct conditions.
- **Create and edit DOS launchers in ISDesk.** Builds with DOS launcher support show commands to create and edit launchers and set their icons.
- **See more files in file selectors.** The selector adjusts its height to the screen size. Applications can also use labels that combine an icon with text.

### Scroll with the mouse wheel

- **Use the wheel across the desktop and in applications.** System-wide wheel support is new since Breadbox Ensemble 4. IntelliMouse, CuteMouse, and Basebox-compatible drivers can use native wheel events or simulate key presses. Reverse the wheel direction in Preferences.
- **Use more keys in the updated layouts.** Selected layouts have mappings for the Euro, Windows, and Menu keys. Code page 858 supports the Euro character in environments such as FreeDOS.

### Read more pages in WebMagick

- **Read more HTML text and submit UTF-8 forms.** WebMagick maps UTF-8 text to the GEOS character set in the single-byte build. It handles more named and hexadecimal character entities, newer block elements, templates, and raw-text elements. Changes improve paragraph and list layout, text after line breaks, character conversion, and the handling of oversized forms. The source removes the unused JavaScript engine and related browser variants.
- **Set up the browser for reading.** Reorganized navigation and toolbar controls give you options for page size, bars, and the globe display. You can choose the default font. The initial font is Sans. Downloads of unknown types use one fewer confirmation.
- **Fit pictures to the window.** Choose picture sources, fit images to the available space, and see supported images appear during loading. WebMagick handles inline SVG and more image formats. WebP pictures appear after decoding finishes. You can configure the number of image import workers. The default number of connection workers increases from one to two.
- **Stop a page load more reliably.** Stop and browser shutdown release image and page-fetch resources more consistently. Reference counts stay correct when an operation finishes late. Other fixes cover table reflow after images load, cells that span multiple regions, masked images, local HTML files, large HTTP chunks, HTTP 304 responses, and cookie paths and attributes.
- **Edit HTML with WebBox.** WebBox is the default HTML editor in the updated browser configuration. It has updated controls, translatable information text, more content tags, and simpler handling of HTML frames.

### Exchange pictures and drawings

- **Import and export PNG with transparency.** Open PNG in Graphics Viewer or import and export it in applications that use the system translators. On import, blend transparency against a chosen color or convert it to a GEOS bitmap mask. On export, turn a bitmap mask into a PNG alpha channel. Import supports non-interlaced PNG within scanline and IDAT chunk limits.
- **Keep supported SVG graphics as vectors.** Import and export shapes, paths, transforms, view boxes, and stroke and fill styles through the SVG translator. Graphics Viewer and WebMagick can display supported SVG. The importer skips text, embedded images, `use` references, and `foreignObject` elements. It has a fixed limit for tag storage.
- **Open static lossy WebP images.** Graphics Viewer, WebMagick, and the WebP translator accept static VP8 images with a maximum width and height of 2,048 pixels. Import accepts one image per file and excludes lossless VP8L, alpha, and animation. WebP support is for import only.
- **Open JPEG files more reliably and export 24-bit BMP.** The default image import build includes Fjpeg. The fallback decoder checks JPEG dimensions correctly. Palette displays use the IJG decoder for color reduction and dithering. WebMagick handles the type of local JPEG files correctly, and the BMP translator exports 24-bit color.

### Build icon sets in the new Icon Editor

- **Edit icons for different displays.** The new Icon Editor replaces the previous Icon application. Create icon sets, edit bitmaps and masks, import graphics or icons from the token database, change size and color depth, and preview the result.
- **Prepare and reuse your icons.** Reduce the palette, dither colors, scale, rotate, clip, and edit masks. Copy icon sets through the clipboard or generate icon source code. Help is available in English and German.

### Write, calculate, and read with fewer interruptions

- **Zoom to 400% in GeoWrite and GeoCalc.** The intermediate user level includes 300% and 400% menu choices. GeoCalc also has an updated header layout. GeoWrite restores its toolbar defaults.
- **Save an unnamed GeoPoint presentation.** GeoPoint now handles the first save of a new presentation correctly. The Open Watcom migration also repairs object references, structure returns, and allocation handling in database and spreadsheet code.
- **Find and copy special characters.** Character Map has adjustable character boxes, magnification, character codes, and a choice of startup font. Select multiple characters and copy them automatically at the correct point size. Use it on its own or with **Insert Special Character**.
- **Read across files in Book Reader.** Pages refresh and scale to fit more reliably. **Previous** and **Next** can move into an adjacent content file in a multi-file book. Direct page-number navigation stays in the current file. An adjacent file without numbered pages stops navigation at that boundary.
- **Use the updated GrafCalc.** Ensemble includes the revised application and its help.
- **Catalog your belongings and print recipes.** Ensemble includes Home Inventory Plus and Gourmet with help and German translations. Gourmet supports translation of its messages. Fixes improve clipping and page breaks in printed recipes.

### Play and learn

- **Play GeoLadder and FreeCell.** GeoLadder joins the product with help, a German translation, and fixes for sound and resource handling. FreeCell is part of the current selection.
- **Get Quick Tips and updated controls in familiar games.** Card, puzzle, arcade, and learning games received interface, help, translation, and Open Watcom compatibility updates.
- **Work with more word lists.** Word Matcher accepts files with LF line endings and includes German word data. WMLib and WordList Generator support the updated word-list handling. WordList Generator requires the tools package.
- **Use updated learning tools.** Laser Letters has revised controls, exercise data, translations, and Quick Tips. Crossword Maker also received an update. Both applications and Word Matcher are in the product manifest.

### Use a desktop with a refreshed look and less idle work

- **Find familiar applications by name.** GeoWrite, GeoDraw, and GeoCalc return to their familiar names. Contacts and Calendar have new locations in the application tree.
- **Start with a refreshed look.** Ensemble has a VGA startup screen, updated desktop and Preferences icons, revised background choices, and an updated default color scheme. Preferences uses a more compact layout. The product removes old Breadbox branding.
- **Let the processor pause while Ensemble is idle.** The product configuration selects the HLT power driver. It halts the guest processor when GEOS has no work. The Perf monitor also updates less frequently while the system is idle.
- **Choose from more display sizes.** Video drivers restore and repair higher resolutions and add modes such as 848 × 480, 960 × 540, and 960 × 600. VESA modes depend on the adapter or emulator. The source includes VGA15 and VGA24. TrueColor drawing fixes improve regions and masked pixels. RGB bitmap compression also works more reliably.
- **Set up native network connections more reliably.** PPP setup works in Open Watcom builds. DHCP requests ask for broadcast replies. The packet driver removes a polling thread and preserves registers that Dosemu2 needs. The connection application shows the active access point more clearly and handles PPP separately from other connections.
- **Access folders in DOSBox.** The kernel detects DOSBox and selects the OS/2-style primary file-system driver. DOS file-system code also lists folder names more reliably.
- **Hear corrected sounds.** Updates fix standard interface sounds and FM instrument and drum tables.
- **Clear temporary data with RESET.BAT.** The updated reset tool clears session state, failed print jobs, clipboard data, and browser cache files. A German version is available.
- **Use Back & Forth or TaskMax.** Both drivers return to the build and product manifest. Each requires its external task-switching software.
- **Make and run installation packages.** Ensemble includes Uni Installer and Install Creator. Updated versions fix INI entry editing and reduce dependence on newer runtime features. GEOS 2.0 is a compatibility target.

## Development tools and system code

### Build with Open Watcom on Linux and Windows

- **Use the same compiler toolchain on both hosts.** Open Watcom support covers the GEOS target code, GOC-generated C, linker object records, calling conventions, resource references, the C runtime, and host-specific paths. The tools, SDK packaging, target packaging, and launch scripts work on Linux and Windows.

### Debug GEOS with Swat on Linux and Windows

- **Launch and inspect a running target.** Swat communicates with the target and works with the launch scripts. Step through source code, inspect local variables, and use improved breakpoint and method lookup.
- **Work in a resizable console.** Swat improves focus handling, terminal key decoding, command editing, and source scrolling. It also reduces CPU use while idle. On Linux, terminal text selection can require **Shift** while Swat uses mouse reporting.

### Build translated editions with Resource Editor

- **Run repeatable translation builds.** Resource Editor and the `prodLoc` scripts process resources in batches, produce logs, and integrate translations into product builds. Updates fix resource loading crashes and resource counts. They also keep translators' notes when translations change.
- **Maintain editable resources and help.** Localized templates and editable help sources support further language work. Resource Editor is conditional on the tools package. Its German translation is in the unreleased source area.

### Render TrueType in 16-bit movable memory

- **Use FreeType through existing GEOS graphics and print interfaces.** The driver registers font families and styles, renders glyphs, handles kerning and simulated styles, and supplies paths and regions for transformed text and printing.
- **Reduce repeated work and locked memory.** The driver caches font data between runs, delays font header processing, and uses faster kerning conversion and arithmetic. Changes to the render pool, temporary data, and code reduce overhead. The existing fractional advance-width rounding stays in use for stable document layout.

### Use Basebox services through GEOS interfaces

- **Connect through existing networking interfaces.** HostIf and HstTCPIP connect GEOS to Basebox networking. The HTTP and SSL libraries use host services. The default SSL build uses the smaller host-service-only variant. Updates refine the host API, events, and connection handling.
- **Receive display size changes through HostIf.** Host events supply the size to the VGA16 driver and GEOS window system. Dynamic resizing requires a compatible Basebox host service and display mode.

### Reuse image libraries and bitmap tools

- **Use the shared graphics interfaces.** GEOS exposes PNG decoding and encoding, SVG conversion to and from GStrings, and WebP decoding into a native bitmap. The decoder builds the bitmap incrementally. System translators connect the libraries to applications. The browser and thumbnail database also use shared image handling, including vector thumbnails.
- **Reuse image and icon operations.** Public interfaces cover bitmap transformations, palettes, image and icon controls, and the icon-set clipboard format. zlib storage uses GEOS memory management. The ASCII text translator source is available again. Use the current headers and geode export lists for these interfaces.

### Pass data correctly between C, GOC, and assembly

- **Use corrected object, resource, and message interfaces.** Fixes cover structure returns, `ConstructOptr`, object-method alignment, resource and chunk references, register preservation in C wrappers, token-loading failure results, and graphics and message parameters. Some corrected declarations can require source changes when you rebuild older code.
- **Keep GEOS and C floating-point types distinct.** Fixes cover 32-bit arithmetic helpers, GEOS `FloatNum`, calling conventions, `double` return values, missing math functions, and segment initialization. Glue links Watcom floating-point support when the code requires it.
- **See more program information in the debugger.** Glue supplies more complete CodeView data for unions, type definitions, local symbols, case-sensitive lookup, and source lines.

### Protect common graphics, file, and browser operations

- **Use correctly sized compression buffers.** The replacement compression code initializes its work buffers to zero.
- **Lock the bitmap directory during color queries.** The kernel locks the bitmap's HugeArray directory before it queries the driver.
- **Free virtual memory chains before file compression.** `VMFreeVMChain` prevents compression until it frees the chain.
- **Release browser resources after cancellation.** Stop and shutdown fixes cover image and fetch operations, including operations that finish after cancellation.

### Learn the SDK and automate build tasks

- **Search the developer reference.** The SDK reference is available as searchable Markdown documentation. It includes DDK material and new or repaired C and GOC examples.
- **Use updated development utilities.** `cvtpcx` and `geodump` support SDK work. `mkext` generates GOC extern declarations. Build scripts handle error-checking (EC) and normal (NC) targets separately and work with current Perl distributions.

## More work in the source tree

These changes are in the source tree. Availability in the final distribution is open.

- **Gopher client and server.** GClient, GServer, and the Gopher and Navigate libraries were added and adapted to the revised host interface. A package needs a compatible host setup.
- **HPGL and CGM import.** VConvert, Meta, and the VCImpex filter add source and build support for these vector formats. Distribution as an application, translator, or SDK component is open.
- **Note Taker and Pen Support.** An assembly implementation replaces Note Taker. Later changes fix the application and pen library and let Note Taker save its options. Compatibility with older documents and pen input needs confirmation.
- **PicAlbum and PhotoPC.** Both build again. The standard product manifest omits PicAlbum and has a disabled PhotoPC entry.
- **Dose and Startbar.** The Dose source is available again. An early Startbar draft compiles.
- **Additional games.** Hangman source can use German word lists. The product manifest has disabled entries for Taipei, Columns II, Follow Me, Maze Runner, Mine Field, Treasure Hunt, GeoFrotz, GeoNoid, Paddle, Spider, and several entertainment-pack games.

## About this list

- The repository review starts with the source publication on 17 November 2018. It covers upstream `master` through 15 November 2026, including merged branches. It uses Breadbox Ensemble 4.13 as the provisional baseline. The Basebox packaging and split-setup items come from the release highlights and extend beyond that repository review. [Reviewed revision](https://github.com/bluewaysw/pcgeos/commit/01c7a0172688aa72cc29898eb832dd5915d49cf7)
- The standard product manifest identifies source integration. Availability depends on the final package, language, host, and build configuration. For example, the manifest removes BIM instant messaging and includes FreeCell again after an earlier exclusion. The source review used no runtime tests. [Product manifest at the reviewed revision](https://github.com/bluewaysw/pcgeos/blob/01c7a0172688aa72cc29898eb832dd5915d49cf7/Tools/build/product/bbxensem/bbxensem.filetree)
- The review screens 3,609 commits and groups the changes into 52 release topics. Five of those topics cover optional components or work in the source tree. The release changes record the commit evidence, detailed review scope, and open release checks. The release highlights describe the packaging workflow and set the order for this list. [Release changes](PCGEOS6-Release-Changes.md), [Release highlights](PCGEOS6-Release-Highlights.md)
