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
semaphore. HostIfCall waits without a timeout. HOSTIF_ASYNC_RESULT_WITHOUT_WAITER
is the existing EC warning for a completion without a registered waiter.

## Browser TLS path

Library/SSL/local.mk defines COMPILE_OPTION_HOST_SERVICE_ONLY; the active
wrappers are the final #else branch of Library/SSL/ssl/ssl_lib.c. The earlier
native/fallback branch is not the normal build. Host-only SSL_connect,
SSL_read and SSL_write decode the operation result from the high word of
HostIfCall's dword return. SSL_read clears ThreadGetError before the host
call, matching the native GEOS_ERROR read path's treatment of stale errors.

Library/Breadbox/UrlDrv/Wmg3Http/WMG3HTTP.goc SocketRecvNice interprets a zero
read plus SE_TIMED_OUT as retryable, up to HTTP_TIMEOUT (90*60 ticks,
wmg3http.goh). sock_getline requests one byte at a time through SocketRecvNice;
for HTTPS each byte reaches SSL_read and HIF_SSL_READ. HTTPGet serializes
entire HTTPS requests with sslSem and does not cache their sockets.
SocketMyClose calls SSL_shutdown before SSL_free and CloseSocket. Thus a host
TLS read, handshake or shutdown that remains pending blocks that caller and
can delay other HTTPS requests. The HostIF SSL calls pass no timeout argument.

Use source breakpoints in the active wrappers (after spawn ssl) to distinguish
handshake and shutdown waits. During a stall, btall shows the waiting threads;
a stack in HostIfCall's ASD_semaphore wait means GEOS is waiting for a host
completion, but does not alone identify why the host has not completed it.
