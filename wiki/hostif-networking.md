# HostIf networking and TLS

## Call serialization

Library/HostIf/hostif.asm HostIfCall exchanges six request and six response
words through port 38FFh (preceded by a ping read). asyncOpSem must be acquired
before any port access, with request registers preserved. Holding it only
around the last request word allows a caller to block with a partial request
in the shared port. BlockOnLongQueue can dispatch another thread even when
called inside INT_OFF (Library/Kernel/Thread/threadSem.asm).

The mutex also covers pending-result slot registration. HIF_PENDING returns
the slot in AH; HostIfCall stores a pointer to AsyncSlotData on the caller's
stack before releasing asyncOpSem. HostIfProcEventProcess fetches completions
through HostIfCall/HIF_GET_EVENT, fills that structure and signals its
semaphore. HostIfCall waits without an operation timeout. A waiter must not abandon its
stack slot while the host can still complete into it.
HOSTIF_ASYNC_RESULT_WITHOUT_WAITER is the EC warning for a completion without
a registered waiter.

## Browser TLS path

Library/SSL/local.mk defines COMPILE_OPTION_HOST_SERVICE_ONLY; the active
wrappers are the final #else branch of Library/SSL/ssl/ssl_lib.c. The earlier
native/fallback branch is not the normal build. Host-only SSL_connect,
SSL_read and SSL_write decode the operation result from the high word of
HostIfCall's dword return. SSL_read clears ThreadGetError before the host
call, matching the native GEOS_ERROR read path's treatment of stale errors.

Library/Breadbox/UrlDrv/Wmg3Http/WMG3HTTP.goc SocketRecvNice interprets a zero
read plus SE_TIMED_OUT as retryable, up to HTTP_TIMEOUT (90*60 ticks,
wmg3http.goh). sock_getline requests one byte at a time through SocketRecvNice.
For HTTPS, SocketRecvNice keeps a BUFFER_SIZE (2048-byte) read-ahead buffer in
T_HTTPConnection (wmg3con.goh), shared by header, chunk and body reads and
cleared by SocketMyClose. Thus SSL_read/HIF_SSL_READ is needed only when the
buffer is empty, rather than for every header/chunk byte. HTTPGet serializes
entire HTTPS requests with sslSem and does not cache their sockets. It releases
the connection lock while acquiring sslSem, so a waiting HTTPS request does not
hold that lock against ConnectionFind/URLDrvAbort. Its long-URL allocation
failure also goes through common cleanup to release both resources.
SocketMyClose calls SSL_shutdown before SSL_free and CloseSocket. Thus a host
TLS read, handshake or shutdown that remains pending blocks that caller and
can delay other HTTPS requests. The HostIF SSL calls pass no timeout argument.

Use source breakpoints in the active wrappers (after spawn ssl) to distinguish
handshake and shutdown waits. During a stall, btall shows the waiting threads;
a stack in HostIfCall's ASD_semaphore wait means GEOS is waiting for a host
completion, but does not alone identify why the host has not completed it.

## HTTP framing and protected-mode overhead

HTTPGet drains ignored response bodies only for reusable plain HTTP sockets.
The SocketGetBlock noWait argument reaches SocketRecv's short timeout, but
SSL_read has no corresponding timeout parameter. Draining a persistent HTTPS
redirect or 304 response to EOF can therefore wait on a server that is keeping
the connection open. HTTPS requests explicitly send Connection: close because
their sockets are never reused. Skipping the drain is still necessary: a
server can ignore that header, and a 304 response has no body.

Byte-at-a-time host operations also carry scheduler overhead. In protected
mode, DispatchSI/RecoverFromPartialBlock in
Library/Kernel/Thread/threadThread.asm uses SafePop for GS, FS, ES and DS.
Include/geos.def:SafePop calls GPMISelectorGetLimitFar; the loader's
Loader32/gpmi.asm:GPMISelectorGetLimit calls GPMIGetDescriptor, which uses
DPMI int 31h/000Bh. Thus each resumed blocked thread performs four descriptor
queries. The PM merge 260eccbb4 added these SafePop calls. The browser change
690d15fc7 independently changed the product numConn default from one to two
and made import worker counts independent; neither change removes the HTTP
driver's global sslSem serialization.

## TLS socket binding

Host-only SSL_set_fd (Library/SSL/ssl/ssl_lib.c) forwards the socket's
SO_CONNECTION_HDL to HIF_SSL_SET_FD. That option reads
SSI_connection.CE_link (Library/Socket/socketApi.asm:connectionHandler),
which is assigned during SocketDataConnect
(Library/Socket/socketConnection.asm). Therefore HTTPGet must bind TLS after
SocketConnect succeeds; the old native SSL placement before SocketConnect
passes a zero host connection handle. HTTPGet checks the post-connect binding
result before the TLS handshake.

## SSL pointer representation

Host-only SSL_read, SSL_write and SSL_set_tlsext_host_name pass raw far
pointers in HostIfCall's data2 (Library/SSL/ssl/ssl_lib.c). HOSTIFCALL and
HostIfCall forward the offset and segment/selector words without conversion
(Library/HostIf/hostif.asm). In PM these are selector:offset pointers; the host
must resolve the selector or the guest must supply suitable DOS-memory buffers.
The normal HstTCPIP socket send path similarly forwards ES and SI as pointer
words (Driver/Socket/HstTCPIP/tcpipEntry.asm:TcpipSendData).

The task report ../hostif-ssl-static-analysis.md records a separate static
inspection of the installed Basebox binary, with binary identity, addresses
and reproduction commands. Its host-side findings are specific to that binary.

## Initial text versus image loading

BbxBrow does not stream the top-level HTML into its parser. URLFetchChildThread
calls LoadURLToFile and then queues its completion acknowledgement
(Appl/Breadbox/BbxBrow/urlfetch/URLFETCH.goc). MSG_URL_FRAME_URL_FETCHED in
urlframe/FRFETCH.goc subsequently calls ParseFrameHTML/ParseAnyFile with
HFTT_SOURCE_FILENAME. The initial display therefore waits for document fetch
and parsing. Increasing fetch/import worker counts does not parallelize the
parsing of that single initial HTML document.

The fetchWhileImport default is FALSE (init/INIT.goc). When false,
URLFetchChildThread waits on LPD_importSync after a streamed image fetch before
accepting its next request (urlfetch/URLFETCH.goc). This is a later image-loading
cost, distinct from the initial HTML download and parsing.
