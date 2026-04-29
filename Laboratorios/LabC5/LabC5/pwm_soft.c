#include "pwm_soft.h"
#include <avr/interrupt.h>

volatile uint8_t counter = 0;
volatile uint8_t duty_value = 0;

void pwm_soft_init(void)
{
	DDRD |= (1 << PD6); // LED en D6

	// Timer0 CTC
	TCCR0A = (1 << WGM01);
	TCCR0B = (1 << CS01); // prescaler 8

	OCR0A = 124; // 1 ms

	TIMSK0 |= (1 << OCIE0A); // habilitar interrupci?n

	sei();
}

void pwm_soft_set_duty(uint8_t duty)
{
	duty_value = duty;
}

ISR(TIMER0_COMPA_vect)
{
	counter++;

	if (counter == 0)
	{
		PORTD |= (1 << PD6); // ON
	}

	if (counter == duty_value)
	{
		PORTD &= ~(1 << PD6); // OFF
	}
}