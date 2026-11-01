# HostIF SSL protected-mode static analysis

The pointer-decoding finding below applies to the outdated binary identified
in the original inspection. The user replaced it and confirmed that the page
now loads. The current binary has SHA-256
4af21ac72af122ea919638dc91cec14318c2a999f0d48b82118b8a43cb8c021a
and its AsyncSSLRead::PollStatus includes protected-mode selector checks and
translation. Do not use the old finding as the diagnosis of current slowness.

## Finding

The installed Linux Basebox binary handles protected-mode addresses in its
ordinary networking path, but not in three SSL paths. GEOS passes selector:offset
pointers; these SSL paths interpret them as real-mode segment:offset pointers.
This is a concrete interface incompatibility, independent of browser buffering
or interrupt/mutex placement.

Examined binary: /home/konstantinmeyer/pcgeos-basebox/binl64/basebox

- ELF x86-64, not stripped; inspected with nm, readelf and objdump. Not executed.
- Build ID: 2ee7f9dba3473b300de5b3af3f6bf25b12e46c1b
- SHA-256: bfd32bf4171d8bf2ffe8feb58160f6463a176f4f3647635ea4bc94d28795ff10
- File timestamp: 2026-02-07. This is not a verified build/version date.
- Windows/macOS binaries have not been verified by this analysis.

## GEOS side

Library/SSL/ssl/ssl_lib.c, active COMPILE_OPTION_HOST_SERVICE_ONLY branch:

- SSL_write passes (dword) buf as data2 to HIF_SSL_WRITE (1210).
- SSL_read passes (dword) buf as data2 to HIF_SSL_READ (1209).
- SSL_set_tlsext_host_name passes (dword) name as data2 to
  HIF_SSL_SET_TLSEXT_HOST_NAME (1215).

Library/HostIf/hostif.asm:HOSTIFCALL loads data2.low into CX and data2.high into
DX. HostIfCall sends those words unchanged through the shared port. Therefore
G_commandBuffer+6 is the offset and G_commandBuffer+8 is the selector in PM.
There is no conversion to real-mode memory and no DOS bounce buffer.

## Binary evidence

The following snippets describe the relevant instructions, not recovered source.
The numeric addresses apply only to the binary identified above.

### TLS writes

AsyncSSLWrite::Init(unsigned short*) starts at 0x99cb10.
At 0x99cb66 it loads G_commandBuffer+8, and at 0x99cb77 it loads
G_commandBuffer+6. At 0x99cb87 it shifts the former left by four bits; at
0x99cb90 it adds the offset. The loop at 0x99cbf0 reads bytes from this
address using mem_readb, before passing the copied data to tls_write.
There is no protected-mode selector resolution in this function.

### TLS reads

AsyncSSLRead::Init(unsigned short*) at 0x99cca0 stores the guest destination
pointer, swapping its two words with pshuflw before saving it at object+0x203c.
The HIF_SSL_READ dispatcher at 0x99dd10 inlines the same initialization.

AsyncSSLRead::PollStatus() starts at 0x99ea80. Its copy loop loads the saved
segment/selector at 0x99eac0 and the offset at 0x99eacf, shifts the former
left by four at 0x99ead8, adds the offset and byte index, then calls
mem_writeb at 0x99eae4. This writes received plaintext to the wrong guest
address when the saved value is a PM selector.

### TLS hostname / SNI

The SSL dispatcher jump table at 0xda7ac0 is indexed by function minus 1202.
The 1215 entry selects handler 0x99deb0.

At 0x99df0e the handler loads G_commandBuffer+6. At 0x99df29 it loads
G_commandBuffer+8, shifts it left by four at 0x99df33 and adds the offset
at 0x99df36. It then calls MEM_StrCopy and tls_sni_set. The resulting hostname
is read from the wrong memory in protected mode.

### Ordinary sockets use a different address conversion

AsyncSocketSend::Init(unsigned short*) starts at 0x99ce80. At 0x99cf0e it tests
G_protectedOpMode, branching to 0x99cfd8 for protected mode. That path resolves
the selector through the GDT/LDT descriptor and adds its base to the offset.
Only its real-mode branch uses segment << 4.

AsyncSocketResolveAddr::Init(unsigned short*) at 0x99cd40 has the same PM/RM
split. Thus the difference between working plain HTTP and broken HTTPS is
present in the inspected host implementation.

## Relation to the reported failure

The reported text matches Tools/build/product/bbxensem/Privdata/htmlerr/error9.htm,
selected by Wmg3Http's MsgConnectErr. HTTPGet maps SSL_connect <= 0 to
SE_CONNECTION_ERROR and that message. A wrong SNI hostname can cause precisely
this handshake failure. If the handshake happens to succeed, SSL write and
read buffer addresses are still wrong.

Selector allocation and the contents at selector*16 can vary between sessions
and machines. This provides a mechanism for differing symptoms; the exact
failing operation in the user's completed session was not captured.

The prior host-side regression checks mock SSL/HostIF calls. They verify browser
buffering and scheduling but do not reproduce Basebox's guest address decoding,
so they cannot exclude this incompatibility.

## Other ABI observations

The 1206 (SSL_SET_FD) handler at 0x99db98 stores the association between TLS
handle and socket, marks that socket as TLS, but writes status 7 and result 0
at 0x99dc2a/0x99dc37. The GEOS wrapper returns the low word directly, and its
caller treats this nonzero value as Boolean success. Changing this wrapper
to return the high word would therefore break binding with this binary.

The 1216 (SET_SSL_METHOD) entry selects 0x99d9c0, which returns status 7 and
result 0 without changing a method. The GEOS wrapper again exposes 7 as Boolean
success. Hence the browser's SSLv2 fallback does not actually switch methods
with this binary; retries can obscure the first failure.

## Fix location

The direct fix is in Basebox: reuse its existing protected-mode address decoder
for SSL write, SSL read destination and SNI hostname access. Review the SSL
return conventions and unsupported method fallback separately.

A GEOS-side compatibility workaround would require bounded buffers in DOS
memory, passing their real-mode segment:offset to these legacy SSL functions
and copying to/from the PM buffers. Reinterpreting a selector as a segment,
or merely converting to a linear address and packing it as a far pointer,
does not solve access to arbitrary PM memory above the real-mode range.

No further GEOS code changes were made for this static-analysis round.

## Reproduce

    nm -C /home/konstantinmeyer/pcgeos-basebox/binl64/basebox
    objdump -d -C --start-address=0x99cb10 --stop-address=0x99cca0 /home/konstantinmeyer/pcgeos-basebox/binl64/basebox
    objdump -d -C --start-address=0x99ea80 --stop-address=0x99eaf8 /home/konstantinmeyer/pcgeos-basebox/binl64/basebox
    objdump -d -C --start-address=0x99deb0 --stop-address=0x99df78 /home/konstantinmeyer/pcgeos-basebox/binl64/basebox
    objdump -d -C --start-address=0x99ce80 --stop-address=0x99d0c0 /home/konstantinmeyer/pcgeos-basebox/binl64/basebox

## Remaining delay before the first page text

The captured Tagesschau HTML response was 1,574,926 bytes (without images),
including 504 source tags and 55 inline SVGs. Wmg3Http does not negotiate
Content-Encoding and currently uses a 2048-byte TLS receive buffer. Transferring
that many bytes requires 770 body reads, plus any extra reads caused by headers or fragmentation.

In the current binary, AsyncSSLRead::Init at 0x691480 calls AsyncOp::Init at
0x691280, which returns HIF_PENDING for this non-threaded operation. Read
processing occurs through AsyncSSLRead::PollStatus (0x693ba0), invoked from
GeosHost_TickHandler (0x6933e0). Even buffered TLS plaintext goes through this
asynchronous path; Init has no synchronous buffered-data fast path. The poll
first tries tls_read and, if empty, consumes up to 8192 encrypted socket bytes
and leaves completion to a later poll. Guest requests currently ask for 2048
plaintext bytes. No wall-clock transfer or parser timings were measured.

BbxBrow URLFetchChildThread acknowledges the document after LoadURLToFile
returns. MSG_URL_FRAME_URL_FETCHED then parses that completed source file with
ParseFrameHTML/ParseAnyFile before attaching its result for display. It does
not render HTML progressively while downloading. Thus download latency and
full-document parsing contribute sequentially to the initial blank period.
Image fetch/import concurrency primarily affects the later loading phase.

A fresh direct HTTP/1.1 comparison after the host update returned 1,574,997
uncompressed bytes in 0.263 seconds, versus 123,106 wire bytes in 0.143 seconds
with Content-Encoding: br when compression was negotiated by curl. These are
native-host measurements, not GEOS transfer or parsing measurements. Wmg3Http
has no Accept-Encoding negotiation or Content-Encoding decoder. The server
therefore delivers the much larger uncompressed representation to this browser.
The user located the remaining delay before the first page text, so image
worker concurrency is not the primary explanation of that initial delay.
