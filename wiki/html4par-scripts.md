# Html4Par script feature split

`HTML_SCRIPT_SUPPORT` is derived from `JAVASCRIPT_SUPPORT` or
`COMPILE_OPTION_AUTO_BROWSE` in `Library/Breadbox/Html4Par/internal.h`. It
enables script/event collection and AutoBrowse analysis. External `SCRIPT
SRC` content is fetched and read directly from its HugeArray by
`HandleExternalScript()` in `htmlpars/htmlpars.goc`.

`JAVASCRIPT_SUPPORT` additionally owns execution and reparsing HTML generated
by `document.write`. The `HTMLextra.HE_scriptSrc` fields, `ScriptSrcHeader`,
`HFTT_SOURCE_SCRIPT`, `HTMLgetcLow()` injection path, and `getcScriptURL()`
reader belong to this execution-only path. Do not widen them to
`HTML_SCRIPT_SUPPORT` unless a non-JavaScript build gains a generated-HTML
producer and initializes the corresponding public `HTMLextra` fields.
