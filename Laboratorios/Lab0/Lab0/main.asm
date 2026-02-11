;
; Lab0.asm
;
; Created: 23/01/2026 16:34:05
; Author : Chichu
;


//Inicio del codigo en si
.include "M328PDEF.inc"
.dseg
.org SRAM_START

.cseg //code segment
.org 0x0000

//Settings de la pila
// Configuraci?n de la pila
LDI     R16, LOW(RAMEND)
OUT     SPL, R16
LDI     R16, HIGH(RAMEND)
OUT     SPH, R16


//Configuracion MCU
SETUP:
	LDI R16, 0x00 //Limpia el registro R16
	LDI R16, 0x01 //Declarando que es salida
	OUT DDRB, R16 //DDRB decide que es la salida

//DDRB es diciendole el PORTB
//PB0=D8 del arduino

Loop_Main:
	SBI PORTB, 0 //Set Bit IO (Le pone 1 al PORT B)
	CALL Delay_Bank
	CALL Delay_Bank

	CBI PORTB, 0 //Clear Bit IO (Le limpia el valor)
	CALL Delay_Bank
	CALL Delay_Bank

	RJMP Loop_Main
	
Delay_Bank:
    ldi r18, 50
loopA:
    ldi r19, 255
loopB:
    ldi r20, 255
loopC:
    dec r20
    brne loopC //Branch if not equal
    dec r19
    brne loopB
    dec r18
    brne loopA
    ret