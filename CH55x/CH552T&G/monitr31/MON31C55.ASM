;  MONITOR31 For CH552T/G                                   2023.05.03
;   Internal Clock 24MHz, Fsys 6MHz(Defalt)
;   Use UART0, Clock Generater Timer1
;     2023.05.05 CH552 add system clock change fuction
;
;=======================================================================
; Program MONITR31.ASM with DEF31.ASM and DECLARES.ASM
; A low-level monitor for the 8051 for the TASM assembler
; Copyright 1989 Ron Stubbers 
; This program is provided for personal, private use only.
; Commercial use in whole or in part without express written permission of
; the author is prohibited.  
; No warranty is made as to the suitability of the program for any 
; particular use.  
;
;_______________________________________________________________________
; REVISION HISTORY
;3/10/90 Robert Gallahan, 11300 Melody Dr.#307, Northglenn CO 80234
; 1.1	Syntax modified for PSEUDOSAM ASSEMBLER, include files not required.
;	Clean up user display, add interrupt support, ASCII dump display,
;	register & internal memory dump
;_______________________________________________________________________
;
	.equ	version,'1'
	.equ	revision,'5'
	.equ	rambase,h'8000	;beginning of program ram area
	.equ	stkbase,h'40	;bottom of stack area
	.equ	sfrbase,h'80	;sfr area start address
	.equ	esc,h'1b	;escape character
	.equ	bs,h'08		;backspace character
	.equ	toupper,h'5f	;convert mask for lowercase character to upper

	.equ	h07,h'07
	.equ	h0f,h'0f
	.equ	h20,h'20
	.equ	h52,h'52
	.equ	h7f,h'7f
	.equ	h80,h'80
	.equ	hf0,h'f0
	.equ	hff,h'ff
	.equ	hf8,h'f8
	.equ	h55,h'55	; CH552 Keyword-1 for Enter safe mode
	.equ	haa,h'aa	; CH552 Keyword-2 for Enter safe mode

	.equ	ar0,0
	.equ	ar1,1
	.equ	ar2,2
	.equ	ar3,3
	.equ	ar4,4
	.equ	ar5,5
	.equ	ar6,6
	.equ	ar7,7

	.org 	0		;then set rest of prog at 00h
;0000 is the processor's reset vector
         ajmp 	INIT
;
;Interrupt Service Routines
;0003 external INT0 (p3.2)
	.org 3
;	ljmp	RAMBASE+3
;
;000B timer 0 
	.org	h'000b
;	ljmp	RAMBASE+h'0b
;
;0013 external INT1 (p3.3)
	.org	h'0013
;	ljmp	RAMBASE+h'13
;
;001b timer 1
	.org	h'001b
;	ljmp	RAMBASE+h'1b
;
;0023 internal serial interface RI and TI
	.org	h'0023
;	ljmp	RAMBASE+h'23

	.org	h'0023+3
;------------------------------------------------------------------------
;		***** MAINLINE CODE STARTS HERE *****
;------------------------------------------------------------------------
INIT:	mov	a,#STKBASE		;set stack pointer
	mov	sp,a
;	CLR	P1.5	;*** SHUT OFF BELL FOR WYSE 50
	clr	a
	mov	psw,a			;set register bank zero
;
;initalize interrupt vectors in RAM
;	mov	a,#h'32			;"RETI"  instruction
;	mov	dptr,#RAMBASE+h'03	;INT0 vector in RAM
;	movx	@dptr,a
;	mov	dptr,#RAMBASE+h'0B	;timer 0 vector in RAM
;	movx	@dptr,a
;	mov	dptr,#RAMBASE+h'13	;INT1 vector in RAM
;	movx	@dptr,a
;	mov	dptr,#RAMBASE+h'1b	;timer 1 vector in RAM
;	movx	@dptr,a
;	mov	dptr,#RAMBASE+h'23	;serial RI/TI vector in RAM
;	movx	@dptr,a
;
;initialize CPU's serial port
	mov	scon,#h52
	mov	tmod,#h20
	orl	pcon,#h80		; Set Pcon.7 ( Smod:double baud rate bit )	
;	-- CH552 ---
	.equ	t2mod,h'c9		; t2mod define
	orl		t2mod,#h'a0		; Set bTMR_CLK, bT1_CLK ( Set Timer1 Clock, MAX Speed = Fsys = 6MHz )
;	------------
;
	acall	Set_Baud	; set Serial Port Baud Rate
;
;------------------------------------------------------------------------
; Main Menu
;------------------------------------------------------------------------
MENU:
	acall	dsp_menu
getsel:
	push	ar2
	push	ar3
	clr	F0		; set echoback on

	acall	xstring
	.db	"\n:"		;prompt
	.db	esc

	acall 	chr_in
	anl	a,#toupper	;upcase, strip parity
	mov	r2,a		; input command
	mov	r3,#00		; loop counter
	mov	dptr,#cmdtbl
menu01:	mov	a,r3
	movc	a,@a+dptr	; get one of menutbl
	jnz	menu02		; Table End ?
	pop	ar3
	pop	ar2
	ajmp	MENU		; yes, input command error

menu02:	cjne	a,ar2,menu03	; acc = r2 (input command) ?
	sjmp	menu04
menu03:	inc	r3		; next table entry
	sjmp	menu01

menu04:	mov	dptr,#jumptbl
	mov	a,r3		; cmdtbl index
	add	a,r3		; a = a * 2
	mov	r3,a		; save jump table high-byte index
	movc	a,@a+dptr	; get high-byte of terget addr
	mov	r2,a		; save high-byte
	mov	a,r3		; high-byte index
	inc	a		; low-byte index
	movc	a,@a+dptr	; get low-byte of terget addr
	mov	dph,r2
	mov	dpl,a

	pop	ar3
	pop	ar2
	clr	a
	jmp	@a+dptr		; jump terget routine

cmdtbl:
	.db	"D"		; DUMP External RAM
	.db	"P"		; DUMP PROGRAM ROM
	.db	"C"		; CLEAR External RAM
;	.db	"R"		; READ Internal RAM (00-FF)
	.db	"W"		; CLEAR Internal RAM (00-FF)
	.db	"S"		; SET Value in External RAM
	.db	"T"		; SET Test Pattern in External RAM
	.db	"J"		; JUMP to Address
	.db	"L"		; LOAD Hex File to RAM
;	.db	"I"		; DIRECT READ Internal RAM (00-7F) & SFR's
	.db	"V"		; SET Value in Internal RAM (00-7F) & SFR's
	.db	"X"		; Display REGISTER & internal RAM
	.db	"Y"		; Display All SFR's AREA
	.db	"Z"		; Display EXT-RAM by 8-bit addresss mode
	.db	"H"		; CH552 System clock selection
	.db	0		; end of command table

jumptbl:
	.dw	dump_eram
	.dw	dump_prom
	.dw	c_run
;	.dw	r_run
	.dw	w_run
	.dw	s_run
	.dw	t_run
	.dw	j_run
	.dw	load_hex
;	.dw	i_run
	.dw	v_run
	.dw	disp_reg
	.dw	disp_sfr
	.dw	disp_page
	.dw	ch552_clk
	.dw	0
;
;------------------------------------------------------------------------
; Set Serial Port Baud Rate
;------------------------------------------------------------------------
Set_Baud:
	mov	r1,#0		; Baud Rate Table Index = 0
setb01:
	mov	dptr,#Baud_Tbl	; Baud Rate Table Addr
	mov	a,r1		; Baud Rate Table Index
	movc	a,@a+dptr	; Fetch Baud Rate Table
	inc	r1
	jz	setb02		; Table End, Use Last Speed

	clr	tr1		; stop timer for serial port
	mov	th1,a		; Set Timer1 Value
;	orl	pcon,#h80	; Set Pcon.7 ( Smod:double baud rate bit )
	setb	tr1		; start timer for serial port

	acall	xstring		; put test message
	.db	"\n\rSpeed OK y/n ?"
	.db	esc

	jnb	ri,*		; get anser from terminal
	clr	ri
	mov	a,sbuf
	anl	a,#h7f		; Clear Parity

	cjne	a,#'y',setb01	; Ok?, Test Next Speed

setb02:	ret
;
Baud_Tbl:
;	TH1 = 256 - ( X'TAL-Freq / 192 / BaudRate ) : When SMOD = 1
;	.db	248		; 248 : 19.2kbps@29.4912MHz
;	.db	250		; 250 : 19.2kbps@22.1184MHz
;	.db	251		; 251 : 19.2Kbps@18.4320MHz
;	.db	252		; 252 : 19.2Kbps@14.7456MHz
;	.db	253		; 253 : 19.2Kbps@11.0592MHz
;	.db	0		; end of table
;
;	-- CH552 --
;	TH1 = 256 - ( Fsys/16/Baud Rate ) : When Fsys = 6MHz, SMOD=1,bTMR_CLK=1,bT1_CLK=1
	.db	236		; 236 : 18.75Kbps
	.db	237		; 237 : 19.737Kbps
	.db	217		; 217 :  9.615Kbps
	.db	178		; 178 :  4.808Kbps
	.db	0		; end of table
;
;------------------------------------------------------------------------
; Display program ROM (hex and ASCII)
;------------------------------------------------------------------------
dump_prom:
	mov	r2,#0		; Set Flag = 0
	acall	memdump		; Call Dump Routine
	ajmp	getsel		; return to command mode
;
;------------------------------------------------------------------------
; Display external data memory (hex and ASCII)
;------------------------------------------------------------------------
dump_eram:
	mov	r2,#1		; Set Flag = 1
	acall	memdump		; Call Dump Routine
	ajmp	getsel		; return to command mode
;
;------------------------------------------------------------------------
; Common Memory Dump Routine
memdump:
	acall	askaddr		; ask start/end address to terminal

; get dump size
	clr	c		; (r6,r7) = (r6,r7) - (r4,r5)
	mov	a,r7
	subb	a,r5
	mov	r7,a
	mov	a,r6
	subb	a,r4
	mov	r6,a

	anl	a,#hf0
	jz	memd01		; dump size < 0x1000 ok
	acall	xstring
	.db	"\n\rrMax dump size 0FFFH\n\r"
	.db	esc
	mov	r1,#hff
	sjmp	memd02

memd01:
; get row counter number	; r1 = (r6,r7) / 16 : shift right 4bit
	mov	a,r6		; dump size high byte
	swap	a		; shift 7-4bit << 3-0bit
	anl	a,#hf0		; clear low 4-bit
	mov	r6,a
	mov	a,r7		; dump size low byte
	swap	a		; shift 7-4bit >> 3-0bit
	anl	a,#h0f		; clear high 4-bit
	orl	a,r6		; acc = (r6.3-0,r7.7-4)
	mov	r1,a		; r1 = row loop counter
memd02:
	mov	dph,r4		; dump start address
	mov	dpl,r5
	acall	lfcr		; go to next line to start
	inc	r1		; make sure at least one

; outer loop - put line loop
memd03:
	mov	r0,#16		; set up byte counter
	mov	a,dph		; at start of line output addr
	acall	wrbyte
	mov	a,dpl
	acall	wrbyte
	acall	putspace	;and space to make it tidy
	push	dpl
	push	dph		;save line start address on stack

; inner loop - put 16-byte one-line
memd04:
	acall	getmemory	;output row one byte at a time
	acall	wrbyte
	acall	putspace
	inc	dptr
	djnz	r0,memd04	;end of byte loop
;
	pop	dph
	pop	dpl		;restore line start address
	acall	dascii		;display ascii equivalents
	acall	lfcr		;go to next line
	djnz	r1,memd03	;loop through next line if req'd
	acall	lfcr		;drop down a line

	ret			; return to main routine
;
;-------------------------------------------------------------------
dascii: mov	r0,#16		;initalize loop count
	acall	putspace	;put out couple of spaces
	acall	chr_out
dasci1:	acall	getmemory	;get the byte
	anl	a,#h7f		;mask parity bit
	clr	c		;clear carry
	subb	a,#' '		;subtract ascii space
	jnc	dasci2		;jump if displayable
	mov	a,#('.'-' ')	;load "." minus space if not displayable
dasci2:	add	a,#' '		;make it ascii again
	acall	chr_out		;print it
	inc	dptr		;bump data pointer
	djnz	r0,dasci1	;and loop 'till done
	ret			;return and do next line
;
;-------------------------------------------------------------------
getmemory:
	mov	a,r2
	jz	getm01
	movx	a,@dptr		; get the byte from External Data Memory
	ret
getm01:
	movc	a,@a+dptr	; get the byte from Program Memory
	ret	
;
;-------------------------------------------------------------------
; Internal subroutine askaddr
; ask start/end address to terminal
;   start address = (r4,r5), end address = (r6,r7)
askaddr:
	acall	xstring		;ask for start address
	.db	"\n\rENTER 2-BYTE START ADDRESS\n\r"
	.db	esc
	acall	readhex
	mov	r4,a
	acall	readhex
	anl	a,#hf0		; start address 16-byte boundary
	mov	r5,a		; (r4,r5) = start address

	acall	xstring		; ask for end address
	.db	"\n\rENTER END ADDRESS\n\r"
	.db	esc
	acall	readhex
	mov	r6,a
	acall	readhex
	orl	a,#h0f		; end address 16-byte boundary
	mov	r7,a		; (r6,r7) = end address

	ret
;
;------------------------------------------------------------------------
; Clear external data memory by fill data
;------------------------------------------------------------------------
c_run:
	acall	askaddr		; ask start/end address to terminal

	acall	xstring
	.db 	"\n\rENTER FILL DATA\n\r"
	.db 	esc
	acall	readhex
	mov	r3,a		;put fill data to r3

	mov	dph,r4		;set start address to dptr
	mov	dpl,r5
clrloop:
	mov	a,r3		;set fill data
	movx	@dptr,a		;clear ext-memory

	mov	a,r6		;dptr = end address ?
	xrl	a,dph		;16bit compare
	mov	b,a
	mov	a,r7
	xrl	a,dpl
	orl	a,b
	jz	clrloope	;loop end
	inc	dptr
	sjmp	clrloop

clrloope:
	acall	lfcr
	ajmp	getsel		;return to command mode
;
;------------------------------------------------------------------------
; Clear internal data memory by fill data
;------------------------------------------------------------------------
w_run:	acall	xstring		;ASK FOR START ADDRESS
	.db	"\n\rENTER START INT-MEMORY ADDRESS\n\r"
	.db	esc
	acall	readhex		;put start addr to r4
	mov	r4,a

	acall	xstring
	.db 	"\n\rENTER END ADDRESS\n\r"
	.db 	esc
	acall	readhex
	mov	r5,a		;put end address to r5

	acall	xstring
	.db 	"\n\rENTER FILL DATA\n\r"
	.db 	esc
	acall	readhex
	mov	r3,a		;put fill data to r3

	mov	a,r4
	mov	r0,a		;set start address to r0
	clr	c		;clear carry flag
wimloop:
	mov	a,r3		;set fill data
	mov	@r0,a		;clear int-memory

	mov	a,r5		;r0 = end address ?
	subb	a,r0		;8bit compare
	jz	wimloope	;loop end
	inc	r0
	sjmp	wimloop

wimloope:
	acall	lfcr
	ajmp	getsel		;return to command mode
;
;------------------------------------------------------------------------
; Read Internal RAM
;------------------------------------------------------------------------
;r_run:	acall	xstring
;	.db	"\n\rENTER INT-MEMORY ADDRESS\n\r"
;	.db	esc
;	acall	readhex		;get address byte
;	mov	b,r0		; save r0
;	mov	r0,a		;put the address into a register
;	acall	putspace		;put a space between reg addr and data
;	cjne	r0,#00,rrun01
;	mov	a,b		; recover r0
;	sjmp	rrun02
;rrun01:	mov	a,@r0		;use register indirect to get data
;rrun02:	acall	wrbyte		;and send it to the console
;	acall	lfcr
;	ajmp	getsel
;
;------------------------------------------------------------------------
; Set Value in Ext-Memory
;------------------------------------------------------------------------
s_run:	acall	XSTRING
	.db	"\n\rENTER FIRST ADDRESS TO SET\n\r"
	.db	esc
	acall	readhex		;first get the two address bytes
	mov	r4,a		;put start address to r4,r5
	acall	readhex
	mov	r5,a

	acall	xstring
	.db	"\n\rENTER SET BYTE NUMBER (1-9)\n\r"
	.db	esc
	acall	chr_in		;get one char
	clr	c
	subb	a,#'0'		;subtract 0x30
	jz	svlext		;If zero goto exit

	mov	r3,a		;change loop number
	acall	lfcr

svlloop:
	mov	a,r4		;put current address
	acall	wrbyte
	mov	a,r5
	acall	wrbyte
	acall	putspace		;put space

	mov	dph,r4
	mov	dpl,r5
	movx	a,@dptr		;get current value
	acall	wrbyte		;put current value
	acall	xstring
	.db	"\n\rENTER WRITE DATA : "
	.db	esc
	acall	readhex		;get new value
	mov	dph,r4
	mov	dpl,r5
	movx	@dptr,a		;write new value
	inc	dptr
	mov	r4,dph
	mov	r5,dpl
	acall	lfcr

	djnz	r3,svlloop
svlext:
	ajmp	getsel		;return to command mode
;
;------------------------------------------------------------------------
; Set Memory Test Pattern in Ext-Memory
;------------------------------------------------------------------------
t_run:	acall	xstring		;ASK FOR START ADDRESS
	.db	"\n\rENTER 2-BYTE START ADDRESS\n\r"
	.db	esc
	acall	readhex		;put start addr to r4,r5
	mov	r4,a
	acall	readhex
	mov	r5,a

	acall	xstring
	.db 	"\n\rENTER END ADDRESS\n\r"
	.db 	esc
	acall	readhex
	mov	r6,a		;put end address to r6,r7
	acall	readhex
	mov	r7,a

	mov	r3,#0		;set Pattern inital value to r3

	mov	dph,r4		;set start address to dptr
	mov	dpl,r5
pstloop:
	inc	r3		;next Pattern 
	mov	a,r3		;set fill data
	movx	@dptr,a		;clear ext-memory
	xrl	a,#254		; Pattern = 254, Reset to 0
	jnz	pstloop1
	mov	r3,#0		; set initial value
pstloop1:
	mov	a,r6		;dptr = end address ?
	xrl	a,dph		;16bit compare
	mov	b,a
	mov	a,r7
	xrl	a,dpl
	orl	a,b
	jz	pstloope	;loop end
	inc	dptr
	sjmp	pstloop

pstloope:
	acall	lfcr
	ajmp	getsel		;return to command mode
;
;------------------------------------------------------------------------
; Jump to address 
;------------------------------------------------------------------------
j_run:	acall	xstring
	.db	"\n\rENTER 2-BYTE JUMP DESTINATION ADDRESS\n\r"
	.db	esc
	acall	readhex		;first get the jump address
	mov	dph,a
	acall	readhex
	mov	dpl,a
	clr	a
	jmp	@a+dptr		;jump to the address
;
;------------------------------------------------------------------------
; Load hex file into memory
;------------------------------------------------------------------------
load_hex:
	acall	lfcr
	acall	lfcr
;
	setb	f0		; echoback off
;
nextchar:
	acall	chr_in		; get rid of : at start of line
	cjne	a,#':',nextchar	; find ':' charcter
	acall	readhex
	mov	r5,a		; load byte count for line into r5
	acall	readhex		; read high byte of start address
	mov	dph,a		
	acall	readhex		; read low byte of start address
	mov	dpl,a
	acall	readhex		; read record type 00 = data, 01 = end
	jnz	allread		; not 00, end record found

readloop:
	acall	readhex
	movx	@dptr,a
	inc	dptr		; move dptr to next byte address
	djnz	r5,readloop	; decr byte counter, jnz

;	acall	readhex		; get rid of checksum, no checking
	mov	a,#'.'
	acall	chr_out		; put response message
	ajmp	nextchar	; get next line

allread:
	acall	chr_in 		; skip end record
	cjne	a,#'\r',allread

	acall	xstring
	.db	"\n\rHEX-file Upload end\n\r"
	.db	esc

	clr	f0		; echoback on
	ajmp	getsel		; done, go back to menu
;
;------------------------------------------------------------------------
; Read internal RAM using direct addressing 
;------------------------------------------------------------------------
;i_run:	acall	sfrlist
;	acall	xstring
;	.db	"\n\rENTER ADDRESS OF DIRECT READ\n\r"
;	.db	esc
;
;	acall	direct_read
;
;	acall	LFCR
;	ajmp	getsel
;
;------------------------------------------------------------------------
; Set Value in internal RAM using direct addressing
;------------------------------------------------------------------------
v_run:	acall	sfrlist
	acall	xstring
	.db	"\n\rENTER ADDRESS OF DIRECT WRITE\n\r"
	.db	esc

	acall	direct_read

	acall	xstring
	.db	"\n\rENTER WRITE DATA : "
	.db	esc
	acall	readhex
	mov 	r1,a		; r1 = SFR Write Data

	acall	sfrput		; Put SFR 

	acall	lfcr
	ajmp	getsel
;
;-----------------------------------------------------------------------
; Internal Subroutine direct_read
; Internal memory & SFR's One byte Direct Read
; 
direct_read:
	acall	readhex
	mov	r0,a		; r0 = SFR Addr to be Read

	acall	putspace	;space between each one

	acall	sfrget		; Get SFR Value
	acall	wrbyte		;display data
	
	ret
;
;------------------------------------------------------------------------
; display registers & Internal RAM
;------------------------------------------------------------------------
disp_reg:
	acall	xstring
	.db	"\n\rRegisters:\n\rBank  r0 r1 r2 r3 r4 r5 r6 r7\n\r"
	.db	esc
	push	ar0		; save R0
	clr	a
	mov	r0,a		;data pointer
dr1:	mov	a,r0
	rr	a
	rr	a
	rr	a		;make value a bank address
	acall	wrbyte		;display bank number
	acall	put4space	;output four spaces
dr2:	cjne	r0,#00,dr3	; data pointer is R0
	pop	acc		; yes, recover R0 to ACC
	sjmp	dr4
dr3:	mov	a,@r0		; get r1-r7, rb0r0-rb3r7
dr4:	acall	wrbyte		;display the value
	acall	putspace		;space between each one
	inc	r0		;bump pointer
	mov	a,r0		;get address
	anl	a,#h07
	jnz	dr2		;continue till bits 2-0 = zero
;
	acall	lfcr		;bump display to next line
	cjne	r0,#h20,dr1	;continue 'till all four banks displayed
;
	acall	xstring
	.db	"\n\rInternal data ram:\n\r"
	.db	esc
dr5:	mov	a,r0
	acall	wrbyte		;display the address
	acall	put4space	;output four spaces
dr6:	mov	a,@r0
	inc	r0
	acall	wrbyte		;display the data
	acall	putspace		;keep it pretty
	mov	a,r0
	anl	a,#h0f
	jnz	dr6		;16 bytes at a time

	acall	lfcr		;bump down to next line
	cjne	r0,#0,dr5	;loop s'till r0 overflows	
	ajmp	getsel		;and return to command mode
;
;------------------------------------------------------------------------
; display SFR area
;------------------------------------------------------------------------
disp_sfr:
	acall	xstring
	.db	"\n\rall SFR's area:\n\r"
	.db	esc

	mov	r0,#SFRBASE	;SFR area top address
ds1:
	mov	a,r0
	acall	wrbyte		;display the address
	acall	putspace
	acall	chr_out
ds2:
	acall	sfrget		;get SFR area
	inc	r0

	acall	wrbyte		;display the data
	acall	putspace		;keep it pretty

	mov	a,r0
	anl	a,#h07
	jnz	ds2		;8 bytes at a time
	acall	putspace		;One Space

	mov	a,r0
	anl	a,#h0f
	jnz	ds2		;16 bytes at a time

	acall	lfcr		;bump down to next line
	cjne	r0,#0,ds1	;loop s'till r0 overflows	

	ajmp	getsel		;and return to command mode
;
;------------------------------------------------------------------------
; Display External Memory Read by 8-bit address-mode
;------------------------------------------------------------------------
disp_page:
	acall	XSTRING
	.db	"\n\rENTER PAGE ADDRESS OF EXT-MEMORY\n\r"
	.db	esc
	acall	READHEX
	mov	b,a		; save page address
	acall	xstring
	.db	"\n\rEXT-RAM Page data:\n\r"
	.db	esc
	mov	P2,b		; output page-address
	mov	r0,#00		; inner address counter
dpage1:
	mov	a,b
	acall	wrbyte		; display page address
	mov	a,#':'
	acall	chr_out
	mov	a,r0
	acall	wrbyte		; display inner address
	acall	putspace
dpage2:
	movx	a,@r0
	inc	r0
	acall	wrbyte		; display the data
	acall	putspace		; keep it pretty
	mov	a,r0
	anl	a,#h0F
	jnz	dpage2		;16 bytes at a time

	acall	lfcr		;bump down to next line
	cjne	r0,#0,dpage1	;loop s'till r0 overflows	

	ajmp	getsel		;and return to command mode
;
;------------------------------------------------------------------------
; CH552 System clock selection
;------------------------------------------------------------------------
ch552_clk:
	.equ	CLOCK_CFG,h'b9	; System clock configuration register
	.equ	SAFE_MOD,h'a1	; Safe mode control register

	acall	XSTRING
	.db	"\n\rENTER SYSTEM CLOCK MASK (3-6)\n\r"
	.db	esc
	acall	chr_in		; get one character
	anl		a,#h07		; clear Upper 5 bits
	mov		b,a			; save clock mask

	mov		a,CLOCK_CFG
	anl		a,#hf8		; Clear MASK_SYS_CK_SEL
	orl		a,b			; Set MASK_SYS_CK_SEL

	mov		SAFE_MOD,#h55	; Enter Safe_Mode Key-1
	mov		SAFE_MOD,#haa	; Enter Safe_Mode Key-2

	mov		CLOCK_CFG,a		; Rewrite CLOCK_CFG

	mov		SAFE_MOD,#00	; Exit Safe_Mode

	acall	Set_Baud	; set Serial Port Baud Rate
	ajmp	getsel		;and return to command mode
;
;------------------------------------------------------------------------
; common subroutine
;------------------------------------------------------------------------
; put one space to serial port
;
putspace:
	mov	a,#' '
	acall	chr_out
	ret
;
;------------------------------------------------------------------------
; put four space to serial port
;
put4space:
	mov	a,#' '
	acall	chr_out
	acall	chr_out
	acall	chr_out
	acall	chr_out
	ret
;
;------------------------------------------------------------------------
; lfcr sends a line feed and carriage return out the serial port
;
lfcr:	mov	a,#'\n'
	acall	chr_out
	mov	a,#'\r'
	acall	chr_out
	ret
;
;------------------------------------------------------------------------
; xstring is from the amd 8051 data book and sends the text string
; that follows the call to the serial port.  it messes up the 
; dptr and acc, and although is not ended with a ret, must be 
; called.  the text string must end with an esc character
;
xstring:
	pop	dph		;load dptr with first char
	pop	dpl		
xstr_1:	clr	a		;(zero offset)
	movc	a,@a+dptr		;fetch first char in string
xstr_2:	jnb	ti,*		;wait until transmitter ready
	clr	ti		;mark as not ready
	mov	sbuf,a		;output next character
	inc	dptr		;bump pointer
	clr	a		
	movc	a,@a+dptr		;get next character
	cjne	a,#esc,xstr_2	;loop until escape read
	mov	a,#1
	jmp	@a+dptr		;return to code after escape
;
;------------------------------------------------------------------------
; reads a character into a from the serial port and
; echos the character back to the serial port
;
chr_in:	jnb	ri,*
	clr	ri
	mov	a,sbuf
	anl	a,#h7f
	jb	f0,noecho	; f0 is on, echoback off
	acall	chr_out
noecho:	cjne	a,#'!',chr_ine	; break input ?
	mov	a,#stkbase	;  yes, reset stack pointer
	mov	sp,a
	ajmp	getsel		;  jump menu-routine

chr_ine:
	ret
;
;------------------------------------------------------------------------
; sends a character in a out the serial port.  must be an ascii character
;
chr_out:
	jnb	ti,*
	clr	ti
	mov	sbuf,a
	ret
;
;------------------------------------------------------------------------
; converts an ascii character in a to its hex equivalent.
; returns value in lower nibble, upper nibble zeros
;
asc2hex:
	push	b		; Save B-Reg
	mov	b,a		; Save acc
	clr	C
	subb	a,#'@'
	mov	a,b		; Recover acc
	jc	as201		; acc < '@'

; 'A'-'F' or 'a'-'f' Process
	anl	a,#toupper	; Convert LowerCase Alfa to Upper
	subb	a,#'A'
	jc	as2err		; error, acc < 'A'
	mov	b,a		; save acc
	subb	a,#6
	jnc	as2err		; error, acc >= 6 ( > 'F' )

	mov	a,#10
	add	a,b		; acc = hexa value
	clr	c		; input char is valid
	pop	b
	ret

; '0' - '9' Process
as201:	clr	c
	subb	a,#'0'
	jc	as2err		; error, acc < '0'
	mov	b,a		; save acc
	subb	a,#10
	jnc	as2err		; error, acc >= 10 ( > '9' )

	mov	a,b		; acc = hexa value
	clr	c		; input char is valid
	pop	b
	ret

; input char is invalid
as2err:	clr	a		; acc = 0
	setb	c		; input char is invalid
	pop	b
	ret
;
;------------------------------------------------------------------------
; reads two ascii characters from the serial port and 
; converts them into a byte returned in a.
;
readhex:
	push	b
readhex1:
	acall	chr_in		;get the first character
	acall	asc2hex		;convert to hex nibble
	jnc	readhex2	; no convert error ?
	mov	a,#bs		; set backspace
	acall	chr_out		; send backspace
	sjmp	readhex1	; re-read
readhex2:
	swap	a		;high order nibble is first one
	mov	b,a		;save the high order nibble
readhex3:
	acall	chr_in		;get low order character
	acall	asc2hex		;change to hex nibble
	jnc	readhex4	; no conver error ?
	mov	a,#bs		; set backspace
	acall	chr_out		; send backspace
	sjmp	readhex3	; re-read
readhex4:
	orl	a,b		;put nibbles together in a
	pop	b
	ret
;
;------------------------------------------------------------------------
; writes byte into serial port as two hexadecimal characters.
;
wrbyte:	push	dph
	push	dpl
	push	acc
	mov	dptr,#h16tbl	; Hexdecimal Character Table Address

	swap	a		; get Upper Nibble
	anl	a,#h0f
	movc	a,@a+dptr	; to Hexdecimal Character
	acall	chr_out

	pop	acc
	anl	a,#h0f		; get Lower Nibble
	movc	a,@a+dptr	; to Hexdecimal Character
	acall	chr_out

	pop	dpl
	pop	dph
	ret
;
h16tbl	.db	"0123456789ABCDEF"	; Hexadecimal Character Table
;
;-----------------------------------------------------------------------
; SFR Area Put Routine
;  r0 = SFR Addr
;  r1 = SFR Write Data
;
sfrput: mov	a,r0		; Acc = R0 = SFR Addr
	anl	a,#h80
	jnz	sfrp01		; Acc >= 80H , Jump SFR Process
	mov	a,r1		; Acc = R1 = Internal RAM Write Data
	mov	@r0,a		; Put Internal RAM
	ret

sfrp01: acall	getjaddr	; Compute Jump Addr
	mov	a,#0		; Jump SFR Put Routine
	jmp	@a+dptr
;
;-----------------------------------------------------------------------
; SFR Area Get Routine
;  r0 = SFR Addr
;  Return : Acc = SFR Read Data
;
sfrget: mov	a,r0		; ACC = R0 = SFR Addr
	anl	a,#h80
	jnz	sfrg01		; ACC >= 80H , Jump SFR Process
	mov	a,@r0		; Get Internal RAM
	ret
	
sfrg01:	acall	getjaddr	; Compute Jump Addr
	mov	a,#2		; Jump SFR Read Routine
	jmp	@a+dptr
;
;-----------------------------------------------------------------------
; Compute SFR Put/Get Routine Address
;
getjaddr:
	mov	a,r0		; Acc = R0 = SFR Addr
	anl	a,#h7f		; Acc = Acc - 80H

	mov	b,#5
	mul	ab		; (B,Acc) = ACC * 5
	mov	dptr,#sfrjtab	; DPTR = addr(sfrjtab)
	add	a,dpl		; DPL = Acc + DPL
	mov	dpl,a
	mov	a,b		; DPH = B + DPH
	addc	a,dph
	mov	dph,a
	ret
;
;------------------------------------------------------------------------
; display SFR crib sheet 
;
sfrlist:
	acall	xstring
	.db	"\n\rSpecial Function Register Addresses:\n\r"
	.db	"\n\rP0    80  P1    90  P2  A0  P3   B0"
	.db	"\n\rACC   E0  PSW   D0  B   F0  SP   81  DPL  82  DPH   83"
	.db	"\n\rTCON  88  TMOD  89  TL0 8A  TH0  8C  TL1  8B  TH1   8D"
	.db	"\n\rSCON  98  SBUF  99  IE  A8  PCON 87  AUXR 8E  AUXR1 A2"
	.db	"\n\rT2CON C8  T2MOD C9  TL2 CC  TH2  CD  DP1L 84  DP1H  85"
	.db	"\n\r"
	.db	esc
	ret
;
;-----------------------------------------------------------------------
; display command menu
;
dsp_menu:
	acall 	xstring
	.db	"\n\r"
	.db	"MONITR31    i8031/32 Simple Monitor    VERSION "
	.db	VERSION,'.',REVISION,"\r\n\n"
	.db	"ENTER THE LETTER FOR YOUR SELECTION\n\r\n\r"
	.db	"D - DUMP External RAM\n\r"
	.db	"P - DUMP Program ROM\n\r"
	.db	"C - CLEAR External RAM\n\r"
	.db	"W - CLEAR Internal RAM (00-FF)\n\r"
	.db	"S - SET Value in External RAM\n\r"
	.db	"V - SET Value in Internal RAM (00-7F) & SFR's\n\r"
	.db	"T - WRITE Test Pattern in External RAM\n\r"
;	.db	"R - READ Internal RAM (00-FF)\n\r"
	.db	"J - JUMP to Address\n\r"
	.db	"L - LOAD Hex File to RAM\n\r"
;	.db	"I - DIRECT READ Internal RAM (00-7F) & SFR's\n\r"
	.db	"X - Display REGISTER & internal RAM\n\r"
	.db	"Y - Display All SFR's AREA\n\r"
	.db	"Z - Display Ext-RAM 8-bit address-mode\n\r"
	.db	"H - CH552 System clock selection\n\r"
	.db	esc
	ret
;
;----- SFR Get/Put Routine Jump Table ---------------------------------
;
sfrjtab:
	mov	128,r1		; SFR Put
	mov	a,128		; SFR Get
	ret
	mov	129,r1
	mov	a,129
	ret
	mov	130,r1
	mov	a,130
	ret
	mov	131,r1
	mov	a,131
	ret
	mov	132,r1
	mov	a,132
	ret
	mov	133,r1
	mov	a,133
	ret
	mov	134,r1
	mov	a,134
	ret
	mov	135,r1
	mov	a,135
	ret
	mov	136,r1
	mov	a,136
	ret
	mov	137,r1
	mov	a,137
	ret
	mov	138,r1
	mov	a,138
	ret
	mov	139,r1
	mov	a,139
	ret
	mov	140,r1
	mov	a,140
	ret
	mov	141,r1
	mov	a,141
	ret
	mov	142,r1
	mov	a,142
	ret
	mov	143,r1
	mov	a,143
	ret
	mov	144,r1
	mov	a,144
	ret
	mov	145,r1
	mov	a,145
	ret
	mov	146,r1
	mov	a,146
	ret
	mov	147,r1
	mov	a,147
	ret
	mov	148,r1
	mov	a,148
	ret
	mov	149,r1
	mov	a,149
	ret
	mov	150,r1
	mov	a,150
	ret
	mov	151,r1
	mov	a,151
	ret
	mov	152,r1
	mov	a,152
	ret
	mov	153,r1
	mov	a,153
	ret
	mov	154,r1
	mov	a,154
	ret
	mov	155,r1
	mov	a,155
	ret
	mov	156,r1
	mov	a,156
	ret
	mov	157,r1
	mov	a,157
	ret
	mov	158,r1
	mov	a,158
	ret
	mov	159,r1
	mov	a,159
	ret
	mov	160,r1
	mov	a,160
	ret
	mov	161,r1
	mov	a,161
	ret
	mov	162,r1
	mov	a,162
	ret
	mov	163,r1
	mov	a,163
	ret
	mov	164,r1
	mov	a,164
	ret
	mov	165,r1
	mov	a,165
	ret
	mov	166,r1
	mov	a,166
	ret
	mov	167,r1
	mov	a,167
	ret
	mov	168,r1
	mov	a,168
	ret
	mov	169,r1
	mov	a,169
	ret
	mov	170,r1
	mov	a,170
	ret
	mov	171,r1
	mov	a,171
	ret
	mov	172,r1
	mov	a,172
	ret
	mov	173,r1
	mov	a,173
	ret
	mov	174,r1
	mov	a,174
	ret
	mov	175,r1
	mov	a,175
	ret
	mov	176,r1
	mov	a,176
	ret
	mov	177,r1
	mov	a,177
	ret
	mov	178,r1
	mov	a,178
	ret
	mov	179,r1
	mov	a,179
	ret
	mov	180,r1
	mov	a,180
	ret
	mov	181,r1
	mov	a,181
	ret
	mov	182,r1
	mov	a,182
	ret
	mov	183,r1
	mov	a,183
	ret
	mov	184,r1
	mov	a,184
	ret
	mov	185,r1
	mov	a,185
	ret
	mov	186,r1
	mov	a,186
	ret
	mov	187,r1
	mov	a,187
	ret
	mov	188,r1
	mov	a,188
	ret
	mov	189,r1
	mov	a,189
	ret
	mov	190,r1
	mov	a,190
	ret
	mov	191,r1
	mov	a,191
	ret
	mov	192,r1
	mov	a,192
	ret
	mov	193,r1
	mov	a,193
	ret
	mov	194,r1
	mov	a,194
	ret
	mov	195,r1
	mov	a,195
	ret
	mov	196,r1
	mov	a,196
	ret
	mov	197,r1
	mov	a,197
	ret
	mov	198,r1
	mov	a,198
	ret
	mov	199,r1
	mov	a,199
	ret
	mov	200,r1
	mov	a,200
	ret
	mov	201,r1
	mov	a,201
	ret
	mov	202,r1
	mov	a,202
	ret
	mov	203,r1
	mov	a,203
	ret
	mov	204,r1
	mov	a,204
	ret
	mov	205,r1
	mov	a,205
	ret
	mov	206,r1
	mov	a,206
	ret
	mov	207,r1
	mov	a,207
	ret
	mov	208,r1
	mov	a,208
	ret
	mov	209,r1
	mov	a,209
	ret
	mov	210,r1
	mov	a,210
	ret
	mov	211,r1
	mov	a,211
	ret
	mov	212,r1
	mov	a,212
	ret
	mov	213,r1
	mov	a,213
	ret
	mov	214,r1
	mov	a,214
	ret
	mov	215,r1
	mov	a,215
	ret
	mov	216,r1
	mov	a,216
	ret
	mov	217,r1
	mov	a,217
	ret
	mov	218,r1
	mov	a,218
	ret
	mov	219,r1
	mov	a,219
	ret
	mov	220,r1
	mov	a,220
	ret
	mov	221,r1
	mov	a,221
	ret
	mov	222,r1
	mov	a,222
	ret
	mov	223,r1
	mov	a,223
	ret
	mov	224,r1
	mov	a,224
	ret
	mov	225,r1
	mov	a,225
	ret
	mov	226,r1
	mov	a,226
	ret
	mov	227,r1
	mov	a,227
	ret
	mov	228,r1
	mov	a,228
	ret
	mov	229,r1
	mov	a,229
	ret
	mov	230,r1
	mov	a,230
	ret
	mov	231,r1
	mov	a,231
	ret
	mov	232,r1
	mov	a,232
	ret
	mov	233,r1
	mov	a,233
	ret
	mov	234,r1
	mov	a,234
	ret
	mov	235,r1
	mov	a,235
	ret
	mov	236,r1
	mov	a,236
	ret
	mov	237,r1
	mov	a,237
	ret
	mov	238,r1
	mov	a,238
	ret
	mov	239,r1
	mov	a,239
	ret
	mov	240,r1
	mov	a,240
	ret
	mov	241,r1
	mov	a,241
	ret
	mov	242,r1
	mov	a,242
	ret
	mov	243,r1
	mov	a,243
	ret
	mov	244,r1
	mov	a,244
	ret
	mov	245,r1
	mov	a,245
	ret
	mov	246,r1
	mov	a,246
	ret
	mov	247,r1
	mov	a,247
	ret
	mov	248,r1
	mov	a,248
	ret
	mov	249,r1
	mov	a,249
	ret
	mov	250,r1
	mov	a,250
	ret
	mov	251,r1
	mov	a,251
	ret
	mov	252,r1
	mov	a,252
	ret
	mov	253,r1
	mov	a,253
	ret
	mov	254,r1
	mov	a,254
	ret
	mov	255,r1
	mov	a,255
	ret

	.END
