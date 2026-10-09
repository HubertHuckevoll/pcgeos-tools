# Html4Par script feature split

`HTML_SCRIPT_SUPPORT` is derived from `JAVASCRIPT_SUPPORT` or
`COMPILE_OPTION_AUTO_BROWSE` in `Library/Breadbox/Html4Par/internal.h`. It
enables script/event collection and AutoBrowse analysis. External `SCRIPT
SRC` content is fetched and read directly from its HugeArray by
`HandleExternalScript()` in `htmlpars/htmlpars.goc`.

`PopStyle()` runs its tag-specific close handling before shifting that tag
out of the parser stack. `EnclosingCount()` called from a close handler
therefore still sees the closing tag and its enclosing tags. Evidence:
`Library/Breadbox/Html4Par/htmlpars/parstags.goc` (`PopStyle`,
`EnclosingCount`).

`SkipRawTextContent()` is shared by every build variant. `HandleNamedTag()`
must resolve `tagStyle` before filtering attributes and use the raw-text path
for `STYLE`. `SCRIPT` uses that path when script processing is disabled or
`ignoreTags` is nonzero; ignored `TITLE` and `TEXTAREA` bodies also need it so
apparent tags cannot change nesting. Calling `HandleScript()` on an ignored
or disabled path incorrectly creates script storage. `HandleNamedTag()` owns
and frees the parameter array passed to `Open_SCRIPT()`; the callee must not
free it a second time. Evidence: `htmlpars/htmlpars.goc`.

`HTML_JAVASCRIPT` enables collection in both JS and AutoBrowse builds;
execution additionally requires `JAVASCRIPT_SUPPORT`. `Open_NOSCRIPT()` in
`htmlpars/opentags.goc` leaves suppression active when script processing or
`HTML_IGNORE_NOSCRIPT` is enabled. Suppression uses both `TAG_IGNORE_TAGS`
and `TAG_FLUSH_TEXT`: the main output loop also checks `ignoreTags`, so
suppression survives a full `HTML_MAXSTACK` formatting stack.
`GetCurrentStyles()` in
`htmlpars/parstags.goc` must preserve `TAG_CUMULATIVE_FLAGS` even when
`HTML_READ_FAST` skips formatting. Ignored attributes still require the
quote-aware parameter scanner, with values discarded before allocation.

`JAVASCRIPT_SUPPORT` additionally owns execution and reparsing HTML generated
by `document.write`. The `HTMLextra.HE_scriptSrc` fields, `ScriptSrcHeader`,
`HFTT_SOURCE_SCRIPT`, `HTMLgetcLow()` injection path, and `getcScriptURL()`
reader belong to this execution-only path. Do not widen them to
`HTML_SCRIPT_SUPPORT` unless a non-JavaScript build gains a generated-HTML
producer and initializes the corresponding public `HTMLextra` fields.
