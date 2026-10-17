# BbxBrow cookies

BbxBrow and Wmg3Http link the shared Cookies library. HTTP Set-Cookie
headers call CookieParse in Library/Cookies/Cookies.goc; request headers
use CookieFind through SendCookies in
Library/Breadbox/UrlDrv/Wmg3Http/WMG3HTTP.goc. The old driver-local
cookies.goc contains the legacy implementation; its initialization, cleanup,
and declarations in WMG3HTTP.goc are disabled with #if 0.

## Attribute scanning and default paths

CookieParse splits optional attributes on semicolons, then separates each
name and value at the first equals sign. Unknown attributes cannot consume
subsequent Path, Domain or Secure attributes. Secure is recognized next to
HttpOnly and other flag attributes. The initial cookie value still uses
HTScanCookie and may contain equals signs. Evidence: CookieParse and
HTScanCookie in Library/Cookies/Cookies.goc.

CookieSet defaults a missing, empty or non-absolute Path to the containing
request directory. A root-level request such as /log-in defaults to /;
query-string slashes are excluded. CookieFind tests the stored path as a
prefix of the requested path. Evidence: CookieSet and CookieFind in
Library/Cookies/Cookies.goc. The host check
Library/Cookies/tests/check_cookie_parse.pl extracts the actual parser and
default-path code; it covers modern attributes, session cookies, default
paths and restoration of the request buffer.

Cookies without Expires are session cookies (TDAT_year == SESSION_COOKIE).
CookiesWrite deliberately omits them from SP_PRIVATE_DATA/cookies.txt;
CookiesCleanup frees them on library detach. CookieParse does not recognize
Max-Age. Evidence: CookieSet, CookiesWrite, CookiesCleanup, COOKIES_ENTRY,
and reservedWords in Library/Cookies/Cookies.goc.

## Cached pages after login

A normal link can reuse an unexpired parsed page through
URLFrameFetch.goc's ObjCacheFindURL call without invoking the HTTP driver.
The object-cache lookup keys on type and URL, with source-cache expiration,
not cookie state. The source cache also keys by URL. Cookies do not notify
these caches when changed: CookieParse/CookieSet in the shared library
only update cookie storage. A login POST forces its own load but does not
invalidate other URLs. Reload sets forceLoad and bypasses the object cache;
LoadURLToFile uses ULM_ALWAYS to contact the driver. Evidence:
Appl/Breadbox/BbxBrow/urlframe/URLFrameFetch.goc,
cache/ObjectCache.goc (ObjCacheFindURL), cache/SourceCache.goc
(SrcCacheFindURL), urlfetch/URLLoad.goc (LoadURLToFile), and
Library/Cookies/Cookies.goc (CookieSet).
