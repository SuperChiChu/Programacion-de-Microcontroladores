/*
 * servo_t2.h
 * Timer2 PWM por software usando ISR overflow
 * Servo 3 Å® D11 (PB3)
 * Servo 4 Å® D3  (PD3)
 *
 * Timer2 modo normal, prescaler /8 Å® Ftimer = 2MHz
 * TCNT2 precargado en 56 Å® overflow cada 200 ticks = 100us
 * 200 overflows Å~ 100us = 20ms Å® per?odo servo 50Hz
 *
 * Resoluci?n: 1 tick = 100us
 * 1ms  Å® 10 ticks
 * 1.5ms Å® 15 ticks
 * 2ms  Å® 20 ticks
 */
#ifndef SERVO_T2_H_
#define SERVO_T2_H_

#include <avr/io.h>
#include <avr/interrupt.h>

#define S_MIN_TICKS  5     // 1ms  Å® 0Åã
#define S_MAX_TICKS  30    // 2ms  Å® 180Åã
#define S_MID_TICKS  15     // 1.5ms Å® 90Åã
#define PERIOD_TICKS 200    // 20ms Å® periodo completo

// Pines
#define SERVO3_DDR  DDRB
#define SERVO3_PORT PORTB
#define SERVO3_PIN  PB3

#define SERVO4_DDR  DDRD
#define SERVO4_PORT PORTD
#define SERVO4_PIN  PD3

void servo_t2_init(void);
void servo3_adc(uint16_t adc);
void servo4_adc(uint16_t adc);
void servo3_set(uint16_t pulso);
void servo4_set(uint16_t pulso);

#endif