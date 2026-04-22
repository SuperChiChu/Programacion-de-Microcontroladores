#include "pwm_servo2.h"

#ifndef F_CPU
#define F_CPU 16000000UL
#endif

#define PRESCALER 1024UL

void pwm_servo2_init(void)
{
	DDRB |= (1 << DDB3); // D11 (OC2A)

	// Fast PWM
	TCCR2A = (1 << COM2A1) | (1 << WGM21) | (1 << WGM20);
	TCCR2B = (1 << CS22) | (1 << CS21) | (1 << CS20); // prescaler 1024
}

void pwm_servo2_set_pulse(uint16_t us)
{
	if (us < SERVO2_MIN_US) us = SERVO2_MIN_US;
	if (us > SERVO2_MAX_US) us = SERVO2_MAX_US;

	// Periodo ~16 ms Å® 16000 us
	uint32_t duty = (uint32_t)us * 255 / 16000;

	OCR2A = (uint8_t)duty;
}