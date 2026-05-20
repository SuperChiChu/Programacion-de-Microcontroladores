/*
 * servo_t1.h
 * Timer1 (16 bits) Fast PWM Modo 14
 * OC1A Å® Servo 1 (D9, PB1)
 * OC1B Å® Servo 2 (D10, PB2)
 * Ambos comparten ICR1 Å® 50 Hz
 */
#ifndef SERVO_T1_H_
#define SERVO_T1_H_

#include <avr/io.h>

#define ICR1_TOP    39999   // 50 Hz con prescaler /8
#define SERVO_MIN   1200    // 0.5ms Å® 0Åã
#define SERVO_MAX   5000    // 2.5ms Å® 180Åã

void servo_t1_init(void);
void servo1_set(uint16_t pulso);
void servo1_adc(uint16_t adc);
void servo2_set(uint16_t pulso);
void servo2_adc(uint16_t adc);

#endif