/*
* Sumador4bits.asm
*
* Creado: 4-Feb-26 12:53:51 PM
* Autor : Juan Daniel Sandoval Rodriguez
* Descripcion: Sumador binario 4 bits con 2 botones y antirrebote
*/

/****************************************/
// Encabezado (Definicion de Registros, Variables y Constantes)
.include "M328PDEF.inc"
.dseg
.org	SRAM_START
counter1: .byte 1    // original contador 4 bits
counter2: .byte 1	// nuevo contador 4 bits
.cseg
.org 0x0000

/****************************************/
// Configuracion de la pila
LDI R16, LOW(RAMEND)
OUT SPL, R16
LDI R16, HIGH(RAMEND)
OUT SPH, R16

/****************************************/
// Configuracion MCU
SETUP:
// Clear bit y Set bit
//BOTONES
// UP1 -> PD5
CBI DDRD, DDD5
SBI PORTD, PORTD5   // pull-up ON

// DOWN1 -> PD6
CBI DDRD, DDD6
SBI PORTD, PORTD6   // pull-up ON

// UP2 -> PD
CBI DDRD, DDD2
SBI PORTD, PORTD2   // pull-up ON

// DOWN2 -> PD6
CBI DDRD, DDD3
SBI PORTD, PORTD3   // pull-up ON

//LED

// salida contador 1
LDI R16, 0x0F
OUT DDRB, R16

// salida contador 2
LDI R16, 0x0F
OUT DDRC, R16

// SALIDAS SUMA (5 bits)
// S2 -> PD4 (D4)
SBI DDRD, DDD4
// S3 -> PD7 (D7)
SBI DDRD, DDD7
// S0 -> PC4 (A4)
SBI DDRC, DDC4
// S1 -> PC5 (A5)
SBI DDRC, DDC5
// S4 -> PB4 (D12)
SBI DDRB, DDB4

//Store direct to data space (STS)
// Inicializar contador1
LDI R16, 0
STS counter1, R16

// Inicializar contador2
LDI R16, 0
STS counter2, R16


OUT PORTB, R16
OUT PORTC, R16

CALL UPDATE_SUM

CLR R17
CLR R18
CLR R19
CLR R20

/****************************************/
// Loop Infinito
MAIN_LOOP:
CALL CONTADOR1_FN
CALL CONTADOR2_FN
RJMP MAIN_LOOP

//Sub rutinas

CONTADOR1_FN:
// Leer botones
IN R17, PIND

//BOTON UP
//Skip if Bit in Register is Set
SBRS R17, 5          // si PD5=1 (no presionado) salta
CALL DEBOUNCE_UP

//BOTON DOWN
SBRS R17, 6
CALL DEBOUNCE_DOWN

RET

CONTADOR2_FN:
// Leer botones
IN R17, PIND

SBRS R17, 2
CALL DEBOUNCE2_UP

SBRS R17, 3
CALL DEBOUNCE_DOWN2

RET

DEBOUNCE_UP:
CALL DELAY

IN R18, PIND
SBRS R18, 5
CALL INC_COUNTER

WAIT_RELEASE_UP:
IN R19, PIND
SBRC R19, 5
RET
RJMP WAIT_RELEASE_UP


DEBOUNCE_DOWN:
CALL DELAY

IN R18, PIND
SBRS R18, 6
CALL DEC_COUNTER

WAIT_RELEASE_DOWN:
IN R19, PIND
SBRC R19, 6
RET
RJMP WAIT_RELEASE_DOWN

// Agregar para el segundo contador

DEBOUNCE2_UP:
CALL DELAY

IN R18, PIND
SBRS R18, 2
CALL INC_COUNTER2

WAIT_RELEASE_UP2:
IN R19, PIND
SBRC R19, 2
RET
RJMP WAIT_RELEASE_UP2


DEBOUNCE_DOWN2:
CALL DELAY

IN R18, PIND
SBRS R18, 3
CALL DEC_COUNTER2

WAIT_RELEASE_DOWN2:
IN R19, PIND
SBRC R19, 3
RET
RJMP WAIT_RELEASE_DOWN2

// Incrementar contador
INC_COUNTER:
LDS R16, counter1
INC R16
ANDI R16, 0x0F    // solo 4 bits
STS counter1, R16
OUT PORTB, R16
CALL UPDATE_SUM
RET

// Decrementar contador
DEC_COUNTER:
LDS R16, counter1
DEC R16
ANDI R16, 0x0F
STS counter1, R16
OUT PORTB, R16
CALL UPDATE_SUM
RET

// Incrementar contador 2
INC_COUNTER2:
LDS R16, counter2
INC R16
ANDI R16, 0x0F    // solo 4 bits
STS counter2, R16
OUT PORTC, R16
CALL UPDATE_SUM
RET

// Decrementar contador 2
DEC_COUNTER2:
LDS R16, counter2
DEC R16
ANDI R16, 0x0F
STS counter2, R16
OUT PORTC, R16
CALL UPDATE_SUM
RET

// SUMA (counter1 + counter2) -> 5 bits
// S0 -> PC4, S1 -> PC5, S2 -> PD4, S3 -> PD7, S4 -> PB4
// -----------------------------
UPDATE_SUM:
    // sum = counter1 + counter2
    LDS R16, counter1
    LDS R21, counter2
    ADD R16, R21            

    //  PORTC: S0,S1
    IN  R22, PORTC
    ANDI R22, 0xCF          // limpia PC4 y PC5 (1100 1111)
    MOV R23, R16
    ANDI R23, 0x03         // bits 0..1
    LSL R23
    LSL R23
    LSL R23
    LSL R23                 // <<4 para PC4/PC5
    OR  R22, R23
    OUT PORTC, R22

    // PORTD: S2 -> PD4, S3 -> PD7 
    IN  R22, PORTD
    ANDI R22, 0x6F          // limpia PD4 y PD7 (0110 1111)

    MOV R23, R16
    ANDI R23, 0x04          // bit2
    LSL R23
    LSL R23                 // bit2 -> PD4 (0x10)
    OR  R22, R23

    MOV R23, R16
    ANDI R23, 0x08          // bit3
    LSL R23
    LSL R23
    LSL R23
    LSL R23                 // bit3 -> PD7 (0x80)
    OR  R22, R23

    OUT PORTD, R22

    // PORTB: S4 (MSB) -> PB4
    IN  R22, PORTB
    ANDI R22, 0xEF          // limpia PB4 (1110 1111)
    MOV R23, R16
    ANDI R23, 0x10          // bit4 ya es PB4
    OR  R22, R23
    OUT PORTB, R22

    RET


// Delay
DELAY:
    ldi r18, 50
loopA:
    ldi r19, 50
loopB:
    ldi r20, 50
loopC:
    dec r20
    brne loopC //Branch if not equal
    dec r19
    brne loopB
    dec r18
    brne loopA
    ret