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
.DEF Local_index1 = R17
.DEF local_index2 = R18
.DEF PAT_COL1   = R19 ;Temporary Pattern for column
.DEF DummyReg   = R20
.DEF BOSS_SHIPCOUNTER = R25 ; Current active gun index of the boss

.EQU MonsterNotGunPat = 0b11111001
.EQU MonsterGunPat = 0b11111001
.EQU ShipGun = 0b0011111
.EQU ShipMiddle = 0b00111110
.EQU ShipEnd = 0b0010000
.EQU boss_shoot_status = 0x0380
.EQU Ship_life = 0x0381   ; Global var to store life of ship
.EQU boss_life = 0x0382   ; Global var to store life of boss ship
.EQU SCREEN_STATE = 0x0383  ; Global var to store which screen to display from screen patterns (defined below)
.EQU JOY_STK_STATE = 0x0384 ; Global var to store state of joystick whether low or high
.EQU LAST_KEY = 0x0385    ; Global var to store state of keyboard last pressed
.EQU RowIndex = 0x0386    ; Global var to store Index used to count row number in display
.EQU BUZZ_PATTERN = 0x0387  ; Global var to store key pattern for buzzer sound

;.EQU RANDOM_MASK = 0x0388 ; Bit mask for random bit generation tap.
.EQU SEED = 9 ; Random seed for random bit generation
.EQU RANDOM_NUMBER = 0x0388 ; Random number resulting from PSRG

;keyboard patterns
.EQU BTN8_PATTERN = 0b01111011 ; Button 8 pressed pattern
.EQU BTN7_PATTERN = 0b01110111 ; Button 7 pressed pattern
.EQU BTN5_PATTERN = 0b10111011 ; Button 5 pressed pattern
.EQU BTN4_PATTERN = 0b10110111 ; Button 4 pressed pattern
.EQU BTN2_PATTERN = 0b11011011 ; Button 2 pressed pattern
.EQU NOBTN_PATTERN =  0b11111111 ; No button preesed pattern
.EQU OTHER_PATTERN = 0b00110011 ; Pattern for the rest of the buttons
.EQU SHIP_DAMAGE = 0b11 ; Pattern checked by buzzer for ship damage
.EQU BOSS_DAMAGE = 0b101 ; Pattern checked by buzzer for boss damage

;Screen states
.EQU start_screen = 0x01  ;State for displaying start screen
.EQU game_screen = 0x02   ;State for displaying game screen
.EQU over_screen = 0x03   ;State for displaying game over screen
.EQU win_screen = 0x04    ;State for displaying victory!

;Variables
.EQU ShipLifeLine = 0x4E  ;Location of ship lifeline on screenbuffer
.EQU BossLifeLine = 0x4C  ;Location of boss lifeline on screenbuffer
.EQU Lives_ship_5 = 0b11000000 ;lives remaining
.EQU Lives_boss_5 = 0b00011111 ;lives remaining

; Interrupts
.ORG 0x0006
rjmp JoystickInterrupt

.ORG 0x0012
rjmp Timer2interrupt

.org 0x001A
rjmp Timer1Interrupt

.ORG 0x0020
rjmp Timer0interrupt



Init:
; Configure output pin PB3
SBI DDRB, 3 ; Pin PB3 is an output: Data pin SDI (Serial Data In)
SBI DDRB, 4 ; Pin PB4 is an output: Latch/Output pin: LE(Latch Enable) + OE(Output Enable)
SBI DDRB, 5 ; Pin PB5 is an output: Clock pin CLK

CBI DDRB, 0 ; switch to shut down the buzzer
SBI PORTB, 0

; Configure input joystick pin PB2
CBI DDRB,2; pin an input switch
SBI PORTB,2;Enable the pull-up resistor

;enabling keyboard input
LDI R16, 0x0F
LDI R17, 0xF0
OUT DDRD, R17
OUT PORTD, R16 ; Init keyboard. set all rows to ground and cols to 1

;LED
SBI DDRC, 2
SBI PORTC,2

;configure output buzzer in PB1
SBI DDRB,1; output pin
CBI PORTB,1 ; pull-down buzzer by default

; INIT THE STACK !
LDI R16, HIGH (RAMEND)
OUT SPH, R16
LDI R16, LOW (RAMEND)
OUT SPL, R16

;Initializing state machine
LDI DummyReg, 0x01
STS SCREEN_STATE, DummyReg
LDI DummyReg, 0x00
STS JOY_STK_STATE, DummyReg
STS LAST_KEY, DummyReg
LDI DummyReg, SEED
STS RANDOM_NUMBER, DummyReg ; init random number to be the seed



;Establishing start screen
CALL Load_game_play_start

SEI ;Set golabl interrupt
; timer1Interrupt /* Timer interrupt enabled inside machine state*/

LDI R16, 0x05
STS TCCR2B, R16 ;prescaler timer 2
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
Main:
  CALL display
  CALL load_screen_state
  SBI PORTC,2
  LDS R18, boss_shoot_status
  CPI R18, 1
  BRNE Main
  CALL BOSS_SHOOT
RJMP Main


Display:
  LDI DummyReg, 0x08
  STS RowIndex, DummyReg
  Send1Row:
    CALL execute_col_loop
    CALL execute_row_loop
    CALL Latch_shift_reg

    ;Decrement RowIndex
    LDS DummyReg, RowIndex
    DEC DummyReg
    STS RowIndex, DummyReg
  BRNE Send1Row
RET



Load_screen_state:
  LDS DummyReg, SCREEN_STATE
  CPI DummyReg, start_screen
  BREQ load_start_screen
  CPI DummyReg, game_screen
  BREQ load_game_screen
  CPI DummyReg, over_screen
  BREQ load_over_screen
  CPI DummyReg, win_screen
  BREQ load_win_screen
  RET
  load_start_screen:
    LDI ZH, high(CharTable1<<1)
    LDI ZL, low(CharTable1<<1)
    LDI DummyReg, Lives_ship_5
    STS ship_life, DummyReg
    LDI DummyReg, Lives_boss_5
    STS boss_life, DummyReg
    ;----------------------------------------------
    ;-------------Disable timers for this state
    LDI R16, 0x00
    STS TIMSK1, R16 ;timer1 interrupt disable
    STS TIMSK0, R16 ; timer0 interrupt disable
    STS TIMSK2, R16 ; timer2 interrupt disable
    ;---------------------------------------------
  RET
  load_game_screen:
    LDI R16, 0x01
    STS TIMSK1, R16 ; timer1 interrupt enable
    STS TIMSK0, R16 ; timer0 interrupt enable
    STS TIMSK2, R16 ; timer2 interrupt enable
    CALL CHECK_STATE
    LDI ZH,0x01
    LDI ZL,0x00
  RET
  load_over_screen:
    LDI R16, 0x00
    STS TIMSK1, R16 ;timer1 interrupt disable
    STS TIMSK0, R16 ; timer0 interrupt disable
    STS TIMSK2, R16 ; timer2 interrupt disnable
    LDI ZH, high(CharTable2<<1)
    LDI ZL, low(CharTable2<<1)

  RET
  load_win_screen:
    LDI R16, 0x00
    STS TIMSK1, R16 ; timer1 interrupt disable
    STS TIMSK0, R16 ; timer0 interrupt disable
    STS TIMSK2, R16 ; timer2 interrupt enable
    LDI ZH, high(CharTable3<<1)
    LDI ZL, low(CharTable3<<1)
  RET

CHECK_STATE:
       IN R18,PIND ; Copy PIND into R18
         RCALL CONTEXT_SWITCH ; Call context switch (RCALL takes less instruction cycles than CALL)
         IN R19,PIND ; Copy PIND into R19
         RCALL RESET_CONTEXT ; Call reset context
         OR R18,R19 ; R18 OR R19 and store the result in R18
       STS BUZZ_PATTERN, R18 ;Storing key pattern

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
        LDI DummyReg, 0x02
        STS LAST_KEY, DummyReg
       RET

       state_plus_8:
        LDI DummyReg, 0x04
        STS LAST_KEY, DummyReg
       RET

       state_plus_5:
        LDI DummyReg, 0x06
        STS LAST_KEY, DummyReg
       RET

       reset_key_state:
        LDS DummyReg, LAST_KEY
        CPI DummyReg,0x02 ; If button 2 is pressed
        BREQ go_down
        CPI DummyReg,0x04 ; if button 8 is pressed
        BREQ go_up
        CPI DummyReg,0x06 ; if button 5 is pressed
        BREQ ship_shoot
       RET

       go_down:
        LDI DummyReg, 0x00
        STS LAST_KEY, DummyReg
        CALL MOVE_DOWN
       RET

       go_up:
        LDI DummyReg, 0x00
        STS LAST_KEY, DummyReg
        CALL MOVE_UP
       RET

       ship_shoot:
        LDI DummyReg, 0x00
        STS LAST_KEY, DummyReg
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
          LDI R20, 19 ; 4th upper row            ;xxxxx
          CALL SHIFT_Z
          CALL TRACE_BULLET

          LDI XL, 0x9C ; BOSS GUN !
          LDI R20, 9 ; 5th upper row              ;xxxxxxx  x
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
          CALL lifeline_to_screenbuff


      finish_update:  OUT SREG, R2
              POP R2
              POP R20
              POP R18
              POP ZH
              POP ZL
              RET

TRACE_BULLET:
      LD R16, Y ; ship bullet
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
           BRCC boss_not_hit

          ; ---- Check if boss is hit
          DEC ZL
          LD R18, Z
          CPI R18, MonsterGunPat
          BREQ bossDamaged
          INC ZL
          ; --------------

           boss_not_hit:
            CLC
            LSL R17
            ST X, R17
            BRCC finish_trace ; problem here regarding X
              LDI R17, 0x01
           ST -X, R17  ; move the boss bultt to the next byte if carry is set



        finish_trace: RET
        ; -- if bullets collapse => reset ---
        bullets_collapse: LDI R16, 0x00
                  ST Y, R16
                  ST X, R16
                  RET
        ; --- if ship is hit by boss bullet -------
        shipDamaged: LDS R18, ship_life
               LSL R18
               BREQ game_over
               STS ship_life, R18
               RET

               game_over: LDI DummyReg, over_screen
                    STS SCREEN_STATE, DummyReg
                    RET

         ; ----- Check if boss is hit by ship bullet ---------------
         bossDamaged:  LDS R18, boss_life
               LSR R18
               BREQ game_victory
               STS boss_life, R18
               RET

               game_victory: LDI DummyReg, win_screen
                    STS SCREEN_STATE, DummyReg
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

BOSS_SHOOT:   LDI XH, 0x02
        PUSH ZL
        PUSH ZH
          PUSH R18
          PUSH R2
        IN R2, SREG

    LDS DummyReg, RANDOM_NUMBER

        CPI DummyReg, 11
        BREQ PAT1
        CPI DummyReg, 15
        BREQ PAT2
        CPI DummyReg, 3
        BREQ PAT3
        CPI DummyReg, 1
        BREQ PAT4
        CPI DummyReg, 7
        BREQ PAT5
        CPI DummyReg, 9
        BREQ PAT6

        ;LDI BOSS_SHIPCOUNTER, 6 ; reset
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

        ;CALL UPDATE_BULLETSTATE
      LDI R18, 0
      STS boss_shoot_status, R18

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

  ;Loading initial life line display
  CALL lifeline_to_screenbuff

  LDI ZL, 0x00 ; Reset
  LDI ZH, 0x01

RET
lifeline_to_screenbuff:
  LDS DummyReg, ship_life
  LDI ZH, 0x01
  LDI ZL, ShipLifeLine
  ST Z, DummyReg
  LDS DummyReg, boss_life
  LDI ZL, BossLifeLine
  ST Z, DummyReg
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
  LDS DummyReg, SCREEN_STATE
  CPI DummyReg, game_screen
  BREQ screenbuff_display
  RJMP charbuff_display

  charbuff_display:
    ;increment Z till RowIndex for a character is reached
    LDS Local_index1, RowIndex
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
        SBI PORTB,3 ;pixel on
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
    LDS Local_index1, RowIndex
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
        SBI PORTB,3 ;pixel on
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
    LDS DummyReg, RowIndex
    CP Local_index1,DummyReg
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
        PUSH R24
        IN R2, SREG
        RET

POP_PROTECT: OUT SREG, R2
       POP R24
       POP R20
       POP R18
       POP R2
       POP ZH
       POP ZL

       RET

;R0 and R24 re reserved for this timer interrupt
;Please use them elsewhere cautiously
Timer2Interrupt:
  PUSH R0
  PUSH R1
  IN R0, SREG

  ;IN R1, PINB
  ;BST R1, 0
  ;BRTS silence

  LDS R24, BUZZ_PATTERN
  CPI R24, BTN8_PATTERN
  BREQ MoveKeyPressed
  CPI R24, BTN5_PATTERN
  BREQ ShootKeyPressed
  CPI R24, BTN2_PATTERN
  BREQ MoveKeyPressed
  RJMP DefaultSound

  MoveKeyPressed:
    LDI R24, 0x2E
    STS TCNT2, R24
    SBI PINB, 1 ; toggle output of PB1 by setting PINB,1
    OUT SREG, R0
  POP R0
  POP R1
    RETI
  ShootKeyPressed:
    LDI R24, 248
    STS TCNT2, R24
    SBI PINB, 1 ; toggle output of PB1 by setting PINB,1
    OUT SREG, R0
  POP R0
  POP R1
    RETI
  DefaultSound:
    LDI R24, 0xFF
    STS TCNT2, R24
    ;SBI PINB, 1 ; toggle output of PB1 by setting PINB,1
  CBI PORTB, 0 ; sshut the buzzer
    OUT SREG, R0
  POP R0
  POP R1
    RETI

  silence: CBI PORTB, 0
       LDI R24, 0xFF
       STS TCNT2, R24
       POP R0
       POP R1
        RETI

Timer1Interrupt: LDI R16, 0xFF
        LDI R17, 0xEF
        STS TCNT1L,R16
        STS TCNT1H,R17

		PUSH R2
        PUSH R18
		PUSH R16
		IN R2, SREG

        LDI R18, 1
        STS boss_shoot_status, R18

		; ----- Generate next random number ---------
        ;DEC BOSS_SHIPCOUNTER
		LDS R16, RANDOM_NUMBER
		 LDS DummyReg, RANDOM_NUMBER
		 LSR R16
		 EOR DummyReg, R16
		 ANDI DummyReg, 1 ; newly generated random bit

		 LSL DummyReg
		 LSL DummyReg
		 LSL DummyReg

		 OR DummyReg, R16
		 STS RANDOM_NUMBER, DummyReg

		 OUT SREG, R2

        POP R16
		POP R18
		POP R2
        RETI

Timer0interrupt: LDI R17, 1
         OUT TCNT0,R17
;        ;CALL DISPLAY_INTERMEDIATE_STATE
         CALL UPDATE_BULLETSTATE
;        ;CALL CHECK_STATE
;        LDI ZH,0x01
;        LDI ZL,0x00
         CBI PORTC, 2
         RETI

JoystickInterrupt:
          LDS DummyReg, SCREEN_STATE
          CPI DummyReg, game_screen ; while playing can't switch state here
          BRNE next_state
          RETI

          next_state: LDS DummyReg, JOY_STK_STATE   ;Stores last state of joystick for change after two actions on interrupt
          SBRS DummyReg, 0        ; skip state increase if previous state was joy stick not pressed
          CALL increment_state
          LDS DummyReg, JOY_STK_STATE
          INC DummyReg
          STS JOY_STK_STATE, DummyReg
            LDI R16, 0x00
            OUT PCIFR, R16 ; reset interrupt
          RETI

increment_state:
  LDS DummyReg, SCREEN_STATE
  CPI DummyReg, start_screen
  BREQ to_next_state
  ;CPI DummyReg, game_screen
  ;BREQ to_next_state
  CPI DummyReg, over_screen
  BREQ to_start_state
  CPI DummyReg, win_screen
  BREQ to_start_state

  to_next_state:
    INC DummyReg
    STS SCREEN_STATE, DummyReg
    RET
  to_start_state:
    LDI DummyReg, start_screen
    STS SCREEN_STATE, DummyReg
    RET

;character memory table
;Stores >START!
;     ----
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
.DB 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000 ;Nothing
.DB 0b00000, 0b00100, 0b01110, 0b11011, 0b01110, 0b00100, 0b00000, 0b00000 ;Diamond
.DB 0b00000, 0b00100, 0b01110, 0b11011, 0b01110, 0b00100, 0b00000, 0b00000 ;Diamond
.DB 0b00000, 0b00100, 0b01110, 0b11011, 0b01110, 0b00100, 0b00000, 0b00000 ;Diamond
.DB 0b00000, 0b00100, 0b01110, 0b11011, 0b01110, 0b00100, 0b00000, 0b00000 ;Diamond
.DB 0b00000, 0b00100, 0b01110, 0b11011, 0b01110, 0b00100, 0b00000, 0b00000 ;Diamond
.DB 0b00000, 0b00100, 0b01110, 0b11011, 0b01110, 0b00100, 0b00000, 0b00000 ;Diamond
.DB 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000 ;Nothing
.DB 0b10001, 0b10001, 0b11001, 0b10101, 0b10011, 0b10001, 0b10001, 0b10000 ;N
.DB 0b01110, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b01110, 0b00000 ;I
.DB 0b10001, 0b10001, 0b10001, 0b10001, 0b10101, 0b11011, 0b10001, 0b00000 ;W
.DB 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000 ;Nothing
.DB 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000 ;Nothing
.DB 0b01001, 0b01001, 0b01001, 0b01001, 0b01001, 0b01001, 0b00110, 0b00000 ;U
.DB 0b00110, 0b01001, 0b01001, 0b01001, 0b01001, 0b01001, 0b00110, 0b00000 ;0
.DB 0b10001, 0b01010, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100 ;Y
