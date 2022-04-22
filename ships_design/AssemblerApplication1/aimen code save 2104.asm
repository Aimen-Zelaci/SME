.INCLUDE "m328pdef.inc"

.org 0x0000
rjmp init

.EQU MonsterNotGunPat = 0b01111001
.EQU MonsterGunPat = 0b01111001

init: 
	  LDI R16, 0xFF 
	  OUT DDRB, R16 ; Set PORTB to out

	  LDI R21, 0x01 ; initial row

	  LDI ZL, 0x00
	  LDI ZH, 0x01


	 LDI R16, HIGH(RAMEND)
	 OUT SPH, R16
	 LDI R16, LOW(RAMEND)
	 OUT SPL, R16


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
	   
main: LDI R20, 10 ; 10 bytes per row 
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
	   MOV R29, R21
       CLC
	   SEND_BYTE_ROW: CBI PORTB,3 ; clear data input
					   ROL R29
					   BRCC _CARRY_ISZERO
					   SBI PORTB,3 ; set data input
					   _CARRY_ISZERO: CBI PORTB,5 ; clock edge
									 SBI PORTB,5
					   DEC R18
					   BRNE SEND_BYTE_ROW
	

	CBI PORTB,4 ; latch data to output
	SBI PORTB,4
	DELAY: LDI R29, 3
	AGAIN: NOP
		   LDI R28, 20
		   NESTED: NOP
			       DEC R28
				   BRNE NESTED
		   DEC R29
		   BRNE AGAIN
	CBI PORTB, 4
	    
	;CLC
	LSL R21 ; shift to next row
	CPI R21, 0x80
	BRNE main
	    
	LDI R21, 0x01 ; reset to first row again
	LDI ZL, 0x00
	LDI ZH, 0x01
	RJMP main


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