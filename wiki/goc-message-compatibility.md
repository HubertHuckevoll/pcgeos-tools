# GOC message compatibility

GOC assigns every `@message` the class's next sequential message number in
source order. Existing message declarations must therefore not be inserted,
removed, or reordered when binary compatibility matters; append new messages
instead.

For conditional builds, keep a pre-existing message in its original slot for
the configuration where it already existed. A declaration needed only by a new
configuration belongs after that configuration's existing messages, so their
numbers stay unchanged.

Evidence: `Tools/goc/parse.y`, `messageLine` increments
`classBeingParsed->data.symClass.nextMessage` at lines 1712-1725; the generated
message list is emitted as an enum at lines 1167-1185. The GOC documentation
also describes messages as compile-time 16-bit enumerated values in
`TechDocs/html/Programming/GOCLanguage/combo.htm` around lines 1611 and
1890-1905.

For a library header using `@protominor`, wrap the public declarations in
`@deflib <library>` and `@endlib`. The defining library must suppress only
the `@protominor`/matching `@protoreset` pair with a private `XGOCFLAGS`
build macro; external clients keep those directives and emit the library
dependency. The library's normal `LIBNAME` handling already supplies its
`-L` option, so do not add a duplicate. Evidence: `CInclude/html4par.goh`
and `Library/Breadbox/Html4Par/local.mk`.
