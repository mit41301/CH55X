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

//  ADC register
__sfr __at (0xB9) P1_IE  ;      // port 1 input enable, 0=enable ADC analog input and disable digital input
__sfr __at (0xEF) ADC_CK_SE ;   // ADC clock divisor setting
__sfr __at (0xF1) ADC_STAT ;    // ADC status
__sfr __at (0xF2) ADC_CTRL ;    // ADC control
__sfr __at (0xF3) ADC_CHANN ;   // ADC channel seletion
__sfr __at (0xF4) ADC_FIFO_L ;  // ReadOnly: FIFO low byte
__sfr __at (0xF5) ADC_FIFO_H ;  // ReadOnly: FIFO high byte
__sfr __at (0xF6) ADC_SETUP ;   // ADC setup
__sfr __at (0xF7) ADC_EX_SW ;   // ADC extend switch control

#define bADC_IF_ACT      0x10   // interrupt flag for a ADC finished, write 1 to clear
#define bADC_SAMPLE      0x80   // automatic or manual sample pulse control, high action
#define bADC_POWER_EN    0x04   // control ADC power: 0=shut down ADC, 1=enable power for ADC
#define bADC_RESOLUTION  0x04   // ADC resolution: 0=10 bits, 1=11 bits

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


//------------------------------------------------------------------------------
// delay loop
void mDelayuS(int n)				// Delay in uS
{
    while (n) {						// total = 12~13 Fsys cycles, 1uS @Fsys=12MHz
      -- n ;
    }
}


//
//------------------------------------------------------------------------------
// Initialize ADC manual mode
void InitAdc( unsigned char portnum )
{
	unsigned char templ, temph ;	// temp area
	unsigned char i, mask ;

	mask = 0x01 ;
	for ( i=portnum ; i>0 ; i-- ) {
		mask = mask << 1 ;
	}

	P1_IE = ~mask ;					// set P1.x(AINx) is analog port

    ADC_SETUP |= bADC_POWER_EN ;	// ADC power on
    ADC_CK_SE = 0x04 ;				// set frequency division, 12MHz/4 = 3MHz
    ADC_CTRL = 0b00000000 ;			// set manual sampling and manual channnel selection mode
    ADC_CHANN = mask ;				// use analog port P1.x(AINx)
    ADC_EX_SW = bADC_RESOLUTION ;	// set 11bit sampling
    mDelayuS(100);					// Ensure ADC starts normally

	templ = ADC_FIFO_L ;			// clear FIFO, dummy read
	temph = ADC_FIFO_H ;

	ADC_STAT |= bADC_IF_ACT ;		// clear IF_ACT flag
}


//
//------------------------------------------------------------------------------
// terminate ADC
void StopAdc()
{
	ADC_SETUP &= ~bADC_POWER_EN;	// ADC power off
	P1_IE = 0xFF ;					// set all P1 port is digital in/out (defalt)
    mDelayuS(100);

}


//
//------------------------------------------------------------------------------
// Start ADC
int StartAdc()
{
	int ADCValue ;

	mDelayuS(10);					// Optional, wait for the channel to switch successfully
	ADC_CTRL |= bADC_SAMPLE ;		// set 1, manually generate sampling pulse
	mDelayuS(5) ;
	ADC_CTRL &= ~bADC_SAMPLE ;		// set 0, sampling start

	while ((ADC_STAT & bADC_IF_ACT) == 0) ;	// wait for conversion complete

	ADC_STAT |= bADC_IF_ACT ;		// clear IF_ACT flag
	ADCValue = (int) ADC_FIFO_L | (int) ADC_FIFO_H << 8 ;	// get ADC value

	return ADCValue ;				// Return sample value
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
	unsigned char	j, s ;
	unsigned int	n ;
	unsigned int	ADCdat ;

	InitSio () ;
	
	PutText ( "\r\n ADC start ? " ) ;
	s = GetChar () ;

	InitAdc ( 4 ) ;

	for ( j=0; j<200; j++ ) {
		ADCdat = StartAdc () ;
		PutNum5 ( ADCdat ) ;
		PutText ( "\r\n" ) ;

		for ( n=0; n<500; n++ ) {
			 mDelayuS(1000);
		}
	}

	StopAdc () ;

	return 0 ;
}

