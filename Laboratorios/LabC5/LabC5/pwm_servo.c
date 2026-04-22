#include "pwm_servo.h"

#define PWM_SERVO_PRESCALER              8UL
#define PWM_SERVO_TICKS_PER_MICROSECOND  (F_CPU / PWM_SERVO_PRESCALER / 1000000UL)

static uint16_t pwm_servo_limit_duty(uint16_t dutyTicks);
static uint16_t pwm_servo_limit_pulse(uint16_t pulseWidthUs);
static uint16_t pwm_servo_us_to_ticks(uint16_t pulseWidthUs);

void pwm_servo_init(void)
{
	DDRB |= (1 << DDB1) | (1 << DDB2);

	TCCR1A = (1 << COM1A1) |
	(1 << COM1B1) |
	(1 << WGM11);

	TCCR1B = (1 << WGM13) |
	(1 << WGM12) |
	(1 << CS11);

	ICR1 = PWM_SERVO_TOP_VALUE;
	OCR1A = pwm_servo_us_to_ticks(PWM_SERVO_CENTER_PULSE_US);
	OCR1B = pwm_servo_us_to_ticks(PWM_SERVO_CENTER_PULSE_US);
}

void pwm_servo_set_dutyA(uint16_t dutyTicks)
{
	OCR1A = pwm_servo_limit_duty(dutyTicks);
}

void pwm_servo_set_dutyB(uint16_t dutyTicks)
{
	OCR1B = pwm_servo_limit_duty(dutyTicks);
}

void pwm_servo_set_pulseA(uint16_t pulseWidthUs)
{
	pwm_servo_set_dutyA(pwm_servo_us_to_ticks(pwm_servo_limit_pulse(pulseWidthUs)));
}

void pwm_servo_set_pulseB(uint16_t pulseWidthUs)
{
	pwm_servo_set_dutyB(pwm_servo_us_to_ticks(pwm_servo_limit_pulse(pulseWidthUs)));
}

uint16_t pwm_servo_map_adc_to_pulse(uint16_t adcValue)
{
	if (adcValue > 1023U)
	{
		adcValue = 1023U;
	}

	uint32_t scaledPulse = (uint32_t)adcValue *
	(PWM_SERVO_MAX_PULSE_US - PWM_SERVO_MIN_PULSE_US);

	return (uint16_t)(PWM_SERVO_MIN_PULSE_US + (scaledPulse / 1023UL));
}

void pwm_servo_set_duty(uint16_t duty)
{
	pwm_servo_set_dutyA(duty);
}

static uint16_t pwm_servo_limit_duty(uint16_t dutyTicks)
{
	if (dutyTicks > ICR1)
	{
		return ICR1;
	}

	return dutyTicks;
}

static uint16_t pwm_servo_limit_pulse(uint16_t pulseWidthUs)
{
	if (pulseWidthUs < PWM_SERVO_MIN_PULSE_US)
	{
		return PWM_SERVO_MIN_PULSE_US;
	}

	if (pulseWidthUs > PWM_SERVO_MAX_PULSE_US)
	{
		return PWM_SERVO_MAX_PULSE_US;
	}

	return pulseWidthUs;
}

static uint16_t pwm_servo_us_to_ticks(uint16_t pulseWidthUs)
{
	return (uint16_t)(pulseWidthUs * PWM_SERVO_TICKS_PER_MICROSECOND);
}