;
; start and over screen.asm
;
; Created: 21-04-2022 10:42:00
; Author : Deeksha
;

;This code will display
; button 1 : START!
; button 2 : GAME OVER


; Definition file of the ATmega328P
.INCLUDE "m328pdef.inc"
; Boot
.ORG 0x0000 ; 
RJMP Init ; First instruction that is executed by the microcontroller

;macro
.DEF RowIndex		= R16 ; Index used to count the row number 
.DEF Local_index1	= R17
.DEF local_index2	= R18
.DEF STATE_MACHINE	= R19 ;Stores state of game 00 : 
.DEF PAT_COL1		= R20 ;Temporary Pattern for column
.DEF DummyReg		= R21

.EQU buffer_start = 0x0100
.EQU buffer_end = 0x010F

Init: 
; Configure output pin PB3
SBI DDRB, 3 ; Pin PB3 is an output: Data pin SDI (Serial Data In)
SBI DDRB, 4 ; Pin PB4 is an output: Latch/Output pin: LE(Latch Enable) + OE(Output Enable)
SBI DDRB, 5 ; Pin PB5 is an output: Clock pin CLK
; Configure input joystick pin PB2
CBI DDRB,2;	pin an input switch
SBI PORTB,2;Enable the pull-up resistor
;configure output buzzer in PB1
SBI DDRB,1;	output pin
CBI PORTB,1 ; pull-down buzzer by default

;Main Function
Main:
	LDI RowIndex, 0x08 ;index for send1row
	Send1Row:
		CALL execute_col_loop
		CALL execute_row_loop
		CALL Latch_shift_reg
		DEC RowIndex
	BRNE Send1Row 
RJMP Main

;Funtion to shift column data on for a pattern
execute_col_loop:
	;Loading chartable address in Z register
	LDI ZH, high(CharTable1<<1)
	LDI ZL, low(CharTable1<<1)

	;increment Z till RowIndex for a character is reached
	MOV Local_index1, RowIndex
	Loop_Z:
		LPM PAT_COL1, Z+
		DEC Local_index1
	BRNE Loop_Z

 	LDI Local_index2, 16  ;index to shift screen 16 times for every screen block
	Col_loop2:
		
		;shift 5bit Column pattern into Shift Reg
		LDI Local_index1, 5	
		Col_loop3: 
			CBI PORTB,3 ;pixel_off
			SBRC PAT_COL1, 0 ;pixel turned off if pattern's LSB is 0
			SBI PORTB,3	;pixel on
			CBI PORTB, 5 ;falling edge of shift-reg clock
			SBI PORTB, 5 ;rising edge of clk
			LSR PAT_COL1 ; right shifting pattern for next bit
			DEC Local_index1
		BRNE Col_loop3

		;Increment Z pointer by 8 to point to same row in next character
		LDI Local_index1,8
		Loop_Z2:
			LPM PAT_COL1,Z+
			DEC Local_index1
		BRNE Loop_Z2
		DEC Local_index2
	BRNE col_loop2
RET

;function to shift row data for a pattern
execute_row_loop:
	LDI Local_index1, 0x08 
	CLC
	LoopRow:
		CBI PORTB, 3 
		CP Local_index1,RowIndex
		BRNE Row_not_on
		SBI PORTB, 3 
		Row_not_on: 
			CBI PORTB, 5 
			SBI PORTB, 5
		DEC Local_index1 
	BRNE LoopRow
RET

;function to latch shift register data to output
latch_shift_reg:
	CBI PORTB, 4
	SBI PORTB, 4 
	LDI Local_index1, 50 ;index for delay loop
	delay_loop:
		NOP
		DEC Local_index1
	BRNE delay_loop
	CBI PORTB, 4
RET

;character memory table
;Stores >START!
;		  ----
CharTable3:
.DB 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000 ;Nothing
.DB 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000 ;Nothing
.DB 0b00000, 0b00000, 0b00000, 0b11111, 0b00000, 0b00000, 0b00000, 0b00000 ;line
.DB 0b00000, 0b00000, 0b00000, 0b11111, 0b00000, 0b00000, 0b00000, 0b00000 ;line
.DB 0b00000, 0b00000, 0b00000, 0b11111, 0b00000, 0b00000, 0b00000, 0b00000 ;line
.DB 0b00000, 0b00000, 0b00000, 0b11111, 0b00000, 0b00000, 0b00000, 0b00000 ;line
.DB 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000 ;Nothing
.DB 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000 ;Nothing
.DB 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000 ;Nothing
.DB 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b00000, 0b00100, 0b00000 ;exclamation
.DB 0b01110, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b00000 ;T
.DB 0b01110, 0b01001, 0b01001, 0b01110, 0b01100, 0b01010, 0b01001, 0b00000 ;R
.DB 0b00110, 0b01001, 0b01001, 0b01111, 0b01001, 0b01001, 0b01001, 0b00000 ;A
.DB 0b01110, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b00000 ;T
.DB 0b00111, 0b01000, 0b01000, 0b00110, 0b00001, 0b00001, 0b01110, 0b00000 ;S
.DB 0b00000, 0b00100, 0b00010, 0b00001, 0b00010, 0b00100, 0b00000, 0b00000 ;small arrow
.DB 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000 ;Nothing

CharTable2:
.DB 0b01110, 0b01001, 0b01001, 0b01110, 0b01100, 0b01010, 0b01001, 0b00000 ;R
.DB 0b01111, 0b01000, 0b01000, 0b01111, 0b01000, 0b01000, 0b01111, 0b00000 ;E
.DB 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01010, 0b00100, 0b00000 ;V
.DB 0b00110, 0b01001, 0b01001, 0b01001, 0b01001, 0b01001, 0b00110, 0b00000 ;0
.DB 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000 ;Nothing
.DB 0b00000, 0b00100, 0b00010, 0b00001, 0b00010, 0b00100, 0b00000, 0b00000 ;small arrow
.DB 0b00000, 0b00100, 0b00010, 0b00001, 0b00010, 0b00100, 0b00000, 0b00000 ;small arrow
.DB 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000 ;Nothing
.DB 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000 ;Nothing
.DB 0b00000, 0b00100, 0b00010, 0b00001, 0b00010, 0b00100, 0b00000, 0b00000 ;small arrow
.DB 0b00000, 0b00100, 0b00010, 0b00001, 0b00010, 0b00100, 0b00000, 0b00000 ;small arrow
.DB 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000 ;Nothing
.DB 0b01111, 0b01000, 0b01000, 0b01111, 0b01000, 0b01000, 0b01111, 0b00000 ;E
.DB 0b10001, 0b11011, 0b10101, 0b10001, 0b10001, 0b10001, 0b10001, 0b00000 ;M
.DB 0b00110, 0b01001, 0b01001, 0b01111, 0b01001, 0b01001, 0b01001, 0b00000 ;A
.DB 0b00110, 0b01001, 0b01000, 0b01011, 0b01001, 0b01001, 0b00110, 0b00000 ;G

CharTable1:
.DB 0b11001, 0b11111, 0b11111, 0b11001, 0b11001, 0b11111, 0b11111, 0b00000 ;ship BIG part
.DB 0b01000, 0b01111, 0b01111, 0b01111, 0b01000, 0b00000, 0b00000, 0b00000 ;ship 1 part
.DB 0b01111, 0b01000, 0b01000, 0b01111, 0b01000, 0b01000, 0b01111, 0b00000 ;E
.DB 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01010, 0b00100, 0b00000 ;V
.DB 0b00110, 0b01001, 0b01001, 0b01001, 0b01001, 0b01001, 0b00110, 0b00000 ;0
.DB 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000 ;Nothing
.DB 0b00000, 0b00100, 0b00010, 0b00001, 0b00010, 0b00100, 0b00000, 0b00000 ;small arrow
.DB 0b00000, 0b00100, 0b00010, 0b00001, 0b00010, 0b00100, 0b00000, 0b00000 ;small arrow
.DB 0b11111, 0b11111, 0b11001, 0b11001, 0b11111, 0b11111, 0b11001, 0b00000 ;ship BIG part
.DB 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000 ;Nothing
.DB 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000 ;Nothing
.DB 0b00000, 0b00100, 0b00010, 0b00001, 0b00010, 0b00100, 0b00000, 0b00000 ;small arrow
.DB 0b00000, 0b00100, 0b00010, 0b00001, 0b00010, 0b00100, 0b00000, 0b00000 ;small arrow
.DB 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000 ;Nothing
.DB 0b01111, 0b01000, 0b01000, 0b01111, 0b01000, 0b01000, 0b01111, 0b00000 ;E
.DB 0b10001, 0b11011, 0b10101, 0b10001, 0b10001, 0b10001, 0b10001, 0b00000 ;M

