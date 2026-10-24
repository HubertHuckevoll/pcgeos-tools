# HTML character mapper results

`HTMLTranslateCharNum()` is not restricted to SBCS byte values. In SBCS
builds, `TranslateCharNum()` first tries `LocalCodePageToGeosChar()` for
Latin-1 input, then looks up `xlateTable`. Some entries return
`HTML_SPECIAL_ENTITY_BASE + index`, where the base is 10000, to request
special HTML rendering rather than a single GEOS character. For example,
U+00DE (THORN) returns 10010; truncating that to a byte produces 0x1a,
`C_GRAPHIC`, without a graphic run. Byte-oriented callers must reject or
handle these non-byte results before storing them.

Evidence: `Library/Breadbox/Html4Par/htmlpars/htmlpars.goc`
(`TranslateCharNum`, `HTMLTranslateCharNum`, special-entity handling around
lines 1608-1612), `htmlsty.goh` (`xlateTable`, THORN and fraction entries),
`internal.h` (`HTML_SPECIAL_ENTITY_BASE`),
`Library/Kernel/Local/cmapLatin1.asm` (unmapped THORN), and
`CInclude/char.h` (`C_GRAPHIC`).

`MSG_VIS_TEXT_APPEND_PTR` does not filter control characters:
`AppendWithSomething` sets `VTRP_flags` to zero. Its EC entry checks for
embedded NULs; graphic markers require matching graphic runs.
Evidence: `Library/Text/Text/textMethodSet.asm` (`VisTextAppendPtr`,
`AppendWithSomething`) and `Library/Text/TextAttr/taRunQuery.asm`
(`TA_GetGraphicForPosition`, `NO_GRAPHIC_RUN_AT_GIVEN_POSITION`).

GEOS SBCS differs from modern MacRoman at 0xc6 (U+0394 capital delta),
0xd7 (U+25C6 black diamond), 0xde (U+00FD y acute) and 0xdf (U+00DD Y acute).
Both map 0xdb to U+20AC euro; Include/char.def calls this C_CURRENCY and
aliases it as C_EURO_CHAR. GEOS 0xf0 is C_LOGO and has no Unicode mapping
in the TrueType driver. Evidence: geosCharMap in
Driver/Font/TrueType/Adapter/ttcharmapper.c, CInclude/unicode.h and
Include/char.def. Do not use an unmodified MacRoman decoder for font import.
