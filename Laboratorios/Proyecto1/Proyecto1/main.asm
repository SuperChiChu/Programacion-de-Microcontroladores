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

alarm_hh: .byte 1
alarm_mm: .byte 1
alarm_on: .byte 1
alarm_ringing: .byte 1

set_lock: .byte 1 ;Variable de si se esta editando el valor
inc_lock: .byte 1
sel_lock: .byte 1


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

	ldi r16, 1
	sts dd, r16

	ldi r16, 1
	sts mes, r16


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

	clr r16
	sts set_lock, r16

	clr r16
	sts inc_lock, r16

	clr r16
	sts sel_lock, r16

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
	out PORTB, r16

;==================== BOTONES ====================
    ; A0 Modo, A1 Cambio, A2 Arriba, A3 Set

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

;==================== ALARM ====================

	ldi r16,6
	sts alarm_hh,r16

	ldi r16,30
	sts alarm_mm,r16

	clr r16
	sts alarm_on,r16

	clr r16
	sts alarm_ringing, r16

	sbi DDRC, 4      ; A4 como salida
	cbi PORTC, 4     ; buzzer apagado

    sei

;==================== MAIN ====================
MAIN_LOOP:
    rcall MUX_UPDATE
    rcall HANDLE_BTNS
    rcall BUZZER_UPDATE

    ; LED EDIT en D0
    lds r16, edit_flag
    tst r16
    breq LED_OFF

LED_ON:
    sbi PORTD, 0
    rjmp LED_DONE

LED_OFF:
    cbi PORTD, 0

LED_DONE:

    rjmp MAIN_LOOP

;==================== SUB ====================

ISR_T0_COMPA:
	push r16
	push r17
	push r18
	in	 r16, SREG
	push r16

    lds r16, ticks1ms ;Byte bajo 16
	lds r17, ticks1ms+1 ;Byte alto 16
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

    ; comparar con 1000
    cpi  r16, LOW(1000)
    brne GO_T_END
    cpi  r17, HIGH(1000)
    brne GO_T_END

    ; si llego a 1000 ms: reset ticks a 0
    clr  r16
    clr  r17
    sts  ticks1ms, r16
    sts  ticks1ms+1, r17



;============ ======== RELOJ ====================
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
    sts  hh, r16

    ; avanzar dia
    lds  r16, dd
    inc  r16
    cpi  r16, 32
    brlo SAVE_DD

    ; dd llego a 32 -> reiniciar a 1 y subir mes
    ldi  r16, 1
    sts  dd, r16

    lds  r16, mes
    inc  r16
    cpi  r16, 13
    brlo SAVE_MES

    ; mes llego a 13 -> volver a 1
    ldi  r16, 1

SAVE_MES:
    sts  mes, r16
    rjmp ALARM_COMPARE

SAVE_DD:
    sts  dd, r16
    rjmp ALARM_COMPARE

SAVE_HH:
    sts  hh, r16
    rjmp ALARM_COMPARE

SAVE_MM:
    sts  mm, r16
    rjmp ALARM_COMPARE

SAVE_SS:
    sts  ss, r16


GO_T_END:
	rjmp T_END

ALARM_COMPARE:
    ;==================== COMPARAR ALARMA ====================

    lds r16, hh
    lds r17, alarm_hh
    cp  r16, r17
    brne ALARM_CHECK_END

    lds r16, mm
    lds r17, alarm_mm
    cp  r16, r17
    brne ALARM_CHECK_END

    lds r16, ss
    tst r16
    brne ALARM_CHECK_END

    ldi r16, 1
    sts alarm_ringing, r16

ALARM_CHECK_END:

T_END:
    pop  r16
    out  SREG, r16
	pop	 r18
    pop  r17
    pop  r16
    reti

;==================== MULTIPLEXADO ====================
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

    ; DP apagado por defecto
    sbi PORTC, 5     ; HIGH apaga dp

	;Parpadeo de display
    lds r16, edit_flag
    tst r16
    rjmp MUX_CONTINUE_NORMAL

    lds r17, ticks1ms
    lds r18, ticks1ms+1

    cpi r18, HIGH(800)
    brlo MUX_CONTINUE_NORMAL
    brne MUX_BLANK

    cpi r17, LOW(300)
    brlo MUX_CONTINUE_NORMAL

MUX_BLANK:
    rjmp MUX_NEXT_ONLY

MUX_CONTINUE_NORMAL:

    ; Ver que digito toca
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

;==================== CLOCK ====================

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

;==================== FECHA ====================

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

CHECK_DAY_LIMIT:

    push r16
    push r17

    lds r16,mes

    cpi r16,2
    breq FEB_CHECK

    cpi r16,4
    breq M30_CHECK
    cpi r16,6
    breq M30_CHECK
    cpi r16,9
    breq M30_CHECK
    cpi r16,11
    breq M30_CHECK

; ====== meses de 31 ======

M31_CHECK:
    lds r17,dd
    cpi r17,32
    brlo DAY_OK
    ldi r17,31
    sts dd,r17
    rjmp DAY_OK

; ====== meses de 30 ======

M30_CHECK:
    lds r17,dd
    cpi r17,31
    brlo DAY_OK
    ldi r17,30
    sts dd,r17
    rjmp DAY_OK

; ====== febrero ======

FEB_CHECK:
    lds r17,dd
    cpi r17,29
    brlo DAY_OK
    ldi r17,28
    sts dd,r17

DAY_OK:
    pop r17
    pop r16
    ret

;==================== ALARM ====================

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

    ; dp segun mitad de segundo
    lds r17, ticks1ms
    lds r18, ticks1ms+1

    ; comparar ticks1ms con 500 (0x01F4)
    cpi r18, HIGH(500)
    brlo MUX_DIG2_DP_ON
    brne MUX_DIG2_DP_DONE

    cpi r17, LOW(500)
    brlo MUX_DIG2_DP_ON
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
	rjmp MUX_NEXT

;--------------------------------------------------------
; DIG1 = decena de dia
MUX_DIG1_DATE:
    lds r16, dd
    clr r17
MUX_DD_TENS_LOOP:
    cpi r16, 10
    brlo MUX_DD_TENS_DONE
    subi r16, 10
    inc r17
    rjmp MUX_DD_TENS_LOOP
MUX_DD_TENS_DONE:
    mov r16, r17
    rcall HEX_TO_PAT
    rcall OUT_SEGMENTS
    cbi PORTB, 1
    rjmp MUX_NEXT

;--------------------------------------------------------
; DIG2 = unidad de dia
MUX_DIG2_DATE:
    lds r16, dd
MUX_DD_UNITS_LOOP:
    cpi r16, 10
    brlo MUX_DD_UNITS_DONE
    subi r16, 10
    rjmp MUX_DD_UNITS_LOOP
MUX_DD_UNITS_DONE:
    rcall HEX_TO_PAT
    rcall OUT_SEGMENTS
    cbi PORTB, 2
    rjmp MUX_NEXT

;--------------------------------------------------------
; DIG3 = decena de mes
MUX_DIG3_DATE:
    lds r16, mes
    clr r17
MUX_MES_TENS_LOOP:
    cpi r16, 10
    brlo MUX_MES_TENS_DONE
    subi r16, 10
    inc r17
    rjmp MUX_MES_TENS_LOOP
MUX_MES_TENS_DONE:
    mov r16, r17
    rcall HEX_TO_PAT
    rcall OUT_SEGMENTS
    cbi PORTB, 3
    rjmp MUX_NEXT

;--------------------------------------------------------
; DIG4 = unidad de mes
MUX_DIG4_DATE:
    lds r16, mes
MUX_MES_UNITS_LOOP:
    cpi r16, 10
    brlo MUX_MES_UNITS_DONE
    subi r16, 10
    rjmp MUX_MES_UNITS_LOOP
MUX_MES_UNITS_DONE:
    rcall HEX_TO_PAT
    rcall OUT_SEGMENTS
    cbi PORTB, 4
    rjmp MUX_NEXT

;--------------------------------------------------------
MUX_DIG1_ALARM:
    lds r16,alarm_hh
    clr r17

AL_HH_TENS_LOOP:
    cpi r16,10
    brlo AL_HH_TENS_DONE
    subi r16,10
    inc r17
    rjmp AL_HH_TENS_LOOP

AL_HH_TENS_DONE:
    mov r16,r17
    rcall HEX_TO_PAT
    rcall OUT_SEGMENTS
    cbi PORTB,1
    rjmp MUX_NEXT

MUX_DIG2_ALARM:
    lds r16,alarm_hh

AL_HH_UNITS_LOOP:
    cpi r16,10
    brlo AL_HH_UNITS_DONE
    subi r16,10
    rjmp AL_HH_UNITS_LOOP

AL_HH_UNITS_DONE:
    rcall HEX_TO_PAT
    rcall OUT_SEGMENTS
    cbi PORTB,2
    rjmp MUX_NEXT

MUX_DIG3_ALARM:
    lds r16,alarm_mm
    clr r17

AL_MM_TENS_LOOP:
    cpi r16,10
    brlo AL_MM_TENS_DONE
    subi r16,10
    inc r17
    rjmp AL_MM_TENS_LOOP

AL_MM_TENS_DONE:
    mov r16,r17
    rcall HEX_TO_PAT
    rcall OUT_SEGMENTS
    cbi PORTB,3
    rjmp MUX_NEXT

MUX_DIG4_ALARM:
    lds r16,alarm_mm

AL_MM_UNITS_LOOP:
    cpi r16,10
    brlo AL_MM_UNITS_DONE
    subi r16,10
    rjmp AL_MM_UNITS_LOOP

AL_MM_UNITS_DONE:
    rcall HEX_TO_PAT
    rcall OUT_SEGMENTS
    cbi PORTB,4
    rjmp MUX_NEXT

MUX_NEXT_ONLY:
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

;==================== END MULTIPLEX ====================

READ_BTNS:
    in   r16, PINC
    andi r16, 0x0F      ; solo PC0-PC3
    com  r16            ; invertir
    andi r16, 0x0F
    ret

HANDLE_BTNS:
    push r16
    push r17
    push r18

    ; leer botones actuales
    rcall READ_BTNS
    mov  r17, r16

	; si cualquier boton esta presionado, apagar alarma
    tst  r17
    breq NO_ALARM_STOP

    clr  r16
    sts  alarm_ringing, r16

NO_ALARM_STOP:

    ;==================== MODE ====================
    ; si MODE no esta presionado -> liberar lock
    sbrs r17, 0
    rjmp HB_MODE_RELEASED
    rjmp HB_MODE_CHECK

HB_MODE_RELEASED:
    clr  r16
    sts  mode_lock, r16
    rjmp HB_SET_START

HB_MODE_CHECK:
    ; si debounce activo, no hacer nada con MODE
    lds  r16, debounce_cnt
    tst  r16
    brne HB_SET_START

    ; si ya estaba bloqueado, no hacer nada con MODE
    lds  r16, mode_lock
    tst  r16
    brne HB_SET_START

    ; MODE solo funciona si NO estoy editando
    lds  r16, edit_flag
    tst  r16
    brne HB_SET_START

    ; nueva pulsacion valida de MODE
    lds  r16, mode
    inc  r16
	cpi  r16, 3
	brlo GO_HB_MODE_OK
	clr  r16

GO_HB_MODE_OK:
    rjmp HB_MODE_OK

HB_MODE_OK:
    sts mode, r16

    ; bloquear hasta liberar
    ldi  r16, 1
    sts  mode_lock, r16

    ; debounce corto
    ldi  r16, 20
    sts  debounce_cnt, r16

    ;==================== SET ====================
HB_SET_START:
    ; si SET no esta presionado -> liberar lock
    sbrs r17, 3
    rjmp HB_SET_RELEASED
    rjmp HB_SET_CHECK

HB_SET_RELEASED:
    clr  r16
    sts  set_lock, r16
    rjmp HB_SEL_START

HB_SET_CHECK:
    ; debounce activo?
    lds  r16, debounce_cnt
    tst  r16
    brne GO_HB_END

    ; ya estaba bloqueado?
    lds  r16, set_lock
    tst  r16
    brne HB_SEL_START

    ; toggle edit_flag
    lds  r16, edit_flag
    ldi  r18, 1
    eor  r16, r18
    sts  edit_flag, r16

    ; si entro a edicion -> empezar en digito 0
    tst  r16
    breq HB_SET_LOCK

    clr  r18
    sts  edit_digit, r18

HB_SET_LOCK:
    ldi  r16, 1
    sts  set_lock, r16

    ldi  r16, 20
    sts  debounce_cnt, r16

    rjmp HB_SEL_START

GO_HB_END:
    rjmp HB_END

;==================== SELECT DIGIT (A1) ====================
HB_SEL_START:
    ; si A1 no esta presionado -> liberar lock
    sbrs r17, 1
    rjmp HB_SEL_RELEASED
    rjmp HB_SEL_CHECK

HB_SEL_RELEASED:
    clr  r16
    sts  sel_lock, r16
    rjmp HB_INC_START

HB_SEL_CHECK:
    ; solo funciona si edit_flag = 1
    lds  r16, edit_flag
    tst  r16
    breq HB_INC_START

    ; debounce activo?
    lds  r16, debounce_cnt
    tst  r16
    brne HB_INC_START

    ; ya estaba bloqueado?
    lds  r16, sel_lock
    tst  r16
    brne HB_INC_START

    ; avanzar edit_digit: 0->1->2->3->0
    lds  r16, edit_digit
    inc  r16
    cpi  r16, 4
    brlo HB_SEL_OK
    clr  r16

HB_SEL_OK:
    sts  edit_digit, r16

    ; bloquear hasta liberar
    ldi  r16, 1
    sts  sel_lock, r16

    ; debounce corto
    ldi  r16, 20
    sts  debounce_cnt, r16

;==================== INCREMENT DIGIT (A2) ====================

HB_INC_START:

    ; si A2 no esta presionado -> liberar lock
    sbrs r17,2
    rjmp HB_INC_RELEASED
    rjmp HB_INC_CHECK

HB_INC_RELEASED:
    clr  r16
    sts  inc_lock,r16
    rjmp HB_END

HB_INC_CHECK:

    lds  r16,edit_flag
    tst  r16
    breq GO_HB_END

    lds  r16,debounce_cnt
    tst  r16
    brne GO_HB_END

    lds  r16,inc_lock
    tst  r16
    brne GO_HB_END

    lds r18,mode
    cpi r18,0
    breq GO_EDIT_CLOCK

    cpi r18,1
    breq GO_EDIT_DATE

    rjmp EDIT_ALARM

GO_EDIT_CLOCK:
    rjmp EDIT_CLOCK

GO_EDIT_DATE:
    rjmp EDIT_DATE

EDIT_CLOCK:

    lds r18,edit_digit

    cpi r18,0
    breq GO_INC_HH_TENS
    cpi r18,1
    breq GO_INC_HH_UNITS
    cpi r18,2
    breq GO_INC_MM_TENS
    rjmp INC_MM_UNITS

EDIT_DATE:
	lds r18,edit_digit

    cpi r18,0
    breq GO_INC_DD_TENS
    cpi r18,1
    breq GO_INC_DD_UNITS
    cpi r18,2
    breq GO_INC_MES_TENS
    rjmp INC_MES_UNITS

GO_INC_DD_TENS:
    rjmp INC_DD_TENS

GO_INC_DD_UNITS:
    rjmp INC_DD_UNITS

GO_INC_MES_TENS:
    rjmp INC_MES_TENS

EDIT_ALARM:

    lds r18,edit_digit

    cpi r18,0
    breq GO_INC_AL_HH_TENS
    cpi r18,1
    breq GO_INC_AL_HH_UNITS
    cpi r18,2
    breq GO_INC_AL_MM_TENS
    rjmp INC_AL_MM_UNITS

GO_INC_AL_HH_TENS:
    rjmp INC_AL_HH_TENS

GO_INC_AL_HH_UNITS:
    rjmp INC_AL_HH_UNITS

GO_INC_AL_MM_TENS:
    rjmp INC_AL_MM_TENS

GO_INC_HH_TENS:
    rjmp INC_HH_TENS

GO_INC_HH_UNITS:
    rjmp INC_HH_UNITS

GO_INC_MM_TENS:
    rjmp INC_MM_TENS

INC_HH_TENS:
    lds r16,hh
    subi r16,10
    brpl HH_TENS_OK
    ldi r16,20
    rjmp SAVE_HH_TENS

HH_TENS_OK:
    subi r16,-10

SAVE_HH_TENS:
    sts hh,r16
    rjmp INC_DONE

INC_HH_UNITS:
    lds r16,hh
    inc r16
    cpi r16,24
    brlo SAVE_HH_UNITS
    clr r16

SAVE_HH_UNITS:
    sts hh,r16
    rjmp INC_DONE

INC_MM_TENS:
    lds r16,mm
    subi r16,-10
    cpi r16,60
    brlo SAVE_MM_TENS
    clr r16

SAVE_MM_TENS:
    sts mm,r16
    rjmp INC_DONE

INC_MM_UNITS:
    lds r16,mm
    inc r16
    cpi r16,60
    brlo SAVE_MM_UNITS
    clr r16

SAVE_MM_UNITS:
    sts mm,r16

INC_DD_TENS:
    lds r16,dd
    subi r16,-10
    cpi r16,32
    brlo SAVE_DD_TENS
    ldi r16,1

SAVE_DD_TENS:
    sts dd,r16
	rcall CHECK_DAY_LIMIT
    rjmp INC_DONE

INC_DD_UNITS:
    lds r16,dd
    inc r16
    cpi r16,32
    brlo SAVE_DD_UNITS
    ldi r16,1

SAVE_DD_UNITS:
    sts dd,r16
	rcall CHECK_DAY_LIMIT
    rjmp INC_DONE

INC_MES_TENS:
    lds r16,mes
    subi r16,-10
    cpi r16,13
    brlo SAVE_MES_TENS
    ldi r16,1

SAVE_MES_TENS:
    sts mes,r16
	rcall CHECK_DAY_LIMIT
    rjmp INC_DONE

INC_MES_UNITS:
    lds r16,mes
    inc r16
    cpi r16,13
    brlo SAVE_MES_UNITS
    ldi r16,1

SAVE_MES_UNITS:
    sts mes,r16
	rcall CHECK_DAY_LIMIT
    rjmp INC_DONE

INC_AL_HH_TENS:
    lds r16,alarm_hh
    subi r16,-10
    cpi r16,24
    brlo SAVE_AL_HH_TENS
    clr r16

SAVE_AL_HH_TENS:
    sts alarm_hh,r16
    rjmp INC_DONE

INC_AL_HH_UNITS:
    lds r16,alarm_hh
    inc r16
    cpi r16,24
    brlo SAVE_AL_HH_UNITS
    clr r16

SAVE_AL_HH_UNITS:
    sts alarm_hh,r16
    rjmp INC_DONE

INC_AL_MM_TENS:
    lds r16,alarm_mm
    subi r16,-10
    cpi r16,60
    brlo SAVE_AL_MM_TENS
    clr r16

SAVE_AL_MM_TENS:
    sts alarm_mm,r16
    rjmp INC_DONE

INC_AL_MM_UNITS:
    lds r16,alarm_mm
    inc r16
    cpi r16,60
    brlo SAVE_AL_MM_UNITS
    clr r16

SAVE_AL_MM_UNITS:
    sts alarm_mm,r16
    rjmp INC_DONE

INC_DONE:

    ; activar lock
    ldi r16,1
    sts inc_lock,r16

    ; debounce
    ldi r16,20
    sts debounce_cnt,r16

    rjmp HB_END

HB_END:
    pop  r18
    pop  r17
    pop  r16
    ret

BUZZER_UPDATE:
    push r16
    push r17

    lds r16, alarm_ringing
    tst r16
    breq BUZZER_OFF

    ; usar ticks para hacer PWM
    lds r17, ticks1ms
    andi r17, 0x03

    brne BUZZER_OFF

BUZZER_ON:
    sbi PORTC, 4
    rjmp BUZZER_DONE

BUZZER_OFF:
    cbi PORTC, 4

BUZZER_DONE:
    pop r17
    pop r16
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
    andi r17, 0b01000000
    breq OUT_SEG_G0
    ori r18, 0b00000001
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