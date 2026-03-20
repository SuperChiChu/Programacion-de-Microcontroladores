/*
* Proyecto_1.asm
*
* Creado: 27-Feb-26
* Autor : Juan Daniel Sandoval Rodriguez
* Descripcion:
*   - Reloj de 24 Horas con alarma y fecha
*   - Se utilizan 4 botones, A0 es para los modos, A1 es para incrementar y A2 es para decrementar, A3 es el elegido para la alarma
*   - 4 Displays con Multiplexado, ademas 2 leds, secundero y modo
*   - El clock va igual a funcionar como el lab 3 por 1ms de momento.
****************************************/
.include "M328PDEF.inc"

.dseg
.org SRAM_START
ss: .byte 1
mm: .byte 1
hh: .byte 1
ticks1ms:	.byte 2		;Contador de ticks 1 ms
blink_dp:   .byte 1
mux_digit:  .byte 1

mode:       .byte 1		;Congifuracion ya de las cosas del reloj
edit_flag:  .byte 1
btn_prev:   .byte 1
debounce_cnt: .byte 1
mode_lock: .byte 1
edit_digit: .byte 1

dd: .byte 1	;Variable del dia
mes: .byte 1 ;Variable del mes


.cseg
.org 0x0000
    rjmp START

.org 0x001C
    rjmp ISR_T0_COMPA ;Direccion de disparo de las interrupciones del timer 0

;==================== STACK ====================
START:
    ldi r16, LOW(RAMEND)
    out SPL, r16
    ldi r16, HIGH(RAMEND)
    out SPH, r16

;==================== SETUP ====================
SETUP:
	clr r16
	sts ticks1ms, r16
	sts ticks1ms+1, r16

	;Limpiar los valores de la hora
    clr r16
    sts ss, r16

    ldi r16, 34
    sts mm, r16

    ldi r16, 12
    sts hh, r16


	sts blink_dp, r16
	sts mux_digit, r16


	sbi DDRC, 5
	sbi PORTC, 5

    clr r16
    sts mode, r16
    sts edit_flag, r16

    ldi r16, 0x0F
    sts btn_prev, r16 ;pull-up

	clr r16
	sts debounce_cnt, r16

	clr r16
	sts mode_lock, r16

    ; Segmentos D2-D7 como salida
    ldi r16, 0b11111100
    out DDRD, r16

    ; PB0 = D8 como salida
    ldi r16, 0b00011111
    out DDRB, r16

    ; Todos los segmentos apagados al inicio
    ldi r16, 0b11111100
    out PORTD, r16

    ; PB0 apagado y todos los digitos desactivados
    ldi r16, 0b00011111

    ;==================== BOTONES ====================
    ; A0 MODE, A1 DOWN, A2 UP, A3 SET

    cbi DDRC, 0
    cbi DDRC, 1
    cbi DDRC, 2
    cbi DDRC, 3

    sbi PORTC, 0
    sbi PORTC, 1
    sbi PORTC, 2
    sbi PORTC, 3

	sbi DDRD, 0      ; D0 como salida, El que muestra el modo
	cbi PORTD, 0     ; LED apagado


; Timer0 CTC 1ms
    ldi r16, 0
    out TCCR0A, r16

    ldi r16, (1<<WGM01)
    out TCCR0A, r16

    ldi r16, 250
    out OCR0A, r16

    clr r16
    out TCNT0, r16

    ldi r16, (1<<OCIE0A)
    sts TIMSK0, r16

    ldi r16, (1<<CS01)|(1<<CS00) ;Pre escaler de 64
    out TCCR0B, r16

    sei

;==================== MAIN ====================
MAIN_LOOP:
    rcall MUX_UPDATE
    rcall HANDLE_BTNS
    rjmp MAIN_LOOP

;==================== SUB ====================

ISR_T0_COMPA:
	push r16
	push r17
	in	 r16, SREG
	push r16

    lds r16, ticks1ms
	lds r17, ticks1ms+1
    inc r16
    brne T_SAVE
	inc r17

T_SAVE:
    sts  ticks1ms, r16
    sts  ticks1ms+1, r17

;==================== DEBOUNCE ====================

    lds r18, debounce_cnt
    tst r18
    breq DB_DONE
    dec r18
    sts debounce_cnt, r18

DB_DONE:

    ; comparar con 1000 (0x03E8)
    cpi  r16, LOW(1000)
    brne T_END
    cpi  r17, HIGH(1000)
    brne T_END

    ; si llega: reset a 0 y toggle PC5 (A5)
    clr  r16
    clr  r17
    sts  ticks1ms, r16
    sts  ticks1ms+1, r17



;==================== RELOJ ====================
    lds  r16, ss
    inc  r16
    cpi  r16, 60
    brlo SAVE_SS

    ; ss llego a 60
    clr  r16
    sts  ss, r16

    lds  r16, mm
    inc  r16
    cpi  r16, 60
    brlo SAVE_MM

    ; mm llego a 60
    clr  r16
    sts  mm, r16

    lds  r16, hh
    inc  r16
    cpi  r16, 24
    brlo SAVE_HH

    ; hh llego a 24
    clr  r16



SAVE_HH:
    sts  hh, r16
    rjmp T_END

SAVE_MM:
    sts  mm, r16
    rjmp T_END

SAVE_SS:
    sts  ss, r16

T_END:
    pop  r16
    out  SREG, r16
    pop  r17
    pop  r16
    reti

; \\\Multiplexado///
MUX_UPDATE:
    push r16
    push r17
    push r18
    push r19

    ; digitos apagados
    sbi PORTB, 1
    sbi PORTB, 2
    sbi PORTB, 3
    sbi PORTB, 4

    ; 2) DP apagado por defecto
    sbi PORTC, 5     ; HIGH apaga dp

    ; 3) Ver que digito toca
    lds r18, mux_digit

	lds r19, mode

	cpi r19, 0
	breq GO_MODE_CLOCK
	cpi r19, 1
	breq GO_MODE_DATE
	rjmp MUX_MODE_ALARM

	GO_MODE_CLOCK:
    rjmp MUX_MODE_CLOCK

	GO_MODE_DATE:
    rjmp MUX_MODE_DATE

; \\\Clock///

	MUX_MODE_CLOCK:
	cpi r18, 0
	breq GO_DIG1_CLOCK
	cpi r18, 1
	breq GO_DIG2_CLOCK
	cpi r18, 2
	breq GO_DIG3_CLOCK
	rjmp MUX_DIG4_CLOCK

	GO_DIG1_CLOCK:
    rjmp MUX_DIG1_CLOCK
	GO_DIG2_CLOCK:
    rjmp MUX_DIG2_CLOCK
	GO_DIG3_CLOCK:
    rjmp MUX_DIG3_CLOCK

; \\\DATE///

	MUX_MODE_DATE:
    cpi r18, 0
    breq GO_DIG1_DATE
    cpi r18, 1
    breq GO_DIG2_DATE
    cpi r18, 2
    breq GO_DIG3_DATE
    rjmp MUX_DIG4_DATE

	GO_DIG1_DATE:
    rjmp MUX_DIG1_DATE

	GO_DIG2_DATE:
    rjmp MUX_DIG2_DATE

	GO_DIG3_DATE:
    rjmp MUX_DIG3_DATE

; \\\Alarma///

	MUX_MODE_ALARM:
    cpi r18, 0
    breq GO_DIG1_ALARM
    cpi r18, 1
    breq GO_DIG2_ALARM
    cpi r18, 2
    breq GO_DIG3_ALARM
    rjmp MUX_DIG4_ALARM

	GO_DIG1_ALARM:
    rjmp MUX_DIG1_ALARM

	GO_DIG2_ALARM:
    rjmp MUX_DIG2_ALARM

	GO_DIG3_ALARM:
    rjmp MUX_DIG3_ALARM

;--------------------------------------------------------
; DIG1 = decena de hora
MUX_DIG1_CLOCK:
    lds r16, hh
    clr r17              ; r17 = decenas
MUX_HH_TENS_LOOP:
    cpi r16, 10
    brlo MUX_HH_TENS_DONE
    subi r16, 10
    inc r17
    rjmp MUX_HH_TENS_LOOP
MUX_HH_TENS_DONE:
    mov r16, r17
    rcall HEX_TO_PAT
    rcall OUT_SEGMENTS
    cbi PORTB, 1
    rjmp MUX_NEXT

;--------------------------------------------------------
; DIG2 = unidad de hora
MUX_DIG2_CLOCK:
    lds r16, hh
MUX_HH_UNITS_LOOP:
    cpi r16, 10
    brlo MUX_HH_UNITS_DONE
    subi r16, 10
    rjmp MUX_HH_UNITS_LOOP
MUX_HH_UNITS_DONE:
    rcall HEX_TO_PAT
    rcall OUT_SEGMENTS

    ; dp/colon segun mitad de segundo
    lds r17, ticks1ms
    lds r18, ticks1ms+1

    ; comparar ticks1ms con 500 (0x01F4)
    cpi r18, HIGH(500)
    brlo MUX_DIG2_DP_ON       ; high < 1  -> menor que 500
    brne MUX_DIG2_DP_DONE     ; high > 1  -> mayor o igual, apagar

    cpi r17, LOW(500)
    brlo MUX_DIG2_DP_ON       ; low < F4 y high=1 -> menor que 500
    rjmp MUX_DIG2_DP_DONE

MUX_DIG2_DP_ON:
    cbi PORTC, 5              ; LOW = encender dp

MUX_DIG2_DP_DONE:
    cbi PORTB, 2
    rjmp MUX_NEXT

;--------------------------------------------------------
; DIG3 = decena de minuto
MUX_DIG3_CLOCK:
    lds r16, mm
    clr r17
MUX_MM_TENS_LOOP:
    cpi r16, 10
    brlo MUX_MM_TENS_DONE
    subi r16, 10
    inc r17
    rjmp MUX_MM_TENS_LOOP
MUX_MM_TENS_DONE:
    mov r16, r17
    rcall HEX_TO_PAT
    rcall OUT_SEGMENTS
    cbi PORTB, 3
    rjmp MUX_NEXT

;--------------------------------------------------------
; DIG4 = unidad de minuto
MUX_DIG4_CLOCK:
    lds r16, mm
MUX_MM_UNITS_LOOP:
    cpi r16, 10
    brlo MUX_MM_UNITS_DONE
    subi r16, 10
    rjmp MUX_MM_UNITS_LOOP
MUX_MM_UNITS_DONE:
    rcall HEX_TO_PAT
    rcall OUT_SEGMENTS
    cbi PORTB, 4

;-------------------------------------------------------

MUX_DIG1_DATE: ;Decena de Dia
    ldi r16, 0
    rcall HEX_TO_PAT
    rcall OUT_SEGMENTS
    cbi PORTB, 1
    rjmp MUX_NEXT

MUX_DIG2_DATE: ;Unidad de Dias
    ldi r16, 2
    rcall HEX_TO_PAT
    rcall OUT_SEGMENTS
    cbi PORTB, 2
    rjmp MUX_NEXT

MUX_DIG3_DATE: ; Decena de mes
    ldi r16, 1
    rcall HEX_TO_PAT
    rcall OUT_SEGMENTS
    cbi PORTB, 3
    rjmp MUX_NEXT

MUX_DIG4_DATE: ; Unidad de mes
    ldi r16, 1
    rcall HEX_TO_PAT
    rcall OUT_SEGMENTS
    cbi PORTB, 4
    rjmp MUX_NEXT
;--------------------------------------------------------
MUX_DIG1_ALARM:
    ldi r16, 0
    rcall HEX_TO_PAT
    rcall OUT_SEGMENTS
    cbi PORTB, 1
    rjmp MUX_NEXT

MUX_DIG2_ALARM:
    ldi r16, 6
    rcall HEX_TO_PAT
    rcall OUT_SEGMENTS
    cbi PORTB, 2
    rjmp MUX_NEXT

MUX_DIG3_ALARM:
    ldi r16, 3
    rcall HEX_TO_PAT
    rcall OUT_SEGMENTS
    cbi PORTB, 3
    rjmp MUX_NEXT

MUX_DIG4_ALARM:
    ldi r16, 0
    rcall HEX_TO_PAT
    rcall OUT_SEGMENTS
    cbi PORTB, 4
    rjmp MUX_NEXT

MUX_NEXT:
    lds r16, mux_digit
    inc r16
    cpi r16, 4
    brlo MUX_SAVE
    clr r16
MUX_SAVE:
    sts mux_digit, r16

    pop r19
    pop r18
    pop r17
    pop r16
    ret

; \\\Termina multiplexado///

READ_BTNS:
    in   r16, PINC
    andi r16, 0x0F      ; solo PC0-PC3
    com  r16            ; invertir porque pull-up
    andi r16, 0x0F
    ret

HANDLE_BTNS:
    push r16
    push r17

    ; leer botones actuales
    rcall READ_BTNS
    mov  r17, r16

    ;==================== MODE RELEASE ====================
    ; si MODE no esta presionado, liberar candado
    sbrs r17, 0
    rjmp HB_MODE_RELEASED
    rjmp HB_MODE_CHECK

HB_MODE_RELEASED:
    clr  r16
    sts  mode_lock, r16
    rjmp HB_END

HB_MODE_CHECK:
    ; si debounce activo, salir
    lds  r16, debounce_cnt
    tst  r16
    brne HB_END

    ; si ya estaba bloqueado, salir
    lds  r16, mode_lock
    tst  r16
    brne HB_END

    ; nueva pulsacion valida de MODE
    lds  r16, mode
    inc  r16
    cpi  r16, 3
    brlo HB_MODE_OK
    clr  r16

HB_MODE_OK:
    sts  mode, r16

    ; bloquear hasta liberar
    ldi  r16, 1
    sts  mode_lock, r16

    ; debounce corto
    ldi  r16, 20
    sts  debounce_cnt, r16

HB_END:
    pop  r17
    pop  r16
    ret

OUT_SEGMENTS:
    push r17
    push r18

    ; Sacar bits a-f hacia PD2-PD7
    mov r17, r16
    andi r17, 0b00111111     ; tomar a..f
    lsl r17
    lsl r17                  ; mover a bits 2..7

    in  r18, PORTD
    andi r18, 0b00000011     ; conservar PD0 y PD1
    or  r18, r17
    out PORTD, r18

    ; Sacar g hacia PB0
    in  r18, PORTB
    andi r18, 0b11111110     ; limpiar PB0

    mov r17, r16
    andi r17, 0b01000000     ; aislar g
    breq OUT_SEG_G0
    ori r18, 0b00000001      ; poner PB0 en 1 si g=1
OUT_SEG_G0:
    out PORTB, r18

    pop r18
    pop r17
    ret

; Tabla hex de los numeros
HEX_TO_PAT:
    andi r16, 0b00001111

    cpi r16, 0
    breq Cero
    cpi r16, 1
    breq Uno
    cpi r16, 2
    breq Dos
    cpi r16, 3
    breq Tres
    cpi r16, 4
    breq Cuatro
    cpi r16, 5
    breq Cinco
    cpi r16, 6
    breq Seis
    cpi r16, 7
    breq Siete
    cpi r16, 8
    breq Ocho
    rjmp Nueve

Cero: ldi r16, 0b01000000
    ret
Uno: ldi r16, 0b01111001
    ret
Dos: ldi r16, 0b00100100
    ret
Tres: ldi r16, 0b00110000
    ret
Cuatro: ldi r16, 0b00011001
    ret
Cinco: ldi r16, 0b00010010
    ret
Seis: ldi r16, 0b00000010
    ret
Siete: ldi r16, 0b01111000
    ret
Ocho: ldi r16, 0b00000000
    ret
Nueve: ldi r16, 0b00011000
    ret