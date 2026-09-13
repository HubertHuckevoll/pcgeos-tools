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
