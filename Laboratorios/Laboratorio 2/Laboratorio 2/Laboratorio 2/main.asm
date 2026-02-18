/*
* Contador4bits_Timer0.asm
*
* Creado: 11-Feb-26 12:51:20 PM
* Autor : Juan Daniel Sandoval Rodriguez
* Descripcion:
*   - Timer0 sigue marcando 100ms (internamente 1ms).
*   - Contador 4 bits (PB0..PB3) incrementa cada 1s.
*   - second_counter incrementa cada 1s.
*   - Cuando second_counter == digit7seg: second_counter se reinicia y se togglea LED D12 (PB4).
*
****************************************/
.include "M328PDEF.inc"

.dseg
.org SRAM_START
counter4bit:     .byte 1
digit7seg:       .byte 1
btn_prev:        .byte 1
second_counter:  .byte 1
second_ticks:    .byte 1
led_state:       .byte 1      ; 0x00 o (1<<PB4)

.cseg
.org 0x0000

/****************************************/
; Stack
LDI R16, LOW(RAMEND)
OUT SPL, R16
LDI R16, HIGH(RAMEND)
OUT SPH, R16

/****************************************/
; Setup
SETUP:
; PB0..PB3 LEDs contador, PB4 LED D12
LDI R16, 0x1F
OUT DDRB, R16

; Botones PC1/PC2 pull-up
LDI R16, (1<<PC1) | (1<<PC2)
OUT PORTC, R16

IN   R16, PINC
STS  btn_prev, R16

; Display 7 segmentos: D2..D7 salida
LDI R16, 0b11111100
OUT DDRD, R16

; PC0 (A0) salida (segmento G)
LDI R16, (1<<PC0)
OUT DDRC, R16

; Variables en 0
CLR R16
STS counter4bit, R16
STS digit7seg, R16
STS second_counter, R16
STS second_ticks, R16
STS led_state, R16

; Actualizar PORTB desde variables
CALL REFRESH_PORTB

; Registros auxiliares
CLR R17
CLR R18
CLR R19
CLR R20      ; R20 = contador 1ms (0..99)

/****************************************/
; TIMER0 SETUP
TIMER0_SETUP:
LDI R16, (1<<WGM01)
OUT TCCR0A, R16

LDI R16, (1<<CS01) | (1<<CS00)   ; prescaler 64
OUT TCCR0B, R16

LDI R16, 124                      ; 1ms
OUT OCR0A, R16

LDI R16, (1<<OCF0A)
OUT TIFR0, R16

/****************************************/
; MAIN LOOP
MAIN_LOOP:
    CALL TIMER_TICK_1MS
    CALL READ_BUTTONS_EDGE

    ; Si UP (bit0)
    SBRS R16, 0
    RJMP CHK_DOWN2
    CALL DIGIT_UP
    RJMP REFRESH

CHK_DOWN2:
    ; Si DOWN (bit1)
    SBRS R16, 1
    RJMP REFRESH
    CALL DIGIT_DOWN

REFRESH:
    CALL SHOW_DIGIT
    RJMP MAIN_LOOP

/****************************************/
; TIMER_TICK_1MS: cada 100ms llama UPDATE_SECOND
TIMER_TICK_1MS:
IN   R16, TIFR0
SBRS R16, OCF0A
RJMP NO_TICK

LDI  R16, (1<<OCF0A)
OUT  TIFR0, R16

INC  R20
CPI  R20, 100
BRNE NO_TICK

CLR  R20
CALL UPDATE_SECOND

NO_TICK:
RET

/****************************************/
; REFRESH_PORTB:
; PORTB = (counter4bit & 0x0F) | (led_state & (1<<PB4))
REFRESH_PORTB:
    LDS  R16, counter4bit
    ANDI R16, 0x0F

    LDS  R17, led_state
    ANDI R17, (1<<PB4)

    OR   R16, R17
    OUT  PORTB, R16
    RET

/****************************************/
; INC_COUNTER: incrementa counter4bit y refresca PORTB
INC_COUNTER:
    LDS  R16, counter4bit
    INC  R16
    ANDI R16, 0x0F
    STS  counter4bit, R16
    CALL REFRESH_PORTB
    RET

/****************************************/
; UPDATE_SECOND: se llama cada 100ms
UPDATE_SECOND:
    LDS  R16, second_ticks
    INC  R16
    CPI  R16, 10              ; 10 * 100ms = 1 segundo
    BRNE UPDATE_SAVE_100MS

    CLR  R16                  ; Reinicia ticks (pas? 1s)

    ; --- contador 4 bits cada 1s ---
    PUSH R16
    CALL INC_COUNTER
    POP  R16

    ; --- incrementar second_counter 0..15 ---
    LDS  R17, second_counter
    INC  R17
    ANDI R17, 0x0F
    STS  second_counter, R17

    ; --- comparar con digit7seg ---
    LDS  R18, digit7seg
    CP   R17, R18
    BRNE UPDATE_SAVE_1S

    ; iguales: reset second_counter
    CLR  R17
    STS  second_counter, R17

    ; toggle LED D12 (PB4)
    LDS  R19, led_state
    LDI  R22, (1<<PB4)
    EOR  R19, R22
    STS  led_state, R19

    ; aplicar el estado a PORTB (sin romper ticks)
    PUSH R16
    CALL REFRESH_PORTB
    POP  R16

UPDATE_SAVE_1S:
    STS  second_ticks, R16
    RET

UPDATE_SAVE_100MS:
    STS  second_ticks, R16
    RET

/****************************************/
; SHOW_DIGIT (tu misma tabla y SHOW igual)
SHOW_DIGIT:
    LDS  R18, digit7seg

    CPI  R18, 0
    BREQ DIG0
    CPI  R18, 1
    BREQ DIG1
    CPI  R18, 2
    BREQ DIG2
    CPI  R18, 3
    BREQ DIG3
    CPI  R18, 4
    BREQ DIG4
    CPI  R18, 5
    BREQ DIG5
    CPI  R18, 6
    BREQ DIG6
    CPI  R18, 7
    BREQ DIG7
    CPI  R18, 8
    BREQ DIG8
    CPI  R18, 9
    BREQ DIG9
    CPI  R18, 10
    BREQ DIGA
    CPI  R18, 11
    BREQ DIGB
    CPI  R18, 12
    BREQ DIGC
    CPI  R18, 13
    BREQ DIGD
    CPI  R18, 14
    BREQ DIGE
    RJMP DIGF

DIG0: ldi r16, 0b11000000  ;0
      rjmp SHOW
DIG1: ldi r16, 0b11111001  ;1
      rjmp SHOW
DIG2: ldi r16, 0b10100100  ;2
      rjmp SHOW
DIG3: ldi r16, 0b10110000  ;3
      rjmp SHOW
DIG4: ldi r16, 0b10011001  ;4
      rjmp SHOW
DIG5: ldi r16, 0b10010010  ;5
      rjmp SHOW
DIG6: ldi r16, 0b10000010  ;6
      rjmp SHOW
DIG7: ldi r16, 0b11111000  ;7
      rjmp SHOW
DIG8: ldi r16, 0b10000000  ;8
      rjmp SHOW
DIG9: ldi r16, 0b10010000  ;9
      rjmp SHOW
DIGA: ldi r16, 0b10001000  ;A
      rjmp SHOW
DIGB: ldi r16, 0b10000011  ;B
      rjmp SHOW
DIGC: ldi r16, 0b11000110  ;C
      rjmp SHOW
DIGD: ldi r16, 0b10100001  ;D
      rjmp SHOW
DIGE: ldi r16, 0b10000110  ;E
      rjmp SHOW
DIGF: ldi r16, 0b10001110  ;F
      rjmp SHOW

SHOW:
    ; G (bit6) -> PC0
    SBRS R16, 6
    CBI  PORTC, PC0
    SBRC R16, 6
    SBI  PORTC, PC0

    ; A..F (bits0..5) -> PORTD D2..D7
    IN   R18, PORTD
    ANDI R18, 0b00000011

    MOV  R19, R16
    ANDI R19, 0b00111111

    LSL  R19
    LSL  R19

    OR   R18, R19
    OUT  PORTD, R18
    RET

/****************************************/
; Botones
DIGIT_UP:
    LDS  R18, digit7seg
    INC  R18
    CPI  R18, 16
    BRLO UP_OK
    CLR  R18
UP_OK:
    STS  digit7seg, R18
    RET

DIGIT_DOWN:
    LDS  R18, digit7seg
    TST  R18
    BRNE DOWN_DEC
    LDI  R18, 15
    RJMP DOWN_SAVE
DOWN_DEC:
    DEC  R18
DOWN_SAVE:
    STS  digit7seg, R18
    RET

READ_BUTTONS_EDGE:
    IN   R18, PINC
    LDS  R19, btn_prev

    CLR  R16

    ; UP (PC1)
    SBRS R19, PC1
    RJMP CHK_DOWN
    SBRC R18, PC1
    RJMP CHK_DOWN
    ORI  R16, 1<<0

CHK_DOWN:
    ; DOWN (PC2)
    SBRS R19, PC2
    RJMP SAVE
    SBRC R18, PC2
    RJMP SAVE
    ORI  R16, 1<<1

SAVE:
    STS  btn_prev, R18
    RET
