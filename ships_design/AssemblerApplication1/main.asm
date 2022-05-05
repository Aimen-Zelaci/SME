;
; UC GAME PROJECT
;
; Created: 24-04-2022 10:35:44
; Authors : Deeksha - Aimen
;


; Definition file of the ATmega328P
.INCLUDE "m328pdef.inc"
; Boot
.ORG 0x0000 ; 
RJMP Init ; First instruction that is executed by the microcontroller

;macro
.DEF Local_index1	= R17
.DEF local_index2	= R18
.DEF PAT_COL1		= R19 ;Temporary Pattern for column
.DEF DummyReg		= R20
.DEF STATE_MACHINE	= R21 ;Stores state of game  00 : start
												;01 : game over
.DEF LAST_JOY		= R22 ; Stores last state of joystick  
.DEF RowIndex		= R23 ; Index used to count the row number
.DEF LAST_KEY		= R24 ; global var to store state of keyboard last 
.DEF BOSS_SHIPCOUNTER = R25 ; Current active gun index of the boss

.EQU MonsterNotGunPat = 0b11111001
.EQU MonsterGunPat = 0b11111001
.EQU ShipGun = 0b0011111
.EQU ShipMiddle = 0b00111110
.EQU ShipEnd = 0b0010000

;keyboard patterns
.EQU BTN8_PATTERN = 0b01111011 ; Button 8 pressed pattern
.EQU BTN7_PATTERN = 0b01110111 ; Button 7 pressed pattern
.EQU BTN5_PATTERN = 0b10111011 ; Button 5 pressed pattern
.EQU BTN4_PATTERN = 0b10110111 ; Button 4 pressed pattern
.EQU BTN2_PATTERN = 0b11011011 ; Button 2 pressed pattern
.EQU NOBTN_PATTERN =  0b11111111 ; No button preesed pattern
.EQU OTHER_PATTERN = 0b00110011 ; Pattern for the rest of the buttons

; Interrupts
.ORG 0x0006
rjmp JoystickInterrupt

.org 0x001A
rjmp TimerInterrupt


.ORG 0x0020
rjmp Timer0interrupt

Init: 
; Configure output pin PB3
SBI DDRB, 3 ; Pin PB3 is an output: Data pin SDI (Serial Data In)
SBI DDRB, 4 ; Pin PB4 is an output: Latch/Output pin: LE(Latch Enable) + OE(Output Enable)
SBI DDRB, 5 ; Pin PB5 is an output: Clock pin CLK

; Configure input joystick pin PB2
CBI DDRB,2;	pin an input switch
SBI PORTB,2;Enable the pull-up resistor

;enabling keyboard input
LDI R16, 0x0F
LDI R17, 0xF0
OUT DDRD, R17 
OUT PORTD, R16 ; Init keyboard. set all rows to ground and cols to 1 

;LED 
SBI DDRC, 2
SBI PORTC,2

;Initializing state machine
LDI STATE_MACHINE, 0x01
LDI LAST_JOY, 0x00
LDI LAST_KEY, 0x00

;CALL init_screen
CALL Load_game_play_start

SEI ;Set golabl interrupt
; timerinterrupt	/* Timer interrupt enabled inside machine state*/

LDI R16, 0x05
STS TCCR1B, R16 ;prescaler timer 1
LDI R16, 0x05
OUT TCCR0B, R16 ;prescaler timer 0
;LDI R16, 0x02
;OUT TCCR0A, R16 ;CTC MODE
;LDI R16, 100
;OUT OCR0A, R16
 
; Joystick interrupt
LDI R16, 0x01
LDI R17, 4
STS PCICR, R16
STS PCMSK0, R17

; INIT BOSS ACTIVE GUN COUNTER = it has 6 guns
LDI BOSS_SHIPCOUNTER, 6

LDI XH, 0x02
LDI YH, 0x02
LDI YL, 0x50
LDI XL, 0x90

LDI local_index1, 20
LDI R16, 0x00
INIT_BULLETS: ST Y, R16
			  ST X, R16
			  DEC local_index1
			  BRNE INIT_BULLETS

;Main Function
Main: CALL display
	;CALL state_machine_update
	CALL load_screen_state
	LDI LAST_JOY, 0x00
	SBI PORTC,2
	LDS R18, 0x0380
	CPI R18, 1
	BRNE Main
	CALL BOSS_SHOOT
RJMP Main

init_screen:
	LDI ZH, high(CharTable2<<1)
	LDI ZL, low(CharTable2<<1)
RET

Display:
	LDI RowIndex, 0x08 ;index for send1row
	Send1Row:
		CALL execute_col_loop
		CALL execute_row_loop
		CALL Latch_shift_reg
		DEC RowIndex
	BRNE Send1Row
RET

Load_screen_state:
	CPI STATE_MACHINE, 0x01 ;Joystick went off 
	BREQ state_0 ; 
	CPI STATE_MACHINE, 0x02 ;Joystick went off 
	BREQ state_0 ; 	
	CPI STATE_MACHINE, 0x03 ;Joystick went off - on - off 
	BREQ State_1 ; game display
	CPI STATE_MACHINE, 0x04 ;Joystick went off - on - off 
	BREQ State_1 ; game display
	CPI STATE_MACHINE, 0x05 ;Joystick went off - on - off - on - off
	BREQ State_2 ; game over display
	CPI STATE_MACHINE, 0x06 ;Joystick went off - on - off - on - off
	BREQ State_2 ; game over display
	CPI STATE_MACHINE, 0x07 ;Joystick went off - on - off - on - off - on - off
	BREQ Reset_state ; reset to start display
	RET 	

	State_0: ;START
		LDI ZH, high(CharTable1<<1) 
		LDI ZL, low(CharTable1<<1)

		LDI R18, 5
		STS 0x0381, R18

		LDI R16, 0x00
		STS TIMSK1, R16 ;timer1 interrupt disable
		STS TIMSK0, R16 ; timer0 interrupt disable
		RET
	State_1: ;GAME PLAY
		LDI R16, 0x01
		STS TIMSK1, R16 ;timer1 interrupt enable
		STS TIMSK0, R16 ; timer0 interrupt enable

		CALL CHECK_STATE
		;CALL UPDATE_BULLETSTATE
		;CALL BULLET_DELAY

		;SBIC TIFR0, TOV0
		;rjmp update

		LDI ZH,0x01
		LDI ZL,0x00
		RET
	State_2: ; GAME OVER
		LDI R16, 0x00
		STS TIMSK1, R16 ;timer1 interrupt disable
		STS TIMSK0, R16 ; timer0 interrupt disable
		LDI ZH, high(CharTable2<<1)
		LDI ZL, low(CharTable2<<1)
		RET	
	Reset_state:
	    LDI R16, 0x00
		STS TIMSK1, R16 ;timer1 interrupt disable
		LDI STATE_MACHINE, 0x01
		RET			


CHECK_STATE: 
			 IN R18,PIND ; Copy PIND into R18
		     RCALL CONTEXT_SWITCH ; Call context switch (RCALL takes less instruction cycles than CALL)
		     IN R19,PIND ; Copy PIND into R19
		     RCALL RESET_CONTEXT ; Call reset context 
		     OR R18,R19 ; R18 OR R19 and store the result in R18

		     CPI R18,BTN2_PATTERN ; If button 2 is pressed
			 BREQ state_plus_2

     		 CPI R18,BTN8_PATTERN ; If button 8 is pressed
		     BREQ state_plus_8

			 CPI R18,BTN5_PATTERN ; If button 5 is pressed
		     BREQ state_plus_5


			 CPI R18,NOBTN_PATTERN ; If no button is pressed
			 BREQ reset_key_state
			 RET

			 state_plus_2:
				LDI LAST_KEY, 0x02
			 RET

			 state_plus_8:
				LDI LAST_KEY, 0x04
			 RET

			 state_plus_5:
				LDI LAST_KEY, 0x06
			 RET

			 reset_key_state:
				CPI LAST_KEY,0x02 ; If button 2 is pressed
				BREQ go_down
				CPI LAST_KEY,0x04 ; if button 8 is pressed
				BREQ go_up
				CPI LAST_KEY,0x06 ; if button 5 is pressed
				BREQ ship_shoot
			 RET

			 go_down:
				LDI LAST_KEY,0x00
				CALL MOVE_DOWN
			 RET

			 go_up:
				LDI LAST_KEY,0x00
				CALL MOVE_UP
			 RET

			 ship_shoot:
				LDI LAST_KEY,0x00
				CALL SHOOT
			 RET

UPDATE_BULLETSTATE: PUSH ZL
				    PUSH ZH
					PUSH R18
					PUSH R20
					PUSH R2
					IN R2, SREG
					LDI ZL, 0x0A
					LDI YH, 0x02
					LDI XH, 0x02

					LDI YL, 0x50 ; Ship bullet
					LDI XL, 0x90 ; Boss bullet	
					

				    LDI R20, 49 ; 1St upper row                   ;xxxxxxx  x  
					CALL SHIFT_Z
					CALL TRACE_BULLET

					LDI XL, 0x93 ; BOSS GUN!
					
					LDI R20, 39 ; 2nd upper row                   ;xxxxxxx  x
					CALL SHIFT_Z
					CALL TRACE_BULLET

					LDI XL, 0x96 ; BOSS GUN !
					LDI R20, 29 ; 3rd upper row                    ;xxxxx      
					CALL SHIFT_Z
					CALL TRACE_BULLET
					
					LDI XL, 0x99 ; BOSS GUN !
					LDI R20, 19 ; 4th upper row				     ;xxxxx 
					CALL SHIFT_Z
					CALL TRACE_BULLET

					LDI XL, 0x9C ; BOSS GUN !
					LDI R20, 9 ; 5th upper row				      ;xxxxxxx  x
					CALL SHIFT_Z
					CALL TRACE_BULLET

					LDI XL, 0x9F ; BOSS GUN !
					LDI R20, 64 ; 1St bottom row
					CALL SHIFT_Z
					CALL TRACE_BULLET

					LDI XL, 0xA2 ; BOSS GUN !
					LDI R20, 54 ; 2nd bottom row
					CALL SHIFT_Z
					CALL TRACE_BULLET

					LDI XL, 0xA5 ; BOSS GUN !
					LDI R20, 44 ; 3rd bottom row
					CALL SHIFT_Z
					CALL TRACE_BULLET

					LDI XL, 0xA8 ; BOSS GUN !
					LDI R20, 34 ; 4th bottom row
					CALL SHIFT_Z
					CALL TRACE_BULLET

					LDI XL, 0xAB ; BOSS GUN !

					LDI R20, 24 ; 5th bottom row
					CALL SHIFT_Z
					CALL TRACE_BULLET

					LDI XL, 0xAE ; BOSS GUN !
					LDI R20, 14 ; 6th bottom row
					CALL SHIFT_Z
					CALL TRACE_BULLET

					LDI XL, 0xB1 ; BOSS GUN !
					LDI R20, 4 ; 7th bottom row
					CALL SHIFT_Z
					CALL TRACE_BULLET
							 
			
			finish_update:  OUT SREG, R2
							POP R2
							POP R20
							POP R18
							POP ZH
							POP ZL
							RET

TRACE_BULLET: LD R16, Y ; ship bullet
			LD R17, X ; boss bullet
			
			; --------------
			; ---- check if bullets are met ----
			CPI R16, 0x00
			BREQ continue
			MOV dummyReg, R16 
			SUB dummyReg, R17
			CPI dummyReg, 0x00
			BREQ bullets_collapse
			; --- continue ----
			continue: MOV R18, R16
			OR R18, R17
			ST -Z, R18;storing bullet 

			LSL R17 ; shift boss bullet to the left
			ST X+, R17
			BRCC shipNotHit

			
			; ---- Check if ship is hit
			INC ZL
			LD R18, Z
			CPI R18, shipGun
			BREQ shipDamaged
			DEC ZL
			; --------------

			shipNotHit:CLC
			LSR R16 ; shift ship bullet to the right
			ST Y+, R16
			BRCC next ; if carry is set write to the next byte 
			LDI R16, 0x80 ;shifting 1 to next byte of bullet path
			ST Y, R16

			; next byte
			next: LD R16, Y
				  LD R17, X
				  MOV R18, R16
				  OR R16, R17
				  ST -Z, R16

				  LSR R18
				  ST Y+, R18
				  BRCC bossBullet
				  LDI R16, 0x80
				  ST Y, R16
					; move the boss bultt to the next byte if carry is set
				  bossBullet:  LSL R17
						  ST X, R17
						  BRCC next3
						  LDI R17, 0x01
						  ST -X, R17
						  INC XL

					; last byte
			  next3: INC XL		 
					 LD R16, Y
					 LD R17, X
					 MOV R18, R16
					 OR R16, R17
					 ST -Z, R16

					 LSR R18
					 ST Y+, R18
					 BRCS bossDamaged

					 CLC
					 LSL R17
					 ST X, R17
					 BRCC finish_trace ; problem here regarding X
					 LDI R17, 0x01
					 ST -X, R17	 ; move the boss bultt to the next byte if carry is set
							
							

				finish_trace: RET
				; -- if bullets collapse => reset ---
				bullets_collapse: LDI R16, 0x00
								  ST Y, R16
								  ST X, R16
								  RET
				; --- if ship is hit by boss bullet -------
				shipDamaged: LDS R18, 0x0381
							 DEC R18
							 BREQ game_over
							 STS 0x0381, R18
							 RET

							 game_over: LDI STATE_MACHINE, 0x05 ; game over state
										RET
			   ; ----- Check if boss is hit by ship bullet ---------------
			   bossDamaged: LDI STATE_MACHINE, 0x05 ; game over state
							RET	
										 
										 		

SHOOT: PUSH ZL
	   PUSH ZH
	   PUSH R2
	   IN R2, SREG
	   LDI ZL, 0x0A
	   LDI YL, 0x50

	   LDD R16, Z+49
	   RCALL SHIP_FIRE

	   LDD R16, Z+39
	   RCALL SHIP_FIRE

	   LDD R16, Z+29
	   RCALL SHIP_FIRE

	   LDD R16, Z+19
	   RCALL SHIP_FIRE

	   LDD R16, Z+9
	   RCALL SHIP_FIRE

	   
	   LDI R20, 64 ; 1St bottom row
	   CALL SHIFT_Z
	   LD R16, Z
	   RCALL SHIP_FIRE
	   LDI ZL, 0x0A

	   LDD R16, Z+54
	   RCALL SHIP_FIRE

	   LDD R16, Z+44
	   RCALL SHIP_FIRE

	   LDD R16, Z+34
	   RCALL SHIP_FIRE

	   LDD R16, Z+24
	   RCALL SHIP_FIRE
	   
	   LDD R16, Z+14
	   RCALL SHIP_FIRE

	   LDD R16, Z+4
	   RCALL SHIP_FIRE

	   finish_shooting: OUT SREG, R2
						POP R2
						POP ZH
						POP ZL
						RET

SHIP_FIRE: CPI R16, ShipGun
		   BRNE DONT_FIRE
		   LD R16, Y
		  LDI R17, 0x80
		   OR R16, R17
		   ST Y, R16
		   DONT_FIRE: INC YL
					   INC YL
					  INC YL
					  RET

BOSS_SHOOT:		LDI XH, 0x02
				PUSH ZL
				PUSH ZH
			    PUSH R18
			    PUSH R2
				IN R2, SREG
				
				CPI BOSS_SHIPCOUNTER, 6
				BREQ PAT1
				CPI BOSS_SHIPCOUNTER, 5
				BREQ PAT2
				CPI BOSS_SHIPCOUNTER, 4
				BREQ PAT3
				CPI BOSS_SHIPCOUNTER, 3
				BREQ PAT4
				CPI BOSS_SHIPCOUNTER, 2
				BREQ PAT5
				CPI BOSS_SHIPCOUNTER, 1
				BREQ PAT6

				LDI BOSS_SHIPCOUNTER, 6 ; reset
				OUT SREG, R2
				POP R2
			    POP R18
				POP ZH
				POP ZL
				RETI

				PAT1: LDI XL, 0x92
					  RJMP boss_fire
				PAT2: LDI XL, 0x95
					  RJMP boss_fire
				PAT3: LDI XL, 0x9E
					  RJMP boss_fire
				PAT4: LDI XL, 0xA1
					  RJMP boss_fire
				PAT5: LDI XL, 0xAA
					  RJMP boss_fire
				PAT6: LDI XL, 0xAD

				boss_fire: LD R16, X
				LDI R17, 0x01
				OR R16, R17
				ST X, R16
				DEC BOSS_SHIPCOUNTER

				;CALL UPDATE_BULLETSTATE

				LDI R18, 0
				STS 0x0380, R18

				OUT SREG, R2
				POP R2
			    POP R18
				POP ZH
				POP ZL

				RET

MOVE_DOWN:

	LDI ZH, 0x01

	LDI ZL, 0x0E ;ROW 1, lower block
	LD PAT_COL1, Z
	
	LDI ZL, 0x18 ;ROW 2, lower block
	LD DummyReg, Z
	LDI ZL, 0x0E
	ST Z, DummyReg

	LDI ZL, 0x22 ;ROW 3, lower block
	LD DummyReg, Z
	LDI ZL, 0x18
	ST Z, DummyReg

	LDI ZL, 0x2C ;ROW 4, lower block
	LD DummyReg, Z
	LDI ZL, 0x22
	ST Z, DummyReg

	LDI ZL, 0x36 ;ROW 5, lower block
	LD DummyReg, Z
	LDI ZL, 0x2C
	ST Z, DummyReg

	LDI ZL, 0x40 ;ROW 6, lower block
	LD DummyReg, Z
	LDI ZL, 0x36
	ST Z, DummyReg

	LDI ZL, 0x4A ;ROW 7, lower block
	LD DummyReg, Z
	LDI ZL, 0x40
	ST Z, DummyReg

	LDI ZL, 0x13 ;ROW 1, upper block
	LD DummyReg, Z
	LDI ZL, 0x4A
	ST Z, DummyReg

	LDI ZL, 0x1D ;ROW 2, upper block
	LD DummyReg, Z
	LDI ZL, 0x13
	ST Z, DummyReg

	LDI ZL, 0x27 ;ROW 3, upper block
	LD DummyReg, Z
	LDI ZL, 0x1D
	ST Z, DummyReg

	LDI ZL, 0x31 ;ROW 4, upper block
	LD DummyReg, Z
	LDI ZL, 0x27
	ST Z, DummyReg

	LDI ZL, 0x3B ;ROW 5, upper block
	LD DummyReg, Z
	LDI ZL, 0x31
	ST Z, DummyReg

	LDI ZL, 0x45 ;ROW 6, upper block
	LD DummyReg, Z
	LDI ZL, 0x3B
	ST Z, DummyReg

	LDI ZL, 0x4F ;ROW 7, upper block
	LD DummyReg, Z
	LDI ZL, 0x45
	ST Z, DummyReg

	LDI ZL, 0x4F ;ROW 7, upper block
	ST Z, PAT_COL1

	;Restoring Z
	LDI ZL, 0x00

RET

MOVE_UP:

	LDI ZH, 0x01

	LDI ZL, 0x4F ;ROW 7, upper block
	LD PAT_COL1, Z
	
	LDI ZL, 0x45 ;ROW 6, upper block
	LD DummyReg, Z
	LDI ZL, 0x4F
	ST Z, DummyReg

	LDI ZL, 0x3B ;ROW 5, upper block
	LD DummyReg, Z
	LDI ZL, 0x45
	ST Z, DummyReg

	LDI ZL, 0x31 ;ROW 4, upper block
	LD DummyReg, Z
	LDI ZL, 0x3B
	ST Z, DummyReg

	LDI ZL, 0x27 ;ROW 3, upper block
	LD DummyReg, Z
	LDI ZL, 0x31
	ST Z, DummyReg

	LDI ZL, 0x1D ;ROW 2, upper block
	LD DummyReg, Z
	LDI ZL, 0x27
	ST Z, DummyReg

	LDI ZL, 0x13 ;ROW 1, upper block
	LD DummyReg, Z
	LDI ZL, 0x1D
	ST Z, DummyReg

	LDI ZL, 0x4A ;ROW 7, lower block
	LD DummyReg, Z
	LDI ZL, 0x13
	ST Z, DummyReg

	LDI ZL, 0x40 ;ROW 6, lower block
	LD DummyReg, Z
	LDI ZL, 0x4A
	ST Z, DummyReg

	LDI ZL, 0x36 ;ROW 5, lower block
	LD DummyReg, Z
	LDI ZL, 0x40
	ST Z, DummyReg

	LDI ZL, 0x2C ;ROW 4, lower block
	LD DummyReg, Z
	LDI ZL, 0x36
	ST Z, DummyReg

	LDI ZL, 0x22 ;ROW 3, lower block
	LD DummyReg, Z
	LDI ZL, 0x2C
	ST Z, DummyReg

	LDI ZL, 0x18 ;ROW 2, lower block
	LD DummyReg, Z
	LDI ZL, 0x22
	ST Z, DummyReg

	LDI ZL, 0x0E ;ROW 1, lower block
	LD DummyReg, Z
	LDI ZL, 0x18
	ST Z, DummyReg

	LDI ZL, 0x0E ;ROW 1, lower block
	ST Z, PAT_COL1

	;Restoring Z
	LDI ZL, 0x00

RET





load_game_play_start:
	LDI ZL, 0x00
	LDI ZH, 0x01
	;oth ROW (Not displayed - dummy)
	LDI R16, MonsterNotGunPat
	STS 0x212, R16
	LDI R16, 0b00011111
	STS 0x213, R16
	LDI R16, ShipEnd
	STS 0x214, R16
	CALL InitScreenState

	;1st ROW
	LDI R16, 0b00011111
	STS 0x212, R16
	LDI R16, MonsterGunPat
	STS 0x213, R16
	LDI R16, 0b00000000
	STS 0x214, R16
	CALL InitScreenState 

	;2nd ROW
	LDI R16, 0b00011111
	STS 0x212, R16
	LDI R16, 0b00011111
	STS 0x213, R16
	LDI R16, 0b00000000
	STS 0x214, R16
	CALL InitScreenState

	;3rd ROW
	LDI R16, MonsterNotGunPat
	STS 0x212, R16
	LDI R16, 0b00011111
	STS 0x213, R16
	LDI R16, ShipEnd
	STS 0x214, R16
	CALL InitScreenState

	;4th ROW
	LDI R16, MonsterGunPat
	STS 0x212, R16
	LDI R16, MonsterNotGunPat
	STS 0x213, R16
	LDI R16, ShipMiddle
	STS 0x214, R16
	CALL InitScreenState

	;5th ROW
	LDI R16, 0b00011111
	STS 0x212, R16
	LDI R16, MonsterGunPat
	STS 0x213, R16
	LDI R16, ShipGun
	STS 0x214, R16
	CALL InitScreenState

	;6th ROW
	SECOND_ROW: 
	LDI R16, 0b00011111
	STS 0x212, R16
	LDI R16, 0b00011111
	STS 0x213, R16
	LDI R16, ShipMiddle
	STS 0x214, R16
	CALL InitScreenState

	; 7th ROW
	LDI R16, MonsterNotGunPat
	STS 0x212, R16
	LDI R16, 0b00011111
	STS 0x213, R16
	LDI R16, ShipEnd
	STS 0x214, R16
	CALL InitScreenState
 
	LDI ZL, 0x00 ; Reset
	LDI ZH, 0x01

RET

InitScreenState: 
	LDS R18,  0x212
	ST Z+, R18

	LDI R18, 0x00
	LDI R17, 4

	LOOP_BUFF: 
		ST Z+, R18
		DEC R17
	BRNE LOOP_BUFF
	LDS R18, 0x213
	ST Z+, R18
	LDI R18, 0x00
	LDI R17, 3
	LOOP_BUFF1_: 
		ST Z+, R18
		DEC R17
	BRNE LOOP_BUFF1_
	LDS R18, 0x214
	ST Z+, R18
RET ; Return to caller

;keyboard part
CONTEXT_SWITCH: LDI R16, 0xF0  ; Copy 0b1111 0000 to R16
			    LDI R17, 0x0F  ; Copy 0b0000 1111 to R17



			    OUT PORTD, R16 ; Set PORTD to R16
	            OUT DDRD, R17  ; Set DDRD to R17  	
			    RET ; Return to caller
;keyboard part
RESET_CONTEXT: LDI R16, 0x0F ; keyboard set
			   LDI R17, 0xF0

			   OUT PORTD, R16
		       OUT DDRD, R17
			   RET ; Return to caller


;Funtion to shift column data on for a pattern
execute_col_loop:
	CPI STATE_MACHINE, 0x03 ;Joystick went off - on - off 
	BREQ screenbuff_display ; game display
	CPI STATE_MACHINE, 0x04 ;Joystick went off - on - off 
	BREQ screenbuff_display ; game display
	;CPI STATE_MACHINE, 0x05 ;Joystick went off - on - off 
	;BREQ screenbuff_display ; game display
	;CPI STATE_MACHINE, 0x06 ;Joystick went off - on - off 
	;BREQ screenbuff_display ; game display
	
	;else display charbuffer:
	charcuffer_display:
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

		;Restoring Z pointer address before next row access

		LDI Local_index2, 16  ;index to shift screen 16 times for every screen block
		rev_loop1:
			;Decrement Z pointer by 8 to point to same row in next character
			LDI Local_index1,8
			rev_loop2:
				LD PAT_COL1, -Z
				DEC Local_index1
			BRNE rev_loop2
			DEC Local_index2
		BRNE rev_loop1
	
		;increment Z till RowIndex for a character is reached
		MOV Local_index1, RowIndex
		rev_loop3:
			LD PAT_COL1, -Z
			DEC Local_index1
		BRNE rev_loop3
	RET

	screenbuff_display:
		LDI Local_index2, 10  ;index to shift screen 80 times for every screen block
		Col_loop4:
			;shift 5bit Column pattern into Shift Reg
			LD PAT_COL1, Z
			LDI Local_index1, 8	
			Col_loop5: 
				CBI PORTB,3 ;pixel_off
				SBRC PAT_COL1, 0 ;pixel turned off if pattern's LSB is 0
				SBI PORTB,3	;pixel on
				CBI PORTB, 5 ;falling edge of shift-reg clock
				SBI PORTB, 5 ;rising edge of clk
				LSR PAT_COL1 ; right shifting pattern for next bit
				DEC Local_index1
			BRNE Col_loop5
			LD PAT_COL1, Z+	
			DEC Local_index2
		BRNE Col_loop4
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
	LDI Local_index1, 255 ;index for delay loop
	delay_loop:
		NOP
		DEC Local_index1
	BRNE delay_loop
	CBI PORTB, 4
RET

SHIFT_Z: LDI ZL, 0x0A
		   LDI ZH, 0x01
		    INC_LOOP: INC ZL
					DEC R20
					BRNE INC_LOOP
			
		    RET

BULLET_DELAY: LDI Local_index1, 100
	BLOOP:  NOP
	LDI R28, 0xFF
		BNESTED: NOP
				DEC R28
				BRNE BNESTED
	DEC Local_index1
	BRNE BLOOP
	RET

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
PUSH_PROTECT: PUSH ZL
			  PUSH ZH
			  PUSH R2
			  PUSH R18
			  PUSH R20
			  IN R2, SREG

POP_PROTECT: OUT SREG, R2
			 POP R20
			 POP R18
			 POP R2
			 POP ZH
			 POP ZL

TimerInterrupt: LDI R16, 0xFF
				LDI R17, 0xDF
				STS TCNT1L,R16
				STS TCNT1H,R17
				
				PUSH R18

				LDI R18, 1
				STS 0x0380, R18

				POP R18
				RETI

Timer0interrupt: LDI R17, 1
				 OUT TCNT0,R17
;				 ;CALL DISPLAY_INTERMEDIATE_STATE
				 CALL UPDATE_BULLETSTATE
;				 ;CALL CHECK_STATE
;				 LDI ZH,0x01
;				 LDI ZL,0x00
				 CBI PORTC, 2
				 RETI

JoystickInterrupt: ;CBI PORTC, 2
				   SBRS LAST_JOY, 0 ;skip state change if previous JS state was same as on
				   INC STATE_MACHINE
				   LDI LAST_JOY,0x01
				   LDI R16, 0x00
				   OUT PCIFR, R16 ; reset
				   RETI

;character memory table
;Stores >START!
;		  ----
CharTable1:
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

CharTable3:
.DB 0b00000, 0b00100, 0b00010, 0b00001, 0b00010, 0b00100, 0b00000, 0b00000 ;small arrow
.DB 0b00000, 0b00100, 0b00010, 0b00001, 0b00010, 0b00100, 0b00000, 0b00000 ;small arrow
.DB 0b01111, 0b01000, 0b01000, 0b01111, 0b01000, 0b01000, 0b01111, 0b00000 ;E
.DB 0b10001, 0b11011, 0b10101, 0b10001, 0b10001, 0b10001, 0b10001, 0b00000 ;M
.DB 0b00110, 0b01001, 0b01001, 0b01111, 0b01001, 0b01001, 0b01001, 0b00000 ;A
.DB 0b00110, 0b01001, 0b01000, 0b01011, 0b01001, 0b01001, 0b00110, 0b00000 ;G
.DB 0b00000, 0b00100, 0b00010, 0b00001, 0b00010, 0b00100, 0b00000, 0b00000 ;small arrow
.DB 0b00000, 0b00100, 0b00010, 0b00001, 0b00010, 0b00100, 0b00000, 0b00000 ;small arrow
.DB 0b00000, 0b00100, 0b00010, 0b00001, 0b00010, 0b00100, 0b00000, 0b00000 ;small arrow
.DB 0b00000, 0b00100, 0b00010, 0b00001, 0b00010, 0b00100, 0b00000, 0b00000 ;small arrow
.DB 0b01111, 0b01000, 0b01000, 0b01111, 0b01000, 0b01000, 0b01111, 0b00000 ;E
.DB 0b10001, 0b11011, 0b10101, 0b10001, 0b10001, 0b10001, 0b10001, 0b00000 ;M
.DB 0b00110, 0b01001, 0b01001, 0b01111, 0b01001, 0b01001, 0b01001, 0b00000 ;A
.DB 0b00110, 0b01001, 0b01000, 0b01011, 0b01001, 0b01001, 0b00110, 0b00000 ;G
.DB 0b00000, 0b00100, 0b00010, 0b00001, 0b00010, 0b00100, 0b00000, 0b00000 ;small arrow
.DB 0b00000, 0b00100, 0b00010, 0b00001, 0b00010, 0b00100, 0b00000, 0b00000 ;small arrow
.DB 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000 ;Nothing
.DB 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000 ;Nothing