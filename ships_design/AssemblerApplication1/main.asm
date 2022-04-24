.INCLUDE "m328pdef.inc"

.org 0x0000
rjmp init

.org 0x0020
rjmp TimerInterrupt



.EQU MonsterNotGunPat = 0b11111001
.EQU MonsterGunPat = 0b11111001
.EQU ShipGun = 0b0011111
.EQU ShipMiddle = 0b00111110
.EQU ShipEnd = 0b0010000

.EQU BTN8_PATTERN = 0b01111011 ; Button 8 pressed pattern
.EQU BTN7_PATTERN = 0b01110111 ; Button 7 pressed pattern
.EQU BTN5_PATTERN = 0b10111011 ; Button 5 pressed pattern
.EQU BTN4_PATTERN = 0b10110111 ; Button 4 pressed pattern
.EQU BTNA_PATTERN = 0b11100111 ; Button A pressed pattern
.EQU BTN0_PATTERN = 0b11101110 ; Button 0 pressed pattern
.EQU BTN1_PATTERN = 0b11010111 ; Button 1 pressed pattern
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
LDI R16, ShipEnd
STS 0x214, R16
RCALL InitScreenState
		

;2ND ROW
SECOND_ROW: 
LDI R16, 0b00011111
STS 0x212, R16
LDI R16, 0b00011111
STS 0x213, R16
LDI R16, ShipMiddle
STS 0x214, R16
CALL InitScreenState
            


;3RD ROW
LDI R16, 0b00011111
STS 0x212, R16
LDI R16, MonsterGunPat
STS 0x213, R16
LDI R16, ShipGun
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
LDI R16, MonsterNotGunPat
STS 0x212, R16
LDI R16, 0b00011111
STS 0x213, R16
LDI R16, ShipEnd
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

LDI YL, 0xB0
LDI YH, 0x08

main: CALL DISPLAY
	  CALL UPDATE_STATE

	RJMP CHECK_STATE
			 


CHECK_STATE: IN R18,PIND ; Copy PIND into R18
		     RCALL CONTEXT_SWITCH ; Call context switch (RCALL takes less instruction cycles than CALL)
		     IN R19,PIND ; Copy PIND into R19
		     RCALL RESET_CONTEXT ; Call reset context 
		     OR R18,R19 ; R18 OR R19 and store the result in R18

		     CPI R18,BTN4_PATTERN ; If button 4 is pressed
		     BREQ MOVE_DOWN

     		 CPI R18,BTN1_PATTERN ; If button 1 is pressed
		     BREQ MOVE_UP

		     CPI R18,BTNA_PATTERN ; If button A is pressed
		     BREQ SHOOT

			 RCALL SHOOT_BOSS

		     LDI R21, 0x01 ; reset to first row again
		     LDI ZL, 0x00
		     LDI ZH, 0x01
		     RJMP main

SHOOT: CALL SHIP_SHOOT
	   LDI R21, 0x01 ; reset to first row again
	   LDI ZL, 0x00
	   LDI ZH, 0x01
	   RJMP main

MOVE_DOWN:   
		CBI PORTC,2 ; Turn on top led

		
	 ; --------------- MOVE TO INTERMEDIATE STATE OF THE SCREEN ---------
			RCALL DISPLAY_INTERMEDIATE_STATE

		; -------------- CHECK IF SHIP IS AT THE END ----------------
		LDI ZL, 0x00 ; Start at 10
		LDI ZH, 0x01

		RCALL POINT65TH_BYTE ; can't read with ldd for over 63
		LD R16, Z

		CPI R16, ShipEnd
		BREQ FinishMoveDown
		    
       ; --------------- COPY PARTS OF THE SHIP TO POINTER X -----------
	   RCALL COPY_SHIP

		; -------------- MOVE DOWN ------------

		; ------------ FIRST ROW OF BLOCKS --------------
		LDI ZL, 0x00 
		LDI ZH, 0x01

		LDI XL, 0x20
		LDI XH, 0x02
		
		LDI R16, 0x00 ; send 0 to the first row
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

		RCALL POINT70TH_BYTE
      
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

		RCALL POINT65TH_BYTE
      
		LD R16, X+
		ST Z, R16

	   
	   RCALL AWAIT_KEYRELEASE
	   
	  FinishMoveDown: LDI R21, 0x01 ; reset to first row again
					  LDI ZL, 0x00
					  LDI ZH, 0x01
					  RJMP main
MOVE_UP:   
		CBI PORTC,2 ; Turn on top led
		
	 ; --------------- MOVE TO INTERMEDIATE STATE OF THE SCREEN ---------
			RCALL DISPLAY_INTERMEDIATE_STATE


		; -------------- CHECK IF SHIP IS AT THE END ----------------
		LDI ZL, 0x00 ; Start at 10
		LDI ZH, 0x01

		LDD R16, Z+9

		CPI R16, ShipEnd
		BREQ FinishMoveUp
		    
       ; --------------- COPY PARTS OF THE SHIP TO POINTER X -----------
	   RCALL COPY_SHIP
	  

		; -------------- MOVE UP ------------
		; ------------ FIRST ROW OF BLOCKS --------------
	  LDI ZL, 0x00
	  LDI ZH, 0x01

	  LDI XL, 0x20
	  LDI XH, 0x02

	  INC XL ;skip the first segment

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

	  RCALL POINT70TH_BYTE
      
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
	

	  RCALL POINT65TH_BYTE ; cant' write with std for over 63
	  LDI R16, 0x00 
	  ST Z, R16
	  
	  RCALL AWAIT_KEYRELEASE
	   
	  FinishMoveUp: LDI R21, 0x01 ; reset to first row again
					  LDI ZL, 0x00
					  LDI ZH, 0x01
					  RJMP main

COPY_SHIP: ; ------------ FIRST ROW OF BLOCKS --------------
		LDI ZL, 0x00 ; Start at 10
		LDI ZH, 0x01

		LDI XL, 0x20
		LDI XH, 0x02
		
		;LDI R16, 0x00
		;ST X+, R16

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

		RCALL POINT70TH_BYTE
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

		RCALL POINT65TH_BYTE
		LD R16, Z
		ST X+, R16

		RET

AWAIT_KEYRELEASE: DELAY: LDI R20, 0xFF
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
				   RET

POINT70TH_BYTE: LDI ZL, 0x00 
			   LDI ZH, 0x01
			   LDI R17, 69
			   READ70TH_LOOP: LD R16, Z+
					  DEC R17
					  BRNE READ70TH_LOOP
			
		        RET

POINT65TH_BYTE:  LDI ZL, 0x00
				LDI ZH, 0x01
				LDI R17, 64
				READ65TH_LOOP: LD R16, Z+
					  DEC R17
					  BRNE READ65TH_LOOP
				
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

SHOOT_BOSS: 
			LDI YL, 0xB4
			LDI YH, 0x08

			LDI ZL, 0x00
			LDI ZH, 0x01

			LDI R26, 10 ; 5 gun locations
			LDI R18, 25 ; Start at 35

			Bshootloop: LDI R16, 0x80
		 	; -------- FIND WHERE THE GUN IS ---
			RCALL SHIFT_Z
			LD R17, Z
			CPI R17, MonsterGunPat
			 
			RJMP BFIRE
			;------ MOVE TO NEXT PATH ------
			LDI R27, 10
			ADD R18, R27
			LDI ZL, 0x00
			LD R30, Y+
			DEC R26
			BRNE Bshootloop

			BFIRE:  LDI R16, 0x00
					LD R17, Y
				    LDI R17, 0x00
				  SHOOT1: ST Y+, R17


		  BEND_SHOOTING : RET
			

SHIP_SHOOT: 
	    ; -------------- START SHOOTING -------------------

		; -------------- -----------FIRST BLOC ------------------------------------------
		    LDI YL, 0xB0
			LDI YH, 0x08

			LDI ZL, 0x00
			LDI ZH, 0x01

			LDI R26, 2 ; 5 gun locations
			LDI R18, 49 ; Start at 30, to check the location of the gun

			shootloop: LDI R16, 0x80
		 				; -------- FIND WHERE THE GUN IS ---
						RCALL SHIFT_Z
						LD R17, Z
						CPI R17, ShipGun
			 
						BREQ FIRE
						;------ MOVE TO NEXT PATH ------
						LDI R27, 10
						ADD R18, R27
						LDI ZL, 0x00
						LD R30, Y+
						DEC R26
						BRNE shootloop

			; -------------- -----------SECOND BLOC ------------------------------------------
			
			LDI R26, 2 ; 5 gun locations
			LDI R18, 14 ; Start at 5, to check the location of the gun

			shootloop2: LDI R16, 0x80
		 				; ------ FIND WHERE THE GUN IS ----
						RCALL SHIFT_Z
						LD R17, Z
						CPI R17, ShipGun 
						BREQ FIRE
						;------ MOVE TO NEXT PATH ----------
						LDI R27, 10
						ADD R18, R27
						LDI ZL, 0x00
						LD R30, Y+
						DEC R26
						BRNE shootloop2
						RJMP END_SHOOTING
			; --------------------------- FIRE -------------------------
			FIRE: LDI R16, 0x80
				  ST Y, R16

		  END_SHOOTING : RET
		  test: SBI DDRC, 3
				CBI PORTC,3



UPDATE_STATE: LDI YL, 0xB0
			 LDI YH, 0x08 
			 LDI ZL, 0x00
			 LDI ZH, 0x01
		
		; ---------------------------------------FIRST BLOC ----------------------------
       LDI R19, 2 ; 5 BULLET PATHS
       LDI R18, 48 ; FIRST PATH ADDRESS

       TRACE_BULLET: RCALL SHIFT_Z
               RCALL BULLET_PATH
               LDI R25, 10
               ADD R18, R25

               LDI ZL, 0x00
               DEC  R19
               BRNE TRACE_BULLET


       LDI ZL, 0x00
       LDI ZH, 0x01


      ; ----------------- --------------SECOND BLOC -------------------------------------------
   
      LDI ZL, 0x00
      LDI R19, 2 ; 10 BULLET PATHS
      LDI R18, 13 ; FIRST PATH ADDRESS

       TRACE_BULLET2: RCALL SHIFT_Z
               RCALL BULLET_PATH
               LDI R25, 10
               ADD R18, R25

               LDI ZL, 0x00
               DEC  R19
               BRNE TRACE_BULLET2

	  ; -------------------- BOSS BULLETS -----------------------
       ;-------------- FIRST BLOC ----------------------
       LDI ZL, 0x00
       LDI R19, 2 ; 5 BULLET PATHS
       LDI R18, 26 ; FIRST PATH ADDRESS

       BTRACE_BULLET: RCALL SHIFT_Z
               RCALL BOSSBULLET_PATH
               LDI R25, 10
               ADD R18, R25

               LDI ZL, 0x00
               DEC  R19
               BRNE BTRACE_BULLET

      LDI YL, 0xB0
       LDI YH, 0x08

       LDI R16, 0x00
       LDI R17, 20
       RESET: ST Y+, R16
          DEC R17
          BRNE RESET

			 RCALL BULLET_DELAY
			 RET

SHIFT_Z:  NOP
		  STS 0x260, R18
		  LDS R25, 0x260
			SHIFT:  INC ZL
					DEC R25
					BRNE SHIFT
			RET


BOSSBULLET_PATH: LD R16, Z
			  LD R17, Y+
			  OR R16, R17

			  LSL R16
			  ST Z+, R16
			BRCC BNextByte

			LDI R16, 0x01
			ST Z, R16

			BNextByte: LD R16, Z
					LSL R16
					ST Z+, R16
			BRCC BNextByte2

			LDI R16, 0x01
			ST Z, R16
			
		BNextByte2: LD R16, Z
					LSL R16
					ST Z, R16


			  RET

BULLET_PATH:  LD R16, Z
			  LD R17, Y+
			  OR R16, R17

			  LSR R16
			  ST Z, R16	  
			  DEC ZL
			  BRCC NextByte

			LDI R16, 0x80
			ST Z, R16

			NextByte:  LD R16, Z
					LSR R16
					ST Z, R16
					DEC ZL
			BRCC NextByte2

			LDI R16, 0x80
			ST Z, R16
			
		NextByte2: LD R16, Z
					LSR R16
					ST Z, R16
			  
			  RET

BULLET_DELAY: LDI R20, 0x0F
	BLOOP:  NOP
		LDI R28, 0xFF
		BNESTED: NOP
				DEC R28
				BRNE BNESTED
	DEC R20
	BRNE BLOOP
	RET

TimerInterrupt: LDI R16, 250
				OUT TCNT0,R16
				CBI PORTB, 4
				RETI

