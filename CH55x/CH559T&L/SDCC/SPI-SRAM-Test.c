// CH559L Version @ Fsys:12MHz
//
#include <8052.h>
#define SS 4			// CH559L SS port

__sfr __at (0xC9) T2MOD ;       // timer 2 mode and timer 0/1/2 clock mode

//  CH552 port register
__sfr __at (0x92) P1_MOD_OC ;   // port 1 output mode: 0=push-pull, 1=open-drain
__sfr __at (0x93) P1_DIR_PU ;   // port 1 direction for push-pull or pullup enable for open-drain

//  CH559 port register
__sfr __at (0xC6) PORT_CFG ;    // port 0/1/2/3 config
__sfr __at (0xBA) P1_DIR   ;    // port 1 direction
__sfr __at (0xBB) P1_PU    ;    // port 1 pullup enable

//  SPI-0 register
__sfr __at (0xF8) SPI0_STAT ;   // SPI 0 status
 __sbit __at (0xFB) S0_FREE  ;  // ReadOnly: SPI0 free status
__sfr __at (0xF9) SPI0_DATA ;   // FIFO data port: reading for receiving, writing for transmittal
__sfr __at (0xFA) SPI0_CTRL ;   // SPI 0 control
__sfr __at (0xFB) SPI0_CK_SE ;  // clock divisor setting
__sfr __at (0xFC) SPI0_SETUP ;  // SPI 0 setup

static unsigned char hex[] = "0123456789ABCDEF" ;

//------------------------------------------------------------------------------
// Initialize SIO 9.6Kbps/19.2Kbps 1 stop bit @ Max Speed = 6MHz(CH552)/12MHz(CH559)
void InitSio()
{
	PCON |= 0x80;		// set smod ( double baud rate )
	TMOD = 0x20;		// Timer1 mode-2 : auto reload 8-bit timer mode
	T2MOD |= 0xA0;		// set bTMR_CLK, bT1_CLK ( Set Timer1 Clock, MAX Speed = Fsys = 12MHz )
	TH1  = 217;			// 9.615Kbps@6MHz/19.23Kbps@12MHz SMOD=1,bTMR_CLK=1,bT1_CLK=1
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


//
//------------------------------------------------------------------------------
// Initialize SPI Port : Master Mode, Clock-rate 1/16
void InitSpi()
{
    // SS    P1.3  Not Use
    // SCS   P1.4  Use
    // MOSI  P1.5
    // MISO  P1.6
    // SCK   P1.7

    // GPIO Register Setting CH552
//  P1_MOD_OC = 0b00001101;		// SCK,MISO,MOSI,SCS and P1.1(SS) push-pull output
//  P1_DIR_PU = 0b10111111;		// MISO input (No-Pullup registor)

	// GPIO Register Setting CH559
    PORT_CFG = 0b00101101;		// P1 driver current is 10mA & Push-Pull
	P1_DIR |=  0b10110000 | (1 << SS);  // SCK,MOSI,SCS,P1.3(SS) output, MISO input

    // SPI Register Setting
    SPI0_SETUP = 0b00000000;	// SPI master mode, MSB first
    SPI0_CTRL  = 0b01101000;	// MOSI,SCK output, Mode-3, 3-wire full duplex (SCK+MOSI+MISO)
    SPI0_CK_SE = 16;			// SPI Clock 1/16 = 12MHz/16 = 750KHz
}

//------------------------------------------------------------------------------
// SPI Transmit Data
void SpiTXbyte(unsigned char s)
{
    SPI0_DATA = s;				// Transmission data
    while(!S0_FREE);			// Wait for transmission complete
}

//------------------------------------------------------------------------------
// SPI Receive Data
unsigned char SpiRXbyte()
{
    SPI0_DATA = 0xff;			// Dummy transmission data
    while(!S0_FREE);			// Wait for transmission complete

	return SPI0_DATA;			// Receive data
}

//------------------------------------------------------------------------------
// SPI Transmit/Receive Data
unsigned char SpiTRXbyte ( unsigned char s )
{
    SPI0_DATA = s;				// Transmission data
    while(!S0_FREE);			// Wait for transmission complete

	return SPI0_DATA;			// Receive data
}


//
//------------------------------------------------------------------------------
// Initialize 23LC512 Serial SRAM
void InitSram ()
{
	// Set SS Low
	P1 &= ~(1 << SS);

	// Reset Dual and Quad Mode
	SpiTXbyte ( 0xff ) ; 

	// Write WRMR Command
	SpiTXbyte ( 0x01 ) ;	// WRMR Command
	SpiTXbyte ( 0x40 ) ;	// MODE Register Value ( Sequential Mode )

	// Set SS High
	P1 |= (1 << SS);
}

// Read Serial SRAM
void ReadSram ( unsigned int maddr, unsigned char *rdata, unsigned int rnum )
{
	unsigned char madr8[2], s ;
	unsigned int i ;

	madr8[0] = maddr >> 8 ;
	madr8[1] = (char)maddr ;

	// Set SS Low
	P1 &= ~(1 << SS);

	SpiTXbyte ( 0x03 ) ;		// READ Command
	SpiTXbyte ( madr8[0] ) ;	// Address (H)
	SpiTXbyte ( madr8[1] ) ;	// Address (L)

	for ( i=0; i<rnum; i++ ) {	// Read Data
		s = SpiRXbyte () ;
		*rdata++ = s ;
	}

	// Set SS High
	P1 |= (1 << SS);
}

// Write Serial SRAM
void WriteSram ( unsigned int maddr, __xdata unsigned char *wdata, unsigned int wnum )
{
	unsigned char madr8[2], s ;
	unsigned int i ;

	madr8[0] = maddr >> 8 ;
	madr8[1] = (char)maddr ;

	// Set SS Low
	P1 &= ~(1 << SS);
	
	SpiTXbyte ( 0x02 ) ;		// WRITE Command
	SpiTXbyte ( madr8[0] ) ;	// Address (H)
	SpiTXbyte ( madr8[1] ) ;	// Address (L)

	for ( i=0; i<wnum; i++ ) {	// Write Data
		s = *wdata++ ;
		SpiTXbyte ( s ) ;
	}

	// Set SS High
	P1 |= (1 << SS);	
}


//------------------------------------------------------------------------------
// Put 5-Digit Integer Number
//
void PutNum5 ( unsigned int n )
{
	unsigned char d[5], s, i ;
	unsigned int n16 ;

	n16 = n ;
	for ( i=4 ; i>0 ; i-- ) {
		d[i] = n16 % 10 ;
		n16 = n16 / 10 ;
	}
	d[0] = n16 ;

	PutChar( ' ' ) ;		// One Space
	for ( i=0 ; i<=4 ; i++ ) {
		s = d[i] + 0x30 ;
		PutChar ( s ) ;
	}
}

//------------------------------------------------------------------------------
//
// Put 3-Digit Integer Number
//
void PutNum3 ( unsigned char n )
{
	unsigned char q, r ;

	PutChar( ' ' ) ;		// One Space
	q = n / 100 + 0x30 ;
	r = n % 100 ;
	PutChar ( q ) ;

	q = r / 10 + 0x30 ;
	r = r % 10 + 0x30 ;
	PutChar ( q ) ;
	PutChar ( r ) ;
}

//------------------------------------------------------------------------------
//
// Put Hexadecimal Format
//
void PutHex ( unsigned char s )
{
//	unsigned char hex[] = "0123456789ABCDEF" ;
	unsigned char ch, cl ;

	cl = s & 0x0f ;
	ch = s >> 4 ;

//	PutChar ( ' ' ) ;		// One Space	
	PutChar ( hex[ch] ) ;
	PutChar ( hex[cl] ) ;
}


//------------------------------------------------------------------------------
int main ()
{
	unsigned char	j, k, s, madr8[2] ;
	unsigned int	i, n, maddr;
	unsigned char	__xdata xmem[256] ;

	InitSio () ;
	InitSpi () ;
	InitSram() ;	// Initialize 23LC512

	for ( i=0; i<256; i++ ) {
		xmem[i] = i + 128 ;
	}

	PutText ( "\r\n Write ? " ) ;
	s = GetChar () ;

	maddr = 0 ;
	for ( j=0; j<128; j++ ) {
		WriteSram ( maddr, xmem, 256 ) ;
		maddr += 256 ;
	}
	
	PutText ( " Read ? " ) ;
	s = GetChar () ;		
	PutText ( "\r\n" ) ;

	maddr = 0 ;
	for ( j=0; j<128; j++ ) {
		madr8[0] = maddr >> 8 ;
		madr8[1] = (char)maddr ;
		PutHex ( madr8[0] ) ;
		PutHex ( madr8[1] ) ;
		PutChar ( ' ' ) ;

		ReadSram ( maddr, xmem, 256 ) ;		

		n = 0 ;
		for ( i=0; i<256; i++ ) {
			k = i + 128 ;
			if ( xmem[i] != k ) {
				n++ ;
			}
		}
		if ( n > 0 ) PutNum5 ( n ) ;
		PutText ( "\r\n" ) ;

		maddr += 256 ;
	}

	return 0 ;
}

