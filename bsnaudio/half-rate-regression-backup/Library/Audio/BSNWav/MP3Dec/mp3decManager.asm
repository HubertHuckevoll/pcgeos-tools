	;
	; 386 fixed-point MP3 DSP. Algorithm and constants derived from PacketVideo
	; OpenCORE / microMP3; see LICENSE, NOTICE and core/CHANGES.md.
	; All additions/shifts wrap at 32 bits. Q32 truncates each product;
	; Q27..30 add half an LSB to the full product before shifting.
	; Locked input/output segments never survive a public decoder call.
	;

		include	stdapp.def
		include	product.def
		SetGeosConvention
.386

if not SUPPORT_32BIT_DATA_REGS
		.err <MP3Dec requires 386 register preservation in the kernel>
endif

MP3MathCode segment public 'CODE'

	;
	; Fixed C-callable helper: no GEOS movable-resource trampoline per product.
	; Pascal long arguments, word shift; return the long result in DX:AX.
	;
global MP3MULSHIFT:far
MP3MULSHIFT proc far a:dword, b:dword, shift:word
	uses cx
	.enter
		mov	eax, a
		imul	b		; signed full EDX:EAX product
		mov	cx, shift
		cmp	cx, 32
		je	truncate
		push	ebx
		mov	ebx, 1
		dec	cx
		shl	ebx, cl
		add	eax, ebx	; include carry into the high product word
		adc	edx, 0
		inc	cx
		pop	ebx
		shrd	eax, edx, cl
		mov	edx, eax
		shr	edx, 16
		jmp	short done
truncate:
		mov	eax, edx
		shr	edx, 16
done:
	.leave
		ret
MP3MULSHIFT endp
MP3MathCode ends

MP3DspCode segment public 'CODE'

	;
	; EAX input, signed coefficient, EAX result; clobbers EDX only.
	; Never combine products before this truncation/rounding point.
	;
Mp3Product macro coefficient, bits
		mov	edx, coefficient
		imul	edx
if (bits eq 32)
		mov	eax, edx
else
		add	eax, (1 shl (bits-1))
		adc	edx, 0
		shrd	eax, edx, bits
endif
endm

	; Pascal far-pointer entry; the private kernel never calls GEOS.
global PVMP3_DCT_16:far
PVMP3_DCT_16 proc far vecP:fptr, flag:dword
	uses ebx, ecx, edx, si, di, ds, es, fs
	.enter
		lds	si, vecP
		push	word ptr flag
		call	Mp3Dct16
	.leave
		ret
PVMP3_DCT_16 endp

	; Pascal far-pointer entry; the private kernel never calls GEOS.
global PVMP3_MERGE_IN_PLACE_N32:far
PVMP3_MERGE_IN_PLACE_N32 proc far vecP:fptr
	uses ebx, ecx, edx, si, di, ds, es, fs
	.enter
		lds	si, vecP
		call	Mp3Merge32
	.leave
		ret
PVMP3_MERGE_IN_PLACE_N32 endp

	; Pascal far-pointer entry; the private kernel never calls GEOS.
global PVMP3_SPLIT:far
PVMP3_SPLIT proc far vecP:fptr
	uses ebx, ecx, edx, si, di, ds, es, fs
	.enter
		lds	si, vecP
		call	Mp3Split
	.leave
		ret
PVMP3_SPLIT endp

	; Pascal far-pointer entry; the private kernel never calls GEOS.
global PVMP3_DCT_9:far
PVMP3_DCT_9 proc far vecP:fptr
	uses ebx, ecx, edx, si, di, ds, es, fs
	.enter
		lds	si, vecP
		call	Mp3Dct9
	.leave
		ret
PVMP3_DCT_9 endp

	; Pascal far-pointer entry; the private kernel never calls GEOS.
global PVMP3_DCT_6:far
PVMP3_DCT_6 proc far vecP:fptr
	uses ebx, ecx, edx, si, di, ds, es, fs
	.enter
		lds	si, vecP
		call	Mp3Dct6
	.leave
		ret
PVMP3_DCT_6 endp

	; Pascal far-pointer entry; the private kernel never calls GEOS.
global PVMP3_MDCT_18:far
PVMP3_MDCT_18 proc far vecP:fptr, historyP:fptr, windowP:fptr
	uses ebx, ecx, edx, si, di, ds, es, fs
	.enter
		lds	si, vecP
		les	di, historyP
		lfs	bx, windowP
		call	Mp3Mdct18
	.leave
		ret
PVMP3_MDCT_18 endp

	; Pascal far-pointer entry; the private kernel never calls GEOS.
global PVMP3_MDCT_6:far
PVMP3_MDCT_6 proc far vecP:fptr, historyP:fptr
	uses ebx, ecx, edx, si, di, ds, es, fs
	.enter
		lds	si, vecP
		les	di, historyP
		call	Mp3Mdct6
	.leave
		ret
PVMP3_MDCT_6 endp

	; Pascal far-pointer entry; the private kernel never calls GEOS.
global PVMP3_POLYPHASE_FILTER_WINDOW:far
PVMP3_POLYPHASE_FILTER_WINDOW proc far vecP:fptr, pcmP:fptr, channels:dword,
                                      halfRate:dword
	uses ebx, ecx, edx, si, di, ds, es, fs
	.enter
		lds	si, vecP
		les	di, pcmP
		mov	bx, word ptr channels
		shl	bx, 1
		push	word ptr halfRate
		call	Mp3Window
	.leave
		ret
PVMP3_POLYPHASE_FILTER_WINDOW endp

	;
	; One granule of synthesis, after the C equalizer/transposition step.
	; DS stays on the locked circular buffer, ES on the caller's PCM block.
	; BX is the PCM stride in bytes (2 mono, 4 stereo).
	;
global MP3SYNTHESIS386:far
MP3SYNTHESIS386 proc far bufferP:fptr, pcmP:fptr, channels:word, halfRate:word
slots	local	word
	uses ebx, ecx, edx, si, di, ds, es
	.enter
		lds	si, bufferP
		add	si, 544*4
		les	di, pcmP
		mov	bx, channels
		shl	bx, 1
		mov	slots, 18
nextSlot:
		add	si, 16*4
		call	Mp3Split
		push	0
		call	Mp3Dct16
		sub	si, 16*4
		push	1
		call	Mp3Dct16
		call	Mp3Merge32
		push	halfRate
		call	Mp3Window
		mov	ax, bx
		shl	ax, 5
		cmp	halfRate, 0
		je	fullStride
		shr	ax, 1		; Half rate writes 16 samples, not 32.
fullStride:
		add	di, ax
		sub	si, 32*4
		dec	slots
		jnz	nextSlot
	; The two ranges do not overlap: retain the last 480 synthesis samples.
		lds	si, bufferP
		segmov	es, ds
		mov	di, si
		add	di, 576*4
		mov	cx, 480
		cld
		rep movsd
	.leave
		ret
MP3SYNTHESIS386 endp

	;
	; Pair split for DCT32. Q27 covers the first six large cosine terms;
	; the remaining ten use a wrapped doubled input and a Q32 product.

	;
	; Alias butterflies. Boundaries touch disjoint first/last groups of eight
	; samples, so bands can be outermost without changing any dependencies.
	; ECX/EBX retain doubled inputs; all four products truncate separately.
	;
Mp3AliasPair macro slot, signal, alias
		mov	ecx, ds:[si-(slot*4)]
		shl	ecx, 1
		mov	ebx, ds:[di+(slot*4)]
		shl	ebx, 1
		mov	eax, ecx
		mov	edx, signal
		imul	edx
		push	edx
		mov	eax, ebx
		mov	edx, alias
		imul	edx
		pop	eax
		sub	eax, edx
		mov	ds:[si-(slot*4)], eax
		mov	eax, ebx
		mov	edx, signal
		imul	edx
		push	edx
		mov	eax, ecx
		mov	edx, alias
		imul	edx
		pop	eax
		add	eax, edx
		mov	ds:[di+(slot*4)], eax
endm

global MP3ALIAS386:far
MP3ALIAS386 proc far bufferP:fptr, bands:word
remaining	local	word
	uses ebx, ecx, edx, si, di, ds
	.enter
		mov	ax, bands
		tst	ax
		LONG jz done
		mov	remaining, ax
		lds	si, bufferP
		add	si, 17*4
		mov	di, si
		add	di, 4
nextBand:
		Mp3AliasPair	0, 1841452031, -1104871167
		Mp3AliasPair	1, 1893526527, -1013036671
		Mp3AliasPair	2, 2039311999, -672972927
		Mp3AliasPair	3, 2111651967, -390655615
		Mp3AliasPair	4, 2137858175, -203096527
		Mp3AliasPair	5, 2145681023, -87972919
		Mp3AliasPair	6, 2147267199, -30491193
		Mp3AliasPair	7, 2147468927, -7945634
		add	si, 18*4
		add	di, 18*4
		dec	remaining
		LONG jnz nextBand
done:
	.leave
		ret
MP3ALIAS386 endp

	;
Mp3Split proc near
	uses ebx, ecx, edx, si, di
	.enter
		mov	di, si
		sub	di, 4
		mov	bx, offset Mp3Cos32+15*4
		mov	cx, 6
roundedPair:
		mov	eax, ds:[di]
		mov	edx, eax
		add	edx, ds:[si]
		sub	eax, ds:[si]
		mov	ds:[di], edx
		imul	dword ptr cs:[bx]
		add	eax, 4000000h
		adc	edx, 0
		shrd	eax, edx, 27
		mov	ds:[si], eax
		add	si, 4
		sub	di, 4
		sub	bx, 4
		loop	roundedPair
		mov	cx, 10
truncatedPair:
		mov	eax, ds:[di]
		mov	edx, eax
		add	edx, ds:[si]
		sub	eax, ds:[si]
		mov	ds:[di], edx
		shl	eax, 1
		imul	dword ptr cs:[bx]
		mov	ds:[si], edx
		add	si, 4
		sub	di, 4
		sub	bx, 4
		loop	truncatedPair
	.leave
		ret
Mp3Split endp

	;
	; Window products truncate individually before wrapping accumulation.
	; SI and DI walk the two mirrored buffer positions; BX walks CS constants.
	; ECX/EBP retain both sums. Borrow EBP only across the leaf product block,
	; which has no frame references; restore it before output and keep sum2
	; in EDX across clipping sum1. Each sum starts with the 0x20 rounding bias.
	;
Mp3Window proc near halfRate:word
pcmOff	local	word
baseOff	local	word
stride	local	word
sample	local	word
	uses ebx, ecx, edx, si, di
	.enter
		mov	pcmOff, di
		mov	baseOff, si
		mov	stride, bx
		mov	ax, halfRate
		inc	ax
		mov	sample, ax		; Half rate starts at even sample 2.
		mov	bx, offset Mp3SynthWin
		cmp	halfRate, 0
		je	nextSample
		add	bx, 16*4		; Skip coefficients for sample 1.
nextSample:
		mov	si, baseOff
		add	si, 16*4
		mov	di, si
		mov	ax, sample
		shl	ax, 2
		add	si, ax
		sub	di, ax
		mov	ecx, 20h
		push	ebp
		mov	ebp, 20h
		mov	eax, ds:[si+0]
		imul	dword ptr cs:[bx+0]
		add	ecx, edx
		mov	eax, ds:[di+1920]
		imul	dword ptr cs:[bx+0]
		add	ebp, edx
		mov	eax, ds:[si+0]
		imul	dword ptr cs:[bx+4]
		add	ebp, edx
		mov	eax, ds:[di+1920]
		imul	dword ptr cs:[bx+4]
		sub	ecx, edx
		mov	eax, ds:[di+128]
		imul	dword ptr cs:[bx+8]
		add	ecx, edx
		mov	eax, ds:[si+1792]
		imul	dword ptr cs:[bx+8]
		sub	ebp, edx
		mov	eax, ds:[di+128]
		imul	dword ptr cs:[bx+12]
		add	ebp, edx
		mov	eax, ds:[si+1792]
		imul	dword ptr cs:[bx+12]
		add	ecx, edx
		mov	eax, ds:[si+256]
		imul	dword ptr cs:[bx+16]
		add	ecx, edx
		mov	eax, ds:[di+1664]
		imul	dword ptr cs:[bx+16]
		add	ebp, edx
		mov	eax, ds:[si+256]
		imul	dword ptr cs:[bx+20]
		add	ebp, edx
		mov	eax, ds:[di+1664]
		imul	dword ptr cs:[bx+20]
		sub	ecx, edx
		mov	eax, ds:[di+384]
		imul	dword ptr cs:[bx+24]
		add	ecx, edx
		mov	eax, ds:[si+1536]
		imul	dword ptr cs:[bx+24]
		sub	ebp, edx
		mov	eax, ds:[di+384]
		imul	dword ptr cs:[bx+28]
		add	ebp, edx
		mov	eax, ds:[si+1536]
		imul	dword ptr cs:[bx+28]
		add	ecx, edx
		mov	eax, ds:[si+512]
		imul	dword ptr cs:[bx+32]
		add	ecx, edx
		mov	eax, ds:[di+1408]
		imul	dword ptr cs:[bx+32]
		add	ebp, edx
		mov	eax, ds:[si+512]
		imul	dword ptr cs:[bx+36]
		add	ebp, edx
		mov	eax, ds:[di+1408]
		imul	dword ptr cs:[bx+36]
		sub	ecx, edx
		mov	eax, ds:[di+640]
		imul	dword ptr cs:[bx+40]
		add	ecx, edx
		mov	eax, ds:[si+1280]
		imul	dword ptr cs:[bx+40]
		sub	ebp, edx
		mov	eax, ds:[di+640]
		imul	dword ptr cs:[bx+44]
		add	ebp, edx
		mov	eax, ds:[si+1280]
		imul	dword ptr cs:[bx+44]
		add	ecx, edx
		mov	eax, ds:[si+768]
		imul	dword ptr cs:[bx+48]
		add	ecx, edx
		mov	eax, ds:[di+1152]
		imul	dword ptr cs:[bx+48]
		add	ebp, edx
		mov	eax, ds:[si+768]
		imul	dword ptr cs:[bx+52]
		add	ebp, edx
		mov	eax, ds:[di+1152]
		imul	dword ptr cs:[bx+52]
		sub	ecx, edx
		mov	eax, ds:[di+896]
		imul	dword ptr cs:[bx+56]
		add	ecx, edx
		mov	eax, ds:[si+1024]
		imul	dword ptr cs:[bx+56]
		sub	ebp, edx
		mov	eax, ds:[di+896]
		imul	dword ptr cs:[bx+60]
		add	ebp, edx
		mov	eax, ds:[si+1024]
		imul	dword ptr cs:[bx+60]
		add	ecx, edx
		mov	edx, ebp
		pop	ebp
		add	bx, 16*4
		cmp	halfRate, 0
		je	windowStep
		add	bx, 16*4		; Skip the next odd output sample.
windowStep:
		mov	eax, ecx
		call	Mp3ClipPCM
		mov	di, sample
		shl	di, 1
		cmp	halfRate, 0
		je	firstRate
		shr	di, 1			; Pack the even samples contiguously.
firstRate:
		cmp	stride, 2
		je	monoFirst
		shl	di, 1
monoFirst:
		add	di, pcmOff
		mov	es:[di], ax
		mov	eax, edx
		call	Mp3ClipPCM
		mov	di, 32
		sub	di, sample
		shl	di, 1
		cmp	halfRate, 0
		je	secondRate
		shr	di, 1
secondRate:
		cmp	stride, 2
		je	monoSecond
		shl	di, 1
monoSecond:
		add	di, pcmOff
		mov	es:[di], ax
		inc	sample
		mov	ax, halfRate
		add	sample, ax		; Step by two in half-rate mode.
		cmp	sample, 16
		LONG jne nextSample
	; DC and the center sample use the final 24 coefficients.
		mov	si, baseOff
		mov	ecx, 20h
		mov	ebx, 20h
		mov	eax, ds:[si+64]
		imul	dword ptr cs:Mp3SynthWin+960
		add	ecx, edx
		mov	eax, ds:[si+192]
		imul	dword ptr cs:Mp3SynthWin+964
		add	ecx, edx
		mov	eax, ds:[si+128]
		imul	dword ptr cs:Mp3SynthWin+968
		add	ebx, edx
		mov	eax, ds:[si+320]
		imul	dword ptr cs:Mp3SynthWin+972
		add	ecx, edx
		mov	eax, ds:[si+448]
		imul	dword ptr cs:Mp3SynthWin+976
		add	ecx, edx
		mov	eax, ds:[si+384]
		imul	dword ptr cs:Mp3SynthWin+980
		add	ebx, edx
		mov	eax, ds:[si+576]
		imul	dword ptr cs:Mp3SynthWin+984
		add	ecx, edx
		mov	eax, ds:[si+704]
		imul	dword ptr cs:Mp3SynthWin+988
		add	ecx, edx
		mov	eax, ds:[si+640]
		imul	dword ptr cs:Mp3SynthWin+992
		add	ebx, edx
		mov	eax, ds:[si+832]
		imul	dword ptr cs:Mp3SynthWin+996
		add	ecx, edx
		mov	eax, ds:[si+960]
		imul	dword ptr cs:Mp3SynthWin+1000
		add	ecx, edx
		mov	eax, ds:[si+896]
		imul	dword ptr cs:Mp3SynthWin+1004
		add	ebx, edx
		mov	eax, ds:[si+1088]
		imul	dword ptr cs:Mp3SynthWin+1008
		add	ecx, edx
		mov	eax, ds:[si+1216]
		imul	dword ptr cs:Mp3SynthWin+1012
		add	ecx, edx
		mov	eax, ds:[si+1152]
		imul	dword ptr cs:Mp3SynthWin+1016
		add	ebx, edx
		mov	eax, ds:[si+1344]
		imul	dword ptr cs:Mp3SynthWin+1020
		add	ecx, edx
		mov	eax, ds:[si+1472]
		imul	dword ptr cs:Mp3SynthWin+1024
		add	ecx, edx
		mov	eax, ds:[si+1408]
		imul	dword ptr cs:Mp3SynthWin+1028
		add	ebx, edx
		mov	eax, ds:[si+1600]
		imul	dword ptr cs:Mp3SynthWin+1032
		add	ecx, edx
		mov	eax, ds:[si+1728]
		imul	dword ptr cs:Mp3SynthWin+1036
		add	ecx, edx
		mov	eax, ds:[si+1664]
		imul	dword ptr cs:Mp3SynthWin+1040
		add	ebx, edx
		mov	eax, ds:[si+1856]
		imul	dword ptr cs:Mp3SynthWin+1044
		add	ecx, edx
		mov	eax, ds:[si+1984]
		imul	dword ptr cs:Mp3SynthWin+1048
		add	ecx, edx
		mov	eax, ds:[si+1920]
		imul	dword ptr cs:Mp3SynthWin+1052
		add	ebx, edx
		mov	eax, ecx
		call	Mp3ClipPCM
		mov	di, pcmOff
		mov	es:[di], ax
		mov	eax, ebx
		call	Mp3ClipPCM
		mov	di, stride
		shl	di, 4
		cmp	halfRate, 0
		je	centerRate
		shr	di, 1
centerRate:
		add	di, pcmOff
		mov	es:[di], ax
	.leave
		ret
Mp3Window endp

Mp3ClipPCM proc near
		sar	eax, 6
		cmp	eax, -32768
		jge	upper
		mov	eax, -32768
upper:
		cmp	eax, 32767
		jle	done
		mov	eax, 32767
done:
		ret
Mp3ClipPCM endp


	;
	; IMDCT granule driver. DS:SI input, ES:DI overlap, GS:BX short-block
	; scratch. All far pointers refer to locked blocks owned by this instance.
	; The long kernels use FS:BX for windows; no C calls inside band loops.
	;
global PVMP3_IMDCT_SYNTH:far
PVMP3_IMDCT_SYNTH proc far inP:fptr, overlapP:fptr, blockType:dword,
		mixedBand:word, usedLines:dword, scratchP:fptr
band		local	word
activeBands	local	word
	uses ebx, ecx, edx, si, di, ds, es, fs, gs
	.enter
		lds	si, inP
		les	di, overlapP
		lgs	bx, scratchP
		mov	eax, usedLines
		add	eax, 2
		cmp	eax, 32
		jle	bounded
		mov	eax, 32
bounded:
		mov	activeBands, ax
		mov	band, 0
nextBand:
		mov	ax, band
		cmp	ax, activeBands
		LONG jge historyOnly
		cmp	ax, mixedBand
		jl	longBlock
		mov	eax, blockType
		tst	eax
		jz	longBlock
		cmp	eax, 1
		je	startBlock
		cmp	eax, 3
		je	stopBlock
		cmp	eax, 2
		je	shortBlock
		LONG jmp inversion
longBlock:
		mov	bx, offset NORMAL_WIN
		jmp	short longWindow
startBlock:
		mov	bx, offset Mp3StartWin
		jmp	short longWindow
stopBlock:
		mov	bx, offset Mp3StopWin
longWindow:
		segmov	fs, cs
		call	Mp3Mdct18
		LONG jmp inversion
shortBlock:
		mov	bx, word ptr scratchP
	; Transpose the three interleaved short transforms into scratch[0..17].
		mov	cx, 6
		push	si, bx
shortInput:
		mov	eax, ds:[si]
		mov	gs:[bx], eax
		mov	eax, ds:[si+4]
		mov	gs:[bx+24], eax
		mov	eax, ds:[si+8]
		mov	gs:[bx+48], eax
		add	si, 12
		add	bx, 4
		loop	shortInput
		pop	si, bx
		push	ds, es, si, di
		segmov	ds, gs
		segmov	es, gs
		mov	si, bx
		mov	di, bx
		add	di, 18*4
		call	Mp3Mdct6
		add	si, 6*4
		add	di, 6*4
		call	Mp3Mdct6
		add	si, 6*4
		add	di, 6*4
		call	Mp3Mdct6
		pop	ds, es, si, di
	; Short window/overlap slot 0.
		mov	ecx, es:[di+0]
		mov	eax, gs:[bx+96]
		shl	eax, 1
		imul	dword ptr cs:Mp3ShortWin+24
		mov	es:[di+0], edx
		mov	eax, gs:[bx+48]
		shl	eax, 1
		imul	dword ptr cs:Mp3ShortWin+0
		add	es:[di+0], edx
		mov	ds:[si+0], ecx
		mov	eax, gs:[bx+0]
		shl	eax, 1
		imul	dword ptr cs:Mp3ShortWin+0
		add	edx, es:[di+24]
		mov	ds:[si+24], edx
		mov	eax, gs:[bx+120]
		shl	eax, 1
		imul	dword ptr cs:Mp3ShortWin+24
		mov	es:[di+24], edx
		mov	eax, gs:[bx+72]
		shl	eax, 1
		imul	dword ptr cs:Mp3ShortWin+24
		mov	ecx, edx
		mov	eax, gs:[bx+24]
		shl	eax, 1
		imul	dword ptr cs:Mp3ShortWin+0
		add	edx, ecx
		add	edx, es:[di+48]
		mov	ds:[si+48], edx
		mov	dword ptr es:[di+48], 0
	; Short window/overlap slot 1.
		mov	ecx, es:[di+4]
		mov	eax, gs:[bx+100]
		shl	eax, 1
		imul	dword ptr cs:Mp3ShortWin+28
		mov	es:[di+4], edx
		mov	eax, gs:[bx+52]
		shl	eax, 1
		imul	dword ptr cs:Mp3ShortWin+4
		add	es:[di+4], edx
		mov	ds:[si+4], ecx
		mov	eax, gs:[bx+4]
		shl	eax, 1
		imul	dword ptr cs:Mp3ShortWin+4
		add	edx, es:[di+28]
		mov	ds:[si+28], edx
		mov	eax, gs:[bx+124]
		shl	eax, 1
		imul	dword ptr cs:Mp3ShortWin+28
		mov	es:[di+28], edx
		mov	eax, gs:[bx+76]
		shl	eax, 1
		imul	dword ptr cs:Mp3ShortWin+28
		mov	ecx, edx
		mov	eax, gs:[bx+28]
		shl	eax, 1
		imul	dword ptr cs:Mp3ShortWin+4
		add	edx, ecx
		add	edx, es:[di+52]
		mov	ds:[si+52], edx
		mov	dword ptr es:[di+52], 0
	; Short window/overlap slot 2.
		mov	ecx, es:[di+8]
		mov	eax, gs:[bx+104]
		shl	eax, 1
		imul	dword ptr cs:Mp3ShortWin+32
		mov	es:[di+8], edx
		mov	eax, gs:[bx+56]
		shl	eax, 1
		imul	dword ptr cs:Mp3ShortWin+8
		add	es:[di+8], edx
		mov	ds:[si+8], ecx
		mov	eax, gs:[bx+8]
		shl	eax, 1
		imul	dword ptr cs:Mp3ShortWin+8
		add	edx, es:[di+32]
		mov	ds:[si+32], edx
		mov	eax, gs:[bx+128]
		shl	eax, 1
		imul	dword ptr cs:Mp3ShortWin+32
		mov	es:[di+32], edx
		mov	eax, gs:[bx+80]
		shl	eax, 1
		imul	dword ptr cs:Mp3ShortWin+32
		mov	ecx, edx
		mov	eax, gs:[bx+32]
		shl	eax, 1
		imul	dword ptr cs:Mp3ShortWin+8
		add	edx, ecx
		add	edx, es:[di+56]
		mov	ds:[si+56], edx
		mov	dword ptr es:[di+56], 0
	; Short window/overlap slot 3.
		mov	ecx, es:[di+12]
		mov	eax, gs:[bx+108]
		shl	eax, 1
		imul	dword ptr cs:Mp3ShortWin+36
		mov	es:[di+12], edx
		mov	eax, gs:[bx+60]
		shl	eax, 1
		imul	dword ptr cs:Mp3ShortWin+12
		add	es:[di+12], edx
		mov	ds:[si+12], ecx
		mov	eax, gs:[bx+12]
		shl	eax, 1
		imul	dword ptr cs:Mp3ShortWin+12
		add	edx, es:[di+36]
		mov	ds:[si+36], edx
		mov	eax, gs:[bx+132]
		shl	eax, 1
		imul	dword ptr cs:Mp3ShortWin+36
		mov	es:[di+36], edx
		mov	eax, gs:[bx+84]
		shl	eax, 1
		imul	dword ptr cs:Mp3ShortWin+36
		mov	ecx, edx
		mov	eax, gs:[bx+36]
		shl	eax, 1
		imul	dword ptr cs:Mp3ShortWin+12
		add	edx, ecx
		add	edx, es:[di+60]
		mov	ds:[si+60], edx
		mov	dword ptr es:[di+60], 0
	; Short window/overlap slot 4.
		mov	ecx, es:[di+16]
		mov	eax, gs:[bx+112]
		shl	eax, 1
		imul	dword ptr cs:Mp3ShortWin+40
		mov	es:[di+16], edx
		mov	eax, gs:[bx+64]
		shl	eax, 1
		imul	dword ptr cs:Mp3ShortWin+16
		add	es:[di+16], edx
		mov	ds:[si+16], ecx
		mov	eax, gs:[bx+16]
		shl	eax, 1
		imul	dword ptr cs:Mp3ShortWin+16
		add	edx, es:[di+40]
		mov	ds:[si+40], edx
		mov	eax, gs:[bx+136]
		shl	eax, 1
		imul	dword ptr cs:Mp3ShortWin+40
		mov	es:[di+40], edx
		mov	eax, gs:[bx+88]
		shl	eax, 1
		imul	dword ptr cs:Mp3ShortWin+40
		mov	ecx, edx
		mov	eax, gs:[bx+40]
		shl	eax, 1
		imul	dword ptr cs:Mp3ShortWin+16
		add	edx, ecx
		add	edx, es:[di+64]
		mov	ds:[si+64], edx
		mov	dword ptr es:[di+64], 0
	; Short window/overlap slot 5.
		mov	ecx, es:[di+20]
		mov	eax, gs:[bx+116]
		shl	eax, 1
		imul	dword ptr cs:Mp3ShortWin+44
		mov	es:[di+20], edx
		mov	eax, gs:[bx+68]
		shl	eax, 1
		imul	dword ptr cs:Mp3ShortWin+20
		add	es:[di+20], edx
		mov	ds:[si+20], ecx
		mov	eax, gs:[bx+20]
		shl	eax, 1
		imul	dword ptr cs:Mp3ShortWin+20
		add	edx, es:[di+44]
		mov	ds:[si+44], edx
		mov	eax, gs:[bx+140]
		shl	eax, 1
		imul	dword ptr cs:Mp3ShortWin+44
		mov	es:[di+44], edx
		mov	eax, gs:[bx+92]
		shl	eax, 1
		imul	dword ptr cs:Mp3ShortWin+44
		mov	ecx, edx
		mov	eax, gs:[bx+44]
		shl	eax, 1
		imul	dword ptr cs:Mp3ShortWin+20
		add	edx, ecx
		add	edx, es:[di+68]
		mov	ds:[si+68], edx
		mov	dword ptr es:[di+68], 0
inversion:
		test	band, 1
		jz	advanceBand
		push	si
		mov	cx, 9
oddSlot:
		neg	dword ptr ds:[si+4]
		add	si, 8
		loop	oddSlot
		pop	si
		jmp	short advanceBand
historyOnly:
	; Silent spectral bands still emit (and then clear) their saved overlap.
		push	si, di
		mov	cx, 9
copyHistory:
		mov	eax, es:[di]
		mov	ds:[si], eax
		mov	eax, es:[di+4]
		test	band, 1
		jz	evenBand
		neg	eax
evenBand:
		mov	ds:[si+4], eax
		mov	dword ptr es:[di], 0
		mov	dword ptr es:[di+4], 0
		add	si, 8
		add	di, 8
		loop	copyHistory
		pop	si, di
advanceBand:
		add	si, 18*4
		add	di, 18*4
		inc	band
		cmp	band, 32
		LONG jne nextBand
	.leave
		ret
PVMP3_IMDCT_SYNTH endp

	; DS:SI = in-place vector. Each product is shifted before adding.
Mp3Dct16 proc near flag:word
tmp0	local	dword
tmp2	local	dword
tmp3	local	dword
tmp4	local	dword
tmp5	local	dword
tmp_o0	local	dword
tmp_o1	local	dword
tmp_o2	local	dword
tmp_o3	local	dword
tmp_o4	local	dword
tmp_o5	local	dword
tmp_o6	local	dword
tmp_o7	local	dword
itmp_e0	local	dword
itmp_e1	local	dword
itmp_e2	local	dword
	uses ebx, ecx, edx, edi
	; ECX = tmp1, EBX = tmp6, EDI = tmp7 (reference names below).
	.enter
	; tmp_o0 = fxp_mul32_Q32(vec[0] - vec[15], 1078937216L)
		mov	eax, dword ptr ds:[si+0]
		sub	eax, dword ptr ds:[si+60]
		Mp3Product	<1078937216>, 32
		mov	tmp_o0, eax
	; tmp0 = vec[0] + vec[15]
		mov	eax, dword ptr ds:[si+0]
		add	eax, dword ptr ds:[si+60]
		mov	tmp0, eax
	; tmp_o7 = fxp_mul32_Q32((vec[7] - vec[8]) << 3, 1369329152L)
		mov	eax, dword ptr ds:[si+28]
		sub	eax, dword ptr ds:[si+32]
		shl	eax, 3
		Mp3Product	<1369329152>, 32
		mov	tmp_o7, eax
	; tmp7 = vec[7] + vec[8]
		mov	eax, dword ptr ds:[si+28]
		add	eax, dword ptr ds:[si+32]
		mov	edi, eax
	; itmp_e0 = fxp_mul32_Q32(tmp0 - tmp7, 1094777728L)
		mov	eax, tmp0
		sub	eax, edi
		Mp3Product	<1094777728>, 32
		mov	itmp_e0, eax
	; tmp7 = tmp0 + tmp7
		mov	eax, tmp0
		add	eax, edi
		mov	edi, eax
	; tmp_o1 = fxp_mul32_Q32(vec[1] - vec[14], 1122057216L)
		mov	eax, dword ptr ds:[si+4]
		sub	eax, dword ptr ds:[si+56]
		Mp3Product	<1122057216>, 32
		mov	tmp_o1, eax
	; tmp1 = vec[1] + vec[14]
		mov	eax, dword ptr ds:[si+4]
		add	eax, dword ptr ds:[si+56]
		mov	ecx, eax
	; tmp_o6 = fxp_mul32_Q32((vec[6] - vec[9]) << 1, 1849463552L)
		mov	eax, dword ptr ds:[si+24]
		sub	eax, dword ptr ds:[si+36]
		shl	eax, 1
		Mp3Product	<1849463552>, 32
		mov	tmp_o6, eax
	; tmp6 = vec[6] + vec[9]
		mov	eax, dword ptr ds:[si+24]
		add	eax, dword ptr ds:[si+36]
		mov	ebx, eax
	; itmp_e1 = tmp1 + tmp6
		mov	eax, ecx
		add	eax, ebx
		mov	itmp_e1, eax
	; tmp6 = fxp_mul32_Q32(tmp1 - tmp6, 1291378304L)
		mov	eax, ecx
		sub	eax, ebx
		Mp3Product	<1291378304>, 32
		mov	ebx, eax
	; tmp_o2 = fxp_mul32_Q32(vec[2] - vec[13], 1217503104L)
		mov	eax, dword ptr ds:[si+8]
		sub	eax, dword ptr ds:[si+52]
		Mp3Product	<1217503104>, 32
		mov	tmp_o2, eax
	; tmp2 = vec[2] + vec[13]
		mov	eax, dword ptr ds:[si+8]
		add	eax, dword ptr ds:[si+52]
		mov	tmp2, eax
	; tmp_o5 = fxp_mul32_Q32((vec[5] - vec[10]) << 1, 1138893952L)
		mov	eax, dword ptr ds:[si+20]
		sub	eax, dword ptr ds:[si+40]
		shl	eax, 1
		Mp3Product	<1138893952>, 32
		mov	tmp_o5, eax
	; tmp5 = vec[5] + vec[10]
		mov	eax, dword ptr ds:[si+20]
		add	eax, dword ptr ds:[si+40]
		mov	tmp5, eax
	; itmp_e2 = tmp2 + tmp5
		mov	eax, tmp2
		add	eax, tmp5
		mov	itmp_e2, eax
	; tmp5 = fxp_mul32_Q32(tmp2 - tmp5, 1932684160L)
		mov	eax, tmp2
		sub	eax, tmp5
		Mp3Product	<1932684160>, 32
		mov	tmp5, eax
	; tmp_o3 = fxp_mul32_Q32(vec[3] - vec[12], 1389039232L)
		mov	eax, dword ptr ds:[si+12]
		sub	eax, dword ptr ds:[si+48]
		Mp3Product	<1389039232>, 32
		mov	tmp_o3, eax
	; tmp3 = vec[3] + vec[12]
		mov	eax, dword ptr ds:[si+12]
		add	eax, dword ptr ds:[si+48]
		mov	tmp3, eax
	; tmp_o4 = fxp_mul32_Q32(vec[4] - vec[11], 1692549120L)
		mov	eax, dword ptr ds:[si+16]
		sub	eax, dword ptr ds:[si+44]
		Mp3Product	<1692549120>, 32
		mov	tmp_o4, eax
	; tmp4 = vec[4] + vec[11]
		mov	eax, dword ptr ds:[si+16]
		add	eax, dword ptr ds:[si+44]
		mov	tmp4, eax
	; tmp1 = tmp3 + tmp4
		mov	eax, tmp3
		add	eax, tmp4
		mov	ecx, eax
	; tmp4 = fxp_mul32_Q32((tmp3 - tmp4) << 2, 1375954816L)
		mov	eax, tmp3
		sub	eax, tmp4
		shl	eax, 2
		Mp3Product	<1375954816>, 32
		mov	tmp4, eax
	; tmp0 = tmp7 + tmp1
		mov	eax, edi
		add	eax, ecx
		mov	tmp0, eax
	; tmp1 = fxp_mul32_Q32(tmp7 - tmp1, 1162209792L)
		mov	eax, edi
		sub	eax, ecx
		Mp3Product	<1162209792>, 32
		mov	ecx, eax
	; tmp3 = fxp_mul32_Q32((itmp_e1 - itmp_e2) << 1, 1402911360L)
		mov	eax, itmp_e1
		sub	eax, itmp_e2
		shl	eax, 1
		Mp3Product	<1402911360>, 32
		mov	tmp3, eax
	; tmp7 = itmp_e1 + itmp_e2
		mov	eax, itmp_e1
		add	eax, itmp_e2
		mov	edi, eax
	; vec[0] = (tmp0 + tmp7) >> 1
		mov	eax, tmp0
		add	eax, edi
		sar	eax, 1
		mov	dword ptr ds:[si+0], eax
	; vec[8] = fxp_mul32_Q32(tmp0 - tmp7, 1518500224L)
		mov	eax, tmp0
		sub	eax, edi
		Mp3Product	<1518500224>, 32
		mov	dword ptr ds:[si+32], eax
	; tmp0 = fxp_mul32_Q32((tmp1 - tmp3) << 1, 1518500224L)
		mov	eax, ecx
		sub	eax, tmp3
		shl	eax, 1
		Mp3Product	<1518500224>, 32
		mov	tmp0, eax
	; vec[4] = (tmp1 + tmp3) + tmp0
		mov	eax, ecx
		add	eax, tmp3
		add	eax, tmp0
		mov	dword ptr ds:[si+16], eax
	; vec[12] = tmp0
		mov	eax, tmp0
		mov	dword ptr ds:[si+48], eax
	; tmp1 = fxp_mul32_Q32((itmp_e0 - tmp4) << 1, 1162209792L)
		mov	eax, itmp_e0
		sub	eax, tmp4
		shl	eax, 1
		Mp3Product	<1162209792>, 32
		mov	ecx, eax
	; tmp7 = itmp_e0 + tmp4
		mov	eax, itmp_e0
		add	eax, tmp4
		mov	edi, eax
	; tmp3 = fxp_mul32_Q32((tmp6 - tmp5) << 2, 1402911360L)
		mov	eax, ebx
		sub	eax, tmp5
		shl	eax, 2
		Mp3Product	<1402911360>, 32
		mov	tmp3, eax
	; tmp6 += tmp5
		add	ebx, tmp5
	; tmp4 = fxp_mul32_Q32((tmp7 - tmp6) << 1, 1518500224L)
		mov	eax, edi
		sub	eax, ebx
		shl	eax, 1
		Mp3Product	<1518500224>, 32
		mov	tmp4, eax
	; tmp6 += tmp7
		add	ebx, edi
	; tmp7 = fxp_mul32_Q32((tmp1 - tmp3) << 1, 1518500224L)
		mov	eax, ecx
		sub	eax, tmp3
		shl	eax, 1
		Mp3Product	<1518500224>, 32
		mov	edi, eax
	; tmp1 += tmp3 + tmp7
		mov	eax, ecx
		add	eax, tmp3
		add	eax, edi
		mov	ecx, eax
	; vec[2] = tmp1 + tmp6
		add	eax, ebx
		mov	dword ptr ds:[si+8], eax
	; vec[6] = tmp1 + tmp4
		mov	eax, ecx
		add	eax, tmp4
		mov	dword ptr ds:[si+24], eax
	; vec[10] = tmp7 + tmp4
		mov	eax, edi
		add	eax, tmp4
		mov	dword ptr ds:[si+40], eax
	; vec[14] = tmp7
		mov	eax, edi
		mov	dword ptr ds:[si+56], eax
	; tmp1 = fxp_mul32_Q32((tmp_o0 - tmp_o7) << 1, 1094777728L)
		mov	eax, tmp_o0
		sub	eax, tmp_o7
		shl	eax, 1
		Mp3Product	<1094777728>, 32
		mov	ecx, eax
	; tmp7 = tmp_o0 + tmp_o7
		mov	eax, tmp_o0
		add	eax, tmp_o7
		mov	edi, eax
	; tmp6 = tmp_o1 + tmp_o6
		mov	eax, tmp_o1
		add	eax, tmp_o6
		mov	ebx, eax
	; tmp_o1 = fxp_mul32_Q32((tmp_o1 - tmp_o6) << 1, 1291378304L)
		mov	eax, tmp_o1
		sub	eax, tmp_o6
		shl	eax, 1
		Mp3Product	<1291378304>, 32
		mov	tmp_o1, eax
	; tmp5 = tmp_o2 + tmp_o5
		mov	eax, tmp_o2
		add	eax, tmp_o5
		mov	tmp5, eax
	; tmp_o5 = fxp_mul32_Q32((tmp_o2 - tmp_o5) << 1, 1932684160L)
		mov	eax, tmp_o2
		sub	eax, tmp_o5
		shl	eax, 1
		Mp3Product	<1932684160>, 32
		mov	tmp_o5, eax
	; tmp0 = fxp_mul32_Q32((tmp_o3 - tmp_o4) << 3, 1375954816L)
		mov	eax, tmp_o3
		sub	eax, tmp_o4
		shl	eax, 3
		Mp3Product	<1375954816>, 32
		mov	tmp0, eax
	; tmp4 = tmp_o3 + tmp_o4
		mov	eax, tmp_o3
		add	eax, tmp_o4
		mov	tmp4, eax
		cmp	flag, 0
		jne	positive
	; tmp7 = -tmp7
		neg	edi
	; tmp1 = -tmp1
		neg	ecx
	; tmp6 = -tmp6
		neg	ebx
	; tmp_o1 = -tmp_o1
		mov	eax, tmp_o1
		neg	eax
		mov	tmp_o1, eax
	; tmp5 = -tmp5
		mov	eax, tmp5
		neg	eax
		mov	tmp5, eax
	; tmp_o5 = -tmp_o5
		mov	eax, tmp_o5
		neg	eax
		mov	tmp_o5, eax
	; tmp4 = -tmp4
		mov	eax, tmp4
		neg	eax
		mov	tmp4, eax
	; tmp0 = -tmp0
		mov	eax, tmp0
		neg	eax
		mov	tmp0, eax
positive:
	; tmp2 = fxp_mul32_Q32((tmp1 - tmp0) << 1, 1162209792L)
		mov	eax, ecx
		sub	eax, tmp0
		shl	eax, 1
		Mp3Product	<1162209792>, 32
		mov	tmp2, eax
	; tmp0 += tmp1
		mov	eax, tmp0
		add	eax, ecx
		mov	tmp0, eax
	; tmp1 = fxp_mul32_Q32((tmp7 - tmp4) << 1, 1162209792L)
		mov	eax, edi
		sub	eax, tmp4
		shl	eax, 1
		Mp3Product	<1162209792>, 32
		mov	ecx, eax
	; tmp7 += tmp4
		add	edi, tmp4
	; tmp4 = fxp_mul32_Q32((tmp6 - tmp5) << 2, 1402911360L)
		mov	eax, ebx
		sub	eax, tmp5
		shl	eax, 2
		Mp3Product	<1402911360>, 32
		mov	tmp4, eax
	; tmp6 += tmp5
		add	ebx, tmp5
	; tmp5 = fxp_mul32_Q32((tmp_o1 - tmp_o5) << 2, 1402911360L)
		mov	eax, tmp_o1
		sub	eax, tmp_o5
		shl	eax, 2
		Mp3Product	<1402911360>, 32
		mov	tmp5, eax
	; tmp_o1 += tmp_o5
		mov	eax, tmp_o1
		add	eax, tmp_o5
		mov	tmp_o1, eax
	; vec[13] = fxp_mul32_Q32((tmp1 - tmp4) << 1, 1518500224L)
		mov	eax, ecx
		sub	eax, tmp4
		shl	eax, 1
		Mp3Product	<1518500224>, 32
		mov	dword ptr ds:[si+52], eax
	; vec[5] = (tmp1 + tmp4) + vec[13]
		mov	eax, ecx
		add	eax, tmp4
		add	eax, dword ptr ds:[si+52]
		mov	dword ptr ds:[si+20], eax
	; vec[9] = fxp_mul32_Q32((tmp7 - tmp6) << 1, 1518500224L)
		mov	eax, edi
		sub	eax, ebx
		shl	eax, 1
		Mp3Product	<1518500224>, 32
		mov	dword ptr ds:[si+36], eax
	; vec[1] = tmp7 + tmp6
		mov	eax, edi
		add	eax, ebx
		mov	dword ptr ds:[si+4], eax
	; tmp4 = fxp_mul32_Q32((tmp0 - tmp_o1) << 1, 1518500224L)
		mov	eax, tmp0
		sub	eax, tmp_o1
		shl	eax, 1
		Mp3Product	<1518500224>, 32
		mov	tmp4, eax
	; tmp0 += tmp_o1
		mov	eax, tmp0
		add	eax, tmp_o1
		mov	tmp0, eax
	; tmp6 = fxp_mul32_Q32((tmp2 - tmp5) << 1, 1518500224L)
		mov	eax, tmp2
		sub	eax, tmp5
		shl	eax, 1
		Mp3Product	<1518500224>, 32
		mov	ebx, eax
	; tmp2 += tmp5 + tmp6
		mov	eax, tmp2
		add	eax, tmp5
		add	eax, ebx
		mov	tmp2, eax
	; tmp0 += tmp2
		mov	eax, tmp0
		add	eax, tmp2
		mov	tmp0, eax
	; vec[1] += tmp0
		mov	eax, dword ptr ds:[si+4]
		add	eax, tmp0
		mov	dword ptr ds:[si+4], eax
	; vec[3] = tmp0 + vec[5]
		mov	eax, tmp0
		add	eax, dword ptr ds:[si+20]
		mov	dword ptr ds:[si+12], eax
	; tmp2 += tmp4
		mov	eax, tmp2
		add	eax, tmp4
		mov	tmp2, eax
	; vec[5] = tmp2 + vec[5]
		add	eax, dword ptr ds:[si+20]
		mov	dword ptr ds:[si+20], eax
	; vec[7] = tmp2 + vec[9]
		mov	eax, tmp2
		add	eax, dword ptr ds:[si+36]
		mov	dword ptr ds:[si+28], eax
	; tmp4 += tmp6
		mov	eax, tmp4
		add	eax, ebx
		mov	tmp4, eax
	; vec[9] = tmp4 + vec[9]
		add	eax, dword ptr ds:[si+36]
		mov	dword ptr ds:[si+36], eax
	; vec[11] = tmp4 + vec[13]
		mov	eax, tmp4
		add	eax, dword ptr ds:[si+52]
		mov	dword ptr ds:[si+44], eax
	; vec[13] = tmp6 + vec[13]
		mov	eax, ebx
		add	eax, dword ptr ds:[si+52]
		mov	dword ptr ds:[si+52], eax
	; vec[15] = tmp6
		mov	eax, ebx
		mov	dword ptr ds:[si+60], eax
	.leave
		ret
Mp3Dct16 endp

	; DS:SI = in-place vector. Each product is shifted before adding.
Mp3Merge32 proc near
	uses ebx, ecx, edx, edi
	; EBX = temp0, ECX = temp1, EDX = temp2, EDI = temp3 (reference names below).
	.enter
	; temp0 = vec[14]
		mov	eax, dword ptr ds:[si+56]
		mov	ebx, eax
	; vec[14] = vec[7]
		mov	eax, dword ptr ds:[si+28]
		mov	dword ptr ds:[si+56], eax
	; temp1 = vec[12]
		mov	eax, dword ptr ds:[si+48]
		mov	ecx, eax
	; vec[12] = vec[6]
		mov	eax, dword ptr ds:[si+24]
		mov	dword ptr ds:[si+48], eax
	; temp2 = vec[10]
		mov	eax, dword ptr ds:[si+40]
		mov	edx, eax
	; vec[10] = vec[5]
		mov	eax, dword ptr ds:[si+20]
		mov	dword ptr ds:[si+40], eax
	; temp3 = vec[8]
		mov	eax, dword ptr ds:[si+32]
		mov	edi, eax
	; vec[8] = vec[4]
		mov	eax, dword ptr ds:[si+16]
		mov	dword ptr ds:[si+32], eax
	; vec[6] = vec[3]
		mov	eax, dword ptr ds:[si+12]
		mov	dword ptr ds:[si+24], eax
	; vec[4] = vec[2]
		mov	eax, dword ptr ds:[si+8]
		mov	dword ptr ds:[si+16], eax
	; vec[2] = vec[1]
		mov	eax, dword ptr ds:[si+4]
		mov	dword ptr ds:[si+8], eax
	; vec[1] = vec[16] + vec[17]
		mov	eax, dword ptr ds:[si+64]
		add	eax, dword ptr ds:[si+68]
		mov	dword ptr ds:[si+4], eax
	; vec[16] = temp3
		mov	eax, edi
		mov	dword ptr ds:[si+64], eax
	; vec[3] = vec[18] + vec[17]
		mov	eax, dword ptr ds:[si+72]
		add	eax, dword ptr ds:[si+68]
		mov	dword ptr ds:[si+12], eax
	; vec[5] = vec[19] + vec[18]
		mov	eax, dword ptr ds:[si+76]
		add	eax, dword ptr ds:[si+72]
		mov	dword ptr ds:[si+20], eax
	; vec[18] = vec[9]
		mov	eax, dword ptr ds:[si+36]
		mov	dword ptr ds:[si+72], eax
	; vec[7] = vec[20] + vec[19]
		mov	eax, dword ptr ds:[si+80]
		add	eax, dword ptr ds:[si+76]
		mov	dword ptr ds:[si+28], eax
	; vec[9] = vec[21] + vec[20]
		mov	eax, dword ptr ds:[si+84]
		add	eax, dword ptr ds:[si+80]
		mov	dword ptr ds:[si+36], eax
	; vec[20] = temp2
		mov	eax, edx
		mov	dword ptr ds:[si+80], eax
	; temp2 = vec[13]
		mov	eax, dword ptr ds:[si+52]
		mov	edx, eax
	; temp3 = vec[11]
		mov	eax, dword ptr ds:[si+44]
		mov	edi, eax
	; vec[11] = vec[22] + vec[21]
		mov	eax, dword ptr ds:[si+88]
		add	eax, dword ptr ds:[si+84]
		mov	dword ptr ds:[si+44], eax
	; vec[13] = vec[23] + vec[22]
		mov	eax, dword ptr ds:[si+92]
		add	eax, dword ptr ds:[si+88]
		mov	dword ptr ds:[si+52], eax
	; vec[22] = temp3
		mov	eax, edi
		mov	dword ptr ds:[si+88], eax
	; temp3 = vec[15]
		mov	eax, dword ptr ds:[si+60]
		mov	edi, eax
	; vec[15] = vec[24] + vec[23]
		mov	eax, dword ptr ds:[si+96]
		add	eax, dword ptr ds:[si+92]
		mov	dword ptr ds:[si+60], eax
	; vec[17] = vec[25] + vec[24]
		mov	eax, dword ptr ds:[si+100]
		add	eax, dword ptr ds:[si+96]
		mov	dword ptr ds:[si+68], eax
	; vec[19] = vec[26] + vec[25]
		mov	eax, dword ptr ds:[si+104]
		add	eax, dword ptr ds:[si+100]
		mov	dword ptr ds:[si+76], eax
	; vec[21] = vec[27] + vec[26]
		mov	eax, dword ptr ds:[si+108]
		add	eax, dword ptr ds:[si+104]
		mov	dword ptr ds:[si+84], eax
	; vec[23] = vec[28] + vec[27]
		mov	eax, dword ptr ds:[si+112]
		add	eax, dword ptr ds:[si+108]
		mov	dword ptr ds:[si+92], eax
	; vec[24] = temp1
		mov	eax, ecx
		mov	dword ptr ds:[si+96], eax
	; vec[25] = vec[29] + vec[28]
		mov	eax, dword ptr ds:[si+116]
		add	eax, dword ptr ds:[si+112]
		mov	dword ptr ds:[si+100], eax
	; vec[26] = temp2
		mov	eax, edx
		mov	dword ptr ds:[si+104], eax
	; vec[27] = vec[30] + vec[29]
		mov	eax, dword ptr ds:[si+120]
		add	eax, dword ptr ds:[si+116]
		mov	dword ptr ds:[si+108], eax
	; vec[28] = temp0
		mov	eax, ebx
		mov	dword ptr ds:[si+112], eax
	; vec[29] = vec[30] + vec[31]
		mov	eax, dword ptr ds:[si+120]
		add	eax, dword ptr ds:[si+124]
		mov	dword ptr ds:[si+116], eax
	; vec[30] = temp3
		mov	eax, edi
		mov	dword ptr ds:[si+120], eax
	.leave
		ret
Mp3Merge32 endp

	; DS:SI = in-place vector. Each product is shifted before adding.
Mp3Dct9 proc near
sum0	local	dword
sum1	local	dword
sum2	local	dword
sum3	local	dword
odd8	local	dword
odd7	local	dword
odd6	local	dword
odd5	local	dword
	uses ebx, ecx, edx, edi
	.enter
	; Read each input pair once; keep wrapped sums and differences separate.
		mov	eax, ds:[si+32]
		mov	edx, ds:[si+0]
		mov	ecx, eax
		add	eax, edx
		sub	ecx, edx
		mov	sum0, eax
		mov	odd8, ecx
		mov	eax, ds:[si+28]
		mov	edx, ds:[si+4]
		mov	ecx, eax
		add	eax, edx
		sub	ecx, edx
		mov	sum1, eax
		mov	odd7, ecx
		mov	eax, ds:[si+24]
		mov	edx, ds:[si+8]
		mov	ecx, eax
		add	eax, edx
		sub	ecx, edx
		mov	sum2, eax
		mov	odd6, ecx
		mov	eax, ds:[si+20]
		mov	edx, ds:[si+12]
		mov	ecx, eax
		add	eax, edx
		sub	ecx, edx
		mov	sum3, eax
		mov	odd5, ecx
	; R0 = sum0+sum2+sum3, R1 = sum1+vec[4]. The half-shifts precede
	; subtraction, exactly as in the reference; sums wrap before shifting.
		mov	eax, sum0
		add	eax, sum2
		add	eax, sum3
		mov	ecx, sum1
		add	ecx, ds:[si+16]
		mov	edx, eax
		add	edx, ecx
		mov	ds:[si], edx
		sar	eax, 1
		sub	eax, ecx
		mov	ds:[si+24], eax
		mov	ecx, sum1
		sar	ecx, 1
		sub	ecx, ds:[si+16]
		mov	ebx, ecx
		neg	ebx
		mov	edi, ebx
	; ECX = vec[2], EBX = vec[4], EDI = vec[8] until all terms are added.
		mov	eax, sum0
		shl	eax, 1
		Mp3Product	<2017974528>, 32
		add	ecx, eax
		mov	eax, sum0
		shl	eax, 1
		Mp3Product	<1645067904>, 32
		add	ebx, eax
		mov	eax, sum0
		shl	eax, 1
		Mp3Product	<372906624>, 32
		add	edi, eax
		mov	eax, sum2
		shl	eax, 1
		Mp3Product	<-372906624>, 32
		add	ecx, eax
		mov	eax, sum2
		shl	eax, 1
		Mp3Product	<-2017974528>, 32
		add	ebx, eax
		mov	eax, sum2
		shl	eax, 1
		Mp3Product	<1645067904>, 32
		add	edi, eax
		mov	eax, sum3
		shl	eax, 1
		Mp3Product	<-1645067904>, 32
		add	ecx, eax
		mov	eax, sum3
		shl	eax, 1
		Mp3Product	<372906624>, 32
		add	ebx, eax
		mov	eax, sum3
		shl	eax, 1
		Mp3Product	<-2017974528>, 32
		add	edi, eax
		mov	ds:[si+8], ecx
		mov	ds:[si+16], ebx
		mov	ds:[si+32], edi
	; Even sums are finished. Reuse EBX/EDI for two repeatedly used odd inputs.
		mov	ebx, odd5
		mov	edi, odd6
		mov	eax, ebx
		shl	eax, 1
		Mp3Product	<-734482688>, 32
		mov	ecx, eax
		mov	eax, edi
		shl	eax, 1
		Mp3Product	<-1380375936>, 32
		add	ecx, eax
		mov	eax, odd7
		shl	eax, 1
		Mp3Product	<-1859775360>, 32
		add	ecx, eax
		mov	eax, odd8
		shl	eax, 1
		Mp3Product	<-2114858496>, 32
		add	ecx, eax
		mov	ds:[si+4], ecx
		mov	eax, ebx
		shl	eax, 1
		Mp3Product	<-2114858496>, 32
		mov	ecx, eax
		mov	eax, edi
		shl	eax, 1
		Mp3Product	<734482688>, 32
		add	ecx, eax
		mov	eax, odd7
		shl	eax, 1
		Mp3Product	<1859775360>, 32
		add	ecx, eax
		mov	eax, odd8
		shl	eax, 1
		Mp3Product	<-1380375936>, 32
		add	ecx, eax
		mov	ds:[si+20], ecx
		mov	eax, ebx
		shl	eax, 1
		Mp3Product	<1380375936>, 32
		mov	ecx, eax
		mov	eax, edi
		shl	eax, 1
		Mp3Product	<-2114858496>, 32
		add	ecx, eax
		mov	eax, odd7
		shl	eax, 1
		Mp3Product	<1859775360>, 32
		add	ecx, eax
		mov	eax, odd8
		shl	eax, 1
		Mp3Product	<-734482688>, 32
		add	ecx, eax
		mov	ds:[si+28], ecx
	; vec[3] has one product of a wrapped sum, not three separate products.
		mov	eax, ebx
		add	eax, edi
		sub	eax, odd8
		shl	eax, 1
		Mp3Product	<1859775360>, 32
		mov	ds:[si+12], eax
	.leave
		ret
Mp3Dct9 endp

	; DS:SI = in-place vector. Each product is shifted before adding.
Mp3Dct6 proc near
tmp1	local	dword
tmp2	local	dword
tmp5	local	dword
	uses ebx, ecx, edx, edi
	; EBX = tmp0, EDI = tmp3, ECX = tmp4 (reference names below).
	.enter
	; tmp0 = vec[5] + vec[0]
		mov	eax, dword ptr ds:[si+20]
		add	eax, dword ptr ds:[si+0]
		mov	ebx, eax
	; tmp5 = vec[5] - vec[0]
		mov	eax, dword ptr ds:[si+20]
		sub	eax, dword ptr ds:[si+0]
		mov	tmp5, eax
	; tmp1 = vec[4] + vec[1]
		mov	eax, dword ptr ds:[si+16]
		add	eax, dword ptr ds:[si+4]
		mov	tmp1, eax
	; tmp4 = vec[4] - vec[1]
		mov	eax, dword ptr ds:[si+16]
		sub	eax, dword ptr ds:[si+4]
		mov	ecx, eax
	; tmp2 = vec[3] + vec[2]
		mov	eax, dword ptr ds:[si+12]
		add	eax, dword ptr ds:[si+8]
		mov	tmp2, eax
	; tmp3 = vec[3] - vec[2]
		mov	eax, dword ptr ds:[si+12]
		sub	eax, dword ptr ds:[si+8]
		mov	edi, eax
	; vec[0] = tmp0 + tmp2
		mov	eax, ebx
		add	eax, tmp2
		mov	dword ptr ds:[si+0], eax
	; vec[2] = fxp_mul32_Q30(tmp0 - tmp2, cos_pi_6)
		mov	eax, ebx
		sub	eax, tmp2
		Mp3Product	<929887680>, 30
		mov	dword ptr ds:[si+8], eax
	; vec[4] = (vec[0] >> 1) - tmp1
		mov	eax, dword ptr ds:[si+0]
		sar	eax, 1
		sub	eax, tmp1
		mov	dword ptr ds:[si+16], eax
	; vec[0] += tmp1
		mov	eax, dword ptr ds:[si+0]
		add	eax, tmp1
		mov	dword ptr ds:[si+0], eax
	; tmp0 = fxp_mul32_Q30(tmp3, cos_7_pi_12)
		mov	eax, edi
		Mp3Product	<-277904832>, 30
		mov	ebx, eax
	; tmp0 = fxp_mac32_Q30(tmp4, -cos_3_pi_12, tmp0)
		mov	eax, ecx
		Mp3Product	<-759250112>, 30
		add	ebx, eax
	; vec[1] = fxp_mac32_Q30(tmp5, cos_11_pi_12, tmp0)
		mov	eax, tmp5
		Mp3Product	<-1037154944>, 30
		add	eax, ebx
		mov	dword ptr ds:[si+4], eax
	; vec[3] = fxp_mul32_Q30((tmp3 + tmp4) - tmp5, cos_3_pi_12)
		mov	eax, edi
		add	eax, ecx
		sub	eax, tmp5
		Mp3Product	<759250112>, 30
		mov	dword ptr ds:[si+12], eax
	; tmp0 = fxp_mul32_Q30(tmp3, cos_11_pi_12)
		mov	eax, edi
		Mp3Product	<-1037154944>, 30
		mov	ebx, eax
	; tmp0 = fxp_mac32_Q30(tmp4, cos_3_pi_12, tmp0)
		mov	eax, ecx
		Mp3Product	<759250112>, 30
		add	ebx, eax
	; vec[5] = fxp_mac32_Q30(tmp5, cos_7_pi_12, tmp0)
		mov	eax, tmp5
		Mp3Product	<-277904832>, 30
		add	eax, ebx
		mov	dword ptr ds:[si+20], eax
	.leave
		ret
Mp3Dct6 endp

	; DS:SI = in-place vector. Each product is shifted before adding.
Mp3Mdct18 proc near
tmp	local	dword
tmp2	local	dword
tmp3	local	dword
tmp4	local	dword
	uses ebx, ecx, edx
	; ECX = tmp1 (reference names below).
	.enter
	; tmp = fxp_mul32_Q32(vec[0] << 1, 1074764800L)
		mov	eax, dword ptr ds:[si+0]
		shl	eax, 1
		Mp3Product	<1074764800>, 32
		mov	tmp, eax
	; tmp1 = fxp_mul32_Q27(vec[17], 1538509952L)
		mov	eax, dword ptr ds:[si+68]
		Mp3Product	<1538509952>, 27
		mov	ecx, eax
	; vec[0] = tmp + tmp1
		mov	eax, tmp
		add	eax, ecx
		mov	dword ptr ds:[si+0], eax
	; vec[17] = fxp_mul32_Q28(tmp - tmp1, 134730416L)
		mov	eax, tmp
		sub	eax, ecx
		Mp3Product	<134730416>, 28
		mov	dword ptr ds:[si+68], eax
	; tmp = fxp_mul32_Q32(vec[1] << 1, 1083007104L)
		mov	eax, dword ptr ds:[si+4]
		shl	eax, 1
		Mp3Product	<1083007104>, 32
		mov	tmp, eax
	; tmp1 = fxp_mul32_Q27(vec[16], 514140992L)
		mov	eax, dword ptr ds:[si+64]
		Mp3Product	<514140992>, 27
		mov	ecx, eax
	; vec[1] = tmp + tmp1
		mov	eax, tmp
		add	eax, ecx
		mov	dword ptr ds:[si+4], eax
	; vec[16] = fxp_mul32_Q28(tmp - tmp1, 138952416L)
		mov	eax, tmp
		sub	eax, ecx
		Mp3Product	<138952416>, 28
		mov	dword ptr ds:[si+64], eax
	; tmp = fxp_mul32_Q32(vec[2] << 1, 1099811712L)
		mov	eax, dword ptr ds:[si+8]
		shl	eax, 1
		Mp3Product	<1099811712>, 32
		mov	tmp, eax
	; tmp1 = fxp_mul32_Q27(vec[15], 310058144L)
		mov	eax, dword ptr ds:[si+60]
		Mp3Product	<310058144>, 27
		mov	ecx, eax
	; vec[2] = tmp + tmp1
		mov	eax, tmp
		add	eax, ecx
		mov	dword ptr ds:[si+8], eax
	; vec[15] = fxp_mul32_Q28(tmp - tmp1, 148092880L)
		mov	eax, tmp
		sub	eax, ecx
		Mp3Product	<148092880>, 28
		mov	dword ptr ds:[si+60], eax
	; tmp = fxp_mul32_Q32(vec[3] << 1, 1125849600L)
		mov	eax, dword ptr ds:[si+12]
		shl	eax, 1
		Mp3Product	<1125849600>, 32
		mov	tmp, eax
	; tmp1 = fxp_mul32_Q27(vec[14], 223171168L)
		mov	eax, dword ptr ds:[si+56]
		Mp3Product	<223171168>, 27
		mov	ecx, eax
	; vec[3] = tmp + tmp1
		mov	eax, tmp
		add	eax, ecx
		mov	dword ptr ds:[si+12], eax
	; vec[14] = fxp_mul32_Q28(tmp - tmp1, 163849584L)
		mov	eax, tmp
		sub	eax, ecx
		Mp3Product	<163849584>, 28
		mov	dword ptr ds:[si+56], eax
	; tmp = fxp_mul32_Q32(vec[4] << 1, 1162209792L)
		mov	eax, dword ptr ds:[si+16]
		shl	eax, 1
		Mp3Product	<1162209792>, 32
		mov	tmp, eax
	; tmp1 = fxp_mul32_Q27(vec[13], 175363920L)
		mov	eax, dword ptr ds:[si+52]
		Mp3Product	<175363920>, 27
		mov	ecx, eax
	; vec[4] = tmp + tmp1
		mov	eax, tmp
		add	eax, ecx
		mov	dword ptr ds:[si+16], eax
	; vec[13] = fxp_mul32_Q28(tmp - tmp1, 189812528L)
		mov	eax, tmp
		sub	eax, ecx
		Mp3Product	<189812528>, 28
		mov	dword ptr ds:[si+52], eax
	; tmp = fxp_mul32_Q32(vec[5] << 1, 1210517120L)
		mov	eax, dword ptr ds:[si+20]
		shl	eax, 1
		Mp3Product	<1210517120>, 32
		mov	tmp, eax
	; tmp1 = fxp_mul32_Q27(vec[12], 145336368L)
		mov	eax, dword ptr ds:[si+48]
		Mp3Product	<145336368>, 27
		mov	ecx, eax
	; vec[5] = tmp + tmp1
		mov	eax, tmp
		add	eax, ecx
		mov	dword ptr ds:[si+20], eax
	; vec[12] = fxp_mul32_Q28(tmp - tmp1, 234001472L)
		mov	eax, tmp
		sub	eax, ecx
		Mp3Product	<234001472>, 28
		mov	dword ptr ds:[si+48], eax
	; tmp = fxp_mul32_Q32(vec[6] << 1, 1273123968L)
		mov	eax, dword ptr ds:[si+24]
		shl	eax, 1
		Mp3Product	<1273123968>, 32
		mov	tmp, eax
	; tmp1 = fxp_mul32_Q27(vec[11], 124900264L)
		mov	eax, dword ptr ds:[si+44]
		Mp3Product	<124900264>, 27
		mov	ecx, eax
	; vec[6] = tmp + tmp1
		mov	eax, tmp
		add	eax, ecx
		mov	dword ptr ds:[si+24], eax
	; vec[11] = fxp_mul32_Q28(tmp - tmp1, 317586208L)
		mov	eax, tmp
		sub	eax, ecx
		Mp3Product	<317586208>, 28
		mov	dword ptr ds:[si+44], eax
	; tmp = fxp_mul32_Q32(vec[7] << 1, 1353421952L)
		mov	eax, dword ptr ds:[si+28]
		shl	eax, 1
		Mp3Product	<1353421952>, 32
		mov	tmp, eax
	; tmp1 = fxp_mul32_Q27(vec[10], 110238360L)
		mov	eax, dword ptr ds:[si+40]
		Mp3Product	<110238360>, 27
		mov	ecx, eax
	; vec[7] = tmp + tmp1
		mov	eax, tmp
		add	eax, ecx
		mov	dword ptr ds:[si+28], eax
	; vec[10] = fxp_mul32_Q28(tmp - tmp1, 518577472L)
		mov	eax, tmp
		sub	eax, ecx
		Mp3Product	<518577472>, 28
		mov	dword ptr ds:[si+40], eax
	; tmp = fxp_mul32_Q32(vec[8] << 1, 1456360832L)
		mov	eax, dword ptr ds:[si+32]
		shl	eax, 1
		Mp3Product	<1456360832>, 32
		mov	tmp, eax
	; tmp1 = fxp_mul32_Q27(vec[9], 99333680L)
		mov	eax, dword ptr ds:[si+36]
		Mp3Product	<99333680>, 27
		mov	ecx, eax
	; vec[8] = tmp + tmp1
		mov	eax, tmp
		add	eax, ecx
		mov	dword ptr ds:[si+32], eax
	; vec[9] = fxp_mul32_Q28(tmp - tmp1, 1539975680L)
		mov	eax, tmp
		sub	eax, ecx
		Mp3Product	<1539975680>, 28
		mov	dword ptr ds:[si+36], eax
		call	Mp3Dct9
		add	si, 36
		call	Mp3Dct9
		sub	si, 36
	; tmp3 = vec[16]
		mov	eax, dword ptr ds:[si+64]
		mov	tmp3, eax
	; vec[16] = vec[8]
		mov	eax, dword ptr ds:[si+32]
		mov	dword ptr ds:[si+64], eax
	; tmp4 = vec[14]
		mov	eax, dword ptr ds:[si+56]
		mov	tmp4, eax
	; vec[14] = vec[7]
		mov	eax, dword ptr ds:[si+28]
		mov	dword ptr ds:[si+56], eax
	; tmp = vec[12]
		mov	eax, dword ptr ds:[si+48]
		mov	tmp, eax
	; vec[12] = vec[6]
		mov	eax, dword ptr ds:[si+24]
		mov	dword ptr ds:[si+48], eax
	; tmp2 = vec[10]
		mov	eax, dword ptr ds:[si+40]
		mov	tmp2, eax
	; vec[10] = vec[5]
		mov	eax, dword ptr ds:[si+20]
		mov	dword ptr ds:[si+40], eax
	; vec[8] = vec[4]
		mov	eax, dword ptr ds:[si+16]
		mov	dword ptr ds:[si+32], eax
	; vec[6] = vec[3]
		mov	eax, dword ptr ds:[si+12]
		mov	dword ptr ds:[si+24], eax
	; vec[4] = vec[2]
		mov	eax, dword ptr ds:[si+8]
		mov	dword ptr ds:[si+16], eax
	; vec[2] = vec[1]
		mov	eax, dword ptr ds:[si+4]
		mov	dword ptr ds:[si+8], eax
	; vec[1] = vec[9] - tmp2
		mov	eax, dword ptr ds:[si+36]
		sub	eax, tmp2
		mov	dword ptr ds:[si+4], eax
	; vec[3] = vec[11] - tmp2
		mov	eax, dword ptr ds:[si+44]
		sub	eax, tmp2
		mov	dword ptr ds:[si+12], eax
	; vec[5] = vec[11] - tmp
		mov	eax, dword ptr ds:[si+44]
		sub	eax, tmp
		mov	dword ptr ds:[si+20], eax
	; vec[7] = vec[13] - tmp
		mov	eax, dword ptr ds:[si+52]
		sub	eax, tmp
		mov	dword ptr ds:[si+28], eax
	; vec[9] = vec[13] - tmp4
		mov	eax, dword ptr ds:[si+52]
		sub	eax, tmp4
		mov	dword ptr ds:[si+36], eax
	; vec[11] = vec[15] - tmp4
		mov	eax, dword ptr ds:[si+60]
		sub	eax, tmp4
		mov	dword ptr ds:[si+44], eax
	; vec[13] = vec[15] - tmp3
		mov	eax, dword ptr ds:[si+60]
		sub	eax, tmp3
		mov	dword ptr ds:[si+52], eax
	; vec[15] = vec[17] - tmp3
		mov	eax, dword ptr ds:[si+68]
		sub	eax, tmp3
		mov	dword ptr ds:[si+60], eax
	; tmp2 = vec[0]
		mov	eax, dword ptr ds:[si+0]
		mov	tmp2, eax
	; tmp3 = vec[9]
		mov	eax, dword ptr ds:[si+36]
		mov	tmp3, eax
	; tmp = history[0]
		mov	eax, dword ptr es:[di+0]
		mov	tmp, eax
	; tmp4 = vec[0 + 10]
		mov	eax, dword ptr ds:[si+40]
		mov	tmp4, eax
	; vec[0 + 10] = tmp3 + tmp4
		mov	eax, tmp3
		add	eax, tmp4
		mov	dword ptr ds:[si+40], eax
	; tmp1 = vec[0 + 1]
		mov	eax, dword ptr ds:[si+4]
		mov	ecx, eax
	; vec[0] = fxp_mac32_Q32(tmp, vec[0 + 10], window[0])
		mov	eax, dword ptr ds:[si+40]
		Mp3Product	<dword ptr fs:[bx+0]>, 32
		add	eax, tmp
		mov	dword ptr ds:[si+0], eax
	; tmp3 = tmp4
		mov	eax, tmp4
		mov	tmp3, eax
	; history[0] = -(tmp2 + tmp1)
		mov	eax, tmp2
		add	eax, ecx
		neg	eax
		mov	dword ptr es:[di+0], eax
	; tmp2 = tmp1
		mov	eax, ecx
		mov	tmp2, eax
	; tmp = history[1]
		mov	eax, dword ptr es:[di+4]
		mov	tmp, eax
	; tmp4 = vec[1 + 10]
		mov	eax, dword ptr ds:[si+44]
		mov	tmp4, eax
	; vec[1 + 10] = tmp3 + tmp4
		mov	eax, tmp3
		add	eax, tmp4
		mov	dword ptr ds:[si+44], eax
	; tmp1 = vec[1 + 1]
		mov	eax, dword ptr ds:[si+8]
		mov	ecx, eax
	; vec[1] = fxp_mac32_Q32(tmp, vec[1 + 10], window[1])
		mov	eax, dword ptr ds:[si+44]
		Mp3Product	<dword ptr fs:[bx+4]>, 32
		add	eax, tmp
		mov	dword ptr ds:[si+4], eax
	; tmp3 = tmp4
		mov	eax, tmp4
		mov	tmp3, eax
	; history[1] = -(tmp2 + tmp1)
		mov	eax, tmp2
		add	eax, ecx
		neg	eax
		mov	dword ptr es:[di+4], eax
	; tmp2 = tmp1
		mov	eax, ecx
		mov	tmp2, eax
	; tmp = history[2]
		mov	eax, dword ptr es:[di+8]
		mov	tmp, eax
	; tmp4 = vec[2 + 10]
		mov	eax, dword ptr ds:[si+48]
		mov	tmp4, eax
	; vec[2 + 10] = tmp3 + tmp4
		mov	eax, tmp3
		add	eax, tmp4
		mov	dword ptr ds:[si+48], eax
	; tmp1 = vec[2 + 1]
		mov	eax, dword ptr ds:[si+12]
		mov	ecx, eax
	; vec[2] = fxp_mac32_Q32(tmp, vec[2 + 10], window[2])
		mov	eax, dword ptr ds:[si+48]
		Mp3Product	<dword ptr fs:[bx+8]>, 32
		add	eax, tmp
		mov	dword ptr ds:[si+8], eax
	; tmp3 = tmp4
		mov	eax, tmp4
		mov	tmp3, eax
	; history[2] = -(tmp2 + tmp1)
		mov	eax, tmp2
		add	eax, ecx
		neg	eax
		mov	dword ptr es:[di+8], eax
	; tmp2 = tmp1
		mov	eax, ecx
		mov	tmp2, eax
	; tmp = history[3]
		mov	eax, dword ptr es:[di+12]
		mov	tmp, eax
	; tmp4 = vec[3 + 10]
		mov	eax, dword ptr ds:[si+52]
		mov	tmp4, eax
	; vec[3 + 10] = tmp3 + tmp4
		mov	eax, tmp3
		add	eax, tmp4
		mov	dword ptr ds:[si+52], eax
	; tmp1 = vec[3 + 1]
		mov	eax, dword ptr ds:[si+16]
		mov	ecx, eax
	; vec[3] = fxp_mac32_Q32(tmp, vec[3 + 10], window[3])
		mov	eax, dword ptr ds:[si+52]
		Mp3Product	<dword ptr fs:[bx+12]>, 32
		add	eax, tmp
		mov	dword ptr ds:[si+12], eax
	; tmp3 = tmp4
		mov	eax, tmp4
		mov	tmp3, eax
	; history[3] = -(tmp2 + tmp1)
		mov	eax, tmp2
		add	eax, ecx
		neg	eax
		mov	dword ptr es:[di+12], eax
	; tmp2 = tmp1
		mov	eax, ecx
		mov	tmp2, eax
	; tmp = history[4]
		mov	eax, dword ptr es:[di+16]
		mov	tmp, eax
	; tmp4 = vec[4 + 10]
		mov	eax, dword ptr ds:[si+56]
		mov	tmp4, eax
	; vec[4 + 10] = tmp3 + tmp4
		mov	eax, tmp3
		add	eax, tmp4
		mov	dword ptr ds:[si+56], eax
	; tmp1 = vec[4 + 1]
		mov	eax, dword ptr ds:[si+20]
		mov	ecx, eax
	; vec[4] = fxp_mac32_Q32(tmp, vec[4 + 10], window[4])
		mov	eax, dword ptr ds:[si+56]
		Mp3Product	<dword ptr fs:[bx+16]>, 32
		add	eax, tmp
		mov	dword ptr ds:[si+16], eax
	; tmp3 = tmp4
		mov	eax, tmp4
		mov	tmp3, eax
	; history[4] = -(tmp2 + tmp1)
		mov	eax, tmp2
		add	eax, ecx
		neg	eax
		mov	dword ptr es:[di+16], eax
	; tmp2 = tmp1
		mov	eax, ecx
		mov	tmp2, eax
	; tmp = history[5]
		mov	eax, dword ptr es:[di+20]
		mov	tmp, eax
	; tmp4 = vec[5 + 10]
		mov	eax, dword ptr ds:[si+60]
		mov	tmp4, eax
	; vec[5 + 10] = tmp3 + tmp4
		mov	eax, tmp3
		add	eax, tmp4
		mov	dword ptr ds:[si+60], eax
	; tmp1 = vec[5 + 1]
		mov	eax, dword ptr ds:[si+24]
		mov	ecx, eax
	; vec[5] = fxp_mac32_Q32(tmp, vec[5 + 10], window[5])
		mov	eax, dword ptr ds:[si+60]
		Mp3Product	<dword ptr fs:[bx+20]>, 32
		add	eax, tmp
		mov	dword ptr ds:[si+20], eax
	; tmp3 = tmp4
		mov	eax, tmp4
		mov	tmp3, eax
	; history[5] = -(tmp2 + tmp1)
		mov	eax, tmp2
		add	eax, ecx
		neg	eax
		mov	dword ptr es:[di+20], eax
	; tmp2 = tmp1
		mov	eax, ecx
		mov	tmp2, eax
	; tmp = history[6]
		mov	eax, dword ptr es:[di+24]
		mov	tmp, eax
	; tmp4 = vec[16]
		mov	eax, dword ptr ds:[si+64]
		mov	tmp4, eax
	; vec[16] = tmp3 + tmp4
		mov	eax, tmp3
		add	eax, tmp4
		mov	dword ptr ds:[si+64], eax
	; tmp1 = vec[7]
		mov	eax, dword ptr ds:[si+28]
		mov	ecx, eax
	; vec[6] = fxp_mac32_Q32(tmp, vec[16] << 1, window[6])
		mov	eax, dword ptr ds:[si+64]
		shl	eax, 1
		Mp3Product	<dword ptr fs:[bx+24]>, 32
		add	eax, tmp
		mov	dword ptr ds:[si+24], eax
	; tmp = history[7]
		mov	eax, dword ptr es:[di+28]
		mov	tmp, eax
	; history[6] = -(tmp2 + tmp1)
		mov	eax, tmp2
		add	eax, ecx
		neg	eax
		mov	dword ptr es:[di+24], eax
	; history[7] = -(tmp1 + vec[8])
		mov	eax, ecx
		add	eax, dword ptr ds:[si+32]
		neg	eax
		mov	dword ptr es:[di+28], eax
	; tmp1 = history[8]
		mov	eax, dword ptr es:[di+32]
		mov	ecx, eax
	; tmp4 = vec[17] + tmp4
		mov	eax, dword ptr ds:[si+68]
		add	eax, tmp4
		mov	tmp4, eax
	; vec[7] = fxp_mac32_Q32(tmp, tmp4 << 1, window[7])
		shl	eax, 1
		Mp3Product	<dword ptr fs:[bx+28]>, 32
		add	eax, tmp
		mov	dword ptr ds:[si+28], eax
	; history[8] = -(vec[8] + vec[9])
		mov	eax, dword ptr ds:[si+32]
		add	eax, dword ptr ds:[si+36]
		neg	eax
		mov	dword ptr es:[di+32], eax
	; vec[8] = fxp_mac32_Q32(tmp1, vec[17] << 1, window[8])
		mov	eax, dword ptr ds:[si+68]
		shl	eax, 1
		Mp3Product	<dword ptr fs:[bx+32]>, 32
		add	eax, ecx
		mov	dword ptr ds:[si+32], eax
	; tmp = history[9]
		mov	eax, dword ptr es:[di+36]
		mov	tmp, eax
	; tmp1 = history[17]
		mov	eax, dword ptr es:[di+68]
		mov	ecx, eax
	; tmp2 = history[16]
		mov	eax, dword ptr es:[di+64]
		mov	tmp2, eax
	; vec[9] = fxp_mac32_Q32(tmp, vec[17] << 1, window[9])
		mov	eax, dword ptr ds:[si+68]
		shl	eax, 1
		Mp3Product	<dword ptr fs:[bx+36]>, 32
		add	eax, tmp
		mov	dword ptr ds:[si+36], eax
	; vec[17] = fxp_mac32_Q32(tmp1, vec[10] << 1, window[17])
		mov	eax, dword ptr ds:[si+40]
		shl	eax, 1
		Mp3Product	<dword ptr fs:[bx+68]>, 32
		add	eax, ecx
		mov	dword ptr ds:[si+68], eax
	; vec[10] = -vec[16]
		mov	eax, dword ptr ds:[si+64]
		neg	eax
		mov	dword ptr ds:[si+40], eax
	; vec[16] = fxp_mac32_Q32(tmp2, vec[11] << 1, window[16])
		mov	eax, dword ptr ds:[si+44]
		shl	eax, 1
		Mp3Product	<dword ptr fs:[bx+64]>, 32
		add	eax, tmp2
		mov	dword ptr ds:[si+64], eax
	; tmp1 = history[15]
		mov	eax, dword ptr es:[di+60]
		mov	ecx, eax
	; tmp2 = history[14]
		mov	eax, dword ptr es:[di+56]
		mov	tmp2, eax
	; vec[11] = -vec[15]
		mov	eax, dword ptr ds:[si+60]
		neg	eax
		mov	dword ptr ds:[si+44], eax
	; vec[15] = fxp_mac32_Q32(tmp1, vec[12] << 1, window[15])
		mov	eax, dword ptr ds:[si+48]
		shl	eax, 1
		Mp3Product	<dword ptr fs:[bx+60]>, 32
		add	eax, ecx
		mov	dword ptr ds:[si+60], eax
	; vec[12] = -vec[14]
		mov	eax, dword ptr ds:[si+56]
		neg	eax
		mov	dword ptr ds:[si+48], eax
	; vec[14] = fxp_mac32_Q32(tmp2, vec[13] << 1, window[14])
		mov	eax, dword ptr ds:[si+52]
		shl	eax, 1
		Mp3Product	<dword ptr fs:[bx+56]>, 32
		add	eax, tmp2
		mov	dword ptr ds:[si+56], eax
	; tmp = history[13]
		mov	eax, dword ptr es:[di+52]
		mov	tmp, eax
	; tmp1 = history[12]
		mov	eax, dword ptr es:[di+48]
		mov	ecx, eax
	; tmp2 = history[11]
		mov	eax, dword ptr es:[di+44]
		mov	tmp2, eax
	; tmp3 = history[10]
		mov	eax, dword ptr es:[di+40]
		mov	tmp3, eax
	; vec[13] = fxp_mac32_Q32(tmp, vec[12] << 1, window[13])
		mov	eax, dword ptr ds:[si+48]
		shl	eax, 1
		Mp3Product	<dword ptr fs:[bx+52]>, 32
		add	eax, tmp
		mov	dword ptr ds:[si+52], eax
	; vec[12] = fxp_mac32_Q32(tmp1, vec[11] << 1, window[12])
		mov	eax, dword ptr ds:[si+44]
		shl	eax, 1
		Mp3Product	<dword ptr fs:[bx+48]>, 32
		add	eax, ecx
		mov	dword ptr ds:[si+48], eax
	; vec[11] = fxp_mac32_Q32(tmp2, vec[10] << 1, window[11])
		mov	eax, dword ptr ds:[si+40]
		shl	eax, 1
		Mp3Product	<dword ptr fs:[bx+44]>, 32
		add	eax, tmp2
		mov	dword ptr ds:[si+44], eax
	; vec[10] = fxp_mac32_Q32(tmp3, tmp4 << 1, window[10])
		mov	eax, tmp4
		shl	eax, 1
		Mp3Product	<dword ptr fs:[bx+40]>, 32
		add	eax, tmp3
		mov	dword ptr ds:[si+40], eax
	; tmp1 = history[8]
		mov	eax, dword ptr es:[di+32]
		mov	ecx, eax
	; tmp3 = history[7]
		mov	eax, dword ptr es:[di+28]
		mov	tmp3, eax
	; tmp2 = history[1]
		mov	eax, dword ptr es:[di+4]
		mov	tmp2, eax
	; tmp = history[0]
		mov	eax, dword ptr es:[di+0]
		mov	tmp, eax
	; tmp1 <<= 1
		shl	ecx, 1
	; tmp3 <<= 1
		mov	eax, tmp3
		shl	eax, 1
		mov	tmp3, eax
	; history[0] = fxp_mul32_Q32(tmp1, window[18])
		mov	eax, ecx
		Mp3Product	<dword ptr fs:[bx+72]>, 32
		mov	dword ptr es:[di+0], eax
	; history[17] = fxp_mul32_Q32(tmp1, window[35])
		mov	eax, ecx
		Mp3Product	<dword ptr fs:[bx+140]>, 32
		mov	dword ptr es:[di+68], eax
	; history[1] = fxp_mul32_Q32(tmp3, window[19])
		mov	eax, tmp3
		Mp3Product	<dword ptr fs:[bx+76]>, 32
		mov	dword ptr es:[di+4], eax
	; history[16] = fxp_mul32_Q32(tmp3, window[34])
		mov	eax, tmp3
		Mp3Product	<dword ptr fs:[bx+136]>, 32
		mov	dword ptr es:[di+64], eax
	; tmp2 <<= 1
		mov	eax, tmp2
		shl	eax, 1
		mov	tmp2, eax
	; tmp <<= 1
		mov	eax, tmp
		shl	eax, 1
		mov	tmp, eax
	; history[7] = fxp_mul32_Q32(tmp2, window[25])
		mov	eax, tmp2
		Mp3Product	<dword ptr fs:[bx+100]>, 32
		mov	dword ptr es:[di+28], eax
	; history[10] = fxp_mul32_Q32(tmp2, window[28])
		mov	eax, tmp2
		Mp3Product	<dword ptr fs:[bx+112]>, 32
		mov	dword ptr es:[di+40], eax
	; history[8] = fxp_mul32_Q32(tmp, window[26])
		mov	eax, tmp
		Mp3Product	<dword ptr fs:[bx+104]>, 32
		mov	dword ptr es:[di+32], eax
	; history[9] = fxp_mul32_Q32(tmp, window[27])
		mov	eax, tmp
		Mp3Product	<dword ptr fs:[bx+108]>, 32
		mov	dword ptr es:[di+36], eax
	; tmp1 = history[6]
		mov	eax, dword ptr es:[di+24]
		mov	ecx, eax
	; tmp3 = history[5]
		mov	eax, dword ptr es:[di+20]
		mov	tmp3, eax
	; tmp4 = history[4]
		mov	eax, dword ptr es:[di+16]
		mov	tmp4, eax
	; tmp2 = history[3]
		mov	eax, dword ptr es:[di+12]
		mov	tmp2, eax
	; tmp = history[2]
		mov	eax, dword ptr es:[di+8]
		mov	tmp, eax
	; tmp1 <<= 1
		shl	ecx, 1
	; tmp3 <<= 1
		mov	eax, tmp3
		shl	eax, 1
		mov	tmp3, eax
	; tmp4 <<= 1
		mov	eax, tmp4
		shl	eax, 1
		mov	tmp4, eax
	; history[2] = fxp_mul32_Q32(tmp1, window[20])
		mov	eax, ecx
		Mp3Product	<dword ptr fs:[bx+80]>, 32
		mov	dword ptr es:[di+8], eax
	; history[15] = fxp_mul32_Q32(tmp1, window[33])
		mov	eax, ecx
		Mp3Product	<dword ptr fs:[bx+132]>, 32
		mov	dword ptr es:[di+60], eax
	; history[3] = fxp_mul32_Q32(tmp3, window[21])
		mov	eax, tmp3
		Mp3Product	<dword ptr fs:[bx+84]>, 32
		mov	dword ptr es:[di+12], eax
	; history[14] = fxp_mul32_Q32(tmp3, window[32])
		mov	eax, tmp3
		Mp3Product	<dword ptr fs:[bx+128]>, 32
		mov	dword ptr es:[di+56], eax
	; history[4] = fxp_mul32_Q32(tmp4, window[22])
		mov	eax, tmp4
		Mp3Product	<dword ptr fs:[bx+88]>, 32
		mov	dword ptr es:[di+16], eax
	; history[13] = fxp_mul32_Q32(tmp4, window[31])
		mov	eax, tmp4
		Mp3Product	<dword ptr fs:[bx+124]>, 32
		mov	dword ptr es:[di+52], eax
	; tmp2 <<= 1
		mov	eax, tmp2
		shl	eax, 1
		mov	tmp2, eax
	; tmp <<= 1
		mov	eax, tmp
		shl	eax, 1
		mov	tmp, eax
	; history[5] = fxp_mul32_Q32(tmp2, window[23])
		mov	eax, tmp2
		Mp3Product	<dword ptr fs:[bx+92]>, 32
		mov	dword ptr es:[di+20], eax
	; history[12] = fxp_mul32_Q32(tmp2, window[30])
		mov	eax, tmp2
		Mp3Product	<dword ptr fs:[bx+120]>, 32
		mov	dword ptr es:[di+48], eax
	; history[6] = fxp_mul32_Q32(tmp, window[24])
		mov	eax, tmp
		Mp3Product	<dword ptr fs:[bx+96]>, 32
		mov	dword ptr es:[di+24], eax
	; history[11] = fxp_mul32_Q32(tmp, window[29])
		mov	eax, tmp
		Mp3Product	<dword ptr fs:[bx+116]>, 32
		mov	dword ptr es:[di+44], eax
	.leave
		ret
Mp3Mdct18 endp

	; DS:SI = in-place vector. Each product is shifted before adding.
Mp3Mdct6 proc near
	uses ebx, ecx, edx
	; EBX = tmp (reference names below).
	.enter
	; vec[0] = fxp_mul32_Q29(vec[0], 270751776L)
		mov	eax, dword ptr ds:[si+0]
		Mp3Product	<270751776>, 29
		mov	dword ptr ds:[si+0], eax
	; vec[1] = fxp_mul32_Q29(vec[1], 290552448L)
		mov	eax, dword ptr ds:[si+4]
		Mp3Product	<290552448>, 29
		mov	dword ptr ds:[si+4], eax
	; vec[2] = fxp_mul32_Q29(vec[2], 338355488L)
		mov	eax, dword ptr ds:[si+8]
		Mp3Product	<338355488>, 29
		mov	dword ptr ds:[si+8], eax
	; vec[3] = fxp_mul32_Q29(vec[3], 440953440L)
		mov	eax, dword ptr ds:[si+12]
		Mp3Product	<440953440>, 29
		mov	dword ptr ds:[si+12], eax
	; vec[4] = fxp_mul32_Q29(vec[4], 701455680L)
		mov	eax, dword ptr ds:[si+16]
		Mp3Product	<701455680>, 29
		mov	dword ptr ds:[si+16], eax
	; vec[5] = fxp_mul32_Q29(vec[5], 2056563968L)
		mov	eax, dword ptr ds:[si+20]
		Mp3Product	<2056563968>, 29
		mov	dword ptr ds:[si+20], eax
		call	Mp3Dct6
	; tmp = -(vec[0] + vec[1])
		mov	eax, dword ptr ds:[si+0]
		add	eax, dword ptr ds:[si+4]
		neg	eax
		mov	ebx, eax
	; history[3] = tmp
		mov	dword ptr es:[di+12], eax
	; history[2] = tmp
		mov	eax, ebx
		mov	dword ptr es:[di+8], eax
	; tmp = -(vec[1] + vec[2])
		mov	eax, dword ptr ds:[si+4]
		add	eax, dword ptr ds:[si+8]
		neg	eax
		mov	ebx, eax
	; vec[0] = vec[3] + vec[4]
		mov	eax, dword ptr ds:[si+12]
		add	eax, dword ptr ds:[si+16]
		mov	dword ptr ds:[si+0], eax
	; vec[1] = vec[4] + vec[5]
		mov	eax, dword ptr ds:[si+16]
		add	eax, dword ptr ds:[si+20]
		mov	dword ptr ds:[si+4], eax
	; history[4] = tmp
		mov	eax, ebx
		mov	dword ptr es:[di+16], eax
	; history[1] = tmp
		mov	eax, ebx
		mov	dword ptr es:[di+4], eax
	; tmp = -(vec[2] + vec[3])
		mov	eax, dword ptr ds:[si+8]
		add	eax, dword ptr ds:[si+12]
		neg	eax
		mov	ebx, eax
	; vec[4] = -vec[1]
		mov	eax, dword ptr ds:[si+4]
		neg	eax
		mov	dword ptr ds:[si+16], eax
	; history[5] = tmp
		mov	eax, ebx
		mov	dword ptr es:[di+20], eax
	; history[0] = tmp
		mov	eax, ebx
		mov	dword ptr es:[di+0], eax
	; vec[2] = vec[5]
		mov	eax, dword ptr ds:[si+20]
		mov	dword ptr ds:[si+8], eax
	; vec[3] = -vec[5]
		mov	eax, dword ptr ds:[si+20]
		neg	eax
		mov	dword ptr ds:[si+12], eax
	; vec[5] = -vec[0]
		mov	eax, dword ptr ds:[si+0]
		neg	eax
		mov	dword ptr ds:[si+20], eax
	.leave
		ret
Mp3Mdct6 endp

Mp3Cos32 label dword
		 dword	1075036800, 1085490560, 1106914688, 1140405248
		 dword	1187781632, 1251843328, 1336817408, 1449139840
		 dword	1598879488, 1802489600, 130535896, 156959568
		 dword	199201200, 276190688, 457361472, 1367679744

Mp3SynthWin label dword
		 dword	-16384, 425984, 507903, 3407871
		 dword	3571712, 6569979, 8503294, 33800192
		 dword	32768000, 78446592, 90390528, 116883456
		 dword	97632256, 583925760, 644481024, 1228668928
		 dword	-16384, 393216, 573440, 3309567
		 dword	3637247, 5685248, 9519108, 34078720
		 dword	31981572, 72499200, 96321536, 125173760
		 dword	86638592, 553631744, 674627584, 1226440704
		 dword	-16384, 344064, 622592, 3211264
		 dword	3686400, 4816891, 10567681, 34193404
		 dword	31014914, 66568192, 102187008, 132579328
		 dword	74727424, 523419648, 704610304, 1222737920
		 dword	-16384, 311296, 671743, 3112960
		 dword	3719167, 3997691, 11649025, 34160644
		 dword	29851644, 60702716, 107954176, 139132928
		 dword	61865988, 493355008, 734347264, 1217544192
		 dword	-16384, 278527, 737280, 2998271
		 dword	3735552, 3227647, 12763140, 33996804
		 dword	28491772, 54902780, 113623040, 144834560
		 dword	48087044, 463486976, 763772928, 1210908672
		 dword	-16384, 262144, 802816, 2883584
		 dword	3735552, 2506752, 13893629, 33701888
		 dword	26935296, 49217532, 119128072, 149733376
		 dword	33374208, 433881088, 792821760, 1202831360
		 dword	-32768, 229375, 868352, 2768895
		 dword	3719167, 1818624, 15056899, 33292288
		 dword	25149438, 43630596, 124469248, 153829376
		 dword	17727488, 404586496, 821444608, 1193328640
		 dword	-32768, 212991, 950272, 2637824
		 dword	3670016, 1179648, 16236544, 32784388
		 dword	23166978, 38174720, 129597440, 157155328
		 dword	1146885, 375668736, 849559552, 1182416896
		 dword	-32768, 180224, 1032192, 2523136
		 dword	3620863, 589823, 17432574, 32145404
		 dword	20971520, 32866304, 134496256, 159744000
		 dword	-16351230, 347160576, 877101056, 1170145280
		 dword	-32768, 163840, 1114112, 2408448
		 dword	3522560, 32768, 18628604, 31440900
		 dword	18530304, 27721726, 139116544, 161595392
		 dword	-34766848, 319127552, 904036352, 1156546560
		 dword	-49151, 147455, 1196032, 2277376
		 dword	3407871, -475136, 19824634, 30638084
		 dword	15892485, 22740992, 143441920, 162775040
		 dword	-54067196, 291618816, 930250752, 1141620736
		 dword	-49151, 131071, 1294335, 2162687
		 dword	3276800, -933888, 21020676, 29769728
		 dword	13008898, 17940476, 147423232, 163282944
		 dword	-74268672, 264683520, 955727872, 1125449728
		 dword	-65535, 114688, 1392639, 2048000
		 dword	3096575, -1359871, 22216706, 28819456
		 dword	9912323, 13336571, 151044096, 163168256
		 dword	-95322104, 238354432, 980385792, 1108033536
		 dword	-65535, 114688, 1490944, 1916927
		 dword	2899968, -1736704, 23396352, 27820028
		 dword	6586364, 8929280, 154271744, 162463744
		 dword	-117211136, 212664320, 1004158976, 1089437696
		 dword	-81920, 98304, 1589248, 1818624
		 dword	2670592, -2080767, 24543236, 26771454
		 dword	3031044, 4718590, 157040640, 161185792
		 dword	-139919360, 187678720, 1027014656, 1069711360
		 dword	0, 475136, 1703931, 3489792
		 dword	7520251, 25673730, 33374208, 84426760
		 dword	159367168, 107708416, 614219776, 1048887296
		 dword	1229422592, -614219776, -163430400, 107708416
		 dword	-84426752, -737280, 33374208, -7520257
		 dword	2392063, 3489792, -475130, -81920


global NORMAL_WIN:dword
NORMAL_WIN label dword
		dword	187343840, 560605696, 929601088, 1291521536
		dword	1643612800, 1983195136, 1153842176, 1307305216
		dword	1450818944, -1583291008, -1703713280, 1811169280
		dword	1904841216, 1984016128, -2048091520, -2096579712
		dword	-2129111680, -2145439744, 2145439744, 2129111680
		dword	2096579712, 2048091520, 1984016128, 1904841216
		dword	1811169280, 1703713280, 1583291008, 1450818944
		dword	1307305216, 1153842176, 991597568, 821806400
		dword	645760768, 464800544, 280302848, 93671920
Mp3StartWin label dword
		dword	187343840, 560605696, 929601088, 1291521536
		dword	1643612800, 1983195136, 1153842176, 1307305216
		dword	1450818944, -1583291008, -1703713280, 1811169280
		dword	1904841216, 1984016128, -2048091520, -2096579712
		dword	-2129111680, -2145439744, 2147483392, 2147483392
		dword	2147483392, 2147483392, 2147483392, 2147483392
		dword	2129111680, 1984016128, 1703713280, 1307305216
		dword	821806400, 280302848, 0, 0
		dword	0, 0, 0, 0
Mp3StopWin label dword
		dword	0, 0, 0, 0
		dword	0, 0, 280302848, 821806400
		dword	1307305216, -1703713280, -1984016128, 2129111680
		dword	2147483392, 2147483392, -2147483392, -2147483392
		dword	-2147483392, -2147483392, 2145439744, 2129111680
		dword	2096579712, 2048091520, 1984016128, 1904841216
		dword	1811169280, 1703713280, 1583291008, 1450818944
		dword	1307305216, 1153842176, 991597568, 821806400
		dword	645760768, 464800544, 280302848, 93671920
Mp3ShortWin label dword
		dword	280302848, 821806400, 1307305216, 1703713280
		dword	1984016128, 2129111680, 2129111680, 1984016128
		dword	1703713280, 1307305216, 821806400, 280302848

MP3DspCode ends
