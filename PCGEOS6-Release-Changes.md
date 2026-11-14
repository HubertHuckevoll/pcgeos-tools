# PC/GEOS 6: Important Changes for Release Review

Working draft, 14 November 2026. Author: Codex/MeyerK.

## Review scope and use

This document covers all 3,602 commits reachable from local master at
[beb7e2c77](https://github.com/bluewaysw/pcgeos/commit/beb7e2c770262a3f20ba5a889801cce32ac23379), dated 12 November 2026. The history starts with the source
publication on 17 November 2018. It includes commits on merged branches,
not just the first-parent history. Unmerged branches and other repositories
are outside this review. No fetch was done.

The provisional baseline is the source used for Breadbox Ensemble 4.13,
as stated in [README.md](../pcgeos/README.md). The initial import and repository moves are not
new product features. No numbered release tag identifies which intermediate
changes users already received. Thus, this is a catalog of important changes
in the repository history, not yet a verified comparison with a previous
shipped product.

Every commit was screened by its subject, message, and changed component
paths. Selected and unclear changes received patch and current-source checks.
Merge changes were checked for paths changed against all parents; 56 of the
802 merge commits have such paths. Related development steps are combined
into release topics. Commit links provide representative evidence, including
later corrections and removals. Patch inspection was targeted; this was not
a line-by-line code audit of every patch.

The normal product manifest is [Tools/build/product/bbxensem/bbxensem.filetree](../pcgeos/Tools/build/product/bbxensem/bbxensem.filetree).
A listed component has source-level product integration. This does not prove
that a particular installer contains it or that it passes runtime tests.
Conditional tools and components absent from that manifest are identified
below. No geodes were built and PC/GEOS was not run for this review.

### Selection rules

Keep a change when it adds a useful capability, removes a substantial user
problem, improves compatibility, reduces a material resource cost, or makes
development practical. Small patches can qualify when they prevent crashes,
memory corruption, or incorrect output.

Combine repeated work on the same result. Do not publish routine build
repairs, generated dependencies, formatting, individual translation corrections,
version-number changes, or development experiments as separate release points.
Keep important SDK and API changes in the developer section.

The topic identifiers are stable labels for refinement. H means a proposed
headline. I means an important supporting point. O means an optional or
source-only candidate. Priority is an editorial proposal, not a test result.

## Proposed release highlights

- TrueType fonts throughout the system, with bundled replacement fonts,
  improved text layout and printing, and extensive resource work. F01-F03.
- OpenSpellGEOS replaces the missing proprietary linguistic engine and data
  with spelling, suggestions, a thesaurus, and hyphenation. F04.
- A more useful desktop: Motif Redux, a taskbar, tray launchers, Open With,
  folder tools, and DOS launcher editing. D01-D06.
- Host networking and host TLS through Basebox, plus desktop resizing in
  Basebox display modes. N01 and S01.
- Improved WebMagick page handling, UTF-8 forms, image loading, and Stop
  behavior, within the browser's documented limits. N02-N05.
- PNG import/export, SVG vector exchange, and limited static WebP support.
  G01-G03.
- A replacement Icon Editor with bitmap editing, icon sets, palette tools,
  and source-code generation. A01.
- A usable Open Watcom development system on Linux and Windows, with an
  improved Swat debugger and expanded documentation. T01-T07.

## Fonts, text, and language services

### F01. TrueType font support - H

A FreeType-based driver was added and integrated into the product. It registers
font families and styles, renders glyphs, handles kerning and simulated styles,
and supplies paths and regions for transformed text and printing. This is one
system-wide capability, not hundreds of separate font-driver changes.

Evidence: [3c43c5521](https://github.com/bluewaysw/pcgeos/commit/3c43c5521a57efa2525f1722044f00c3f19ab771), [8bea24d1f](https://github.com/bluewaysw/pcgeos/commit/8bea24d1f2875d7af435a70b02fa98fd50baf9a2), [9c74f4aed](https://github.com/bluewaysw/pcgeos/commit/9c74f4aed2388cd9a59eb00e41c3794d6e02c4a8), [64c85e145](https://github.com/bluewaysw/pcgeos/commit/64c85e14563dce395283fe828372201352aec084).
Current source: [Driver/Font/TrueType](../pcgeos/Driver/Font/TrueType).

Limit: this is a GEOS adaptation of TrueType support. Do not claim support for
all OpenType features, font collections, arbitrary Unicode text, or font
smoothing. The current configuration disables grayscale font rendering.

### F02. Better font layout, printing, and document substitution - H

Later work corrects baselines, underlines, character mapping, document zoom,
rotated text, subscript/superscript, skew, and text converted to paths or regions.
Font substitution preserves text attributes and can match the same font from
a different manufacturer. PostScript export handles mapped fonts and styles
more correctly. These changes matter to existing documents as well as new
TrueType documents.

Evidence: [7088909a2](https://github.com/bluewaysw/pcgeos/commit/7088909a273b6daabb323f8dc5be8dbc7535bbfc), [b84769dc5](https://github.com/bluewaysw/pcgeos/commit/b84769dc5d99d7fab76d14a99d5e8e95fa1e8330), [dd95ec438](https://github.com/bluewaysw/pcgeos/commit/dd95ec438c85a46a7c84cabaf4335ccebfa4b685), [d7513579e](https://github.com/bluewaysw/pcgeos/commit/d7513579ef98686c9a3b55abec6726b2172b6107),
[8679e8ed9](https://github.com/bluewaysw/pcgeos/commit/8679e8ed99abdf645d57fecf67fcb9d31d5cb581), [3cafaacbe](https://github.com/bluewaysw/pcgeos/commit/3cafaacbe2b7ab9944214d5890b55463ba3f5eaa), [394733271](https://github.com/bluewaysw/pcgeos/commit/3947332719a9902302d17281460eecb8ed16f8c0).
Current source: [Library/Kernel/Graphics](../pcgeos/Library/Kernel/Graphics), [Driver/Font/TrueType/Adapter](../pcgeos/Driver/Font/TrueType/Adapter),
and [Library/Trans/Graphics/Vector/EPS/Export/exportText.asm](../pcgeos/Library/Trans/Graphics/Vector/EPS/Export/exportText.asm).

Limit: a proposed change to fractional advance-width rounding was reverted
by [a9e3c7c95](https://github.com/bluewaysw/pcgeos/commit/a9e3c7c95e8c72c297c68cdf320e32e93f3f32aa) to preserve stable GEOS layout. Do not present that experiment
as a release improvement.

### F03. Bundled fonts and lower font-processing resource costs - H

The product gains a collection of TrueType fonts, GEOS font mappings, and font
corrections for missing or misplaced characters. The collection includes
Nimbus families and other text and symbol fonts. The driver gained persistent
font-data caching, delayed header work, faster kerning conversion and arithmetic,
and extensive reductions in locked memory, temporary data, and code overhead.
Later work changes the cache and render-pool design again.

Evidence: [316d28073](https://github.com/bluewaysw/pcgeos/commit/316d28073fa15bd07d5d445034427c82fe4c4fe6), [175b9a471](https://github.com/bluewaysw/pcgeos/commit/175b9a471ad8a7682e5aaeb6e1e2019fc6fd5d57), [1e54b0b60](https://github.com/bluewaysw/pcgeos/commit/1e54b0b60f1e558b178644c12559057dc0375894), [8c32f10f9](https://github.com/bluewaysw/pcgeos/commit/8c32f10f9ad3f4af2d53835d92037f6b8eceeb0c),
[86976557d](https://github.com/bluewaysw/pcgeos/commit/86976557da41fd207c61dda7e1a3e23eecac7eee), [80f5c919c](https://github.com/bluewaysw/pcgeos/commit/80f5c919c553a4ff88701c42f46dd0210e65aec4), [e6ef6b9ba](https://github.com/bluewaysw/pcgeos/commit/e6ef6b9ba7052778052f46e12f2ca9996246a7e5), [114b537b4](https://github.com/bluewaysw/pcgeos/commit/114b537b4d523e40acb5d5fdaf50b315f0b44838).
Current source: [FontData/Ttf](../pcgeos/FontData/Ttf), [Driver/Font/TrueType](../pcgeos/Driver/Font/TrueType).

Limit: use the final manifest and font license files to select the published
font list. The old Nimbus outline driver was removed from the product by
[ceafa23df](https://github.com/bluewaysw/pcgeos/commit/ceafa23df94f33e2678cb1b8634f7d1683ce8904); Nimbus TrueType fonts remain. Do not quote speed, memory-saving,
or startup-time figures without measurements of the final build.

### F04. OpenSpellGEOS linguistic services - H

OpenSpellGEOS supplies a replacement implementation for spelling checks,
suggestions, personal dictionaries, thesaurus lookup, and hyphenation through
the existing Spell library entry points. English US, English GB, and German
data were added; the product configuration selects US English or German for
the corresponding language build. Later commits repair the data paths and
configuration.

Evidence: [ff05a66a0](https://github.com/bluewaysw/pcgeos/commit/ff05a66a05f2234bb6509a2a2e16e72c2824fbf7), [349c22af7](https://github.com/bluewaysw/pcgeos/commit/349c22af74140f8eb13dbf8b7dfd5e381cbf3063), [3531f7d46](https://github.com/bluewaysw/pcgeos/commit/3531f7d469fa2ee4c7d68597f63392aef7e8cff2), [4eb86639e](https://github.com/bluewaysw/pcgeos/commit/4eb86639e64ef7afbf3438606fd89cbd39935195),
[2c3815881](https://github.com/bluewaysw/pcgeos/commit/2c3815881184857b5e9da0aed25150e7b35384dc), [daf7c09a3](https://github.com/bluewaysw/pcgeos/commit/daf7c09a3f749a357e079bd1f01b29597d79ca76).
Current source: [Library/Spell/Open](../pcgeos/Library/Spell/Open),
[Tools/build/product/bbxensem/Userdata/dicts](../pcgeos/Tools/build/product/bbxensem/Userdata/dicts),
and [Tools/build/product/bbxensem/Template/geos.ini](../pcgeos/Tools/build/product/bbxensem/Template/geos.ini).

Why it matters: the early repository contained an incomplete spelling engine,
and dictionary files were later withheld to prevent crashes
([59a9007ae](https://github.com/bluewaysw/pcgeos/commit/59a9007aedabc61041d9554254944011b658803f)). The new work replaces that gap. The selected dictionary stem
also selects the associated thesaurus and hyphenation files.

Limit: the implementation has explicit word, suggestion, and personal-dictionary
limits. Hyphenation uses the supplied exact-word data. Confirm language coverage,
dictionary selection, and compatibility with existing personal dictionaries
before writing final user instructions. Do not describe this as unrestricted
Hunspell compatibility or a complete linguistic service for every language.

## Desktop and everyday use

### D01. Motif Redux and configurable taskbar behavior - H

Motif gains a taskbar-based interface choice exposed as Motif Redux. It includes
application/window switching, taskbar position options, and related Express
menu and window-placement changes. The existing UI choices remain available.
The current product template enables the taskbar.

Evidence: [46693bf56](https://github.com/bluewaysw/pcgeos/commit/46693bf56c6a63964cf4bf15bc77cd5131dbd0e9), [f10ce6e4e](https://github.com/bluewaysw/pcgeos/commit/f10ce6e4e5edb3e898e8a30d82b04ffbcfbd37a4), [543fdcd3f](https://github.com/bluewaysw/pcgeos/commit/543fdcd3fd9b5d8233d21334a0e3c770bcc820d5).
Current source: [Library/SpecUI/CommonUI](../pcgeos/Library/SpecUI/CommonUI), [Library/Pref/ConfigUI](../pcgeos/Library/Pref/ConfigUI),
[Tools/build/product/bbxensem/Template/geos.ini](../pcgeos/Tools/build/product/bbxensem/Template/geos.ini).

Limit: describe the final UI as Motif Redux. Motif 95 was a development name.
Do not infer that other UI variants on unmerged branches are part of this
release.

### D02. Tray application launchers and improved clock - I

TrayApps adds launch buttons for applications from a designated folder, with
file-change updates, tool-icon handling, and bubble help. The tray clock gains
a date display and a Calendar launch command. Later Express menu work follows
changes to the Desk Accessories folder more reliably.

Evidence: [d76415fa2](https://github.com/bluewaysw/pcgeos/commit/d76415fa2cebdfaace8b14864880def35041129d), [ba6999b03](https://github.com/bluewaysw/pcgeos/commit/ba6999b03aed80b2c9f45aa986fa8edb5e69e35c), [528498d3b](https://github.com/bluewaysw/pcgeos/commit/528498d3bdfba6c22f42f692ba90ac115172fe34), [32f8df27c](https://github.com/bluewaysw/pcgeos/commit/32f8df27cdc168b1d52ca416b9dcb2f3cff8196c),
[8a6f4d722](https://github.com/bluewaysw/pcgeos/commit/8a6f4d722609debce199d0133b409456e1d4ffa1).
Current source: [Appl/SysTray](../pcgeos/Appl/SysTray), [Library/User/UI/uiExpress.asm](../pcgeos/Library/User/UI/uiExpress.asm).
Both tray components are listed in the product manifest. Do not include the
experimental TrayApps minimizer that was removed during development.

### D03. Open With and a configurable application list - H

A File Manager tool lets users open a selected file with another application.
Later work adds a configurable application list, icon-and-text buttons,
application ordering, and improved error handling. The product template
supplies initial choices.

Evidence: [b32e16e79](https://github.com/bluewaysw/pcgeos/commit/b32e16e7909cade684c8681360578419b9e491b3), [e9c6101be](https://github.com/bluewaysw/pcgeos/commit/e9c6101be9bfdb472c4b1f03712f885fd4262aa8), [69946ff00](https://github.com/bluewaysw/pcgeos/commit/69946ff0091bdd79a8b6e06a88af2d61a325d0b0).
Current source: [Library/FMTools/OpenWith](../pcgeos/Library/FMTools/OpenWith).

Why it matters: users can choose a program without changing the file's normal
association. The implementation has a fixed maximum number of configured
triggers; do not describe the list as unlimited.

### D04. Folder Edit and old-document conversion tools - I

Folder Edit adds a File Manager tool for folder properties and icons, including
clearing or selecting a token. A separate tool exposes conversion of GEOS 1.x
documents, with the conversion library included in the build.

Evidence: [a3ebdac72](https://github.com/bluewaysw/pcgeos/commit/a3ebdac72612670b7d8a69a5789b4ef7532672e3), [fd70c3bd8](https://github.com/bluewaysw/pcgeos/commit/fd70c3bd82df5c1952793e0f8364e7a5565c2cb5), [f41da727a](https://github.com/bluewaysw/pcgeos/commit/f41da727a77b7e67a9973689bb57554b2edb7873),
[1ad1591a4](https://github.com/bluewaysw/pcgeos/commit/1ad1591a4fce4a108555e1c912ab578916dad584), [2f4060285](https://github.com/bluewaysw/pcgeos/commit/2f4060285ef9dc5a44984ba407d236cd73c3d2ee).
Current source: [Library/FMTools/FolderEd](../pcgeos/Library/FMTools/FolderEd), [Library/FMTools/CvtTool](../pcgeos/Library/FMTools/CvtTool),
[Library/Convert](../pcgeos/Library/Convert). All are listed in the product manifest.

Limit: conversion is a capability with an old-file compatibility boundary.
Confirm representative old documents before claiming complete conversion.

### D05. More useful ISDesk folder and selection behavior - I

ISDesk gains improved Select All and Duplicate commands, keyboard shortcuts,
and copy names with a suffix. Holding Ctrl while opening a folder temporarily
changes the single-window/multiple-window behavior. Opening a folder that is
already open can bring its window forward. Desktop windows follow available
space more closely, and standard folders receive friendly titles. Missing
folder tokens now fall back to a folder icon.

Evidence: [9c91d1024](https://github.com/bluewaysw/pcgeos/commit/9c91d10243090a34652612d04cf30d1aaefd3f70), [3da48011b](https://github.com/bluewaysw/pcgeos/commit/3da48011b175066b31ebb4b0c361566e1ab26f5a), [c820b09c7](https://github.com/bluewaysw/pcgeos/commit/c820b09c718e8298e9df744520abb8af0881202f),
[9202f41c5](https://github.com/bluewaysw/pcgeos/commit/9202f41c55f2e75bf6a763c96929f33252ef5b21), [ae0ef3dae](https://github.com/bluewaysw/pcgeos/commit/ae0ef3dae90c5e2fa321b5626cde49e35c4aa1e2), [537f0436e](https://github.com/bluewaysw/pcgeos/commit/537f0436eb7b4592f5117fbfa17dfe1ccfaae41f).
Current source: [Appl/FileMgrs2/CommonDesktop](../pcgeos/Appl/FileMgrs2/CommonDesktop).

Limit: keep the ISDesk-specific behavior distinct from GeoManager behavior
when preparing help text.

### D06. Create and edit DOS launchers in ISDesk - I

ISDesk exposes commands to create and edit DOS application launchers, including
launcher icon handling. This brings an existing DOS integration mechanism into
the desktop's visible workflow.

Evidence: [4dc17fe43](https://github.com/bluewaysw/pcgeos/commit/4dc17fe43da772c97c08e42e2b8ed761ddbd59ed).
Current source: [Appl/FileMgrs2/CommonIS](../pcgeos/Appl/FileMgrs2/CommonIS),
[Appl/FileMgrs2/ISDesk/isdesk.gp](../pcgeos/Appl/FileMgrs2/ISDesk/isdesk.gp). The code is conditional on DOS launcher
support. Confirm that the release build uses that configuration.

### D07. File selectors show more useful content - I

The file-selector height was revised so the number of visible files can follow
the screen size. A separate repair makes combined icon-and-text monikers usable
by callers.

Evidence: [91ed9d8f1](https://github.com/bluewaysw/pcgeos/commit/91ed9d8f14b31b0da61043b3df7f59c95468ba5a), [8aa7423b5](https://github.com/bluewaysw/pcgeos/commit/8aa7423b599c601a2be453927e76a154d0363107).
Current source: [Library/SpecUI/CommonUI/CUtils/copenFileSelectorHigh.asm](../pcgeos/Library/SpecUI/CommonUI/CUtils/copenFileSelectorHigh.asm),
[Library/User/User/userC.asm](../pcgeos/Library/User/User/userC.asm).

Limit: the history contains a larger experimental file-selector design that
was reduced before merge. Publish the adaptive height and moniker fix; do not
claim the whole experimental design shipped.

### D08. A consistent product appearance and startup - I

The main applications return to the GeoWrite, GeoDraw, and GeoCalc names.
Contacts and Calendar are reorganized in the application tree. The VGA loader
gains a product splash screen. Preferences gain updated icons and a compact
layout; desktop icons, background choices, and the default color scheme also
receive updates. Later work removes old Breadbox branding.

Evidence: [0b01fa850](https://github.com/bluewaysw/pcgeos/commit/0b01fa8502a2820ad3100db530de76bfb60e6d5e), [a860cb4ff](https://github.com/bluewaysw/pcgeos/commit/a860cb4ffba185f04012356970e3e4a723a215aa), [647afbbf0](https://github.com/bluewaysw/pcgeos/commit/647afbbf01e11099b0d47a8af2fcf1129d9aad2e),
[5857adadf](https://github.com/bluewaysw/pcgeos/commit/5857adadf71ae498337047a32ebc02c002d95af2), [71e0ed923](https://github.com/bluewaysw/pcgeos/commit/71e0ed9236df236dd94f1f501e323db1b9187c3a), [da7b81f53](https://github.com/bluewaysw/pcgeos/commit/da7b81f534355f05a84ab5cf3a144d51bdf04fc1), [e2915eb13](https://github.com/bluewaysw/pcgeos/commit/e2915eb13fe8503be132cd8d8ec8d4684f2d7614),
[07547a0b7](https://github.com/bluewaysw/pcgeos/commit/07547a0b7aa613639edbfd13e3165f2159310034), [8f0ca5d8f](https://github.com/bluewaysw/pcgeos/commit/8f0ca5d8f1cdd57d60438f813203eabb0a8cff55).
Current source: [Loader/VGA](../pcgeos/Loader/VGA), [Library/Pref](../pcgeos/Library/Pref),
[Tools/build/product/bbxensem](../pcgeos/Tools/build/product/bbxensem).

Why it matters: this is one product-presentation point. Individual icon fixes,
renames, and copyright-dialog removals should not fill the main change list.

## Internet and WebMagick

### N01. Host networking and TLS through Basebox - H

HostIf and the HstTCPIP driver connect GEOS networking to host services.
The HTTP and SSL libraries gain host-service integration, and a host access
point is added to the product configuration. Later work revises host events,
connection handling, and the host API. The normal SSL configuration uses the
small host-service-only variant.

Evidence: [c19c1763e](https://github.com/bluewaysw/pcgeos/commit/c19c1763e5e9d5a8791bd51b8d81419eb7c3186c), [d7c28217e](https://github.com/bluewaysw/pcgeos/commit/d7c28217e53d45980c5f9b459d497e4e06ee6345), [6b5224ea6](https://github.com/bluewaysw/pcgeos/commit/6b5224ea6d6dbb358fd12f1c200cabdae9934a05),
[7e494c936](https://github.com/bluewaysw/pcgeos/commit/7e494c936c86b6fc5dc2f5986383de6fb180b298), [9b88ec05f](https://github.com/bluewaysw/pcgeos/commit/9b88ec05f2abb09f347e0283da1b713f6b5580d0), [a0abf8ab8](https://github.com/bluewaysw/pcgeos/commit/a0abf8ab8361d0c9b0ccf56f82dd5c3c7b9ff7c9).
Current source: [Library/HostIf](../pcgeos/Library/HostIf), [Driver/Socket/HstTCPIP](../pcgeos/Driver/Socket/HstTCPIP),
[Library/SSL/local.mk](../pcgeos/Library/SSL/local.mk), [Library/Breadbox/UrlDrv/Wmg3Http](../pcgeos/Library/Breadbox/UrlDrv/Wmg3Http).

Why it matters: supported Basebox installations can use host networking and
TLS without depending on the old guest SSL implementation for that path.

Limit: this requires a compatible Basebox host implementation. The repository
alone does not establish its minimum version, supported TLS versions,
certificate-validation policy, or supported sites. Confirm those in the final
host package. Do not market host TLS as a general upgrade to the old native
SSL stack on plain DOS.

### N02. More compatible HTML text, UTF-8, and forms - H

The HTML parser gains UTF-8 decoding in the single-byte build, hexadecimal
character entities, additional entity names, better handling of template and
raw-text elements, newer block elements, and improved list and paragraph
formatting. Form responses gain UTF-8 encoding. Follow-up work fixes characters
after line breaks, GEOS character conversion, and oversized-form handling.

Evidence: [d16ed8ae5](https://github.com/bluewaysw/pcgeos/commit/d16ed8ae537a5b8e6ac94131e8e6c6ffbc81a363), [2341ac79e](https://github.com/bluewaysw/pcgeos/commit/2341ac79e03c6ba655496f9e830b353bed1e3f77), [e19c1d037](https://github.com/bluewaysw/pcgeos/commit/e19c1d037f200851c721448f41b24c8aa6e4f132),
[28c418d2e](https://github.com/bluewaysw/pcgeos/commit/28c418d2e8ac94effa44a52ff9d7b565383f64c4), [4fd647926](https://github.com/bluewaysw/pcgeos/commit/4fd647926e43e435a45494a33cb3901cdb6234d1), [8ae1149df](https://github.com/bluewaysw/pcgeos/commit/8ae1149df90e03a3ffb0d7aeb49eabb009e0fa08), [a110d5277](https://github.com/bluewaysw/pcgeos/commit/a110d5277a5953018c2935a887974cf68dcd89ef),
[83989e4b5](https://github.com/bluewaysw/pcgeos/commit/83989e4b59126ac2ae44cb755c1c55bbd176d45d), [ab0179722](https://github.com/bluewaysw/pcgeos/commit/ab0179722da3547de6bfc7335e32cce7c96ef08b), [ca8a21e79](https://github.com/bluewaysw/pcgeos/commit/ca8a21e79b3422c38cf99301e0f0ea3d9d6e57d7).
Current source: [Library/Breadbox/Html4Par](../pcgeos/Library/Breadbox/Html4Par).

Limit: UTF-8 input is mapped to the available GEOS character set. This is not
a Unicode conversion of the whole operating system, a complete HTML5 browser,
or general support for current web applications.

### N03. Revised browser controls and defaults - I

WebMagick gains reorganized toolbar and navigation controls, configurable bars
and globe display, page-size controls, and revised defaults. A later change
adds default-font selection and makes Sans the default browser font. An extra
save confirmation for unknown downloads is removed.

Evidence: [fc9c10a7d](https://github.com/bluewaysw/pcgeos/commit/fc9c10a7d493e81e119475f315bbea198a6e9a88), [6d2c31a5f](https://github.com/bluewaysw/pcgeos/commit/6d2c31a5faff2fc60109836f9b249004dd51e928), [8d62cf9e1](https://github.com/bluewaysw/pcgeos/commit/8d62cf9e1fb2d4f0546bce17c3bf6aa2fc2a3c71).
Current source: [Appl/Breadbox/BbxBrow/UI](../pcgeos/Appl/Breadbox/BbxBrow/UI),
[Appl/Breadbox/BbxBrow/init](../pcgeos/Appl/Breadbox/BbxBrow/init).

Limit: the long UI development history includes experiments with document
management and multiple windows that were partly reverted. Do not claim a
new tabbed or fully redesigned multiple-window browser from that history.

### N04. Better image loading and page fitting - H

The browser gains intelligent and progressive image handling, fit-to-window
controls, configurable image-import workers, picture-source selection,
inline SVG, and additional image formats. The product default increases the
connection-worker count from one to two. Graphics Viewer and thumbnail handling
also receive related integration.

Evidence: [690d15fc7](https://github.com/bluewaysw/pcgeos/commit/690d15fc771ff237f0f1306e83ecc3a494bd4c6a).
Current source: [Appl/Breadbox/BbxBrow](../pcgeos/Appl/Breadbox/BbxBrow),
[Library/Breadbox/ImpGraph](../pcgeos/Library/Breadbox/ImpGraph), [Library/Breadbox/ThumbDB](../pcgeos/Library/Breadbox/ThumbDB).

Limit: the available paths differ by image format. In particular, WebP is
published after complete decoding. More workers do not prove parallel TLS
requests or faster initial HTML parsing. Avoid a general claim that every
image format streams progressively.

### N05. Stop, shutdown, layout, HTTP, and cookie reliability - I

Stop cancellation and shutdown now release image and fetch resources more
consistently and avoid late-completion reference-count errors. Other fixes
address table reflow after images arrive, multi-region cells, masked-image
rendering, local HTML opening, large HTTP chunks, and 304 responses. Cookie
path and attribute parsing is also revised.

Evidence: [2356cb75a](https://github.com/bluewaysw/pcgeos/commit/2356cb75a49ae998460502cc9a0f5d9e0dc24ba6), [6059873da](https://github.com/bluewaysw/pcgeos/commit/6059873daf76c4a8546b55f7ec9fb08907cda7aa), [446b0ce4f](https://github.com/bluewaysw/pcgeos/commit/446b0ce4f2820e6bdf8711d022a306e06d9081a0),
[fa0dd95d8](https://github.com/bluewaysw/pcgeos/commit/fa0dd95d81348fabff13976bd2faf34130fc36b8), [257c0b51d](https://github.com/bluewaysw/pcgeos/commit/257c0b51d213336f341ed3586ef225015eb9beb8), [a7c5b7b35](https://github.com/bluewaysw/pcgeos/commit/a7c5b7b351ed730707f27372190f76fc55cb8de3),
[5075ca313](https://github.com/bluewaysw/pcgeos/commit/5075ca313c0b5e3afe4d46e40fca1e376f8c32a3), [85d2a7218](https://github.com/bluewaysw/pcgeos/commit/85d2a721854e25dab5815a0dda258de3313cc088), [b5c152f37](https://github.com/bluewaysw/pcgeos/commit/b5c152f37ad45519ecec78960cb83f4d89d9c2e0), [521c464c7](https://github.com/bluewaysw/pcgeos/commit/521c464c7cb09443abca5e7fe10887e919235f31).
Current source: [Appl/Breadbox/BbxBrow/urlfetch](../pcgeos/Appl/Breadbox/BbxBrow/urlfetch),
[Appl/Breadbox/BbxBrow/urltext](../pcgeos/Appl/Breadbox/BbxBrow/urltext), [Library/Breadbox/Html4Par](../pcgeos/Library/Breadbox/Html4Par),
[Library/Breadbox/UrlDrv/Wmg3Http](../pcgeos/Library/Breadbox/UrlDrv/Wmg3Http), [Library/Cookies](../pcgeos/Library/Cookies).

These are important reliability changes. They do not establish general
standards compliance for HTTP or cookies, or browser security certification.

### N06. Native network and connection-setup repairs - I

PPP connection setup is repaired for Watcom builds. DHCP requests ask for
broadcast responses. Packet-driver work removes an unnecessary polling thread
and preserves registers needed by Dosemu2. The connection application gains
clearer active-access-point selection and separate handling for PPP and other
connection types.

Evidence: [03dff2896](https://github.com/bluewaysw/pcgeos/commit/03dff2896035b1a902dbb7fd586b0d98692878f8), [b09b05507](https://github.com/bluewaysw/pcgeos/commit/b09b05507b0ac156041d88bc9f861cfca7c6624b), [d7878165c](https://github.com/bluewaysw/pcgeos/commit/d7878165cd421ab3dd45a3de060b929bea8cfd7f),
[0ac14f8b9](https://github.com/bluewaysw/pcgeos/commit/0ac14f8b947dc4ca2f961c51bbfef9509077ea5b), [053f0e5b2](https://github.com/bluewaysw/pcgeos/commit/053f0e5b2491ed011225b2862e93c3b8ab560743).
Current source: [Driver/Socket](../pcgeos/Driver/Socket), [Appl/IDialup](../pcgeos/Appl/IDialup).

Limit: retain plain DOS, Dosemu2, and Basebox as separate test environments.
A repair to one network path does not validate all other paths.

## Graphics and file exchange

### G01. PNG import and export, including transparency conversion - H

A new PNG library is integrated into Graphics Viewer and the image-import
path. A PNG translator adds import and export for applications that use the
system translators. Import can blend alpha against a chosen color or convert
it to a GEOS mask. Export can produce an alpha channel from a bitmap mask.
Related work adapts zlib storage to GEOS memory handling.

Evidence: [5ffd6e4c7](https://github.com/bluewaysw/pcgeos/commit/5ffd6e4c71c09f71fce0691285a3eb4490d9b102), [464c26f4a](https://github.com/bluewaysw/pcgeos/commit/464c26f4a8fcdf69a034c1367854a1530df44e01), [17d1ddfe3](https://github.com/bluewaysw/pcgeos/commit/17d1ddfe319fa98426d53a98e3ef77e911bdbf3e).
Current source: [Library/PngLib](../pcgeos/Library/PngLib), [Library/Breadbox/Impex/PNG](../pcgeos/Library/Breadbox/Impex/PNG),
[CInclude/pnglib.h](../pcgeos/CInclude/pnglib.h).

Limit: import rejects interlaced PNGs. The current code also has explicit
scanline and IDAT-chunk limits. Do not promise all valid PNG files, arbitrary
image dimensions, or animated PNG support.

### G02. SVG vector import and export - H

SvgLib adds SVG-to-GString import and GString-to-SVG export, with a translator,
Graphics Viewer integration, browser image integration, inline SVG handling,
and vector-thumbnail support. The implementation handles a useful subset of
shapes, paths, transforms, view boxes, and stroke/fill styles.

Evidence: [690d15fc7](https://github.com/bluewaysw/pcgeos/commit/690d15fc771ff237f0f1306e83ecc3a494bd4c6a).
Current source: [Library/SvgLib](../pcgeos/Library/SvgLib), [Library/Trans/Graphics/Vector/Svg](../pcgeos/Library/Trans/Graphics/Vector/Svg),
[CInclude/svgLib.h](../pcgeos/CInclude/svgLib.h).

Why it matters: supported graphics can stay vector-based when exchanged with
other software.

Limit: this is a subset, not full SVG support. The importer skips elements
such as text, embedded images, use references, and foreignObject. The parser
also has bounded tag storage. Test actual exchange files before claiming
round-trip fidelity.

### G03. Static lossy WebP decoding - H

WebpLib adds a decoder and translator, plus Graphics Viewer and browser image
support. It decodes incrementally into a GEOS bitmap.

Evidence: [690d15fc7](https://github.com/bluewaysw/pcgeos/commit/690d15fc771ff237f0f1306e83ecc3a494bd4c6a).
Current source: [Library/WebpLib/notes/WebPImport.md](../pcgeos/Library/WebpLib/notes/WebPImport.md),
[Library/Trans/Graphics/Bitmap/Webp](../pcgeos/Library/Trans/Graphics/Bitmap/Webp), [CInclude/webplib.h](../pcgeos/CInclude/webplib.h).

Limit: the decoder accepts static lossy VP8 WebP with dimensions up to 2048
pixels per side. It rejects lossless VP8L, alpha, animation, and multiple
image payloads. This is import support; do not claim WebP export.

### G04. Better JPEG handling and TrueColor bitmap exchange - I

Fjpeg is added to the default image-import build. JPEG size checking is repaired
for the fallback path, while palette displays use the IJG decoder's color
reduction/dithering path. MIME handling for local JPEG files is corrected.
BMP export gains working 24-bit output.

Evidence: [82e35dee7](https://github.com/bluewaysw/pcgeos/commit/82e35dee76367b7654004a14c3cfdc8e08ad1d34), [07997c15f](https://github.com/bluewaysw/pcgeos/commit/07997c15fddb6e68dab1b43d835ebe123558f1da), [0251ad6a1](https://github.com/bluewaysw/pcgeos/commit/0251ad6a1bb1e63de24c12e0ca3917da38983dfb),
[8d492cebb](https://github.com/bluewaysw/pcgeos/commit/8d492cebbf15b68998cc5cfa9ae54097ffe44fea), [ed64554e6](https://github.com/bluewaysw/pcgeos/commit/ed64554e6c90036248063833a846eea57645bddb).
Current source: [Library/Breadbox/ImpGraph](../pcgeos/Library/Breadbox/ImpGraph), [Library/Breadbox/Fjpeg](../pcgeos/Library/Breadbox/Fjpeg),
[Library/Trans/Graphics/Bitmap/Bmp](../pcgeos/Library/Trans/Graphics/Bitmap/Bmp).

Limit: describe the decoder choices and output capability. A measured JPEG
speed claim still needs comparable files, display modes, and hardware.

## Applications and supplied content

### A01. Replacement Icon Editor - H

IconEd replaces the old Icon application. It manages icon sets for different
displays, edits bitmaps and masks, imports graphics and token-database entries,
changes size and color depth, previews icons, and writes icon source code.
The supporting bitmap tools include palette reduction and dithering, scaling,
rotation, clipping, and mask operations. A new clipboard transfer format
supports icon sets. English and German help are included.

Evidence: [dd4bce7d5](https://github.com/bluewaysw/pcgeos/commit/dd4bce7d5f186614a11093492fe7d486ef9f2ae3), [27e7803b8](https://github.com/bluewaysw/pcgeos/commit/27e7803b8405d5f8b11df65c1cf5944029f3407d), [caa9b436a](https://github.com/bluewaysw/pcgeos/commit/caa9b436a7e870ca405c68c0a1ac1091f929f2a1),
[f078339f7](https://github.com/bluewaysw/pcgeos/commit/f078339f73988356789a2233b689067c015e554c), [9cfeace12](https://github.com/bluewaysw/pcgeos/commit/9cfeace122718aab2997a8315a4f8f5d7f2f10e6).
Current source: [Appl/IconEd](../pcgeos/Appl/IconEd), [Library/IcmTool](../pcgeos/Library/IcmTool),
[Library/RabeSoft](../pcgeos/Library/RabeSoft), [TechDocs/Markdown/Tools/ticoned.md](../pcgeos/TechDocs/Markdown/Tools/ticoned.md).

The product manifest selects IconEd. Do not present the earlier fix to the
removed Icon application's 256-color export as a separate new feature.

### A02. Home Inventory Plus and Gourmet added to the source and product - I

The repository gains Home Inventory Plus and Gourmet, with product integration,
help, and German translations. Later work makes Gourmet messages localizable
and repairs clipping and page-boundary problems in printed recipes.

Evidence: [530fde459](https://github.com/bluewaysw/pcgeos/commit/530fde459dc879851cfc4c9075e95012eb22b48a), [bc63d9afa](https://github.com/bluewaysw/pcgeos/commit/bc63d9afa60d7710b8c2627b6a126218017ee96d), [81672f9a9](https://github.com/bluewaysw/pcgeos/commit/81672f9a9dff8f597bf27fae85bb075632707abf),
[a320a9372](https://github.com/bluewaysw/pcgeos/commit/a320a9372ba2f80f986210ea77d4be6c6ecb85ac), [633d9d4db](https://github.com/bluewaysw/pcgeos/commit/633d9d4db22838822541c60ae5ce3143a3363813).
Current source: [Appl/Breadbox/Hinv10](../pcgeos/Appl/Breadbox/Hinv10), [Appl/Breadbox/BBGrmt](../pcgeos/Appl/Breadbox/BBGrmt).

Limit: these are additions to this repository. Confirm whether customers
already received these applications in another product before calling them
new applications in version 6.

### A03. Improved Character Map - I

Character Map gains selectable character-box sizes and options for character
codes, magnification, startup fonts, multiple characters, and automatic copying.
It can serve the Insert Special Character workflow as well as standalone use.
Later work corrects the copied text's point size.

Evidence: [8d574cf2e](https://github.com/bluewaysw/pcgeos/commit/8d574cf2e68e79db6505ae4b5a86bedd117e4a6c), [acd8a3d0d](https://github.com/bluewaysw/pcgeos/commit/acd8a3d0d4e83655f3ebc62bb5c7ae5bc950e8d7).
Current source: [Appl/Charm](../pcgeos/Appl/Charm). It is listed in the product manifest.

### A04. Updated GrafCalc - I

The old GrafCalc source is replaced with a revised version, followed by another
set of application updates. GrafCalc and its help are added to the product
manifest. This is a meaningful application update, but the commit messages do
not give a reliable feature-by-feature comparison with the old application.

Evidence: [c7036ba84](https://github.com/bluewaysw/pcgeos/commit/c7036ba84b0942c44ad753a57d43fe28702e95fc), [c7fba013a](https://github.com/bluewaysw/pcgeos/commit/c7fba013a6c59eb489db429b594820b66ab6c715), [9e3da57f5](https://github.com/bluewaysw/pcgeos/commit/9e3da57f51fdc92fb7236a8f088ca8be1b2c89b0).
Current source: [Appl/GrafCalc](../pcgeos/Appl/GrafCalc).

Refinement needed: obtain an author-supplied list of new calculation and graph
features, then confirm it against the old and new implementations. Until then,
use the limited claim "updated GrafCalc".

### A05. Book Reader navigation and scaling - I

Book Reader gains corrected page refresh and scale-to-fit behavior. Previous
and Next can continue into the adjacent content file in a multi-file book,
instead of stopping at each file boundary.

Evidence: [06794d848](https://github.com/bluewaysw/pcgeos/commit/06794d84862a27fb5afb1ffbaffee33ec99dd6af), [43fc1f463](https://github.com/bluewaysw/pcgeos/commit/43fc1f463a8c2ff6cc1f8329d39782eb1a9ce123), [0c1af940a](https://github.com/bluewaysw/pcgeos/commit/0c1af940aec71b78ce9729b87e13a4e9d7291d26).
Current source: [Library/ConView/Main](../pcgeos/Library/ConView/Main).

Limit: direct page-number navigation remains within the current content file.
An adjacent file without numbered pages stops boundary navigation rather than
being skipped.

### A06. Office application compatibility and useful fixes - I

The Watcom migration repairs database and spreadsheet object references,
structure returns, and allocation handling. GeoPoint gains a fix for saving
a newly created presentation before it has a name. Smaller final UI changes
adjust GeoCalc's header layout and restore GeoWrite's toolbar defaults.

Evidence: [f81257082](https://github.com/bluewaysw/pcgeos/commit/f81257082f6f19869cf8a6f37962e6f8e41bc102), [60104d4e1](https://github.com/bluewaysw/pcgeos/commit/60104d4e13e209ea5e339255cdeeda574de0c43f), [eb6846ed2](https://github.com/bluewaysw/pcgeos/commit/eb6846ed20da33f0395cce6e66f9d4949befed99),
[b6f0ea007](https://github.com/bluewaysw/pcgeos/commit/b6f0ea007a9ba5d0c12971ee6be707bf17d343c8), [cd6087f26](https://github.com/bluewaysw/pcgeos/commit/cd6087f268474da827940066ec57a3ae4013104a), [e7353cc0d](https://github.com/bluewaysw/pcgeos/commit/e7353cc0d61088ccb9003727d145f810ca5ddaef), [7ba327389](https://github.com/bluewaysw/pcgeos/commit/7ba32738998fd3ac2ff56a7d383bca57fe3923b8).
Current source: [Appl/GeoFile](../pcgeos/Appl/GeoFile), [Library/FlatFile](../pcgeos/Library/FlatFile),
[Library/Spreadsheet](../pcgeos/Library/Spreadsheet), [Appl/GeoPoint](../pcgeos/Appl/GeoPoint).

Priority: keep the first-save fix and compatibility result. The layout and
toolbar changes can be omitted from short public notes.

### A07. Word Matcher, word-list tools, and learning applications - I

Word Matcher accepts LF-only input and gains German word data. WMLib and a new
WordList Generator support revised word-list handling. Hangman is adapted for
German lists. Laser Letters gains UI, exercise-data, localization, and Quick Tips
updates; Crossword Maker also receives an update.

Evidence: [151502465](https://github.com/bluewaysw/pcgeos/commit/151502465b9c0f78ef32619fe4283e41105aa399), [ca89cec7b](https://github.com/bluewaysw/pcgeos/commit/ca89cec7b93be3369ca357d7cdfd0b26fb6072d2), [c979eb068](https://github.com/bluewaysw/pcgeos/commit/c979eb068d98abf1bbbfbcb2bb78967530b0be8b),
[e8c08377e](https://github.com/bluewaysw/pcgeos/commit/e8c08377e4fd415a5e98f7bcaa5daf2080d36e4a), [bbd0c003b](https://github.com/bluewaysw/pcgeos/commit/bbd0c003b62b985d362f3ccd11b63f7a95bc80e3), [62455d073](https://github.com/bluewaysw/pcgeos/commit/62455d073ce84ef4174d86ab0de162c9d4623c45).
Current source: [Appl/WordMat](../pcgeos/Appl/WordMat), [Appl/Tools/WListGen](../pcgeos/Appl/Tools/WListGen),
[Library/Breadbox/WMLib](../pcgeos/Library/Breadbox/WMLib), [Appl/EduApps](../pcgeos/Appl/EduApps).

Status: Word Matcher, Laser Letters, and Crossword Maker are in the manifest.
WordList Generator is conditional on the tools package. Hangman's source update
does not establish inclusion in the normal product.

### A08. WebBox localization and generated-page handling - I

WebBox receives localizable information text, UI changes, additional content
tags, and simpler HTML frame handling. It is also used as the browser's default
HTML editor in the revised configuration.

Evidence: [48aca0400](https://github.com/bluewaysw/pcgeos/commit/48aca04000cd359ae2a70c526bff171b65043a6b), [fc9c10a7d](https://github.com/bluewaysw/pcgeos/commit/fc9c10a7d493e81e119475f315bbea198a6e9a88).
Current source: [Appl/Breadbox/Webbox](../pcgeos/Appl/Breadbox/Webbox). It is listed in the product manifest.

### A09. GeoLadder and a maintained selection of games - I

GeoLadder is added with product integration, help, German translation, and
follow-up sound and resource-handling fixes. Existing card, puzzle, arcade,
and learning games receive Watcom repairs, Quick Tips, localization, and UI
updates. FreeCell is present in the final manifest despite an earlier temporary
exclusion.

Evidence: [08abdd688](https://github.com/bluewaysw/pcgeos/commit/08abdd68883406ce570a5552c4f254f844701315), [b9b58732a](https://github.com/bluewaysw/pcgeos/commit/b9b58732a25c1d0e9a2152aeec72db358d8f9b8f), [084663ca1](https://github.com/bluewaysw/pcgeos/commit/084663ca188a2e85cc4abd2f7c195c1562cbf424),
[1f2041394](https://github.com/bluewaysw/pcgeos/commit/1f2041394e8f99cb1d4508baabd3d6d3ec98cbb4), [c33199c36](https://github.com/bluewaysw/pcgeos/commit/c33199c3628eca29ea77357d0ecf2916cb1adc5c), [db53c8342](https://github.com/bluewaysw/pcgeos/commit/db53c834233f21f9ca5114ae0adf2c69a981d020), [b3ccad7cf](https://github.com/bluewaysw/pcgeos/commit/b3ccad7cfeee1a35ec3d81cc969a451bf87cd822).
Current source: [Appl/Games/GeoLadder](../pcgeos/Appl/Games/GeoLadder) and the Games section of the manifest.

Limit: do not turn every restored game build into a new-game claim. The current
manifest comments out Taipei, Columns II, Follow Me, Maze Runner, Mine Field,
Treasure Hunt, GeoFrotz, GeoNoid, Paddle, Spider, and several entertainment-pack
games. Source and help updates to those games are not proof that they ship.

### A10. Uni Installer and Install Creator - I

Uni Installer and Install Creator are added to the tree and product. Later work
repairs INI-entry editing and makes the applications less dependent on new
runtime features, with GEOS 2.0 compatibility as an explicit build target.

Evidence: [8075afcce](https://github.com/bluewaysw/pcgeos/commit/8075afcce24329989876e97ebe764ec0899a1541), [3c4618173](https://github.com/bluewaysw/pcgeos/commit/3c461817380c170aaec308ecc3544b2b81e1e04c), [c009c75f9](https://github.com/bluewaysw/pcgeos/commit/c009c75f96ddb60011a8d0ff6e6e8226fb16661e).
Current source: [Appl/Install](../pcgeos/Appl/Install).

Limit: retain the claim of a compatibility target. Do not guarantee installation
on every older GEOS version without tests of the generated packages.

## System, display, input, and reliability

### S01. Desktop resizing in Basebox display modes - H

The host interface gains display-size notifications. The VGA16 driver adds
Basebox modes for 72, 96, and 120 DPI, and the UI responds to host size changes.
Desktop views, windows, taskbar positioning, and screen savers receive related
resizing work.

Evidence: [9b88ec05f](https://github.com/bluewaysw/pcgeos/commit/9b88ec05f2abb09f347e0283da1b713f6b5580d0).
Current source: [Driver/Video/VGAlike/VGA16](../pcgeos/Driver/Video/VGAlike/VGA16),
[Library/HostIf/hostif.asm](../pcgeos/Library/HostIf/hostif.asm), [Library/SpecUI/CommonUI/CWin/cwinScreen.asm](../pcgeos/Library/SpecUI/CommonUI/CWin/cwinScreen.asm),
[Library/Saver/saverApplication.asm](../pcgeos/Library/Saver/saverApplication.asm).

Limit: dynamic resizing requires the corresponding Basebox host service and
mode. It is not a general promise for every physical VGA/VESA adapter or emulator.

### S02. Lower idle CPU demand - I

A new HLT power driver halts the guest processor while GEOS is idle. The product
template selects it. Perf gains a slower idle update path so monitoring need
not keep the system busy. Separate work reduces unnecessary polling in the
packet driver and in Swat.

Evidence: [3efe92bf7](https://github.com/bluewaysw/pcgeos/commit/3efe92bf78715eda0e41a403b1c3c8911bb87a4a), [76b947970](https://github.com/bluewaysw/pcgeos/commit/76b947970de8727bfd323ad866c3db31974e19e3), [d7878165c](https://github.com/bluewaysw/pcgeos/commit/d7878165cd421ab3dd45a3de060b929bea8cfd7f),
[a6db0bba7](https://github.com/bluewaysw/pcgeos/commit/a6db0bba7da1f760b9ef31a078307e62ac95e8b3).
Current source: [Driver/Power/hltpwr](../pcgeos/Driver/Power/hltpwr), [Appl/Perf](../pcgeos/Appl/Perf),
[Tools/build/product/bbxensem/Template/geos.ini](../pcgeos/Tools/build/product/bbxensem/Template/geos.ini).

Limit: measure actual host CPU use and behavior with active serial/network
operations. Do not publish a numerical power or battery-life claim from source
inspection.

### S03. Mouse wheel, natural scrolling, and keyboard support - I

Wheel support is restored through IntelliMouse, CuteMouse, and Basebox-compatible
mouse drivers, with native wheel events and alternative key-emulation modes.
A later Preferences option reverses wheel direction. Keyboard work adds Euro,
Windows, and menu-key mappings in the affected layouts. Code page 858 support
helps FreeDOS and Euro-character use.

Evidence: [651c360d9](https://github.com/bluewaysw/pcgeos/commit/651c360d9313094d1d06d70180af297686a256ad), [97ee5060c](https://github.com/bluewaysw/pcgeos/commit/97ee5060c9a8069b6cfe5adecdec960178724c02), [8ce6528c4](https://github.com/bluewaysw/pcgeos/commit/8ce6528c481afa5fce2bc5fc682784007af013e6),
[f5d461ef0](https://github.com/bluewaysw/pcgeos/commit/f5d461ef0c75da6a9dfe8455e577b27261d2bb0e), [224a374b3](https://github.com/bluewaysw/pcgeos/commit/224a374b38c99e1520e6591c53a8d4d6bbe5b8ff), [3ffbeeea1](https://github.com/bluewaysw/pcgeos/commit/3ffbeeea1b26175db78fe49f0b179dd95ec44950).
Current source: [Driver/Mouse](../pcgeos/Driver/Mouse), [Driver/Keyboard](../pcgeos/Driver/Keyboard),
[Library/Pref/Prefmous](../pcgeos/Library/Pref/Prefmous), [Library/Kernel/Local](../pcgeos/Library/Kernel/Local).

Limit: keyboard changes apply to the modified layouts. Do not claim every
keyboard layout and every mouse transport was tested.

### S04. More display modes and corrected TrueColor drawing - I

Video work restores and repairs higher-resolution modes, adds modes such as
848x480, 960x540, and 960x600, and includes VGA15/VGA24 source. Later fixes repair
TrueColor region and masked-pixel rendering. Bitmap-library compression handling
is corrected for RGB images.

Evidence: [97b0fb24a](https://github.com/bluewaysw/pcgeos/commit/97b0fb24a7f9a5b81a5130755c3afaf11d7fc349), [0f5290b9b](https://github.com/bluewaysw/pcgeos/commit/0f5290b9ba127e4ec0de8bdade2ce36b42921384), [f7ecd75f2](https://github.com/bluewaysw/pcgeos/commit/f7ecd75f2cbacbf1b869679a02d38ec06374824c),
[c63bea14d](https://github.com/bluewaysw/pcgeos/commit/c63bea14deb13427e340901b60f7eb42f26b30a5), [2ccabd1f5](https://github.com/bluewaysw/pcgeos/commit/2ccabd1f535152b683c3307343382927e4c53083), [5712584d6](https://github.com/bluewaysw/pcgeos/commit/5712584d627f10667b147dd71004b62bafe508c8), [f9c3f955c](https://github.com/bluewaysw/pcgeos/commit/f9c3f955c2081a9b0ae620aec305dbbb222174bc).
Current source: [Driver/Video](../pcgeos/Driver/Video), [Library/Bitmap](../pcgeos/Library/Bitmap).

Limit: the VESA modes still depend on the adapter or emulator. A mode in the
driver's table does not establish support on all hardware.

### S05. Compression, bitmap-state, and VM-chain reliability - I

The compression library gains a replacement implementation and correctly sized,
zero-initialized work buffers. A kernel fix ensures the bitmap HugeArray
directory is locked when color-state operations query the bitmap driver.
VMFreeVMChain correctly prevents file compression until the chain is freed.
These are small but important fixes to shared code used by many applications.

Evidence: [6b8a0d4fd](https://github.com/bluewaysw/pcgeos/commit/6b8a0d4fd3fc90a3dca179f39a1d7e52dc5b324e), [54ecdcb32](https://github.com/bluewaysw/pcgeos/commit/54ecdcb32bc0c91cd1af7883730d76a4c796ae40), [d9c7918ae](https://github.com/bluewaysw/pcgeos/commit/d9c7918aec68bdae66fb862c39eacc274efa6c1b),
[c125078c7](https://github.com/bluewaysw/pcgeos/commit/c125078c744a62f1562cac3e7dbbbc03737228c7), [c2744bd02](https://github.com/bluewaysw/pcgeos/commit/c2744bd020b48a8b879ca77e7373211ef69951f8).
Current source: [Library/Compress](../pcgeos/Library/Compress), [Library/Kernel/Graphics/graphicsState.asm](../pcgeos/Library/Kernel/Graphics/graphicsState.asm),
[Library/Kernel/VMem/vmemChain.asm](../pcgeos/Library/Kernel/VMem/vmemChain.asm).

Priority: keep this as a compact reliability point, with the specific failures
available for technical notes. Do not turn it into a claim that all memory or
file-corruption faults have been removed.

### S06. DOSBox file-system selection and folder enumeration - I

The kernel detects DOSBox and selects the OS/2-style primary file-system driver
for that environment. DOS file-system code also gains a repair to folder-name
enumeration. These changes address the guest/host file interface rather than
adding a new on-disk file system.

Evidence: [aaf1536a0](https://github.com/bluewaysw/pcgeos/commit/aaf1536a0afcbc87ea4b8e30a3d5fc3f90c95c78), [30ae3957c](https://github.com/bluewaysw/pcgeos/commit/30ae3957cd6fec21e1b7344bb41417730bfff830).
Current source: [Library/Kernel/FSD/fsdInit.asm](../pcgeos/Library/Kernel/FSD/fsdInit.asm), [Driver/IFS/DOS](../pcgeos/Driver/IFS/DOS).

### S07. Sound, reset, and legacy task-switcher support - I

FM-sound instrument and drum tables and standard UI sounds are corrected.
RESET.BAT is extended to clear state, failed print jobs, clipboard data, and
browser cache files; a German version is supplied. Back & Forth and TaskMax
drivers are restored to the build and product manifest.

Evidence: [17ad953f0](https://github.com/bluewaysw/pcgeos/commit/17ad953f006dd3e3c4f22c07d7e648ac44f573e7), [b4da2d2e1](https://github.com/bluewaysw/pcgeos/commit/b4da2d2e1d7d570fafe0cd85a7fdc32f7c9cf6f0), [d1b4aa2d5](https://github.com/bluewaysw/pcgeos/commit/d1b4aa2d57a8283fe6e086a57dbafae11b453e76),
[b51c164e6](https://github.com/bluewaysw/pcgeos/commit/b51c164e6c49fb562c526d56631df6fd0a1d2f66), [f0288bcdf](https://github.com/bluewaysw/pcgeos/commit/f0288bcdf5fe53d8d6de15e8aee08db4d556e798).
Current source: [Driver/Sound/SoundBlaster](../pcgeos/Driver/Sound/SoundBlaster),
[Tools/build/product/bbxensem/Images/RESET.BAT](../pcgeos/Tools/build/product/bbxensem/Images/RESET.BAT), [Driver/Task](../pcgeos/Driver/Task).

Priority: these are supporting points. RESET removes session and temporary data;
its final help text must explain what users lose. Task-switcher drivers still
require their external task-switching software.

## Localization and documentation for users

### L01. Broad German localization and refreshed help - I

The history adds and revises German application, library, driver, Preferences,
folder, and browser-error translations. It adds help and editable help sources,
localized templates and sample content, and consistent application names.
Later help work centralizes common Exit Application instructions. English help
also receives repairs and updates.

Evidence: [b3aef34f2](https://github.com/bluewaysw/pcgeos/commit/b3aef34f284a18ebb214d2a951a867872e393b1f), [ca073dfa1](https://github.com/bluewaysw/pcgeos/commit/ca073dfa11747beaf16ff977b17bc772e3a2015b), [0b41a277c](https://github.com/bluewaysw/pcgeos/commit/0b41a277c9a50cbb818357260586f10147ab9ba8),
[2a888b51c](https://github.com/bluewaysw/pcgeos/commit/2a888b51ccaecde503e4cf84cb680bcd7aeef487), [28817d256](https://github.com/bluewaysw/pcgeos/commit/28817d25624aca6a4edf40faa95d2a39ef51a122), [e4d9c5ae2](https://github.com/bluewaysw/pcgeos/commit/e4d9c5ae21ac66d64827e75bc28a5b9baa0c86c6),
[3a5dfa379](https://github.com/bluewaysw/pcgeos/commit/3a5dfa379a8e5a48d366eed7233c0135be684c91), [d88eab6ef](https://github.com/bluewaysw/pcgeos/commit/d88eab6ef4c74614c9a4018681dd485327b85cb3), [61fa86a53](https://github.com/bluewaysw/pcgeos/commit/61fa86a53b5a2a34c214a6d4d69f4df4aa993ef8), [8f06794f4](https://github.com/bluewaysw/pcgeos/commit/8f06794f4fe98bce2915a661b441c8d08d37b656).
Current source: [Tools/build/product/bbxensem/Trans](../pcgeos/Tools/build/product/bbxensem/Trans),
[Tools/build/product/bbxensem/Help](../pcgeos/Tools/build/product/bbxensem/Help), [Tools/build/product/bbxensem/HelpSource](../pcgeos/Tools/build/product/bbxensem/HelpSource).

Why it matters: describe localization and help as a substantial product-wide
effort. Individual spelling fixes and repeated binary translation refreshes
should not become separate release points. Confirm completeness against the
final English and German packages, especially for recently changed features.

## Developer and SDK changes

### T01. Open Watcom builds on Linux and Windows - H

The tools and target sources are adapted to Open Watcom, including GOC output,
linker object handling, calling conventions, resource references, the C runtime,
and platform-specific paths. The tools, SDK packaging, target packaging, and
launch scripts are made usable on Linux and Windows. This is the main result
of the long early build-restoration history.

Evidence: [171beef85](https://github.com/bluewaysw/pcgeos/commit/171beef8541c934a0db51a194a2b2ce16253d967), [2266a781d](https://github.com/bluewaysw/pcgeos/commit/2266a781d80237e9637cbed8893b89744544dab4), [a44bf49b7](https://github.com/bluewaysw/pcgeos/commit/a44bf49b7e723b176e28db1852b4a31234494d61),
[8c42f1f03](https://github.com/bluewaysw/pcgeos/commit/8c42f1f03950679197578cbc3b36b7380bbf978e), [933dc3ba2](https://github.com/bluewaysw/pcgeos/commit/933dc3ba20147b9a62907db3e50a0f7b161eff51), [5fe84424a](https://github.com/bluewaysw/pcgeos/commit/5fe84424a0fc927106bfd332d1cf9d1be9618045),
[48c99ba0f](https://github.com/bluewaysw/pcgeos/commit/48c99ba0f58760379c9f1a2bf5c9de7a9a2c0873), [ced5f9323](https://github.com/bluewaysw/pcgeos/commit/ced5f932312c574c49d3b7e7406b2e9356f81038).
Current source: [Tools](../pcgeos/Tools), [Include/Win32](../pcgeos/Include/Win32), [Library/AnsiC](../pcgeos/Library/AnsiC),
[Tools/sdk](../pcgeos/Tools/sdk), [bin](../pcgeos/bin).

Limit: do not list each "make component compile" commit as a product feature.
Some components were already present in the original product and only needed
compiler adaptation.

### T02. Floating-point runtime and preserved math interfaces - I

The migration repairs 32-bit arithmetic helpers and the distinction between
GEOS FloatNum and C floating types. A Watcom floating-point support library is
added and automatically linked when required. Later changes correct calling
conventions, double returns, missing math functions, and segment initialization.

Evidence: [1a3e26bf0](https://github.com/bluewaysw/pcgeos/commit/1a3e26bf0717d673e19ad72e3b708038c5862934), [a7f70b510](https://github.com/bluewaysw/pcgeos/commit/a7f70b51067cb25bccfa43a75b522ef7e913d18f), [49cfacc70](https://github.com/bluewaysw/pcgeos/commit/49cfacc706b323e058bea10b7693c733e25d3402),
[b6f0ea007](https://github.com/bluewaysw/pcgeos/commit/b6f0ea007a9ba5d0c12971ee6be707bf17d343c8), [dd27ea5e5](https://github.com/bluewaysw/pcgeos/commit/dd27ea5e56a2bcc8fa1cd999cb095bf41a00cc39), [7e69d1dba](https://github.com/bluewaysw/pcgeos/commit/7e69d1dba2498882f9d29ad76a22f9f4ccc955f8),
[042043965](https://github.com/bluewaysw/pcgeos/commit/0420439652425095410992afd64e17df267ffe92), [b727c6324](https://github.com/bluewaysw/pcgeos/commit/b727c6324772b2e1dad6ca77ae16d7f36f827cdd), [80627c3cc](https://github.com/bluewaysw/pcgeos/commit/80627c3cc50b0eaeb567f1aa9d851a9e0afb48d2).
Current source: [Library/Math](../pcgeos/Library/Math), [Library/CoProcessor](../pcgeos/Library/CoProcessor),
[CInclude/math.h](../pcgeos/CInclude/math.h), [CInclude/geos.h](../pcgeos/CInclude/geos.h), [Tools/glue](../pcgeos/Tools/glue).

Why it matters: existing applications and new SDK code need the correct data
sizes and return conventions. Do not summarize this as replacing all GEOS
math with ordinary C double arithmetic.

### T03. Corrected C/GOC bindings and compiler/linker contracts - I

The history repairs structure returns, ConstructOptr, object-method alignment,
resource/chunk references, register preservation in C wrappers, token-loading
failure results, and graphics/message parameter declarations. Glue gains more
complete CodeView type and symbol handling, including unions, typedefs, local
symbols, case-sensitive lookup, and source-line information.

Evidence: [ab39445e9](https://github.com/bluewaysw/pcgeos/commit/ab39445e93bf1f6abe994c756e089483f4c4d122), [f81257082](https://github.com/bluewaysw/pcgeos/commit/f81257082f6f19869cf8a6f37962e6f8e41bc102), [8c06f5685](https://github.com/bluewaysw/pcgeos/commit/8c06f568580adf5ab847050fdb088ed7cc6ea56f),
[7358a23eb](https://github.com/bluewaysw/pcgeos/commit/7358a23eb2d31ea17a06d46de0b7a393104eb426), [3d83ba0f3](https://github.com/bluewaysw/pcgeos/commit/3d83ba0f319b641e9392c2bc4668278b276f7291), [17fc1673e](https://github.com/bluewaysw/pcgeos/commit/17fc1673e38a706077228e2d726954644cd504ca),
[08ff4cc80](https://github.com/bluewaysw/pcgeos/commit/08ff4cc80ff4e16c8deeca6390ed4a440cc18669), [dee25f2b5](https://github.com/bluewaysw/pcgeos/commit/dee25f2b59e521a49aa9427ae56ce7db5bb47d77), [766cc605f](https://github.com/bluewaysw/pcgeos/commit/766cc605ff9a8ec92b879bb0ea8f62d44ebf7cb0),
[fc334e281](https://github.com/bluewaysw/pcgeos/commit/fc334e281dca293f11ef69d39c3b8aaee79b1c15), [beb7e2c77](https://github.com/bluewaysw/pcgeos/commit/beb7e2c770262a3f20ba5a889801cce32ac23379).
Current source: [CInclude](../pcgeos/CInclude), [Tools/goc](../pcgeos/Tools/goc), [Tools/glue](../pcgeos/Tools/glue),
[Library/User/Token/tokenC.asm](../pcgeos/Library/User/Token/tokenC.asm), [Library/Kernel/Graphics/graphicsC.asm](../pcgeos/Library/Kernel/Graphics/graphicsC.asm).

Compatibility note: corrected declarations can require source changes when
rebuilding older code. Prepare a short migration note for the affected APIs;
do not claim that every change is invisible to SDK clients.

### T04. Swat on current development hosts - H

Swat is restored for Linux and Windows, with target communication and launch
integration, source and local-variable debugging, focus handling, and lower
idle CPU demand. Later changes improve terminal key decoding, command editing,
source-window scrolling, breakpoint/method resolution, and resizable consoles.

Evidence: [14afd5a83](https://github.com/bluewaysw/pcgeos/commit/14afd5a8329ecca55ee18a7e1a0b7ba3687fb9ed), [566efc6c9](https://github.com/bluewaysw/pcgeos/commit/566efc6c9ceae9b52ee37d70add7f0362dbed7bc), [d159b50c5](https://github.com/bluewaysw/pcgeos/commit/d159b50c5653d46f244b1f86033a8b5d900a1fe5),
[cebdad5fd](https://github.com/bluewaysw/pcgeos/commit/cebdad5fd2ba0410fc660e6616a71381298363d9), [a6db0bba7](https://github.com/bluewaysw/pcgeos/commit/a6db0bba7da1f760b9ef31a078307e62ac95e8b3), [365b6a20b](https://github.com/bluewaysw/pcgeos/commit/365b6a20bc21b90e3fb65ba6fc09f2c007acbb99),
[a2ddb71a8](https://github.com/bluewaysw/pcgeos/commit/a2ddb71a8db23c7b67e7de78fbcb5bcc72a2839f), [e65912047](https://github.com/bluewaysw/pcgeos/commit/e6591204749da53050fd8d19d1e002549cddd52a), [3facef014](https://github.com/bluewaysw/pcgeos/commit/3facef014fa8e9bef590a470474aa85ba8b654c5),
[3c56b1d0c](https://github.com/bluewaysw/pcgeos/commit/3c56b1d0c4044ed8af24130b356b139071857b17), [b356487fe](https://github.com/bluewaysw/pcgeos/commit/b356487fea512b9d6fe9adbc2fbe04c3bb49e85a).
Current source: [Tools/swat](../pcgeos/Tools/swat), [bin/target](../pcgeos/bin/target), [bin/target.cmd](../pcgeos/bin/target.cmd).

Limit: document host-specific key and terminal behavior. For example, Linux
terminal text selection can require Shift when Swat enables mouse reporting.

### T05. Automated localization and Resource Editor repairs - I

ResEdit and the prodLoc scripts provide a batch localization workflow, logs,
and product integration for translation builds. Later fixes repair resource
loading crashes, preserve user notes during translation updates, and correct
resource-count handling.

Evidence: [03e581525](https://github.com/bluewaysw/pcgeos/commit/03e581525c484f86a1c78436b13d77d77ab87e4f), [bc8052343](https://github.com/bluewaysw/pcgeos/commit/bc8052343d17dc38537f0fac335380569bb6ef7f), [c6ae4c8e7](https://github.com/bluewaysw/pcgeos/commit/c6ae4c8e77b54b9ff654c3916f2191f8b1a1b65d),
[5536bf823](https://github.com/bluewaysw/pcgeos/commit/5536bf823f42d06d6e527cb581f3d539795190d8), [c7511e55a](https://github.com/bluewaysw/pcgeos/commit/c7511e55af62e679d0deaf027c455fd2a2e6859c).
Current source: [Appl/Tools/Localize](../pcgeos/Appl/Tools/Localize), [bin/prodLoc](../pcgeos/bin/prodLoc), [bin/prodLoc.cmd](../pcgeos/bin/prodLoc.cmd).

Status: Resource Editor is conditional on the tools package. Its German
translation was later moved to the unreleased area; confirm the intended SDK
and translation-tool package before advertising a fully localized editor.

### T06. Public graphics libraries and reusable bitmap tools - I

New or extended interfaces expose PNG decoding/encoding, SVG import/export,
WebP decoding, vector thumbnails, bitmap transformations, palette operations,
and reusable image/icon UI tools. The new icon-set clipboard format is another
interface addition. The ASCII text translator source is restored to the tree.

Evidence: [5ffd6e4c7](https://github.com/bluewaysw/pcgeos/commit/5ffd6e4c71c09f71fce0691285a3eb4490d9b102), [464c26f4a](https://github.com/bluewaysw/pcgeos/commit/464c26f4a8fcdf69a034c1367854a1530df44e01), [690d15fc7](https://github.com/bluewaysw/pcgeos/commit/690d15fc771ff237f0f1306e83ecc3a494bd4c6a),
[047cedcd5](https://github.com/bluewaysw/pcgeos/commit/047cedcd583fed14b8d4eba75e8e82d2bee26dc1), [9cec9ef38](https://github.com/bluewaysw/pcgeos/commit/9cec9ef38d72d08d7b6950bb0fe2770b0f0ca096), [e22dce833](https://github.com/bluewaysw/pcgeos/commit/e22dce833011d426e38674e3189c78472294c87e),
[27e7803b8](https://github.com/bluewaysw/pcgeos/commit/27e7803b8405d5f8b11df65c1cf5944029f3407d), [caa9b436a](https://github.com/bluewaysw/pcgeos/commit/caa9b436a7e870ca405c68c0a1ac1091f929f2a1), [dd4bce7d5](https://github.com/bluewaysw/pcgeos/commit/dd4bce7d5f186614a11093492fe7d486ef9f2ae3), [f0bcdce35](https://github.com/bluewaysw/pcgeos/commit/f0bcdce35f50363f789b1c2d9a58560b1b733878).
Current source: [CInclude/pnglib.h](../pcgeos/CInclude/pnglib.h), [CInclude/svgLib.h](../pcgeos/CInclude/svgLib.h),
[CInclude/webplib.h](../pcgeos/CInclude/webplib.h), [CInclude/bmptools.goh](../pcgeos/CInclude/bmptools.goh),
[CInclude/icmtool.goh](../pcgeos/CInclude/icmtool.goh), [Library/Trans/Text/Ascii](../pcgeos/Library/Trans/Text/Ascii).

Compatibility note: use the final headers and geode export lists. The new
formats retain their limits described in G01-G03; library availability does
not establish full file-format conformance.

### T07. SDK documentation, examples, utilities, and build workflow - I

The SDK documentation is imported, converted to Markdown, and published through
a searchable documentation site. DDK material and many C/GOC examples are added
or repaired. Tools include cvtpcx, geodump updates, and the new mkext utility,
which generates GOC extern declarations. Build scripts gain separate EC/NC
target handling and compatibility with modern Perl distributions.

Evidence: [f66a68cbe](https://github.com/bluewaysw/pcgeos/commit/f66a68cbe7912ff409ebdd5cb70ed4ee46b6ca12), [be752f2d9](https://github.com/bluewaysw/pcgeos/commit/be752f2d9783ae376002a94905ed81c4f20eb1ea), [e81ceac71](https://github.com/bluewaysw/pcgeos/commit/e81ceac710362cd4b2fcefb898bdad9e37abfb67),
[ab166a382](https://github.com/bluewaysw/pcgeos/commit/ab166a3822a65b5c025a25f4d44018bf6e17f4ba), [7cc5abd09](https://github.com/bluewaysw/pcgeos/commit/7cc5abd092e2a38fdd35b039f9fb4d3f9a4bf446), [06f883308](https://github.com/bluewaysw/pcgeos/commit/06f883308b2143fe910f68e7b6cbfbd8b4b764a8),
[3d2e9642d](https://github.com/bluewaysw/pcgeos/commit/3d2e9642d124091b39d7b8a33ac4031904e12dec), [8dcc76ad6](https://github.com/bluewaysw/pcgeos/commit/8dcc76ad6ba19914406a805937885adcaaae542c), [0197b5445](https://github.com/bluewaysw/pcgeos/commit/0197b5445644ca0d0df546eaa25a9ce740f0d6b3),
[eb6916fe8](https://github.com/bluewaysw/pcgeos/commit/eb6916fe87be00a5319646e7de5b25344237cf0e), [ec3862b8b](https://github.com/bluewaysw/pcgeos/commit/ec3862b8b3cdddec1dbd893f7d992e041fdcb2e7).
Current source: [TechDocs/Markdown](../pcgeos/TechDocs/Markdown), [Appl/SDK_C](../pcgeos/Appl/SDK_C), [Tools/mkext](../pcgeos/Tools/mkext),
[Tools/build/product/bbxensem/Scripts/buildbbx.pl](../pcgeos/Tools/build/product/bbxensem/Scripts/buildbbx.pl).

Priority: combine documentation, examples, and tooling into a small number of
SDK release points. Do not list every chapter import, hyperlink repair, or
old CI experiment.

## Important source additions with unconfirmed product status

These changes are worth keeping for release planning, but none establishes
inclusion in the normal product manifest at the review endpoint.

### O01. Gopher client, server, and supporting libraries - O

Gopher, Navigate, GClient, and GServer source is added and later adapted to the
revised host interface. Evidence: [2ed590fb7](https://github.com/bluewaysw/pcgeos/commit/2ed590fb78c976e4772b9dc2239410149ca047ad), [98858135e](https://github.com/bluewaysw/pcgeos/commit/98858135e4e63b7b4342cb5bb711f1eeabbb9536), [9b88ec05f](https://github.com/bluewaysw/pcgeos/commit/9b88ec05f2abb09f347e0283da1b713f6b5580d0).
Current source: [Library/Gopher](../pcgeos/Library/Gopher), [Library/Navigate](../pcgeos/Library/Navigate), [Appl/GClient](../pcgeos/Appl/GClient),
[Appl/GServer](../pcgeos/Appl/GServer). These components are not listed in the normal product manifest.
Confirm the intended package and required host setup before promoting them.

### O02. VConvert and vector-format import - O

VConvert, Meta, and the VCImpex filter add HPGL and CGM import source and build
support. Evidence: [7f11797f2](https://github.com/bluewaysw/pcgeos/commit/7f11797f2e59d82fe3f91b450284c1922392c858), [940b2223d](https://github.com/bluewaysw/pcgeos/commit/940b2223d1cc133c410bc4bce963718453388a53), [b4e086d62](https://github.com/bluewaysw/pcgeos/commit/b4e086d621e2c22610bd908014b8d8c99039418a),
[76660ede3](https://github.com/bluewaysw/pcgeos/commit/76660ede3be98d9c0fb9e5dd0734520dcb2a9cfa). Current source: [Appl/Breadbox/VConvert](../pcgeos/Appl/Breadbox/VConvert),
[Library/Breadbox/Meta](../pcgeos/Library/Breadbox/Meta), [Library/Breadbox/Impex/VCImpex](../pcgeos/Library/Breadbox/Impex/VCImpex).
They are not listed in the normal product manifest. Confirm whether they will
ship as applications, translators, or SDK material.

### O03. Note Taker source replacement and pen-library fixes - O

Note Taker is replaced with an assembly implementation; later work fixes
Note Taker and Pen Support and enables saved options.
Evidence: [3b79d2e9c](https://github.com/bluewaysw/pcgeos/commit/3b79d2e9c6f42da0c7b6f4ac277f2f5ef7bd415d), [be7df391b](https://github.com/bluewaysw/pcgeos/commit/be7df391b68670fe3e19caa602872322cb9b49b2), [ac56529c1](https://github.com/bluewaysw/pcgeos/commit/ac56529c190377ce9c0e4b58263fd79437690551), [c55b90e82](https://github.com/bluewaysw/pcgeos/commit/c55b90e82a1f0f0a3c2f8daab43440d44b39349c).
Current source: [Appl/NTaker](../pcgeos/Appl/NTaker), [Library/Pen](../pcgeos/Library/Pen). It is not listed in the normal
product manifest. Existing-document and pen-input compatibility need release
confirmation.

### O04. PicAlbum and PhotoPC build restoration - O

PicAlbum and the PhotoPC library are made buildable.
Evidence: [8f8668c11](https://github.com/bluewaysw/pcgeos/commit/8f8668c117256487f893ac8f474d16f1a4dd16cf). Current source: [Appl/PicAlbum](../pcgeos/Appl/PicAlbum), [Library/PhotoPC](../pcgeos/Library/PhotoPC).
PicAlbum is absent from the normal product manifest, and the PhotoPC library
entry is commented out. Keep this as an optional-component candidate.

### O05. Other restored applications and development drafts - O

The history also restores the Dose application source and makes an old
Startbar draft compile. Evidence: [70cbe801c](https://github.com/bluewaysw/pcgeos/commit/70cbe801c58a3c6d8fc9a69c0b4a0f8666a456ab), [2fa57dd0b](https://github.com/bluewaysw/pcgeos/commit/2fa57dd0b04161fb2133bc97c2f753c7e0ae62fc),
[10fcb26ae](https://github.com/bluewaysw/pcgeos/commit/10fcb26ae2ca375075a1ef06ff7df3ed2660d2a1). These are not listed in the normal product manifest. Their build
restoration does not establish release readiness. Keep them out of the main
user highlights unless the release team selects and validates them.

## Deliberate exclusions and claims to avoid

- Initial source publication and repository moves: [06a10e6d0](https://github.com/bluewaysw/pcgeos/commit/06a10e6d062d03e4c2b50ea9f1e6c799be8fb9e2),
  [6101511a2](https://github.com/bluewaysw/pcgeos/commit/6101511a20e28efea23d260a1978efef3fa7bd3d), [963612ee4](https://github.com/bluewaysw/pcgeos/commit/963612ee4b3733aa5c6b7c439bd85180a4527862). These establish the baseline and layout.
- Merge-only history and repeated feature-development steps. Count the
  surviving capability once, even if many branches and merges contributed.
- Routine generated Makefiles/dependencies, filename-case repairs, formatting,
  comments, revision bumps, compiler-warning cleanup, and old Travis setup
  experiments. Major build-system results are retained under T01 and T07.
- JavaScript support: [136f22926](https://github.com/bluewaysw/pcgeos/commit/136f22926d95a6ff5626cbfdc3500e5a37f8ccf2) removes the unused engine and browser
  variants; [1333b41c3](https://github.com/bluewaysw/pcgeos/commit/1333b41c35b213222bae8f9ceed9c6b38ecf5089) removes a remaining header. Script-related parser
  improvements do not mean that JavaScript execution was restored.
- The former Nimbus outline driver: removed from the release by [ceafa23df](https://github.com/bluewaysw/pcgeos/commit/ceafa23df94f33e2678cb1b8634f7d1683ce8904).
  This is separate from the retained Nimbus TrueType font files.
- BIM instant messaging: removed from the product manifest by [ebd345be8](https://github.com/bluewaysw/pcgeos/commit/ebd345be8ff7df23c8fc4804eddc18fd656e49ea).
- Temporary exclusions that no longer describe the endpoint. In particular,
  FreeCell's earlier exclusion [cafaa9d02](https://github.com/bluewaysw/pcgeos/commit/cafaa9d024325b08ecbdc690660bba19ba63108f) is superseded by its active entry
  in the final Games manifest.
- Experimental implementations later replaced within the same feature:
  intermediate TrueType memory/cache designs, TrayApps shutdown attempts,
  selector artwork experiments, and browser UI experiments.
- Small application repairs with no clear release-level benefit. Examples
  include isolated label changes, mnemonic corrections, and individual dialog
  layout changes. Their aggregate effects can support an application or
  localization entry without becoming independent claims.
- Work in other repositories, such as the Basebox host or host installers.
  This review records dependencies on that work, not its complete change list.

## Information needed to refine importance

### 1. The actual previous release

Supply its product name, version, and preferably a source commit or release
archive. A list of what was already shipped also helps. This is the largest
remaining factor: a major repository addition may be old news to customers.
It is especially relevant to restored applications, supplied fonts, and work
that may already have appeared in a version 6 preview or another distribution.

### 2. The final package contents

Supply the intended normal, optional, games, developer, and translation-tool
packages. Confirm English/German choices and which commented-out applications
will be enabled. This decides whether O01-O05 become user release points and
whether conditional tools belong only in SDK notes.

### 3. The release priorities

Rank the main promises, for example: document work and printing; a useful
classic desktop; better web/image exchange; running on current host systems;
or SDK development. The current draft gives broad user benefit the highest
priority and gives SDK changes their own section. Your ranking can reduce the
headline list substantially.

### 4. Supported machines and host versions

Supply the minimum compatible Basebox build and the intended status of plain
DOS, FreeDOS, Dosemu2, physical hardware, display modes, and input drivers.
This determines how prominently to present N01, N06, and S01-S04 and which
requirements must accompany them.

### 5. Evidence from the final release build

Supply known-good test results and known defects for document opening/saving,
font substitution and printing, dictionaries, network/TLS connections,
resizing, and new graphic formats. For performance claims, supply before/after
measurements with the same data and environment. Source changes establish
intent and implementation; these tests establish the claims users can rely on.

### 6. Author summaries for replaced applications

An old/new feature list is most useful for GrafCalc, Note Taker, and imported
applications such as Home Inventory Plus and Gourmet. Commit messages such as
"new code" do not reliably identify user-visible differences. Final font and
dictionary license lists should also be checked against the selected package.

## Review coverage and accounting

- Total screened: 3,602 commit records.
- Baseline import and repository moves: 3.
- Merge/integration records: 802, including 56 with combined changed paths.
- Directly cited non-merge supporting commits: 227.
- Other screened commits, excluded as separate release claims: 2,570.
- Unscreened commit records: 0.
- Catalog: 52 grouped topics, including 5 optional/source-only topics.

Commit counts by recorded author year:

- 2018: 241.
- 2019: 311.
- 2020: 228.
- 2021: 91.
- 2022: 233.
- 2023: 534.
- 2024: 1,620.
- 2025: 195.
- 2026: 149.

Every commit is accounted for by the following exclusive rules, applied in
order: baseline import/move; merge/integration; directly cited non-merge
support; other screened history not selected as a separate release claim.
The last group includes intermediate work already represented by a surviving
topic as well as routine maintenance and removed work. It is not a claim that
all of those commits were useless.

The directly cited support set is the commit links in this document after
removing baseline and merge commits. The remaining set can be reproduced by
subtracting those sets from the full endpoint history. No commit records remain
unscreened. Product inclusion, exact previous-release novelty, runtime quality,
and the stated optional-component questions remain open.

To reproduce the ordered history, run this command in the pcgeos checkout:

    git log --reverse --topo-order --format='%H %ad %s' --date=short beb7e2c770262a3f20ba5a889801cce32ac23379

The review endpoint stays fixed even if master later advances. Update this
document with a new endpoint and review only the additional range before
publishing release notes.
