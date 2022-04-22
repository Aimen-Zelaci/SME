.INCLUDE "m328pdef.inc"

.org 0x0000
rjmp init

.org 0x0020
rjmp TimerInterrupt



.EQU MonsterNotGunPat = 0b01111001
.EQU MonsterGunPat = 0b01111001

.EQU BTN8_PATTERN = 0b01111011 ; Button 8 pressed pattern
.EQU BTN7_PATTERN = 0b01110111 ; Button 7 pressed pattern
.EQU BTN5_PATTERN = 0b10111011 ; Button 5 pressed pattern
.EQU BTN4_PATTERN = 0b10110111 ; Button 4 pressed pattern
.EQU NOBTN_PATTERN =  0b11111111 ; No button preesed pattern
.EQU OTHER_PATTERN = 0b00110011 ; Pattern for the rest of the buttons

init: SBI DDRC, 2
	  SBI PORTC,2

	  LDI R16, 0b10001111 ; keyboard set
	  LDI R17, 0b01110000
	  OUT DDRD, R17 
	  OUT PORTD, R16 ; Init keyboard. set all rows to ground and cols to 1 

	  LDI R16, 0xFF 
	  OUT DDRB, R16 ; Set PORTB to out

	  LDI R21, 0x01 ; initial row

	  LDI ZL, 0x00
	  LDI ZH, 0x01


	 LDI R16, HIGH(RAMEND)
	 OUT SPH, R16
	 LDI R16, LOW(RAMEND)
	 OUT SPL, R16

	 SEI ;Set I bit to 1
	
	 LDI R16, 0x01
	 STS TIMSK0, R16 ;timer0 interrupt enable

 	 LDI R16, 0x05
	 OUT TCCR0B, R16 ;prescaler 1024



; 1ST ROW
LDI R16, MonsterNotGunPat
STS 0x212, R16
LDI R16, 0b00011111
STS 0x213, R16
LDI R16, 0b01000000
STS 0x214, R16
RCALL InitScreenState
		

;2ND ROW
SECOND_ROW: 
LDI R16, 0b00011111
STS 0x212, R16
LDI R16, 0b00011111
STS 0x213, R16
LDI R16, 0b01111000
STS 0x214, R16
CALL InitScreenState
            


;3RD ROW
LDI R16, 0b00011111
STS 0x212, R16
LDI R16, MonsterGunPat
STS 0x213, R16
LDI R16, 0b01111100
STS 0x214, R16
CALL InitScreenState

;4th ROW
LDI R16, MonsterGunPat
STS 0x212, R16
LDI R16, MonsterNotGunPat
STS 0x213, R16
LDI R16, 0b01111000
STS 0x214, R16
CALL InitScreenState

;5th ROW
LDI R16, MonsterNotGunPat
STS 0x212, R16
LDI R16, 0b00011111
STS 0x213, R16
LDI R16, 0b01000000
STS 0x214, R16
CALL InitScreenState

;6th ROW
LDI R16, 0b00011111
STS 0x212, R16
LDI R16, 0b00011111
STS 0x213, R16
LDI R16, 0b00000000
STS 0x214, R16
CALL InitScreenState

; 7th ROW
LDI R16, 0b00011111
STS 0x212, R16
LDI R16, MonsterGunPat
STS 0x213, R16
LDI R16, 0b00000000
STS 0x214, R16
CALL InitScreenState 
 
LDI ZL, 0x00 ; Reset
LDI ZH, 0x01

LDI R23, 0x01
   
main: CALL DISPLAY
    
	RJMP CHECK_STATE

	RJMP main
	

CHECK_STATE: 
	 ; --------------- MOVE TO INTERMEDIATE STATE OF THE SCREEN ---------
			RCALL DISPLAY_INTERMEDIATE_STATE

	  IN R18,PIND ; Copy PIND into R18
	  RCALL CONTEXT_SWITCH ; Call context switch (RCALL takes less instruction cycles than CALL)
	  IN R19,PIND ; Copy PIND into R19
	  RCALL RESET_CONTEXT ; Call reset context 
	  OR R18,R19 ; R18 OR R19 and store the result in R18
	  

	  CPI R18,BTN4_PATTERN ; If button 8 is pressed
	  BREQ MOVE_DOWN
	LDI R21, 0x01 ; reset to first row again
	  LDI ZL, 0x00
	  LDI ZH, 0x01
	  RJMP main
MOVE_DOWN:   
		CBI PORTC,2 ; Turn on top led
		    
       ; --------------- COPY PARTS OF THE SHIP TO POINTER X -----------

		; ------------ FIRST ROW OF BLOCKS --------------
		LDI ZL, 0x00 ; Start at 10
		LDI ZH, 0x01

		LDI XL, 0x20
		LDI XH, 0x02
		
		LDI R16, 0x00
		ST X+, R16

		LDD R16, Z+9
		ST X+, R16

		LDD R16, Z+19
		ST X+, R16

		LDD R16, Z+29
		ST X+, R16

		LDD R16, Z+39
		ST X+, R16

		LDD R16, Z+49
		ST X+, R16

		LDD R16, Z+59
		ST X+, R16

		; cant' write with std for over 63
		LDI R17, 69
		READ: LD R16, Z+
			  DEC R17
			  BRNE READ
		LD R16, Z
		ST X+, R16

		; ------------ SECOND ROW OF BLOCKS --------------
		LDI ZL, 0x00 
		LDI ZH, 0x01

		LDD R16, Z+4
		ST X+, R16

		LDD R16, Z+14
		ST X+, R16

		LDD R16, Z+24
		ST X+, R16

		LDD R16, Z+34
		ST X+, R16

		LDD R16, Z+44
		ST X+, R16

		LDD R16, Z+54
		ST X+, R16

		; cant' write with std for over 63
		LDI R17, 64
		READ1: LD R16, Z+
			  DEC R17
			  BRNE READ1
		LD R16, Z
		ST X+, R16

		; -------------- MOVE DOWN ------------

		; ------------ FIRST ROW OF BLOCKS --------------
		LDI ZL, 0x00 
		LDI ZH, 0x01

		LDI XL, 0x20
		LDI XH, 0x02
		
		LD R16, X+
		STD Z+9, R16
		
		LD R16, X+
		STD Z+19, R16

		LD R16, X+
		STD Z+29, R16

		LD R16, X+
		STD Z+39, R16

		LD R16, X+
		STD Z+49, R16

		LD R16, X+
		STD Z+59, R16

		; cant' write with std for over 63
		LDI R17, 69
		READ2: LD R16, Z+
			  DEC R17
			  BRNE READ2
      
	  LD R16, X+
	  ST Z, R16
	  ; ------------ SECOND ROW OF BLOCKS --------------
	  LDI ZL, 0x00
	  LDI ZH, 0x01

	  LD R16, X+
		STD Z+4, R16
		
		LD R16, X+
		STD Z+14, R16

		LD R16, X+
		STD Z+24, R16

		LD R16, X+
		STD Z+34, R16

		LD R16, X+
		STD Z+44, R16

		LD R16, X+
		STD Z+54, R16

		; cant' write with std for over 63
		LDI R17, 64
		READ3: LD R16, Z+
			  DEC R17
			  BRNE READ3
      
	  LD R16, X+
	  ST Z, R16

	 LDI R21, 0x01 ; reset to first row again
	  LDI ZL, 0x00
	  LDI ZH, 0x01
	   
	   DELAY: LDI R20, 0xFF
	  LOOP:  NOP
			LDI R28, 0xFF
			NESTED: NOP
					LDI R29, 0x04
					NESTED2: NOP
							 DEC R29
							 BRNE NESTED2
					DEC R28
					BRNE NESTED
	   DEC R20
	   BRNE LOOP
	   
	  RJMP main
			    
DISPLAY_INTERMEDIATE_STATE: LDI R17, 88
				   CBI PORTB, 3
				   SEND_DATA: CBI PORTB, 5
							  SBI PORTB, 5
							  DEC R17
							  BRNE SEND_DATA
					CBI PORTB, 4
					SBI PORTB, 4
					CBI PORTB, 4
					
				  
					RET
				   

InitScreenState: LDS R22,  0x212
				 ST Z+, R22

				LDI R22, 0x00
				LDI R17, 4

				LOOP_BUFF: ST Z+, R22
						   DEC R17
						   BRNE LOOP_BUFF

				LDS R22, 0x213
				ST Z+, R22

				LDI R22, 0x00
				LDI R17, 3

				LOOP_BUFF1_: ST Z+, R22
						   DEC R17
						   BRNE LOOP_BUFF1_
		   
				LDS R22, 0x214
				ST Z+, R22

				RET ; Return to caller

CONTEXT_SWITCH: LDI R16, 0b01110000  ; Copy 0b1111 0000 to R16
			    LDI R17, 0b10001111  ; Copy 0b0000 1111 to R17



			    OUT PORTD, R16 ; Set PORTD to R16
	            OUT DDRD, R17  ; Set DDRD to R17  	
			    RET ; Return to caller

RESET_CONTEXT: LDI R16, 0b10001111 ; keyboard set
			   LDI R17, 0b01110000

			   OUT PORTD, R16
		       OUT DDRD, R17
			   RET ; Return to caller



DISPLAY: SBI PORTC, 2 ; test
      LDI R20, 10 ; 10 bytes per row 
	  LOAD_BYTE: LDI R18, 8 ;Iteration variable, 8 bits to serially shift
			     LD R16, Z+ ; Read from loacation pointed by z and auto-increment z
			     CLC ; Clear carry bit

	   SEND_BYTE_COL: SBI PORTB,3 ; Clear column data input
				  ROR R16
				  BRCS CARRY_ISONE
				  CBI PORTB,3
				  CARRY_ISONE: CBI PORTB,5 ; clock edge
							   SBI PORTB,5
				  DEC R18
				  BRNE SEND_BYTE_COL

	   DEC R20
	   BRNE LOAD_BYTE ; load next byte
	  
		   
	   LDI R18, 8
	   MOV R25, R21
       CLC
	   SEND_BYTE_ROW: CBI PORTB,3 ; clear data input
					   ROL R25
					   BRCC _CARRY_ISZERO
					   SBI PORTB,3 ; set data input
					   _CARRY_ISZERO: CBI PORTB,5 ; clock edge
									 SBI PORTB,5
					   DEC R18
					   BRNE SEND_BYTE_ROW
	

	CBI PORTB,4 ; latch data to output
	SBI PORTB,4
	AWAIT: SBIS TIFR0, TOV0 ; Delay
		   RJMP AWAIT
	
	;CLC
	LSL R21 ; shift to next row
	CPI R21, 0x80
	BRNE DISPLAY
	
	LDI R21, 0x01 ; reset to first row again
	  LDI ZL, 0x00
	  LDI ZH, 0x01
	  LDI XL, 0x20
	  LDI XH, 0x02

	RET

TimerInterrupt: LDI R16, 253
				OUT TCNT0,R16
				CBI PORTB, 4
				RETI

