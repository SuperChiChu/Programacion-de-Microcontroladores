/*
* Laboratorio_3.asm
*
* Creado: 19-Feb-26
* Autor : Juan Daniel Sandoval Rodriguez
* Descripcion:
*   - Contador manual 4 bits (LEDs) solo con botones
*   - Reloj de segundos 0..59 en dos displays 7 segmentos (unidades y decenas)
*   - 2 Displays 7 segmentos Catodo Comun con multiplex NPN
*   - Debounce de botones por software (50ms)
****************************************/
.include "M328PDEF.inc"

; Constantes
.equ DEBOUNCE_TIME = 5   ; 50 ms (asumiendo ticks de 10ms)

.dseg
.org SRAM_START
counter4bit: .byte 1      ; contador manual para LEDs
btn_prevC:   .byte 1      ; estado anterior de botones
btn_flags:   .byte 1      ; flags de botones (bit0 inc, bit1 dec)
ticks10ms:   .byte 1      ; contador de ticks de 10ms para segundos
seconds_units: .byte 1    ; unidades de segundos (0-9)
seconds_tens:  .byte 1    ; decenas de segundos (0-5)
disp_pat1:    .byte 1     ; patron para display 1 (unidades)
disp_pat2:    .byte 1     ; patron para display 2 (decenas)
mux_state:    .byte 1     ; estado del multiplexor (0=display1, 1=display2)
last_inc_time: .byte 1    ; Ultimo tick de pulsacion incremento (debounce)
last_dec_time: .byte 1    ; Ultimo tick de pulsacion decremento

.cseg
.org 0x0000
    rjmp START

.org 0x0008
    rjmp ISR_PCINT1

.org 0x001C
    rjmp ISR_T0_COMPA

;==================== STACK ====================
START:
    ldi r16, LOW(RAMEND)
    out SPL, r16
    ldi r16, HIGH(RAMEND)
    out SPH, r16

;==================== SETUP ====================
SETUP:
    clr r16
    sts counter4bit, r16
    sts btn_flags, r16
    sts ticks10ms, r16
    sts seconds_units, r16
    sts seconds_tens, r16
    sts mux_state, r16
    sts last_inc_time, r16
    sts last_dec_time, r16

; LEDs PB0,PB1,PB4 + EN1 PB2 + EN2 PB3
    ldi r16, 0b00011111
    out DDRB, r16

; Segmentos PD0..PD6
    ldi r16, 0b01111111
    out DDRD, r16

; PC2 salida (LED3), PC0 PC1 botones
    ldi r16, 0b00000100
    out DDRC, r16

; Pull-ups botones
    ldi r16, 0b00000011
    out PORTC, r16

; Inicializar puertos de salida a 0 (apagar todo)
    clr r16
    out PORTB, r16      ; LEDs y enables apagados
    out PORTD, r16      ; segmentos apagados
    ; PORTC: solo bit2 es salida, lo ponemos a 0
    in r16, PORTC
    andi r16, 0b11111011
    out PORTC, r16

; Guardar estado inicial botones
    in r16, PINC
    sts btn_prevC, r16

; PCINT1 habilitar
    ldi r16, 0b00000010
    sts PCICR, r16

    ldi r16, 0b00000011
    sts PCMSK1, r16

; Timer0 CTC 10ms
    ldi r16, 0
    out TCCR0A, r16

    ldi r16, (1<<WGM01)
    out TCCR0A, r16

    ldi r16, 155
    out OCR0A, r16

    clr r16
    out TCNT0, r16

    ldi r16, (1<<OCIE0A)
    sts TIMSK0, r16

    ldi r16, (1<<CS02)|(1<<CS00)
    out TCCR0B, r16

    sei

;==================== MAIN ====================
MAIN_LOOP:

    lds r16, btn_flags

    sbrs r16, 0
    rjmp CHECK_DOWN
    andi r16, 0b11111110
    sts btn_flags, r16
    rcall INC_COUNTER4

CHECK_DOWN:
    lds r16, btn_flags

    sbrs r16, 1
    rjmp REFRESH
    andi r16, 0b11111101
    sts btn_flags, r16
    rcall DEC_COUNTER4

REFRESH:
    rcall REFRESH_LEDS
    rjmp MAIN_LOOP

;==================== CONTADOR MANUAL ====================
INC_COUNTER4:
    lds r16, counter4bit
    inc r16
    andi r16, 0b00001111
    sts counter4bit, r16
    ret

DEC_COUNTER4:
    lds r16, counter4bit
    tst r16
    brne DEC_OK
    ldi r16, 15
    rjmp DEC_SAVE
DEC_OK:
    dec r16
DEC_SAVE:
    sts counter4bit, r16
    ret

;==================== LEDs ====================
REFRESH_LEDS:
    cli                     ; Proteger contra interrupciones
    lds r16, counter4bit
    andi r16, 0b00001111

    in r17, PORTB
    andi r17, 0b11101100    ; Limpiar bits PB0,PB1,PB4

    sbrc r16,0
    ori r17,0b00000001
    sbrc r16,1
    ori r17,0b00000010
    sbrc r16,2
    ori r17,0b00010000
    out PORTB, r17

    in r18, PORTC
    andi r18, 0b11111011    ; Limpiar PC2
    sbrc r16,3
    ori r18, 0b00000100
    out PORTC, r18
    sei
    ret

;==================== ISR BOTONES ====================
ISR_PCINT1:
    push r16
    push r17
    push r18
    push r19

    in r16, PINC
    lds r17, btn_prevC
    mov r18, r16
    eor r18, r17            ; r18 = cambios
    sts btn_prevC, r16

    ; Boton incremento (PC0)
    sbrs r18, 0
    rjmp CHECK_D
    sbrc r16, 0             ; Si esta en 0 (presionado)
    rjmp CHECK_D
    ; Flanco de bajada detectado
    lds r18, ticks10ms      ; tiempo actual
    lds r19, last_inc_time
    sub r18, r19
    cpi r18, DEBOUNCE_TIME
    brlo CHECK_D             ; Si no ha pasado el tiempo, ignorar
    lds r19, ticks10ms
    sts last_inc_time, r19   ; actualizar Ultimo tiempo
    lds r17, btn_flags
    ori r17, 0b00000001
    sts btn_flags, r17

CHECK_D:
    ; Boton decremento (PC1)
    sbrs r18, 1
    rjmp END_ISR
    sbrc r16, 1
    rjmp END_ISR
    ; Flanco de bajada detectado
    lds r18, ticks10ms
    lds r19, last_dec_time
    sub r18, r19
    cpi r18, DEBOUNCE_TIME
    brlo END_ISR
    lds r19, ticks10ms
    sts last_dec_time, r19
    lds r17, btn_flags
    ori r17, 0b00000010
    sts btn_flags, r17

END_ISR:
    pop r19
    pop r18
    pop r17
    pop r16
    reti

;==================== ISR TIMER ====================
ISR_T0_COMPA:
    push r16
    push r17
    in r16, SREG
    push r16

    lds r16, ticks10ms
    inc r16
    sts ticks10ms, r16

    cpi r16, 100            ; 1 segundo?
    brne MUX

    clr r16
    sts ticks10ms, r16

    ; Incrementar contador de segundos
    lds r16, seconds_units
    inc r16
    cpi r16, 10
    brne SAVE_UNITS
    ; unidades llegaron a 10
    clr r16                 ; unidades = 0
    lds r17, seconds_tens
    inc r17
    cpi r17, 6
    brne SAVE_TENS
    ; llega a 60, reiniciar ambos
    clr r17
SAVE_TENS:
    sts seconds_tens, r17
SAVE_UNITS:
    sts seconds_units, r16

    ; Convertir unidades a patron
    mov r16, r16            ; ya esta en r16
    rcall HEX_TO_PAT
    sts disp_pat1, r16

    ; Convertir decenas a patron
    lds r16, seconds_tens
    rcall HEX_TO_PAT
    sts disp_pat2, r16

MUX:
    ; Alternar display cada 10ms
    lds r16, mux_state
    ldi r17, 0b00000001
    eor r16, r17
    sts mux_state, r16

    sbrc r16, 0
    rjmp DISP2

DISP1:
    lds r16, disp_pat1
    rcall OUT_SEG
    in r17, PORTB
    andi r17, 0b11110011     ; Limpiar enables
    ori r17, 0b00000100      ; Activar EN1 (PB2)
    out PORTB, r17
    rjmp END_T

DISP2:
    lds r16, disp_pat2
    rcall OUT_SEG
    in r17, PORTB
    andi r17, 0b11110011
    ori r17, 0b00001000      ; Activar EN2 (PB3)
    out PORTB, r17

END_T:
    pop r16
    out SREG, r16
    pop r17
    pop r16
    reti

;==================== SEGMENTOS ====================
OUT_SEG:
    andi r16, 0b01111111    ; Asegurar que el bit7 (PD7) no se use
    in r17, PORTD
    andi r17, 0b10000000    ; Conservar solo PD7 (no usado)
    or r17, r16
    out PORTD, r17
    ret

;==================== TABLA HEX ====================
HEX_TO_PAT:
    andi r16, 0b00001111

    cpi r16, 0
    breq P0
    cpi r16, 1
    breq P1
    cpi r16, 2
    breq P2
    cpi r16, 3
    breq P3
    cpi r16, 4
    breq P4
    cpi r16, 5
    breq P5
    cpi r16, 6
    breq P6
    cpi r16, 7
    breq P7
    cpi r16, 8
    breq P8
    cpi r16, 9
    breq P9
    cpi r16, 10
    breq PA
    cpi r16, 11
    breq PB
    cpi r16, 12
    breq PATC
    cpi r16, 13
    breq PD_
    cpi r16, 14
    breq PE
    rjmp PF

P0: ldi r16, 0b00111111 ;0
    ret
P1: ldi r16, 0b00000110 ;1
    ret
P2: ldi r16, 0b01011011 ;2
    ret
P3: ldi r16, 0b01001111 ;3
    ret
P4: ldi r16, 0b01100110 ;4
    ret
P5: ldi r16, 0b01101101 ;5
    ret
P6: ldi r16, 0b01111101 ;6
    ret
P7: ldi r16, 0b00000111 ;7
    ret
P8: ldi r16, 0b01111111 ;8
    ret
P9: ldi r16, 0b01101111 ;9
    ret
PA: ldi r16, 0b01110111 ;A
    ret
PB: ldi r16, 0b01111100 ;b
    ret
PATC: ldi r16, 0b00111001 ;C
    ret
PD_: ldi r16, 0b01011110 ;d
    ret
PE: ldi r16, 0b01111001 ;E
    ret
PF: ldi r16, 0b01110001 ;F
    ret