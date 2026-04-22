/*
 * LabC5.c
 *
 * Created: 16 de Abril del 2026
 * Author: Juan Daniel Sandoval Rodriguez
 * Description: Lab No.5
 */
/****************************************/
// Encabezado (Libraries)
#define F_CPU 16000000UL
#include <avr/io.h>
#include <util/delay.h>
#include "pwm_servo.h"
#include "pwm_servo2.h"
#include "pwm_soft.h"

/****************************************/
// Function prototypes
void adc_init(void);
uint16_t adc_read(uint8_t channel);

/****************************************/
// Main Function
int main(void)
{
	adc_init();
	pwm_servo_init(); //Timer 1
	pwm_servo2_init(); //Timer 2
	pwm_soft_init(); //Timer 0
	
	while (1)
	{
		// Leer ADCs
		uint16_t adc1 = adc_read(0); // A0 Å® Servo 1
		uint16_t adc2 = adc_read(1); // A1 Å® Servo 2
		uint16_t adc3 = adc_read(2); // A2 Å® LED PWM

		// Mapear servos (?s)
		uint16_t pulse1 = pwm_servo_map_adc_to_pulse(adc1);
		uint16_t pulse2 = pwm_servo_map_adc_to_pulse(adc2);

		// Enviar a servos
		pwm_servo_set_pulseA(pulse1);   // D9 (Timer1)
		pwm_servo2_set_pulse(pulse2);   // D11 (Timer2)

		// PWM manual LED (0?255)
		uint8_t duty = adc3 / 4;
		pwm_soft_set_duty(duty);

		_delay_ms(10); // peque?o delay para estabilidad
	}
}

/****************************************/
// NON-Interrupt subroutines
void adc_init(void)
{
	ADMUX = (1 << REFS0);
	ADCSRA = (1 << ADEN) | (1 << ADPS2) | (1 << ADPS1) | (1 << ADPS0);
}

uint16_t adc_read(uint8_t channel)
{
	ADMUX = (ADMUX & 0xF0) | (channel & 0x0F);
	ADCSRA |= (1 << ADSC);
	while (ADCSRA & (1 << ADSC));
	return ADC;
}

/****************************************/
// Interrupt routines