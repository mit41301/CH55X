//------------------------------------------------------------------------------
//   PAI - Machin formula method  ( 10進2桁対応版 )           < pai21_CH559.c >
//
//     pi = 16 * arctan( 1/5 ) - 4 * arctan ( 1/239 )
//
//     arctan(x) = x - (1/3)x**3 + (1/5)x**5 ... 
//       x = 1/5 or x = 1/239
//
//   2023.05.13 0.06.07 新規作成。8052(AT89S8253)版を元に作成
//            --> 
//
//   Comple & Link command ;
//
//      > sdcc pai21_CH559.c
//
//------------------------------------------------------------------------------
#include <8052.h>
__sfr __at (0xC9) T2MOD ;       // timer 2 mode and timer 0/1/2 clock mode


#define	W	2010/2		// 2,000桁まで求める
#define WP	W-5			// 印刷桁数
#define VER	"<pai21>"

//----------------------------------------------------------------

	unsigned char GRE8 ;	// 余り(remainder)
	unsigned int GRE16 ;	// 余り(remainder)

//----------------------------------------------------------------
// Initialize SIO 19.2Kbps 1 stop bit @ Max Speed = 12MHz(CH559)
void InitSio()
{
	PCON |= 0x80;		// set smod ( double baud rate )
	TMOD = 0x20;		// Timer1 mode-2 : auto reload 8-bit timer mode
	T2MOD |= 0xA0;		// set bTMR_CLK, bT1_CLK ( Set Timer1 Clock, MAX Speed = Fsys = 12MHz )
	TH1  = 217;			// 19.23Kbps@12MHz SMOD=1,bTMR_CLK=1,bT1_CLK=1
	SCON = 0x50;		// 8-bit async, timer1 as baud rate generater, receive enabled
	TCON = 0x41;		// Timer1 startup
}

// Send a single char to serial port
void PutChar(char c)
{
	SBUF = c;
	while (!TI);
	TI = 0;
}

// Send String to serial port
void PutText(char *st)
{
	while(*st) PutChar(*st++) ;
}

// Send One Number to serial port
void PutNum(char n)
{
	char s ;
	s = n + 0x30 ;
	PutChar( s ) ;
}

// Recive a single char from serial port
char GetChar()
{
	while(!RI);
	RI = 0;
	return SBUF;
}

//------------------------------------------------------------------------------
//  16-Bit integer Multiply by 100 Routine
//  (dph,dpl) = x * 100
//    x = (dph,dpl)
//------------------------------------------------------------------------------
unsigned int mul100d ( unsigned int x ) __naked
{
__asm
	push	ar2

	mov		a,dpl		; dpl * 100
	mov		b,#100
	mul		ab			; (b,a) = dpl * 100
	mov		dpl,a		; Lower-Byte dpl = a
	mov		r2,b		; Save High-Byte
	mov		a,dph		; dph * 100
	mov		b,#100
	mul		ab			; (b,a) = dph * 100
	add		a,r2		; a = a + r2
	mov		dph,a		; High-Byte dph = a

	pop		ar2
	ret

__endasm ;

}


//------------------------------------------------------------------------------
//  24-Bit integer Multiply by 100 Routine
//  (a,b,dph,dpl) = x * 100
//    x = (dph,dpl)
//  a-regの値は常に0
//------------------------------------------------------------------------------
long mul100t ( unsigned int x ) __naked
{
__asm
	push	ar2

	mov		a,dpl		; dpl * 100
	mov		b,#100
	mul		ab			; (b,a) = dpl * 100
	mov		dpl,a		; Lower-Byte dpl = a
	mov		r2,b
	mov		a,dph		; dph * 100
	mov		b,#100
	mul		ab			; (b,a) = dph * 100
	add		a,r2		; a = a + r2
	jnc		00010$
	inc		b			; if carry-flag on, +1 to b ; b is Upper-Byte
00010$:
	mov		dph,a		; Middle-Byte dph = a
	mov		a,#0		; Top-Byte = 0

	pop		ar2
	ret

__endasm ;

}


//------------------------------------------------------------------------------
//  8-Bit integer Divied Routine
//  dpl = x / y ... GRE8
//   x = (dpl)
//------------------------------------------------------------------------------
unsigned char div8b ( unsigned char x, unsigned char y ) __naked
{
__asm

	mov		a,dpl		; a = dpl = x
	mov		b,_div8b_PARM_2	; b = y
	div		ab			; a / b = a ... b
	mov		dpl,a		; 商
;	mov		dph,#0
	mov		_GRE8,b		; 余り

	ret

__endasm ;
	
}


//------------------------------------------------------------------------------
//  16-Bit integer Divied Routine
//  (dph,dpl) = x / y ... GRE16
//    x = (dph,dpl)
//------------------------------------------------------------------------------
unsigned int div16b ( unsigned int x, unsigned int y ) __naked
{
__asm

;   除数の上位バイトをチェック

	mov		a,_div16b_PARM_2+1
	jnz		00020$		; 除数の上位バイトは0以外

;   除数の上位バイトが0
;   --------------------------------------------------------
;   被除数の上位バイトをチェック

	mov		a,dph
	jnz		00010$		; 被除数の上位バイトは0以外

;   --------------------------------------------------------
;   除数も被除数も上位バイトが0の時
;   8ビット÷8ビットの割算、ハード命令で割り算をする

	mov		a,dpl		; dpl = x
	mov		b,_div16b_PARM_2
	div		ab			; a / b = a ... b
	mov		dpl,a		; 商
	mov		dph,#0
	mov		_GRE16,b	; 余り
	mov		_GRE16+1,#0

	ret	

;   --------------------------------------------------------
;   除数の上位バイトが0、被除数の上位バイトが0以外の時
;   16ビット÷8ビットの割算、3バイト16回シフトで計算
;   除数が128以上の時、左シフトでオーバフロービットが発生するので対応

00010$:
	push	ar2
	push	ar3
	mov		r2,#16		; Loop Counter
	mov		r3,#0		; remainder area Low-byte

;   割算ルーチン
;   r3,dph,dpl / low(y) = dph,dpl ... r3
00011$:
;	shift left 3-byte(r3,dph,dpl)
	mov		a,dpl
	add		a,acc		; shift left dpl
	mov		dpl,a
	mov		a,dph
	rlc		a			; shift left with carry dph
	mov		dph,a
	mov		a,r3
	rlc		a			; shift left with carry r3
	mov		r3,a
	mov		F0,C		; save shift over-flow bit

;	Sub a = R3 - y
	clr		c			; Clear Carry Flag
	mov		a,r3
	subb	a,_div16b_PARM_2
	jb		F0,00012$	; if shift over-fiow is on, ignore bollow
	jc		00013$		; jump if carry(bollow) flag is on

00012$:
	mov		r3,a		; r3 = a
	orl		dpl,#1		; set 1 to LSB of quotient
00013$:
	djnz	r2,00011$

;   loop end
;						  商はdph,dpl
	mov		_GRE16,r3	; 余り下位バイト
	mov		_GRE16+1,#0	; 余り上位バイトは0

	pop		ar3
	pop		ar2
	ret


;   除数の上位バイトが0以外
;   --------------------------------------------------------
;   被除数の上位バイトをチェック

00020$:
	mov		a,dph
	jz		00090$		; 被除数の上位バイトは0、被除数 < 除数 なので割算不要

;   --------------------------------------------------------
;   除数の上位バイトが0以外の時
;   16ビット÷16ビットの割算、3バイト8回シフトで計算
;   除数が32,768以上の時、左シフトでオーバフロービットが発生するので対応

;   被除数が除数より小さいかチェック
	clr		c
	mov		a,dpl		; (dph,dpl) = x
	subb	a,_div16b_PARM_2	; x - y
	mov		a,dph
	subb	a,_div16b_PARM_2+1
	jc		00090$		; carry(bollow) Flag on, 被除数 < 除数 なので割算不要

	push	ar2
	push	ar3
	mov		r2,#8		; Loop Conter
	mov		r3,#0		; remainder area High-byte

;   割算ルーチン
;   r3,dph,dpl / y = dpl ... r3,dph
00021$:
;	shift left 3-byte(r3,dph,dpl)
	mov		a,dpl
	add		a,acc		; shift left dpl
	mov		dpl,a
	mov		a,dph
	rlc		a			; shift left with carry dph
	mov		dph,a
	mov		a,r3
	rlc		a			; shift left with carry r3
	mov		r3,a
	mov		F0,C		; save shift over-flow bit

;	Sub (a,b) = (r3,dph) - y
	clr		c		; Clear Carry(Overflow) Flag
	mov		a,dph
	subb	a,_div16b_PARM_2
	mov		b,a
	mov		a,r3
	subb	a,_div16b_PARM_2+1
	jb		F0,00022$	; if shift over-fiow is on, ignore bollow
	jc		00023$		; jump if carry(bollow) flag is on

00022$:
	mov		dph,b		; (r3,dph) = (a,b)
	mov		r3,a
	orl		dpl,#1		; set 1 to LSB of quotient
00023$:
	djnz	r2,00021$

;   loop end
	mov		_GRE16,dph	; 余り下位バイト
	mov		_GRE16+1,r3	; 余り上位バイト
	mov		dph,#0		; 商の上位バイト（常に0）、商の下位バイトはdpl

	pop		ar3
	pop		ar2
	ret

;   --------------------------------------------------------
;   被除数が除数より小さい時は割算不要
00090$:

	mov		_GRE16,dpl	; 余り = (dph,dpl)
	mov		_GRE16+1,dph
	mov		dpl,#0		; 商 = 0
	mov		dph,#0

	ret

__endasm ;
	
}


//------------------------------------------------------------------------------
//  24-Bit integer Divied Routine
//  (dph,dpl) = x / y ... GRE16
//    x = (a,b,dph,dpl)
//    y must be y >= 256, x must be x < 16,777,216
//  xの最上位バイト(a-reg)は無視、商が3バイトになることは想定しない
//------------------------------------------------------------------------------
unsigned int div24b ( long x, unsigned int y ) __naked
{
__asm

;   被除数の上位バイト(mid-high)をチェック
	mov		a,b
	jnz		00020$		; 上位バイトが0以外

;   --------------------------------------------------------
;   被除数の上位バイトが0の時
;   16ビット÷16ビットの割算、3バイト8回シフトで計算
;   除数が32,768以上の時、左シフトでオーバフロービットが発生するので対応

;   被除数が除数より小さいかチェック
	clr		c
	mov		a,dpl		; (dph,dpl) = x
	subb	a,_div24b_PARM_2	; x - y
	mov		a,dph
	subb	a,_div24b_PARM_2+1
	jc		00090$		; carry(bollow) Flag on, 被除数 < 除数 なので割算不要

	push	ar2
	push	ar3
	mov		r2,#8		; Loop Conter
	mov		r3,#0		; remainder area High-byte

;   割算ルーチン
;   r3,dph,dpl / y = dpl ... r3,dph
00010$:
;	shift left 3-byte(r3,dph,dpl)
	mov		a,dpl
	add		a,acc		; shift left dpl
	mov		dpl,a
	mov		a,dph
	rlc		a			; shift left with carry dph
	mov		dph,a
	mov		a,r3
	rlc		a			; shift left with carry r3
	mov		r3,a
	mov		F0,C		; save shift over-flow bit

;	Sub (a,b) = (r3,dph) - y
	clr		c		; Clear Carry(Overflow) Flag
	mov		a,dph
	subb	a,_div24b_PARM_2
	mov		b,a
	mov		a,r3
	subb	a,_div24b_PARM_2+1
	jb		F0,00011$	; if shift over-fiow is on, ignore bollow
	jc		00012$		; jump if carry(bollow) flag is on

00011$:
	mov		dph,b		; (r3,dph) = (a,b)
	mov		r3,a
	orl		dpl,#1		; set 1 to LSB of quotient
00012$:
	djnz	r2,00010$

;   loop end
	mov		_GRE16,dph	; 余り下位バイト
	mov		_GRE16+1,r3	; 余り上位バイト
	mov		dph,#0		; 商の上位バイト（常に0）、商の下位バイトはdpl

	pop		ar3
	pop		ar2
	ret


;   --------------------------------------------------------
;   被除数の上位バイトが0以外の時
;   24ビット÷16ビットの割算、4バイト16回シフトで計算
;   除数が32,768以上の時、左シフトでオーバフロービットが発生するので対応

00020$:
	push	ar2
	push	ar3
	push    ar4
	mov		r2,#16	; Loop Conter
	mov		r3,b	; remainder area Low-byte
	mov		r4,#0	; remainder area High-byte

;   割算ルーチン
;   r4,r3,dph,dpl / y = dph,dpl ... r4,r3
00021$:
;	shift left 4-byte(r4,r3,dph,dpl)
	mov		a,dpl
	add		a,acc	; shift left dpl
	mov		dpl,a
	mov		a,dph
	rlc		a		; shift left with carry dph
	mov		dph,a
	mov		a,r3
	rlc		a		; shift left with carry r3
	mov		r3,a
	mov		a,r4
	rlc		a		; shift left with carry r4
	mov		r4,a
	mov		F0,C	; save shift over-flow bit

;	Sub (a,b) = (r4,r3) - y
	clr		c		; Clear Carry(Overflow) Flag
	mov		a,r3
	subb	a,_div24b_PARM_2
	mov		b,a
	mov		a,r4
	subb	a,_div24b_PARM_2+1
	jb		F0,00022$	; if shift over-fiow is on, ignore bollow
	jc		00023$		; jump if carry(bollow) flag is on

00022$:	
	mov		r3,b	; (r4,r3) = (a,b)
	mov		r4,a
	orl		dpl,#1	; set 1 to LSB of quotient
00023$:
	djnz	r2,00021$

;   loop end
;					; 商はdph,dpl
	mov	_GRE16,r3	; 余り下位バイト
	mov	_GRE16+1,r4	; 余り上位バイト

	pop	ar4
	pop	ar3
	pop	ar2
	ret


;   --------------------------------------------------------
;   被除数が除数より小さい時は割算不要
00090$:

	mov		_GRE16,dpl	; 余り = (dph,dpl)
	mov		_GRE16+1,dph
	mov		dpl,#0		; 商 = 0
	mov		dph,#0

	ret

__endasm ;
	
}


//------------------------------------------------------------------------------
//
// Put 2-Digit Integer Number
//
void PutNum2 ( unsigned char n )
{
	unsigned char s ;

	s = div8b ( n, 10 ) + 0x30 ;
	PutChar ( s ) ;
	s = GRE8 + 0x30 ;
	PutChar ( s ) ;
}

//------------------------------------------------------------------------------
//
// Put 5-Digit Integer Number
//
void PutNum5 ( int n )
{
	unsigned char d[5], n8, s, i ;
	unsigned int n16 ;

	n16 = div16b ( n, 10 ) ;
	d[4] = GRE16 ;
	n16 = div16b ( n16, 10 ) ;
	d[3] = GRE16 ;
	n8 = div16b ( n16, 10 ) ;
	d[2] = GRE16 ;
	d[0] = div8b ( n8, 10 ) ;
	d[1] = GRE8 ;

	PutChar( ' ' ) ;		// One Space
	for ( i=0 ; i<=4 ; i++ ) {
		s = d[i] + 0x30 ;
		PutChar ( s ) ;
	}
}


//------------------------------------------------------------------------------
void div ( __xdata unsigned char *wa, __xdata unsigned char *wb, unsigned int d, unsigned int p )
//
//  16ビット版割算ルーチン ※dが653以上になるとオーバフローする可能性があるので注意
//
//    wa = wb / d
//
//  本ルーチン内で以下の例のように、dの値により16ビット割算と24ビット割算を
//  切り替えるようにすると、オプテマイズの関係か異様に遅くなるので、24ビット
//  割算を別ルーチンdiv3とした
//    if ( d<653 ) {
//       for ( i=p; i<=W; i++ ) {  16ビット割算処理  } 
//    else {
//       for ( i=p; i<=W; i++ ) {  24ビット割算処理  } 
//    }
{
	unsigned int	i ;
	unsigned int t, x ;		// max 65,535

	wa += p ;
	wb += p ;

	t = 0 ;
	for ( i=p; i<=W; i++ ) {
//		x = t * 100 + wb[i] ;
		x = mul100d ( t ) + *wb++ ;	// 16ビットで計算, t*100の計算でオーバーフローに注意
		*wa++ = div16b ( x, d ) ;	// *wa = x / d ... GRE16
		t = GRE16 ;					// 余りは16ビット
	}
}


//------------------------------------------------------------------------------
void div3 ( __xdata unsigned char *wa, __xdata unsigned char *wb, unsigned int d, unsigned int p )
//
//  24ビット版割算ルーチン
//
//    wa = wb / d
//
{
	unsigned int	i ;
	unsigned int	t ;		// max 65,535
	long			x ;		// max +2,147,483,647

	wa += p ;
	wb += p ;

	t = 0 ;
	for ( i=p; i<=W; i++ ) {
//		x = t * 100 + wb[i] ;
		x = mul100t ( t ) + *wb++ ;	// 24ビットで計算
		*wa++ = div24b ( x, d ) ;	// *wa = x / d ... GRE16
		t = GRE16 ;					// 余りは16ビット
	}
}

//------------------------------------------------------------------------------
void add ( __xdata unsigned char *wa, __xdata unsigned char *wb, unsigned int p )
//
//   wa = wa + wb
//
{
	unsigned int	i, pp ;
	unsigned char	t, x ;

	t = 0 ;
	wa += W ;
	wb += W ;
	pp = W - p ;
	for ( i=0; i<=W; i++ ) { 
		x = *wa + *wb-- + t ;
		t = div8b ( x, 100 ) ;		// t = x / 100 ... GRE8
		*wa-- = GRE8 ;
		if ( i > pp && t == 0 ) break ;		// 桁上りがなくなったら終了
	}

	if ( t!=0 ) PutText( "add overflow\n" ) ;
}

//------------------------------------------------------------------------------
void sub ( __xdata unsigned char *wa, __xdata unsigned char *wb, unsigned int p )
//
//   wa = wa - wb
//
{
	unsigned int	i, pp ;
	unsigned char	t, x ;

	t = 1 ;
	wa += W ;
	wb += W ;
	pp = W - p ;
	for ( i=0; i<=W; i++ ) {
		x = *wa + ( 100-1 - *wb-- ) + t ;
		t = div8b ( x, 100 ) ;		// t = x / 100 ... GRE8
		*wa-- = GRE8 ;
		if ( i > pp && t == 1 ) break ;		// 桁借りがなくなったら終了
	}

	if ( t!=1 ) PutText( "sub overflow\n" ) ;
}

//------------------------------------------------------------------------------
void dup ( __xdata unsigned char *wa, __xdata unsigned char *wb )
//
//   wa = wb
//
{
	unsigned int	i ;

	for ( i=0; i<=W; i++ ) {
		*wa++ = *wb++ ;
	}
}

//------------------------------------------------------------------------------
void init ( __xdata unsigned char *wa, unsigned int n )
{
	unsigned int	i ;

	*wa++ = n ;
	for ( i=1; i<=W; i++ ) {
		*wa++ = 0 ;
	}
}

//------------------------------------------------------------------------------
unsigned int top ( __xdata unsigned char *wa, unsigned int p )
{
	unsigned int	i ;

	wa += p ;
	for ( i=p; i<=W; i++ ) {
		if ( *wa++ != 0 ) break ;
	}
	return (i) ;
}

//------------------------------------------------------------------------------
void marctan ( __xdata unsigned char wa[], unsigned int n, unsigned int d )
//
//   wa = n * arctan ( 1 / d )
//
{
	__xdata static unsigned char we[W+1], wf[W+1] ;
	unsigned int	p, i ;
	unsigned int	dd ;
	unsigned char	fdd ;

	dd = d * d ;
	fdd = 0 ;
	if ( dd < 653 ) fdd = 1 ;

	init ( we, n ) ;			// we = n
	div ( we, we, d, 0 ) ;		// we = we / d
	p = top ( we, 0 ) ;
	dup ( wa, we ) ;			// wa = we
	i = 1 ;
	while ( p<= W ) {
		i += 2 ;
		if ( fdd ) {				// divルーチン内でオーバーフローが発生する可能性がないか？
			div ( we, we, dd, p ) ;	  // we = we / d**2 ：発生しない時
		} else {
			div3 ( we, we, dd, p ) ;  // we = we / d**2 ：発生する可能性がある時
		}

		if ( i < 653 ) {			// divルーチン内でオーバーフローが発生する可能性がないか？
			div ( wf, we, i, p ) ;	  // wf = we / i ：発生しない時
		} else {
			div3 ( wf, we, i, p ) ;	  // wf = we / i ：発生する可能性がある時
		}

		if ( (i&0x0003)==1 ) {
			add ( wa, wf, p ) ;		// wa = wa + wf
		} else {
			sub ( wa, wf, p ) ;		// wa = wa - wf
		}
		p = top ( we, p ) ;

		// Debug Write
		div16b( i, 100 ) ;
		if ( GRE16==1 ) {			// i%100 == 1
			PutNum5 ( d ) ;
			PutNum5 ( i ) ;
			PutNum5 ( p ) ;
			PutChar ( ' ' ) ;
			PutNum2 ( wa[WP-2] ) ;
			PutNum2 ( wa[WP-1] ) ;
			PutNum2 ( wa[WP] ) ;
			PutText ( "\r\n" ) ;
		}
	}
	PutText ( " n=" ) ;
	PutNum5 ( i ) ;
	PutText ( "\r\n\r\n" ) ;
}

//------------------------------------------------------------------------------
void Machin ()
{
	__xdata static unsigned char wa[W+1], wb[W+1] ;
	__xdata unsigned char	*pwa ;
	unsigned int	i ;

	marctan ( wa, 16,   5 ) ;	// wa = 16 * arctan(1/5)
	marctan ( wb,  4, 239 ) ;	// wb = 4 * arctan(1/239)
	sub ( wa, wb, 0 ) ;			// wa = wa - wb

	pwa = wa ;
	PutNum ( *pwa++ ) ;			// 「3.」を印刷
	PutChar ( '.' ) ;
	for ( i=1; i<=WP; i++ ) {
		PutNum2 ( *pwa++ ) ;	// 2桁ずつ印刷 
		div16b ( i, 5 ) ;			
		if ( GRE16==0 ) {				// i%5 == 0 ：10桁ごとに空白
			PutChar ( ' ' ) ;
			div16b ( i, 25 ) ;
			if ( GRE16==0 ) {			// i%25 == 0 ：50桁ごとに改行
				PutText ( "\r\n  " ) ;
				div16b ( i, 500 ) ;
				if ( GRE16==0 ) PutText ( "\r\n  " ) ;	// i%500 == 0 ：1000桁ごとに空白行
			}
		}
	}
}

//------------------------------------------------------------------------------
void main ()
{
	unsigned char	s ;

	InitSio () ;
	PutText ( VER ) ;
	PutText ( " Machin Method. Start OK ? " ) ;
	s = GetChar () ;
	PutChar ( s ) ;
	PutText ( "\r\n" ) ;

	Machin () ;

	PutText ( "*** END ***\r\n" ) ;
}	

